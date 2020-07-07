if not BUILDING_ENABLED then return end

class 'cBuildMode'

function cBuildMode:__init()

    self.enabled = false -- Whether build mode is enabled or not
    self.selected_object = nil
    self.groupmode = false
    
    self.selected_objects = {}

    self.disabled_build_actions = -- Actions to disable while in build mode
    {
        [Action.FireLeft] = true,
        [Action.FireRight] = true,
        [Action.McFire] = true,
        [Action.VehicleFireRight] = true,
        [Action.PickupWithLeftHand] = true,
        [Action.PickupWithRightHand] = true,
        [Action.ActivateBlackMarketBeacon] = true,
        [Action.GuiPDAZoomOut] = true,
        [Action.GuiPDAZoomIn] = true,
        [Action.NextWeapon] = true,
        [Action.PrevWeapon] = true,
        [Action.Kick] = true
    }

    Events:Subscribe("LocalPlayerChat", self, self.LocalPlayerChat)

end

function cBuildMode:Render(args)
    self:RenderSelectedObject(args)
    self:RenderHud(args)
end

function cBuildMode:RenderHud(args)

    local color = Color(255, 255, 255, 200)
    local text_size = 20
    local text_height = Render:GetTextHeight("A", text_size) + 2

    local pos = Vector2(10, Render.Size.y * 0.25)

    local current_object = LocalPlayer:GetValue("CurrentObject") or {model = "none", collision = "none"}

    Render:DrawText(pos, string.format("Current Model: %s", current_object.model), color, text_size)
    pos = pos + Vector2(0, text_height)
    Render:DrawText(pos, string.format("Current Collision: %s", current_object.collision), color, text_size)
    pos = pos + Vector2(0, text_height)

    
    local location = LocalPlayer:GetValue("Build_Location") or "None"
    Render:DrawText(pos, string.format("Location: %s", location), color, text_size)
    pos = pos + Vector2(0, text_height)

    local groupmode = tostring(self.groupmode)
    Render:DrawText(pos, string.format("Group Mode Enabled: %s", groupmode), color, text_size)
    pos = pos + Vector2(0, text_height)


end

function cBuildMode:RenderSelectedObject(args)

    if not IsValid(self.selected_object) then return end

    local pos, on_screen = Render:WorldToScreen(self.selected_object:GetPosition())

    if not on_screen then return end

    local t = Transform2():Translate(pos)
    Render:SetTransform(t)

    Render:FillCircle(Vector2.Zero, 50, Color(0, 200, 0, 150))

    Render:ResetTransform()

end

function cBuildMode:GameRender(args)

end

function cBuildMode:LocalPlayerInput(args)
    if self.disabled_build_actions[args.input] then return false end
end

function cBuildMode:MouseScroll(args)



end

function cBuildMode:PlaceObject(args)
    Network:Send("BuildTools/PlaceObject", args)
end

-- Returns the object that the player is looking at, if any
function cBuildMode:GetLookAtObject()

    local ray = Physics:Raycast(Camera:GetPosition(), Camera:GetAngle() * Vector3.Forward, 0, 1000)
    if not ray.entity or ray.entity.__type ~= "ClientStaticObject" then return end

    local object = ray.entity
    if not object:GetValue("LocationName") then return end -- Not a valid location object

    return object

end

function cBuildMode:MouseUp(args)

    if args.button == 1 then

        -- Left click, place object
        -- cBuildObjectPlacer handles this

    elseif args.button == 2 then 

        -- Right click, select object and begin editing it
        if cBuildObjectPlacer.placing then return end

        if not self.groupmode then
            self.selected_object = self:GetLookAtObject()
            if not IsValid(self.selected_object) then return end

            cBuildObjectPlacer:StartObjectPlacement({
                object = self.selected_object,
                angle = self.selected_object:GetAngle()
            })

            Network:Send("BuildTools/SetCurrentObject", {
                model = self.selected_object:GetModel(),
                collision = self.selected_object:GetCollision()
            })
        else

            local object = self:GetLookAtObject()
            if not self.selected_objects[object:GetId()] then
                self.selected_objects[object:GetId()] = object
            else
                self.selected_objects[object:GetId()] = nil
            end

        end

    elseif args.button == 3 then

        -- Middle click, duplicate object(s)

        if not self.groupmode then
            local object = self.selected_object

            if not IsValid(object) then return end

            cBuildObjectPlacer:StartObjectPlacement({
                object = ClientStaticObject.Create({
                    position = object:GetPosition(),
                    angle = object:GetAngle(),
                    model = object:GetModel(),
                    collision = object:GetCollision()
                }),
                angle = object:GetAngle()
            })

            Network:Send("BuildTools/SetCurrentObject", {
                model = object:GetModel(),
                collision = object:GetCollision()
            })
        else

            -- Duplicate all objects and start placing

        end

    end

end

function cBuildMode:KeyUp(args)

    if args.key == string.byte("Q") then

        if not self.groupmode then
            if not LocalPlayer:GetValue("CurrentObject") then return end

            if not cBuildObjectPlacer.placing then
                cBuildObjectPlacer:StartObjectPlacement({
                    model = LocalPlayer:GetValue("CurrentObject").model
                })
            else
                cBuildObjectPlacer:StopObjectPlacement()
            end
        else

            -- Spawn entire group of objects with anchor point as the center

        end

    elseif args.key == VirtualKey.Delete then

        if not self.groupmode then

            if not IsValid(self.selected_object) then return end

            Network:Send("BuildTools/DeleteObject", {
                object_id = self.selected_object:GetValue("ObjectIndex")
            })

            self.selected_object:Remove()
            
        else

            for id, obj in pairs(self.selected_objects) do
                if IsValid(obj) then obj:Remove() end
            end

            self.selected_objects = {}

            -- TODO: remove all objects from location

        end

    end

end

function cBuildMode:StartBuilding()

    self.events = 
    {
        Events:Subscribe("Render", self, self.Render),
        Events:Subscribe("GameRender", self, self.GameRender),
        Events:Subscribe("LocalPlayerInput", self, self.LocalPlayerInput),
        Events:Subscribe("MouseUp", self, self.MouseUp),
        Events:Subscribe("MouseScroll", self, self.MouseScroll),
        Events:Subscribe("KeyUp", self, self.KeyUp)
    }

end

function cBuildMode:StopBuilding()

    if self.events then
        for _, event in pairs(self.events) do
            event = Events:Unsubscribe(event)
        end
    end

    self.events = nil

end

function cBuildMode:LocalPlayerChat(args)

    if args.text == "/buildmode" then

        self.enabled = not self.enabled

        Chat:Print(string.format("Buildmode %s", self.enabled and "enabled" or "disabled"), Color.Yellow)

        if self.enabled then
            self:StartBuilding()
        else
            self:StopBuilding()
        end

    end

    if not self.enabled then return end

    if args.text == "/groupmode" then
        self.groupmode = not self.groupmode
        self.selected_objects = {}
    elseif args.text == "/spawnhere" then
        Network:Send("BuildTools/PlaceObject", {
            position = Camera:GetPosition(),
            angle = Angle()
        })
    end

end