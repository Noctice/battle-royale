GLOBAL.setfenv(1, GLOBAL)

local _GenerateChatMessage = ChatHistory.GenerateChatMessage
function ChatHistory:GenerateChatMessage(type, sender_userid, sender_netid, sender_name, message, colour, icondata, whisper, localonly, text_filter_context)
    if sender_userid then -- sender_userid can be nil
        sender_name = TheNet:GetClientTableForUser(sender_userid).name
    end

    return _GenerateChatMessage(self, type, sender_userid, sender_netid, sender_name, message, WHITE, icondata, whisper, localonly, text_filter_context)
end
