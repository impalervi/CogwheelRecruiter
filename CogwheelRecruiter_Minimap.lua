local addonName, NS = ...
NS = NS or {}

NS.Minimap = NS.Minimap or {}
local MinimapUI = NS.Minimap

function MinimapUI.Create(config)
    config = config or {}

    local minimapBtn = CreateFrame("Button", config.name or "CogwheelRecruiterMinimapButton", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameLevel(8)
    NS.Platform.SetupMinimapButton(minimapBtn)
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", -56, -56)
    minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(25, 25)
    bg:SetPoint("CENTER")

    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(config.iconTexture or "Interface\\AddOns\\CogwheelRecruiter\\Media\\CogwheelRecruiterIcon_64x64")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local border = minimapBtn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    local drag = NS.Platform.GetMinimapButtonDrag()

    local function GetSettings()
        if config.getSettings then
            return config.getSettings()
        end
        return nil
    end

    local function UpdatePosition()
        local settings = GetSettings()
        if not settings or not settings.minimapPos then return end

        local angle = math.rad(settings.minimapPos)
        local x, y = NS.Platform.GetMinimapButtonOffset(angle)
        minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    NS.Platform.WatchMinimapLayout(UpdatePosition)

    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- No click follows a drag (the game cancels it), so every OnClick is a real click.
    minimapBtn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if config.onLeftClick then
                config.onLeftClick()
            end
        elseif button == "RightButton" then
            if config.onRightClick then
                config.onRightClick()
            end
        end
    end)

    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(config.tooltipTitle or "Cogwheel Recruiter")
        GameTooltip:AddLine("Left-click: Open Scanner Mode", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Open Quick Scanner Mode", 1, 1, 1)
        GameTooltip:AddLine(drag.hint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", GameTooltip_Hide)

    minimapBtn:SetMovable(true)
    minimapBtn:RegisterForDrag(drag.button)
    minimapBtn:SetScript("OnDragStart", function(self)
        if drag.needsShift and not IsShiftKeyDown() then
            return
        end

        self:SetScript("OnUpdate", function()
            local settings = GetSettings()
            if not settings then
                return
            end

            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            settings.minimapPos = angle
            UpdatePosition()
        end)
    end)

    minimapBtn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    return {
        button = minimapBtn,
        UpdatePosition = UpdatePosition,
    }
end

