-- =============================================================
-- 1. SETUP & VARIABLES
-- =============================================================
local addonName, NS = ...
NS = NS or {}

addonName = addonName or "CogwheelRecruiter"
local historyDB -- Shortcut to CogwheelRecruiterHistoryDB
local settingsDB -- Shortcut to CogwheelRecruiterSettingsDB
local whispersDB -- Shortcut to CogwheelRecruiterWhispersDB
local analyticsDB -- Shortcut to CogwheelRecruiterAnalyticsDB
local UpdateMinimapPosition -- Forward declaration
local UpdateWhispersList -- Forward declaration
local UpdateHistoryList -- Forward declaration
local UpdateTabButtons -- Forward declaration
local UpdateStatsView -- Forward declaration
local UpdateGuildStats -- Forward declaration
local Analytics -- Forward declaration
local GuildReports -- Forward declaration
local Permissions -- Forward declaration
local Messaging -- Forward declaration
local QuickScannerEngine -- Forward declaration
local ScannerEngine -- Forward declaration
local Utils -- Forward declaration
local StartWhispersTabFlash -- Forward declaration
local StopWhispersTabFlash -- Forward declaration
local SetTab -- Forward declaration
local SetWelcomeMode -- Forward declaration
local ApplyMainLayoutForTab -- Forward declaration
local currentTab -- Forward declaration
local quickState -- Forward declaration
local ShowMainAddonWindow -- Forward declaration
local UpdateWelcomeState -- Forward declaration
local ShowAddonWindow -- Forward declaration
local OpenQuickScannerWindow -- Forward declaration
local ToggleAddonWindow -- Forward declaration
local MAX_WHISPER_CHARS = 255
local MAX_PLAYER_LEVEL = 70
local ACTIVE_MEMBER_WINDOW_DAYS = 7
local RECRUIT_PERMISSION_REQUIRED_TEXT = "Guild invite permission required."

local function GetAddonMeta(name, key)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, key)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(name, key)
    end
    return nil
end

local ADDON_TITLE = GetAddonMeta(addonName, "Title") or addonName
local ADDON_VERSION = GetAddonMeta(addonName, "Version") or "dev"
local ADDON_AUTHOR = "ImpalerV (Marviy @ Nightslayer)"
local ADDON_NOTES = GetAddonMeta(addonName, "Notes") or "Recruit new guild members with smart filters and personalized outreach."
local WELCOME_NOTES_DISPLAY = ADDON_NOTES:gsub(" and personalized outreach%.?", " and\npersonalized outreach")
local COLOR_HEADER_GOLD = "|cffFFD100"
local COLOR_FOOTER_GOLD = "|cffC89B3C"
local COLOR_DARK_RED = "|cff7A1F1F"
local COLOR_DARK_MAGE = "|cff2A86A0"
local COLOR_RESET = "|r"

local SPLASH_LOGO_CANDIDATES = {
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400.blp",
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400.tga",
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400.png",
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogo.blp",
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogo.tga",
    "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogo.png",
}
local DEBUG_ALWAYS_SHOW_WELCOME = false -- Keep false for normal first-launch welcome behavior
local DEBUG_ON_SELF = false -- TEMP DEBUG: route addon whispers/reports to self; MUST disable before merge
local DEBUG_RESET_WELCOME_ON_LOAD = false -- TEMP DEBUG: reset splash screen trigger on load; MUST disable before merge

local CLASS_LIST = NS.CLASS_LIST or {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

Utils = NS.Utils or {}
Analytics = NS.Analytics or {}
GuildReports = NS.GuildReports or {}
Permissions = NS.Permissions or {}
Messaging = NS.Messaging or {}
QuickScannerEngine = NS.QuickScanner or {}
ScannerEngine = NS.Scanner or {}

if Analytics.SetContext then
    Analytics.SetContext({
        getDB = function() return analyticsDB end,
        getClassList = function() return CLASS_LIST end,
        getZoneCategories = function() return NS.ZONE_CATEGORIES end,
        getLevelCategoryName = NS.GetLevelCategoryName,
    })
end

if GuildReports.SetContext then
    GuildReports.SetContext({
        getZoneCategories = function() return NS.ZONE_CATEGORIES end,
        getActiveWindowDays = function() return ACTIVE_MEMBER_WINDOW_DAYS end,
        getDebugOnSelf = function() return DEBUG_ON_SELF end,
        getSelfPlayerName = function() return UnitName("player") end,
    })
end

if Messaging.SetContext then
    Messaging.SetContext({
        getDebugOnSelf = function() return DEBUG_ON_SELF end,
        getSelfPlayerName = function() return UnitName("player") end,
    })
end

-- Create Main/Quick/Welcome frame shell
local frameShell = nil
if NS.FrameShell and NS.FrameShell.Create then
    frameShell = NS.FrameShell.Create({
        addonTitle = ADDON_TITLE,
        addonVersion = ADDON_VERSION,
        addonAuthor = ADDON_AUTHOR,
        colorHeaderGold = COLOR_HEADER_GOLD,
        colorFooterGold = COLOR_FOOTER_GOLD,
        colorDarkRed = COLOR_DARK_RED,
        colorDarkMage = COLOR_DARK_MAGE,
        colorReset = COLOR_RESET,
        splashLogoCandidates = SPLASH_LOGO_CANDIDATES,
        onSwitchToQuick = function()
            if SetTab then SetTab(8) end
        end,
        onSwitchToFull = function()
            if SetTab then SetTab(1) end
        end,
    })
end

local mainFrame = frameShell and frameShell.mainFrame or nil
local contentPanel = frameShell and frameShell.contentPanel or nil
local footerFrame = frameShell and frameShell.footerFrame or nil
local quickFrame = frameShell and frameShell.quickFrame or nil
local welcomeFrame = frameShell and frameShell.welcomeFrame or nil
local welcomeStartBtn = frameShell and frameShell.welcomeStartBtn or nil
local welcomeStatus = frameShell and frameShell.welcomeStatus or nil

if not (mainFrame and contentPanel and quickFrame and welcomeFrame and welcomeStartBtn and welcomeStatus) then
    error("CogwheelRecruiter frame shell initialization failed")
end

local FORCE_INVITE_PERMISSION_BYPASS = false -- TEMP DEBUG: bypass invite-permission check; MUST disable before merge

if Permissions.SetContext then
    Permissions.SetContext({
        getInviteBypass = function() return FORCE_INVITE_PERMISSION_BYPASS end,
    })
end

local function PlayerHasGuild()
    if Permissions.PlayerHasGuild then
        return Permissions.PlayerHasGuild()
    end
    local guildName = GetGuildInfo("player")
    return guildName ~= nil and guildName ~= ""
end

local function RawPlayerCanInviteGuildMembers()
    if Permissions.RawPlayerCanInviteGuildMembers then
        return Permissions.RawPlayerCanInviteGuildMembers()
    end
    return false
end

local function PlayerCanInviteGuildMembers()
    if Permissions.PlayerCanInviteGuildMembers then
        return Permissions.PlayerCanInviteGuildMembers()
    end
    if FORCE_INVITE_PERMISSION_BYPASS then
        return true
    end
    return RawPlayerCanInviteGuildMembers()
end

local function PlayerCanRecruitNow()
    if Permissions.PlayerCanRecruitNow then
        return Permissions.PlayerCanRecruitNow()
    end
    return PlayerHasGuild() and PlayerCanInviteGuildMembers()
end

local WindowRouting = NS.WindowRouting or {}
local windowRouter = nil
if WindowRouting.Create then
    windowRouter = WindowRouting.Create({
        mainFrame = mainFrame,
        quickFrame = quickFrame,
        welcomeFrame = welcomeFrame,
        welcomeStartBtn = welcomeStartBtn,
        welcomeStatus = welcomeStatus,
        playerCanInviteGuildMembers = PlayerCanInviteGuildMembers,
        getSettingsDB = function() return settingsDB end,
        getCurrentTab = function() return currentTab end,
        setTab = function(id) SetTab(id) end,
        getSetWelcomeMode = function() return SetWelcomeMode end,
        getDebugAlwaysShowWelcome = function() return DEBUG_ALWAYS_SHOW_WELCOME end,
        welcomeNotesDisplay = WELCOME_NOTES_DISPLAY,
        addonVersion = ADDON_VERSION,
    })
end

ShowMainAddonWindow = function(forceScanner)
    if not (windowRouter and windowRouter.ShowMainAddonWindow) then return end
    windowRouter.ShowMainAddonWindow(forceScanner)
end

UpdateWelcomeState = function(forceScanner)
    if not (windowRouter and windowRouter.UpdateWelcomeState) then return end
    windowRouter.UpdateWelcomeState(forceScanner)
end

ShowAddonWindow = function(forceScanner)
    if not (windowRouter and windowRouter.ShowAddonWindow) then return end
    windowRouter.ShowAddonWindow(forceScanner)
end

OpenQuickScannerWindow = function()
    if not (windowRouter and windowRouter.OpenQuickScannerWindow) then return end
    windowRouter.OpenQuickScannerWindow()
end

ToggleAddonWindow = function()
    if not (windowRouter and windowRouter.ToggleAddonWindow) then return end
    windowRouter.ToggleAddonWindow()
end

welcomeStartBtn:SetScript("OnClick", function()
    if not (windowRouter and windowRouter.OnWelcomeStartClicked) then return end
    windowRouter.OnWelcomeStartClicked()
end)
local bootstrapFrame = nil
if NS.Bootstrap and NS.Bootstrap.Create then
    bootstrapFrame = NS.Bootstrap.Create({
        addonName = addonName,
        ensureDatabases = NS.EnsureDatabases,
        applyDefaultSettings = NS.ApplyDefaultSettings,
        pruneHistory = NS.PruneHistory,
        classList = CLASS_LIST,
        maxPlayerLevel = MAX_PLAYER_LEVEL,
        defaultWhisperTemplate = "Hi <character>, would you like to join <guild>, a friendly and supportive community, while you continue your adventure leveling up?",
        defaultWelcomeTemplate = "Welcome to <guild>, <character>!",
        getDebugResetWelcomeOnLoad = function() return DEBUG_RESET_WELCOME_ON_LOAD end,
        onDatabasesReady = function(h, s, w, a)
            historyDB = h
            settingsDB = s
            whispersDB = w
            analyticsDB = a
        end,
        ensureAnalyticsDefaults = function()
            if Analytics and Analytics.EnsureDefaults then
                Analytics.EnsureDefaults()
            end
        end,
        updateMinimapPosition = function()
            if UpdateMinimapPosition then
                UpdateMinimapPosition()
            end
        end,
        addonVersion = ADDON_VERSION,
        print = print,
    })
end
-- =============================================================
-- 2. ZONE DATA (Structured for New UI)
-- =============================================================
local ZONE_CATEGORIES = NS.ZONE_CATEGORIES or {
    {
        name = "Starter Zones (1-15)",
        zones = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Azuremyst Isle", "Durotar", "Mulgore", "Tirisfal Glades", "Eversong Woods"},
        min = 1, max = 15, color = {r=0.8, g=0.8, b=0.8}
    },
    {
        name = "Early Game (15-30)",
        zones = {"The Barrens", "Westfall", "Redridge Mountains", "Duskwood", "Loch Modan", "Wetlands", "Ashenvale", "Stonetalon Mountains", "Hillsbrad Foothills", "Silverpine Forest", "Ghostlands", "Bloodmyst Isle"},
        min = 15, max = 30, color = {r=0.1, g=0.8, b=0.1}
    },
    {
        name = "Mid-Game (30-50)",
        zones = {"Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Stranglethorn Vale", "Badlands", "Swamp of Sorrows", "Dustwallow Marsh", "Desolace", "Arathi Highlands", "Alterac Mountains", "Thousand Needles"},
        min = 30, max = 50, color = {r=0.1, g=0.5, b=1.0}
    },
    {
        name = "Endgame Azeroth (50-60)",
        zones = {"Eastern Plaguelands", "Western Plaguelands", "Silithus", "Winterspring", "Burning Steppes", "Searing Gorge", "Un'Goro Crater", "Felwood", "Azshara", "Deadwind Pass", "Blasted Lands"},
        min = 50, max = 60, color = {r=0.6, g=0.2, b=0.8}
    },
    {
        name = "Outland (58-70)",
        zones = {"Hellfire Peninsula", "Zangarmarsh", "Terokkar Forest", "Nagrand", "Blade's Edge Mountains", "Netherstorm", "Shadowmoon Valley", "Isle of Quel'Danas"},
        min = 58, max = 70, color = {r=1.0, g=0.5, b=0.0}
    },
    {
        name = "Major Cities",
        zones = {"Orgrimmar", "Stormwind City", "Ironforge", "Undercity", "Darnassus", "Thunder Bluff", "Silvermoon City", "The Exodar", "Shattrath City"},
        min = 0, max = 0, color = {r=0.5, g=0.5, b=0.5}
    }
}

-- Selection State
local SelectedSpecificZone = nil

local function GetShortName(name)
    if Utils.GetShortName then
        return Utils.GetShortName(name)
    end
    if not name then return "" end
    return (name:match("^[^-]+") or name)
end

local function GetWhisperKey(name)
    if Utils.GetWhisperKey then
        return Utils.GetWhisperKey(name)
    end
    return GetShortName(name)
end

local function NormalizeClassName(classToken)
    if Utils.NormalizeClassName then
        return Utils.NormalizeClassName(classToken)
    end
    if not classToken or classToken == "" then return "Adventurer" end
    local upper = string.upper(classToken)
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[upper] then
        return LOCALIZED_CLASS_NAMES_MALE[upper]
    end
    if LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[upper] then
        return LOCALIZED_CLASS_NAMES_FEMALE[upper]
    end
    return upper:sub(1, 1) .. upper:sub(2):lower()
end

local function BuildWhisperMessage(targetName, targetClass)
    local tmpl = (settingsDB and settingsDB.whisperTemplate) or "Hi <character>!"
    local guildName = GetGuildInfo("player") or "our guild"
    if Messaging.BuildWhisperMessage then
        return Messaging.BuildWhisperMessage(tmpl, targetName, targetClass, guildName)
    end
    if Utils.BuildWhisperMessage then
        return Utils.BuildWhisperMessage(tmpl, targetName, targetClass, guildName)
    end
    return tmpl
end

local function BuildWelcomeMessage(targetName)
    local tmpl = (settingsDB and settingsDB.welcomeTemplate) or "Welcome to <guild>, <character>!"
    local guildName = GetGuildInfo("player") or "our guild"
    if Messaging.BuildWelcomeMessage then
        return Messaging.BuildWelcomeMessage(tmpl, targetName, guildName)
    end
    if Utils.BuildWelcomeMessage then
        return Utils.BuildWelcomeMessage(tmpl, targetName, guildName)
    end
    return tmpl
end

local function SendDelayedWelcomeMessage(targetName)
    if Messaging.SendDelayedWelcomeMessage then
        Messaging.SendDelayedWelcomeMessage({
            targetName = targetName,
            settingsDB = settingsDB,
            maxWhisperChars = MAX_WHISPER_CHARS,
            buildWelcomeMessage = BuildWelcomeMessage,
            print = print,
            delaySeconds = 2,
        })
    end
end

local function SendWhisperToPlayer(targetName, targetClass)
    if Messaging.SendWhisperToPlayer then
        return Messaging.SendWhisperToPlayer({
            targetName = targetName,
            targetClass = targetClass,
            maxWhisperChars = MAX_WHISPER_CHARS,
            buildWhisperMessage = BuildWhisperMessage,
            print = print,
            whispersDB = whispersDB,
            getWhisperKey = GetWhisperKey,
            getShortName = GetShortName,
            recordWhisperSent = Analytics.RecordWhisperSent,
            handleInboundWhisper = NS.HandleInboundWhisper,
            debugReply = "[debug] Thanks for the message!",
        })
    end
    return false
end

-- =============================================================
-- 3. TABS SETUP
-- =============================================================
currentTab = 1

local scanView = CreateFrame("Frame", nil, mainFrame)
scanView:SetAllPoints(contentPanel)

local historyView = CreateFrame("Frame", nil, mainFrame)
historyView:SetAllPoints(contentPanel)
historyView:Hide()

local settingsView = CreateFrame("Frame", nil, mainFrame)
settingsView:SetAllPoints(contentPanel)
settingsView:Hide()

local filtersView = CreateFrame("Frame", nil, mainFrame)
filtersView:SetAllPoints(contentPanel)
filtersView:Hide()

local statsView = CreateFrame("Frame", nil, mainFrame)
statsView:SetAllPoints(contentPanel)
statsView:Hide()

local guildStatsView = CreateFrame("Frame", nil, mainFrame)
guildStatsView:SetAllPoints(contentPanel)
guildStatsView:Hide()

local whispersView = CreateFrame("Frame", nil, mainFrame)
whispersView:SetAllPoints(contentPanel)
whispersView:Hide()

local quickView = CreateFrame("Frame", nil, quickFrame)
quickView:SetAllPoints(quickFrame.contentPanel)
quickView:Hide()

local settingsStatsGuildController = nil
if NS.SettingsStatsGuildController and NS.SettingsStatsGuildController.Create then
    settingsStatsGuildController = NS.SettingsStatsGuildController.Create({
        settingsView = settingsView,
        filtersView = filtersView,
        statsView = statsView,
        guildStatsView = guildStatsView,
        guildReports = GuildReports,
        getActiveWindowDays = function() return ACTIVE_MEMBER_WINDOW_DAYS end,
        getZoneCategories = function() return ZONE_CATEGORIES end,
        requestGuildRoster = function()
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
        end,
        print = print,
        getAnalyticsDB = function() return analyticsDB end,
        ensureAnalyticsDefaults = function()
            if Analytics.EnsureDefaults then
                Analytics.EnsureDefaults()
            end
        end,
        getClassList = function() return CLASS_LIST end,
        normalizeClassName = NormalizeClassName,
        formatRate = Utils.FormatRate,
        findExtremes = Utils.FindExtremes,
        getSettingsDB = function() return settingsDB end,
        getMaxPlayerLevel = function() return MAX_PLAYER_LEVEL end,
        maxWhisperChars = MAX_WHISPER_CHARS,
        buildWhisperPreview = BuildWhisperMessage,
        buildWelcomePreview = BuildWelcomeMessage,
        onSaveFilters = function()
            if NS.ResetQuickScanState then
                NS.ResetQuickScanState()
            end
            local returnTab = NS.filterReturnTab
            if returnTab ~= 8 then returnTab = 1 end
            SetTab(returnTab)
        end,
    })
end

if not settingsStatsGuildController then
    error("CogwheelRecruiter settings/stats/guild controller initialization failed")
end

UpdateGuildStats = function()
    if settingsStatsGuildController and settingsStatsGuildController.UpdateGuildStats then
        settingsStatsGuildController.UpdateGuildStats()
    end
end

UpdateStatsView = function()
    if settingsStatsGuildController and settingsStatsGuildController.UpdateStatsView then
        settingsStatsGuildController.UpdateStatsView()
    end
end
local tabShellController = nil
if NS.TabShellController and NS.TabShellController.Create then
    tabShellController = NS.TabShellController.Create({
        mainFrame = mainFrame,
        quickFrame = quickFrame,
        welcomeFrame = welcomeFrame,
        contentPanel = contentPanel,
        footerFrame = footerFrame,
        views = {
            scanView = scanView,
            quickView = quickView,
            historyView = historyView,
            settingsView = settingsView,
            filtersView = filtersView,
            statsView = statsView,
            guildStatsView = guildStatsView,
            whispersView = whispersView,
        },
        getCurrentTab = function() return currentTab end,
        setCurrentTab = function(id) currentTab = id end,
        onSetFilterReturnTab = function(id) NS.filterReturnTab = id end,
        onShowHistory = function()
            if UpdateHistoryList then
                UpdateHistoryList()
            end
        end,
        onShowStats = function()
            if UpdateStatsView then
                UpdateStatsView()
            end
        end,
        onShowGuild = function()
            if UpdateGuildStats then
                UpdateGuildStats()
            end
            if C_GuildInfo and C_GuildInfo.GuildRoster then
                C_GuildInfo.GuildRoster()
            elseif GuildRoster then
                GuildRoster()
            end
        end,
        onShowWhispers = function()
            if StopWhispersTabFlash then
                StopWhispersTabFlash()
            end
            if UpdateWhispersList then
                UpdateWhispersList()
            end
        end,
    })
end

if not tabShellController then
    error("CogwheelRecruiter tab shell initialization failed")
end

SetTab = function(id)
    if tabShellController and tabShellController.SetTab then
        tabShellController.SetTab(id)
    end
end

ApplyMainLayoutForTab = function(tabId)
    if tabShellController and tabShellController.ApplyMainLayoutForTab then
        tabShellController.ApplyMainLayoutForTab(tabId)
    end
end

SetWelcomeMode = function(enabled)
    if tabShellController and tabShellController.SetWelcomeMode then
        tabShellController.SetWelcomeMode(enabled)
    end
end

UpdateTabButtons = function()
    if tabShellController and tabShellController.UpdateTabButtons then
        tabShellController.UpdateTabButtons()
    end
end

StopWhispersTabFlash = function()
    if tabShellController and tabShellController.StopWhispersTabFlash then
        tabShellController.StopWhispersTabFlash()
    end
end

StartWhispersTabFlash = function()
    if tabShellController and tabShellController.StartWhispersTabFlash then
        tabShellController.StartWhispersTabFlash()
    end
end

UpdateTabButtons()

-- =============================================================
-- 4. RESULTS + QUICK SCANNER VIEWS
-- =============================================================

local QUICK_QUEUE_TARGET = 10
local QUICK_QUEUE_MAX = 20
local QUICK_LEVEL_BALANCE_BUCKETS = 4
local WHO_QUERY_TIMEOUT_SECONDS = 3.5
local QUICK_ZONE_TIMEOUT_SECONDS = WHO_QUERY_TIMEOUT_SECONDS
local QUICK_EMPTY_ZONE_STREAK_CAP = 8

local quickActionHandlers = {
    onNext = nil,
    onWhisper = nil,
    onInvite = nil,
}

local function OpenQuickFiltersPanel()
    local qx, qy = quickFrame:GetCenter()
    NS.filterReturnTab = 8
    SetTab(7)
    if qx and qy then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", qx + 360, qy)
    end
    quickFrame:Show()
    quickView:Show()
end

local function OpenQuickWhispersPanel()
    local qx, qy = quickFrame:GetCenter()
    SetTab(6)
    if qx and qy then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", qx + 360, qy)
    end
    quickFrame:Show()
    quickView:Show()
end

local scannerQuickViews = nil
if NS.ScannerQuickViewsController and NS.ScannerQuickViewsController.Create then
    scannerQuickViews = NS.ScannerQuickViewsController.Create({
        scanView = scanView,
        quickFrame = quickFrame,
        quickView = quickView,
        getZoneCategories = function() return ZONE_CATEGORIES end,
        getSelectedSpecificZone = function() return SelectedSpecificZone end,
        setSelectedSpecificZone = function(zoneName) SelectedSpecificZone = zoneName end,
        onStartScan = function()
            if StartScanSequence then
                StartScanSequence()
            end
        end,
        onOpenMainFilters = function()
            NS.filterReturnTab = 1
            SetTab(7)
        end,
        getSettingsDB = function() return settingsDB end,
        getHistoryDB = function() return historyDB end,
        getWhispersDB = function() return whispersDB end,
        getWhisperKey = GetWhisperKey,
        getMaxPlayerLevel = function() return MAX_PLAYER_LEVEL end,
        playerCanRecruit = PlayerCanRecruitNow,
        onPermissionDenied = function()
            print("|cffff0000[Cogwheel]|r " .. RECRUIT_PERMISSION_REQUIRED_TEXT)
        end,
        onScannerWhisper = function(data)
            local sent = SendWhisperToPlayer(data.name, data.class)
            if sent then
                print("|cff00ff00[Cogwheel]|r Whisper sent to " .. data.name)
            end
            return sent
        end,
        onScannerInvite = function(data, button)
            if C_GuildInfo and C_GuildInfo.Invite then
                C_GuildInfo.Invite(data.name)
            else
                GuildInvite(data.name)
            end

            if button then
                button:SetText("Sent")
                button:Disable()
            end

            historyDB[data.name] = {
                time = time(),
                action = "INVITED",
                class = string.upper(data.class or "PRIEST"),
                level = data.level
            }
            Analytics.RecordInviteSent(data.name, data.class, data.level)

            if settingsDB and settingsDB.stats then
                settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1
            end
        end,
        onOpenQuickFilters = OpenQuickFiltersPanel,
        onOpenQuickWhispers = OpenQuickWhispersPanel,
        onQuickNext = function()
            if quickActionHandlers.onNext then
                quickActionHandlers.onNext()
            end
        end,
        onQuickWhisper = function()
            if quickActionHandlers.onWhisper then
                quickActionHandlers.onWhisper()
            end
        end,
        onQuickInvite = function()
            if quickActionHandlers.onInvite then
                quickActionHandlers.onInvite()
            end
        end,
        getQuickState = function() return quickState end,
        scanWatermarkTexture = "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400",
    })
end

if not (scannerQuickViews and scannerQuickViews.scanBtn) then
    error("CogwheelRecruiter scanner/quick views initialization failed")
end

local scanBtn = scannerQuickViews.scanBtn

local function ClearScanView()
    if scannerQuickViews and scannerQuickViews.ClearScanView then
        scannerQuickViews.ClearScanView()
    end
end

local function UpdateScanList(results)
    if scannerQuickViews and scannerQuickViews.UpdateScanList then
        scannerQuickViews.UpdateScanList(results)
    end
end

local function UpdateQuickCandidateCard(statusText)
    if scannerQuickViews and scannerQuickViews.UpdateQuickCandidateCard then
        scannerQuickViews.UpdateQuickCandidateCard(statusText)
    end
end

if scannerQuickViews and scannerQuickViews.GetQuickWhispersTabButton and tabShellController and tabShellController.RegisterQuickWhispersButton then
    tabShellController.RegisterQuickWhispersButton(scannerQuickViews.GetQuickWhispersTabButton())
end

-- =============================================================
-- 5. HISTORY + WHISPERS VIEWS
-- =============================================================

local historyWhispersController = nil
if NS.HistoryWhispersController and NS.HistoryWhispersController.Create then
    historyWhispersController = NS.HistoryWhispersController.Create({
        historyView = historyView,
        whispersView = whispersView,
        maxRows = 50,
        getHistoryDB = function() return historyDB end,
        getWhispersDB = function() return whispersDB end,
        getAnalyticsDB = function() return analyticsDB end,
        getWhisperKey = GetWhisperKey,
        getShortName = GetShortName,
        onClearHistory = function()
            CogwheelRecruiterHistoryDB = {}
            historyDB = CogwheelRecruiterHistoryDB
        end,
        onHistoryCleared = function()
            print("History Cleared.")
        end,
        onHistoryReinvite = function(name)
            if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(name)
            else GuildInvite(name) end

            historyDB[name] = historyDB[name] or {}
            historyDB[name].time = time()
            historyDB[name].action = "INVITED"
            Analytics.RecordInviteSent(name, historyDB[name].class, historyDB[name].level)
        end,
        onWhisperInvite = function(item)
            if C_GuildInfo and C_GuildInfo.Invite then
                C_GuildInfo.Invite(item.name)
            else
                GuildInvite(item.name)
            end

            historyDB[item.name] = historyDB[item.name] or {}
            historyDB[item.name].time = time()
            historyDB[item.name].action = "INVITED"
            historyDB[item.name].class = historyDB[item.name].class or "PRIEST"
            Analytics.RecordInviteSent(item.name, historyDB[item.name].class, historyDB[item.name].level)
            if settingsDB and settingsDB.stats then
                settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1
            end
            return true
        end,
        onWhisperClear = function(item)
            whispersDB[item.key] = nil
        end,
        recordWhisperAnswered = function(sender) Analytics.RecordWhisperAnswered(sender) end,
        startWhispersTabFlash = function() if StartWhispersTabFlash then StartWhispersTabFlash() end end,
        getCurrentTab = function() return currentTab end,
    })
end

UpdateHistoryList = function()
    if historyWhispersController and historyWhispersController.UpdateHistoryList then
        historyWhispersController.UpdateHistoryList()
    end
end

UpdateWhispersList = function()
    if historyWhispersController and historyWhispersController.UpdateWhispersList then
        historyWhispersController.UpdateWhispersList()
    end
end

NS.HandleInboundWhisper = function(msg, sender)
    if historyWhispersController and historyWhispersController.HandleInboundWhisper then
        return historyWhispersController.HandleInboundWhisper(msg, sender)
    end
    return false
end

-- =============================================================
-- 7. SETTINGS / FILTERS
-- =============================================================
-- Wiring lives in SettingsStatsGuildController.

-- =============================================================
-- 8. SCAN LOGIC
-- =============================================================

local scanController = nil
if NS.ScanController and NS.ScanController.Create then
    scanController = NS.ScanController.Create({
        scannerEngine = ScannerEngine,
        quickScannerEngine = QuickScannerEngine,
        analytics = Analytics,
        print = print,
        quickQueueTarget = QUICK_QUEUE_TARGET,
        quickQueueMax = QUICK_QUEUE_MAX,
        quickLevelBalanceBuckets = QUICK_LEVEL_BALANCE_BUCKETS,
        quickZoneTimeoutSeconds = QUICK_ZONE_TIMEOUT_SECONDS,
        quickEmptyZoneStreakCap = QUICK_EMPTY_ZONE_STREAK_CAP,
        whoQueryTimeoutSeconds = WHO_QUERY_TIMEOUT_SECONDS,
        maxPlayerLevel = MAX_PLAYER_LEVEL,
        getSettingsDB = function() return settingsDB end,
        getHistoryDB = function() return historyDB end,
        getZoneCategories = function() return ZONE_CATEGORIES end,
        getClassList = function() return CLASS_LIST end,
        updateScanList = UpdateScanList,
        clearScanView = ClearScanView,
        updateQuickCandidateCard = UpdateQuickCandidateCard,
        playerCanRecruitNow = PlayerCanRecruitNow,
        recruitPermissionRequiredText = RECRUIT_PERMISSION_REQUIRED_TEXT,
        sendWhisperToPlayer = SendWhisperToPlayer,
        handleInboundWhisper = function(msg, sender)
            if NS.HandleInboundWhisper then
                NS.HandleInboundWhisper(msg, sender)
            end
        end,
        sendDelayedWelcomeMessage = SendDelayedWelcomeMessage,
        getSelectedSpecificZone = function() return SelectedSpecificZone end,
        getCurrentZoneText = GetZoneText,
        setScanButtonText = function(text)
            scanBtn:SetText(text)
        end,
        enableScanButton = function()
            scanBtn:Enable()
        end,
        disableScanButton = function()
            scanBtn:Disable()
        end,
    })
end

if not scanController then
    error("CogwheelRecruiter scan controller initialization failed")
end

quickState = scanController.GetQuickState and scanController.GetQuickState() or nil

NS.ResetQuickScanState = function()
    if scanController and scanController.ResetQuickScanState then
        scanController.ResetQuickScanState()
    end
end

quickActionHandlers.onNext = function()
    if scanController and scanController.OnQuickNext then
        scanController.OnQuickNext()
    end
end

quickActionHandlers.onWhisper = function()
    if scanController and scanController.OnQuickWhisper then
        scanController.OnQuickWhisper()
    end
end

quickActionHandlers.onInvite = function()
    if scanController and scanController.OnQuickInvite then
        scanController.OnQuickInvite()
    end
end

function StartScanSequence()
    if scanController and scanController.StartScanSequence then
        scanController.StartScanSequence()
    end
end

UpdateQuickCandidateCard()

-- =============================================================
-- 8. MINIMAP BUTTON
-- =============================================================
local minimapAPI
if NS.Minimap and NS.Minimap.Create then
    minimapAPI = NS.Minimap.Create({
        name = "CogwheelRecruiterMinimapButton",
        iconTexture = "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterIcon_64x64",
        tooltipTitle = "Cogwheel Recruiter",
        onLeftClick = function()
            ShowAddonWindow(true)
            if not welcomeFrame:IsShown() then
                SetTab(1)
            end
        end,
        onRightClick = function()
            OpenQuickScannerWindow()
        end,
        getSettings = function()
            return settingsDB
        end,
    })
end

UpdateMinimapPosition = function()
    if minimapAPI and minimapAPI.UpdatePosition then
        minimapAPI.UpdatePosition()
    end
end

SLASH_COGWHEELRECRUITER1 = "/cogwheel"
SlashCmdList["COGWHEELRECRUITER"] = function(msg)
    if msg == "reset" then
        CogwheelRecruiterHistoryDB = {}
        CogwheelRecruiterWhispersDB = {}
        historyDB = CogwheelRecruiterHistoryDB
        whispersDB = CogwheelRecruiterWhispersDB
        print("History and whispers cleared.")
        return
    end

    ShowAddonWindow(true)
end














