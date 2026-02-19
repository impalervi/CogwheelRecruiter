local addonName, NS = ...
NS = NS or {}

function NS.EnsureDatabases()
    if NoGuildHistoryDB == nil then NoGuildHistoryDB = {} end
    if NoGuildSettingsDB == nil then NoGuildSettingsDB = {} end
    return NoGuildHistoryDB, NoGuildSettingsDB
end

function NS.ApplyDefaultSettings(settingsDB, classList)
    if not settingsDB.minLevel then settingsDB.minLevel = 1 end
    if not settingsDB.maxLevel then settingsDB.maxLevel = 80 end

    if not settingsDB.classes then settingsDB.classes = {} end
    for _, cls in ipairs(classList or {}) do
        if settingsDB.classes[cls] == nil then settingsDB.classes[cls] = true end
    end

    if not settingsDB.stats then settingsDB.stats = { invited = 0, joined = 0 } end
    if not settingsDB.historyRetentionDays then settingsDB.historyRetentionDays = 1 end
    if not settingsDB.minimapPos then settingsDB.minimapPos = 45 end
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
