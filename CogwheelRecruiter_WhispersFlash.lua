local addonName, NS = ...
NS = NS or {}

NS.WhispersFlash = NS.WhispersFlash or {}
local WhispersFlash = NS.WhispersFlash

function WhispersFlash.Create(config)
    config = config or {}

    local tabButton = config.tabButton
    local getCurrentTab = config.getCurrentTab or function() return nil end
    local activeTabId = config.activeTabId or 6
    local inactiveAlpha = config.inactiveAlpha or 0.85

    local isFlashing = false
    local hasUnread = false
    local highlightTicker = nil
    local highlightOn = false

    local function Stop()
        isFlashing = false
        hasUnread = false

        if highlightTicker then
            highlightTicker:Cancel()
            highlightTicker = nil
        end

        highlightOn = false
        if tabButton then
            tabButton:UnlockHighlight()
            tabButton:SetAlpha((getCurrentTab() == activeTabId) and 1.0 or inactiveAlpha)
        end
    end

    local function Start()
        if not tabButton then
            return
        end

        if getCurrentTab() == activeTabId then
            return
        end

        hasUnread = true
        if isFlashing then
            return
        end

        isFlashing = true

        if not (C_Timer and C_Timer.NewTicker) then
            tabButton:LockHighlight()
            highlightOn = true
            return
        end

        highlightOn = true
        tabButton:LockHighlight()
        highlightTicker = C_Timer.NewTicker(0.6, function()
            if not isFlashing or not hasUnread then
                return
            end

            highlightOn = not highlightOn
            if highlightOn then
                tabButton:LockHighlight()
            else
                tabButton:UnlockHighlight()
            end
        end)
    end

    return {
        Start = Start,
        Stop = Stop,
    }
end

