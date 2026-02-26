local addonName, NS = ...
NS = NS or {}

NS.TemplatePreview = NS.TemplatePreview or {}
local TemplatePreview = NS.TemplatePreview

function TemplatePreview.BuildPreviewState(template, previewText, maxChars)
    local utils = NS.Utils or {}
    local countWords = utils.CountWords or function(text)
        local n = 0
        for _ in string.gmatch(text or "", "%S+") do
            n = n + 1
        end
        return n
    end

    local templateSafe = template or ""
    local previewSafe = previewText or ""
    local limit = tonumber(maxChars) or 255

    local templateChars = string.len(templateSafe)
    local templateWords = countWords(templateSafe)
    local previewChars = string.len(previewSafe)
    local overLimit = previewChars > limit

    return {
        countText = string.format("Template: %d chars, %d words | Final: %d/%d chars", templateChars, templateWords, previewChars, limit),
        overLimit = overLimit,
    }
end

function TemplatePreview.ApplyCountToFontString(fontString, state)
    if not fontString or not state then
        return
    end

    fontString:SetText(state.countText or "")
    if state.overLimit then
        fontString:SetTextColor(1, 0.2, 0.2)
    else
        fontString:SetTextColor(0.7, 0.9, 0.7)
    end
end

