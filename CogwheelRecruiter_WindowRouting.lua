local addonName, NS = ...
NS = NS or {}

NS.WindowRouting = NS.WindowRouting or {}
local WindowRouting = NS.WindowRouting

function WindowRouting.Create(context)
    context = context or {}

    local addonVersion = tostring(context.addonVersion or "")
    local welcomeStartTab = 1

    local function IsWelcomeRequired(settingsDB)
        if not settingsDB then
            return false
        end

        if context.getDebugAlwaysShowWelcome and context.getDebugAlwaysShowWelcome() then
            return true
        end

        if settingsDB.splashSeen ~= true then
            return true
        end

        if addonVersion ~= "" and settingsDB.splashSeenVersion ~= addonVersion then
            return true
        end

        return false
    end

    local function MarkWelcomeSeen(settingsDB)
        if not settingsDB then
            return
        end

        settingsDB.splashSeen = true
        if addonVersion ~= "" then
            settingsDB.splashSeenVersion = addonVersion
        end
    end

    local function ShowMainAddonWindow(forceScanner)
        context.quickFrame:Hide()
        context.mainFrame:Show()

        local setWelcomeMode = context.getSetWelcomeMode and context.getSetWelcomeMode() or nil
        if setWelcomeMode then
            setWelcomeMode(false)
        elseif context.welcomeFrame then
            context.welcomeFrame:Hide()
        end

        if forceScanner then
            context.setTab(1)
        else
            context.setTab((context.getCurrentTab and context.getCurrentTab()) or 1)
        end
    end

    local function UpdateWelcomeState(forceScanner)
        local settingsDB = context.getSettingsDB and context.getSettingsDB() or nil
        if not settingsDB then
            return
        end

        local guildName = GetGuildInfo("player")
        local hasGuild = guildName ~= nil and guildName ~= ""
        local canInvite = hasGuild and context.playerCanInviteGuildMembers()
        local firstLaunchOrUpdate = IsWelcomeRequired(settingsDB)
        local blocked = (not hasGuild) or (not canInvite)

        if blocked or firstLaunchOrUpdate then
            context.mainFrame:Show()

            local setWelcomeMode = context.getSetWelcomeMode and context.getSetWelcomeMode() or nil
            if setWelcomeMode then
                setWelcomeMode(true)
            elseif context.welcomeFrame then
                context.welcomeFrame:Show()
            end

            if not hasGuild then
                context.welcomeStartBtn:SetText("You Don't Currently Have A Guild")
                context.welcomeStartBtn:Disable()
                context.welcomeStatus:SetText("|cffff6666You need to be in a guild to use Cogwheel Recruiter.|r")
            elseif not canInvite then
                context.welcomeStartBtn:SetText("You Can Not Invite Members To Your Guild")
                context.welcomeStartBtn:Disable()
                context.welcomeStatus:SetText("|cffff6666Your current guild rank does not have invite permissions.|r")
            else
                context.welcomeStartBtn:SetText("Start Scanning")
                context.welcomeStartBtn:Enable()
                context.welcomeStatus:SetText(context.welcomeNotesDisplay or "")
            end
            return
        end

        ShowMainAddonWindow(forceScanner)
    end

    local function ShowAddonWindow(forceScanner)
        local settingsDB = context.getSettingsDB and context.getSettingsDB() or nil
        if settingsDB then
            welcomeStartTab = forceScanner and 1 or ((context.getCurrentTab and context.getCurrentTab()) or 1)
            UpdateWelcomeState(forceScanner)
            return
        end
        ShowMainAddonWindow(forceScanner)
    end

    local function OpenQuickScannerWindow()
        local settingsDB = context.getSettingsDB and context.getSettingsDB() or nil
        if not settingsDB then
            ShowMainAddonWindow(false)
            context.setTab(8)
            return
        end

        local guildName = GetGuildInfo("player")
        local hasGuild = guildName ~= nil and guildName ~= ""
        local canInvite = hasGuild and context.playerCanInviteGuildMembers()
        local blocked = (not hasGuild) or (not canInvite)
        local firstLaunchOrUpdate = IsWelcomeRequired(settingsDB)

        if blocked or firstLaunchOrUpdate then
            welcomeStartTab = 8
            UpdateWelcomeState(false)
            return
        end

        ShowMainAddonWindow(false)
        context.setTab(8)
    end

    local function ToggleAddonWindow()
        if context.mainFrame:IsShown() or context.welcomeFrame:IsShown() or context.quickFrame:IsShown() then
            context.mainFrame:Hide()
            context.welcomeFrame:Hide()
            context.quickFrame:Hide()
            return
        end
        ShowAddonWindow(false)
    end

    local function OnWelcomeStartClicked()
        local guildName = GetGuildInfo("player")
        local hasGuild = guildName ~= nil and guildName ~= ""
        if not hasGuild or not context.playerCanInviteGuildMembers() then
            UpdateWelcomeState(true)
            return
        end

        local settingsDB = context.getSettingsDB and context.getSettingsDB() or nil
        MarkWelcomeSeen(settingsDB)

        local targetTab = welcomeStartTab
        welcomeStartTab = 1

        if targetTab == 8 then
            ShowMainAddonWindow(false)
            context.setTab(8)
            return
        end

        ShowMainAddonWindow(true)
    end

    return {
        ShowMainAddonWindow = ShowMainAddonWindow,
        UpdateWelcomeState = UpdateWelcomeState,
        ShowAddonWindow = ShowAddonWindow,
        OpenQuickScannerWindow = OpenQuickScannerWindow,
        ToggleAddonWindow = ToggleAddonWindow,
        OnWelcomeStartClicked = OnWelcomeStartClicked,
    }
end
