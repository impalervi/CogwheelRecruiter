local addonName, NS = ...
NS = NS or {}

-- WoW: Forever versions of CogwheelRecruiter_Platform.lua. Loaded by CogwheelRecruiter_Camelot.toc only.
local _, _, _, tocVersion = GetBuildInfo()
if not tocVersion or tocVersion < 16001 or tocVersion >= 20000 then
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

function Platform.RestoreWhoUI()
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

function Platform.NormalizeSystemMessageName(name)
    return (name:gsub("%-", SURNAME_SEPARATOR))
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
