local addonName, NS = ...
NS = NS or {}

NS.GuildView = NS.GuildView or {}
local GuildView = NS.GuildView

local function GetActiveWindowDays(context)
    if context and context.getActiveWindowDays then
        return tonumber(context.getActiveWindowDays()) or 7
    end
    return 7
end

local function ToTitleCase(token)
    if not token or token == "" then
        return ""
    end
    return token:sub(1, 1) .. token:sub(2):lower()
end

function GuildView.Create(context)
    context = context or {}

    local parent = context.parent
    if not parent then
        return {
            Update = function() end,
        }
    end

    local getZoneCategories = context.getZoneCategories or function() return NS.ZONE_CATEGORIES or {} end
    local getGuildClassCounts = context.getGuildClassCounts or function() return {}, 0 end
    local getGuildLevelCounts = context.getGuildLevelCounts or function() return {}, 0 end
    local buildClassDistributionSegments = context.buildClassDistributionSegments or function() return {}, 0 end
    local buildLevelDistributionSegments = context.buildLevelDistributionSegments or function() return {}, 0 end
    local sendDistributionReportToGuild = context.sendDistributionReportToGuild or function() end
    local requestGuildRoster = context.requestGuildRoster or function() end
    local printFn = context.print or print

    local gsTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gsTitle:SetPoint("TOPLEFT", 20, -15)
    gsTitle:SetText("Guild Overview")

    local gsSummaryValues = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    gsSummaryValues:SetPoint("TOPLEFT", 20, -46)
    gsSummaryValues:SetWidth(460)
    gsSummaryValues:SetJustifyH("LEFT")
    gsSummaryValues:SetTextColor(0.85, 0.85, 0.85)

    local gsActiveScopeNote = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gsActiveScopeNote:SetPoint("TOPLEFT", 20, -74)
    gsActiveScopeNote:SetWidth(460)
    gsActiveScopeNote:SetJustifyH("LEFT")
    gsActiveScopeNote:SetTextColor(0.72, 0.88, 0.72)
    gsActiveScopeNote:SetText(string.format(
        "Class and level distributions are calculated from members active in the past %d days.",
        GetActiveWindowDays(context)
    ))

    local currentStatsMode = "CLASS" -- CLASS or LEVEL
    local currentVisMode = "BAR" -- MOSAIC or BAR

    parent.statsTypeDD = CreateFrame("Frame", "CogwheelRecruiterStatsTypeDD", parent, "UIDropDownMenuTemplate")
    parent.statsTypeDD:SetPoint("TOPLEFT", 0, -98)
    UIDropDownMenu_SetWidth(parent.statsTypeDD, 100)

    parent.statsVisDD = CreateFrame("Frame", "CogwheelRecruiterStatsVisDD", parent, "UIDropDownMenuTemplate")
    parent.statsVisDD:SetPoint("LEFT", parent.statsTypeDD, "RIGHT", -20, 0)
    UIDropDownMenu_SetWidth(parent.statsVisDD, 120)

    local gsContainer = CreateFrame("Frame", nil, parent)
    gsContainer:SetPoint("TOPLEFT", 20, -142)
    gsContainer:SetPoint("BOTTOMRIGHT", -20, 48)

    local gsSquares = {}
    local gsLegend = {}
    local gsStackSegments = {}

    local function HideCurrentVisuals()
        for _, sq in ipairs(gsSquares) do
            sq:Hide()
        end
        for _, legend in ipairs(gsLegend) do
            legend:Hide()
        end
        for _, segment in ipairs(gsStackSegments) do
            segment:Hide()
        end
    end

    local function DrawMosaic(sorted, total, colorMap)
        local sqSize = 20
        local startX, startY = 20, -10
        local currentSq = 0

        for _, data in ipairs(sorted) do
            local numBlocks = math.floor((data.count / total) * 100 + 0.5)
            local c = colorMap[data.key] or { r = 0.5, g = 0.5, b = 0.5 }

            for _ = 1, numBlocks do
                currentSq = currentSq + 1
                if currentSq <= 100 then
                    if not gsSquares[currentSq] then
                        local f = gsContainer:CreateTexture(nil, "ARTWORK")
                        f:SetSize(sqSize - 1, sqSize - 1)
                        gsSquares[currentSq] = f
                    end
                    local f = gsSquares[currentSq]
                    local row = math.floor((currentSq - 1) / 10)
                    local col = (currentSq - 1) % 10
                    f:SetPoint("TOPLEFT", startX + (col * sqSize), startY - (row * sqSize))
                    f:SetColorTexture(c.r, c.g, c.b)
                    f:Show()
                end
            end
        end

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
            local c = colorMap[data.key] or { r = 1, g = 1, b = 1 }
            local colorStr = string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            t:SetText(colorStr .. ToTitleCase(data.key) .. "|r: " .. data.count .. " (" .. math.floor((data.count / total) * 100) .. "%)")
            t:Show()
            ly = ly - 20
        end
    end

    local function DrawStackedBar(sorted, total, colorMap)
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
            local width = pct * totalWidth

            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", currentX, 0)
            f:SetSize(width, barHeight)

            local c = colorMap[data.key] or { r = 0.5, g = 0.5, b = 0.5 }
            f:SetColorTexture(c.r, c.g, c.b)
            f:Show()

            currentX = currentX + width
        end

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

            local c = colorMap[data.key] or { r = 1, g = 1, b = 1 }
            local colorStr = string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            t:SetText(colorStr .. ToTitleCase(data.key) .. "|r: " .. data.count .. " (" .. math.floor((data.count / total) * 100) .. "%)")
            t:Show()

            ly = ly - 20
        end
    end

    local function Update()
        if not parent:IsVisible() then
            return
        end

        local activeWindowDays = GetActiveWindowDays(context)

        local guildName = GetGuildInfo("player") or "No Guild"
        local rosterSize = GetNumGuildMembers() or 0
        local totalMembers = 0
        local activeMembers = 0

        for i = 1, rosterSize do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if name then
                totalMembers = totalMembers + 1
                local active = online
                if not active then
                    local y, m, d = GetGuildRosterLastOnline(i)
                    if y and (y == 0 and m == 0 and d <= activeWindowDays) then
                        active = true
                    end
                end
                if active then
                    activeMembers = activeMembers + 1
                end
            end
        end

        gsSummaryValues:SetText(string.format(
            "Guild: |cffFFD100%s|r  |  Characters: |cffffffff%d|r  |  Active (%d days): |cff6fdc6f%d|r",
            guildName,
            totalMembers,
            activeWindowDays,
            activeMembers
        ))

        local counts, total
        local colorMap = {}

        if currentStatsMode == "CLASS" then
            counts, total = getGuildClassCounts()
            for cls, _ in pairs(counts) do
                colorMap[cls] = RAID_CLASS_COLORS[cls] or { r = 0.5, g = 0.5, b = 0.5 }
            end
        else
            counts, total = getGuildLevelCounts()
            for _, cat in ipairs(getZoneCategories()) do
                if cat.color then
                    colorMap[cat.name] = cat.color
                end
            end
            colorMap["Other"] = { r = 0.5, g = 0.5, b = 0.5 }
        end

        local sorted = {}
        for key, count in pairs(counts) do
            table.insert(sorted, { key = key, count = count })
        end
        table.sort(sorted, function(a, b)
            return a.count > b.count
        end)

        HideCurrentVisuals()

        if total == 0 then
            return
        end

        if currentVisMode == "MOSAIC" then
            DrawMosaic(sorted, total, colorMap)
        else
            DrawStackedBar(sorted, total, colorMap)
        end
    end

    UIDropDownMenu_Initialize(parent.statsTypeDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "By Class"
        info.checked = (currentStatsMode == "CLASS")
        info.func = function()
            currentStatsMode = "CLASS"
            UIDropDownMenu_SetText(parent.statsTypeDD, "By Class")
            Update()
        end
        UIDropDownMenu_AddButton(info)

        info.text = "By Level"
        info.checked = (currentStatsMode == "LEVEL")
        info.func = function()
            currentStatsMode = "LEVEL"
            UIDropDownMenu_SetText(parent.statsTypeDD, "By Level")
            Update()
        end
        UIDropDownMenu_AddButton(info)
    end)
    UIDropDownMenu_SetText(parent.statsTypeDD, "By Class")

    UIDropDownMenu_Initialize(parent.statsVisDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Mosaic"
        info.checked = (currentVisMode == "MOSAIC")
        info.func = function()
            currentVisMode = "MOSAIC"
            UIDropDownMenu_SetText(parent.statsVisDD, "Mosaic")
            Update()
        end
        UIDropDownMenu_AddButton(info)

        info.text = "Stacked Bar"
        info.checked = (currentVisMode == "BAR")
        info.func = function()
            currentVisMode = "BAR"
            UIDropDownMenu_SetText(parent.statsVisDD, "Stacked Bar")
            Update()
        end
        UIDropDownMenu_AddButton(info)
    end)
    UIDropDownMenu_SetText(parent.statsVisDD, "Stacked Bar")

    local reportButtonsRow = CreateFrame("Frame", nil, parent)
    reportButtonsRow:SetSize(350, 22)
    reportButtonsRow:SetPoint("BOTTOM", parent, "BOTTOM", 0, 12)

    local reportWarning = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reportWarning:SetPoint("BOTTOM", reportButtonsRow, "TOP", 0, 6)
    reportWarning:SetText("Warning: These will report to guild chat")
    reportWarning:SetTextColor(0.25, 1.0, 0.25)

    local reportClassBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reportClassBtn:SetSize(170, 22)
    reportClassBtn:SetPoint("LEFT", reportButtonsRow, "LEFT", 0, 0)
    reportClassBtn:SetText("Report Class Stats")
    reportClassBtn:SetScript("OnClick", function()
        requestGuildRoster()

        local segments = buildClassDistributionSegments()
        local header = string.format(
            "Guild Class Distribution (Based on members active for the past %d days)",
            GetActiveWindowDays(context)
        )
        sendDistributionReportToGuild(header, segments)
        printFn("|cff00ff00[Cogwheel]|r Class distribution posted to guild chat.")
    end)

    local reportLevelBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reportLevelBtn:SetSize(170, 22)
    reportLevelBtn:SetPoint("LEFT", reportClassBtn, "RIGHT", 10, 0)
    reportLevelBtn:SetText("Report Level Stats")
    reportLevelBtn:SetScript("OnClick", function()
        requestGuildRoster()

        local segments = buildLevelDistributionSegments()
        local header = string.format(
            "Guild Level Distribution (Based on members active for the past %d days)",
            GetActiveWindowDays(context)
        )
        sendDistributionReportToGuild(header, segments)
        printFn("|cff00ff00[Cogwheel]|r Level distribution posted to guild chat.")
    end)

    return {
        Update = Update,
    }
end
