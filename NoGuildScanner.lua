-- =============================================================
-- 1. SETUP & VARIABLES
-- =============================================================
local addonName = "NoGuildScanner"
local historyDB -- Shortcut to NoGuildHistoryDB
local settingsDB -- Shortcut to NoGuildSettingsDB
local UpdateMinimapPosition -- Forward declaration

local CLASS_LIST = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

-- Create Main Window
local mainFrame = CreateFrame("Frame", "NoGuildFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(480, 550) -- Increased width for single line text
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide()

mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY")
mainFrame.title:SetFontObject("GameFontHighlight")
mainFrame.title:SetPoint("CENTER", mainFrame.TitleBg, "CENTER", 0, 0)
mainFrame.title:SetText("NoGuild Scanner")

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if NoGuildHistoryDB == nil then NoGuildHistoryDB = {} end
        historyDB = NoGuildHistoryDB

        if NoGuildSettingsDB == nil then NoGuildSettingsDB = {} end
        settingsDB = NoGuildSettingsDB

        if not settingsDB.minLevel then settingsDB.minLevel = 1 end
        if not settingsDB.maxLevel then settingsDB.maxLevel = 80 end

        if not settingsDB.classes then settingsDB.classes = {} end
        for _, cls in ipairs(CLASS_LIST) do
            if settingsDB.classes[cls] == nil then settingsDB.classes[cls] = true end
        end

        if not settingsDB.stats then settingsDB.stats = { invited = 0, joined = 0 } end

        if not settingsDB.historyRetentionDays then settingsDB.historyRetentionDays = 1 end

        if not settingsDB.minimapPos then settingsDB.minimapPos = 45 end
        if UpdateMinimapPosition then UpdateMinimapPosition() end

        -- Cleanup old history
        local cutoff = time() - (settingsDB.historyRetentionDays * 86400)
        for name, data in pairs(historyDB) do
            if data.time < cutoff then historyDB[name] = nil end
        end
    end
end)

-- =============================================================
-- 2. ZONE DATA (Structured for New UI)
-- =============================================================
local ZONE_CATEGORIES = {
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
        min = 0, max = 0, color = {r=0.5, g=0.5, b=0.5} -- Ignored for stats usually
    }
}

-- Selection State
local SelectedCategories = {}
local SelectedSpecificZone = nil

-- =============================================================
-- 3. TABS SETUP
-- =============================================================
local currentTab = 1
local scanRows = {}

local scanView = CreateFrame("Frame", nil, mainFrame)
scanView:SetPoint("TOPLEFT", 10, -60)
scanView:SetPoint("BOTTOMRIGHT", -10, 10)

local historyView = CreateFrame("Frame", nil, mainFrame)
historyView:SetPoint("TOPLEFT", 10, -60)
historyView:SetPoint("BOTTOMRIGHT", -10, 10)
historyView:Hide()

local settingsView = CreateFrame("Frame", nil, mainFrame)
settingsView:SetPoint("TOPLEFT", 10, -60)
settingsView:SetPoint("BOTTOMRIGHT", -10, 10)
settingsView:Hide()

local statsView = CreateFrame("Frame", nil, mainFrame)
statsView:SetPoint("TOPLEFT", 10, -60)
statsView:SetPoint("BOTTOMRIGHT", -10, 10)
statsView:Hide()

local guildStatsView = CreateFrame("Frame", nil, mainFrame)
guildStatsView:SetPoint("TOPLEFT", 10, -60)
guildStatsView:SetPoint("BOTTOMRIGHT", -10, 10)
guildStatsView:Hide()

local gsTitle = guildStatsView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
gsTitle:SetPoint("TOPLEFT", 20, -15)
gsTitle:SetText("Active Guild Members (Last 7 Days)")

-- Dropdowns for Stats
local currentStatsMode = "CLASS" -- "CLASS" or "LEVEL"
local currentVisMode = "BAR" -- "MOSAIC" or "BAR"

local statsTypeDD = CreateFrame("Frame", "NoGuildStatsTypeDD", guildStatsView, "UIDropDownMenuTemplate")
statsTypeDD:SetPoint("TOPLEFT", 0, -35)
UIDropDownMenu_SetWidth(statsTypeDD, 100)
UIDropDownMenu_Initialize(statsTypeDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "By Class"
    info.checked = (currentStatsMode == "CLASS")
    info.func = function() currentStatsMode = "CLASS"; UIDropDownMenu_SetText(statsTypeDD, "By Class"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)

    info.text = "By Level"
    info.checked = (currentStatsMode == "LEVEL")
    info.func = function() currentStatsMode = "LEVEL"; UIDropDownMenu_SetText(statsTypeDD, "By Level"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)
end)
UIDropDownMenu_SetText(statsTypeDD, "By Class")

local statsVisDD = CreateFrame("Frame", "NoGuildStatsVisDD", guildStatsView, "UIDropDownMenuTemplate")
statsVisDD:SetPoint("LEFT", statsTypeDD, "RIGHT", -20, 0)
UIDropDownMenu_SetWidth(statsVisDD, 120)
UIDropDownMenu_Initialize(statsVisDD, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "Mosaic"
    info.checked = (currentVisMode == "MOSAIC")
    info.func = function() currentVisMode = "MOSAIC"; UIDropDownMenu_SetText(statsVisDD, "Mosaic"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)

    info.text = "Stacked Bar"
    info.checked = (currentVisMode == "BAR")
    info.func = function() currentVisMode = "BAR"; UIDropDownMenu_SetText(statsVisDD, "Stacked Bar"); if UpdateGuildStats then UpdateGuildStats() end end
    UIDropDownMenu_AddButton(info)
end)
UIDropDownMenu_SetText(statsVisDD, "Stacked Bar")

local gsContainer = CreateFrame("Frame", nil, guildStatsView)
gsContainer:SetPoint("TOPLEFT", 20, -80)
gsContainer:SetPoint("BOTTOMRIGHT", -20, 20)

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
                if y and (y == 0 and m == 0 and d <= 7) then active = true end
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
                if y and (y == 0 and m == 0 and d <= 7) then active = true end
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

UpdateGuildStats = function()
    if not guildStatsView:IsVisible() then return end

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

local statInvitedText, statJoinedText

local function UpdateStatsView()
    if not settingsDB or not settingsDB.stats then return end
    if not statInvitedText then
        -- Create elements on first load
        local font = "GameFontNormalHuge"
        statInvitedText = statsView:CreateFontString(nil, "OVERLAY", font)
        statInvitedText:SetPoint("CENTER", 0, 40)

        statJoinedText = statsView:CreateFontString(nil, "OVERLAY", font)
        statJoinedText:SetPoint("CENTER", 0, -40)
        statJoinedText:SetTextColor(0, 1, 0)
    end

    statInvitedText:SetText("Total Invited: " .. (settingsDB.stats.invited or 0))
    statJoinedText:SetText("Total Joined: " .. (settingsDB.stats.joined or 0))
end

local function SetTab(id)
    currentTab = id
    scanView:Hide()
    historyView:Hide()
    settingsView:Hide()
    statsView:Hide()
    guildStatsView:Hide()

    if id == 1 then
        scanView:Show()
    elseif id == 2 then
        historyView:Show()
        if UpdateHistoryList then UpdateHistoryList() end
    elseif id == 3 then
        settingsView:Show()
    elseif id == 4 then
        statsView:Show()
        UpdateStatsView()
    elseif id == 5 then
        guildStatsView:Show()
        UpdateGuildStats()
        if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
    end
end

local tab1 = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
tab1:SetSize(80, 25)
tab1:SetPoint("TOPLEFT", 15, -30)
tab1:SetText("Results")
tab1:SetScript("OnClick", function() SetTab(1) end)

local tab2 = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
tab2:SetSize(80, 25)
tab2:SetPoint("TOPLEFT", 100, -30)
tab2:SetText("History")
tab2:SetScript("OnClick", function() SetTab(2) end)

local tab3 = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
tab3:SetSize(80, 25)
tab3:SetPoint("TOPLEFT", 185, -30)
tab3:SetText("Settings")
tab3:SetScript("OnClick", function() SetTab(3) end)

local tab4 = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
tab4:SetSize(80, 25)
tab4:SetPoint("TOPLEFT", 270, -30)
tab4:SetText("Statistics")
tab4:SetScript("OnClick", function() SetTab(4) end)

local tab5 = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
tab5:SetSize(100, 25)
tab5:SetPoint("TOPLEFT", 355, -30)
tab5:SetText("Guild Statistics")
tab5:SetScript("OnClick", function() SetTab(5) end)

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
targetUI:SetSize(460, 80)
targetUI:SetPoint("BOTTOM", 0, 0)

-- C. Specific Zone Dropdown
local ddLabel = targetUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ddLabel:SetPoint("TOPLEFT", 90, -15)
ddLabel:SetText("Select Zone to Scan:")

local zoneDropDown = CreateFrame("Frame", "NoGuildSpecificDropDown", targetUI, "UIDropDownMenuTemplate")
zoneDropDown:SetPoint("TOPLEFT", ddLabel, "BOTTOMLEFT", -15, -5)
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
local scanBtn = CreateFrame("Button", nil, targetUI, "GameMenuButtonTemplate")
scanBtn:SetSize(110, 25)
scanBtn:SetPoint("LEFT", zoneDropDown, "RIGHT", -5, 2)
scanBtn:SetText("Start Scan")
scanBtn:SetScript("OnClick", function()
    if StartScanSequence then StartScanSequence() end
end)

-- E. Results List (Scroll)
local scanScroll = CreateFrame("ScrollFrame", nil, scanView, "UIPanelScrollFrameTemplate")
scanScroll:SetPoint("TOPLEFT", 0, -5)
scanScroll:SetPoint("BOTTOMRIGHT", -25, 85)
local scanContent = CreateFrame("Frame", nil, scanScroll)
scanContent:SetSize(420, 1)
scanScroll:SetScrollChild(scanContent)

-- Helper: Create Row
local function CreateBaseRow(parent, isHistory)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 30)

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

    -- 3. Info Text
    local infoText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    if isHistory then
        infoText:SetPoint("RIGHT", actionBtn, "LEFT", -15, 0)
        infoText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        infoText:SetJustifyH("RIGHT")
    else
        infoText:SetPoint("LEFT", nameText, "RIGHT", 5, 0)
        infoText:SetWidth(170)
        infoText:SetJustifyH("LEFT")
    end
    row.infoText = infoText

    return row
end

local function ClearScanView()
    for _, row in ipairs(scanRows) do row:Hide() end
end

-- Updated to support accumulated results
local function UpdateScanList(results)
    ClearScanView()

    if not results or #results == 0 then return end

    local yOffset = 0
    local count = 0

    for i, data in ipairs(results) do
        local minLvl = settingsDB.minLevel or 1
        local maxLvl = settingsDB.maxLevel or 80
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

            row.actionBtn:SetText("Invite")
            row.actionBtn:Enable()

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
                else
                     row.infoText:SetText("Invited")
                     row.actionBtn:SetText("Invited")
                     row.actionBtn:Disable()
                end
            else
                 row.infoText:SetTextColor(1, 1, 1)
            end

            row.actionBtn:SetScript("OnClick", function(self)
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

local clearBtn = CreateFrame("Button", nil, historyView, "GameMenuButtonTemplate")
clearBtn:SetSize(140, 30)
clearBtn:SetPoint("BOTTOM", 0, 10)
clearBtn:SetText("Clear All History")
clearBtn:SetScript("OnClick", function()
    NoGuildHistoryDB = {}
    historyDB = NoGuildHistoryDB
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

function UpdateHistoryList()
    for _, row in ipairs(histRows) do row:Hide() end

    local filter = searchBox:GetText():lower()

    local list = {}
    for name, data in pairs(historyDB) do
        if filter == "" or name:lower():find(filter) then
            table.insert(list, {name=name, data=data})
        end
    end
    table.sort(list, function(a,b) return a.data.time > b.data.time end)

    local yOffset = 0
    local count = 0

    for _, item in ipairs(list) do
        count = count + 1
        if not histRows[count] then histRows[count] = CreateBaseRow(histContent, true) end

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
            row.infoText:SetText("Declined (" .. dateStr .. ")")
            row.infoText:SetTextColor(1, 0, 0)
        elseif data.action == "JOINED" then
            row.infoText:SetText("Joined (" .. dateStr .. ")")
            row.infoText:SetTextColor(0, 1, 0)
        else
            row.infoText:SetText("Invited (" .. dateStr .. ")")
            row.infoText:SetTextColor(1, 1, 1)
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
                UpdateHistoryList()
            end)
        end
        yOffset = yOffset + 30
    end
    histContent:SetHeight(yOffset)
end


-- =============================================================
-- 6. SETTINGS VIEW (Tab 3)
-- =============================================================

local setHeader = settingsView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
setHeader:SetPoint("TOPLEFT", 10, -10)
setHeader:SetText("Scan Filters")

local function CreateInput(parent, title, dbKey, defaultVal, yPos)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 10, yPos)
    label:SetText(title)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(50, 20)
    editBox:SetPoint("LEFT", label, "RIGHT", 10, 0)
    editBox:SetAutoFocus(false)

    editBox:SetScript("OnShow", function(self)
        self:SetText(settingsDB[dbKey] or defaultVal)
    end)

    editBox:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then settingsDB[dbKey] = val end
    end)

    return editBox
end

local retentionBox = CreateInput(settingsView, "History Days:", "historyRetentionDays", 1, -40)

-- Level Section
local levelHeader = settingsView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelHeader:SetPoint("TOPLEFT", 10, -70)
levelHeader:SetText("Level Range:")

local minBox = CreateInput(settingsView, "Min Level:", "minLevel", 1, -90)
local maxBox = CreateInput(settingsView, "Max Level:", "maxLevel", 80, -115)

local balLevelBtn = CreateFrame("Button", nil, settingsView, "GameMenuButtonTemplate")
balLevelBtn:SetSize(220, 25)
balLevelBtn:SetPoint("TOPLEFT", 20, -145)
balLevelBtn:SetText("Balance Guild Level Distribution")
balLevelBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local counts, total = GetGuildLevelCounts()

    -- Prepare list of all categories (even those with 0 count)
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

    -- Select bottom 3
    local newMin, newMax = 80, 1
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
    minBox:SetText(newMin)
    maxBox:SetText(newMax)
    print("|cff00ff00[NoGuild]|r Level range set to " .. newMin .. "-" .. newMax .. " (Targeting: " .. table.concat(selectedNames, ", ") .. ")")
end)

local classHeader = settingsView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
classHeader:SetPoint("TOPLEFT", 10, -185)
classHeader:SetText("Included Classes:")

local chkY = -205
local chkX = 20

local classCheckboxes = {}

for i, cls in ipairs(CLASS_LIST) do
    local cb = CreateFrame("CheckButton", nil, settingsView, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", chkX, chkY)
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

    if i % 2 == 0 then
        chkX = 20
        chkY = chkY - 25
    else
        chkX = 180
    end
end

-- Balance Button
local balBtn = CreateFrame("Button", nil, settingsView, "GameMenuButtonTemplate")
balBtn:SetSize(220, 25)
balBtn:SetPoint("TOPLEFT", 20, chkY - 40) -- Adjusted position relative to end of checkboxes
balBtn:SetText("Balance Guild Class Distribution")
balBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end

    local counts, total = GetGuildClassCounts()
    if total == 0 then
        print("|cffff0000[NoGuild]|r No guild data found. Please open Guild Statistics tab first or wait for data.")
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
    print("|cff00ff00[NoGuild]|r Filters updated: Targeting 4 least popular classes.")
end)

-- =============================================================
-- 7. SCAN LOGIC (With Queue System)
-- =============================================================

local scanLogic = CreateFrame("Frame")
local isScanning = false
local isWaitingForWho = false
local scanQueue = {}
local currentScanZone = ""
local accumulatedResults = {}

scanLogic:RegisterEvent("CHAT_MSG_SYSTEM")
scanLogic:SetScript("OnEvent", function(self, event, msg)
    local declinedName = string.match(msg, "^(.*) declines guild invitation")

    if declinedName and historyDB[declinedName] then
        historyDB[declinedName].action = "DECLINED"
        historyDB[declinedName].time = time()
        print("|cffff0000[NoGuild]|r Detected decline: " .. declinedName)
    end

    local joinedName = string.match(msg, "^(.*) has joined the guild")
    if joinedName then
        historyDB[joinedName] = { action = "JOINED", time = time(), class = "PRIEST" }
        if settingsDB.stats then settingsDB.stats.joined = (settingsDB.stats.joined or 0) + 1 end
        print("|cff00ff00[NoGuild]|r " .. joinedName .. " joined!")
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
                print("|cff00ff00[NoGuild]|r Zone scanned. Click button to scan next zone.")
            else
                isScanning = false
                scanBtn:SetText("Start Scan")
                scanBtn:Enable()

                local visibleCount = 0
                for _, data in ipairs(accumulatedResults) do
                    local minLvl = settingsDB.minLevel or 1
                    local maxLvl = settingsDB.maxLevel or 80
                    local classAllowed = settingsDB.classes[data.class]
                    if classAllowed == nil then classAllowed = true end
                    if data.level >= minLvl and data.level <= maxLvl and classAllowed then
                        visibleCount = visibleCount + 1
                    end
                end
                print("|cff00ff00[NoGuild]|r Scan Complete. Found " .. #accumulatedResults .. " unguilded players (" .. visibleCount .. " visible).")
            end
        end)
    end
end)

ProcessNextScan = function()
    currentScanZone = table.remove(scanQueue, 1)

    -- Status Update
    scanBtn:SetText("Scanning...")
    print("|cff00ff00[NoGuild]|r Scanning: " .. currentScanZone .. "...")

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
            print("|cffff0000[NoGuild]|r Scan timed out (server didn't respond). Resetting...")

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
local minimapBtn = CreateFrame("Button", "NoGuildMinimapButton", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameLevel(8)
minimapBtn:SetPoint("CENTER", Minimap, "CENTER", -56, -56)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("CENTER")

local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show() end
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("NoGuild Scanner")
    GameTooltip:AddLine("Left-click to toggle window", 1, 1, 1)
    GameTooltip:AddLine("Right-click to drag", 0.6, 0.6, 0.6)
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

SLASH_NOGUILD1 = "/noguild"
SlashCmdList["NOGUILD"] = function(msg)
    if msg == "reset" then
        NoGuildHistoryDB = {}
        historyDB = NoGuildHistoryDB
        print("History cleared.")
        return
    end

    mainFrame:Show()
    SetTab(1)
end