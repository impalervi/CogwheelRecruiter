local addonName, NS = ...
NS = NS or {}

NS.QuickScannerView = NS.QuickScannerView or {}
local QuickScannerView = NS.QuickScannerView

function QuickScannerView.Create(context)
    context = context or {}

    local quickFrame = context.quickFrame
    local quickView = context.quickView
    if not quickView then
        return nil
    end

    local quickUI = {}

    quickUI.topTabsRow = CreateFrame("Frame", nil, quickFrame)
    quickUI.topTabsRow:SetSize(190, 24)
    quickUI.topTabsRow:SetPoint("TOP", quickFrame, "TOP", 0, -30)

    quickUI.filtersTab = CreateFrame("Button", nil, quickUI.topTabsRow, "UIPanelButtonTemplate")
    quickUI.filtersTab:SetSize(88, 24)
    quickUI.filtersTab:SetPoint("LEFT", quickUI.topTabsRow, "LEFT", 0, 0)
    quickUI.filtersTab:SetText("Filters")
    quickUI.filtersTab:SetScript("OnClick", function()
        if context.onOpenFilters then
            context.onOpenFilters()
        end
    end)

    quickUI.whispersTab = CreateFrame("Button", nil, quickUI.topTabsRow, "UIPanelButtonTemplate")
    quickUI.whispersTab:SetSize(96, 24)
    quickUI.whispersTab:SetPoint("LEFT", quickUI.filtersTab, "RIGHT", 6, 0)
    quickUI.whispersTab:SetText("Whispers")
    quickUI.whispersTab:SetScript("OnClick", function()
        if context.onOpenWhispers then
            context.onOpenWhispers()
        end
    end)

    quickUI.nameText = quickView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    quickUI.nameText:SetPoint("TOP", quickView, "TOP", 0, -24)
    quickUI.nameText:SetText("No Candidate")

    quickUI.levelText = quickView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    quickUI.levelText:SetPoint("TOP", quickUI.nameText, "BOTTOM", 0, -8)
    quickUI.levelText:SetText("")

    quickUI.queueText = quickView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    quickUI.queueText:SetPoint("BOTTOM", quickView, "BOTTOM", 0, 56)
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

    quickUI.nextBtn:SetScript("OnClick", function()
        if context.onNext then
            context.onNext()
        end
    end)

    quickUI.whisperBtn:SetScript("OnClick", function()
        if context.onWhisper then
            context.onWhisper()
        end
    end)

    quickUI.inviteBtn:SetScript("OnClick", function()
        if context.onInvite then
            context.onInvite()
        end
    end)

    local function UpdateCard(statusText)
        local quickState = context.getQuickState and context.getQuickState() or nil
        if not quickState then
            quickUI.queueText:SetText("Queue: 0")
            quickUI.nameText:SetText("No Candidate")
            quickUI.levelText:SetText("")
            quickUI.statusText:SetText("Press Next to start scanning.")
            quickUI.nextBtn:SetText("Next")
            quickUI.nextBtn:Enable()
            quickUI.whisperBtn:Disable()
            quickUI.inviteBtn:Disable()
            return
        end

        local candidate = quickState.currentCandidate
        local queueCount = #(quickState.queue or {})
        quickUI.queueText:SetText("Queue: " .. queueCount)

        if candidate then
            local classTag = string.upper(candidate.class or "PRIEST")
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag] or nil
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

            local historyDB = context.getHistoryDB and context.getHistoryDB() or nil
            local whispersDB = context.getWhispersDB and context.getWhispersDB() or nil
            local getWhisperKey = context.getWhisperKey

            local history = historyDB and historyDB[candidate.name]
            local whisperState = nil
            if whispersDB and getWhisperKey then
                whisperState = whispersDB[getWhisperKey(candidate.name)]
            end

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

        if context.playerCanRecruit and not context.playerCanRecruit() then
            whisperEnabled = false
            inviteEnabled = false
        end

        if whisperEnabled then
            quickUI.whisperBtn:Enable()
        else
            quickUI.whisperBtn:Disable()
        end

        if inviteEnabled then
            quickUI.inviteBtn:Enable()
        else
            quickUI.inviteBtn:Disable()
        end

        if quickState.isScanning then
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
        elseif queueCount == 0 and (quickState.scannedZones or 0) > 0 then
            quickUI.statusText:SetText("No matches found yet. Click Next to search another zone.")
        else
            quickUI.statusText:SetText("Press Next to start scanning.")
        end
    end

    return {
        UpdateCard = UpdateCard,
        GetWhispersTabButton = function()
            return quickUI.whispersTab
        end,
    }
end

