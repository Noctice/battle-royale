--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

require("whitelist")

--------------------------------------------------------------------------
--[[ WhiteListed class definition ]]
--------------------------------------------------------------------------
return Class(function(self, inst)

    assert(TheWorld.ismastersim, "WhiteListed should not exist on client")

--------------------------------------------------------------------------
--[[ Public Member Variables ]]
--------------------------------------------------------------------------

    self.inst = inst

--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

    local function OnPlayerJoined(src, player)
        if IsPlayerWhitelisted(player) then
            return
        end

        c_announce(string.format("%s 不在白名单上, 踢出", player.userid))
        TheNet:Ban(player.userid)
    end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------
    for _, player in pairs(AllPlayers) do
        OnPlayerJoined(nil, player)
    end

    self.inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
end)