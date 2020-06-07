class 'sServerStats'

function sServerStats:__init()

    self.stats = 
    {
        ["PlayersOnline"] = 0
    }

    Events:Subscribe("ClientModuleLoad", self, self.ClientModuleLoad)
    Events:Subscribe("PlayerQuit", self, self.PlayerQuit)

end

function sServerStats:ClientModuleLoad(args)
    self.stats["PlayersOnline"] = self.stats["PlayersOnline"] + 1
    self:RefreshOnlinePlayers()
end

function sServerStats:PlayerQuit(args)
    self.stats["PlayersOnline"] = self.stats["PlayersOnline"] - 1
    self:RefreshOnlinePlayers()
end

function sServerStats:RefreshOnlinePlayers()
    Network:Broadcast("ServerStats/UpdatePlayersOnline", {online = self.stats["PlayersOnline"]})
end

sServerStats = sServerStats()