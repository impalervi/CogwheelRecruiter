local addonName, NS = ...
NS = NS or {}

NS.TabController = NS.TabController or {}
local TabController = NS.TabController

function TabController.Create(context)
    context = context or {}

    local mainFrame = context.mainFrame
    local quickFrame = context.quickFrame
    local welcomeFrame = context.welcomeFrame
    local contentPanel = context.contentPanel
    local footerFrame = context.footerFrame
    local views = context.views or {}

    local function getCurrentTab()
        if context.getCurrentTab then
            return context.getCurrentTab() or 1
        end
        return 1
    end

    local function setCurrentTab(id)
        if context.setCurrentTab then
            context.setCurrentTab(id)
        end
    end

    local function hideAllViews()
        if views.scanView then views.scanView:Hide() end
        if views.quickView then views.quickView:Hide() end
        if views.historyView then views.historyView:Hide() end
        if views.settingsView then views.settingsView:Hide() end
        if views.filtersView then views.filtersView:Hide() end
        if views.statsView then views.statsView:Hide() end
        if views.guildStatsView then views.guildStatsView:Hide() end
        if views.whispersView then views.whispersView:Hide() end
    end

    local setTab

    local tabScanner = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    tabScanner:SetSize(132, 24)
    tabScanner:SetPoint("TOP", mainFrame, "TOP", 0, -30)
    tabScanner:SetText("Scanner")

    local tabQuick = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    tabQuick:SetSize(132, 24)
    tabQuick:SetPoint("RIGHT", tabScanner, "LEFT", -4, 0)
    tabQuick:SetText("Quick Scanner")

    local tabWhispers = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    tabWhispers:SetSize(132, 24)
    tabWhispers:SetPoint("LEFT", tabScanner, "RIGHT", 4, 0)
    tabWhispers:SetText("Whispers")

    local function CreateAuxTabButton(anchor, label, tabId)
        local btn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        btn:SetSize(80, 20)
        btn:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
        btn:SetText(label)
        if btn:GetFontString() then
            btn:GetFontString():SetTextColor(1, 1, 1)
        end
        btn.tabId = tabId
        btn:SetScript("OnClick", function()
            if setTab then
                setTab(tabId)
            end
        end)
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

    local btnStats = CreateAuxTabButton(auxStart, "Stats", 4)
    local btnGuild = CreateAuxTabButton(btnStats, "Guild", 5)
    local btnSettings = CreateAuxTabButton(btnGuild, "Settings", 3)
    local btnHistory = auxStart

    local function ApplyMainLayoutForTab(_)
        if not (contentPanel and mainFrame) then
            return
        end

        contentPanel:ClearAllPoints()
        contentPanel:SetPoint("TOPLEFT", 10, -60)
        mainFrame:SetSize(520, 550)
        contentPanel:SetPoint("BOTTOMRIGHT", -10, 58)

        if not (welcomeFrame and welcomeFrame:IsShown()) then
            if footerFrame then footerFrame:Show() end
            auxStart:Show()
            btnStats:Show()
            btnGuild:Show()
            btnSettings:Show()
        end
    end

    local function SetWelcomeMode(enabled)
        if not (mainFrame and contentPanel) then
            return
        end

        if enabled then
            mainFrame:SetSize(520, 550)
            contentPanel:ClearAllPoints()
            contentPanel:SetPoint("TOPLEFT", 10, -60)
            contentPanel:SetPoint("BOTTOMRIGHT", -10, 58)
            contentPanel:Hide()

            if quickFrame then quickFrame:Hide() end
            if footerFrame then footerFrame:Hide() end

            tabQuick:Hide()
            tabScanner:Hide()
            tabWhispers:Hide()
            if mainFrame.quickModeBtn then
                mainFrame.quickModeBtn:Hide()
            end
            auxStart:Hide()
            btnStats:Hide()
            btnGuild:Hide()
            btnSettings:Hide()

            hideAllViews()

            if welcomeFrame then
                welcomeFrame:Show()
            end
            return
        end

        contentPanel:Show()
        tabQuick:Show()
        tabScanner:Show()
        tabWhispers:Show()
        if mainFrame.quickModeBtn then
            mainFrame.quickModeBtn:Show()
        end
        if welcomeFrame then
            welcomeFrame:Hide()
        end

        ApplyMainLayoutForTab(getCurrentTab())
    end

    local function UpdateTabButtons()
        local currentTab = getCurrentTab()
        local primaryActive = {
            [8] = tabQuick,
            [1] = tabScanner,
            [6] = tabWhispers,
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

    setTab = function(id)
        local previousTab = getCurrentTab()
        setCurrentTab(id)

        if id == 7 and (previousTab == 1 or previousTab == 8) and context.onSetFilterReturnTab then
            context.onSetFilterReturnTab(previousTab)
        end

        if id == 8 then
            if mainFrame then mainFrame:Hide() end
            if welcomeFrame then welcomeFrame:Hide() end
            if quickFrame then quickFrame:Show() end
            if views.quickView then views.quickView:Show() end
            UpdateTabButtons()
            return
        end

        if quickFrame then quickFrame:Hide() end
        if mainFrame then mainFrame:Show() end

        ApplyMainLayoutForTab(id)
        hideAllViews()

        if id == 1 then
            if views.scanView then views.scanView:Show() end
        elseif id == 2 then
            if views.historyView then views.historyView:Show() end
            if context.onShowHistory then context.onShowHistory() end
        elseif id == 3 then
            if views.settingsView then views.settingsView:Show() end
        elseif id == 7 then
            if views.filtersView then views.filtersView:Show() end
        elseif id == 4 then
            if views.statsView then views.statsView:Show() end
            if context.onShowStats then context.onShowStats() end
        elseif id == 5 then
            if views.guildStatsView then views.guildStatsView:Show() end
            if context.onShowGuild then context.onShowGuild() end
        elseif id == 6 then
            if views.whispersView then views.whispersView:Show() end
            if context.onShowWhispers then context.onShowWhispers() end
        end

        UpdateTabButtons()
    end

    tabScanner:SetScript("OnClick", function() setTab(1) end)
    tabQuick:SetScript("OnClick", function() setTab(8) end)
    tabWhispers:SetScript("OnClick", function() setTab(6) end)
    auxStart:SetScript("OnClick", function() setTab(2) end)

    return {
        SetTab = setTab,
        SetWelcomeMode = SetWelcomeMode,
        ApplyMainLayoutForTab = ApplyMainLayoutForTab,
        UpdateTabButtons = UpdateTabButtons,
        GetButtons = function()
            return {
                tabScanner = tabScanner,
                tabQuick = tabQuick,
                tabWhispers = tabWhispers,
                auxStart = auxStart,
                btnHistory = btnHistory,
                btnStats = btnStats,
                btnGuild = btnGuild,
                btnSettings = btnSettings,
            }
        end,
    }
end

