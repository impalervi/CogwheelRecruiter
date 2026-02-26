local addonName, NS = ...
NS = NS or {}

NS.ScannerView = NS.ScannerView or {}
local ScannerView = NS.ScannerView

function ScannerView.CreateControls(context)
    context = context or {}

    local parent = context.parent
    local zoneCategories = context.getZoneCategories and context.getZoneCategories() or {}
    local getSelectedZone = context.getSelectedZone or function() return nil end

    local targetUI = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    targetUI:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    targetUI:SetSize(tonumber(context.width) or 500, tonumber(context.height) or 80)
    targetUI:SetPoint("BOTTOM", 0, 0)

    local ddLabel = targetUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ddLabel:SetText(context.dropdownLabel or "Select Zone to Scan:")

    local zoneDropDown = CreateFrame(
        "Frame",
        context.dropdownFrameName or "CogwheelRecruiterSpecificDropDown",
        targetUI,
        "UIDropDownMenuTemplate"
    )
    UIDropDownMenu_SetWidth(zoneDropDown, tonumber(context.dropdownWidth) or 150)
    UIDropDownMenu_SetText(zoneDropDown, context.emptyZoneText or "Select a Zone...")

    UIDropDownMenu_Initialize(zoneDropDown, function(_, level, menuList)
        local info = UIDropDownMenu_CreateInfo()

        if (level or 1) == 1 then
            for i, catData in ipairs(zoneCategories) do
                info.text = catData.name
                info.menuList = i
                info.hasArrow = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info)
            end

            info.text = "|cffff0000Clear Selection|r"
            info.menuList = nil
            info.hasArrow = false
            info.notCheckable = true
            info.func = function()
                if context.onClearZoneSelection then
                    context.onClearZoneSelection()
                end
                UIDropDownMenu_SetText(zoneDropDown, context.emptyZoneText or "Select a Zone...")
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        elseif level == 2 then
            local catData = zoneCategories[menuList]
            if not catData then
                return
            end

            for _, zoneName in ipairs(catData.zones or {}) do
                info.text = zoneName
                info.hasArrow = false
                info.notCheckable = false
                info.checked = (getSelectedZone() == zoneName)
                info.func = function()
                    if context.onZoneSelected then
                        context.onZoneSelected(zoneName)
                    end
                    UIDropDownMenu_SetText(zoneDropDown, zoneName)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)

    local scanBtn = CreateFrame("Button", nil, targetUI, "UIPanelButtonTemplate")
    scanBtn:SetSize(110, 25)
    scanBtn:SetText(context.startButtonText or "Start Scan")
    scanBtn:SetNormalFontObject("GameFontNormal")
    scanBtn:SetHighlightFontObject("GameFontNormal")
    scanBtn:SetDisabledFontObject("GameFontDisable")
    scanBtn:SetScript("OnClick", function()
        if context.onStartScan then
            context.onStartScan()
        end
    end)

    local scanFiltersBtn = CreateFrame("Button", nil, targetUI, "UIPanelButtonTemplate")
    scanFiltersBtn:SetSize(28, 25)
    scanFiltersBtn:SetText("")
    scanFiltersBtn:SetScript("OnClick", function()
        if context.onOpenFilters then
            context.onOpenFilters()
        end
    end)

    local scanFiltersIcon = scanFiltersBtn:CreateTexture(nil, "ARTWORK")
    scanFiltersIcon:SetSize(16, 16)
    scanFiltersIcon:SetPoint("CENTER")
    scanFiltersIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")

    scanFiltersBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(context.filtersTooltip or "Filters", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    scanFiltersBtn:SetScript("OnLeave", GameTooltip_Hide)

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

    return {
        targetUI = targetUI,
        ddLabel = ddLabel,
        zoneDropDown = zoneDropDown,
        scanBtn = scanBtn,
        scanFiltersBtn = scanFiltersBtn,
        SetZoneText = function(text)
            UIDropDownMenu_SetText(zoneDropDown, text or (context.emptyZoneText or "Select a Zone..."))
        end,
    }
end

function ScannerView.Create(context)
    context = context or {}

    local rows = {}
    local parent = context.parent
    local rowWidth = tonumber(context.rowWidth) or 460
    local rowHeight = tonumber(context.rowHeight) or 30

    local function CreateRow()
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(rowWidth, rowHeight)

        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.nameText:SetPoint("LEFT", 5, 0)
        row.nameText:SetWidth(150)
        row.nameText:SetJustifyH("LEFT")

        row.actionBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.actionBtn:SetSize(72, 22)
        row.actionBtn:SetPoint("RIGHT", -5, 0)
        row.actionBtn:SetNormalFontObject("GameFontNormalSmall")
        row.actionBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.actionBtn:SetDisabledFontObject("GameFontDisableSmall")

        row.whisperBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.whisperBtn:SetSize(72, 22)
        row.whisperBtn:SetPoint("RIGHT", row.actionBtn, "LEFT", -5, 0)
        row.whisperBtn:SetNormalFontObject("GameFontNormalSmall")
        row.whisperBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.whisperBtn:SetDisabledFontObject("GameFontDisableSmall")
        row.whisperBtn:SetText("Whisper")

        row.infoText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.infoText:SetPoint("LEFT", row.nameText, "RIGHT", 5, 0)
        row.infoText:SetPoint("RIGHT", row.whisperBtn, "LEFT", -6, 0)
        row.infoText:SetJustifyH("LEFT")
        if row.infoText.SetWordWrap then
            row.infoText:SetWordWrap(false)
        end
        if row.infoText.SetMaxLines then
            row.infoText:SetMaxLines(1)
        end

        return row
    end

    local function Clear()
        for _, row in ipairs(rows) do
            row:Hide()
        end
    end

    local function UpdateList(results)
        Clear()

        if not results or #results == 0 then
            if parent then
                parent:SetHeight(0)
            end
            return
        end

        local settingsDB = context.getSettingsDB and context.getSettingsDB() or nil
        local historyDB = context.getHistoryDB and context.getHistoryDB() or nil
        local whispersDB = context.getWhispersDB and context.getWhispersDB() or nil
        local maxPlayerLevel = context.getMaxPlayerLevel and context.getMaxPlayerLevel() or 70

        local minLvl = (settingsDB and settingsDB.minLevel) or 1
        local maxLvl = (settingsDB and settingsDB.maxLevel) or maxPlayerLevel
        local classSettings = settingsDB and settingsDB.classes

        local canRecruit = true
        if context.playerCanRecruit then
            canRecruit = context.playerCanRecruit() and true or false
        end

        local yOffset = 0
        local count = 0

        for _, data in ipairs(results) do
            local classAllowed = classSettings and classSettings[data.class]
            if classAllowed == nil then
                classAllowed = true
            end

            if data.level >= minLvl and data.level <= maxLvl and classAllowed then
                count = count + 1
                if not rows[count] then
                    rows[count] = CreateRow()
                end

                local row = rows[count]
                row:SetPoint("TOPLEFT", 0, -yOffset)
                row:Show()

                local classTag = string.upper(data.class or "PRIEST")
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag] or nil
                if color then
                    row.nameText:SetTextColor(color.r, color.g, color.b)
                else
                    row.nameText:SetTextColor(1, 1, 1)
                end

                row.nameText:SetText(data.name)
                row.infoText:SetText("Lvl " .. data.level .. " (" .. (data.zone or "?") .. ")")
                row.infoText:SetTextColor(1, 1, 1)

                row.actionBtn:SetText("Invite")
                row.actionBtn:Enable()
                row.actionBtn:SetAlpha(1.0)

                row.whisperBtn:SetText("Whisper")
                row.whisperBtn:Enable()
                row.whisperBtn:SetAlpha(1.0)

                local history = historyDB and historyDB[data.name] or nil
                local whisperKey = context.getWhisperKey and context.getWhisperKey(data.name) or data.name
                local whisperState = whispersDB and whispersDB[whisperKey] or nil

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
                end

                if not canRecruit then
                    row.whisperBtn:Disable()
                    row.actionBtn:Disable()
                end

                local rowData = data

                row.whisperBtn:SetScript("OnClick", function(self)
                    if context.playerCanRecruit and not context.playerCanRecruit() then
                        if context.onPermissionDenied then
                            context.onPermissionDenied()
                        end
                        return
                    end

                    if context.onWhisper then
                        local sent = context.onWhisper(rowData)
                        if sent then
                            self:SetText("Whispered")
                            self:Disable()
                        end
                    end
                end)

                row.actionBtn:SetScript("OnClick", function(self)
                    if context.playerCanRecruit and not context.playerCanRecruit() then
                        if context.onPermissionDenied then
                            context.onPermissionDenied()
                        end
                        return
                    end

                    if context.onInvite then
                        context.onInvite(rowData, self)
                    end
                end)

                yOffset = yOffset + rowHeight
            end
        end

        if parent then
            parent:SetHeight(yOffset)
        end
    end

    return {
        Clear = Clear,
        UpdateList = UpdateList,
    }
end

