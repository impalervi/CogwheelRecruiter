local addonName, NS = ...
NS = NS or {}

NS.SettingsFiltersView = NS.SettingsFiltersView or {}
local SettingsFiltersView = NS.SettingsFiltersView

local function DefaultRequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function SettingsFiltersView.Create(context)
    context = context or {}

    local settingsView = context.settingsView
    local filtersView = context.filtersView
    if not settingsView or not filtersView then
        return {
            RefreshLevelRangeText = function() end,
            InitializeLevelSlidersFromSettings = function() end,
            RefreshHistoryRetentionUI = function() end,
        }
    end

    local classList = context.getClassList and context.getClassList() or {}
    local zoneCategories = context.getZoneCategories and context.getZoneCategories() or {}
    local maxPlayerLevel = tonumber(context.getMaxPlayerLevel and context.getMaxPlayerLevel()) or 70
    local maxWhisperChars = tonumber(context.maxWhisperChars) or 255
    local normalizeClassName = context.normalizeClassName or function(token)
        if not token or token == "" then
            return "Adventurer"
        end
        local upper = string.upper(token)
        return upper:sub(1, 1) .. upper:sub(2):lower()
    end
    local requestGuildRoster = context.requestGuildRoster or DefaultRequestGuildRoster
    local getGuildClassCounts = context.getGuildClassCounts or function() return {}, 0 end
    local getGuildLevelCounts = context.getGuildLevelCounts or function() return {}, 0 end
    local buildWhisperPreview = context.buildWhisperPreview or function(targetName, targetClass) return "" end
    local buildWelcomePreview = context.buildWelcomePreview or function(targetName) return "" end
    local printFn = context.print or print

    local function getSettingsDB()
        if context.getSettingsDB then
            return context.getSettingsDB()
        end
        return nil
    end

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
        local playerClassName = normalizeClassName(playerClassFile)
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

    local function UpdateWhisperPreview()
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

        local template = settingsDB.whisperTemplate or ""
        local sampleTarget = UnitName("player") or "Player"
        local _, sampleClass = UnitClass("player")
        local preview = buildWhisperPreview(sampleTarget, sampleClass)
        whisperPreview:SetText("Preview: " .. preview)

        local previewState
        if NS.TemplatePreview and NS.TemplatePreview.BuildPreviewState then
            previewState = NS.TemplatePreview.BuildPreviewState(template, preview, maxWhisperChars)
        end

        if previewState and NS.TemplatePreview.ApplyCountToFontString then
            NS.TemplatePreview.ApplyCountToFontString(whisperCount, previewState)
        end
    end

    whisperBox:SetScript("OnShow", function(self)
        local settingsDB = getSettingsDB()
        self:SetText((settingsDB and settingsDB.whisperTemplate) or "")
        UpdateWhisperPreview()
    end)
    whisperBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    whisperBox:SetScript("OnTextChanged", function(self)
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end
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
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

        local template = settingsDB.welcomeTemplate or ""
        local sampleTarget = UnitName("player") or "Player"
        local preview = buildWelcomePreview(sampleTarget)
        welcomePreview:SetText("Preview: " .. preview)

        local previewState
        if NS.TemplatePreview and NS.TemplatePreview.BuildPreviewState then
            previewState = NS.TemplatePreview.BuildPreviewState(template, preview, maxWhisperChars)
        end

        if previewState and NS.TemplatePreview.ApplyCountToFontString then
            NS.TemplatePreview.ApplyCountToFontString(welcomeCount, previewState)
        end
    end

    welcomeEnabledCB:SetScript("OnShow", function(self)
        local settingsDB = getSettingsDB()
        self:SetChecked(settingsDB and settingsDB.autoWelcomeEnabled == true)
    end)
    welcomeEnabledCB:SetScript("OnClick", function(self)
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end
        settingsDB.autoWelcomeEnabled = self:GetChecked() == true
    end)

    welcomeBox:SetScript("OnShow", function(self)
        local settingsDB = getSettingsDB()
        self:SetText((settingsDB and settingsDB.welcomeTemplate) or "")
        UpdateWelcomePreview()
    end)
    welcomeBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    welcomeBox:SetScript("OnTextChanged", function(self)
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end
        settingsDB.welcomeTemplate = self:GetText()
        UpdateWelcomePreview()
    end)

    local saveFiltersBtn = CreateFrame("Button", nil, filtersView, "UIPanelButtonTemplate")
    saveFiltersBtn:SetSize(94, 22)
    saveFiltersBtn:SetPoint("BOTTOM", filtersView, "BOTTOM", 0, 10)
    saveFiltersBtn:SetText("Save Filters")
    saveFiltersBtn:SetScript("OnClick", function()
        if context.onSaveFilters then
            context.onSaveFilters()
        end
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

    local classHeader = filtersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 10, -38)
    classHeader:SetText("Included Classes:")

    local classCheckboxes = {}
    local classStartY = -58
    local classCols = {20, 160, 300}

    for i, cls in ipairs(classList) do
        local cb = CreateFrame("CheckButton", nil, filtersContent, "UICheckButtonTemplate")
        local col = ((i - 1) % 3) + 1
        local row = math.floor((i - 1) / 3)
        cb:SetPoint("TOPLEFT", classCols[col], classStartY - (row * 24))
        cb:SetSize(24, 24)

        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        cb.text:SetText(cls:sub(1, 1) .. cls:sub(2):lower())

        local c = RAID_CLASS_COLORS[cls]
        if c then
            cb.text:SetTextColor(c.r, c.g, c.b)
        end

        classCheckboxes[cls] = cb

        cb:SetScript("OnShow", function(self)
            local settingsDB = getSettingsDB()
            local classSettings = settingsDB and settingsDB.classes or {}
            self:SetChecked(classSettings[cls] == true)
        end)

        cb:SetScript("OnClick", function(self)
            local settingsDB = getSettingsDB()
            if not settingsDB then
                return
            end
            settingsDB.classes[cls] = self:GetChecked()
        end)
    end

    local balBtn = CreateFrame("Button", nil, filtersContent, "UIPanelButtonTemplate")
    balBtn:SetSize(220, 25)
    local classRows = math.floor((#classList + 2) / 3)
    local classBlockBottom = classStartY - ((classRows - 1) * 24) - 16
    balBtn:SetPoint("TOPLEFT", 20, classBlockBottom - 18)
    balBtn:SetText("Balance Guild Class Distribution")
    balBtn:SetScript("OnClick", function()
        requestGuildRoster()

        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

        local counts, total = getGuildClassCounts()
        if total == 0 then
            printFn("|cffff0000[Cogwheel]|r No guild data found. Please open Guild Statistics tab first or wait for data.")
            return
        end

        local sorted = {}
        for cls, count in pairs(counts) do
            table.insert(sorted, { cls = cls, count = count })
        end
        table.sort(sorted, function(a, b)
            return a.count < b.count
        end)

        for _, cls in ipairs(classList) do
            settingsDB.classes[cls] = false
        end

        for i = 1, 4 do
            if sorted[i] then
                settingsDB.classes[sorted[i].cls] = true
            end
        end

        for cls, cb in pairs(classCheckboxes) do
            cb:SetChecked(settingsDB.classes[cls])
        end
        printFn("|cff00ff00[Cogwheel]|r Filters updated: Targeting 4 least popular classes.")
    end)

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
    minLevelSlider:SetMinMaxValues(1, maxPlayerLevel)
    minLevelSlider:SetValueStep(1)
    minLevelSlider:SetObeyStepOnDrag(true)
    minLevelSlider:SetWidth(186)
    minLevelSlider:SetHeight(24)
    _G[minLevelSlider:GetName() .. "Low"]:SetText("1")
    _G[minLevelSlider:GetName() .. "High"]:SetText(tostring(maxPlayerLevel))
    _G[minLevelSlider:GetName() .. "Text"]:SetText("Min")
    minLevelSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    minLevelSlider:GetThumbTexture():SetSize(16, 24)

    local maxLevelSlider = CreateFrame("Slider", "CogwheelRecruiterMaxLevelSlider", filtersContent, "OptionsSliderTemplate")
    maxLevelSlider:SetPoint("TOPLEFT", maxGroup, "TOPLEFT", 8, -22)
    maxLevelSlider:SetMinMaxValues(1, maxPlayerLevel)
    maxLevelSlider:SetValueStep(1)
    maxLevelSlider:SetObeyStepOnDrag(true)
    maxLevelSlider:SetWidth(186)
    maxLevelSlider:SetHeight(24)
    _G[maxLevelSlider:GetName() .. "Low"]:SetText("1")
    _G[maxLevelSlider:GetName() .. "High"]:SetText(tostring(maxPlayerLevel))
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
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

        local minVal = math.floor((minLevelSlider:GetValue() or 1) + 0.5)
        local maxVal = math.floor((maxLevelSlider:GetValue() or maxPlayerLevel) + 0.5)

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
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

        syncingLevelSliders = true
        minLevelSlider:SetValue(settingsDB.minLevel or 1)
        maxLevelSlider:SetValue(settingsDB.maxLevel or maxPlayerLevel)
        syncingLevelSliders = false
        RefreshLevelRangeText()
    end

    minLevelSlider:SetScript("OnValueChanged", function()
        if syncingLevelSliders then
            return
        end
        RefreshLevelRangeText("min")
    end)

    maxLevelSlider:SetScript("OnValueChanged", function()
        if syncingLevelSliders then
            return
        end
        RefreshLevelRangeText("max")
    end)
    filtersView:HookScript("OnShow", function()
        InitializeLevelSlidersFromSettings()
    end)

    filtersContent:SetHeight(360)

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
        local settingsDB = getSettingsDB()
        if not settingsDB then
            return
        end

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
            local settingsDB = getSettingsDB()
            if not settingsDB then
                return
            end
            settingsDB.historyRetentionDays = days
            RefreshHistoryRetentionUI()
        end)
        table.insert(historyPresetButtons, b)
        prev = b
    end

    settingsView:HookScript("OnShow", function()
        local settingsDB = getSettingsDB()
        RefreshHistoryRetentionUI()
        welcomeEnabledCB:SetChecked(settingsDB and settingsDB.autoWelcomeEnabled == true)
        if settingsDB then
            welcomeBox:SetText(settingsDB.welcomeTemplate or "")
        end
        UpdateWelcomePreview()
    end)

    settingsContent:SetHeight(400)

    return {
        RefreshLevelRangeText = RefreshLevelRangeText,
        InitializeLevelSlidersFromSettings = InitializeLevelSlidersFromSettings,
        RefreshHistoryRetentionUI = RefreshHistoryRetentionUI,
        CreateSliderTrack = CreateSliderTrack,
        CreateLevelBadge = CreateLevelBadge,
    }
end
