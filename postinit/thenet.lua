GLOBAL.setfenv(1, GLOBAL)

-- ziwbi: 查看玩家主頁的接口
function NetworkProxy.ViewNetProfile()
    -- do nothing
end

-- ziwbi: 加入服务器宣告，改为匿名
function Networking_JoinAnnouncement(name, colour)
    Networking_Announcement(string.format(STRINGS.UI.NOTIFICATION.JOINEDGAME, STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME), colour, "join_game")
end

-- 离开，改动同上
function Networking_LeaveAnnouncement(name, colour)
    Networking_Announcement(string.format(STRINGS.UI.NOTIFICATION.LEFTGAME, STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME), colour, "leave_game")
end

local function anonymise_data(client)
    if not client then
        return
    end

    local base_skin = client.base_skin -- NetworkProxy
    local display_name = STRINGS.SKIN_NAMES[base_skin]
    if base_skin and not base_skin:find("_none") then -- 有 _none 代表无皮肤，角色名等于皮肤名
        display_name = display_name .. " " .. (STRINGS.NAMES[string.upper(client.prefab)] or STRINGS.CHARACTER_NAMES.unknown) -- 加上角色名
    end

    client.name = display_name
    client.equip = {}
end

local _GetClientTable = NetworkProxy.GetClientTable
function NetworkProxy:GetClientTable()
    local data = _GetClientTable(self)
    for k, client in ipairs(data) do
        anonymise_data(client)
    end
    return data
end

local _GetClientTableForUser = NetworkProxy.GetClientTableForUser
function NetworkProxy:GetClientTableForUser(userid)
    local client = _GetClientTableForUser(self, userid)
    anonymise_data(client)
    return client
end
