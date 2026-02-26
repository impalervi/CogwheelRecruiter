local addonName, NS = ...
NS = NS or {}

NS.StatsView = NS.StatsView or {}
local StatsView = NS.StatsView

function StatsView.Create(context)
    context = context or {}

    local parent = context.parent
    if not parent then
        return {
            Update = function() end,
        }
    end

    local classList = context.getClassList and context.getClassList() or {}
    local zoneCategories = context.getZoneCategories and context.getZoneCategories() or {}

    local statsScroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
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

    for i, cls in ipairs(classList) do
        local row = statsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 16, classStartY - ((i - 1) * 18))
        row:SetWidth(430)
        row:SetJustifyH("LEFT")
        classRows[cls] = row
    end

    local levelHeaderY = classStartY - (#classList * 18) - 16
    local levelHeader = statsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelHeader:SetPoint("TOPLEFT", 10, levelHeaderY)
    levelHeader:SetText("Per Level Category (Invites / Accepted / Acceptance Rate)")

    local levelCategoryOrder = {}
    for _, cat in ipairs(zoneCategories) do
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

    local function Update()
        local analyticsDB = context.getAnalyticsDB and context.getAnalyticsDB() or nil
        if not analyticsDB then
            totalsText:SetText("No analytics data available yet.")
            ratesText:SetText("")
            return
        end

        if context.ensureAnalyticsDefaults then
            context.ensureAnalyticsDefaults()
        end

        local formatRate = context.formatRate or function(accepted, invited)
            if not invited or invited <= 0 then
                return "0%"
            end
            return string.format("%d%%", math.floor((accepted / invited) * 100 + 0.5))
        end

        local normalizeClassName = context.normalizeClassName or function(classToken)
            return classToken or "Unknown"
        end

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
            formatRate(answered, whispered),
            formatRate(accepted, invited)
        ))

        local invitesByClass = analyticsDB.invitesByClass or {}
        local acceptedByClass = analyticsDB.acceptedByClass or {}

        for _, cls in ipairs(classList) do
            local invitesCount = tonumber(invitesByClass[cls]) or 0
            local acceptedCount = tonumber(acceptedByClass[cls]) or 0
            local row = classRows[cls]
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls] or nil
            if color then
                row:SetTextColor(color.r, color.g, color.b)
            else
                row:SetTextColor(0.9, 0.9, 0.9)
            end

            row:SetText(string.format(
                "%s - Invites: %d  Accepted: %d  Rate: %s",
                normalizeClassName(cls),
                invitesCount,
                acceptedCount,
                formatRate(acceptedCount, invitesCount)
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
                formatRate(acceptedCount, invitesCount)
            ))
        end

        local findExtremes = context.findExtremes
        local bestClass, worstClass = "No invite data yet.", "No invite data yet."
        if findExtremes then
            bestClass, worstClass = findExtremes(classList, invitesByClass, acceptedByClass, normalizeClassName, formatRate)
        end
        bestClassText:SetText("Highest Class Acceptance: " .. bestClass)
        worstClassText:SetText("Lowest Class Acceptance: " .. worstClass)

        local bestLevel, worstLevel = "No invite data yet.", "No invite data yet."
        if findExtremes then
            bestLevel, worstLevel = findExtremes(levelCategoryOrder, invitesByLevel, acceptedByLevel, function(key) return key end, formatRate)
        end
        bestLevelText:SetText("Highest Level Category Acceptance: " .. bestLevel)
        worstLevelText:SetText("Lowest Level Category Acceptance: " .. worstLevel)
    end

    return {
        Update = Update,
    }
end
