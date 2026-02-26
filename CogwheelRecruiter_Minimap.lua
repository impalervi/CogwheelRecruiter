local addonName, NS = ...
NS = NS or {}

NS.Minimap = NS.Minimap or {}
local MinimapUI = NS.Minimap

function MinimapUI.Create(config)
    config = config or {}

    local minimapBtn = CreateFrame("Button", config.name or "CogwheelRecruiterMinimapButton", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameLevel(8)
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

    local minimapWasDragging = false

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
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapBtn:SetScript("OnClick", function(_, button)
        if minimapWasDragging then
            minimapWasDragging = false
            return
        end

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
        GameTooltip:AddLine("Shift + Right-drag: Move minimap icon", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    minimapBtn:SetScript("OnLeave", GameTooltip_Hide)

    minimapBtn:SetMovable(true)
    minimapBtn:RegisterForDrag("RightButton")
    minimapBtn:SetScript("OnDragStart", function(self)
        if not IsShiftKeyDown() then
            return
        end

        minimapWasDragging = true
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

