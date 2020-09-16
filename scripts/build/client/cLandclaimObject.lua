class 'cLandclaimObject'

-- Data container for objects within landclaims
function cLandclaimObject:__init(args)

    self.id = args.id -- Unique object id per claim, changes every reload
    self.name = args.name
    self.position = args.position
    self.angle = args.angle
    self.health = args.health
    self.custom_data = args.custom_data
    self.extensions = self:GetExtensions()

end

-- Creates the ClientStaticObject in the world
function cLandclaimObject:Create(no_collision)
    if IsValid(self.object) then return end
    self.object = ClientStaticObject.Create({
        position = self.position,
        angle = self.angle,
        model = self:GetModel(),
        collision = no_collision and "" or self:GetCollision()
    })
end

-- Destroys the ClientStaticObject in the world
function cLandclaimObject:Remove()
    if not IsValid(self.object) then return end
    self.object:Remove()
end

-- Destroys the current ClientStaticObject and replaces it with one that has/does not have collision
function cLandclaimObject:ToggleCollision(enabled)
    self:Remove()
    self:Create(not enabled)
end

function cLandclaimObject:GetModel()
    return BuildObjects[self.name].model
end

function cLandclaimObject:GetCollision()
    return BuildObjects[self.name].collision
end

function cLandclaimObject:GetExtensions()
    local extensions = {}

    if self.name == "Door" then
        table.insert(extensions, cDoorExtension(self))
    elseif self.name == "Light" then
        table.insert(extensions, cLightExtension(self))
    elseif self.name == "Bed" then
        table.insert(extensions, cBedExtension(self))
    end

    return extensions
end