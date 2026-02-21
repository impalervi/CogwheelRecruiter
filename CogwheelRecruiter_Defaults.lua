local addonName, NS = ...
NS = NS or {}

function NS.EnsureDatabases()
    if CogwheelRecruiterHistoryDB == nil then CogwheelRecruiterHistoryDB = {} end
    if CogwheelRecruiterSettingsDB == nil then CogwheelRecruiterSettingsDB = {} end
    if CogwheelRecruiterWhispersDB == nil then CogwheelRecruiterWhispersDB = {} end
    return CogwheelRecruiterHistoryDB, CogwheelRecruiterSettingsDB, CogwheelRecruiterWhispersDB
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
        settingsDB.whisperTemplate = "Hi <character>, would you like to join <guild>, a friendly and supportive community while you continue your adventure leveling up?"
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

