local addonName, NS = ...
NS = NS or {}

NS.GuildReports = NS.GuildReports or {}
local GuildReports = NS.GuildReports

GuildReports._ctx = GuildReports._ctx or {}

function GuildReports.SetContext(ctx)
    GuildReports._ctx = ctx or {}
end

local function GetActiveWindowDays()
    local getter = GuildReports._ctx and GuildReports._ctx.getActiveWindowDays
    if getter then
        return tonumber(getter()) or 7
    end
    return 7
end

local function GetZoneCategories()
    local getter = GuildReports._ctx and GuildReports._ctx.getZoneCategories
    if getter then
        return getter() or {}
    end
    return NS.ZONE_CATEGORIES or {}
end

local function IsDebugOnSelf()
    local getter = GuildReports._ctx and GuildReports._ctx.getDebugOnSelf
    if getter then
        return getter() and true or false
    end
    return false
end

local function GetSelfPlayerName()
    local getter = GuildReports._ctx and GuildReports._ctx.getSelfPlayerName
    if getter then
        local name = getter()
        if name and name ~= "" then
            return name
        end
    end
    return UnitName("player")
end

local function SendGuildReportLine(msg)
    if not msg or msg == "" then
        return
    end

    local chatType = "GUILD"
    local targetName = nil
    if IsDebugOnSelf() then
        chatType = "WHISPER"
        targetName = GetSelfPlayerName()
        if not targetName or targetName == "" then
            return
        end
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType, nil, targetName)
    else
        SendChatMessage(msg, chatType, nil, targetName)
    end
end

function GuildReports.GetGuildClassCounts()
    local numMembers = GetNumGuildMembers()
    local counts = {}
    local total = 0
    local activeWindowDays = GetActiveWindowDays()

    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, online, _, classFileName = GetGuildRosterInfo(i)
        if name then
            local active = online
            if not active then
                local y, m, d = GetGuildRosterLastOnline(i)
                if y and (y == 0 and m == 0 and d <= activeWindowDays) then
                    active = true
                end
            end

            if active and classFileName then
                counts[classFileName] = (counts[classFileName] or 0) + 1
                total = total + 1
            end
        end
    end

    return counts, total
end

function GuildReports.GetGuildLevelCounts()
    local numMembers = GetNumGuildMembers()
    local counts = {}
    local total = 0
    local activeWindowDays = GetActiveWindowDays()
    local zoneCategories = GetZoneCategories()

    for i = 1, numMembers do
        local name, _, _, level, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            local active = online
            if not active then
                local y, m, d = GetGuildRosterLastOnline(i)
                if y and (y == 0 and m == 0 and d <= activeWindowDays) then
                    active = true
                end
            end

            if active and level then
                local found = false
                for _, cat in ipairs(zoneCategories) do
                    if cat.min and cat.max and cat.min > 0 then
                        if level >= cat.min and level <= cat.max then
                            counts[cat.name] = (counts[cat.name] or 0) + 1
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    counts["Other"] = (counts["Other"] or 0) + 1
                end
                total = total + 1
            end
        end
    end

    return counts, total
end

function GuildReports.BuildDistributionLines(header, segments)
    local lines = { header }
    local activeWindowDays = GetActiveWindowDays()

    if #segments == 0 then
        table.insert(lines, string.format("No active members found in the past %d days.", activeWindowDays))
        return lines
    end

    local maxLen = 240
    local current = ""
    for _, seg in ipairs(segments) do
        if current == "" then
            current = seg
        elseif string.len(current) + 2 + string.len(seg) <= maxLen then
            current = current .. "; " .. seg
        else
            table.insert(lines, current)
            current = seg
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end

    return lines
end

function GuildReports.SendDistributionReportToGuild(header, segments)
    local lines = GuildReports.BuildDistributionLines(header, segments)
    for _, line in ipairs(lines) do
        SendGuildReportLine(line)
    end
end

function GuildReports.BuildClassDistributionSegments()
    local counts, total = GuildReports.GetGuildClassCounts()
    local sorted = {}
    for cls, count in pairs(counts) do
        table.insert(sorted, { cls = cls, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local segments = {}
    for _, item in ipairs(sorted) do
        local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[item.cls]) or
            (item.cls:sub(1, 1) .. item.cls:sub(2):lower())
        local pct = (total > 0) and math.floor((item.count / total) * 100 + 0.5) or 0
        table.insert(segments, string.format("%s: %d (%d%%)", label, item.count, pct))
    end

    return segments, total
end

function GuildReports.BuildLevelDistributionSegments()
    local counts, total = GuildReports.GetGuildLevelCounts()
    local segments = {}
    local zoneCategories = GetZoneCategories()

    for _, cat in ipairs(zoneCategories) do
        if cat.min and cat.max and cat.min > 0 then
            local count = counts[cat.name] or 0
            local pct = (total > 0) and math.floor((count / total) * 100 + 0.5) or 0
            table.insert(segments, string.format("%s: %d (%d%%)", cat.name, count, pct))
        end
    end

    local otherCount = counts["Other"] or 0
    if otherCount > 0 then
        local pct = (total > 0) and math.floor((otherCount / total) * 100 + 0.5) or 0
        table.insert(segments, string.format("Other: %d (%d%%)", otherCount, pct))
    end

    return segments, total
end
