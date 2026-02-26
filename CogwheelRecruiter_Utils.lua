local addonName, NS = ...
NS = NS or {}

NS.Utils = NS.Utils or {}
local Utils = NS.Utils

function Utils.GetShortName(name)
    if not name then
        return ""
    end
    return (name:match("^[^-]+") or name)
end

function Utils.GetWhisperKey(name)
    return Utils.GetShortName(name)
end

function Utils.NormalizeClassName(classToken)
    if not classToken or classToken == "" then
        return "Adventurer"
    end

    local upper = string.upper(classToken)
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[upper] then
        return LOCALIZED_CLASS_NAMES_MALE[upper]
    end
    if LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[upper] then
        return LOCALIZED_CLASS_NAMES_FEMALE[upper]
    end
    return upper:sub(1, 1) .. upper:sub(2):lower()
end

function Utils.ApplyTemplateTokens(template, targetName, targetClass, guildName)
    local msg = template or ""
    local short = Utils.GetShortName(targetName)
    local resolvedGuild = guildName or "our guild"
    local className = Utils.NormalizeClassName(targetClass)

    msg = msg:gsub("<character>", short)
    msg = msg:gsub("{character}", short)
    msg = msg:gsub("<guild>", resolvedGuild)
    msg = msg:gsub("{guild}", resolvedGuild)
    msg = msg:gsub("<class>", className)
    msg = msg:gsub("{class}", className)

    return msg
end

function Utils.BuildWhisperMessage(template, targetName, targetClass, guildName)
    return Utils.ApplyTemplateTokens(template or "Hi <character>!", targetName, targetClass, guildName)
end

function Utils.BuildWelcomeMessage(template, targetName, guildName)
    local msg = template or "Welcome to <guild>, <character>!"
    local short = Utils.GetShortName(targetName)
    local resolvedGuild = guildName or "our guild"

    msg = msg:gsub("<character>", short)
    msg = msg:gsub("{character}", short)
    msg = msg:gsub("<guild>", resolvedGuild)
    msg = msg:gsub("{guild}", resolvedGuild)
    return msg
end

function Utils.CountWords(text)
    local count = 0
    for _ in string.gmatch(text or "", "%S+") do
        count = count + 1
    end
    return count
end

function Utils.FormatRate(accepted, invited)
    local inv = tonumber(invited) or 0
    local acc = tonumber(accepted) or 0
    if inv <= 0 then
        return "n/a"
    end
    return string.format("%.1f%%", (acc / inv) * 100)
end

function Utils.FindExtremes(keys, invitesBy, acceptedBy, labelFn, formatRateFn)
    local bestKey, bestRate = nil, -1
    local worstKey, worstRate = nil, 2

    for _, key in ipairs(keys or {}) do
        local invites = tonumber((invitesBy or {})[key]) or 0
        local accepted = tonumber((acceptedBy or {})[key]) or 0
        if invites > 0 then
            local rate = accepted / invites
            if rate > bestRate then
                bestRate = rate
                bestKey = key
            end
            if rate < worstRate then
                worstRate = rate
                worstKey = key
            end
        end
    end

    if not bestKey then
        return "No invite data yet.", "No invite data yet."
    end

    local labelFor = labelFn or function(k) return k end
    local formatRate = formatRateFn or Utils.FormatRate

    local bestLabel = labelFor(bestKey)
    local worstLabel = labelFor(worstKey)
    local bestText = string.format("%s (%s)", bestLabel, formatRate(tonumber((acceptedBy or {})[bestKey]) or 0, tonumber((invitesBy or {})[bestKey]) or 0))
    local worstText = string.format("%s (%s)", worstLabel, formatRate(tonumber((acceptedBy or {})[worstKey]) or 0, tonumber((invitesBy or {})[worstKey]) or 0))
    return bestText, worstText
end
