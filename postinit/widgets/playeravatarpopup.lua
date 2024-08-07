GLOBAL.setfenv(1, GLOBAL)

local PlayerAvatarPopup = require("widgets/playeravatarpopup")

local _Layout = PlayerAvatarPopup.Layout
-- 审视自我界面，第二个参数为真时，会显示玩家Steam主页按钮，反之隐藏
function PlayerAvatarPopup:Layout(data, show_net_profile)
    return _Layout(self, data, false) -- don't show Steam profile
end
