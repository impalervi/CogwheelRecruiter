local addonName, NS = ...
NS = NS or {}

NS.Messaging = NS.Messaging or {}
local Messaging = NS.Messaging

Messaging._ctx = Messaging._ctx or {}

function Messaging.SetContext(ctx)
    Messaging._ctx = ctx or {}
end

local function IsDebugOnSelf()
    local getter = Messaging._ctx and Messaging._ctx.getDebugOnSelf
    if getter then
        return getter() and true or false
    end
    return false
end

local function GetSelfPlayerName()
    local getter = Messaging._ctx and Messaging._ctx.getSelfPlayerName
    if getter then
        local name = getter()
        if name and name ~= "" then
            return name
        end
    end
    return UnitName("player")
end

function Messaging.BuildWhisperMessage(template, targetName, targetClass, guildName)
    if NS.Utils and NS.Utils.BuildWhisperMessage then
        return NS.Utils.BuildWhisperMessage(template, targetName, targetClass, guildName)
    end
    return template or ""
end

function Messaging.BuildWelcomeMessage(template, targetName, guildName)
    if NS.Utils and NS.Utils.BuildWelcomeMessage then
        return NS.Utils.BuildWelcomeMessage(template, targetName, guildName)
    end
    return template or ""
end

function Messaging.ResolveWhisperTarget(targetName)
    if IsDebugOnSelf() then
        local selfName = GetSelfPlayerName()
        if selfName and selfName ~= "" then
            return selfName
        end
    end
    return targetName
end

function Messaging.SendWhisperMessage(msg, targetName)
    local whisperTarget = Messaging.ResolveWhisperTarget(targetName)

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, whisperTarget)
    else
        SendChatMessage(msg, "WHISPER", nil, whisperTarget)
    end

    return whisperTarget
end

function Messaging.SendDelayedWelcomeMessage(opts)
    opts = opts or {}

    local settingsDB = opts.settingsDB
    local targetName = opts.targetName
    local maxWhisperChars = tonumber(opts.maxWhisperChars) or 255
    local buildWelcomeMessage = opts.buildWelcomeMessage or function() return "" end
    local printFn = opts.print or print
    local delaySeconds = tonumber(opts.delaySeconds) or 2

    if not (C_Timer and C_Timer.After) then
        return false
    end

    C_Timer.After(delaySeconds, function()
        if not settingsDB or not settingsDB.autoWelcomeEnabled then
            return
        end

        local welcomeMsg = buildWelcomeMessage(targetName)
        if string.len(welcomeMsg) > maxWhisperChars then
            printFn(string.format("|cffff0000[Cogwheel]|r Welcome message too long (%d/%d). Shorten it in Settings.", string.len(welcomeMsg), maxWhisperChars))
            return
        end

        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage(welcomeMsg, "GUILD")
        else
            SendChatMessage(welcomeMsg, "GUILD")
        end
    end)

    return true
end

function Messaging.SendWhisperToPlayer(opts)
    opts = opts or {}

    local targetName = opts.targetName
    local targetClass = opts.targetClass
    local maxWhisperChars = tonumber(opts.maxWhisperChars) or 255
    local buildWhisperMessage = opts.buildWhisperMessage or function() return "" end
    local printFn = opts.print or print

    local whispersDB = opts.whispersDB
    local getWhisperKey = opts.getWhisperKey or function(name) return name end
    local getShortName = opts.getShortName or function(name) return name end
    local recordWhisperSent = opts.recordWhisperSent

    local handleInboundWhisper = opts.handleInboundWhisper
    local debugReply = opts.debugReply or "[debug] Thanks for the message!"

    local msg = buildWhisperMessage(targetName, targetClass)
    if string.len(msg) > maxWhisperChars then
        printFn(string.format("|cffff0000[Cogwheel]|r Whisper too long (%d/%d). Shorten your template in Settings.", string.len(msg), maxWhisperChars))
        return false
    end

    Messaging.SendWhisperMessage(msg, targetName)

    if whispersDB then
        local key = getWhisperKey(targetName)
        whispersDB[key] = whispersDB[key] or {}
        whispersDB[key].displayName = getShortName(targetName)
        whispersDB[key].lastOutbound = msg
        whispersDB[key].lastOutboundTime = time()
    end

    if recordWhisperSent then
        recordWhisperSent(targetName)
    end

    if IsDebugOnSelf() and targetName and targetName ~= "" and handleInboundWhisper then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.35, function()
                handleInboundWhisper(debugReply, targetName)
            end)
        else
            handleInboundWhisper(debugReply, targetName)
        end
    end

    return true
end
