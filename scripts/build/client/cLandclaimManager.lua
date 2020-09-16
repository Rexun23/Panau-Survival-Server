class 'cLandclaimManager'

function cLandclaimManager:__init()

    -- Preemptively register one resource while we wait for the total landclaim count sync
    Events:Fire("loader/RegisterResource", {count = 1})

    self.cell_size = 2048

    self.landclaims = {}

    self.delta = 0

    Events:Fire("build/ResetLandclaimsMenu")

    Network:Subscribe("build/SyncLandclaim", self, self.SyncLandclaim)
    Network:Subscribe("build/SyncTotalLandclaims", self, self.SyncTotalLandclaims)
    Network:Subscribe("build/SyncSmallLandclaimUpdate", self, self.SyncSmallLandclaimUpdate)
    Events:Subscribe("Cells/LocalPlayerCellUpdate" .. tostring(self.cell_size), self, self.LocalPlayerCellUpdate)
    Events:Subscribe("build/ToggleLandclaimVisibility", self, self.ToggleLandclaimVisibility)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
    Events:Subscribe("GameRender", self, self.GameRender)

    -- Wait until player position has been set to load landclaims
    if LocalPlayer:GetValue("Loading") then
        local sub
        sub = Events:Subscribe(var("loader/BaseLoadscreenDone"):get(), function()
            Thread(function()
                local spawn_pos = LocalPlayer:GetValue("SpawnPosition")
                while spawn_pos:Distance(LocalPlayer:GetPosition()) > 3 do
                    Timer.Sleep(250)
                end
                Network:Send("build/ReadyForInitialSync")
                Events:Unsubscribe(sub)
            end)
        end)
    else
        Network:Send("build/ReadyForInitialSync")
    end

end

function cLandclaimManager:SyncSmallLandclaimUpdate(args)
    if not self.landclaims[args.landclaim_owner_id] 
    or not self.landclaims[args.landclaim_owner_id][args.landclaim_id] then return end

    local landclaim = self.landclaims[args.landclaim_owner_id][args.landclaim_id]
    landclaim:PlaceObject(args.object)
    Events:Fire("build/UpdateLandclaims", self:GetLocalPlayerOwnedLandclaims())
end

function cLandclaimManager:ToggleLandclaimVisibility(args)
    if not args.id then return end

    local my_claims = self.landclaims[tostring(LocalPlayer:GetSteamId())]
    if not my_claims then return end

    local landclaim = my_claims[args.id]
    if not landclaim then return end

    landclaim.visible = not landclaim.visible
end

function cLandclaimManager:GameRender(args)

    local my_claims = self.landclaims[tostring(LocalPlayer:GetSteamId())]
    if not my_claims then return end

    self.delta = self.delta + args.delta

    -- Render landclaim borders for the owner if they are enabled
    for id, landclaim in pairs(my_claims) do
        if landclaim.visible then
            cLandclaimPlacer:RenderLandClaimBorder(landclaim.position, landclaim.size, self.delta)
        end
    end

end

function cLandclaimManager:GetLocalPlayerOwnedLandclaims()
    local landclaims = self.landclaims[tostring(LocalPlayer:GetSteamId())] or {}
    local landclaim_data = {}

    for id, landclaim in pairs(landclaims) do
        landclaim_data[id] = landclaim:GetSyncObject()
    end

    return landclaim_data
end

function cLandclaimManager:ModuleUnload()

    for steam_id, landclaims in pairs(self.landclaims) do
        for id, landclaim in pairs(landclaims) do
            landclaim:Unload()
        end
    end
end

function cLandclaimManager:LocalPlayerCellUpdate(args)

    for steam_id, landclaims in pairs(self.landclaims) do
        for id, landclaim in pairs(landclaims) do
            landclaim:LocalPlayerCellUpdate(args)
        end
    end

end

-- Called by server when a single landclaim syncs, either on join or when a new one is placed
function cLandclaimManager:SyncLandclaim(args)

    if not self.landclaims[args.owner_id] then
        self.landclaims[args.owner_id] = {}
    end

    local landclaim = cLandclaim(args)
    self.landclaims[args.owner_id][args.id] = landclaim

    -- Sync owned landclaims to asset manager menu
    if args.owner_id == tostring(LocalPlayer:GetSteamId()) then
        Events:Fire("build/UpdateLandclaims", self:GetLocalPlayerOwnedLandclaims())
        Events:Fire("build/AddLandclaimToMap", landclaim:GetSyncObject())
    end

end

function cLandclaimManager:SyncTotalLandclaims(args)

    -- Regsiter each landclaim as a loading resource so the load screen waits for them to fully load
    Events:Fire("loader/RegisterResource", {count = args.total})
    Events:Fire("loader/CompleteResource", {count = 1})

end

LandclaimManager = nil

Events:Subscribe("LoaderReady", function()

    if not LandclaimManager then
        LandclaimManager = cLandclaimManager()
    end

end)