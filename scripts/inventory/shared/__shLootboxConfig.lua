Lootbox = {}

Lootbox.Types = 
{
    Level1 = 1,
    Level2 = 2,
    Level3 = 3,
    Level4 = 4,
    Level5 = 5, -- Floating ones
    Dropbox = 7, -- Dropbox
    Storage = 8, -- Deprecated
    VendingMachineFood = 9,
    VendingMachineDrink = 10,
    BarrelStash = 11,
    GarbageStash = 12,
    LockedStash = 13,
}

StashAccessMode = 
{
    Everyone = 1,
    Friends = 2,
    OnlyMe = 3
}

StashAccessModeStrings = 
{
    [StashAccessMode.Everyone] = "Everyone",
    [StashAccessMode.Friends] = "Friends",
    [StashAccessMode.OnlyMe] = "Only Me"
}

Lootbox.Stashes = 
{
    [Lootbox.Types.BarrelStash] = {capacity = 10, name = "Barrel Stash", health = 500, default_access = StashAccessMode.Everyone},
    [Lootbox.Types.GarbageStash] = {capacity = 12, name = "Garbage Stash", health = 1000, default_access = StashAccessMode.Everyone},
    [Lootbox.Types.LockedStash] = {capacity = 12, name = "Locked Stash", health = 1500, default_access = StashAccessMode.OnlyMe},
}

Lootbox.GeneratorConfig = 
{
    spawnable = -- Spawnable loot boxes, aka generated by the server
    {
        [Lootbox.Types.Level1] = true,
        [Lootbox.Types.Level2] = true,
        [Lootbox.Types.Level3] = true,
        [Lootbox.Types.Level4] = true,
        [Lootbox.Types.Level5] = true,
        [Lootbox.Types.VendingMachineFood] = true,
        [Lootbox.Types.VendingMachineDrink] = true,
    },
    box = 
    {
        [Lootbox.Types.Level1] = 
        {
            min_items = 1,
            max_items = 1,
            respawn = 10,
            max_spawned = 1.0 -- % of total boxes spawned at once, between 0 and 1
        },
        [Lootbox.Types.Level2] = 
        {
            min_items = 1,
            max_items = 1,
            respawn = 15,
            max_spawned = 1.0
        },
        [Lootbox.Types.Level3] = 
        {
            min_items = 1,
            max_items = 2,
            respawn = 25,
            max_spawned = 1.0
        },
        [Lootbox.Types.Level4] = 
        {
            min_items = 1,
            max_items = 2,
            respawn = 45,
            max_spawned = 1.0
        },
        [Lootbox.Types.Level5] = 
        {
            min_items = 1,
            max_items = 3,
            respawn = 55
        },
        [Lootbox.Types.VendingMachineFood] = 
        {
            min_items = 1,
            max_items = 2,
            respawn = 15,
            max_spawned = 1.0
        },
        [Lootbox.Types.VendingMachineDrink] = 
        {
            min_items = 1,
            max_items = 2,
            respawn = 15,
            max_spawned = 1.0
        },
    }
}

Lootbox.Models = 
{
    [Lootbox.Types.Level1] = 
    {
        model = "mod.heavydrop.grenade.eez/wea00-c.lod",
        col = "mod.heavydrop.grenade.eez/wea00_lod1-c_col.pfx",
        top_model = "mod.heavydrop.grenade.eez/wea00-c1.lod",
        top_col = "mod.heavydrop.grenade.eez/wea00_lod1-c1_col.pfx",
        offset = Vector3(0, 0, 0),
        offset2 = Vector3(0, 0, 0),
        look_offset = Vector3(0, -0.1, 0.2)
    },
    [Lootbox.Types.Level2] = 
    {
        model = "f1m03airstrippile07.eez/go164_01-a.lod",
        col = "f1m03airstrippile07.eez/go164_01_lod1-a_col.pfx",
        offset = Vector3(0, 0, 0),
        look_offset = Vector3(0, 0.2, 0)
    },
    [Lootbox.Types.Level3] =
    {
        model = "mod.heavydrop.beretta.eez/wea00-b.lod",
        col = "mod.heavydrop.beretta.eez/wea00_lod1-b_col.pfx",
        top_model = "mod.heavydrop.beretta.eez/wea00-b1.lod",
        top_col = "mod.heavydrop.beretta.eez/wea00_lod1-b1_col.pfx",
        offset = Vector3(0, 0, 0),
        offset2 = Vector3(0, 0, 0),
        look_offset = Vector3(0, 0, 0.3)
    },
    [Lootbox.Types.Level4] =
    {
        model = "mod.heavydrop.assault.eez/wea00-a.lod",
        col = "mod.heavydrop.assault.eez/wea00_lod1-a_col.pfx",
        top_model = "mod.heavydrop.assault.eez/wea00-a1.lod",
        top_col = "mod.heavydrop.assault.eez/wea00_lod1-a1_col.pfx",
        offset = Vector3(0, 0, 0),
        offset2 = Vector3(0, -0.04, -0.03),
        look_offset = Vector3(0, 0, 0.25)
    },
    [Lootbox.Types.Level5] = 
    {
        model = "pickup.boost.vehicle.eez/pu02-a.lod",
        col = "37x10.flz/go061_lod1-e_col.pfx",
        model2 = "general.blz/gae03-gae03.lod",
        offset = Vector3(0, -0.05, 0)
    },
    [Lootbox.Types.Dropbox] = 
    {
        model = "geo.cbb.eez/go152-a.lod",
        col = "km05.hotelbuilding01.flz/key030_01_lod1-n_col.pfx",
        offset = Vector3(0, -0.025, 0)
    },
    [Lootbox.Types.BarrelStash] = 
    {
        model = "38x11.nl/go231-a.lod",
        col = "38x11.nl/go231_lod1-a_col.pfx",
        offset = Vector3(0, 0, 0),
        look_offset = Vector3(0, 0.4, 0)
    },
    [Lootbox.Types.GarbageStash] = 
    {
        model = "f1t16.garbage_can.eez/go225-a.lod",
        col = "f1t16.garbage_can.eez/go225_lod1-a_col.pfx",
        offset = Vector3(0, 0, 0),
        look_offset = Vector3(0, 0.4, 0)
    },
    [Lootbox.Types.LockedStash] = 
    {
        model = "areaset03.blz/go161-a1_dst.lod",
        col = "areaset03.blz/go161_lod1-a1_dst_col.pfx",
        offset = Vector3(0, 0, 0)
    },
    [Lootbox.Types.VendingMachineFood] = 
    {
        model = "59x36.nl/go158-a1.lod",
        col = "59x36.nl/go158_lod1-a1_col.pfx",
        model_dst = "59x36.nl/go158-a1_dst.lod",
        col_dst = "59x36.nl/go158_lod1-a1_dst_col.pfx",
        offset = Vector3(0, 0, 0),
        look_offset = Vector3(0, 1, -1)
    },
    [Lootbox.Types.VendingMachineDrink] = 
    {
        model = "59x36.nl/go158-a.lod",
        col = "59x36.nl/go158_lod1-a_col.pfx",
        model_dst = "59x36.nl/go158-a_dst.lod",
        col_dst = "59x36.nl/go158_lod1-a_dst_col.pfx",
        offset = Vector3(0, 0, 0),
        look_offset = Vector3(0, 1, -1)
    }
}

Lootbox.LookAtColor = Color(56, 198, 43)

Lootbox.Distances = 
{
    Start_Raycast = 100,
    Can_Open = 2.5
}
Lootbox.Cell_Size = 256
Lootbox.Scan_Interval = 2000 -- How often the client checks for new cells
Lootbox.Dropbox_Despawn_Time = 10 * 60 * 1000
Lootbox.Loot_Despawn_Time = 10 * 60 * 1000 -- How long it takes for an opened lootbox to despawn
Lootbox.Deathdrop_Despawn_Time = 60 * 60 * 1000 -- How long it takes for a death drop to despawn
Lootbox.uid = 0
Lootbox.Max_Items_In_Dropbox = 6
Lootbox.Min_Respawn_Modifier = 0.25 -- Minimum percentage of respawn time a lootbox resapwns at given nearby players
Lootbox.Safe_Place_Radius = 2 -- Radius in which claymores and mines cannot be placed near loot



LootCells = 
{
    Loot = {},
    Player = {}
}


function GetLootboxUID()
    Lootbox.uid = Lootbox.uid + 1
    return Lootbox.uid
end
