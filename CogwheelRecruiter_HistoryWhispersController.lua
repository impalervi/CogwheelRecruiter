local addonName, NS = ...
NS = NS or {}

NS.HistoryWhispersController = NS.HistoryWhispersController or {}
local HistoryWhispersController = NS.HistoryWhispersController

function HistoryWhispersController.Create(context)
    context = context or {}

    local historyView = context.historyView
    local whispersView = context.whispersView
    if not historyView or not whispersView then
        return nil
    end

    local updateHistoryList = nil
    local updateWhispersList = nil

    local searchBox = CreateFrame("EditBox", nil, historyView, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPLEFT", 10, -5)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(5, 0, 0, 0)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnTextChanged", function()
        if updateHistoryList then
            updateHistoryList()
        end
    end)

    local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", 5, 0)
    searchPlaceholder:SetText("Search Name...")
    searchBox:SetScript("OnEditFocusGained", function() searchPlaceholder:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            searchPlaceholder:Show()
        end
    end)

    local historyHint = historyView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    historyHint:SetPoint("TOPLEFT", 220, -8)
    historyHint:SetText("Showing last 50 invite outcomes")

    local clearBtn = CreateFrame("Button", nil, historyView, "UIPanelButtonTemplate")
    clearBtn:SetSize(140, 30)
    clearBtn:SetPoint("BOTTOM", 0, 10)
    clearBtn:SetText("Clear All History")
    clearBtn:SetScript("OnClick", function()
        if context.onClearHistory then
            context.onClearHistory()
        end
        if updateHistoryList then
            updateHistoryList()
        end
        if context.onHistoryCleared then
            context.onHistoryCleared()
        end
    end)

    local histScroll = CreateFrame("ScrollFrame", nil, historyView, "UIPanelScrollFrameTemplate")
    histScroll:SetPoint("TOPLEFT", 0, -35)
    histScroll:SetPoint("BOTTOMRIGHT", -25, 45)
    local histContent = CreateFrame("Frame", nil, histScroll)
    histContent:SetSize(420, 1)
    histScroll:SetScrollChild(histContent)

    local historyViewAPI = nil
    if NS.HistoryView and NS.HistoryView.Create then
        historyViewAPI = NS.HistoryView.Create({
            parent = histContent,
            getHistoryDB = function()
                return context.getHistoryDB and context.getHistoryDB() or nil
            end,
            getFilterText = function()
                return searchBox:GetText()
            end,
            maxRows = tonumber(context.maxRows) or 50,
            onReinvite = function(name)
                if context.onHistoryReinvite then
                    context.onHistoryReinvite(name)
                end
                if updateHistoryList then
                    updateHistoryList()
                end
            end,
        })
    end

    updateHistoryList = function()
        if historyViewAPI and historyViewAPI.UpdateList then
            historyViewAPI.UpdateList()
        end
    end

    local whispersHeader = whispersView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    whispersHeader:SetPoint("TOPLEFT", 10, -10)
    whispersHeader:SetText("Whisper Replies")

    local whispersHint = whispersView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    whispersHint:SetPoint("TOPLEFT", 10, -32)
    whispersHint:SetText("Incoming whisper replies from contacted players.")

    local whispersScroll = CreateFrame("ScrollFrame", nil, whispersView, "UIPanelScrollFrameTemplate")
    whispersScroll:SetPoint("TOPLEFT", 0, -50)
    whispersScroll:SetPoint("BOTTOMRIGHT", -25, 10)
    local whispersContent = CreateFrame("Frame", nil, whispersScroll)
    whispersContent:SetSize(460, 1)
    whispersScroll:SetScrollChild(whispersContent)

    local whispersViewAPI = nil
    if NS.WhispersView and NS.WhispersView.Create then
        whispersViewAPI = NS.WhispersView.Create({
            parent = whispersContent,
            getWhispersDB = function()
                return context.getWhispersDB and context.getWhispersDB() or nil
            end,
            onInvite = function(item)
                if context.onWhisperInvite then
                    return context.onWhisperInvite(item)
                end
                return false
            end,
            onClear = function(item)
                if context.onWhisperClear then
                    context.onWhisperClear(item)
                else
                    local db = context.getWhispersDB and context.getWhispersDB() or nil
                    if db then
                        db[item.key] = nil
                    end
                end
                if updateWhispersList then
                    updateWhispersList()
                end
            end,
        })
    end

    updateWhispersList = function()
        if whispersViewAPI and whispersViewAPI.UpdateList then
            whispersViewAPI.UpdateList()
        end
    end

    local whispersInbox = nil
    if NS.WhispersInbox and NS.WhispersInbox.Create then
        whispersInbox = NS.WhispersInbox.Create({
            getWhisperKey = context.getWhisperKey,
            getShortName = context.getShortName,
            getWhispersDB = function()
                return context.getWhispersDB and context.getWhispersDB() or nil
            end,
            getAnalyticsDB = function()
                return context.getAnalyticsDB and context.getAnalyticsDB() or nil
            end,
            recordWhisperAnswered = context.recordWhisperAnswered,
            startWhispersTabFlash = context.startWhispersTabFlash,
            getCurrentTab = context.getCurrentTab,
            updateWhispersList = function()
                if updateWhispersList then
                    updateWhispersList()
                end
            end,
        })
    end

    return {
        UpdateHistoryList = function()
            if updateHistoryList then
                updateHistoryList()
            end
        end,
        UpdateWhispersList = function()
            if updateWhispersList then
                updateWhispersList()
            end
        end,
        HandleInboundWhisper = function(msg, sender)
            if whispersInbox and whispersInbox.HandleInboundWhisper then
                return whispersInbox.HandleInboundWhisper(msg, sender)
            end
            return false
        end,
    }
end
