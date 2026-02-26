local addonName, NS = ...
NS = NS or {}

NS.Scanner = NS.Scanner or {}
local Scanner = NS.Scanner

function Scanner.NewRuntimeState()
    return {
        isScanning = false,
        isWaitingForWho = false,
        scanQueue = {},
        currentScanZone = "",
        accumulatedResults = {},
    }
end

local function ParseWhoEntry(index, fallbackZone)
    local info
    if C_FriendList and C_FriendList.GetWhoInfo then
        info = C_FriendList.GetWhoInfo(index)
    end

    local name, guild, level, cls, zone
    if type(info) == "table" then
        name = info.fullName or info.name
        guild = info.fullGuildName or info.guild or ""
        level = info.level or 0
        cls = info.filename or info.classFilename or "PRIEST"
        zone = info.area or fallbackZone
    else
        if C_FriendList and C_FriendList.GetWhoInfo then
            name, guild, level, _, _, zone, cls = C_FriendList.GetWhoInfo(index)
        end
        if not name and GetWhoInfo then
            name, guild, level, _, _, zone, cls = GetWhoInfo(index)
        end
        if not guild then guild = "" end
        if not cls or cls == "" then cls = "PRIEST" end
        if not zone or zone == "" then zone = fallbackZone end
    end

    return {
        name = name,
        guild = guild,
        level = level or 0,
        class = string.upper(cls or "PRIEST"),
        zone = zone,
    }
end

function Scanner.GetZonesToScan(selectedSpecificZone, fallbackZone)
    local zones = {}

    if selectedSpecificZone and selectedSpecificZone ~= "" then
        table.insert(zones, selectedSpecificZone)
        return zones
    end

    if fallbackZone and fallbackZone ~= "" then
        table.insert(zones, fallbackZone)
    end

    return zones
end

function Scanner.BeginScan(state, zones)
    if not state then
        return false
    end

    state.scanQueue = {}
    for _, zone in ipairs(zones or {}) do
        if zone and zone ~= "" then
            table.insert(state.scanQueue, zone)
        end
    end

    if #state.scanQueue == 0 then
        return false
    end

    state.isScanning = true
    state.isWaitingForWho = false
    state.currentScanZone = ""
    state.accumulatedResults = {}
    return true
end

function Scanner.PopNextZone(state)
    if not state or #(state.scanQueue or {}) == 0 then
        return nil
    end

    state.currentScanZone = table.remove(state.scanQueue, 1)
    return state.currentScanZone
end

function Scanner.OnWhoEventComplete(state, settingsDB, maxPlayerLevel)
    if not state then
        return {
            hasMore = false,
            nextZone = nil,
            totalCount = 0,
            visibleCount = 0,
        }
    end

    state.isWaitingForWho = false

    local hasMore = #(state.scanQueue or {}) > 0
    if hasMore then
        return {
            hasMore = true,
            nextZone = state.scanQueue[1],
        }
    end

    state.isScanning = false
    local totalCount = #(state.accumulatedResults or {})
    local visibleCount = Scanner.CountVisibleResults(state.accumulatedResults, settingsDB, maxPlayerLevel)

    return {
        hasMore = false,
        nextZone = nil,
        totalCount = totalCount,
        visibleCount = visibleCount,
    }
end

function Scanner.OnWhoTimeout(state)
    if not state then
        return { timedOut = false }
    end
    if not state.isWaitingForWho then
        return { timedOut = false }
    end

    state.isWaitingForWho = false
    local hasMore = #(state.scanQueue or {}) > 0
    if not hasMore then
        state.isScanning = false
    end

    return {
        timedOut = true,
        hasMore = hasMore,
        nextZone = hasMore and state.scanQueue[1] or nil,
    }
end

function Scanner.CollectWhoResults(accumulatedResults, fallbackZone)
    accumulatedResults = accumulatedResults or {}

    local num = 0
    if C_FriendList and C_FriendList.GetNumWhoResults then
        num = C_FriendList.GetNumWhoResults() or 0
    elseif GetNumWhoResults then
        num = GetNumWhoResults() or 0
    end

    local seenNames = {}
    for _, existing in ipairs(accumulatedResults) do
        if existing and existing.name and existing.name ~= "" then
            seenNames[existing.name] = true
        end
    end

    local added = 0
    for i = 1, num do
        local entry = ParseWhoEntry(i, fallbackZone)
        local hasNoGuild = (entry.guild or "") == ""
        local hasName = entry.name and entry.name ~= ""

        if hasNoGuild and hasName and not seenNames[entry.name] then
            seenNames[entry.name] = true
            table.insert(accumulatedResults, {
                name = entry.name,
                level = entry.level,
                class = entry.class,
                zone = entry.zone,
            })
            added = added + 1
        end
    end

    return added
end

function Scanner.CountVisibleResults(results, settingsDB, maxPlayerLevel)
    local visibleCount = 0
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or (maxPlayerLevel or 70)
    local classes = settingsDB and settingsDB.classes

    for _, data in ipairs(results or {}) do
        local classTag = data and data.class
        local classAllowed = classes and classes[classTag]
        if classAllowed == nil then
            classAllowed = true
        end

        local lvl = data and data.level or 0
        if lvl >= minLvl and lvl <= maxLvl and classAllowed then
            visibleCount = visibleCount + 1
        end
    end

    return visibleCount
end

