local addonName, NS = ...
NS = NS or {}

NS.QuickScanner = NS.QuickScanner or {}
local QuickScanner = NS.QuickScanner

local LOW_LEVEL_ZONE_FACTION = {
    ["Elwynn Forest"] = "Alliance",
    ["Dun Morogh"] = "Alliance",
    ["Teldrassil"] = "Alliance",
    ["Azuremyst Isle"] = "Alliance",
    ["Westfall"] = "Alliance",
    ["Loch Modan"] = "Alliance",
    ["Redridge Mountains"] = "Alliance",
    ["Bloodmyst Isle"] = "Alliance",

    ["Durotar"] = "Horde",
    ["Mulgore"] = "Horde",
    ["Tirisfal Glades"] = "Horde",
    ["Eversong Woods"] = "Horde",
    ["The Barrens"] = "Horde",
    ["Silverpine Forest"] = "Horde",
    ["Ghostlands"] = "Horde",
}

local CITY_ZONE_FACTION = {
    ["Stormwind City"] = "Alliance",
    ["Ironforge"] = "Alliance",
    ["Darnassus"] = "Alliance",
    ["The Exodar"] = "Alliance",

    ["Orgrimmar"] = "Horde",
    ["Undercity"] = "Horde",
    ["Thunder Bluff"] = "Horde",
    ["Silvermoon City"] = "Horde",

    ["Shattrath City"] = "Neutral",
}

local START_ZONE_ROTATION_WINDOW = 8

local function GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or maxPlayerLevel or 70
    return minLvl, maxLvl
end

function QuickScanner.NewState(queueTarget)
    return {
        isScanning = false,
        isWaitingForWho = false,
        scanQueue = {},
        currentScanZone = "",
        queue = {},
        seenNames = {},
        scannedZones = 0,
        totalZones = 0,
        refillTarget = queueTarget or 10,
        currentCandidate = nil,
        quietZones = 0,
        maxQuietZones = 0,
        filterSignature = nil,
        nextLevelBucket = 1,
        lastStartOffset = -1,
    }
end

function QuickScanner.MatchesFilters(settingsDB, level, classToken, maxPlayerLevel)
    local minLvl, maxLvl = GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local lvl = level or 0
    if lvl < minLvl or lvl > maxLvl then
        return false
    end

    local classTag = string.upper(classToken or "PRIEST")
    local classAllowed = settingsDB and settingsDB.classes and settingsDB.classes[classTag]
    if classAllowed == nil then
        classAllowed = true
    end
    return classAllowed
end

function QuickScanner.BuildFilterSignature(settingsDB, classList, maxPlayerLevel)
    local minLvl, maxLvl = GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local parts = { tostring(minLvl), tostring(maxLvl) }

    for _, cls in ipairs(classList or {}) do
        local enabled = settingsDB and settingsDB.classes and settingsDB.classes[cls]
        if enabled == nil then
            enabled = true
        end
        parts[#parts + 1] = enabled and "1" or "0"
    end

    return table.concat(parts, ":")
end

function QuickScanner.GetPlayerFactionGroup()
    if not UnitFactionGroup then
        return nil
    end

    local faction = UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        return faction
    end

    return nil
end

function QuickScanner.ShouldSkipZone(zone, minLvl, maxLvl, playerFaction)
    local cityFaction = CITY_ZONE_FACTION[zone]
    if cityFaction and cityFaction ~= "Neutral" and playerFaction and cityFaction ~= playerFaction then
        return true
    end

    local zoneFaction = LOW_LEVEL_ZONE_FACTION[zone]
    if zoneFaction and playerFaction and zoneFaction ~= playerFaction and maxLvl <= 30 then
        return true
    end

    return false
end

function QuickScanner.GetZoneFactionPriority(zone, category, playerFaction, maxLvl)
    local cityFaction = CITY_ZONE_FACTION[zone]
    if cityFaction then
        if cityFaction == "Neutral" then
            return 1
        end
        if playerFaction and cityFaction == playerFaction then
            return 0
        end
        return 3
    end

    local catMin = tonumber(category.min) or 0
    local catMax = tonumber(category.max) or 0
    local zoneFaction = LOW_LEVEL_ZONE_FACTION[zone]

    if catMin > 0 and catMax <= 30 and zoneFaction and playerFaction then
        if zoneFaction == playerFaction then
            return 0
        end
        if maxLvl > 30 then
            return 2
        end
        return 3
    end

    return 1
end
function QuickScanner.SortZoneBucket(bucket, kind)
    table.sort(bucket, function(a, b)
        if kind == "inRange" then
            if a.distance ~= b.distance then
                return a.distance < b.distance
            end
            if a.anchor ~= b.anchor then
                return a.anchor < b.anchor
            end
            return (a.cat.name or "") < (b.cat.name or "")
        elseif kind == "aboveRange" then
            if a.min ~= b.min then
                return a.min < b.min
            end
            if a.anchor ~= b.anchor then
                return a.anchor < b.anchor
            end
            return (a.cat.name or "") < (b.cat.name or "")
        elseif kind == "belowRange" then
            if a.max ~= b.max then
                return a.max > b.max
            end
            if a.anchor ~= b.anchor then
                return a.anchor > b.anchor
            end
            return (a.cat.name or "") < (b.cat.name or "")
        end

        if a.anchor == b.anchor then
            return (a.cat.name or "") < (b.cat.name or "")
        end
        return a.anchor < b.anchor
    end)
end

function QuickScanner.BuildZoneQueue(settingsDB, zoneCategories, maxPlayerLevel)
    local minLvl, maxLvl = GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local filterCenter = (minLvl + maxLvl) / 2

    local inRange = {}
    local aboveRange = {}
    local belowRange = {}
    local misc = {}

    for _, cat in ipairs(zoneCategories or {}) do
        if cat.zones and #cat.zones > 0 then
            local minCat = tonumber(cat.min) or 0
            local maxCat = tonumber(cat.max) or 0
            local hasLevelRange = minCat > 0 and maxCat > 0
            local anchor = hasLevelRange and ((minCat + maxCat) / 2) or 999
            local overlaps = hasLevelRange and maxCat >= minLvl and minCat <= maxLvl

            local entry = {
                cat = cat,
                anchor = anchor,
                min = minCat,
                max = maxCat,
                distance = math.abs(anchor - filterCenter),
                overlaps = overlaps,
            }

            if hasLevelRange then
                if overlaps then
                    table.insert(inRange, entry)
                elseif minCat > maxLvl then
                    table.insert(aboveRange, entry)
                else
                    table.insert(belowRange, entry)
                end
            else
                table.insert(misc, entry)
            end
        end
    end

    QuickScanner.SortZoneBucket(inRange, "inRange")
    QuickScanner.SortZoneBucket(belowRange, "belowRange")
    QuickScanner.SortZoneBucket(aboveRange, "aboveRange")
    QuickScanner.SortZoneBucket(misc, "misc")

    local orderedEntries = {}
    for _, entry in ipairs(inRange) do table.insert(orderedEntries, entry) end
    for _, entry in ipairs(belowRange) do table.insert(orderedEntries, entry) end
    for _, entry in ipairs(aboveRange) do table.insert(orderedEntries, entry) end
    for _, entry in ipairs(misc) do table.insert(orderedEntries, entry) end

    local zones = {}
    local preferredCount = 0
    local seenZones = {}
    local playerFaction = QuickScanner.GetPlayerFactionGroup()

    for _, catEntry in ipairs(orderedEntries) do
        local cat = catEntry.cat
        local overlapsFilter = catEntry.overlaps == true
        local zoneEntries = {}

        for index, zone in ipairs(cat.zones) do
            if not QuickScanner.ShouldSkipZone(zone, minLvl, maxLvl, playerFaction) then
                table.insert(zoneEntries, {
                    zone = zone,
                    index = index,
                    priority = QuickScanner.GetZoneFactionPriority(zone, cat, playerFaction, maxLvl),
                })
            end
        end

        table.sort(zoneEntries, function(a, b)
            if a.priority ~= b.priority then
                return a.priority < b.priority
            end
            return a.index < b.index
        end)

        for _, entry in ipairs(zoneEntries) do
            local zone = entry.zone
            if not seenZones[zone] then
                seenZones[zone] = true
                table.insert(zones, zone)
                if overlapsFilter then
                    preferredCount = preferredCount + 1
                end
            end
        end
    end

    return zones, preferredCount
end

function QuickScanner.RotateZoneQueue(queue, offset)
    local queueSize = #queue
    if queueSize <= 1 then
        return queue
    end

    local shift = (offset or 0) % queueSize
    if shift == 0 then
        return queue
    end

    local rotated = {}
    for i = 1, queueSize do
        local sourceIndex = ((i + shift - 1) % queueSize) + 1
        rotated[i] = queue[sourceIndex]
    end
    return rotated
end

function QuickScanner.ResetZoneQueue(state, settingsDB, zoneCategories, classList, maxPlayerLevel)
    if not state then
        return
    end

    local preferredCount = 0
    state.scanQueue, preferredCount = QuickScanner.BuildZoneQueue(settingsDB, zoneCategories, maxPlayerLevel)
    local scanQueueSize = #state.scanQueue
    if scanQueueSize > 1 then
        local preferredWindowCount = (preferredCount and preferredCount > 0) and preferredCount or scanQueueSize
        local rotationWindow = math.min(preferredWindowCount, START_ZONE_ROTATION_WINDOW)
        local startOffset = math.random(0, rotationWindow - 1)
        if rotationWindow > 1 and startOffset == state.lastStartOffset then
            startOffset = (startOffset + 1) % rotationWindow
        end
        state.lastStartOffset = startOffset
        state.scanQueue = QuickScanner.RotateZoneQueue(state.scanQueue, startOffset)
    end
    state.scannedZones = 0
    state.totalZones = #state.scanQueue
    state.seenNames = {}
    state.filterSignature = QuickScanner.BuildFilterSignature(settingsDB, classList, maxPlayerLevel)
end

function QuickScanner.ResetStateForFilterChange(state, settingsDB, zoneCategories, classList, maxPlayerLevel, queueTarget)
    if not state then
        return
    end

    state.isScanning = false
    state.isWaitingForWho = false
    state.currentScanZone = ""
    state.queue = {}
    state.currentCandidate = nil
    state.quietZones = 0
    state.maxQuietZones = 0
    state.nextLevelBucket = 1
    state.refillTarget = queueTarget or state.refillTarget or 10

    QuickScanner.ResetZoneQueue(state, settingsDB, zoneCategories, classList, maxPlayerLevel)
end

function QuickScanner.EnsureStateMatchesFilters(state, settingsDB, zoneCategories, classList, maxPlayerLevel, queueTarget)
    local currentSignature = QuickScanner.BuildFilterSignature(settingsDB, classList, maxPlayerLevel)
    if state and state.filterSignature == currentSignature then
        return false
    end

    QuickScanner.ResetStateForFilterChange(state, settingsDB, zoneCategories, classList, maxPlayerLevel, queueTarget)
    return true
end

function QuickScanner.PopNextZone(state, settingsDB, zoneCategories, classList, maxPlayerLevel)
    if not state then
        return nil
    end

    if #state.scanQueue == 0 then
        QuickScanner.ResetZoneQueue(state, settingsDB, zoneCategories, classList, maxPlayerLevel)
    end
    if #state.scanQueue == 0 then
        return nil
    end

    state.currentScanZone = table.remove(state.scanQueue, 1)
    state.scannedZones = (state.scannedZones or 0) + 1
    return state.currentScanZone
end

function QuickScanner.IsCandidateInQueue(state, name)
    if not state or not name or name == "" then
        return false
    end

    if state.currentCandidate and state.currentCandidate.name == name then
        return true
    end

    for _, entry in ipairs(state.queue or {}) do
        if entry.name == name then
            return true
        end
    end

    return false
end

function QuickScanner.GetLevelBucketCount(settingsDB, maxPlayerLevel, bucketLimit)
    local minLvl, maxLvl = GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local span = math.max((maxLvl - minLvl + 1), 1)
    local limit = bucketLimit or 1
    return math.max(math.min(limit, span), 1)
end

function QuickScanner.GetLevelBucketIndex(level, settingsDB, maxPlayerLevel, bucketLimit)
    local minLvl, maxLvl = GetMinMaxLevel(settingsDB, maxPlayerLevel)
    local bucketCount = QuickScanner.GetLevelBucketCount(settingsDB, maxPlayerLevel, bucketLimit)
    if bucketCount <= 1 or maxLvl <= minLvl then
        return 1, bucketCount
    end

    local span = math.max((maxLvl - minLvl + 1), 1)
    local relative = (level or minLvl) - minLvl
    if relative < 0 then relative = 0 end
    if relative > (span - 1) then relative = span - 1 end

    local idx = math.floor((relative * bucketCount) / span) + 1
    if idx < 1 then idx = 1 end
    if idx > bucketCount then idx = bucketCount end

    return idx, bucketCount
end

function QuickScanner.PromoteNextCandidate(state, settingsDB, maxPlayerLevel, bucketLimit)
    if not state then
        return nil
    end

    local queue = state.queue or {}
    local queueCount = #queue
    if queueCount == 0 then
        state.currentCandidate = nil
        return nil
    end

    local bucketCount = QuickScanner.GetLevelBucketCount(settingsDB, maxPlayerLevel, bucketLimit)
    if (state.nextLevelBucket or 0) < 1 or state.nextLevelBucket > bucketCount then
        state.nextLevelBucket = 1
    end

    local selectedIndex
    for offset = 0, bucketCount - 1 do
        local targetBucket = ((state.nextLevelBucket + offset - 1) % bucketCount) + 1
        for i, entry in ipairs(queue) do
            local bucket = QuickScanner.GetLevelBucketIndex(entry.level or 0, settingsDB, maxPlayerLevel, bucketLimit)
            if bucket == targetBucket then
                selectedIndex = i
                state.nextLevelBucket = (targetBucket % bucketCount) + 1
                break
            end
        end
        if selectedIndex then
            break
        end
    end

    if not selectedIndex then
        selectedIndex = 1
    end

    state.currentCandidate = table.remove(queue, selectedIndex)
    return state.currentCandidate
end

function QuickScanner.GetCandidateCount(state)
    if not state then
        return 0
    end

    local queueCount = #(state.queue or {})
    return queueCount + (state.currentCandidate and 1 or 0)
end

function QuickScanner.FinishRefill(state, settingsDB, maxPlayerLevel, bucketLimit)
    if not state then
        return
    end

    state.isScanning = false
    state.isWaitingForWho = false
    if not state.currentCandidate and #(state.queue or {}) > 0 then
        QuickScanner.PromoteNextCandidate(state, settingsDB, maxPlayerLevel, bucketLimit)
    end
end

function QuickScanner.RequestQueueRefill(state, opts)
    opts = opts or {}
    if not state then
        return { blocked = true }
    end

    if state.isScanning then
        return { blocked = true }
    end

    local settingsDB = opts.settingsDB
    local zoneCategories = opts.zoneCategories
    local classList = opts.classList
    local maxPlayerLevel = opts.maxPlayerLevel
    local queueTarget = opts.queueTarget or 10
    local queueMax = opts.queueMax or 20
    local emptyZoneStreakCap = opts.emptyZoneStreakCap or 8
    local bucketLimit = opts.bucketLimit or 4

    local filtersChanged = QuickScanner.EnsureStateMatchesFilters(
        state,
        settingsDB,
        zoneCategories,
        classList,
        maxPlayerLevel,
        queueTarget
    )

    if opts.standardScanInProgress then
        return {
            blocked = true,
            filtersChanged = filtersChanged,
            blockedByStandardScan = true,
        }
    end

    local target = opts.targetCount or queueTarget
    if QuickScanner.GetCandidateCount(state) >= target then
        if not state.currentCandidate then
            QuickScanner.PromoteNextCandidate(state, settingsDB, maxPlayerLevel, bucketLimit)
        end
        return {
            ready = true,
            filtersChanged = filtersChanged,
        }
    end

    if #(state.scanQueue or {}) == 0 then
        QuickScanner.ResetZoneQueue(state, settingsDB, zoneCategories, classList, maxPlayerLevel)
    end

    if #(state.scanQueue or {}) == 0 then
        return {
            noZones = true,
            filtersChanged = filtersChanged,
        }
    end

    state.refillTarget = math.min(target, queueMax)
    state.isScanning = true
    state.isWaitingForWho = false
    state.quietZones = 0
    state.maxQuietZones = math.max(1, math.min(math.max(state.totalZones or 1, 1) * 2, emptyZoneStreakCap))

    return {
        started = true,
        filtersChanged = filtersChanged,
    }
end

function QuickScanner.CollectWhoResults(state, settingsDB, maxPlayerLevel, queueMax, historyDB)
    if not state then
        return 0
    end

    local added = 0
    local num = 0
    if C_FriendList and C_FriendList.GetNumWhoResults then
        num = C_FriendList.GetNumWhoResults() or 0
    elseif GetNumWhoResults then
        num = GetNumWhoResults() or 0
    end

    for i = 1, num do
        local info = C_FriendList and C_FriendList.GetWhoInfo and C_FriendList.GetWhoInfo(i)
        local name, guild, level, cls, zone

        if type(info) == "table" then
            name = info.fullName or info.name
            guild = info.fullGuildName or info.guild or ""
            level = info.level or 0
            cls = info.filename or info.classFilename or "PRIEST"
            zone = info.area or state.currentScanZone
        else
            if C_FriendList and C_FriendList.GetWhoInfo then
                name, guild, level, _, _, zone, cls = C_FriendList.GetWhoInfo(i)
            end
            if not name and GetWhoInfo then
                name, guild, level, _, _, zone, cls = GetWhoInfo(i)
            end
            if not guild then guild = "" end
        end

        if guild == "" and name and QuickScanner.MatchesFilters(settingsDB, level or 0, cls, maxPlayerLevel)
            and not state.seenNames[name]
            and not QuickScanner.IsCandidateInQueue(state, name) then
            local history = historyDB and historyDB[name]
            if not (history and history.action == "JOINED") then
                state.seenNames[name] = true
                table.insert(state.queue, {
                    name = name,
                    level = level or 0,
                    class = string.upper(cls or "PRIEST"),
                    zone = zone or state.currentScanZone,
                })
                added = added + 1
                if #state.queue >= (queueMax or 20) then
                    break
                end
            end
        end
    end

    return added
end
