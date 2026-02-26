local addonName, NS = ...
NS = NS or {}

NS.ScannerQuickViewsController = NS.ScannerQuickViewsController or {}
local ScannerQuickViewsController = NS.ScannerQuickViewsController

function ScannerQuickViewsController.Create(context)
    context = context or {}

    local scanView = context.scanView
    local quickFrame = context.quickFrame
    local quickView = context.quickView

    if not (scanView and quickFrame and quickView) then
        return nil
    end

    local scannerControls = nil
    if NS.ScannerView and NS.ScannerView.CreateControls then
        scannerControls = NS.ScannerView.CreateControls({
            parent = scanView,
            getZoneCategories = context.getZoneCategories,
            getSelectedZone = context.getSelectedSpecificZone,
            onZoneSelected = function(zoneName)
                if context.setSelectedSpecificZone then
                    context.setSelectedSpecificZone(zoneName)
                end
            end,
            onClearZoneSelection = function()
                if context.setSelectedSpecificZone then
                    context.setSelectedSpecificZone(nil)
                end
            end,
            onStartScan = context.onStartScan,
            onOpenFilters = context.onOpenMainFilters,
            dropdownFrameName = "CogwheelRecruiterSpecificDropDown",
            dropdownLabel = "Select Zone to Scan:",
            emptyZoneText = "Select a Zone...",
            startButtonText = "Start Scan",
            filtersTooltip = "Filters",
            width = 500,
            height = 80,
            dropdownWidth = 150,
        })
    end

    if not (scannerControls and scannerControls.scanBtn) then
        return nil
    end

    local scanBtn = scannerControls.scanBtn

    local scanScroll = CreateFrame("ScrollFrame", nil, scanView, "UIPanelScrollFrameTemplate")
    scanScroll:SetPoint("TOPLEFT", 0, -5)
    scanScroll:SetPoint("BOTTOMRIGHT", -25, 85)
    local scanContent = CreateFrame("Frame", nil, scanScroll)
    scanContent:SetSize(460, 1)
    scanScroll:SetScrollChild(scanContent)

    local scanResultsWatermark = scanView:CreateTexture(nil, "BACKGROUND")
    scanResultsWatermark:SetPoint("CENTER", scanScroll, "CENTER", 5, 0)
    scanResultsWatermark:SetSize(280, 280)
    scanResultsWatermark:SetTexture(context.scanWatermarkTexture or "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterLogoSimple_400x400")
    scanResultsWatermark:SetAlpha(0.08)
    if scanResultsWatermark.SetDesaturated then
        scanResultsWatermark:SetDesaturated(true)
    end

    local scannerViewAPI = nil
    if NS.ScannerView and NS.ScannerView.Create then
        scannerViewAPI = NS.ScannerView.Create({
            parent = scanContent,
            getSettingsDB = context.getSettingsDB,
            getHistoryDB = context.getHistoryDB,
            getWhispersDB = context.getWhispersDB,
            getWhisperKey = context.getWhisperKey,
            getMaxPlayerLevel = context.getMaxPlayerLevel,
            playerCanRecruit = context.playerCanRecruit,
            onPermissionDenied = context.onPermissionDenied,
            onWhisper = function(data)
                if context.onScannerWhisper then
                    return context.onScannerWhisper(data)
                end
                return false
            end,
            onInvite = function(data, button)
                if context.onScannerInvite then
                    context.onScannerInvite(data, button)
                end
            end,
        })
    end

    local quickScannerViewAPI = nil
    if NS.QuickScannerView and NS.QuickScannerView.Create then
        quickScannerViewAPI = NS.QuickScannerView.Create({
            quickFrame = quickFrame,
            quickView = quickView,
            getQuickState = context.getQuickState,
            getHistoryDB = context.getHistoryDB,
            getWhispersDB = context.getWhispersDB,
            getWhisperKey = context.getWhisperKey,
            playerCanRecruit = context.playerCanRecruit,
            onOpenFilters = context.onOpenQuickFilters,
            onOpenWhispers = context.onOpenQuickWhispers,
            onNext = context.onQuickNext,
            onWhisper = context.onQuickWhisper,
            onInvite = context.onQuickInvite,
        })
    end

    return {
        scanBtn = scanBtn,
        ClearScanView = function()
            if scannerViewAPI and scannerViewAPI.Clear then
                scannerViewAPI.Clear()
            end
        end,
        UpdateScanList = function(results)
            if scannerViewAPI and scannerViewAPI.UpdateList then
                scannerViewAPI.UpdateList(results)
            end
        end,
        UpdateQuickCandidateCard = function(statusText)
            if quickScannerViewAPI and quickScannerViewAPI.UpdateCard then
                quickScannerViewAPI.UpdateCard(statusText)
            end
        end,
        GetQuickWhispersTabButton = function()
            if quickScannerViewAPI and quickScannerViewAPI.GetWhispersTabButton then
                return quickScannerViewAPI.GetWhispersTabButton()
            end
            return nil
        end,
    }
end
