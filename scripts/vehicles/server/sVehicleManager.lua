local insert = table.insert
local random = math.random

class 'sVehicleManager'

function sVehicleManager:__init()

    SQL:Execute("CREATE TABLE IF NOT EXISTS vehicles (vehicle_id INTEGER PRIMARY KEY AUTOINCREMENT, model_id INTEGER, pos VARCHAR, angle VARCHAR, col1 VARCHAR, col2 VARCHAR, decal VARCHAR, template VARCHAR, owner_steamid VARCHAR, health REAL, cost INTEGER, guards INTEGER)")

    self.vehicles = {} -- All vehicles in the server
    self.owned_vehicles = {} -- All owned vehicles in the server

    self.despawning_vehicles = {} -- Owned vehicles that will despawn because the owner got off

    self.spawns = {} -- Spawn positions with their corresponding vehicles and times, etc
    self.spawn_weights = {}

    self:SetupSpawnTables()
    self:ReadVehicleSpawnData("spawns.txt")
    self:SpawnVehicles()

    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
    Events:Subscribe("ClientModuleLoad", self, self.ClientModuleLoad)
    Events:Subscribe("PlayerExitVehicle", self, self.PlayerExitVehicle)
    Events:Subscribe("PlayerEnterVehicle", self, self.PlayerEnterVehicle)

    Events:Subscribe("TimeChange", self, self.TimeChange)

    Events:Subscribe("PlayerQuit", self, self.PlayerQuit)

    Network:Subscribe("Vehicles/SpawnVehicle", self, self.PlayerSpawnVehicle)
    Network:Subscribe("Vehicles/DeleteVehicle", self, self.PlayerDeleteVehicle)

    local func = coroutine.wrap(function()
        while true do

            self:Tick500()

            Timer.Sleep(500)
        end
    end)()


    -- Respawn vehicles loop
    local func = coroutine.wrap(function()
        while true do

            local random = math.random

            for spawn_type, data_entries in pairs(self.spawns) do
                for index, spawn_data in pairs(data_entries) do

                    if not spawn_data.spawned 
                    and random() < config.spawn[spawn_type].spawn_chance
                    and spawn_data.respawn_timer:GetMinutes() >= config.spawn[spawn_type].respawn_interval then
                        -- Spawn vehicle
                        self:SpawnNaturalVehicle(spawn_type, index)
                    end

                    Timer.Sleep(1)
                end

            end
        

            Timer.Sleep(1000 * 60)
        end
    end)()

end

function sVehicleManager:Tick500()
    -- Every 500 ms, heal vehicles that are at gas stations
end

function sVehicleManager:TimeChange()
    for id, timer in pairs(self.despawning_vehicles) do

        if count_table(self.owned_vehicles[id]:GetOccupants()) > 0 then
            -- Friend is using vehicle, restart timer
            timer:Restart()
            self:SaveVehicle(self.owned_vehicles[id])

        elseif timer:GetMinutes() >= config.owned_despawn_time then
            -- Remove vehicle from game
            self.despawning_vehicles[id] = nil

            local vehicle_id = self.owned_vehicles[id]:GetId()
            self.owned_vehicles[id]:Remove()
            self.owned_vehicles[id] = nil

            self.vehicles[vehicle_id] = nil

        end

    end

end

function sVehicleManager:PlayerQuit(args)

    local vehicles = args.player:GetValue("OwnedVehicles")
    if not vehicles then return end

    for id, vehicle_data in pairs(vehicles) do
        if IsValid(vehicle_data.vehicle) then
            self.despawning_vehicles[id] = Timer()
        end
    end

end

function sVehicleManager:PlayerExitVehicle(args)
    local vehicle_data = args.vehicle:GetValue("VehicleData")
    if not vehicle_data then return end

    if vehicle_data.vehicle_id then
        -- Vehicle is owned, update it
        self:SaveVehicle(args.vehicle, args.player)

        -- If a friend is using the vehicle, restart the timer
        if self.despawning_vehicles[vehicle_data.vehicle_id] then
            self.despawning_vehicles[vehicle_data.vehicle_id]:Restart()
        end
    end
end

function sVehicleManager:PlayerSpawnVehicle(args, player)

    local player_owned_vehicles = player:GetValue("OwnedVehicles")
    args.vehicle_id = tonumber(args.vehicle_id)

    local vehicle_data = player_owned_vehicles[args.vehicle_id]

    if not vehicle_data then return end
    if vehicle_data.spawned then return end

    local spawn_args = deepcopy(vehicle_data)
    
    spawn_args.tone1 = vehicle_data.col1
    spawn_args.tone2 = vehicle_data.col2

    local vehicle = self:SpawnVehicle(spawn_args)
    vehicle:SetHealth(vehicle_data.health)

    vehicle_data.spawned = true
    vehicle_data.vehicle = vehicle

    player_owned_vehicles[args.vehicle_id] = vehicle_data

    self.owned_vehicles[args.vehicle_id] = vehicle

    vehicle:SetNetworkValue("VehicleData", vehicle_data)
    player:SetValue("OwnedVehicles", player_owned_vehicles)
    self.vehicles[vehicle:GetId()] = vehicle

    self:SyncPlayerOwnedVehicles(player)

end

function sVehicleManager:PlayerDeleteVehicle(args, player)
    if not args.vehicle_id then return end

    args.vehicle_id = tonumber(args.vehicle_id)
    
    local player_owned_vehicles = player:GetValue("OwnedVehicles")

    local vehicle_data = player_owned_vehicles[args.vehicle_id]

    if not vehicle_data then return end
    
    local cmd = SQL:Command("DELETE FROM vehicles WHERE vehicle_id = (?)")
    cmd:Bind(1, args.vehicle_id)
    cmd:Execute()

    if IsValid(vehicle_data.vehicle) then
        vehicle_data.vehicle:Remove()
    end

    player_owned_vehicles[args.vehicle_id] = nil
    player:SetValue("OwnedVehicles", player_owned_vehicles)

    self.owned_vehicles[args.vehicle_id] = nil

    self:SyncPlayerOwnedVehicles(player)

    
    Chat:Send(args.player, string.format("Vehicle deleted. (%s/%s)", 
        tostring(count_table(player_owned_vehicles)), tostring(config.player_max_vehicles)), Color.Green)

end


function sVehicleManager:PlayerEnterVehicle(args)

    local data = args.vehicle:GetValue("VehicleData")
    args.data = data

    if data.owner_steamid ~= tostring(args.player:GetSteamId()) 
    and not IsAFriend(args.player, data.owner_steamid) then
        -- If this is not the owner and they are not a friend of the owner
        self:TryBuyVehicle(args)
    else
        -- This is an owned vehicle, so update it in the DB
        self:SaveVehicle(args.vehicle, args.player)

        -- If a friend is using the vehicle, restart the timer
        if self.despawning_vehicles[data.vehicle_id] then
            self.despawning_vehicles[data.vehicle_id]:Restart()
        end
    end

end

-- When a player enters an unowned vehicle or owned (not by a friend or themself)
function sVehicleManager:TryBuyVehicle(args)

    local player_lockpicks = Inventory.GetNumOfItem({player = args.player, item_name = "Lockpick"})
    local owned_vehicles = args.player:GetValue("OwnedVehicles")

    if player_lockpicks < args.data.cost then
        self:RemovePlayerFromVehicle(args)
        self:RestoreOldDriverIfExists(args)
        return
    end

    if count_table(owned_vehicles) >= config.player_max_vehicles then
        self:RemovePlayerFromVehicle(args)
        self:RestoreOldDriverIfExists(args)
        return
    end

    -- If they tried to steal it while there was someone inside
    if IsValid(args.old_driver) then
        self:RemovePlayerFromVehicle(args)
        self:RestoreOldDriverIfExists(args)
        return
    end


    local item_cost = CreateItem({
        name = "Lockpick",
        amount = args.data.cost
    })
    
    Inventory.RemoveItem({
        item = item_cost:GetSyncObject(),
        player = args.player
    })

    if args.data.vehicle_id then
        owned_vehicles[args.data.vehicle_id] = args.data
        args.player:SetValue("OwnedVehicles", owned_vehicles)
        self:SyncPlayerOwnedVehicles(args.player)
    end

    -- Check if vehicle is owned or unowned
    if not args.data.owner_steamid then
        -- Not owned previously
        args.data.cost = args.data.cost * config.cost_multiplier_on_purchase

        Chat:Send(args.player, string.format("Vehicle successfully purchased! (%s/%s)", 
            tostring(count_table(owned_vehicles) + 1), tostring(config.player_max_vehicles)), Color.Green)
    
    elseif args.data.vehicle_id then
        
        -- Remove vehicle from old owner's list
        local old_owner = nil

        for p in Server:GetPlayers() do
            if tostring(p:GetSteamId()) == args.data.owner_steamid then
                old_owner = p
                break
            end
        end

        if IsValid(old_owner) then
            local player_owned_vehicles = old_owner:GetValue("OwnedVehicles")
            player_owned_vehicles[args.data.vehicle_id] = nil
            old_owner:SetValue("OwnedVehicles", player_owned_vehicles)
            self:SyncPlayerOwnedVehicles(old_owner)
        end

        Events:Fire("SendPlayerPersistentMessage", {
            steam_id = args.data.owner_steamid,
            message = string.format("%s stole your vehicle [%s]", args.player:GetName(), args.vehicle:GetName()),
            color = Color.Red
        })

        Chat:Send(args.player, string.format("Vehicle successfully stolen! (%s/%s)", 
            tostring(count_table(owned_vehicles)), tostring(config.player_max_vehicles)), Color.Green)
    
        self.despawning_vehicles[args.data.vehicle_id] = nil
    end

    -- Now buy the vehicle
    args.data.owner_steamid = tostring(args.player:GetSteamId())

    args.vehicle:SetNetworkValue("VehicleData", args.data)

    self:SaveVehicle(args.vehicle, args.player)

    if args.data.spawn_index and args.data.spawn_type then
        self.spawns[args.data.spawn_type][args.data.spawn_index].respawn_timer:Restart()
        self.spawns[args.data.spawn_type][args.data.spawn_index].spawned = false
    end

end

function sVehicleManager:RemovePlayerFromVehicle(args)
    args.player:Teleport(args.player:GetPosition(), args.player:GetAngle())
end

-- If the vehicle was somehow hijacked from someone, put old driver back in the vehicle
function sVehicleManager:RestoreOldDriverIfExists(args)
    if args.old_driver then args.old_driver:EnterVehicle(args.vehicle, VehicleSeat.Driver) end
end

function sVehicleManager:ClientModuleLoad(args)

    local result = SQL:Query("SELECT * FROM vehicles WHERE owner_steamid = (?)")
    result:Bind(1, tostring(args.player:GetSteamId()))
    result = result:Execute()

    local owned_vehicles = {}

    if result and count_table(result) > 0 then
        -- Send player vehicle data
        for i, v in ipairs(result) do
            v.model_id = tonumber(v.model_id)
            v.spawned = false
            v.guards = tonumber(v.guards)
            v.cost = tonumber(v.cost)
            v.position = self:DeserializePosition(v.pos)
            v.angle = self:DeserializeAngle(v.angle)
            v.col1 = self:DeserializeColor(v.col1)
            v.col2 = self:DeserializeColor(v.col2)
            v.vehicle_id = tonumber(v.vehicle_id)
            v.health = tonumber(v.health)
            owned_vehicles[v.vehicle_id] = v

            if IsValid(self.owned_vehicles[v.vehicle_id]) then
                v.spawned = true
                v.vehicle = self.owned_vehicles[v.vehicle_id]
                self.despawning_vehicles[v.vehicle_id] = nil
            end
        end
    end

    args.player:SetValue("OwnedVehicles", owned_vehicles)
    self:SyncPlayerOwnedVehicles(args.player)

end

-- Syncs a player's owned vehicles to them for use in the vehicle menu
function sVehicleManager:SyncPlayerOwnedVehicles(player)
    Network:Send(player, "Vehicles/SyncOwnedVehicles", player:GetValue("OwnedVehicles"))
end

-- Read spawn data from file
function sVehicleManager:ReadVehicleSpawnData(filename)

    print("Opening " .. filename)
    local file = io.open(filename, "r")

    if not file then
        print("No spawns.txt, aborting loading of spawns")
        return
    end

    -- For each line, handle appropriately
    for line in file:lines() do
        if line:sub(1,1) == "X" then
            self:ParseVehicle(line)
		end
    end
    
    file:close()

end

function sVehicleManager:ParseVehicle(line)
    -- Remove start, spaces
	line = string.trim(line)
    line = line:gsub("X", "")
    line = line:gsub(" ", "")

    -- Split into tokens
    local tokens = line:split(",")

    -- Create vector
    local vector = Vector3(tonumber(tokens[1]),tonumber(tokens[2]),tonumber(tokens[3]))
    local angle  = Angle(tonumber(tokens[4]),tonumber(tokens[5]),tonumber(tokens[6]))

    -- Save to table
    insert(self.spawns[tokens[7]], {position = vector, angle = angle, spawned = false, respawn_timer = Timer()})
	
end

function sVehicleManager:SetupSpawnTables()

    for k,v in pairs(vIds) do
        self.spawns[k] = {}

        self.spawn_weights[k] = {total = 0, individual = {}}

        for id, weight in pairs(v) do
            self.spawn_weights[k].total = self.spawn_weights[k].total + weight
            insert(self.spawn_weights[k].individual, {id = id, weight = self.spawn_weights[k].total}) -- Running totals
        end
    end

end

-- Spawns all vehicles at their spawns around the world when the server starts up
function sVehicleManager:SpawnVehicles()

    -- Start a timer to measure load time
    local timer = Timer()
    local cnt = 0
    local total_cnt = 0

    local random = math.random

    for spawn_type, data_entries in pairs(self.spawns) do
        for index, spawn_data in pairs(data_entries) do

            if random() < config.spawn[spawn_type].spawn_chance then
                self:SpawnNaturalVehicle(spawn_type, index)
                cnt = cnt + 1
            end
            
            total_cnt = total_cnt + 1

        end
    end

    print(string.format("Spawned %d/%d vehicles, %.02f seconds", cnt, total_cnt, timer:GetSeconds()))

end

-- Spawns/respawns a natural vehicle 
function sVehicleManager:SpawnNaturalVehicle(spawn_type, index)

    local spawn_data = self.spawns[spawn_type][index]
    self.spawns[spawn_type][index].spawned = true

    local spawn_args = self:GetVehicleFromType(spawn_type)
    spawn_args.position = spawn_data.position
    spawn_args.angle = spawn_data.angle
    
    spawn_args.spawn_type = spawn_type
    
    spawn_args.tone1 = self:GetColorFromHSV(config.colors.default)
    spawn_args.tone2 = spawn_args.tone1 -- Matching tones here so cars look normal. 

    local vehicle = self:SpawnVehicle(spawn_args)
    vehicle:SetHealth(config.spawn.health.min + (config.spawn.health.max - config.spawn.health.min) * random())

    local vehicle_data = self:GenerateVehicleData(spawn_args)
    vehicle_data.health = vehicle:GetHealth()
    vehicle_data.position = vehicle:GetPosition()
    vehicle_data.model_id = vehicle:GetModelId()
    vehicle_data.spawned = true
    vehicle_data.vehicle = vehicle
    vehicle_data.spawn_type = spawn_type
    vehicle_data.spawn_index = index

    vehicle:SetNetworkValue("VehicleData", vehicle_data)
    self.vehicles[vehicle:GetId()] = vehicle

end

function sVehicleManager:GenerateVehicleData(args)

    return 
    {
        cost = self:GetVehicleCost(args),
        owner_steamid = nil,
        vehicle_id = nil,
        guards = 0
    }

end

function sVehicleManager:GetVehicleCost(args)

    if config.spawn.cost_overrides[args.model_id] then
        return random(
            math.round(config.spawn.cost_modifier * config.spawn.cost_overrides[args.model_id] * (1 - config.spawn.variance)), 
            math.round(config.spawn.cost_modifier * config.spawn.cost_overrides[args.model_id] * (1 + config.spawn.variance)))
    elseif config.spawn[args.spawn_type] then
        return random(
            math.round(config.spawn.cost_modifier * config.spawn[args.spawn_type].cost * (1 - config.spawn.variance)), 
            math.round(config.spawn.cost_modifier * config.spawn[args.spawn_type].cost * (1 + config.spawn.variance)))
    end

    for k,v in pairs(args) do print(k,v) end
    error("Could not determine valid spawn type for: ")
    return 999

end

function sVehicleManager:GetColorFromHSV(hsv)
    return Color.FromHSV(random(hsv.h_min, hsv.h_max), random(hsv.s_min, hsv.s_max) / 100, random(hsv.v_min, hsv.v_max) / 100)
end

function sVehicleManager:GetVehicleFromType(type)

    local args = {}

    -- First get model id
    local random_num = random()
    local target_weight = self.spawn_weights[type].total * random_num
    for index, data in ipairs(self.spawn_weights[type].individual) do

        if target_weight <= data.weight then
            args.model_id = data.id
            break
        end

    end

    -- Get random decal
    if random() <= config.decal_chance then
        args.decal = table.randomvalue(config.decals)
    end

    -- Now get template, if it exists
    if config.templates[args.model_id] then
        if random() <= config.templates[args.model_id].chance then
            args.template = table.randomvalue(config.templates[args.model_id].templates)
        end
    end

    return args

end

-- Using a function for now incase we need to do future compatibility stuff
function sVehicleManager:SpawnVehicle(args)
    return Vehicle.Create(args)
end

function sVehicleManager:ModuleUnload()
    for k,v in pairs(self.vehicles) do
        if IsValid(v) then v:Remove() end
    end
end

-- Call this to update/insert a vehicle to SQL. Will automatically assign VehicleData if it does not exist
function sVehicleManager:SaveVehicle(vehicle, player)

    if not IsValid(vehicle) or vehicle:GetHealth() <= 0 then return end
    
    local vehicle_data = vehicle:GetValue("VehicleData") -- Vehicle data will always exist
    if not vehicle_data then return end

    local cmd = SQL:Command("UPDATE vehicles SET model_id = ?, pos = ?, angle = ?, col1 = ?, col2 = ?, decal = ?, template = ?, owner_steamid = ?, health = ?, cost = ?, guards = ? where vehicle_id = ?")
    if not vehicle_data.vehicle_id and player then -- New vehicle

        if not IsValid(player) then return end -- How can we insert if the player isn't valid
        cmd = SQL:Command("INSERT INTO vehicles (model_id, pos, angle, col1, col2, decal, template, owner_steamid, health, cost, guards) values (?,?,?,?,?,?,?,?,?,?,?)")

        vehicle_data.owner_steamid = tostring(player:GetSteamId())

    end

    local color1, color2 = vehicle:GetColors()

	cmd:Bind(1, vehicle:GetModelId())
	cmd:Bind(2, self:SerializePosition(vehicle:GetPosition()))
	cmd:Bind(3, self:SerializeAngle(vehicle:GetAngle()))
	cmd:Bind(4, self:SerializeColor(color1))
	cmd:Bind(5, self:SerializeColor(color2))
	cmd:Bind(6, tostring(vehicle:GetDecal()))
	cmd:Bind(7, tostring(vehicle:GetTemplate()))
	cmd:Bind(8, vehicle_data.owner_steamid)
	cmd:Bind(9, math.round(vehicle:GetHealth(), 5))
	cmd:Bind(10, vehicle_data.cost)
    cmd:Bind(11, vehicle_data.guards)
    
    -- If we are updating the vehicle
    if vehicle_data.vehicle_id then
        cmd:Bind(12, tonumber(vehicle_data.vehicle_id))
    end

    cmd:Execute()

    -- Newly purchased vehicle
    if not vehicle_data.vehicle_id then
        cmd = SQL:Query("SELECT last_insert_rowid() as insert_id FROM vehicles")
        local result = cmd:Execute()
        vehicle_data.vehicle_id = tonumber(result[1].insert_id)
    end

    vehicle_data.spawned = true
    vehicle_data.position = vehicle:GetPosition()

    vehicle:SetNetworkValue("VehicleData", vehicle_data)

    if IsValid(player) then
        local owned_vehicles = player:GetValue("OwnedVehicles")
        owned_vehicles[vehicle_data.vehicle_id] = vehicle_data
        player:SetValue("OwnedVehicles", owned_vehicles)
        self:SyncPlayerOwnedVehicles(player)
    end

    self.owned_vehicles[vehicle_data.vehicle_id] = vehicle

end

function sVehicleManager:SerializePosition(pos)
    return math.round(pos.x, 2) .. "," .. math.round(pos.y, 2) .. "," .. math.round(pos.z, 2)
end

function sVehicleManager:DeserializePosition(pos)
    local split = pos:split(",")
    return Vector3(tonumber(split[1]), tonumber(split[2]), tonumber(split[3]))
end

function sVehicleManager:SerializeAngle(ang)
    return math.round(ang.x, 5) .. "," .. math.round(ang.y, 5) .. "," .. math.round(ang.z, 5) .. "," .. math.round(ang.w, 5)
end

function sVehicleManager:DeserializeAngle(ang)
    local split = ang:split(",")
    return Angle(tonumber(split[1]), tonumber(split[2]), tonumber(split[3]), tonumber(split[4]))
end

function sVehicleManager:SerializeColor(col)
    return col.r .. "," .. col.g .. "," .. col.b
end

function sVehicleManager:DeserializeColor(col)
    local split = col:split(",")
    return Color(tonumber(split[1]), tonumber(split[2]), tonumber(split[3]))
end

VehicleManager = sVehicleManager()