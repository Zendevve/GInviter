-- GInviter FilterEngine.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.FilterEngine = {}
local FE = GInviter.FilterEngine

-- Friends Cache
local friendCache = {}
local ignoreCache = {}

function FE:RefreshSocialCaches()
    friendCache = {}
    ignoreCache = {}

    local numFriends = GetNumFriends()
    for i = 1, numFriends do
        local name = GetFriendInfo(i)
        if name then
            friendCache[string.lower(name)] = true
        end
    end

    local numIgnores = GetNumIgnores()
    for i = 1, numIgnores do
        local name = GetIgnoreName(i)
        if name then
            ignoreCache[string.lower(name)] = true
        end
    end
end

function FE:EvaluatePlayer(player)
    if not player or not player.name then
        return false, "Invalid Player Data"
    end

    local settings = GInviter.Database:GetSettings()
    local filters = settings.filters or GInviter.Config.Defaults.filters
    local nameLower = string.lower(player.name)

    -- 1. Self Check
    if nameLower == string.lower(UnitName("player")) then
        return false, "Is Yourself"
    end

    -- 2. Guilded Check
    if filters.noGuildOnly and player.guild and player.guild ~= "" then
        return false, "Guilded (" .. player.guild .. ")"
    end

    -- 3. Blacklist Check
    if filters.excludeBlacklisted and GInviter.Database:IsBlacklisted(player.name) then
        return false, "Blacklisted"
    end

    -- 4. Recent Invite Check
    if filters.excludeRecentInvites and GInviter.Database:IsRecentInvite(player.name) then
        return false, "Already Invited Recently"
    end

    -- 5. Friend Check
    if filters.excludeFriends and friendCache[nameLower] then
        return false, "Friend"
    end

    -- 6. Ignore Check
    if filters.excludeIgnores and ignoreCache[nameLower] then
        return false, "Ignored"
    end

    -- 7. Level Filter
    local level = tonumber(player.level) or 0
    if level < filters.minLevel or level > filters.maxLevel then
        return false, "Level " .. level .. " out of range (" .. filters.minLevel .. "-" .. filters.maxLevel .. ")"
    end

    -- 8. Name Filter (Substring Search)
    if filters.playerNameFilter and filters.playerNameFilter ~= "" then
        if not string.find(nameLower, string.lower(filters.playerNameFilter)) then
            return false, "Name Does Not Match Filter"
        end
    end

    -- 9. Zone Filter
    if filters.zoneFilter and filters.zoneFilter ~= "" and player.zone then
        if not string.find(string.lower(player.zone), string.lower(filters.zoneFilter)) then
            return false, "Zone Does Not Match Filter"
        end
    end

    -- 10. Guild Name Filter (if searching specific guild candidate pool)
    if filters.guildNameFilter and filters.guildNameFilter ~= "" and player.guild then
        if not string.find(string.lower(player.guild), string.lower(filters.guildNameFilter)) then
            return false, "Guild Name Does Not Match Filter"
        end
    end

    return true, "Eligible"
end
