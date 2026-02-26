local addonName, NS = ...
NS = NS or {}

NS.Bootstrap = NS.Bootstrap or {}
local Bootstrap = NS.Bootstrap

function Bootstrap.Create(context)
    context = context or {}

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, event, arg1)
        if event ~= "ADDON_LOADED" or arg1 ~= context.addonName then
            return
        end

        local historyDB, settingsDB, whispersDB, analyticsDB

        if context.ensureDatabases then
            historyDB, settingsDB, whispersDB, analyticsDB = context.ensureDatabases()
        else
            if CogwheelRecruiterHistoryDB == nil then CogwheelRecruiterHistoryDB = {} end
            if CogwheelRecruiterSettingsDB == nil then CogwheelRecruiterSettingsDB = {} end
            if CogwheelRecruiterWhispersDB == nil then CogwheelRecruiterWhispersDB = {} end
            if CogwheelRecruiterAnalyticsDB == nil then CogwheelRecruiterAnalyticsDB = {} end
            historyDB = CogwheelRecruiterHistoryDB
            settingsDB = CogwheelRecruiterSettingsDB
            whispersDB = CogwheelRecruiterWhispersDB
            analyticsDB = CogwheelRecruiterAnalyticsDB
        end

        if context.applyDefaultSettings then
            context.applyDefaultSettings(settingsDB, context.classList or {})
        else
            local maxPlayerLevel = tonumber(context.maxPlayerLevel) or 70
            if not settingsDB.minLevel then settingsDB.minLevel = 1 end
            if not settingsDB.maxLevel then settingsDB.maxLevel = maxPlayerLevel end
            if not settingsDB.classes then settingsDB.classes = {} end
            for _, cls in ipairs(context.classList or {}) do
                if settingsDB.classes[cls] == nil then settingsDB.classes[cls] = true end
            end
            if not settingsDB.stats then settingsDB.stats = { invited = 0, joined = 0 } end
            if not settingsDB.historyRetentionDays then settingsDB.historyRetentionDays = 1 end
            if not settingsDB.minimapPos then settingsDB.minimapPos = 45 end
            if not settingsDB.whisperTemplate then
                settingsDB.whisperTemplate = context.defaultWhisperTemplate or "Hi <character>!"
            end
            if settingsDB.autoWelcomeEnabled == nil then settingsDB.autoWelcomeEnabled = false end
            if not settingsDB.welcomeTemplate then
                settingsDB.welcomeTemplate = context.defaultWelcomeTemplate or "Welcome to <guild>, <character>!"
            end
        end

        if context.getDebugResetWelcomeOnLoad and context.getDebugResetWelcomeOnLoad() then
            settingsDB.splashSeen = false
        end

        if not analyticsDB then
            CogwheelRecruiterAnalyticsDB = CogwheelRecruiterAnalyticsDB or {}
            analyticsDB = CogwheelRecruiterAnalyticsDB
        end

        if context.onDatabasesReady then
            context.onDatabasesReady(historyDB, settingsDB, whispersDB, analyticsDB)
        end

        if context.ensureAnalyticsDefaults then
            context.ensureAnalyticsDefaults()
        end

        if context.updateMinimapPosition then
            context.updateMinimapPosition()
        end

        if context.print then
            context.print(string.format(
                "|cffC8A04A[Cogwheel Recruiter]|r v%s by |cff69CCF0Marviy|r @ Nightslayer. Type /cogwheel to start.",
                tostring(context.addonVersion or "dev")
            ))
        end

        if context.pruneHistory then
            context.pruneHistory(historyDB, settingsDB.historyRetentionDays)
        else
            local cutoff = time() - ((tonumber(settingsDB.historyRetentionDays) or 1) * 86400)
            for name, data in pairs(historyDB or {}) do
                if type(data) ~= "table" or type(data.time) ~= "number" or data.time < cutoff then
                    historyDB[name] = nil
                end
            end
        end
    end)

    return frame
end
