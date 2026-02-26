local addonName, NS = ...
NS = NS or {}

NS.TabShellController = NS.TabShellController or {}
local TabShellController = NS.TabShellController

function TabShellController.Create(context)
    context = context or {}

    local tabController = nil
    local tabButtons = {}

    if NS.TabController and NS.TabController.Create then
        tabController = NS.TabController.Create({
            mainFrame = context.mainFrame,
            quickFrame = context.quickFrame,
            welcomeFrame = context.welcomeFrame,
            contentPanel = context.contentPanel,
            footerFrame = context.footerFrame,
            views = context.views,
            getCurrentTab = context.getCurrentTab,
            setCurrentTab = context.setCurrentTab,
            onSetFilterReturnTab = context.onSetFilterReturnTab,
            onShowHistory = context.onShowHistory,
            onShowStats = context.onShowStats,
            onShowGuild = context.onShowGuild,
            onShowWhispers = context.onShowWhispers,
        })

        if tabController.GetButtons then
            tabButtons = tabController.GetButtons() or {}
        end
    end

    local whispersFlashController = nil
    if NS.WhispersFlash and NS.WhispersFlash.Create and tabButtons.tabWhispers then
        whispersFlashController = NS.WhispersFlash.Create({
            tabButton = tabButtons.tabWhispers,
            getCurrentTab = context.getCurrentTab,
            activeTabId = 6,
            inactiveAlpha = 0.85,
        })
    end

    local quickWhispersFlashController = nil

    local function stopWhispersTabFlash()
        if whispersFlashController and whispersFlashController.Stop then
            whispersFlashController.Stop()
        end
        if quickWhispersFlashController and quickWhispersFlashController.Stop then
            quickWhispersFlashController.Stop()
        end
    end

    local function startWhispersTabFlash()
        if whispersFlashController and whispersFlashController.Start then
            whispersFlashController.Start()
        end
        if quickWhispersFlashController and quickWhispersFlashController.Start then
            quickWhispersFlashController.Start()
        end
    end

    local function registerQuickWhispersButton(button)
        if not (button and NS.WhispersFlash and NS.WhispersFlash.Create) then
            return
        end

        if quickWhispersFlashController and quickWhispersFlashController.Stop then
            quickWhispersFlashController.Stop()
        end

        quickWhispersFlashController = NS.WhispersFlash.Create({
            tabButton = button,
            getCurrentTab = context.getCurrentTab,
            activeTabId = 6,
            inactiveAlpha = 1.0,
        })
    end

    return {
        SetTab = function(id)
            if tabController and tabController.SetTab then
                tabController.SetTab(id)
            end
        end,
        ApplyMainLayoutForTab = function(tabId)
            if tabController and tabController.ApplyMainLayoutForTab then
                tabController.ApplyMainLayoutForTab(tabId)
            end
        end,
        SetWelcomeMode = function(enabled)
            if tabController and tabController.SetWelcomeMode then
                tabController.SetWelcomeMode(enabled)
            end
        end,
        UpdateTabButtons = function()
            if tabController and tabController.UpdateTabButtons then
                tabController.UpdateTabButtons()
            end
        end,
        StartWhispersTabFlash = startWhispersTabFlash,
        StopWhispersTabFlash = stopWhispersTabFlash,
        RegisterQuickWhispersButton = registerQuickWhispersButton,
    }
end
