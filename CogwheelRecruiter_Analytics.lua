local addonName, NS = ...
NS = NS or {}

NS.Analytics = NS.Analytics or {}
local Analytics = NS.Analytics

Analytics._ctx = Analytics._ctx or {}

function Analytics.SetContext(ctx)
    Analytics._ctx = ctx or {}
end

local function GetDB()
    local getter = Analytics._ctx and Analytics._ctx.getDB
    if getter then
        return getter()
    end
    return nil
end

local function GetClassList()
    local getter = Analytics._ctx and Analytics._ctx.getClassList
    if getter then
        return getter()
    end
    return NS.CLASS_LIST or {}
end

local function GetZoneCategories()
    local getter = Analytics._ctx and Analytics._ctx.getZoneCategories
    if getter then
        return getter()
    end
    return NS.ZONE_CATEGORIES or {}
end

local function GetWhisperKey(name)
    if NS.Utils and NS.Utils.GetWhisperKey then
        return NS.Utils.GetWhisperKey(name)
    end
    return name or ""
end

function Analytics.EnsureDefaults()
    local db = GetDB()
    if not db then
        return
    end

    if NS.EnsureAnalyticsDefaults then
        NS.EnsureAnalyticsDefaults(db, GetClassList(), GetZoneCategories())
        return
    end

    db.whispered = tonumber(db.whispered) or 0
    db.whispersAnswered = tonumber(db.whispersAnswered) or 0
    db.invited = tonumber(db.invited) or 0
    db.accepted = tonumber(db.accepted) or 0
    db.invitesByClass = db.invitesByClass or {}
    db.acceptedByClass = db.acceptedByClass or {}
    db.invitesByLevel = db.invitesByLevel or {}
    db.acceptedByLevel = db.acceptedByLevel or {}
    db.pendingWhispers = db.pendingWhispers or {}
    db.pendingInvites = db.pendingInvites or {}
end

function Analytics.IncrementCounter(map, key, amount)
    if not map or not key then
        return
    end
    local delta = amount or 1
    map[key] = (tonumber(map[key]) or 0) + delta
end

function Analytics.NormalizeClassTag(classToken)
    local upper = string.upper(classToken or "PRIEST")
    if upper == "" then
        upper = "PRIEST"
    end
    return upper
end

function Analytics.GetLevelCategory(level)
    local nameFn = Analytics._ctx and Analytics._ctx.getLevelCategoryName
    if nameFn then
        return nameFn(level, GetZoneCategories())
    end
    if NS.GetLevelCategoryName then
        return NS.GetLevelCategoryName(level, GetZoneCategories())
    end
    return "Other"
end

function Analytics.RecordWhisperSent(targetName)
    local db = GetDB()
    if not db then
        return
    end
    Analytics.EnsureDefaults()

    db.whispered = (db.whispered or 0) + 1
    db.pendingWhispers[GetWhisperKey(targetName)] = true
end

function Analytics.RecordWhisperAnswered(sender)
    local db = GetDB()
    if not db then
        return
    end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(sender)
    if db.pendingWhispers[key] then
        db.whispersAnswered = (db.whispersAnswered or 0) + 1
        db.pendingWhispers[key] = nil
    end
end

function Analytics.RecordInviteSent(targetName, targetClass, targetLevel)
    local db = GetDB()
    if not db then
        return
    end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(targetName)
    local classTag = Analytics.NormalizeClassTag(targetClass)
    local levelCategory = Analytics.GetLevelCategory(targetLevel)

    db.invited = (db.invited or 0) + 1
    Analytics.IncrementCounter(db.invitesByClass, classTag, 1)
    Analytics.IncrementCounter(db.invitesByLevel, levelCategory, 1)

    db.pendingInvites[key] = {
        class = classTag,
        level = targetLevel,
        levelCategory = levelCategory,
        time = time()
    }
end

function Analytics.ClearPendingInvite(targetName)
    local db = GetDB()
    if not db then
        return
    end
    Analytics.EnsureDefaults()
    db.pendingInvites[GetWhisperKey(targetName)] = nil
end

function Analytics.RecordInviteAccepted(targetName, fallbackClass, fallbackLevel, previousAction)
    local db = GetDB()
    if not db then
        return
    end
    Analytics.EnsureDefaults()

    local key = GetWhisperKey(targetName)
    local pending = db.pendingInvites[key]
    local shouldCount = (pending ~= nil) or (previousAction == "INVITED")
    if not shouldCount then
        return
    end

    local classTag = Analytics.NormalizeClassTag((pending and pending.class) or fallbackClass)
    local levelCategory = (pending and pending.levelCategory) or Analytics.GetLevelCategory((pending and pending.level) or fallbackLevel)

    db.accepted = (db.accepted or 0) + 1
    Analytics.IncrementCounter(db.acceptedByClass, classTag, 1)
    Analytics.IncrementCounter(db.acceptedByLevel, levelCategory, 1)

    db.pendingInvites[key] = nil
end
