GLOBAL.setfenv(1, GLOBAL)

local PlayerStatusScreen = require("screens/playerstatusscreen")

-- 游戏内看到的玩家列表
local _DoInit = PlayerStatusScreen.DoInit
function PlayerStatusScreen:DoInit(...)
    _DoInit(self, ...)

    local _UpdatePlayerListing = self.scroll_list.updatefn
    self.scroll_list.updatefn = function(playerListing, client, i)
        _UpdatePlayerListing(playerListing, client, i)
        if not TheNet:GetIsServerAdmin() then -- 非管理员
            playerListing.adminBadge:Hide() -- 隐藏管理员图标
        end
    end
    self.scroll_list:RefreshView(false) -- 刷新图标
end
