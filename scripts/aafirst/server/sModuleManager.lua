-- Unload some modules only for testing

Events:Subscribe("ServerStart", function()
    Console:Run("unload settings")
end)