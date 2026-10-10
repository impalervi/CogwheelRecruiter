local addonName, NS = ...
NS = NS or {}

-- WoW: Forever versions of CogwheelRecruiter_Platform.lua. Loaded by CogwheelRecruiter_Camelot.toc only.
-- Forever reports its own project (WOW_PROJECT_CAMELOT, since 1.60.1.70205; the retail one before that).
-- The check keeps this file inert if a Classic client ever loaded it.
local isForever = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
    or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
if not isForever then
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

-- Blizzard's Who list turns results-to-UI on while it is shown and off when it is hidden
-- (LFGWhoListMixin OnShow/OnHide). After our /who, the setting goes back to that rule.
local function RestoreBlizzardWhoToUi()
    local whoList = LFGWhoListFrame
    C_FriendList.SetWhoToUi((whoList and whoList:IsVisible()) and true or false)
end

function Platform.RestoreWhoUI()
    RestoreBlizzardWhoToUi()
end

function Platform.EndWhoCheck()
    RestoreBlizzardWhoToUi()
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

-- The modern minimap is larger: the button sits just outside its edge and drags with the left button,
-- like other addons' minimap buttons. Placement follows LibDBIcon-1.0 (BugSack, RestedXP, Details):
-- the distance comes from the minimap's current size, and minimap addons that make it square or
-- cornered report the shape through GetMinimapShape(), so the button follows that edge.
local MINIMAP_BUTTON_GAP = 5

-- Per shape, whether each quarter is round: 1 bottom right, 2 bottom left, 3 top right, 4 top left.
local MINIMAP_ROUND_QUARTERS = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

function Platform.GetMinimapButtonOffset(angle)
    local x, y = math.cos(angle), math.sin(angle)
    local quarter = 1
    if x < 0 then quarter = quarter + 1 end
    if y > 0 then quarter = quarter + 2 end

    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local roundQuarters = MINIMAP_ROUND_QUARTERS[shape] or MINIMAP_ROUND_QUARTERS["ROUND"]
    local w = (Minimap:GetWidth() / 2) + MINIMAP_BUTTON_GAP
    local h = (Minimap:GetHeight() / 2) + MINIMAP_BUTTON_GAP
    if roundQuarters[quarter] then
        return x * w, y * h
    end

    -- Square corner: slide along the edges instead of the circle.
    local diagonalW = math.sqrt(2 * w * w) - 10
    local diagonalH = math.sqrt(2 * h * h) - 10
    return math.max(-w, math.min(x * diagonalW, w)), math.max(-h, math.min(y * diagonalH, h))
end

-- The minimap's final size and shape are known only once the UI has finished loading, as
-- LibDBIcon waits for PLAYER_LOGIN; minimap addons may also resize it later.
function Platform.WatchMinimapLayout(updatePosition)
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        updatePosition()
    end)
    Minimap:HookScript("OnSizeChanged", function()
        updatePosition()
    end)
end

function Platform.GetMinimapButtonDrag()
    return {
        button = "LeftButton",
        needsShift = false,
        hint = "Drag: Move minimap icon",
    }
end

-- Above the minimap's own art, at a fixed level, as LibDBIcon places its buttons.
function Platform.SetupMinimapButton(button)
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
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
