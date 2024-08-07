GLOBAL.setfenv(1, GLOBAL)

function ChatHistory:GetDisplayName(name, prefab)
    return prefab ~= "" and STRINGS.NAMES[string.upper(prefab)] or STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME
end
