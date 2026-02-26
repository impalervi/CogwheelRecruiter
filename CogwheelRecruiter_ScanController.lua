local addonName, NS = ...
NS = NS or {}

NS.ScanController = NS.ScanController or {}
local ScanController = NS.ScanController

function ScanController.Create(context)
    context = context or {}

    local scannerEngine = context.scannerEngine or {}
    local quickScannerEngine = context.quickScannerEngine or {}
    local analytics = context.analytics or {}

    local printFn = context.print or print

    local quickQueueTarget = tonumber(context.quickQueueTarget) or 10
    local quickQueueMax = tonumber(context.quickQueueMax) or 20
    local quickLevelBalanceBuckets = tonumber(context.quickLevelBalanceBuckets) or 4
    local quickZoneTimeoutSeconds = tonumber(context.quickZoneTimeoutSeconds) or 3.5
    local quickEmptyZoneStreakCap = tonumber(context.quickEmptyZoneStreakCap) or 8
    local whoQueryTimeoutSeconds = tonumber(context.whoQueryTimeoutSeconds) or 3.5
    local maxPlayerLevel = tonumber(context.maxPlayerLevel) or 70

    local scannerState
    if scannerEngine.NewRuntimeState then
        scannerState = scannerEngine.NewRuntimeState()
    else
        scannerState = {
            isScanning = false,
            isWaitingForWho = false,
            scanQueue = {},
            currentScanZone = "",
            accumulatedResults = {},
        }
    end

    local quickState
    if quickScannerEngine.NewState then
        quickState = quickScannerEngine.NewState(quickQueueTarget)
    else
        quickState = {
            isScanning = false,
            isWaitingForWho = false,
            scanQueue = {},
            currentScanZone = "",
            queue = {},
            seenNames = {},
            scannedZones = 0,
            totalZones = 0,
            refillTarget = quickQueueTarget,
            currentCandidate = nil,
            quietZones = 0,
            maxQuietZones = 0,
            filterSignature = nil,
            nextLevelBucket = 1,
            lastStartOffset = -1,
        }
    end

    local function getSettingsDB()
        return context.getSettingsDB and context.getSettingsDB() or nil
    end

    local function getHistoryDB()
        return context.getHistoryDB and context.getHistoryDB() or nil
    end

    local function getZoneCategories()
        return context.getZoneCategories and context.getZoneCategories() or {}
    end

    local function getClassList()
        return context.getClassList and context.getClassList() or {}
    end

    local function UpdateScanList(results)
        if context.updateScanList then
            context.updateScanList(results)
        end
    end

    local function ClearScanView()
        if context.clearScanView then
            context.clearScanView()
        end
    end

    local function UpdateQuickCandidateCard(statusText)
        if context.updateQuickCandidateCard then
            context.updateQuickCandidateCard(statusText)
        end
    end

    local function SendGuildInvite(playerName)
        if context.sendGuildInvite then
            context.sendGuildInvite(playerName)
            return
        end

        if C_GuildInfo and C_GuildInfo.Invite then
            C_GuildInfo.Invite(playerName)
        else
            GuildInvite(playerName)
        end
    end

    local function ResetQuickStateForFilterChange()
        if quickScannerEngine.ResetStateForFilterChange then
            quickScannerEngine.ResetStateForFilterChange(
                quickState,
                getSettingsDB(),
                getZoneCategories(),
                getClassList(),
                maxPlayerLevel,
                quickQueueTarget
            )
        end
    end

    local function EnsureQuickStateMatchesFilters()
        if quickScannerEngine.EnsureStateMatchesFilters then
            return quickScannerEngine.EnsureStateMatchesFilters(
                quickState,
                getSettingsDB(),
                getZoneCategories(),
                getClassList(),
                maxPlayerLevel,
                quickQueueTarget
            )
        end
        return false
    end

    local function PopNextQuickZone()
        if quickScannerEngine.PopNextZone then
            return quickScannerEngine.PopNextZone(
                quickState,
                getSettingsDB(),
                getZoneCategories(),
                getClassList(),
                maxPlayerLevel
            )
        end
        return nil
    end

    local function PromoteNextQuickCandidate()
        if quickScannerEngine.PromoteNextCandidate then
            quickScannerEngine.PromoteNextCandidate(
                quickState,
                getSettingsDB(),
                maxPlayerLevel,
                quickLevelBalanceBuckets
            )
        end
    end

    local function GetQuickCandidateCount()
        if quickScannerEngine.GetCandidateCount then
            return quickScannerEngine.GetCandidateCount(quickState)
        end
        return 0
    end

    local function FinishQuickRefill(statusText)
        if quickScannerEngine.FinishRefill then
            quickScannerEngine.FinishRefill(
                quickState,
                getSettingsDB(),
                maxPlayerLevel,
                quickLevelBalanceBuckets
            )
        end
        UpdateQuickCandidateCard(statusText)
    end

    local function CollectQuickWhoResults()
        if quickScannerEngine.CollectWhoResults then
            return quickScannerEngine.CollectWhoResults(
                quickState,
                getSettingsDB(),
                maxPlayerLevel,
                quickQueueMax,
                getHistoryDB()
            )
        end
        return 0
    end

    local ProcessNextQuickZone

    local function RequestQuickQueueRefill(targetCount)
        local refillResult = {}
        if quickScannerEngine.RequestQueueRefill then
            refillResult = quickScannerEngine.RequestQueueRefill(quickState, {
                settingsDB = getSettingsDB(),
                zoneCategories = getZoneCategories(),
                classList = getClassList(),
                maxPlayerLevel = maxPlayerLevel,
                queueTarget = quickQueueTarget,
                queueMax = quickQueueMax,
                emptyZoneStreakCap = quickEmptyZoneStreakCap,
                bucketLimit = quickLevelBalanceBuckets,
                targetCount = targetCount,
                standardScanInProgress = scannerState.isScanning,
            }) or {}
        end

        if refillResult.blockedByStandardScan then
            printFn("|cffff0000[Cogwheel]|r Standard scan in progress. Finish it before using Quick Scanner.")
            return
        end

        if refillResult.ready then
            UpdateQuickCandidateCard()
            return
        end

        if refillResult.noZones then
            UpdateQuickCandidateCard("No zones available for current filters.")
            return
        end

        if refillResult.started then
            ProcessNextQuickZone()
        end
    end

    local quickWhoListener = CreateFrame("Frame")
    quickWhoListener:Hide()
    quickWhoListener:SetScript("OnEvent", function(self, event)
        if event ~= "WHO_LIST_UPDATE" then return end

        quickState.isWaitingForWho = false
        self:UnregisterEvent("WHO_LIST_UPDATE")
        self:Hide()
        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

        local added = CollectQuickWhoResults()
        if added > 0 then
            quickState.quietZones = 0
        else
            quickState.quietZones = quickState.quietZones + 1
        end

        if GetQuickCandidateCount() >= quickState.refillTarget or GetQuickCandidateCount() >= quickQueueMax then
            FinishQuickRefill("Queue ready.")
            return
        end

        if quickState.quietZones >= quickState.maxQuietZones then
            FinishQuickRefill("No matching players found for current filters.")
            return
        end

        if not quickState.currentCandidate and #quickState.queue > 0 then
            PromoteNextQuickCandidate()
        end

        local queueCount = GetQuickCandidateCount()
        quickState.isScanning = false
        if queueCount == 0 then
            local zoneName = quickState.currentScanZone
            if not zoneName or zoneName == "" then
                zoneName = "this zone"
            end
            UpdateQuickCandidateCard(string.format("No matches in %s. Click Next to scan a different zone.", zoneName))
            return
        end

        UpdateQuickCandidateCard(string.format("Queue %d/%d. Click Next to continue scanning.", queueCount, quickState.refillTarget))
    end)

    ProcessNextQuickZone = function()
        if not quickState.isScanning or quickState.isWaitingForWho then return end

        if InCombatLockdown and InCombatLockdown() then
            FinishQuickRefill("Cannot run /who while in combat. Click Next after combat.")
            return
        end

        local zone = PopNextQuickZone()
        if not zone then
            FinishQuickRefill("No zones available for current filters.")
            return
        end

        UpdateQuickCandidateCard(string.format("Scanning %s...", zone))

        if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end
        quickWhoListener:RegisterEvent("WHO_LIST_UPDATE")
        quickWhoListener:Show()
        quickState.isWaitingForWho = true

        C_FriendList.SendWho(zone)

        C_Timer.After(quickZoneTimeoutSeconds, function()
            if quickState.isScanning and quickState.isWaitingForWho and quickState.currentScanZone == zone then
                quickState.isWaitingForWho = false
                quickWhoListener:UnregisterEvent("WHO_LIST_UPDATE")
                quickWhoListener:Hide()
                if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

                quickState.quietZones = quickState.quietZones + 1
                if quickState.quietZones >= quickState.maxQuietZones then
                    FinishQuickRefill("No matching players found for current filters.")
                    return
                end

                quickState.isScanning = false
                UpdateQuickCandidateCard(string.format("Scan timed out after %.1fs. Click Next to continue.", quickZoneTimeoutSeconds))
            end
        end)
    end

    local function HandleQuickNext()
        if quickState.isScanning then return end

        EnsureQuickStateMatchesFilters()

        if quickState.currentCandidate then
            if #quickState.queue > 0 then
                PromoteNextQuickCandidate()
            else
                quickState.currentCandidate = nil
            end
        elseif #quickState.queue > 0 then
            PromoteNextQuickCandidate()
        end

        if not quickState.currentCandidate and #quickState.queue == 0 then
            RequestQuickQueueRefill(quickQueueTarget)
            return
        end

        UpdateQuickCandidateCard()
    end

    local function HandleQuickWhisper()
        local candidate = quickState.currentCandidate
        if not candidate then return end
        if context.playerCanRecruitNow and not context.playerCanRecruitNow() then
            UpdateQuickCandidateCard(context.recruitPermissionRequiredText or "Guild invite permission required.")
            return
        end

        local sent = false
        if context.sendWhisperToPlayer then
            sent = context.sendWhisperToPlayer(candidate.name, candidate.class)
        end
        if sent then
            UpdateQuickCandidateCard("Whisper sent to " .. candidate.name)
        end
    end

    local function HandleQuickInvite()
        local candidate = quickState.currentCandidate
        if not candidate then return end
        if context.playerCanRecruitNow and not context.playerCanRecruitNow() then
            UpdateQuickCandidateCard(context.recruitPermissionRequiredText or "Guild invite permission required.")
            return
        end

        SendGuildInvite(candidate.name)

        local historyDB = getHistoryDB()
        if historyDB then
            historyDB[candidate.name] = {
                time = time(),
                action = "INVITED",
                class = string.upper(candidate.class or "PRIEST"),
                level = candidate.level,
            }
        end

        if analytics.RecordInviteSent then
            analytics.RecordInviteSent(candidate.name, candidate.class, candidate.level)
        end

        local settingsDB = getSettingsDB()
        if settingsDB and settingsDB.stats then
            settingsDB.stats.invited = (settingsDB.stats.invited or 0) + 1
        end

        UpdateQuickCandidateCard("Invitation sent to " .. candidate.name)
    end

    local scanLogic = CreateFrame("Frame")
    scanLogic:RegisterEvent("CHAT_MSG_SYSTEM")
    scanLogic:RegisterEvent("CHAT_MSG_WHISPER")
    scanLogic:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local msg, sender = ...
            if context.handleInboundWhisper then
                context.handleInboundWhisper(msg, sender)
            end
            return
        end

        local msg = ...
        local declinedName = string.match(msg, "^(.*) declines guild invitation")

        local historyDB = getHistoryDB()
        if declinedName and historyDB and historyDB[declinedName] then
            historyDB[declinedName].action = "DECLINED"
            historyDB[declinedName].time = time()
            if analytics.ClearPendingInvite then
                analytics.ClearPendingInvite(declinedName)
            end
            printFn("|cffff0000[Cogwheel]|r Detected decline: " .. declinedName)
        end

        local joinedName = string.match(msg, "^(.*) has joined the guild")
        if joinedName then
            local existing = (historyDB and historyDB[joinedName]) or {}
            if analytics.RecordInviteAccepted then
                analytics.RecordInviteAccepted(joinedName, existing.class, existing.level, existing.action)
            end

            if historyDB then
                historyDB[joinedName] = {
                    action = "JOINED",
                    time = time(),
                    class = existing.class or "PRIEST",
                    level = existing.level,
                }
            end

            local settingsDB = getSettingsDB()
            if settingsDB and settingsDB.stats then
                settingsDB.stats.joined = (settingsDB.stats.joined or 0) + 1
            end
            printFn("|cff00ff00[Cogwheel]|r " .. joinedName .. " joined!")
            if settingsDB and settingsDB.autoWelcomeEnabled and context.sendDelayedWelcomeMessage then
                context.sendDelayedWelcomeMessage(joinedName)
            end
        end
    end)

    local function GetZonesToScan()
        local selectedSpecificZone = context.getSelectedSpecificZone and context.getSelectedSpecificZone() or nil
        local fallbackZone = context.getCurrentZoneText and context.getCurrentZoneText() or ""

        if scannerEngine.GetZonesToScan then
            return scannerEngine.GetZonesToScan(selectedSpecificZone, fallbackZone)
        end

        local zones = {}
        if selectedSpecificZone and selectedSpecificZone ~= "" then
            table.insert(zones, selectedSpecificZone)
        elseif fallbackZone and fallbackZone ~= "" then
            table.insert(zones, fallbackZone)
        end
        return zones
    end

    local ProcessNextScan

    local whoListener = CreateFrame("Frame")
    whoListener:Hide()

    whoListener:SetScript("OnEvent", function(self, event)
        if event ~= "WHO_LIST_UPDATE" then return end

        scannerState.isWaitingForWho = false
        self:UnregisterEvent("WHO_LIST_UPDATE")
        self:Hide()

        if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

        if scannerEngine.CollectWhoResults then
            scannerEngine.CollectWhoResults(scannerState.accumulatedResults, scannerState.currentScanZone)
        end

        UpdateScanList(scannerState.accumulatedResults)
        if context.setScanButtonText then
            context.setScanButtonText("Cooldown...")
        end

        C_Timer.After(5.0, function()
            local flow = nil
            if scannerEngine.OnWhoEventComplete then
                flow = scannerEngine.OnWhoEventComplete(scannerState, getSettingsDB(), maxPlayerLevel)
            end

            if flow and flow.hasMore then
                local nextZone = flow.nextZone or scannerState.scanQueue[1] or ""
                if context.setScanButtonText then
                    context.setScanButtonText("Scan Next: " .. nextZone)
                end
                if context.enableScanButton then
                    context.enableScanButton()
                end
                printFn("|cff00ff00[Cogwheel]|r Zone scanned. Click button to scan next zone.")
                return
            end

            if context.setScanButtonText then
                context.setScanButtonText("Start Scan")
            end
            if context.enableScanButton then
                context.enableScanButton()
            end

            local totalCount = (flow and flow.totalCount) or #scannerState.accumulatedResults
            local visibleCount = (flow and flow.visibleCount) or 0

            printFn("|cff00ff00[Cogwheel]|r Scan Complete. Found " .. totalCount .. " unguilded players (" .. visibleCount .. " visible).")
        end)
    end)

    ProcessNextScan = function()
        local nextZone = nil
        if scannerEngine.PopNextZone then
            nextZone = scannerEngine.PopNextZone(scannerState)
        end

        if not nextZone or nextZone == "" then
            scannerState.isScanning = false
            if context.setScanButtonText then
                context.setScanButtonText("Start Scan")
            end
            if context.enableScanButton then
                context.enableScanButton()
            end
            return
        end

        if context.setScanButtonText then
            context.setScanButtonText("Scanning...")
        end
        printFn("|cff00ff00[Cogwheel]|r Scanning: " .. nextZone .. "...")

        if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end

        whoListener:RegisterEvent("WHO_LIST_UPDATE")
        whoListener:Show()

        scannerState.isWaitingForWho = true

        C_FriendList.SendWho(nextZone)

        C_Timer.After(whoQueryTimeoutSeconds, function()
            local timeoutState = nil
            if scannerEngine.OnWhoTimeout then
                timeoutState = scannerEngine.OnWhoTimeout(scannerState)
            end

            if not timeoutState or not timeoutState.timedOut then
                return
            end

            printFn("|cffff0000[Cogwheel]|r Scan timed out (server didn't respond). Resetting...")

            whoListener:UnregisterEvent("WHO_LIST_UPDATE")
            whoListener:Hide()
            if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end

            if timeoutState.hasMore then
                local nextZoneLabel = timeoutState.nextZone or scannerState.scanQueue[1] or ""
                if context.setScanButtonText then
                    context.setScanButtonText("Scan Next: " .. nextZoneLabel)
                end
            else
                if context.setScanButtonText then
                    context.setScanButtonText("Start Scan")
                end
            end
            if context.enableScanButton then
                context.enableScanButton()
            end
        end)
    end

    local function StartScanSequence()
        if quickState.isScanning then
            printFn("|cffff0000[Cogwheel]|r Quick Scanner is running. Please wait for it to complete.")
            return
        end

        if scannerState.isScanning and #scannerState.scanQueue > 0 then
            if context.disableScanButton then
                context.disableScanButton()
            end
            ProcessNextScan()
            return
        end

        if scannerState.isScanning then
            return
        end

        local zones = GetZonesToScan()
        local started = false
        if scannerEngine.BeginScan then
            started = scannerEngine.BeginScan(scannerState, zones)
        end

        if not started then
            return
        end

        ClearScanView()
        if context.disableScanButton then
            context.disableScanButton()
        end

        ProcessNextScan()
    end

    return {
        GetQuickState = function() return quickState end,
        ResetQuickScanState = ResetQuickStateForFilterChange,
        UpdateQuickCard = UpdateQuickCandidateCard,
        StartScanSequence = StartScanSequence,
        OnQuickNext = HandleQuickNext,
        OnQuickWhisper = HandleQuickWhisper,
        OnQuickInvite = HandleQuickInvite,
    }
end
