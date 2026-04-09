local addonName, NS = ...
NS = NS or {}

NS.WhispersView = NS.WhispersView or {}
local WhispersView = NS.WhispersView

function WhispersView.Create(context)
    context = context or {}

    local rows = {}
    local parent = context.parent
    local rowWidth = tonumber(context.rowWidth) or 460
    local rowHeight = tonumber(context.rowHeight) or 48
    local rowSpacing = tonumber(context.rowSpacing) or 50

    local function CreateWhisperRow()
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(rowWidth, rowHeight)

        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.nameText:SetPoint("TOPLEFT", 5, -3)
        row.nameText:SetWidth(120)
        row.nameText:SetJustifyH("LEFT")

        row.timeText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.timeText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -1)
        row.timeText:SetWidth(120)
        row.timeText:SetJustifyH("LEFT")

        row.guildTag = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.guildTag:SetPoint("TOPLEFT", row.timeText, "BOTTOMLEFT", 0, -1)
        row.guildTag:SetWidth(120)
        row.guildTag:SetJustifyH("LEFT")
        row.guildTag:SetTextColor(0.4, 0.7, 0.4)
        if row.guildTag.SetWordWrap then row.guildTag:SetWordWrap(false) end
        row.guildTag:SetText("")

        row.replyText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.replyText:SetPoint("TOPLEFT", 130, -5)
        row.replyText:SetPoint("BOTTOMRIGHT", -170, 5)
        row.replyText:SetJustifyH("LEFT")
        row.replyText:SetJustifyV("TOP")

        row.inviteBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.inviteBtn:SetSize(75, 20)
        row.inviteBtn:SetPoint("TOPRIGHT", -85, -5)
        row.inviteBtn:SetText("Invite")
        row.inviteBtn:SetNormalFontObject("GameFontNormalSmall")
        row.inviteBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.inviteBtn:SetDisabledFontObject("GameFontDisableSmall")

        row.checkInviteBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.checkInviteBtn:SetSize(75, 20)
        row.checkInviteBtn:SetPoint("TOPRIGHT", -85, -5)
        row.checkInviteBtn:SetText("Invite")
        row.checkInviteBtn:SetNormalFontObject("GameFontNormalSmall")
        row.checkInviteBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.checkInviteBtn:SetDisabledFontObject("GameFontDisableSmall")
        row.checkInviteBtn:Hide()

        row.clearBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.clearBtn:SetSize(75, 20)
        row.clearBtn:SetPoint("TOPRIGHT", -5, -5)
        row.clearBtn:SetText("Clear")
        row.clearBtn:SetNormalFontObject("GameFontNormalSmall")
        row.clearBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.clearBtn:SetDisabledFontObject("GameFontDisableSmall")

        return row
    end

    local function UpdateList()
        for _, row in ipairs(rows) do
            row:Hide()
        end

        local whispersDB = context.getWhispersDB and context.getWhispersDB() or nil
        if not whispersDB then
            if parent then
                parent:SetHeight(0)
            end
            return
        end

        local list = {}
        for key, data in pairs(whispersDB) do
            if type(data) == "table" and data.lastInbound and data.lastInbound ~= "" then
                table.insert(list, { key = key, name = (data.displayName or key), data = data })
            end
        end

        table.sort(list, function(a, b)
            return (a.data.lastInboundTime or 0) > (b.data.lastInboundTime or 0)
        end)

        local yOffset = 0
        local count = 0

        for _, item in ipairs(list) do
            count = count + 1
            if not rows[count] then
                rows[count] = CreateWhisperRow()
            end

            local row = rows[count]
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:Show()

            row.nameText:SetText(item.name)
            row.timeText:SetText(date("%m/%d %H:%M", item.data.lastInboundTime or time()))
            row.replyText:SetText(item.data.lastInbound)

            local isGuilded = item.data.guild and item.data.guild ~= ""
            if isGuilded then
                local guildDisplay = item.data.guild
                if string.len(guildDisplay) > 20 then
                    guildDisplay = string.sub(guildDisplay, 1, 19) .. "..."
                end
                row.guildTag:SetText("<" .. guildDisplay .. ">")
                row.guildTag:Show()
            else
                row.guildTag:SetText("")
                row.guildTag:Hide()
            end

            local alreadyInvited = item.data.invited == true
            local function SetInviteBtnHandler()
                row.inviteBtn:SetScript("OnClick", function(self)
                    if context.onInvite then
                        local ok = context.onInvite(item, self)
                        if ok == false then
                            return
                        end
                    end

                    item.data.invited = true
                    self:SetText("Invited")
                    self:Disable()
                    self:SetAlpha(0.6)
                    row.checkInviteBtn:Hide()
                end)
            end

            if isGuilded and not alreadyInvited then
                row.inviteBtn:Hide()
                row.checkInviteBtn:Show()
                row.checkInviteBtn:Enable()
                row.checkInviteBtn:SetAlpha(1.0)
                row.checkInviteBtn:SetText("Invite")

                row.checkInviteBtn:SetScript("OnClick", function(self)
                    if context.onCheckAndInvite then
                        context.onCheckAndInvite(item, self)
                    end
                end)
            elseif alreadyInvited then
                row.checkInviteBtn:Hide()
                row.inviteBtn:Show()
                row.inviteBtn:SetText("Invited")
                row.inviteBtn:Disable()
                row.inviteBtn:SetAlpha(0.6)
                SetInviteBtnHandler()
            else
                row.checkInviteBtn:Hide()
                row.inviteBtn:Show()
                row.inviteBtn:SetText("Invite")
                row.inviteBtn:Enable()
                row.inviteBtn:SetAlpha(1.0)
                SetInviteBtnHandler()
            end

            row.clearBtn:SetScript("OnClick", function()
                if context.onClear then
                    context.onClear(item)
                end
            end)

            yOffset = yOffset + rowSpacing
        end

        if parent then
            parent:SetHeight(yOffset)
        end
    end

    return {
        UpdateList = UpdateList,
    }
end
