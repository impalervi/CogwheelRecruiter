local addonName, NS = ...
NS = NS or {}

NS.HistoryView = NS.HistoryView or {}
local HistoryView = NS.HistoryView

function HistoryView.Create(context)
    context = context or {}

    local rows = {}
    local parent = context.parent

    local function CreateInviteHistoryRow()
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(460, 32)

        row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row.nameText:SetPoint("LEFT", 8, 0)
        row.nameText:SetWidth(170)
        row.nameText:SetJustifyH("LEFT")

        row.actionBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.actionBtn:SetSize(84, 22)
        row.actionBtn:SetPoint("RIGHT", -6, 0)
        row.actionBtn:SetNormalFontObject("GameFontNormalSmall")
        row.actionBtn:SetHighlightFontObject("GameFontHighlightSmall")
        row.actionBtn:SetDisabledFontObject("GameFontDisableSmall")

        row.infoText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.infoText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)
        row.infoText:SetPoint("RIGHT", row.actionBtn, "LEFT", -8, 0)
        row.infoText:SetJustifyH("LEFT")

        return row
    end

    local function UpdateList()
        for _, row in ipairs(rows) do
            row:Hide()
        end

        local historyDB = context.getHistoryDB and context.getHistoryDB() or nil
        if not historyDB then
            if parent then
                parent:SetHeight(0)
            end
            return
        end

        local filter = ""
        if context.getFilterText then
            filter = string.lower(context.getFilterText() or "")
        end

        local list = {}
        for name, data in pairs(historyDB) do
            local isValid = type(data) == "table" and type(data.time) == "number"
            if isValid and (filter == "" or string.lower(name):find(filter, 1, true)) then
                table.insert(list, { name = name, data = data })
            end
        end

        table.sort(list, function(a, b)
            return a.data.time > b.data.time
        end)

        local yOffset = 0
        local count = 0
        local maxRows = math.min(#list, tonumber(context.maxRows) or 50)

        for i = 1, maxRows do
            local item = list[i]
            count = count + 1

            if not rows[count] then
                rows[count] = CreateInviteHistoryRow()
            end

            local row = rows[count]
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:Show()

            local data = item.data
            local name = item.name

            local classTag = string.upper(data.class or "PRIEST")
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag] or nil
            if color then
                row.nameText:SetTextColor(color.r, color.g, color.b)
            else
                row.nameText:SetTextColor(1, 1, 1)
            end

            row.nameText:SetText(name)

            local dateStr = date("%m/%d %H:%M", data.time)
            if data.action == "DECLINED" then
                row.infoText:SetText("|cffff4040Declined|r  |cff8f8f8f" .. dateStr .. "|r")
            elseif data.action == "JOINED" then
                row.infoText:SetText("|cff6fdc6fJoined|r  |cff8f8f8f" .. dateStr .. "|r")
            else
                row.infoText:SetText("|cffffd56aInvited|r  |cff8f8f8f" .. dateStr .. "|r")
            end

            if data.action == "JOINED" then
                row.actionBtn:SetText("Member")
                row.actionBtn:Disable()
                row.actionBtn:SetScript("OnClick", nil)
            else
                row.actionBtn:SetText("Re-Invite")
                row.actionBtn:Enable()
                row.actionBtn:SetScript("OnClick", function()
                    if context.onReinvite then
                        context.onReinvite(name)
                    end
                end)
            end

            yOffset = yOffset + 32
        end

        if parent then
            parent:SetHeight(yOffset)
        end
    end

    return {
        UpdateList = UpdateList,
    }
end

