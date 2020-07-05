class 'cEmotes'

function cEmotes:__init()

    self.sitting = false

    self.allowed_actions = 
    {
        [Action.LookDown] = true,
        [Action.LookLeft] = true,
        [Action.LookRight] = true,
        [Action.LookUp] = true,
        [Action.HeliTurnLeft] = true,
        [Action.HeliTurnRight] = true,
        [Action.Weapon4] = true,
        [Action.Weapon6] = true,
        [Action.EquipLeftSlot] = true,
        [Action.GuiPDA] = true,
        [Action.FireLeft] = true,
        [Action.FireRight] = true,
        [Action.McFire] = true,
        [Action.VehicleFireLeft] = true,
        [Action.ThrowGrenade] = true,
        [Action.VehicleFireRight] = true,
    }

    Events:Subscribe("LocalPlayerChat", self, self.LocalPlayerChat)
    Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

end

function cEmotes:ModuleUnload()

    if self.sitting then
        LocalPlayer:SetBaseState(AnimationState.SUprightIdle)
    end

end

function cEmotes:LocalPlayerChat(args)

    local speed = LocalPlayer:GetLinearVelocity():Length()

    if args.text == "/sit" 
    and LocalPlayer:GetBaseState() == AnimationState.SUprightIdle
    and speed < 1 then
        self.sitting = not self.sitting

        if self.sitting then
            self:StartSitting()
        elseif not self.sitting then
            self:StopSitting()
        end

    end

end

function cEmotes:StartSitting()
    LocalPlayer:SetBaseState(AnimationState.SIdlePassengerVehicle)
    self.lpi = Events:Subscribe("LocalPlayerInput", self, self.LocalPlayerInput)
    self.sitting = true
end

function cEmotes:StopSitting()
    self.sitting = false
    LocalPlayer:SetBaseState(AnimationState.SUprightIdle)
    Events:Unsubscribe(self.lpi)
end

function cEmotes:LocalPlayerInput(args)
    if not self.allowed_actions[args.input] then
        self:StopSitting()
    end
end

cEmotes = cEmotes()