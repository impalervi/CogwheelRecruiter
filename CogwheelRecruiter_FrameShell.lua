local addonName, NS = ...
NS = NS or {}

NS.FrameShell = NS.FrameShell or {}
local FrameShell = NS.FrameShell

local function ColorizeAuthor(authorText, darkMageColor, colorReset)
    authorText = authorText or ""
    darkMageColor = darkMageColor or ""
    colorReset = colorReset or ""
    return authorText:gsub("Marviy", darkMageColor .. "Marviy" .. colorReset)
end

local function CreateTitleChip(parentFrame, width, centerWidth)
    local chip = CreateFrame("Frame", nil, parentFrame)
    chip:SetSize(width, 46)
    chip:ClearAllPoints()
    chip:SetPoint("TOP", parentFrame, "TOP", 0, 14)

    chip.center = chip:CreateTexture(nil, "ARTWORK")
    chip.center:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    chip.center:SetTexCoord(0.31, 0.67, 0, 0.63)
    chip.center:SetPoint("TOP", 0, 0)
    chip.center:SetSize(centerWidth, 42)

    chip.left = chip:CreateTexture(nil, "ARTWORK")
    chip.left:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    chip.left:SetTexCoord(0.21, 0.31, 0, 0.63)
    chip.left:SetPoint("RIGHT", chip.center, "LEFT", 0, 0)
    chip.left:SetSize(30, 42)

    chip.right = chip:CreateTexture(nil, "ARTWORK")
    chip.right:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    chip.right:SetTexCoord(0.67, 0.77, 0, 0.63)
    chip.right:SetPoint("LEFT", chip.center, "RIGHT", 0, 0)
    chip.right:SetSize(30, 42)

    return chip
end

local function SetWelcomeLogoTexture(textureObject, candidates)
    for _, path in ipairs(candidates or {}) do
        textureObject:SetTexture(path)
        if textureObject:GetTexture() then
            return true
        end
    end

    textureObject:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    return false
end

function FrameShell.Create(context)
    context = context or {}

    local addonTitle = context.addonTitle or "Cogwheel Recruiter"
    local addonVersion = context.addonVersion or "dev"
    local addonAuthor = context.addonAuthor or "Unknown"

    local colorHeaderGold = context.colorHeaderGold or ""
    local colorFooterGold = context.colorFooterGold or ""
    local colorDarkRed = context.colorDarkRed or ""
    local colorDarkMage = context.colorDarkMage or ""
    local colorReset = context.colorReset or ""

    local onSwitchToQuick = context.onSwitchToQuick
    local onSwitchToFull = context.onSwitchToFull

    local coloredAuthor = ColorizeAuthor(addonAuthor, colorDarkMage, colorReset)

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
        if onSwitchToQuick then
            onSwitchToQuick()
        end
    end)
    mainFrame.quickModeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Switch To Quick Scanner", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    mainFrame.quickModeBtn:SetScript("OnLeave", GameTooltip_Hide)

    mainFrame.titleChip = CreateTitleChip(mainFrame, 250, 190)
    mainFrame.title = mainFrame.titleChip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("CENTER", mainFrame.titleChip.center, "CENTER", 0, 0)
    mainFrame.title:SetText(colorHeaderGold .. addonTitle .. colorReset)

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
    footerFrame.text:SetText(string.format(
        "%s%s%s %sv%s%s | Author: %s",
        colorFooterGold, addonTitle, colorReset,
        colorDarkRed, addonVersion, colorReset,
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
        if onSwitchToFull then
            onSwitchToFull()
        end
    end)
    quickFrame.fullModeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Switch To Full Scanner", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    quickFrame.fullModeBtn:SetScript("OnLeave", GameTooltip_Hide)

    quickFrame.titleChip = CreateTitleChip(quickFrame, 210, 150)
    quickFrame.title = quickFrame.titleChip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    quickFrame.title:SetPoint("CENTER", quickFrame.titleChip.center, "CENTER", 0, 0)
    quickFrame.title:SetText(colorHeaderGold .. addonTitle .. colorReset)

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
        colorFooterGold, addonTitle, colorReset,
        colorDarkRed, addonVersion, colorReset,
        coloredAuthor
    ))

    local welcomeFrame = CreateFrame("Frame", nil, mainFrame)
    welcomeFrame:SetPoint("TOPLEFT", 10, -60)
    welcomeFrame:SetPoint("BOTTOMRIGHT", -10, 58)
    welcomeFrame:Hide()

    local welcomeContent = welcomeFrame
    local welcomeLogo = welcomeContent:CreateTexture(nil, "ARTWORK")
    welcomeLogo:SetSize(260, 260)
    welcomeLogo:SetPoint("TOP", 0, -20)
    SetWelcomeLogoTexture(welcomeLogo, context.splashLogoCandidates)

    local welcomeTitle = welcomeContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    welcomeTitle:SetPoint("TOP", welcomeLogo, "BOTTOM", 0, -6)
    welcomeTitle:SetText(colorHeaderGold .. addonTitle .. colorReset)

    local welcomeMeta = welcomeContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    welcomeMeta:SetPoint("TOP", welcomeTitle, "BOTTOM", 0, -8)
    welcomeMeta:SetText(string.format(
        "%sVersion:%s %sv%s%s    %sAuthor:%s %s",
        colorFooterGold,
        colorReset,
        colorDarkRed,
        addonVersion,
        colorReset,
        colorFooterGold,
        colorReset,
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

    return {
        mainFrame = mainFrame,
        contentPanel = contentPanel,
        footerFrame = footerFrame,
        quickFrame = quickFrame,
        quickFooterFrame = quickFooterFrame,
        welcomeFrame = welcomeFrame,
        welcomeStartBtn = welcomeStartBtn,
        welcomeStatus = welcomeStatus,
    }
end
