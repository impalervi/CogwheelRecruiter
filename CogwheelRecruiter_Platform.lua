local addonName, NS = ...
NS = NS or {}

-- Client-specific behavior used by the shared logic. This file is the Classic behavior
-- (TBC Classic, Classic Era, ...). Forever\Platform.lua replaces these on WoW: Forever only.
NS.Platform = NS.Platform or {}
local Platform = NS.Platform

-- Keeps Blizzard's Who window from opening while our own /who is out.
function Platform.SilenceWhoUI()
    if FriendsFrame then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end
end

function Platform.RestoreWhoUI()
    if FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
end

function Platform.SendWho(query)
    C_FriendList.SendWho(query)
end

function Platform.GetExactNameWhoQuery(name)
    return 'n-"' .. name .. '"'
end

function Platform.GetPlayerFullName()
    return UnitName("player")
end

-- "Name-Realm" -> "Name"
function Platform.GetShortName(name)
    return (name:match("^[^-]+") or name)
end

-- CHAT_MSG_SYSTEM patterns for a declined guild invite and for a new guild member.
function Platform.GetGuildMessagePatterns()
    return { "^(.*) declines guild invitation" }, { "^(.*) has joined the guild" }
end

-- Names in guild system messages already match the names /who returns.
function Platform.NormalizeSystemMessageName(name)
    return name
end

-- Extra setup for the main and Quick Scanner windows (frame, closeButton); none needed here.
function Platform.SetupWindow()
end

-- Minimap button: its distance from the minimap's center, and how it is dragged around it.
function Platform.GetMinimapButtonRadius()
    return 80
end

function Platform.GetMinimapButtonDrag()
    return {
        button = "RightButton",
        needsShift = true,
        hint = "Shift + Right-drag: Move minimap icon",
        suppressClickAfterDrag = true,
    }
end

-- Extra setup for the minimap button (button); none needed here.
function Platform.SetupMinimapButton()
end

-- The button left of a window's close button that switches windows.
-- mode: "quick" (full window -> Quick Scanner) or "full" (Quick Scanner -> full window).
function Platform.StyleWindowModeButton(button, closeButton, mode)
    local texture = (mode == "quick") and "Interface\\Buttons\\UI-Panel-ExpandButton"
        or "Interface\\Buttons\\UI-Panel-CollapseButton"
    button:SetSize(32, 32)
    button:SetPoint("RIGHT", closeButton, "LEFT", 10, 0)
    button:SetNormalTexture(texture .. "-Up")
    button:SetPushedTexture(texture .. "-Down")

    local closeHighlight = closeButton:GetHighlightTexture()
    if closeHighlight and closeHighlight:GetTexture() then
        button:SetHighlightTexture(closeHighlight:GetTexture(), "ADD")
    else
        button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    end
end
