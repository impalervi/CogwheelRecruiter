local addonName, NS = ...
NS = NS or {}

NS.Permissions = NS.Permissions or {}
local Permissions = NS.Permissions

Permissions._ctx = Permissions._ctx or {}

function Permissions.SetContext(ctx)
    Permissions._ctx = ctx or {}
end

local function IsInviteBypassEnabled()
    local getter = Permissions._ctx and Permissions._ctx.getInviteBypass
    if getter then
        return getter() and true or false
    end
    return false
end

function Permissions.PlayerHasGuild()
    local guildName = GetGuildInfo("player")
    return guildName ~= nil and guildName ~= ""
end

function Permissions.RawPlayerCanInviteGuildMembers()
    if C_GuildInfo and C_GuildInfo.CanInvite then
        return C_GuildInfo.CanInvite()
    end
    if CanGuildInvite then
        return CanGuildInvite()
    end
    if IsGuildLeader then
        return IsGuildLeader()
    end
    return false
end

function Permissions.PlayerCanInviteGuildMembers()
    if IsInviteBypassEnabled() then
        return true
    end
    return Permissions.RawPlayerCanInviteGuildMembers()
end

function Permissions.PlayerCanRecruitNow()
    return Permissions.PlayerHasGuild() and Permissions.PlayerCanInviteGuildMembers()
end