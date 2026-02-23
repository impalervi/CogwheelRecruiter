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
local UpdateTabButtons -- Forward declaration
local UpdateStatsView -- Forward declaration
local Analytics -- Forward declaration
local StartWhispersTabFlash -- Forward declaration
local SetTab -- Forward declaration
local SetWelcomeMode -- Forward declaration
local ApplyMainLayoutForTab -- Forward declaration
local currentTab -- Forward declaration
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

local CLASS_LIST = NS.CLASS_LIST or {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

-- Create Main Window (custom framed container)
local mainFrame = CreateFrame("Frame", "CogwheelRecruiterFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(520, 550)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
mainFrame:SetBackdropColor(0, 0, 0, 1)
mainFrame:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
mainFrame:Hide()

mainFrame.closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
mainFrame.closeBtn:SetPoint("TOPRIGHT", -2, -2)

mainFrame.quickModeBtn = CreateFrame("Button", nil, mainFrame)
mainFrame.quickModeBtn:SetSize(32, 32)
mainFrame.quickModeBtn:SetPoint("RIGHT", mainFrame.closeBtn, "LEFT", 10, 0)
mainFrame.quickModeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
mainFrame.quickModeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Down")
local mainCloseHighlight = mainFrame.closeBtn:GetHighlightTexture()
if mainCloseHighlight and mainCloseHighlight:GetTexture() then
    mainFrame.quickModeBtn:SetHighlightTexture(mainCloseHighlight:GetTexture(), "ADD")
else
    mainFrame.quickModeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
end
mainFrame.quickModeBtn:SetScript("OnClick", function()
    if SetTab then SetTab(8) end
end)
mainFrame.quickModeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Switch To Quick Scanner", 1, 0.82, 0)
    GameTooltip:Show()
end)
mainFrame.quickModeBtn:SetScript("OnLeave", GameTooltip_Hide)

mainFrame.titleChip = CreateFrame("Frame", nil, mainFrame)
mainFrame.titleChip:SetSize(250, 46)
mainFrame.titleChip:ClearAllPoints()
mainFrame.titleChip:SetPoint("TOP", mainFrame, "TOP", 0, 14)
mainFrame.titleChip.center = mainFrame.titleChip:CreateTexture(nil, "ARTWORK")
mainFrame.titleChip.center:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
mainFrame.titleChip.center:SetTexCoord(0.31, 0.67, 0, 0.63)
mainFrame.titleChip.center:SetPoint("TOP", 0, 0)
mainFrame.titleChip.center:SetSize(190, 42)
mainFrame.titleChip.left = mainFrame.titleChip:CreateTexture(nil, "ARTWORK")
mainFrame.titleChip.left:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
mainFrame.titleChip.left:SetTexCoord(0.21, 0.31, 0, 0.63)
mainFrame.titleChip.left:SetPoint("RIGHT", mainFrame.titleChip.center, "LEFT", 0, 0)
mainFrame.titleChip.left:SetSize(30, 42)
mainFrame.titleChip.right = mainFrame.titleChip:CreateTexture(nil, "ARTWORK")
mainFrame.titleChip.right:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
mainFrame.titleChip.right:SetTexCoord(0.67, 0.77, 0, 0.63)
mainFrame.titleChip.right:SetPoint("LEFT", mainFrame.titleChip.center, "RIGHT", 0, 0)
mainFrame.titleChip.right:SetSize(30, 42)

mainFrame.title = mainFrame.titleChip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("CENTER", mainFrame.titleChip.center, "CENTER", 0, 0)
mainFrame.title:SetText(COLOR_HEADER_GOLD .. ADDON_TITLE .. COLOR_RESET)

local contentPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
contentPanel:SetPoint("TOPLEFT", 10, -60)
contentPanel:SetPoint("BOTTOMRIGHT", -10, 58)
contentPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
contentPanel:SetBackdropColor(0.04, 0.04, 0.04, 0.88)
contentPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)

local footerFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
footerFrame:SetPoint("BOTTOMLEFT", 10, 8)
footerFrame:SetPoint("BOTTOMRIGHT", -10, 8)
footerFrame:SetHeight(18)
footerFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
footerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
footerFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

footerFrame.text = footerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerFrame.text:SetPoint("CENTER")
local coloredAuthor = ADDON_AUTHOR:gsub("Marviy", COLOR_DARK_MAGE .. "Marviy" .. COLOR_RESET)
footerFrame.text:SetText(string.format(
    "%s%s%s %sv%s%s | Author: %s",
    COLOR_FOOTER_GOLD, ADDON_TITLE, COLOR_RESET,
    COLOR_DARK_RED, ADDON_VERSION, COLOR_RESET,
    coloredAuthor
))


local quickFrame = CreateFrame("Frame", "CogwheelRecruiterQuickFrame", UIParent, "BackdropTemplate")
quickFrame:SetSize(320, 220)
quickFrame:SetPoint("CENTER")
quickFrame:SetMovable(true)
quickFrame:EnableMouse(true)
quickFrame:RegisterForDrag("LeftButton")
quickFrame:SetScript("OnDragStart", quickFrame.StartMoving)
quickFrame:SetScript("OnDragStop", quickFrame.StopMovingOrSizing)
quickFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
quickFrame:SetBackdropColor(0, 0, 0, 1)
quickFrame:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
quickFrame:Hide()

quickFrame.closeBtn = CreateFrame("Button", nil, quickFrame, "UIPanelCloseButton")
quickFrame.closeBtn:SetPoint("TOPRIGHT", -2, -2)

quickFrame.fullModeBtn = CreateFrame("Button", nil, quickFrame)
quickFrame.fullModeBtn:SetSize(32, 32)
quickFrame.fullModeBtn:SetPoint("RIGHT", quickFrame.closeBtn, "LEFT", 10, 0)
quickFrame.fullModeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
quickFrame.fullModeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Down")
local quickCloseHighlight = quickFrame.closeBtn:GetHighlightTexture()
if quickCloseHighlight and quickCloseHighlight:GetTexture() then
    quickFrame.fullModeBtn:SetHighlightTexture(quickCloseHighlight:GetTexture(), "ADD")
else
    quickFrame.fullModeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
end
quickFrame.fullModeBtn:SetScript("OnClick", function()
    if SetTab then SetTab(1) end
end)
quickFrame.fullModeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Switch To Full Scanner", 1, 0.82, 0)
    GameTooltip:Show()
end)
quickFrame.fullModeBtn:SetScript("OnLeave", GameTooltip_Hide)

quickFrame.titleChip = CreateFrame("Frame", nil, quickFrame)
quickFrame.titleChip:SetSize(210, 46)
quickFrame.titleChip:ClearAllPoints()
quickFrame.titleChip:SetPoint("TOP", quickFrame, "TOP", 0, 14)
quickFrame.titleChip.center = quickFrame.titleChip:CreateTexture(nil, "ARTWORK")
quickFrame.titleChip.center:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
quickFrame.titleChip.center:SetTexCoord(0.31, 0.67, 0, 0.63)
quickFrame.titleChip.center:SetPoint("TOP", 0, 0)
quickFrame.titleChip.center:SetSize(150, 42)
quickFrame.titleChip.left = quickFrame.titleChip:CreateTexture(nil, "ARTWORK")
quickFrame.titleChip.left:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
quickFrame.titleChip.left:SetTexCoord(0.21, 0.31, 0, 0.63)
quickFrame.titleChip.left:SetPoint("RIGHT", quickFrame.titleChip.center, "LEFT", 0, 0)
quickFrame.titleChip.left:SetSize(30, 42)
quickFrame.titleChip.right = quickFrame.titleChip:CreateTexture(nil, "ARTWORK")
quickFrame.titleChip.right:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
quickFrame.titleChip.right:SetTexCoord(0.67, 0.77, 0, 0.63)
quickFrame.titleChip.right:SetPoint("LEFT", quickFrame.titleChip.center, "RIGHT", 0, 0)
quickFrame.titleChip.right:SetSize(30, 42)

quickFrame.title = quickFrame.titleChip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
quickFrame.title:SetPoint("CENTER", quickFrame.titleChip.center, "CENTER", 0, 0)
quickFrame.title:SetText(COLOR_HEADER_GOLD .. ADDON_TITLE .. COLOR_RESET)

quickFrame.contentPanel = CreateFrame("Frame", nil, quickFrame, "BackdropTemplate")
quickFrame.contentPanel:SetPoint("TOPLEFT", 10, -60)
quickFrame.contentPanel:SetPoint("BOTTOMRIGHT", -10, 28)
quickFrame.contentPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
quickFrame.contentPanel:SetBackdropColor(0.04, 0.04, 0.04, 0.88)
quickFrame.contentPanel:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)

local quickFooterFrame = CreateFrame("Frame", nil, quickFrame, "BackdropTemplate")
quickFooterFrame:SetPoint("BOTTOMLEFT", 10, 8)
quickFooterFrame:SetPoint("BOTTOMRIGHT", -10, 8)
quickFooterFrame:SetHeight(18)
quickFooterFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
quickFooterFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
quickFooterFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

quickFooterFrame.text = quickFooterFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
quickFooterFrame.text:SetPoint("CENTER")
quickFooterFrame.text:SetText(string.format(
    "%s%s%s %sv%s%s | %s",
    COLOR_FOOTER_GOLD, ADDON_TITLE, COLOR_RESET,
    COLOR_DARK_RED, ADDON_VERSION, COLOR_RESET,
    coloredAuthor
))

local FORCE_INVITE_PERMISSION_BYPASS = false -- Keep false for normal invite-permission behavior

local function PlayerHasGuild()
    local guildName = GetGuildInfo("player")
    return guildName ~= nil and guildName ~= ""
end

local function RawPlayerCanInviteGuildMembers()
    if C_GuildInfo and C_GuildInfo.CanInvite then
        return C_GuildInfo.CanInvite()
    end
    if CanGuildInvite then
        return CanGuildInvite()
    end
    if IsGuildLeader then
        return IsGuildLeader()
    end
    return false
end

local function PlayerCanInviteGuildMembers()
    if FORCE_INVITE_PERMISSION_BYPASS then
        return true
    end
    return RawPlayerCanInviteGuildMembers()
end

local function PlayerCanRecruitNow()
    return PlayerHasGuild() and PlayerCanInviteGuildMembers()
end

local welcomeFrame = CreateFrame("Frame", nil, mainFrame)
welcomeFrame:SetPoint("TOPLEFT", 10, -60)
welcomeFrame:SetPoint("BOTTOMRIGHT", -10, 58)
welcomeFrame:Hide()

local welcomeContent = welcomeFrame
local welcomeLogo = welcomeContent:CreateTexture(nil, "ARTWORK")
welcomeLogo:SetSize(260, 260)
welcomeLogo:SetPoint("TOP", 0, -20)

local function SetWelcomeLogoTexture()
    for _, path in ipairs(SPLASH_LOGO_CANDIDATES) do
        welcomeLogo:SetTexture(path)
        if welcomeLogo:GetTexture() then
            return true
        end
    end
    welcomeLogo:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    return false
end
SetWelcomeLogoTexture()

local welcomeTitle = welcomeContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
welcomeTitle:SetPoint("TOP", welcomeLogo, "BOTTOM", 0, -6)
welcomeTitle:SetText(COLOR_HEADER_GOLD .. "Cogwheel Recruiter" .. COLOR_RESET)

local welcomeMeta = welcomeContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
welcomeMeta:SetPoint("TOP", welcomeTitle, "BOTTOM", 0, -8)
welcomeMeta:SetText(string.format("%sVersion:%s %sv%s%s    %sAuthor:%s %s",
    COLOR_FOOTER_GOLD, COLOR_RESET,
    COLOR_DARK_RED, ADDON_VERSION, COLOR_RESET,
    COLOR_FOOTER_GOLD, COLOR_RESET,
    coloredAuthor
))

local welcomeStatus = welcomeContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
welcomeStatus:SetPoint("TOP", welcomeMeta, "BOTTOM", 0, -16)
welcomeStatus:SetWidth(420)
welcomeStatus:SetJustifyH("CENTER")

local welcomeStartBtn = CreateFrame("Button", nil, welcomeContent, "UIPanelButtonTemplate")
welcomeStartBtn:SetSize(320, 36)
welcomeStartBtn:SetPoint("BOTTOM", welcomeContent, "BOTTOM", 0, -4)
welcomeStartBtn:SetText("Start Scanning")
welcomeStartBtn:SetNormalFontObject("GameFontNormalLarge")
welcomeStartBtn:SetHighlightFontObject("GameFontNormalLarge")
welcomeStartBtn:SetDisabledFontObject("GameFontDisable")

local function ShowMainAddonWindow(forceScanner)
    quickFrame:Hide()
    mainFrame:Show()
    if SetWelcomeMode then
        SetWelcomeMode(false)
    else
        welcomeFrame:Hide()
    end

    if forceScanner then
        SetTab(1)
    else
        SetTab(currentTab or 1)
    end
end

local function UpdateWelcomeState(forceScanner)
    if not settingsDB then return end

    local guildName = GetGuildInfo("player")
    local hasGuild = guildName ~= nil and guildName ~= ""
    local canInvite = hasGuild and PlayerCanInviteGuildMembers()
    local firstLaunch = DEBUG_ALWAYS_SHOW_WELCOME or settingsDB.splashSeen ~= true
    local blocked = (not hasGuild) or (not canInvite)

    if blocked or firstLaunch then
        mainFrame:Show()
        if SetWelcomeMode then
            SetWelcomeMode(true)
        else
            welcomeFrame:Show()
        end
        if not hasGuild then
            welcomeStartBtn:SetText("You Don't Currently Have A Guild")
            welcomeStartBtn:Disable()
            welcomeStatus:SetText("|cffff6666You need to be in a guild to use Cogwheel Recruiter.|r")
        elseif not canInvite then
            welcomeStartBtn:SetText("You Can Not Invite Members To Your Guild")
            welcomeStartBtn:Disable()
            welcomeStatus:SetText("|cffff6666Your current guild rank does not have invite permissions.|r")
        else
            welcomeStartBtn:SetText("Start Scanning")
            welcomeStartBtn:Enable()
            welcomeStatus:SetText(WELCOME_NOTES_DISPLAY)
        end
    else
        ShowMainAddonWindow(forceScanner)
    end
end

welcomeStartBtn:SetScript("OnClick", function()
    local guildName = GetGuildInfo("player")
    local hasGuild = guildName ~= nil and guildName ~= ""
    if not hasGuild or not PlayerCanInviteGuildMembers() then
        UpdateWelcomeState(true)
        return
    end

    settingsDB.splashSeen = true
    ShowMainAddonWindow(true)
end)

local function ShowAddonWindow(forceScanner)
    if settingsDB then
        UpdateWelcomeState(forceScanner)
    else
        ShowMainAddonWindow(forceScanner)
    end
end

local function OpenQuickScannerWindow()
    if not settingsDB then
        ShowMainAddonWindow(false)
        SetTab(8)
        return
    end

    local guildName = GetGuildInfo("player")
    local hasGuild = guildName ~= nil and guildName ~= ""
    local canInvite = hasGuild and PlayerCanInviteGuildMembers()
    local blocked = (not hasGuild) or (not canInvite)

    if blocked then
        UpdateWelcomeState(false)
        return
    end

    settingsDB.splashSeen = true
    ShowMainAddonWindow(false)
    SetTab(8)
end
local function ToggleAddonWindow()
    if mainFrame:IsShown() or welcomeFrame:IsShown() or quickFrame:IsShown() then
        mainFrame:Hide()
        welcomeFrame:Hide()
        quickFrame:Hide()
    else
        ShowAddonWindow(false)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if NS.EnsureDatabases then
            historyDB, settingsDB, whispersDB, analyticsDB = NS.EnsureDatabases()
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

        if NS.ApplyDefaultSettings then
            NS.ApplyDefaultSettings(settingsDB, CLASS_LIST)
        else
            if not settingsDB.minLevel then settingsDB.minLevel = 1 end
            if not settingsDB.maxLevel then settingsDB.maxLevel = MAX_PLAYER_LEVEL end
            if not settingsDB.classes then settingsDB.classes = {} end
            for _, cls in ipairs(CLASS_LIST) do
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

        if not analyticsDB then
            CogwheelRecruiterAnalyticsDB = CogwheelRecruiterAnalyticsDB or {}
            analyticsDB = CogwheelRecruiterAnalyticsDB
        end
        if Analytics and Analytics.EnsureDefaults then
            Analytics.EnsureDefaults()
        end

        if UpdateMinimapPosition then UpdateMinimapPosition() end

        print(string.format("|cffC8A04A[Cogwheel Recruiter]|r v%s by |cff69CCF0Marviy|r @ Nightslayer. Type /cogwheel to start.", ADDON_VERSION))

        -- Cleanup old history
        if NS.PruneHistory then
            NS.PruneHistory(historyDB, settingsDB.historyRetentionDays)
        else
            local cutoff = time() - (settingsDB.historyRetentionDays * 86400)
            for name, data in pairs(historyDB) do
                if data.time < cutoff then historyDB[name] = nil end
            end
        end
    end
end)

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
    if not name then return "" end
    return (name:match("^[^-]+") or name)
end

local function GetWhisperKey(name)
    return GetShortName(name)
end

local function NormalizeClassName(classToken)
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
    local short = GetShortName(targetName)
    local guildName = GetGuildInfo("player") or "our guild"
    local className = NormalizeClassName(targetClass)
    tmpl = tmpl:gsub("<character>", short)
    tmpl = tmpl:gsub("{character}", short)
    tmpl = tmpl:gsub("<guild>", guildName)
    tmpl = tmpl:gsub("{guild}", guildName)
    tmpl = tmpl:gsub("<class>", className)
    tmpl = tmpl:gsub("{class}", className)
    return tmpl
end

local function BuildWelcomeMessage(targetName)
    local tmpl = (settingsDB and settingsDB.welcomeTemplate) or "Welcome to <guild>, <character>!"
    local short = GetShortName(targetName)
    local guildName = GetGuildInfo("player") or "our guild"
    tmpl = tmpl:gsub("<character>", short)
    tmpl = tmpl:gsub("{character}", short)
    tmpl = tmpl:gsub("<guild>", guildName)
    tmpl = tmpl:gsub("{guild}", guildName)
    return tmpl
end

Analytics = {}

function Analytics.EnsureDefaults()
    if not analyticsDB then
        return
    end

    if NS.EnsureAnalyticsDefaults then
        NS.EnsureAnalyticsDefaults(analyticsDB, CLASS_LIST, NS.ZONE_CATEGORIES)
        return
    end

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
end

function Analytics.IncrementCounter(map, key, amount)
    if not map or not key then return end
    local delta = amount or 1
    map[key] = (tonumber(map[key]) or 0) + delta
end

function Analytics.NormalizeClassTag(classToken)
    local upper = string.upper(classToken or "PRIEST")
    if upper == "" then upper = "PRIEST" end
    return upper
end

function Analytics.GetLevelCategory(level)
    if NS.GetLevelCategoryName then
        return NS.GetLevelCategoryName(level, NS.ZONE_CATEGORIES)
    end
    return "Other"
end

function Analytics.RecordWhisperSent(targetName)
    if not analyticsDB then return end
    Analytics.EnsureDefaults()

    analyticsDB.whispered = (analyticsDB.whispered or 0) + 1
    analyticsDB.pendingWhispers[GetWhisperKey(targetName)] = true
end

function Analytics.RecordWhisperAnswered(sender)
    if not analyticsDB then return end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(sender)
    if analyticsDB.pendingWhispers[key] then
        analyticsDB.whispersAnswered = (analyticsDB.whispersAnswered or 0) + 1
        analyticsDB.pendingWhispers[key] = nil
    end
end

function Analytics.RecordInviteSent(targetName, targetClass, targetLevel)
    if not analyticsDB then return end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(targetName)
    local classTag = Analytics.NormalizeClassTag(targetClass)
    local levelCategory = Analytics.GetLevelCategory(targetLevel)

    analyticsDB.invited = (analyticsDB.invited or 0) + 1
    Analytics.IncrementCounter(analyticsDB.invitesByClass, classTag, 1)
    Analytics.IncrementCounter(analyticsDB.invitesByLevel, levelCategory, 1)

    analyticsDB.pendingInvites[key] = {
        class = classTag,
        level = targetLevel,
        levelCategory = levelCategory,
        time = time()
    }
end

function Analytics.ClearPendingInvite(targetName)
    if not analyticsDB then return end
    Analytics.EnsureDefaults()
    analyticsDB.pendingInvites[GetWhisperKey(targetName)] = nil
end

function Analytics.RecordInviteAccepted(targetName, fallbackClass, fallbackLevel, previousAction)
    if not analyticsDB then return end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(targetName)
    local pending = analyticsDB.pendingInvites[key]
    local shouldCount = (pending ~= nil) or (previousAction == "INVITED")
    if not shouldCount then
        return
    end

    local classTag = Analytics.NormalizeClassTag((pending and pending.class) or fallbackClass)
    local levelCategory = (pending and pending.levelCategory) or Analytics.GetLevelCategory((pending and pending.level) or fallbackLevel)

    analyticsDB.accepted = (analyticsDB.accepted or 0) + 1
    Analytics.IncrementCounter(analyticsDB.acceptedByClass, classTag, 1)
    Analytics.IncrementCounter(analyticsDB.acceptedByLevel, levelCategory, 1)

    analyticsDB.pendingInvites[key] = nil
end
local function SendDelayedWelcomeMessage(targetName)
    if not C_Timer or not C_Timer.After then
        return
    end

    C_Timer.After(2, function()
        if not settingsDB or not settingsDB.autoWelcomeEnabled then
            return
        end

        local welcomeMsg = BuildWelcomeMessage(targetName)
        if string.len(welcomeMsg) > MAX_WHISPER_CHARS then
            print(string.format("|cffff0000[Cogwheel]|r Welcome message too long (%d/%d). Shorten it in Settings.", string.len(welcomeMsg), MAX_WHISPER_CHARS))
            return
        end

        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage(welcomeMsg, "GUILD")
        else
            SendChatMessage(welcomeMsg, "GUILD")
        end
    end)
end

local function SendWhisperToPlayer(targetName, targetClass)
    local msg = BuildWhisperMessage(targetName, targetClass)
    if string.len(msg) > MAX_WHISPER_CHARS then
        print(string.format("|cffff0000[Cogwheel]|r Whisper too long (%d/%d). Shorten your template in Settings.", string.len(msg), MAX_WHISPER_CHARS))
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, targetName)
    else
        SendChatMessage(msg, "WHISPER", nil, targetName)
    end

    if whispersDB then
        local key = GetWhisperKey(targetName)
        whispersDB[key] = whispersDB[key] or {}
        whispersDB[key].displayName = GetShortName(targetName)
        whispersDB[key].lastOutbound = msg
        whispersDB[key].lastOutboundTime = time()
    end
    Analytics.RecordWhisperSent(targetName)
    return true
end

-- =============================================================
-- 3. TABS SETUP
-- =============================================================
currentTab = 1
local scanRows = {}

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

local gsTitle = guildStatsView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
gsTitle:SetPoint("TOPLEFT", 20, -15)
gsTitle:SetText("Guild Overview")
local gsSummaryValues = guildStatsView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
gsSummaryValues:SetPoint("TOPLEFT", 20, -46)
gsSummaryValues:SetWidth(460)
gsSummaryValues:SetJustifyH("LEFT")
gsSummaryValues:SetTextColor(0.85, 0.85, 0.85)

local gsActiveScopeNote = guildStatsView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gsActiveScopeNote:SetPoint("TOPLEFT", 20, -74)
gsActiveScopeNote:SetWidth(460)
gsActiveScopeNote:SetJustifyH("LEFT")
gsActiveScopeNote:SetTextColor(0.72, 0.88, 0.72)
gsActiveScopeNote:SetText(string.format("Class and level distributions are calculated from members active in the past %d days.", ACTIVE_MEMBER_WINDOW_DAYS))

-- Dropdowns for Stats
local currentStatsMode = "CLASS" -- "CLASS" or "LEVEL"
local currentVisMode = "BAR" -- "MOSAIC" or "BAR"

guildStatsView.statsTypeDD = CreateFrame("Frame", "CogwheelRecruiterStatsTypeDD", guildStatsView, "UIDropDownMenuTemplate")
guildStatsView.statsTypeDD:SetPoint("TOPLEFT", 0, -98)
UIDropDownMenu_SetWidth(guildStatsView.statsTypeDD, 100)
UIDropDownMenu_Initialize(guildStatsView.statsTypeDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "By Class"
    info.checked = (currentStatsMode == "CLASS")
    info.func = function() currentStatsMode = "CLASS"; UIDropDownMenu_SetText(guildStatsView.statsTypeDD, "By Class"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)

    info.text = "By Level"
    info.checked = (currentStatsMode == "LEVEL")
    info.func = function() currentStatsMode = "LEVEL"; UIDropDownMenu_SetText(guildStatsView.statsTypeDD, "By Level"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)
end)
UIDropDownMenu_SetText(guildStatsView.statsTypeDD, "By Class")

guildStatsView.statsVisDD = CreateFrame("Frame", "CogwheelRecruiterStatsVisDD", guildStatsView, "UIDropDownMenuTemplate")
guildStatsView.statsVisDD:SetPoint("LEFT", guildStatsView.statsTypeDD, "RIGHT", -20, 0)
UIDropDownMenu_SetWidth(guildStatsView.statsVisDD, 120)
UIDropDownMenu_Initialize(guildStatsView.statsVisDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "Mosaic"
    info.checked = (currentVisMode == "MOSAIC")
    info.func = function() currentVisMode = "MOSAIC"; UIDropDownMenu_SetText(guildStatsView.statsVisDD, "Mosaic"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)

    info.text = "Stacked Bar"
    info.checked = (currentVisMode == "BAR")
    info.func = function() currentVisMode = "BAR"; UIDropDownMenu_SetText(guildStatsView.statsVisDD, "Stacked Bar"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)
end)
UIDropDownMenu_SetText(guildStatsView.statsVisDD, "Stacked Bar")

local gsContainer = CreateFrame("Frame", nil, guildStatsView)
gsContainer:SetPoint("TOPLEFT", 20, -142)
gsContainer:SetPoint("BOTTOMRIGHT", -20, 48)

-- Helper: Get Class Counts (Shared by Stats and Settings)
local function GetGuildClassCounts()
    local numMembers = GetNumGuildMembers()
    local counts = {}
    local total = 0

    for i=1, numMembers do
        local name, _, _, _, _, _, _, _, online, _, classFileName = GetGuildRosterInfo(i)
        if name then
            local active = online
            if not active then
                local y, m, d = GetGuildRosterLastOnline(i)
                if y and (y == 0 and m == 0 and d <= ACTIVE_MEMBER_WINDOW_DAYS) then active = true end
            end

            if active and classFileName then
                counts[classFileName] = (counts[classFileName] or 0) + 1
                total = total + 1
            end
        end
    end
    return counts, total
end

-- Helper: Get Level Category Counts
local function GetGuildLevelCounts()
    local numMembers = GetNumGuildMembers()
    local counts = {}
    local total = 0

    for i=1, numMembers do
        local name, _, _, level, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            local active = online
            if not active then
                local y, m, d = GetGuildRosterLastOnline(i)
                if y and (y == 0 and m == 0 and d <= ACTIVE_MEMBER_WINDOW_DAYS) then active = true end
            end

            if active and level then
                local found = false
                for _, cat in ipairs(ZONE_CATEGORIES) do
                    if cat.min and cat.max and cat.min > 0 then
                        if level >= cat.min and level <= cat.max then
                            counts[cat.name] = (counts[cat.name] or 0) + 1
                            found = true
                            break -- Assign to first matching category
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

local gsSquares = {}
local gsLegend = {}
local gsStackSegments = {}
local function SendGuildReportLine(msg)
    if not msg or msg == "" then return end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, "GUILD")
    else
        SendChatMessage(msg, "GUILD")
    end
end

local function BuildDistributionLines(header, segments)
    local lines = { header }
    if #segments == 0 then
        table.insert(lines, string.format("No active members found in the past %d days.", ACTIVE_MEMBER_WINDOW_DAYS))
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

local function SendDistributionReportToGuild(header, segments)
    local lines = BuildDistributionLines(header, segments)
    for _, line in ipairs(lines) do
        SendGuildReportLine(line)
    end
end

local function BuildClassDistributionSegments()
    local counts, total = GetGuildClassCounts()
    local sorted = {}
    for cls, count in pairs(counts) do
        table.insert(sorted, { cls = cls, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local segments = {}
    for _, item in ipairs(sorted) do
        local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[item.cls]) or (item.cls:sub(1, 1) .. item.cls:sub(2):lower())
        local pct = (total > 0) and math.floor((item.count / total) * 100 + 0.5) or 0
        table.insert(segments, string.format("%s: %d (%d%%)", label, item.count, pct))
    end

    return segments, total
end

local function BuildLevelDistributionSegments()
    local counts, total = GetGuildLevelCounts()
    local segments = {}

    for _, cat in ipairs(ZONE_CATEGORIES) do
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

UpdateGuildStats = function()
    if not guildStatsView:IsVisible() then return end

    local guildName = GetGuildInfo("player") or "No Guild"
    local rosterSize = GetNumGuildMembers() or 0
    local totalMembers = 0
    local activeMembers = 0

    for i=1, rosterSize do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            totalMembers = totalMembers + 1
            local active = online
            if not active then
                local y, m, d = GetGuildRosterLastOnline(i)
                if y and (y == 0 and m == 0 and d <= ACTIVE_MEMBER_WINDOW_DAYS) then active = true end
            end
            if active then activeMembers = activeMembers + 1 end
        end
    end

    gsSummaryValues:SetText(string.format(
        "Guild: |cffFFD100%s|r  |  Characters: |cffffffff%d|r  |  Active (%d days): |cff6fdc6f%d|r",
        guildName,
        totalMembers,
        ACTIVE_MEMBER_WINDOW_DAYS,
        activeMembers
    ))

    local counts, total
    local colorMap = {}

    if currentStatsMode == "CLASS" then
        counts, total = GetGuildClassCounts()
        for cls, _ in pairs(counts) do
            colorMap[cls] = RAID_CLASS_COLORS[cls] or {r=0.5, g=0.5, b=0.5}
        end
    else
        counts, total = GetGuildLevelCounts()
        for _, cat in ipairs(ZONE_CATEGORIES) do
            if cat.color then colorMap[cat.name] = cat.color end
        end
        colorMap["Other"] = {r=0.5, g=0.5, b=0.5}
    end

    local sorted = {}
    for key, count in pairs(counts) do table.insert(sorted, {key=key, count=count}) end
    table.sort(sorted, function(a,b) return a.count > b.count end)

    -- Reset UI
    for _, sq in ipairs(gsSquares) do sq:Hide() end
    for _, l in ipairs(gsLegend) do l:Hide() end
    for _, s in ipairs(gsStackSegments) do s:Hide() end

    if total == 0 then return end

    if currentVisMode == "MOSAIC" then
        -- 1. Draw Waffle Chart (10x10 Grid)
        local sqSize = 20
        local startX, startY = 20, -10
        local currentSq = 0

        for i, data in ipairs(sorted) do
            local numBlocks = math.floor((data.count / total) * 100 + 0.5)
            local c = colorMap[data.key] or {r=0.5, g=0.5, b=0.5}

            for b=1, numBlocks do
                currentSq = currentSq + 1
                if currentSq <= 100 then
                    if not gsSquares[currentSq] then
                        local f = gsContainer:CreateTexture(nil, "ARTWORK")
                        f:SetSize(sqSize-1, sqSize-1)
                        gsSquares[currentSq] = f
                    end
                    local f = gsSquares[currentSq]
                    local row = math.floor((currentSq-1) / 10)
                    local col = (currentSq-1) % 10
                    f:SetPoint("TOPLEFT", startX + (col * sqSize), startY - (row * sqSize))
                    f:SetColorTexture(c.r, c.g, c.b)
                    f:Show()
                end
            end
        end

        -- Legend
        local ly = -10
        for i, data in ipairs(sorted) do
            if not gsLegend[i] then
                local t = gsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                t:SetJustifyH("LEFT")
                gsLegend[i] = t
            end
            local t = gsLegend[i]
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 225, ly)
            local c = colorMap[data.key] or {r=1,g=1,b=1}
            local colorStr = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
            local label = data.key:sub(1,1)..data.key:sub(2):lower()
            t:SetText(colorStr .. label .. "|r: " .. data.count .. " (" .. math.floor((data.count/total)*100) .. "%)")
            t:Show()
            ly = ly - 20
        end
    else
        -- 2. Draw Stacked Bar Chart
        local totalWidth = gsContainer:GetWidth()
        local barHeight = 30
        local currentX = 0

        for i, data in ipairs(sorted) do
            if not gsStackSegments[i] then
                local f = gsContainer:CreateTexture(nil, "ARTWORK")
                gsStackSegments[i] = f
            end
            local f = gsStackSegments[i]

            local pct = data.count / total
            local w = pct * totalWidth

            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", currentX, 0)
            f:SetSize(w, barHeight)

            local c = colorMap[data.key] or {r=0.5, g=0.5, b=0.5}
            f:SetColorTexture(c.r, c.g, c.b)
            f:Show()

            currentX = currentX + w
        end

        -- Legend for Stacked Bar
        local ly = -40
        for i, data in ipairs(sorted) do
            if not gsLegend[i] then
                local t = gsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                t:SetJustifyH("LEFT")
                gsLegend[i] = t
            end
            local t = gsLegend[i]
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 0, ly)

            local c = colorMap[data.key] or {r=1,g=1,b=1}
            local colorStr = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
            local label = data.key:sub(1,1)..data.key:sub(2):lower()
            t:SetText(colorStr .. label .. "|r: " .. data.count .. " (" .. math.floor((data.count/total)*100) .. "%)")
            t:Show()

            ly = ly - 20
        end
    end
end

guildStatsView:RegisterEvent("GUILD_ROSTER_UPDATE")
guildStatsView:SetScript("OnEvent", UpdateGuildStats)
local reportButtonsRow = CreateFrame("Frame", nil, guildStatsView)
reportButtonsRow:SetSize(350, 22)
reportButtonsRow:SetPoint("BOTTOM", guildStatsView, "BOTTOM", 0, 12)

local reportWarning = guildStatsView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
reportWarning:SetPoint("BOTTOM", reportButtonsRow, "TOP", 0, 6)
reportWarning:SetText("Warning: These will report to guild chat")
reportWarning:SetTextColor(0.25, 1.0, 0.25)

local reportClassBtn = CreateFrame("Button", nil, guildStatsView, "UIPanelButtonTemplate")
reportClassBtn:SetSize(170, 22)
reportClassBtn:SetPoint("LEFT", reportButtonsRow, "LEFT", 0, 0)
reportClassBtn:SetText("Report Class Stats")
reportClassBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local segments = BuildClassDistributionSegments()
    local header = string.format("Guild Class Distribution (Based on members active for the past %d days)", ACTIVE_MEMBER_WINDOW_DAYS)
    SendDistributionReportToGuild(header, segments)
    print("|cff00ff00[Cogwheel]|r Class distribution posted to guild chat.")
end)

local reportLevelBtn = CreateFrame("Button", nil, guildStatsView, "UIPanelButtonTemplate")
reportLevelBtn:SetSize(170, 22)
reportLevelBtn:SetPoint("LEFT", reportClassBtn, "RIGHT", 10, 0)
reportLevelBtn:SetText("Report Level Stats")
reportLevelBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local segments = BuildLevelDistributionSegments()
    local header = string.format("Guild Level Distribution (Based on members active for the past %d days)", ACTIVE_MEMBER_WINDOW_DAYS)
    SendDistributionReportToGuild(header, segments)
    print("|cff00ff00[Cogwheel]|r Level distribution posted to guild chat.")
end)

do -- Stats Dashboard UI
local statsScroll = CreateFrame("ScrollFrame", nil, statsView, "UIPanelScrollFrameTemplate")
statsScroll:SetPoint("TOPLEFT", 0, -5)
statsScroll:SetPoint("BOTTOMRIGHT", -25, 10)

local statsContent = CreateFrame("Frame", nil, statsScroll)
statsContent:SetSize(460, 1)
statsScroll:SetScrollChild(statsContent)

local header = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 10, -10)
header:SetText("Recruitment Performance")

local totalsText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
totalsText:SetPoint("TOPLEFT", 10, -40)
totalsText:SetWidth(440)
totalsText:SetJustifyH("LEFT")
totalsText:SetWordWrap(false)

local ratesText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ratesText:SetPoint("TOPLEFT", 10, -62)
ratesText:SetWidth(440)
ratesText:SetJustifyH("LEFT")
ratesText:SetWordWrap(false)
ratesText:SetTextColor(0.7, 0.9, 0.7)

local classHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classHeader:SetPoint("TOPLEFT", 10, -92)
classHeader:SetText("Per Class (Invites / Accepted / Acceptance Rate)")

local classRows = {}
local classStartY = -112

for i, cls in ipairs(CLASS_LIST) do
    local row = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", 16, classStartY - ((i - 1) * 18))
    row:SetWidth(430)
    row:SetJustifyH("LEFT")
    classRows[cls] = row
end

local levelHeaderY = classStartY - (#CLASS_LIST * 18) - 16
local levelHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelHeader:SetPoint("TOPLEFT", 10, levelHeaderY)
levelHeader:SetText("Per Level Category (Invites / Accepted / Acceptance Rate)")

local levelCategoryOrder = {}
for _, cat in ipairs(ZONE_CATEGORIES) do
    if cat.min and cat.max and cat.min > 0 then
        table.insert(levelCategoryOrder, cat.name)
    end
end
table.insert(levelCategoryOrder, "Other")

local levelRows = {}
local levelStartY = levelHeaderY - 20
for i, levelName in ipairs(levelCategoryOrder) do
    local row = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", 16, levelStartY - ((i - 1) * 18))
    row:SetWidth(430)
    row:SetJustifyH("LEFT")
    levelRows[levelName] = row
end

local extremesHeaderY = levelStartY - (#levelCategoryOrder * 18) - 16
local extremesHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
extremesHeader:SetPoint("TOPLEFT", 10, extremesHeaderY)
extremesHeader:SetText("Acceptance Highlights")

local bestClassText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bestClassText:SetPoint("TOPLEFT", 16, extremesHeaderY - 22)
bestClassText:SetWidth(430)
bestClassText:SetJustifyH("LEFT")
bestClassText:SetTextColor(0.6, 1.0, 0.6)

local worstClassText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
worstClassText:SetPoint("TOPLEFT", 16, extremesHeaderY - 40)
worstClassText:SetWidth(430)
worstClassText:SetJustifyH("LEFT")
worstClassText:SetTextColor(1.0, 0.65, 0.65)

local bestLevelText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bestLevelText:SetPoint("TOPLEFT", 16, extremesHeaderY - 62)
bestLevelText:SetWidth(430)
bestLevelText:SetJustifyH("LEFT")
bestLevelText:SetTextColor(0.6, 1.0, 0.6)

local worstLevelText = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
worstLevelText:SetPoint("TOPLEFT", 16, extremesHeaderY - 80)
worstLevelText:SetWidth(430)
worstLevelText:SetJustifyH("LEFT")
worstLevelText:SetTextColor(1.0, 0.65, 0.65)

statsContent:SetHeight((-extremesHeaderY) + 120)

local function FormatRate(accepted, invited)
    local inv = tonumber(invited) or 0
    local acc = tonumber(accepted) or 0
    if inv <= 0 then
        return "n/a"
    end
    return string.format("%.1f%%", (acc / inv) * 100)
end

local function GetClassDisplayName(classTag)
    return NormalizeClassName(classTag)
end

local function FindExtremes(keys, invitesBy, acceptedBy, labelFn)
    local bestKey, bestRate = nil, -1
    local worstKey, worstRate = nil, 2

    for _, key in ipairs(keys) do
        local invites = tonumber(invitesBy[key]) or 0
        local accepted = tonumber(acceptedBy[key]) or 0
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

    local bestLabel = labelFn(bestKey)
    local worstLabel = labelFn(worstKey)
    local bestText = string.format("%s (%s)", bestLabel, FormatRate(tonumber(acceptedBy[bestKey]) or 0, tonumber(invitesBy[bestKey]) or 0))
    local worstText = string.format("%s (%s)", worstLabel, FormatRate(tonumber(acceptedBy[worstKey]) or 0, tonumber(invitesBy[worstKey]) or 0))
    return bestText, worstText
end

UpdateStatsView = function()
    if not analyticsDB then
        totalsText:SetText("No analytics data available yet.")
        ratesText:SetText("")
        return
    end

    Analytics.EnsureDefaults()

    local whispered = tonumber(analyticsDB.whispered) or 0
    local answered = tonumber(analyticsDB.whispersAnswered) or 0
    local invited = tonumber(analyticsDB.invited) or 0
    local accepted = tonumber(analyticsDB.accepted) or 0

    totalsText:SetText(string.format(
        "Whispered: %d | Answered: %d | Invited: %d | Accepted: %d",
        whispered,
        answered,
        invited,
        accepted
    ))

    ratesText:SetText(string.format(
        "Reply Rate: %s   |   Overall Acceptance Rate: %s",
        FormatRate(answered, whispered),
        FormatRate(accepted, invited)
    ))

    local invitesByClass = analyticsDB.invitesByClass or {}
    local acceptedByClass = analyticsDB.acceptedByClass or {}

    for _, cls in ipairs(CLASS_LIST) do
        local invitesCount = tonumber(invitesByClass[cls]) or 0
        local acceptedCount = tonumber(acceptedByClass[cls]) or 0
        local row = classRows[cls]
        local color = RAID_CLASS_COLORS[cls]
        if color then
            row:SetTextColor(color.r, color.g, color.b)
        else
            row:SetTextColor(0.9, 0.9, 0.9)
        end

        row:SetText(string.format(
            "%s - Invites: %d  Accepted: %d  Rate: %s",
            GetClassDisplayName(cls),
            invitesCount,
            acceptedCount,
            FormatRate(acceptedCount, invitesCount)
        ))
    end

    local invitesByLevel = analyticsDB.invitesByLevel or {}
    local acceptedByLevel = analyticsDB.acceptedByLevel or {}

    for _, levelName in ipairs(levelCategoryOrder) do
        local invitesCount = tonumber(invitesByLevel[levelName]) or 0
        local acceptedCount = tonumber(acceptedByLevel[levelName]) or 0
        local row = levelRows[levelName]
        row:SetTextColor(0.9, 0.9, 0.9)
        row:SetText(string.format(
            "%s - Invites: %d  Accepted: %d  Rate: %s",
            levelName,
            invitesCount,
            acceptedCount,
            FormatRate(acceptedCount, invitesCount)
        ))
    end

    local bestClass, worstClass = FindExtremes(CLASS_LIST, invitesByClass, acceptedByClass, GetClassDisplayName)
    bestClassText:SetText("Highest Class Acceptance: " .. bestClass)
    worstClassText:SetText("Lowest Class Acceptance: " .. worstClass)

    local bestLevel, worstLevel = FindExtremes(levelCategoryOrder, invitesByLevel, acceptedByLevel, function(key) return key end)
    bestLevelText:SetText("Highest Level Category Acceptance: " .. bestLevel)
    worstLevelText:SetText("Lowest Level Category Acceptance: " .. worstLevel)
end
end

SetTab = function(id)
    local previousTab = currentTab
    currentTab = id
    if id == 7 and (previousTab == 1 or previousTab == 8) then
        NS.filterReturnTab = previousTab
    end

    if id == 8 then
        mainFrame:Hide()
        welcomeFrame:Hide()
        quickFrame:Show()
        quickView:Show()
        if UpdateTabButtons then UpdateTabButtons() end
        return
    end

    quickFrame:Hide()
    mainFrame:Show()

    if ApplyMainLayoutForTab then
        ApplyMainLayoutForTab(id)
    end

    scanView:Hide()
    quickView:Hide()
    historyView:Hide()
    settingsView:Hide()
    filtersView:Hide()
    statsView:Hide()
    guildStatsView:Hide()
    whispersView:Hide()

    if id == 1 then
        scanView:Show()
    elseif id == 2 then
        historyView:Show()
        if UpdateHistoryList then UpdateHistoryList() end
    elseif id == 3 then
        settingsView:Show()
    elseif id == 7 then
        filtersView:Show()
    elseif id == 4 then
        statsView:Show()
        UpdateStatsView()
    elseif id == 5 then
        guildStatsView:Show()
        UpdateGuildStats()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
    elseif id == 6 then
        whispersView:Show()
        if StopWhispersTabFlash then StopWhispersTabFlash() end
        if UpdateWhispersList then UpdateWhispersList() end
    end

    if UpdateTabButtons then UpdateTabButtons() end
end

local tab1 = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
tab1:SetSize(132, 24)
tab1:SetPoint("TOP", mainFrame, "TOP", 0, -30)
tab1:SetText("Scanner")
tab1:SetScript("OnClick", function() SetTab(1) end)

local tabQuick = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
tabQuick:SetSize(132, 24)
tabQuick:SetPoint("RIGHT", tab1, "LEFT", -4, 0)
tabQuick:SetText("Quick Scanner")
tabQuick:SetScript("OnClick", function() SetTab(8) end)

local tab6 = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
tab6:SetSize(132, 24)
tab6:SetPoint("LEFT", tab1, "RIGHT", 4, 0)
tab6:SetText("Whispers")
tab6:SetScript("OnClick", function() SetTab(6) end)

local isWhispersTabFlashing = false
local hasUnreadWhispers = false
local whispersHighlightTicker
local whispersHighlightOn = false

StopWhispersTabFlash = function()
    isWhispersTabFlashing = false
    hasUnreadWhispers = false
    if whispersHighlightTicker then
        whispersHighlightTicker:Cancel()
        whispersHighlightTicker = nil
    end
    whispersHighlightOn = false
    tab6:UnlockHighlight()
    tab6:SetAlpha((currentTab == 6) and 1.0 or 0.85)
end

StartWhispersTabFlash = function()
    if currentTab == 6 then return end
    hasUnreadWhispers = true
    if isWhispersTabFlashing then return end

    isWhispersTabFlashing = true
    if not (C_Timer and C_Timer.NewTicker) then
        tab6:LockHighlight()
        whispersHighlightOn = true
        return
    end
    whispersHighlightOn = true
    tab6:LockHighlight()
    whispersHighlightTicker = C_Timer.NewTicker(0.6, function()
        if not isWhispersTabFlashing or not hasUnreadWhispers then return end
        whispersHighlightOn = not whispersHighlightOn
        if whispersHighlightOn then
            tab6:LockHighlight()
        else
            tab6:UnlockHighlight()
        end
    end)
end

local function CreateAuxTabButton(anchor, label, tabId)
    local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btn:SetSize(80, 20)
    btn:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    btn:SetText(label)
    if btn:GetFontString() then
        btn:GetFontString():SetTextColor(1, 1, 1)
    end
    btn.tabId = tabId
    btn:SetScript("OnClick", function() SetTab(tabId) end)
    return btn
end

local auxStart = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
auxStart:SetSize(80, 20)
auxStart:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOM", -166, 31)
auxStart:SetText("Invites")
if auxStart:GetFontString() then
    auxStart:GetFontString():SetTextColor(1, 1, 1)
end
auxStart.tabId = 2
auxStart:SetScript("OnClick", function() SetTab(2) end)

local btnStats = CreateAuxTabButton(auxStart, "Stats", 4)
local btnGuild = CreateAuxTabButton(btnStats, "Guild", 5)
local btnSettings = CreateAuxTabButton(btnGuild, "Settings", 3)
local btnHistory = auxStart

ApplyMainLayoutForTab = function(tabId)
    contentPanel:ClearAllPoints()
    contentPanel:SetPoint("TOPLEFT", 10, -60)
    mainFrame:SetSize(520, 550)
    contentPanel:SetPoint("BOTTOMRIGHT", -10, 58)

    if not welcomeFrame:IsShown() then
        footerFrame:Show()
        auxStart:Show()
        btnStats:Show()
        btnGuild:Show()
        btnSettings:Show()
    end
end

SetWelcomeMode = function(enabled)
    if enabled then
        mainFrame:SetSize(520, 550)
        contentPanel:ClearAllPoints()
        contentPanel:SetPoint("TOPLEFT", 10, -60)
        contentPanel:SetPoint("BOTTOMRIGHT", -10, 58)
        contentPanel:Hide()
        quickFrame:Hide()
        footerFrame:Hide()
        tabQuick:Hide()
        tab1:Hide()
        tab6:Hide()
        mainFrame.quickModeBtn:Hide()
        auxStart:Hide()
        btnStats:Hide()
        btnGuild:Hide()
        btnSettings:Hide()

        scanView:Hide()
        quickView:Hide()
        historyView:Hide()
        settingsView:Hide()
        filtersView:Hide()
        statsView:Hide()
        guildStatsView:Hide()
        whispersView:Hide()

        welcomeFrame:Show()
    else
        contentPanel:Show()
        tabQuick:Show()
        tab1:Show()
        tab6:Show()
        mainFrame.quickModeBtn:Show()
        welcomeFrame:Hide()

        if ApplyMainLayoutForTab then
            ApplyMainLayoutForTab(currentTab or 1)
        end
    end
end

UpdateTabButtons = function()
    local primaryActive = {
        [8] = tabQuick,
        [1] = tab1,
        [6] = tab6
    }
    for id, btn in pairs(primaryActive) do
        if currentTab == id then
            btn:SetAlpha(1.0)
        else
            btn:SetAlpha(0.85)
        end
    end

    local auxTabs = { btnHistory, btnStats, btnGuild, btnSettings }
    for _, btn in ipairs(auxTabs) do
        if btn:GetFontString() then
            btn:GetFontString():SetTextColor(1, 1, 1)
        end
        if currentTab == btn.tabId then
            btn:SetAlpha(1.0)
        else
            btn:SetAlpha(0.85)
        end
    end
end

UpdateTabButtons()
-- =============================================================
-- 4. RESULTS VIEW (Tab 1 - New UI)
-- =============================================================

-- A. Zone Targeting UI Container
local targetUI = CreateFrame("Frame", nil, scanView, "BackdropTemplate")
targetUI:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
local TARGET_UI_COLLAPSED_HEIGHT = 80
targetUI:SetSize(500, TARGET_UI_COLLAPSED_HEIGHT)
targetUI:SetPoint("BOTTOM", 0, 0)

-- C. Specific Zone Dropdown
local ddLabel = targetUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ddLabel:SetText("Select Zone to Scan:")

local zoneDropDown = CreateFrame("Frame", "CogwheelRecruiterSpecificDropDown", targetUI, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(zoneDropDown, 150)
UIDropDownMenu_SetText(zoneDropDown, "Select a Zone...")

UIDropDownMenu_Initialize(zoneDropDown, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()

    if (level or 1) == 1 then
        -- Category Headers
        for i, catData in ipairs(ZONE_CATEGORIES) do
            info.text = catData.name
            info.menuList = i
            info.hasArrow = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        -- Clear Option
        info.text = "|cffff0000Clear Selection|r"
        info.menuList = nil
        info.hasArrow = false
        info.func = function()
            SelectedSpecificZone = nil
            UIDropDownMenu_SetText(zoneDropDown, "Select a Zone...")
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)

    elseif level == 2 then
        -- Zones inside Category
        local catIndex = menuList
        local catData = ZONE_CATEGORIES[catIndex]
        for _, zoneName in ipairs(catData.zones) do
            info.text = zoneName
            info.hasArrow = false
            info.notCheckable = false
            info.checked = (SelectedSpecificZone == zoneName)
            info.func = function()
                SelectedSpecificZone = zoneName
                UIDropDownMenu_SetText(zoneDropDown, zoneName)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end)

-- D. Scan Button
local scanBtn = CreateFrame("Button", nil, targetUI, "UIPanelButtonTemplate")
scanBtn:SetSize(110, 25)
scanBtn:SetText("Start Scan")
scanBtn:SetNormalFontObject("GameFontNormal")
scanBtn:SetHighlightFontObject("GameFontNormal")
scanBtn:SetDisabledFontObject("GameFontDisable")
scanBtn:SetScript("OnClick", function()
    if StartScanSequence then StartScanSequence() end
end)

local scanFiltersBtn = CreateFrame("Button", nil, targetUI, "UIPanelButtonTemplate")
scanFiltersBtn:SetSize(28, 25)
scanFiltersBtn:SetText("")
scanFiltersBtn:SetScript("OnClick", function()
    NS.filterReturnTab = 1
    SetTab(7)
end)
local scanFiltersIcon = scanFiltersBtn:CreateTexture(nil, "ARTWORK")
scanFiltersIcon:SetSize(16, 16)
scanFiltersIcon:SetPoint("CENTER")
scanFiltersIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
scanFiltersBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Filters", 1, 0.82, 0)
    GameTooltip:Show()
end)
scanFiltersBtn:SetScript("OnLeave", GameTooltip_Hide)

-- Center row: Zone dropdown + Start Scan + Filters
local scanControlsRow = CreateFrame("Frame", nil, targetUI)
scanControlsRow:SetSize(380, 28)
scanControlsRow:SetPoint("BOTTOM", targetUI, "BOTTOM", 0, 20)

zoneDropDown:ClearAllPoints()
scanBtn:ClearAllPoints()
scanFiltersBtn:ClearAllPoints()
ddLabel:ClearAllPoints()

zoneDropDown:SetPoint("LEFT", scanControlsRow, "LEFT", 0, 0)
scanBtn:SetPoint("LEFT", zoneDropDown, "RIGHT", -8, 2)
scanFiltersBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
ddLabel:SetPoint("BOTTOM", zoneDropDown, "TOP", 12, 2)

-- E. Results List (Scroll)
local scanScroll = CreateFrame("ScrollFrame", nil, scanView, "UIPanelScrollFrameTemplate")
scanScroll:SetPoint("TOPLEFT", 0, -5)
scanScroll:SetPoint("BOTTOMRIGHT", -25, 85)
local scanContent = CreateFrame("Frame", nil, scanScroll)
scanContent:SetSize(460, 1)
scanScroll:SetScrollChild(scanContent)

local scanResultsWatermark = scanView:CreateTexture(nil, "BACKGROUND")
scanResultsWatermark:SetPoint("CENTER", scanScroll, "CENTER", 5, 0)
scanResultsWatermark:SetSize(280, 280)
scanResultsWatermark:SetTexture("Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400")
scanResultsWatermark:SetAlpha(0.08)
if scanResultsWatermark.SetDesaturated then scanResultsWatermark:SetDesaturated(true) end

-- Helper: Create Row
local function CreateBaseRow(parent, isHistory)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(460, 30)

    -- 1. Name (Left)
    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("LEFT", 5, 0)
    nameText:SetWidth(150)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- 2. Button (Right)
    local actionBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
    actionBtn:SetSize(80, 22)
    actionBtn:SetPoint("RIGHT", -5, 0)
    actionBtn:SetNormalFontObject("GameFontNormalSmall")
    actionBtn:SetHighlightFontObject("GameFontHighlightSmall")
    actionBtn:SetDisabledFontObject("GameFontDisableSmall")
    row.actionBtn = actionBtn

    local whisperBtn
    if not isHistory then
        actionBtn:SetSize(72, 22)
        whisperBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        whisperBtn:SetSize(72, 22)
        whisperBtn:SetPoint("RIGHT", actionBtn, "LEFT", -5, 0)
        whisperBtn:SetNormalFontObject("GameFontNormalSmall")
        whisperBtn:SetHighlightFontObject("GameFontHighlightSmall")
        whisperBtn:SetDisabledFontObject("GameFontDisableSmall")
        whisperBtn:SetText("Whisper")
        row.whisperBtn = whisperBtn
    end

    -- 3. Info Text
    local infoText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    if isHistory then
        infoText:SetPoint("RIGHT", actionBtn, "LEFT", -15, 0)
        infoText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        infoText:SetJustifyH("RIGHT")
    else
        infoText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        infoText:SetPoint("RIGHT", whisperBtn, "LEFT", -6, 0)
        infoText:SetJustifyH("LEFT")
        if infoText.SetWordWrap then infoText:SetWordWrap(false) end
        if infoText.SetMaxLines then infoText:SetMaxLines(1) end
    end
    row.infoText = infoText

    return row
end
local QUICK_QUEUE_TARGET = 10
local QUICK_QUEUE_REFILL_AT = 2
local QUICK_QUEUE_MAX = 20
local QUICK_LEVEL_BALANCE_BUCKETS = 4

local quickUI = {}

quickUI.topTabsRow = CreateFrame("Frame", nil, quickFrame)
quickUI.topTabsRow:SetSize(190, 24)
quickUI.topTabsRow:SetPoint("TOP", quickFrame, "TOP", 0, -30)

quickUI.filtersTab = CreateFrame("Button", nil, quickUI.topTabsRow, "UIPanelButtonTemplate")
quickUI.filtersTab:SetSize(88, 24)
quickUI.filtersTab:SetPoint("LEFT", quickUI.topTabsRow, "LEFT", 0, 0)
quickUI.filtersTab:SetText("Filters")
quickUI.filtersTab:SetScript("OnClick", function()
    local qx, qy = quickFrame:GetCenter()
    NS.filterReturnTab = 8
    SetTab(7)
    if qx and qy then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", qx + 360, qy)
    end
    quickFrame:Show()
    quickView:Show()
end)

quickUI.whispersTab = CreateFrame("Button", nil, quickUI.topTabsRow, "UIPanelButtonTemplate")
quickUI.whispersTab:SetSize(96, 24)
quickUI.whispersTab:SetPoint("LEFT", quickUI.filtersTab, "RIGHT", 6, 0)
quickUI.whispersTab:SetText("Whispers")
quickUI.whispersTab:SetScript("OnClick", function()
    local qx, qy = quickFrame:GetCenter()
    SetTab(6)
    if qx and qy then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", qx + 360, qy)
    end
    quickFrame:Show()
    quickView:Show()
end)

quickUI.nameText = quickView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
quickUI.nameText:SetPoint("TOP", quickView, "TOP", 0, -24)
quickUI.nameText:SetText("No Candidate")

quickUI.levelText = quickView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
quickUI.levelText:SetPoint("TOP", quickUI.nameText, "BOTTOM", 0, -8)
quickUI.levelText:SetText("")

quickUI.queueText = quickView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
quickUI.queueText:SetPoint("BOTTOM", quickView, "BOTTOM", 0, 52)
quickUI.queueText:SetText("Queue: 0")
quickUI.queueText:SetTextColor(0.62, 0.62, 0.62)

quickUI.statusText = quickView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
quickUI.statusText:SetPoint("BOTTOM", quickView, "BOTTOM", 0, 34)
quickUI.statusText:SetWidth(290)
quickUI.statusText:SetJustifyH("CENTER")
quickUI.statusText:SetText("Press Next to start scanning.")
quickUI.statusText:SetTextColor(0.58, 0.58, 0.58)

quickUI.bottomRow = CreateFrame("Frame", nil, quickView)
quickUI.bottomRow:SetSize(290, 24)
quickUI.bottomRow:SetPoint("BOTTOM", quickView, "BOTTOM", 0, 4)

quickUI.nextBtn = CreateFrame("Button", nil, quickUI.bottomRow, "UIPanelButtonTemplate")
quickUI.nextBtn:SetSize(90, 24)
quickUI.nextBtn:SetPoint("LEFT", quickUI.bottomRow, "LEFT", 0, 0)
quickUI.nextBtn:SetText("Next")

quickUI.whisperBtn = CreateFrame("Button", nil, quickUI.bottomRow, "UIPanelButtonTemplate")
quickUI.whisperBtn:SetSize(94, 24)
quickUI.whisperBtn:SetPoint("LEFT", quickUI.nextBtn, "RIGHT", 6, 0)
quickUI.whisperBtn:SetText("Whisper")
quickUI.whisperBtn:Disable()

quickUI.inviteBtn = CreateFrame("Button", nil, quickUI.bottomRow, "UIPanelButtonTemplate")
quickUI.inviteBtn:SetSize(90, 24)
quickUI.inviteBtn:SetPoint("LEFT", quickUI.whisperBtn, "RIGHT", 6, 0)
quickUI.inviteBtn:SetText("Invite")
quickUI.inviteBtn:Disable()

local function ClearScanView()
    for _, row in ipairs(scanRows) do row:Hide() end
end

-- Updated to support accumulated results
local function UpdateScanList(results)
    ClearScanView()

    if not results or #results == 0 then return end

    local yOffset = 0
    local count = 0
    local canRecruit = PlayerCanRecruitNow()

    for i, data in ipairs(results) do
        local minLvl = settingsDB.minLevel or 1
        local maxLvl = settingsDB.maxLevel or MAX_PLAYER_LEVEL
        local classAllowed = settingsDB.classes[data.class]
        if classAllowed == nil then classAllowed = true end

        if data.level >= minLvl and data.level <= maxLvl and classAllowed then
            count = count + 1
            if not scanRows[count] then scanRows[count] = CreateBaseRow(scanContent, false) end

            local row = scanRows[count]
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:Show()

            local classTag = string.upper(data.class or "PRIEST")
            local color = RAID_CLASS_COLORS[classTag]
            if color then row.nameText:SetTextColor(color.r, color.g, color.b)
            else row.nameText:SetTextColor(1, 1, 1) end

            row.nameText:SetText(data.name)
            row.infoText:SetText("Lvl " .. data.level .. " (" .. (data.zone or "?") .. ")")

            local history = historyDB[data.name]
            local whisperKey = GetWhisperKey(data.name)
            local whisperState = whispersDB and whispersDB[whisperKey]

            row.actionBtn:SetText("Invite")
            row.actionBtn:Enable()
            row.whisperBtn:SetText("Whisper")
            row.whisperBtn:Enable()

            if whisperState and whisperState.lastOutbound then
                row.whisperBtn:SetText("Whispered")
                row.whisperBtn:Disable()
            end

            if history then
                if history.action == "DECLINED" then
                     row.infoText:SetText("Declined")
                     row.infoText:SetTextColor(1, 0, 0)
                     row.actionBtn:SetText("Retry")
                elseif history.action == "JOINED" then
                     row.infoText:SetText("Joined")
                     row.infoText:SetTextColor(0, 1, 0)
                     row.actionBtn:SetText("-")
                     row.actionBtn:Disable()
                     row.whisperBtn:SetText("-")
                     row.whisperBtn:Disable()
                else
                     row.infoText:SetText("Invited")
                     row.actionBtn:SetText("Invited")
                     row.actionBtn:Disable()
                end
            else
                 row.infoText:SetTextColor(1, 1, 1)
            end

            if not canRecruit then
                row.whisperBtn:Disable()
                row.actionBtn:Disable()
            end

            row.whisperBtn:SetScript("OnClick", function(self)
                if not PlayerCanRecruitNow() then
                    print("|cffff0000[Cogwheel]|r " .. RECRUIT_PERMISSION_REQUIRED_TEXT)
                    return
                end

                local sent = SendWhisperToPlayer(data.name, data.class)
                if sent then
                    self:SetText("Whispered")
                    self:Disable()
                    print("|cff00ff00[Cogwheel]|r Whisper sent to " .. data.name)
                end
            end)

            row.actionBtn:SetScript("OnClick", function(self)
                if not PlayerCanRecruitNow() then
                    print("|cffff0000[Cogwheel]|r " .. RECRUIT_PERMISSION_REQUIRED_TEXT)
                    return
                end

                if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(data.name)
                else GuildInvite(data.name) end

                self:SetText("Sent")
                self:Disable()

                historyDB[data.name] = {
                    time = time(),
                    action = "INVITED",
                    class = string.upper(data.class or "PRIEST"),
                    level = data.level
                }
                Analytics.RecordInviteSent(data.name, data.class, data.level)

                -- Update Stats
                if settingsDB.stats then settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1 end
            end)

            yOffset = yOffset + 30
        end
    end
    scanContent:SetHeight(yOffset)
end


-- =============================================================
-- 5. HISTORY VIEW (Tab 2)
-- =============================================================

local searchBox = CreateFrame("EditBox", nil, historyView, "InputBoxTemplate")
searchBox:SetSize(200, 20)
searchBox:SetPoint("TOPLEFT", 10, -5)
searchBox:SetAutoFocus(false)
searchBox:SetTextInsets(5, 0, 0, 0)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
searchBox:SetScript("OnTextChanged", function(self) UpdateHistoryList() end)

local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchPlaceholder:SetPoint("LEFT", 5, 0)
searchPlaceholder:SetText("Search Name...")
searchBox:SetScript("OnEditFocusGained", function(self) searchPlaceholder:Hide() end)
searchBox:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then searchPlaceholder:Show() end
end)

local historyHint = historyView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
historyHint:SetPoint("TOPLEFT", 220, -8)
historyHint:SetText("Showing last 50 invite outcomes")

local clearBtn = CreateFrame("Button", nil, historyView, "UIPanelButtonTemplate")
clearBtn:SetSize(140, 30)
clearBtn:SetPoint("BOTTOM", 0, 10)
clearBtn:SetText("Clear All History")
clearBtn:SetScript("OnClick", function()
    CogwheelRecruiterHistoryDB = {}
    historyDB = CogwheelRecruiterHistoryDB
    UpdateHistoryList()
    print("History Cleared.")
end)

local histScroll = CreateFrame("ScrollFrame", nil, historyView, "UIPanelScrollFrameTemplate")
histScroll:SetPoint("TOPLEFT", 0, -35)
histScroll:SetPoint("BOTTOMRIGHT", -25, 45)
local histContent = CreateFrame("Frame", nil, histScroll)
histContent:SetSize(420, 1)
histScroll:SetScrollChild(histContent)

local histRows = {}

local function CreateInviteHistoryRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(460, 32)

    row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 8, 0)
    row.nameText:SetWidth(170)
    row.nameText:SetJustifyH("LEFT")

    row.actionBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
    row.actionBtn:SetSize(84, 22)
    row.actionBtn:SetPoint("RIGHT", -6, 0)
    row.actionBtn:SetNormalFontObject("GameFontNormalSmall")
    row.actionBtn:SetHighlightFontObject("GameFontHighlightSmall")
    row.actionBtn:SetDisabledFontObject("GameFontDisableSmall")

    row.infoText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.infoText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)
    row.infoText:SetPoint("RIGHT", row.actionBtn, "LEFT", -8, 0)
    row.infoText:SetJustifyH("LEFT")

    return row
end

function UpdateHistoryList()
    for _, row in ipairs(histRows) do row:Hide() end

    local filter = searchBox:GetText():lower()

    local list = {}
    for name, data in pairs(historyDB) do
        local isValid = type(data) == "table" and type(data.time) == "number"
        if isValid and (filter == "" or name:lower():find(filter)) then
            table.insert(list, {name=name, data=data})
        end
    end
    table.sort(list, function(a,b) return a.data.time > b.data.time end)

    local yOffset = 0
    local count = 0
    local maxRows = math.min(#list, 50)

    for i = 1, maxRows do
        local item = list[i]
        count = count + 1
        if not histRows[count] then histRows[count] = CreateInviteHistoryRow(histContent) end

        local row = histRows[count]
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()

        local data = item.data
        local name = item.name

        local classTag = string.upper(data.class or "PRIEST")
        local color = RAID_CLASS_COLORS[classTag]
        if color then row.nameText:SetTextColor(color.r, color.g, color.b)
        else row.nameText:SetTextColor(1,1,1) end

        row.nameText:SetText(name)

        local dateStr = date("%m/%d %H:%M", data.time)
        if data.action == "DECLINED" then
            row.infoText:SetText("|cffff4040Declined|r  |cff8f8f8f" .. dateStr .. "|r")
        elseif data.action == "JOINED" then
            row.infoText:SetText("|cff6fdc6fJoined|r  |cff8f8f8f" .. dateStr .. "|r")
        else
            row.infoText:SetText("|cffffd56aInvited|r  |cff8f8f8f" .. dateStr .. "|r")
        end

        if data.action == "JOINED" then
            row.actionBtn:SetText("Member")
            row.actionBtn:Disable()
        else
            row.actionBtn:SetText("Re-Invite")
            row.actionBtn:Enable()
            row.actionBtn:SetScript("OnClick", function(self)
                if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(name)
                else GuildInvite(name) end

                historyDB[name].time = time()
                historyDB[name].action = "INVITED"
                Analytics.RecordInviteSent(name, historyDB[name].class, historyDB[name].level)
                UpdateHistoryList()
            end)
        end

        yOffset = yOffset + 32
    end
    histContent:SetHeight(yOffset)
end


-- =============================================================
-- 6. WHISPERS VIEW (Tab 6)
-- =============================================================

local whispersHeader = whispersView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
whispersHeader:SetPoint("TOPLEFT", 10, -10)
whispersHeader:SetText("Whisper Replies")

local whispersHint = whispersView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
whispersHint:SetPoint("TOPLEFT", 10, -32)
whispersHint:SetText("Incoming whisper replies from contacted players.")

local whispersScroll = CreateFrame("ScrollFrame", nil, whispersView, "UIPanelScrollFrameTemplate")
whispersScroll:SetPoint("TOPLEFT", 0, -50)
whispersScroll:SetPoint("BOTTOMRIGHT", -25, 10)
local whispersContent = CreateFrame("Frame", nil, whispersScroll)
whispersContent:SetSize(460, 1)
whispersScroll:SetScrollChild(whispersContent)

local whisperRows = {}

local function CreateWhisperRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(460, 48)

    row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.nameText:SetPoint("TOPLEFT", 5, -3)
    row.nameText:SetWidth(140)
    row.nameText:SetJustifyH("LEFT")

    row.timeText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.timeText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -2)
    row.timeText:SetWidth(140)
    row.timeText:SetJustifyH("LEFT")

    row.replyText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.replyText:SetPoint("TOPLEFT", 150, -5)
    row.replyText:SetPoint("BOTTOMRIGHT", -170, 5)
    row.replyText:SetJustifyH("LEFT")
    row.replyText:SetJustifyV("TOP")

    row.inviteBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
    row.inviteBtn:SetSize(75, 20)
    row.inviteBtn:SetPoint("TOPRIGHT", -85, -5)
    row.inviteBtn:SetText("Invite")
    row.inviteBtn:SetNormalFontObject("GameFontNormalSmall")
    row.inviteBtn:SetHighlightFontObject("GameFontHighlightSmall")
    row.inviteBtn:SetDisabledFontObject("GameFontDisableSmall")

    row.clearBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
    row.clearBtn:SetSize(75, 20)
    row.clearBtn:SetPoint("TOPRIGHT", -5, -5)
    row.clearBtn:SetText("Clear")
    row.clearBtn:SetNormalFontObject("GameFontNormalSmall")
    row.clearBtn:SetHighlightFontObject("GameFontHighlightSmall")
    row.clearBtn:SetDisabledFontObject("GameFontDisableSmall")

    return row
end

UpdateWhispersList = function()
    for _, row in ipairs(whisperRows) do row:Hide() end
    if not whispersDB then return end

    local list = {}
    for name, data in pairs(whispersDB) do
        if type(data) == "table" and data.lastInbound and data.lastInbound ~= "" then
            table.insert(list, { key = name, name = (data.displayName or name), data = data })
        end
    end
    table.sort(list, function(a, b)
        return (a.data.lastInboundTime or 0) > (b.data.lastInboundTime or 0)
    end)

    local yOffset = 0
    local count = 0
    for _, item in ipairs(list) do
        count = count + 1
        if not whisperRows[count] then whisperRows[count] = CreateWhisperRow(whispersContent) end
        local row = whisperRows[count]
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()

        row.nameText:SetText(item.name)
        row.timeText:SetText(date("%m/%d %H:%M", item.data.lastInboundTime or time()))
        row.replyText:SetText(item.data.lastInbound)
        local alreadyInvited = item.data.invited == true
        if alreadyInvited then
            row.inviteBtn:SetText("Invited")
            row.inviteBtn:Disable()
            row.inviteBtn:SetAlpha(0.6)
        else
            row.inviteBtn:SetText("Invite")
            row.inviteBtn:Enable()
            row.inviteBtn:SetAlpha(1.0)
        end

        row.inviteBtn:SetScript("OnClick", function(self)
            if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(item.name)
            else GuildInvite(item.name) end

            historyDB[item.name] = historyDB[item.name] or {}
            historyDB[item.name].time = time()
            historyDB[item.name].action = "INVITED"
            historyDB[item.name].class = historyDB[item.name].class or "PRIEST"
            Analytics.RecordInviteSent(item.name, historyDB[item.name].class, historyDB[item.name].level)
            if settingsDB.stats then settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1 end
            item.data.invited = true

            self:SetText("Invited")
            self:Disable()
            self:SetAlpha(0.6)
        end)

        row.clearBtn:SetScript("OnClick", function()
            whispersDB[item.key] = nil
            UpdateWhispersList()
        end)

        yOffset = yOffset + 50
    end

    whispersContent:SetHeight(yOffset)
end

-- =============================================================
-- 7. SETTINGS VIEW (Tab 3)
-- =============================================================

do
local settingsScroll = CreateFrame("ScrollFrame", nil, settingsView, "UIPanelScrollFrameTemplate")
settingsScroll:SetPoint("TOPLEFT", 0, -5)
settingsScroll:SetPoint("BOTTOMRIGHT", -25, 10)
local settingsContent = CreateFrame("Frame", nil, settingsScroll)
settingsContent:SetSize(460, 1)
settingsScroll:SetScrollChild(settingsContent)

local setHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
setHeader:SetPoint("TOPLEFT", 10, -10)
setHeader:SetText("Settings")

local whisperLabel = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
whisperLabel:SetPoint("TOPLEFT", 10, -38)
whisperLabel:SetText("Whisper Template:")

local whisperHelpBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
whisperHelpBtn:SetSize(18, 18)
whisperHelpBtn:SetPoint("LEFT", whisperLabel, "RIGHT", 6, 0)
whisperHelpBtn:SetText("i")
whisperHelpBtn:SetNormalFontObject("GameFontHighlightSmall")
whisperHelpBtn:SetHighlightFontObject("GameFontNormalSmall")

whisperHelpBtn:SetScript("OnEnter", function(self)
    local playerName = UnitName("player") or "Player"
    local guildName = GetGuildInfo("player") or "our guild"
    local _, playerClassFile = UnitClass("player")
    local playerClassName = NormalizeClassName(playerClassFile)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Whisper Template Tokens", 1, 0.82, 0)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("<character> or {character}", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Replaced with the target player's name.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Resolves now: " .. playerName, 0.5, 0.9, 0.5, true)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("<guild> or {guild}", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Replaced with your current guild name.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Resolves now: " .. guildName, 0.5, 0.9, 0.5, true)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("<class> or {class}", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Replaced with the target player's class.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Resolves now: " .. playerClassName, 0.5, 0.9, 0.5, true)
    GameTooltip:Show()
end)
whisperHelpBtn:SetScript("OnLeave", GameTooltip_Hide)

local whisperBoxFrame = CreateFrame("Frame", nil, settingsContent, "BackdropTemplate")
whisperBoxFrame:SetPoint("TOPLEFT", 10, -68)
whisperBoxFrame:SetSize(430, 76)
whisperBoxFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local whisperBox = CreateFrame("EditBox", nil, whisperBoxFrame)
whisperBox:SetPoint("TOPLEFT", 8, -8)
whisperBox:SetPoint("BOTTOMRIGHT", -8, 8)
whisperBox:SetAutoFocus(false)
whisperBox:SetTextInsets(5, 5, 0, 0)
whisperBox:SetMultiLine(true)
whisperBox:SetJustifyH("LEFT")
whisperBox:SetJustifyV("TOP")
whisperBox:SetMaxLetters(500)
whisperBox:SetFontObject("GameFontHighlight")

local whisperPreview = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
whisperPreview:SetPoint("TOPLEFT", 10, -148)
whisperPreview:SetWidth(430)
whisperPreview:SetJustifyH("LEFT")
whisperPreview:SetJustifyV("TOP")

local whisperCount = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
whisperCount:SetPoint("TOPLEFT", 10, -52)
whisperCount:SetWidth(430)
whisperCount:SetJustifyH("LEFT")

local function CountWords(text)
    local n = 0
    for _ in string.gmatch(text or "", "%S+") do n = n + 1 end
    return n
end

local function UpdateWhisperPreview()
    if not settingsDB then return end
    local template = settingsDB.whisperTemplate or ""
    local sampleTarget = UnitName("player") or "Player"
    local _, sampleClass = UnitClass("player")
    local preview = BuildWhisperMessage(sampleTarget, sampleClass)
    whisperPreview:SetText("Preview: " .. preview)

    local templateChars = string.len(template)
    local templateWords = CountWords(template)
    local previewChars = string.len(preview)
    whisperCount:SetText(string.format("Template: %d chars, %d words | Final: %d/%d chars", templateChars, templateWords, previewChars, MAX_WHISPER_CHARS))
    if previewChars > MAX_WHISPER_CHARS then
        whisperCount:SetTextColor(1, 0.2, 0.2)
    else
        whisperCount:SetTextColor(0.7, 0.9, 0.7)
    end
end

whisperBox:SetScript("OnShow", function(self)
    self:SetText(settingsDB.whisperTemplate or "")
    UpdateWhisperPreview()
end)
whisperBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
whisperBox:SetScript("OnTextChanged", function(self)
    if not settingsDB then return end
    settingsDB.whisperTemplate = self:GetText()
    UpdateWhisperPreview()
end)

local welcomeTop = -188
local welcomeHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
welcomeHeader:SetPoint("TOPLEFT", 10, welcomeTop)
welcomeHeader:SetText("Auto Welcome Message:")

local welcomeHelpBtn = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
welcomeHelpBtn:SetSize(18, 18)
welcomeHelpBtn:SetPoint("LEFT", welcomeHeader, "RIGHT", 6, 0)
welcomeHelpBtn:SetText("i")
welcomeHelpBtn:SetNormalFontObject("GameFontHighlightSmall")
welcomeHelpBtn:SetHighlightFontObject("GameFontNormalSmall")
welcomeHelpBtn:SetScript("OnEnter", function(self)
    local playerName = UnitName("player") or "Player"
    local guildName = GetGuildInfo("player") or "our guild"
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Welcome Message Tokens", 1, 0.82, 0)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("<character> or {character}", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Replaced with the new guild member's name.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Resolves now: " .. playerName, 0.5, 0.9, 0.5, true)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("<guild> or {guild}", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Replaced with your current guild name.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Resolves now: " .. guildName, 0.5, 0.9, 0.5, true)
    GameTooltip:Show()
end)
welcomeHelpBtn:SetScript("OnLeave", GameTooltip_Hide)

local welcomeEnabledCB = CreateFrame("CheckButton", nil, settingsContent, "UICheckButtonTemplate")
welcomeEnabledCB:SetPoint("TOPLEFT", 10, welcomeTop - 20)
welcomeEnabledCB:SetSize(24, 24)
welcomeEnabledCB.text = welcomeEnabledCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
welcomeEnabledCB.text:SetPoint("LEFT", welcomeEnabledCB, "RIGHT", 5, 0)
welcomeEnabledCB.text:SetText("Enable automatic guild welcome message")

local welcomeCount = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
welcomeCount:SetPoint("TOPLEFT", 10, welcomeTop - 40)
welcomeCount:SetWidth(430)
welcomeCount:SetJustifyH("LEFT")

local welcomeBoxFrame = CreateFrame("Frame", nil, settingsContent, "BackdropTemplate")
welcomeBoxFrame:SetPoint("TOPLEFT", 10, welcomeTop - 56)
welcomeBoxFrame:SetSize(430, 76)
welcomeBoxFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local welcomeBox = CreateFrame("EditBox", nil, welcomeBoxFrame)
welcomeBox:SetPoint("TOPLEFT", 8, -8)
welcomeBox:SetPoint("BOTTOMRIGHT", -8, 8)
welcomeBox:SetAutoFocus(false)
welcomeBox:SetTextInsets(5, 5, 0, 0)
welcomeBox:SetMultiLine(true)
welcomeBox:SetJustifyH("LEFT")
welcomeBox:SetJustifyV("TOP")
welcomeBox:SetMaxLetters(500)
welcomeBox:SetFontObject("GameFontHighlight")

local welcomePreview = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
welcomePreview:SetPoint("TOPLEFT", 10, welcomeTop - 136)
welcomePreview:SetWidth(430)
welcomePreview:SetJustifyH("LEFT")
welcomePreview:SetJustifyV("TOP")

local function UpdateWelcomePreview()
    if not settingsDB then return end
    local template = settingsDB.welcomeTemplate or ""
    local sampleTarget = UnitName("player") or "Player"
    local preview = BuildWelcomeMessage(sampleTarget)
    welcomePreview:SetText("Preview: " .. preview)

    local templateChars = string.len(template)
    local templateWords = CountWords(template)
    local previewChars = string.len(preview)
    welcomeCount:SetText(string.format("Template: %d chars, %d words | Final: %d/%d chars", templateChars, templateWords, previewChars, MAX_WHISPER_CHARS))
    if previewChars > MAX_WHISPER_CHARS then
        welcomeCount:SetTextColor(1, 0.2, 0.2)
    else
        welcomeCount:SetTextColor(0.7, 0.9, 0.7)
    end
end

welcomeEnabledCB:SetScript("OnShow", function(self)
    self:SetChecked(settingsDB and settingsDB.autoWelcomeEnabled == true)
end)
welcomeEnabledCB:SetScript("OnClick", function(self)
    if not settingsDB then return end
    settingsDB.autoWelcomeEnabled = self:GetChecked() == true
end)

welcomeBox:SetScript("OnShow", function(self)
    self:SetText(settingsDB.welcomeTemplate or "")
    UpdateWelcomePreview()
end)
welcomeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
welcomeBox:SetScript("OnTextChanged", function(self)
    if not settingsDB then return end
    settingsDB.welcomeTemplate = self:GetText()
    UpdateWelcomePreview()
end)


do -- FILTERS local scope
local saveFiltersBtn = CreateFrame("Button", nil, filtersView, "UIPanelButtonTemplate")
saveFiltersBtn:SetSize(94, 22)
saveFiltersBtn:SetPoint("BOTTOM", filtersView, "BOTTOM", 0, 10)
saveFiltersBtn:SetText("Save Filters")
saveFiltersBtn:SetScript("OnClick", function()
    if NS.ResetQuickScanState then
        NS.ResetQuickScanState()
    end
    local returnTab = NS.filterReturnTab
    if returnTab ~= 8 then returnTab = 1 end
    SetTab(returnTab)
end)

local filtersScroll = CreateFrame("ScrollFrame", nil, filtersView, "UIPanelScrollFrameTemplate")
filtersScroll:SetPoint("TOPLEFT", 0, -5)
filtersScroll:SetPoint("BOTTOMRIGHT", -25, 40)
local filtersContent = CreateFrame("Frame", nil, filtersScroll)
filtersContent:SetSize(460, 1)
filtersScroll:SetScrollChild(filtersContent)

local filtersHeader = filtersContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
filtersHeader:SetPoint("TOPLEFT", 10, -10)
filtersHeader:SetText("Filters")

-- Class Section
local classHeader = filtersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classHeader:SetPoint("TOPLEFT", 10, -38)
classHeader:SetText("Included Classes:")

local classCheckboxes = {}
local classStartY = -58
local classCols = {20, 160, 300}

for i, cls in ipairs(CLASS_LIST) do
    local cb = CreateFrame("CheckButton", nil, filtersContent, "UICheckButtonTemplate")
    local col = ((i - 1) % 3) + 1
    local row = math.floor((i - 1) / 3)
    cb:SetPoint("TOPLEFT", classCols[col], classStartY - (row * 24))
    cb:SetSize(24, 24)

    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(cls:sub(1,1)..cls:sub(2):lower())

    local c = RAID_CLASS_COLORS[cls]
    if c then cb.text:SetTextColor(c.r, c.g, c.b) end

    classCheckboxes[cls] = cb

    cb:SetScript("OnShow", function(self)
        self:SetChecked(settingsDB.classes[cls] == true)
    end)

    cb:SetScript("OnClick", function(self)
        settingsDB.classes[cls] = self:GetChecked()
    end)
end

-- Balance Button
local balBtn = CreateFrame("Button", nil, filtersContent, "UIPanelButtonTemplate")
balBtn:SetSize(220, 25)
local classRows = math.floor((#CLASS_LIST + 2) / 3)
local classBlockBottom = classStartY - ((classRows - 1) * 24) - 16
balBtn:SetPoint("TOPLEFT", 20, classBlockBottom - 18)
balBtn:SetText("Balance Guild Class Distribution")
balBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local counts, total = GetGuildClassCounts()
    if total == 0 then
        print("|cffff0000[Cogwheel]|r No guild data found. Please open Guild Statistics tab first or wait for data.")
        return
    end

    local sorted = {}
    for cls, count in pairs(counts) do table.insert(sorted, {cls=cls, count=count}) end
    -- Sort Ascending (Least popular first)
    table.sort(sorted, function(a,b) return a.count < b.count end)

    -- Select bottom 4 classes
    for _, cls in ipairs(CLASS_LIST) do settingsDB.classes[cls] = false end

    for i=1, 4 do
        if sorted[i] then settingsDB.classes[sorted[i].cls] = true end
    end

    -- Update UI
    for cls, cb in pairs(classCheckboxes) do cb:SetChecked(settingsDB.classes[cls]) end
    print("|cff00ff00[Cogwheel]|r Filters updated: Targeting 4 least popular classes.")
end)

-- Level Section (compact)
local levelTop = classBlockBottom - 56
local levelHeader = filtersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelHeader:SetPoint("TOPLEFT", 10, levelTop)
levelHeader:SetText("Level Range:")

local minGroup = CreateFrame("Frame", nil, filtersContent, "BackdropTemplate")
minGroup:SetPoint("TOPLEFT", 10, levelTop - 20)
minGroup:SetSize(206, 76)
minGroup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
minGroup:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
minGroup:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

local maxGroup = CreateFrame("Frame", nil, filtersContent, "BackdropTemplate")
maxGroup:SetPoint("LEFT", minGroup, "RIGHT", 8, 0)
maxGroup:SetSize(206, 76)
maxGroup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
maxGroup:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
maxGroup:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

local minLevelSlider = CreateFrame("Slider", "CogwheelRecruiterMinLevelSlider", filtersContent, "OptionsSliderTemplate")
minLevelSlider:SetPoint("TOPLEFT", minGroup, "TOPLEFT", 8, -22)
minLevelSlider:SetMinMaxValues(1, MAX_PLAYER_LEVEL)
minLevelSlider:SetValueStep(1)
minLevelSlider:SetObeyStepOnDrag(true)
minLevelSlider:SetWidth(186)
minLevelSlider:SetHeight(24)
_G[minLevelSlider:GetName() .. "Low"]:SetText("1")
_G[minLevelSlider:GetName() .. "High"]:SetText(tostring(MAX_PLAYER_LEVEL))
_G[minLevelSlider:GetName() .. "Text"]:SetText("Min")
minLevelSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
minLevelSlider:GetThumbTexture():SetSize(16, 24)

local maxLevelSlider = CreateFrame("Slider", "CogwheelRecruiterMaxLevelSlider", filtersContent, "OptionsSliderTemplate")
maxLevelSlider:SetPoint("TOPLEFT", maxGroup, "TOPLEFT", 8, -22)
maxLevelSlider:SetMinMaxValues(1, MAX_PLAYER_LEVEL)
maxLevelSlider:SetValueStep(1)
maxLevelSlider:SetObeyStepOnDrag(true)
maxLevelSlider:SetWidth(186)
maxLevelSlider:SetHeight(24)
_G[maxLevelSlider:GetName() .. "Low"]:SetText("1")
_G[maxLevelSlider:GetName() .. "High"]:SetText(tostring(MAX_PLAYER_LEVEL))
_G[maxLevelSlider:GetName() .. "Text"]:SetText("Max")
maxLevelSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
maxLevelSlider:GetThumbTexture():SetSize(16, 24)

local function CreateSliderTrack(slider, r, g, b)
    local trackBG = slider:CreateTexture(nil, "BACKGROUND")
    trackBG:SetPoint("LEFT", slider, "LEFT", 8, 0)
    trackBG:SetPoint("RIGHT", slider, "RIGHT", -8, 0)
    trackBG:SetHeight(8)
    trackBG:SetColorTexture(0.08, 0.08, 0.08, 0.9)

    local trackFill = slider:CreateTexture(nil, "ARTWORK")
    trackFill:SetPoint("LEFT", slider, "LEFT", 8, 0)
    trackFill:SetPoint("RIGHT", slider, "RIGHT", -8, 0)
    trackFill:SetHeight(4)
    trackFill:SetColorTexture(r, g, b, 0.95)
end

CreateSliderTrack(minLevelSlider, 0.2, 0.8, 0.2)
CreateSliderTrack(maxLevelSlider, 0.9, 0.7, 0.2)

local function CreateLevelBadge(anchorSlider)
    local badge = CreateFrame("Frame", nil, filtersContent, "BackdropTemplate")
    badge:SetSize(52, 20)
    badge:SetPoint("TOP", anchorSlider, "BOTTOM", 0, -1)
    badge:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    badge:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    badge:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)

    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1, 0.92, 0.45)
    return text
end

local minLevelValue = CreateLevelBadge(minLevelSlider)
local maxLevelValue = CreateLevelBadge(maxLevelSlider)

local syncingLevelSliders = false
local function RefreshLevelRangeText(changed)
    if not settingsDB then return end
    local minVal = math.floor((minLevelSlider:GetValue() or 1) + 0.5)
    local maxVal = math.floor((maxLevelSlider:GetValue() or MAX_PLAYER_LEVEL) + 0.5)

    if changed == "min" and minVal > maxVal then
        syncingLevelSliders = true
        maxLevelSlider:SetValue(minVal)
        syncingLevelSliders = false
        maxVal = minVal
    elseif changed == "max" and maxVal < minVal then
        syncingLevelSliders = true
        minLevelSlider:SetValue(maxVal)
        syncingLevelSliders = false
        minVal = maxVal
    end

    settingsDB.minLevel = minVal
    settingsDB.maxLevel = maxVal
    minLevelValue:SetText(tostring(minVal))
    maxLevelValue:SetText(tostring(maxVal))
end

local function InitializeLevelSlidersFromSettings()
    if not settingsDB then return end
    syncingLevelSliders = true
    minLevelSlider:SetValue(settingsDB.minLevel or 1)
    maxLevelSlider:SetValue(settingsDB.maxLevel or MAX_PLAYER_LEVEL)
    syncingLevelSliders = false
    RefreshLevelRangeText()
end

minLevelSlider:SetScript("OnValueChanged", function()
    if syncingLevelSliders then return end
    RefreshLevelRangeText("min")
end)

maxLevelSlider:SetScript("OnValueChanged", function()
    if syncingLevelSliders then return end
    RefreshLevelRangeText("max")
end)

local balLevelBtn = CreateFrame("Button", nil, filtersContent, "UIPanelButtonTemplate")
balLevelBtn:SetSize(220, 25)
balLevelBtn:SetPoint("TOPLEFT", 20, levelTop - 104)
balLevelBtn:SetText("Balance Guild Level Distribution")
balLevelBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local counts = GetGuildLevelCounts()
    local catList = {}
    for _, cat in ipairs(ZONE_CATEGORIES) do
        if cat.min > 0 then
            table.insert(catList, {
                name = cat.name,
                count = counts[cat.name] or 0,
                min = cat.min,
                max = cat.max
            })
        end
    end
    table.sort(catList, function(a,b) return a.count < b.count end)

    local newMin, newMax = MAX_PLAYER_LEVEL, 1
    local selectedNames = {}
    for i=1, 3 do
        if catList[i] then
            if catList[i].min < newMin then newMin = catList[i].min end
            if catList[i].max > newMax then newMax = catList[i].max end
            table.insert(selectedNames, catList[i].name)
        end
    end

    settingsDB.minLevel = newMin
    settingsDB.maxLevel = newMax
    InitializeLevelSlidersFromSettings()
    print("|cff00ff00[Cogwheel]|r Level range set to " .. newMin .. "-" .. newMax .. " (Targeting: " .. table.concat(selectedNames, ", ") .. ")")
end)


filtersView:HookScript("OnShow", function()
    InitializeLevelSlidersFromSettings()
end)

filtersContent:SetHeight(360)
end -- FILTERS local scope
-- History Retention (revamped)
local historyTop = welcomeTop - 168
local historyHeader = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
historyHeader:SetPoint("TOPLEFT", 10, historyTop)
historyHeader:SetText("History Retention:")

local historyInfo = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
historyInfo:SetPoint("TOPLEFT", 10, historyTop - 18)
historyInfo:SetText("Keep invite history for:")

local historyValue = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
historyValue:SetPoint("LEFT", historyInfo, "RIGHT", 8, 0)

local historyPresetButtons = {}
local function RefreshHistoryRetentionUI()
    if not settingsDB then return end
    local days = tonumber(settingsDB.historyRetentionDays) or 1
    settingsDB.historyRetentionDays = days
    historyValue:SetText(days .. " day" .. (days == 1 and "" or "s"))
    for _, b in ipairs(historyPresetButtons) do
        b:SetEnabled(b.days ~= days)
    end
end

local presetDays = {1, 3, 5, 7}
local prev
for _, days in ipairs(presetDays) do
    local b = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
    b:SetSize(44, 20)
    if prev then
        b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
    else
        b:SetPoint("TOPLEFT", 10, historyTop - 40)
    end
    b:SetText(tostring(days))
    b.days = days
    b:SetScript("OnClick", function()
        settingsDB.historyRetentionDays = days
        RefreshHistoryRetentionUI()
    end)
    table.insert(historyPresetButtons, b)
    prev = b
end

settingsView:HookScript("OnShow", function()
    RefreshHistoryRetentionUI()
    welcomeEnabledCB:SetChecked(settingsDB and settingsDB.autoWelcomeEnabled == true)
    if settingsDB then
        welcomeBox:SetText(settingsDB.welcomeTemplate or "")
    end
    UpdateWelcomePreview()
end)


settingsContent:SetHeight(400)
end -- SETTINGS/FILTERS local scope

-- =============================================================
-- 7. SCAN LOGIC (With Queue System)
-- =============================================================

local scanLogic = CreateFrame("Frame")
local isScanning = false
local isWaitingForWho = false
local scanQueue = {}
local currentScanZone = ""
local accumulatedResults = {}

local quickState = {
    isScanning = false,
    isWaitingForWho = false,
    scanQueue = {},
    currentScanZone = "",
    queue = {},
    seenNames = {},
    scannedZones = 0,
    totalZones = 0,
    refillTarget = QUICK_QUEUE_TARGET,
    currentCandidate = nil,
    quietZones = 0,
    maxQuietZones = 0,
    filterSignature = nil,
    nextLevelBucket = 1
}

local function QuickMatchesFilters(level, classToken)
    if not settingsDB then return true end

    local minLvl = settingsDB.minLevel or 1
    local maxLvl = settingsDB.maxLevel or MAX_PLAYER_LEVEL
    if level < minLvl or level > maxLvl then return false end

    local classTag = string.upper(classToken or "PRIEST")
    local classAllowed = settingsDB.classes and settingsDB.classes[classTag]
    if classAllowed == nil then classAllowed = true end
    return classAllowed
end
local function BuildQuickFilterSignature()
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or MAX_PLAYER_LEVEL
    local parts = { tostring(minLvl), tostring(maxLvl) }

    for _, cls in ipairs(CLASS_LIST) do
        local enabled = settingsDB and settingsDB.classes and settingsDB.classes[cls]
        if enabled == nil then enabled = true end
        parts[#parts + 1] = enabled and "1" or "0"
    end

    return table.concat(parts, ":")
end

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

local function GetPlayerFactionGroup()
    if not UnitFactionGroup then return nil end
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        return faction
    end
    return nil
end

local function ShouldSkipQuickZone(zone, minLvl, maxLvl, playerFaction)
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

local function GetQuickZoneFactionPriority(zone, cat, playerFaction, maxLvl)
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

    local catMin = tonumber(cat.min) or 0
    local catMax = tonumber(cat.max) or 0
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
local function SortQuickZoneBucket(bucket, kind)
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

local function BuildQuickZoneQueue()
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or MAX_PLAYER_LEVEL
    local filterCenter = (minLvl + maxLvl) / 2

    local inRange = {}
    local aboveRange = {}
    local belowRange = {}
    local misc = {}

    for _, cat in ipairs(ZONE_CATEGORIES) do
        if cat.zones and #cat.zones > 0 then
            local minCat = tonumber(cat.min) or 0
            local maxCat = tonumber(cat.max) or 0
            local hasLevelRange = minCat > 0 and maxCat > 0
            local anchor = hasLevelRange and ((minCat + maxCat) / 2) or 999
            local entry = {
                cat = cat,
                anchor = anchor,
                min = minCat,
                max = maxCat,
                distance = math.abs(anchor - filterCenter)
            }

            if hasLevelRange then
                local overlaps = (maxCat >= minLvl and minCat <= maxLvl)
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

    SortQuickZoneBucket(inRange, "inRange")
    SortQuickZoneBucket(belowRange, "belowRange")
    SortQuickZoneBucket(aboveRange, "aboveRange")
    SortQuickZoneBucket(misc, "misc")

    local orderedCats = {}
    for _, entry in ipairs(inRange) do table.insert(orderedCats, entry.cat) end
    for _, entry in ipairs(belowRange) do table.insert(orderedCats, entry.cat) end
    for _, entry in ipairs(aboveRange) do table.insert(orderedCats, entry.cat) end
    for _, entry in ipairs(misc) do table.insert(orderedCats, entry.cat) end

    local zones = {}
    local seenZones = {}
    local playerFaction = GetPlayerFactionGroup()

    for _, cat in ipairs(orderedCats) do
        local zoneEntries = {}
        for index, zone in ipairs(cat.zones) do
            if not ShouldSkipQuickZone(zone, minLvl, maxLvl, playerFaction) then
                table.insert(zoneEntries, {
                    zone = zone,
                    index = index,
                    priority = GetQuickZoneFactionPriority(zone, cat, playerFaction, maxLvl)
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
            end
        end
    end

    return zones
end

local function ResetQuickZoneQueue()
    quickState.scanQueue = BuildQuickZoneQueue()
    quickState.scannedZones = 0
    quickState.totalZones = #quickState.scanQueue
    quickState.seenNames = {}
    quickState.filterSignature = BuildQuickFilterSignature()
end

local function ResetQuickStateForFilterChange()
    quickState.isScanning = false
    quickState.isWaitingForWho = false
    quickState.currentScanZone = ""
    quickState.queue = {}
    quickState.currentCandidate = nil
    quickState.quietZones = 0
    quickState.maxQuietZones = 0
    quickState.nextLevelBucket = 1
    ResetQuickZoneQueue()
end

local function EnsureQuickStateMatchesFilters()
    if quickState.filterSignature == BuildQuickFilterSignature() then
        return false
    end
    ResetQuickStateForFilterChange()
    return true
end

NS.ResetQuickScanState = function()
    ResetQuickStateForFilterChange()
end

local function PopNextQuickZone()
    if #quickState.scanQueue == 0 then
        ResetQuickZoneQueue()
    end
    if #quickState.scanQueue == 0 then return nil end

    quickState.currentScanZone = table.remove(quickState.scanQueue, 1)
    quickState.scannedZones = quickState.scannedZones + 1
    return quickState.currentScanZone
end

local function IsCandidateInQuickQueue(name)
    if quickState.currentCandidate and quickState.currentCandidate.name == name then
        return true
    end
    for _, entry in ipairs(quickState.queue) do
        if entry.name == name then
            return true
        end
    end
    return false
end

local function UpdateQuickCandidateCard(statusText)
    local candidate = quickState.currentCandidate
    quickUI.queueText:SetText("Queue: " .. #quickState.queue)

    if candidate then
        local classTag = string.upper(candidate.class or "PRIEST")
        local color = RAID_CLASS_COLORS[classTag]
        if color then
            quickUI.nameText:SetTextColor(color.r, color.g, color.b)
        else
            quickUI.nameText:SetTextColor(1, 1, 1)
        end
        quickUI.nameText:SetText(candidate.name or "?")
        quickUI.levelText:SetText("Level " .. tostring(candidate.level or 0))
    else
        quickUI.nameText:SetTextColor(1, 1, 1)
        quickUI.nameText:SetText("No Candidate")
        quickUI.levelText:SetText("")
    end

    local whisperEnabled = false
    local inviteEnabled = false
    if candidate then
        whisperEnabled = true
        inviteEnabled = true

        local history = historyDB and historyDB[candidate.name]
        local whisperState = whispersDB and whispersDB[GetWhisperKey(candidate.name)]

        if history then
            if history.action == "JOINED" then
                whisperEnabled = false
                inviteEnabled = false
            elseif history.action == "INVITED" then
                inviteEnabled = false
            end
        end
        if whisperState and whisperState.lastOutbound then
            whisperEnabled = false
        end
    end

    if not PlayerCanRecruitNow() then
        whisperEnabled = false
        inviteEnabled = false
    end

    if whisperEnabled then quickUI.whisperBtn:Enable() else quickUI.whisperBtn:Disable() end
    if inviteEnabled then quickUI.inviteBtn:Enable() else quickUI.inviteBtn:Disable() end

    if quickState.isWaitingForWho then
        quickUI.nextBtn:SetText("Scanning...")
        quickUI.nextBtn:Disable()
    else
        quickUI.nextBtn:SetText("Next")
        quickUI.nextBtn:Enable()
    end

    if statusText and statusText ~= "" then
        quickUI.statusText:SetText(statusText)
    elseif candidate then
        quickUI.statusText:SetText("Use Next to move through queued candidates.")
    elseif quickState.isScanning then
        quickUI.statusText:SetText("Building candidate queue...")
    else
        quickUI.statusText:SetText("Press Next to start scanning.")
    end
end

local function GetQuickLevelBucketCount()
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or MAX_PLAYER_LEVEL
    local span = math.max((maxLvl - minLvl + 1), 1)
    return math.max(math.min(QUICK_LEVEL_BALANCE_BUCKETS, span), 1)
end

local function GetQuickLevelBucketIndex(level)
    local minLvl = (settingsDB and settingsDB.minLevel) or 1
    local maxLvl = (settingsDB and settingsDB.maxLevel) or MAX_PLAYER_LEVEL
    local bucketCount = GetQuickLevelBucketCount()
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

local function PromoteNextQuickCandidate()
    local queueCount = #quickState.queue
    if queueCount == 0 then
        quickState.currentCandidate = nil
        return
    end

    local bucketCount = GetQuickLevelBucketCount()
    if (quickState.nextLevelBucket or 0) < 1 or quickState.nextLevelBucket > bucketCount then
        quickState.nextLevelBucket = 1
    end

    local selectedIndex
    for offset = 0, bucketCount - 1 do
        local targetBucket = ((quickState.nextLevelBucket + offset - 1) % bucketCount) + 1
        for i, entry in ipairs(quickState.queue) do
            local bucket = GetQuickLevelBucketIndex(entry.level or 0)
            if bucket == targetBucket then
                selectedIndex = i
                quickState.nextLevelBucket = (targetBucket % bucketCount) + 1
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

    quickState.currentCandidate = table.remove(quickState.queue, selectedIndex)
end

local function GetQuickCandidateCount()
    return #quickState.queue + (quickState.currentCandidate and 1 or 0)
end

local ProcessNextQuickZone

local function FinishQuickRefill(statusText)
    quickState.isScanning = false
    quickState.isWaitingForWho = false
    if not quickState.currentCandidate and #quickState.queue > 0 then PromoteNextQuickCandidate() end
    UpdateQuickCandidateCard(statusText)
end

local function CollectQuickWhoResults()
    local added = 0
    local num = C_FriendList.GetNumWhoResults()

    for i = 1, num do
        local info = C_FriendList.GetWhoInfo(i)
        local name, guild, level, cls, zone

        if type(info) == "table" then
            name = info.fullName or info.name
            guild = info.fullGuildName or info.guild or ""
            level = info.level or 0
            cls = info.filename or info.classFilename or "PRIEST"
            zone = info.area or quickState.currentScanZone
        else
            name, guild, level, _, _, zone, cls = C_FriendList.GetWhoInfo(i)
            if not name then name, guild, level, _, _, zone, cls = GetWhoInfo(i) end
        end

        if not guild then guild = "" end

        if guild == "" and name and QuickMatchesFilters(level or 0, cls) and not quickState.seenNames[name] and not IsCandidateInQuickQueue(name) then
            local history = historyDB and historyDB[name]
            if not (history and history.action == "JOINED") then
                quickState.seenNames[name] = true
                table.insert(quickState.queue, {
                    name = name,
                    level = level or 0,
                    class = string.upper(cls or "PRIEST"),
                    zone = zone or quickState.currentScanZone
                })
                added = added + 1
                if #quickState.queue >= QUICK_QUEUE_MAX then
                    break
                end
            end
        end
    end

    return added
end

local function RequestQuickQueueRefill(targetCount)
    if quickState.isScanning then return end

    if EnsureQuickStateMatchesFilters() then
        UpdateQuickCandidateCard("Filters changed. Rebuilding queue...")
    end

    if isScanning then
        print("|cffff0000[Cogwheel]|r Standard scan in progress. Finish it before using Quick Scanner.")
        return
    end

    local target = targetCount or QUICK_QUEUE_TARGET
    if GetQuickCandidateCount() >= target then
        if not quickState.currentCandidate then
            PromoteNextQuickCandidate()
        end
        UpdateQuickCandidateCard()
        return
    end

    if #quickState.scanQueue == 0 then
        ResetQuickZoneQueue()
    end
    if #quickState.scanQueue == 0 then
        UpdateQuickCandidateCard("No zones available for current filters.")
        return
    end

    quickState.refillTarget = math.min(target, QUICK_QUEUE_MAX)
    quickState.isScanning = true
    quickState.isWaitingForWho = false
    quickState.quietZones = 0
    quickState.maxQuietZones = math.max(quickState.totalZones, 1) * 2

    ProcessNextQuickZone()
end

local quickWhoListener = CreateFrame("Frame")
quickWhoListener:Hide()
quickWhoListener:SetScript("OnEvent", function(self, event)
    if event ~= "WHO_LIST_UPDATE" then return end

    quickState.isWaitingForWho = false
    self:UnregisterEvent("WHO_LIST_UPDATE")
    self:Hide()
    if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

    local added = CollectQuickWhoResults()
    if added > 0 then
        quickState.quietZones = 0
    else
        quickState.quietZones = quickState.quietZones + 1
    end


    if GetQuickCandidateCount() >= quickState.refillTarget or GetQuickCandidateCount() >= QUICK_QUEUE_MAX then
        FinishQuickRefill("Queue ready.")
        return
    end

    if quickState.quietZones >= quickState.maxQuietZones then
        FinishQuickRefill("No matching players found for current filters.")
        return
    end

    if not quickState.currentCandidate and #quickState.queue > 0 then PromoteNextQuickCandidate() end
    quickState.isScanning = false
    UpdateQuickCandidateCard(string.format("Queue %d/%d. Click Next to continue scanning.", GetQuickCandidateCount(), quickState.refillTarget))
end)

ProcessNextQuickZone = function()
    if not quickState.isScanning or quickState.isWaitingForWho then return end

    if InCombatLockdown and InCombatLockdown() then
        FinishQuickRefill("Cannot run /who while in combat. Click Next after combat.")
        return
    end

    local zone = PopNextQuickZone()
    if not zone then
        FinishQuickRefill("No zones available for current filters.")
        return
    end

    UpdateQuickCandidateCard(string.format("Scanning %s...", zone))

    if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end
    quickWhoListener:RegisterEvent("WHO_LIST_UPDATE")
    quickWhoListener:Show()
    quickState.isWaitingForWho = true

    C_FriendList.SendWho(zone)

    C_Timer.After(10.0, function()
        if quickState.isScanning and quickState.isWaitingForWho and quickState.currentScanZone == zone then
            quickState.isWaitingForWho = false
            quickWhoListener:UnregisterEvent("WHO_LIST_UPDATE")
            quickWhoListener:Hide()
            if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

            quickState.quietZones = quickState.quietZones + 1
            quickState.isScanning = false
            UpdateQuickCandidateCard("Scan timed out. Click Next to continue.")
        end
    end)
end

quickUI.nextBtn:SetScript("OnClick", function()
    if quickState.isWaitingForWho then return end

    if EnsureQuickStateMatchesFilters() then
        UpdateQuickCandidateCard("Filters changed. Rebuilding queue...")
    end

    if quickState.currentCandidate then
        if #quickState.queue > 0 then
            PromoteNextQuickCandidate()
        else
            quickState.currentCandidate = nil
        end
    elseif #quickState.queue > 0 then
        PromoteNextQuickCandidate()
    end

    if not quickState.currentCandidate and #quickState.queue == 0 then
        RequestQuickQueueRefill(QUICK_QUEUE_TARGET)
        return
    end


    UpdateQuickCandidateCard()
end)

quickUI.whisperBtn:SetScript("OnClick", function()
    local candidate = quickState.currentCandidate
    if not candidate then return end
    if not PlayerCanRecruitNow() then
        UpdateQuickCandidateCard(RECRUIT_PERMISSION_REQUIRED_TEXT)
        return
    end

    local sent = SendWhisperToPlayer(candidate.name, candidate.class)
    if sent then
        UpdateQuickCandidateCard("Whisper sent to " .. candidate.name)
    end
end)

quickUI.inviteBtn:SetScript("OnClick", function()
    local candidate = quickState.currentCandidate
    if not candidate then return end
    if not PlayerCanRecruitNow() then
        UpdateQuickCandidateCard(RECRUIT_PERMISSION_REQUIRED_TEXT)
        return
    end

    if C_GuildInfo and C_GuildInfo.Invite then C_GuildInfo.Invite(candidate.name)
    else GuildInvite(candidate.name) end

    historyDB[candidate.name] = {
        time = time(),
        action = "INVITED",
        class = string.upper(candidate.class or "PRIEST"),
        level = candidate.level
    }
    Analytics.RecordInviteSent(candidate.name, candidate.class, candidate.level)

    if settingsDB and settingsDB.stats then
        settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1
    end


    UpdateQuickCandidateCard("Invitation sent to " .. candidate.name)
end)

UpdateQuickCandidateCard()
scanLogic:RegisterEvent("CHAT_MSG_SYSTEM")
scanLogic:RegisterEvent("CHAT_MSG_WHISPER")
scanLogic:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        local key = GetWhisperKey(sender)
        local hasTrackedOutbound = analyticsDB and analyticsDB.pendingWhispers and analyticsDB.pendingWhispers[key]

        if key and key ~= "" and ((whispersDB and whispersDB[key] and whispersDB[key].lastOutbound) or hasTrackedOutbound) then
            if whispersDB then
                whispersDB[key] = whispersDB[key] or {}
                whispersDB[key].lastInbound = msg
                whispersDB[key].lastInboundTime = time()
                whispersDB[key].sender = sender
                whispersDB[key].displayName = whispersDB[key].displayName or GetShortName(sender)
            end
            Analytics.RecordWhisperAnswered(sender)
            if StartWhispersTabFlash and currentTab ~= 6 then StartWhispersTabFlash() end
            if whispersView:IsVisible() and UpdateWhispersList then UpdateWhispersList() end
        end
        return
    end

    local msg = ...
    local declinedName = string.match(msg, "^(.*) declines guild invitation")

    if declinedName and historyDB[declinedName] then
        historyDB[declinedName].action = "DECLINED"
        historyDB[declinedName].time = time()
        Analytics.ClearPendingInvite(declinedName)
        print("|cffff0000[Cogwheel]|r Detected decline: " .. declinedName)
    end

    local joinedName = string.match(msg, "^(.*) has joined the guild")
    if joinedName then
        local existing = historyDB[joinedName] or {}
        Analytics.RecordInviteAccepted(joinedName, existing.class, existing.level, existing.action)
        historyDB[joinedName] = {
            action = "JOINED",
            time = time(),
            class = existing.class or "PRIEST",
            level = existing.level
        }
        if settingsDB and settingsDB.stats then settingsDB.stats.joined = (settingsDB.stats.joined or 0) + 1 end
        print("|cff00ff00[Cogwheel]|r " .. joinedName .. " joined!")
        if settingsDB and settingsDB.autoWelcomeEnabled then
            SendDelayedWelcomeMessage(joinedName)
        end
    end
end)

-- Helper: Get list of zones to scan
local function GetZonesToScan()
    local zones = {}

    -- Priority: Specific Zone
    if SelectedSpecificZone then
        table.insert(zones, SelectedSpecificZone)
        return zones
    end

    -- Fallback: Current Zone if nothing selected
    if #zones == 0 then
        table.insert(zones, GetZoneText())
    end

    return zones
end

-- Forward declaration
local ProcessNextScan

-- Dedicated listener frame (Created once to avoid memory leaks)
local whoListener = CreateFrame("Frame")
whoListener:Hide()

whoListener:SetScript("OnEvent", function(self, event)
    if event == "WHO_LIST_UPDATE" then
        isWaitingForWho = false
        self:UnregisterEvent("WHO_LIST_UPDATE")
        self:Hide()

        -- Restore default UI behavior
        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

        local num = C_FriendList.GetNumWhoResults()

        -- Collect Results
        for i=1, num do
            local info = C_FriendList.GetWhoInfo(i)
            local name, guild, level, cls, zone

            if type(info) == "table" then
                name = info.fullName or info.name
                guild = info.fullGuildName or info.guild or ""
                level = info.level or 0
                cls = info.filename or info.classFilename or "PRIEST"
                zone = info.area or currentScanZone -- Fallback to scanned zone
            else
                name, guild, level, _, _, zone, cls = C_FriendList.GetWhoInfo(i)
                if not name then name, guild, level, _, _, zone, cls = GetWhoInfo(i) end
            end

            if not guild then guild = "" end

            -- Add if no guild and valid name
            if guild == "" and name then
                -- Avoid duplicates if scanning overlapping areas
                local exists = false
                for _, existing in ipairs(accumulatedResults) do
                    if existing.name == name then exists = true break end
                end

                if not exists then
                    table.insert(accumulatedResults, {
                        name = name,
                        level = level,
                        class = string.upper(cls or "PRIEST"),
                        zone = zone
                    })
                end
            end
        end

        -- Update UI
        UpdateScanList(accumulatedResults)

        -- Cooldown before next action
        scanBtn:SetText("Cooldown...")

        C_Timer.After(5.0, function()
            -- Check for next zone
            if #scanQueue > 0 then
                scanBtn:SetText("Scan Next: " .. scanQueue[1])
                scanBtn:Enable()
                print("|cff00ff00[Cogwheel]|r Zone scanned. Click button to scan next zone.")
            else
                isScanning = false
                scanBtn:SetText("Start Scan")
                scanBtn:Enable()

                local visibleCount = 0
                for _, data in ipairs(accumulatedResults) do
                    local minLvl = settingsDB.minLevel or 1
                    local maxLvl = settingsDB.maxLevel or MAX_PLAYER_LEVEL
                    local classAllowed = settingsDB.classes[data.class]
                    if classAllowed == nil then classAllowed = true end
                    if data.level >= minLvl and data.level <= maxLvl and classAllowed then
                        visibleCount = visibleCount + 1
                    end
                end
                print("|cff00ff00[Cogwheel]|r Scan Complete. Found " .. #accumulatedResults .. " unguilded players (" .. visibleCount .. " visible).")
            end
        end)
    end
end)

ProcessNextScan = function()
    currentScanZone = table.remove(scanQueue, 1)

    -- Status Update
    scanBtn:SetText("Scanning...")
    print("|cff00ff00[Cogwheel]|r Scanning: " .. currentScanZone .. "...")

    -- Unregister friend list events temporarily to avoid spam/interference
    if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end

    -- Register listener
    whoListener:RegisterEvent("WHO_LIST_UPDATE")
    whoListener:Show()

    isWaitingForWho = true

    -- Send query (Zone name)
    C_FriendList.SendWho(currentScanZone)

    -- Timeout Watchdog (10s)
    C_Timer.After(10.0, function()
        if isWaitingForWho then
            isWaitingForWho = false
            print("|cffff0000[Cogwheel]|r Scan timed out (server didn't respond). Resetting...")

            whoListener:UnregisterEvent("WHO_LIST_UPDATE")
            whoListener:Hide()
            if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

            if #scanQueue > 0 then
                scanBtn:SetText("Scan Next: " .. scanQueue[1])
            else
                isScanning = false
                scanBtn:SetText("Start Scan")
            end
            scanBtn:Enable()
        end
    end)
end

function StartScanSequence()
    if quickState.isScanning then
        print("|cffff0000[Cogwheel]|r Quick Scanner is running. Please wait for it to complete.")
        return
    end

    -- Resume scan if in progress
    if isScanning and #scanQueue > 0 then
        scanBtn:Disable()
        ProcessNextScan()
        return
    end

    if isScanning then return end

    scanQueue = GetZonesToScan()
    if #scanQueue == 0 then return end

    isScanning = true
    accumulatedResults = {} -- Clear previous results
    ClearScanView()
    scanBtn:Disable()

    ProcessNextScan()
end

-- =============================================================
-- 8. MINIMAP BUTTON
-- =============================================================
local minimapBtn = CreateFrame("Button", "CogwheelRecruiterMinimapButton", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameLevel(8)
minimapBtn:SetPoint("CENTER", Minimap, "CENTER", -56, -56)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("CENTER")

local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterIcon_64x64")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

local minimapWasDragging = false

minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:SetScript("OnClick", function(self, button)
    if minimapWasDragging then
        minimapWasDragging = false
        return
    end

    if button == "LeftButton" then
        ShowAddonWindow(true)
        if not welcomeFrame:IsShown() then
            SetTab(1)
        end
    elseif button == "RightButton" then
        OpenQuickScannerWindow()
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Cogwheel Recruiter")
    GameTooltip:AddLine("Left-click: Open Scanner Mode", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Open Quick Scanner Mode", 1, 1, 1)
    GameTooltip:AddLine("Shift + Right-drag: Move minimap icon", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", GameTooltip_Hide)

UpdateMinimapPosition = function()
    if not settingsDB or not settingsDB.minimapPos then return end
    local angle = math.rad(settingsDB.minimapPos)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:SetMovable(true)
minimapBtn:RegisterForDrag("RightButton")
minimapBtn:SetScript("OnDragStart", function(self)
    if not IsShiftKeyDown() then
        return
    end

    minimapWasDragging = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        settingsDB.minimapPos = angle
        UpdateMinimapPosition()
    end)
end)
minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

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
