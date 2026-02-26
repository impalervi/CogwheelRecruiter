local addonName, NS = ...
NS = NS or {}

function NS.EnsureDatabases()
    if CogwheelRecruiterHistoryDB == nil then CogwheelRecruiterHistoryDB = {} end
    if CogwheelRecruiterSettingsDB == nil then CogwheelRecruiterSettingsDB = {} end
    if CogwheelRecruiterWhispersDB == nil then CogwheelRecruiterWhispersDB = {} end
    if CogwheelRecruiterAnalyticsDB == nil then CogwheelRecruiterAnalyticsDB = {} end
    return CogwheelRecruiterHistoryDB, CogwheelRecruiterSettingsDB, CogwheelRecruiterWhispersDB, CogwheelRecruiterAnalyticsDB
end

function NS.GetLevelCategoryName(level, zoneCategories)
    local lvl = tonumber(level) or 0
    for _, cat in ipairs(zoneCategories or NS.ZONE_CATEGORIES or {}) do
        if cat.min and cat.max and cat.min > 0 and lvl >= cat.min and lvl <= cat.max then
            return cat.name
        end
    end
    return "Other"
end

function NS.EnsureAnalyticsDefaults(analyticsDB, classList, zoneCategories)
    if not analyticsDB then return end

    analyticsDB.whispered = tonumber(analyticsDB.whispered) or 0
    analyticsDB.whispersAnswered = tonumber(analyticsDB.whispersAnswered) or 0
    analyticsDB.invited = tonumber(analyticsDB.invited) or 0
    analyticsDB.accepted = tonumber(analyticsDB.accepted) or 0
    analyticsDB.invitesByClass = analyticsDB.invitesByClass or {}
    analyticsDB.acceptedByClass = analyticsDB.acceptedByClass or {}
    analyticsDB.invitesByLevel = analyticsDB.invitesByLevel or {}
    analyticsDB.acceptedByLevel = analyticsDB.acceptedByLevel or {}
    analyticsDB.pendingWhispers = analyticsDB.pendingWhispers or {}
    analyticsDB.pendingInvites = analyticsDB.pendingInvites or {}

    for _, cls in ipairs(classList or NS.CLASS_LIST or {}) do
        analyticsDB.invitesByClass[cls] = tonumber(analyticsDB.invitesByClass[cls]) or 0
        analyticsDB.acceptedByClass[cls] = tonumber(analyticsDB.acceptedByClass[cls]) or 0
    end

    local levelKeys = { Other = true }
    analyticsDB.invitesByLevel.Other = tonumber(analyticsDB.invitesByLevel.Other) or 0
    analyticsDB.acceptedByLevel.Other = tonumber(analyticsDB.acceptedByLevel.Other) or 0

    for _, cat in ipairs(zoneCategories or NS.ZONE_CATEGORIES or {}) do
        if cat.min and cat.max and cat.min > 0 and cat.name and cat.name ~= "" then
            levelKeys[cat.name] = true
            analyticsDB.invitesByLevel[cat.name] = tonumber(analyticsDB.invitesByLevel[cat.name]) or 0
            analyticsDB.acceptedByLevel[cat.name] = tonumber(analyticsDB.acceptedByLevel[cat.name]) or 0
        end
    end

    for key in pairs(analyticsDB.invitesByLevel) do
        if not levelKeys[key] then
            analyticsDB.invitesByLevel[key] = tonumber(analyticsDB.invitesByLevel[key]) or 0
        end
    end

    for key in pairs(analyticsDB.acceptedByLevel) do
        if not levelKeys[key] then
            analyticsDB.acceptedByLevel[key] = tonumber(analyticsDB.acceptedByLevel[key]) or 0
        end
    end
end

function NS.ApplyDefaultSettings(settingsDB, classList)
    if not settingsDB.minLevel then settingsDB.minLevel = 1 end
    if not settingsDB.maxLevel then settingsDB.maxLevel = 70 end

    if not settingsDB.classes then settingsDB.classes = {} end
    for _, cls in ipairs(classList or {}) do
        if settingsDB.classes[cls] == nil then settingsDB.classes[cls] = true end
    end

    if not settingsDB.stats then settingsDB.stats = { invited = 0, joined = 0 } end
    if not settingsDB.historyRetentionDays then settingsDB.historyRetentionDays = 1 end
    if not settingsDB.minimapPos then settingsDB.minimapPos = 45 end
    if not settingsDB.whisperTemplate then
        settingsDB.whisperTemplate = "Hi <character>, would you like to join <guild>, a friendly and supportive community, while you continue your adventure leveling up?"
    end
    if settingsDB.autoWelcomeEnabled == nil then settingsDB.autoWelcomeEnabled = false end
    if not settingsDB.welcomeTemplate then
        settingsDB.welcomeTemplate = "Welcome to <guild>, <character>!"
    end
end

function NS.PruneHistory(historyDB, retentionDays)
    local days = tonumber(retentionDays) or 1
    local cutoff = time() - (days * 86400)
    for name, data in pairs(historyDB or {}) do
        if type(data) ~= "table" or type(data.time) ~= "number" or data.time < cutoff then
            historyDB[name] = nil
        end
    end
end
