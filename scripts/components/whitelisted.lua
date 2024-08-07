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

    local function OnPlayerJoined(player)
        if IsPlayerWhitelisted(player) then
            return
        end

        local user_table = TheNet:GetClientTableForUser(player.userid)
        c_announce(string.format("%s(%s) 不在白名单上, 踢出", user_table._actual_name, user_table.userid))
        print("角色:", STRINGS.NAMES[string.upper(user_table.prefab)],"Steam用户名:", user_table._actual_name,
            "Steam ID:", user_table.netid, "KUID:", user_table.userid)
        TheNet:Ban(player.userid)
    end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------
    for _, player in pairs(AllPlayers) do
        OnPlayerJoined(player)
    end

    local mt = {
        __newindex = function(t, k, v)
            OnPlayerJoined(v) -- __newindex 元方法会在列表添加元素时调用
        end
    }

    setmetatable(AllPlayers, mt)
end)