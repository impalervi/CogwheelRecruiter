local addonName, NS = ...
NS = NS or {}

NS.SettingsStatsGuildController = NS.SettingsStatsGuildController or {}
local SettingsStatsGuildController = NS.SettingsStatsGuildController

function SettingsStatsGuildController.Create(context)
    context = context or {}

    local settingsView = context.settingsView
    local filtersView = context.filtersView
    local statsView = context.statsView
    local guildStatsView = context.guildStatsView

    if not (settingsView and filtersView and statsView and guildStatsView) then
        return nil
    end

    local guildReports = context.guildReports or {}

    local getGuildClassCounts = guildReports.GetGuildClassCounts or function()
        return {}, 0
    end

    local getGuildLevelCounts = guildReports.GetGuildLevelCounts or function()
        return {}, 0
    end

    local buildClassDistributionSegments = guildReports.BuildClassDistributionSegments or function()
        return {}, 0
    end

    local buildLevelDistributionSegments = guildReports.BuildLevelDistributionSegments or function()
        return {}, 0
    end

    local sendDistributionReportToGuild = guildReports.SendDistributionReportToGuild or function() end

    local guildViewAPI = nil
    if NS.GuildView and NS.GuildView.Create then
        guildViewAPI = NS.GuildView.Create({
            parent = guildStatsView,
            getActiveWindowDays = context.getActiveWindowDays,
            getZoneCategories = context.getZoneCategories,
            getGuildClassCounts = getGuildClassCounts,
            getGuildLevelCounts = getGuildLevelCounts,
            buildClassDistributionSegments = buildClassDistributionSegments,
            buildLevelDistributionSegments = buildLevelDistributionSegments,
            sendDistributionReportToGuild = sendDistributionReportToGuild,
            requestGuildRoster = context.requestGuildRoster,
            print = context.print,
        })
    end

    local updateGuildStats = function()
        if guildViewAPI and guildViewAPI.Update then
            guildViewAPI.Update()
        end
    end

    guildStatsView:RegisterEvent("GUILD_ROSTER_UPDATE")
    guildStatsView:SetScript("OnEvent", function()
        updateGuildStats()
    end)

    local statsViewAPI = nil
    if NS.StatsView and NS.StatsView.Create then
        statsViewAPI = NS.StatsView.Create({
            parent = statsView,
            getAnalyticsDB = context.getAnalyticsDB,
            ensureAnalyticsDefaults = context.ensureAnalyticsDefaults,
            getClassList = context.getClassList,
            getZoneCategories = context.getZoneCategories,
            normalizeClassName = context.normalizeClassName,
            formatRate = context.formatRate,
            findExtremes = context.findExtremes,
        })
    end

    local updateStatsView = function()
        if statsViewAPI and statsViewAPI.Update then
            statsViewAPI.Update()
        end
    end

    local settingsFiltersViewAPI = nil
    if NS.SettingsFiltersView and NS.SettingsFiltersView.Create then
        settingsFiltersViewAPI = NS.SettingsFiltersView.Create({
            settingsView = settingsView,
            filtersView = filtersView,
            getSettingsDB = context.getSettingsDB,
            getClassList = context.getClassList,
            getZoneCategories = context.getZoneCategories,
            getMaxPlayerLevel = context.getMaxPlayerLevel,
            maxWhisperChars = context.maxWhisperChars,
            normalizeClassName = context.normalizeClassName,
            buildWhisperPreview = context.buildWhisperPreview,
            buildWelcomePreview = context.buildWelcomePreview,
            requestGuildRoster = context.requestGuildRoster,
            getGuildClassCounts = getGuildClassCounts,
            getGuildLevelCounts = getGuildLevelCounts,
            onSaveFilters = context.onSaveFilters,
            print = context.print,
        })
    end

    if settingsFiltersViewAPI then
        NS.RefreshLevelRangeText = settingsFiltersViewAPI.RefreshLevelRangeText
        NS.InitializeLevelSlidersFromSettings = settingsFiltersViewAPI.InitializeLevelSlidersFromSettings
        NS.RefreshHistoryRetentionUI = settingsFiltersViewAPI.RefreshHistoryRetentionUI
        NS.CreateSliderTrack = settingsFiltersViewAPI.CreateSliderTrack
        NS.CreateLevelBadge = settingsFiltersViewAPI.CreateLevelBadge
    end

    return {
        UpdateGuildStats = updateGuildStats,
        UpdateStatsView = updateStatsView,
    }
end
