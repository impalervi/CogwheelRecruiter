local addonName, NS = ...
NS = NS or {}

NS.WhispersInbox = NS.WhispersInbox or {}
local WhispersInbox = NS.WhispersInbox

function WhispersInbox.Create(context)
    context = context or {}

    local function HandleInboundWhisper(msg, sender)
        local getWhisperKey = context.getWhisperKey
        if not getWhisperKey then
            return false
        end

        local key = getWhisperKey(sender)
        local analyticsDB = context.getAnalyticsDB and context.getAnalyticsDB() or nil
        local hasTrackedOutbound = analyticsDB and analyticsDB.pendingWhispers and analyticsDB.pendingWhispers[key]
        local whispersDB = context.getWhispersDB and context.getWhispersDB() or nil

        if not (key and key ~= "" and ((whispersDB and whispersDB[key] and whispersDB[key].lastOutbound) or hasTrackedOutbound)) then
            return false
        end

        if whispersDB then
            whispersDB[key] = whispersDB[key] or {}
            whispersDB[key].lastInbound = msg
            whispersDB[key].lastInboundTime = time()
            whispersDB[key].sender = sender

            local getShortName = context.getShortName
            if getShortName then
                whispersDB[key].displayName = whispersDB[key].displayName or getShortName(sender)
            else
                whispersDB[key].displayName = whispersDB[key].displayName or sender
            end
        end

        if context.recordWhisperAnswered then
            context.recordWhisperAnswered(sender)
        end

        local currentTab = context.getCurrentTab and context.getCurrentTab() or nil
        if currentTab ~= 6 then
            if context.startWhispersTabFlash then
                context.startWhispersTabFlash()
            end
        elseif context.updateWhispersList then
            context.updateWhispersList()
        end

        return true
    end

    return {
        HandleInboundWhisper = HandleInboundWhisper,
    }
end

