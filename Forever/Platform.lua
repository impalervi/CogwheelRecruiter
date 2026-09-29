local addonName, NS = ...
NS = NS or {}

-- WoW: Forever versions of CogwheelRecruiter_Platform.lua. Loaded by CogwheelRecruiter_Camelot.toc only.
-- Forever reports the retail project; the check keeps this file inert if a Classic client ever loaded it.
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    return
end

local Platform = NS.Platform

local SURNAME_SEPARATOR = (Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "

-- Blizzard's who windows are left alone on Forever. The one that opens with results there is the
-- group finder's Who list, not FriendsFrame, and Forever guards frame event registrations
-- (RegisterEvent/UnregisterEvent mark the frame). The list opens as it does for a typed /who.
function Platform.SilenceWhoUI()
end

-- Results back to chat afterwards, the game's default for the player's own /who.
function Platform.RestoreWhoUI()
    C_FriendList.SetWhoToUi(false)
end

-- Results always go to the who list (WHO_LIST_UPDATE), even when only a few players match.
function Platform.SendWho(query)
    C_FriendList.SetWhoToUi(true)
    C_FriendList.SendWho(query)
end

-- The exact-name search Blizzard's own player links use on Forever.
function Platform.GetExactNameWhoQuery(name)
    if WHO_TAG_EXACT and C_NameUtil and C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator then
        return WHO_TAG_EXACT .. C_NameUtil.ReplaceSurnameSeparatorWithLinkSeparator(name)
    end
    return 'n-"' .. name .. '"'
end

-- UnitName returns the surname second on Forever: "Barni", "Stormbraider".
function Platform.GetPlayerFullName()
    local name, surname = UnitName("player")
    if surname and surname ~= "" then
        return name .. SURNAME_SEPARATOR .. surname
    end
    return name
end

-- Forever names are "First Surname" with no realm; links and system messages write "First-Surname".
function Platform.GetShortName(name)
    return (name:gsub("%-", SURNAME_SEPARATOR))
end

-- Turns a Blizzard format string such as ERR_GUILD_JOIN_S ("%s has joined the guild.") into a match pattern.
local function PatternFromGlobalString(formatString)
    if type(formatString) ~= "string" or formatString == "" then
        return nil
    end
    local escaped = formatString:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    local pattern, count = escaped:gsub("%%s", "(.+)")
    if count ~= 1 then
        return nil
    end
    return "^" .. pattern
end

local function WithGameWording(formatString, classicPattern)
    local patterns = {}
    local fromGame = PatternFromGlobalString(formatString)
    if fromGame then
        table.insert(patterns, fromGame)
    end
    table.insert(patterns, classicPattern)
    return patterns
end

-- The game's own wording first (Forever says "declines your guild invitation"), then the Classic wording.
function Platform.GetGuildMessagePatterns()
    return WithGameWording(ERR_GUILD_DECLINE_S, "^(.*) declines guild invitation"),
        WithGameWording(ERR_GUILD_JOIN_S, "^(.*) has joined the guild")
end

-- "|Hplayer:...|h[First Surname]|h" or "First-Surname" -> "First Surname"
function Platform.NormalizeSystemMessageName(name)
    name = name:match("|h%[(.-)%]|h") or name
    return (name:gsub("%-", SURNAME_SEPARATOR))
end

-- Forever's close button template has a fixed frame level of 510, which draws it over any window
-- in the same strata. It is tied to its own window instead, and the window rises when clicked,
-- as Blizzard's windows (LFGParentFrame) do.
function Platform.SetupWindow(frame, closeButton)
    frame:SetToplevel(true)
    closeButton:SetFixedFrameLevel(false)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 2)
end

-- Forever's close button is an atlas button (red square); copying its highlight file shows the
-- whole atlas sheet. Use the matching red buttons, as Blizzard's MaximizeMinimizeButtonFrameTemplate does.
function Platform.StyleWindowModeButton(button, closeButton, mode)
    local atlas = (mode == "quick") and "RedButton-Condense" or "RedButton-Expand"
    button:SetSize(24, 24)
    button:SetPoint("RIGHT", closeButton, "LEFT", 0, 0)
    button:SetNormalAtlas(atlas)
    button:SetPushedAtlas(atlas .. "-Pressed")
    button:SetHighlightAtlas("RedButton-Highlight", "ADD")
end
