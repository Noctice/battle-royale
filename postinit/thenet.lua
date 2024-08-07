GLOBAL.setfenv(1, GLOBAL)

local TheNet_index = getmetatable(TheNet).__index

-- ziwbi: 查看玩家主頁的接口
function TheNet_index.ViewNetProfile()
    -- do nothing
end

-- ziwbi 加入服务器宣告，改为匿名
function Networking_JoinAnnouncement(name, colour)
    Networking_Announcement(string.format(STRINGS.UI.NOTIFICATION.JOINEDGAME, STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME), colour, "join_game")
end

-- 离开，改动同上
function Networking_LeaveAnnouncement(name, colour)
    Networking_Announcement(string.format(STRINGS.UI.NOTIFICATION.LEFTGAME, STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME), colour, "leave_game")
end
