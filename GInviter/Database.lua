-- GInviter Database.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.Database = {}
local DB = GInviter.Database

local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = DeepCopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

function DB:Initialize()
    if not GInviterDB then
        GInviterDB = {}
    end
    
    -- Ensure required top-level tables exist
    GInviterDB.settings = GInviterDB.settings or DeepCopy(GInviter.Config.Defaults)
    GInviterDB.history = GInviterDB.history or {}       -- [playerName] = { timestamp, result, recruiter, guild, level, class }
    GInviterDB.blacklist = GInviterDB.blacklist or {}   -- [playerName] = { timestamp, reason, addedBy }
    GInviterDB.notes = GInviterDB.notes or {}           -- [playerName] = { text, tag, timestamp }
    GInviterDB.stats = GInviterDB.stats or {
        todayDate = date("%Y-%m-%d"),
        invited = 0,
        accepted = 0,
        declined = 0,
        alreadyGuilded = 0,
        ignored = 0,
        pending = 0,
    }

    -- Reset daily stats if date changed
    local currentDate = date("%Y-%m-%d")
    if GInviterDB.stats.todayDate ~= currentDate then
        GInviterDB.stats.todayDate = currentDate
        GInviterDB.stats.invited = 0
        GInviterDB.stats.accepted = 0
        GInviterDB.stats.declined = 0
        GInviterDB.stats.alreadyGuilded = 0
        GInviterDB.stats.ignored = 0
        GInviterDB.stats.pending = 0
    end
end

function DB:GetSettings()
    return GInviterDB.settings
end

-- Statistics Tracking
function DB:IncrementStat(statKey)
    if GInviterDB.stats[statKey] ~= nil then
        GInviterDB.stats[statKey] = GInviterDB.stats[statKey] + 1
    end
end

function DB:GetStats()
    return GInviterDB.stats
end

-- Invite History
function DB:RecordInvite(playerName, result, level, class, guild)
    local nameLower = string.lower(playerName)
    GInviterDB.history[nameLower] = {
        name = playerName,
        timestamp = time(),
        result = result or "INVITED", -- "INVITED", "ACCEPTED", "DECLINED", "EXPIRED", "GUILDED", "IGNORED"
        recruiter = UnitName("player"),
        level = level or 0,
        class = class or "UNKNOWN",
        guild = guild or "",
    }
end

function DB:UpdateInviteResult(playerName, result)
    local nameLower = string.lower(playerName)
    if GInviterDB.history[nameLower] then
        GInviterDB.history[nameLower].result = result
        GInviterDB.history[nameLower].timestamp = time()
    else
        self:RecordInvite(playerName, result)
    end
end

function DB:GetInviteHistory(playerName)
    return GInviterDB.history[string.lower(playerName)]
end

-- Duplicate Protection Evaluator
function DB:IsRecentInvite(playerName)
    local record = self:GetInviteHistory(playerName)
    if not record then return false end

    local now = time()
    local elapsed = now - (record.timestamp or 0)
    local window = GInviterDB.settings.dupWindow or "today"

    if window == "10m" then
        return elapsed < 600
    elseif window == "1h" then
        return elapsed < 3600
    elseif window == "today" then
        local recordDate = date("%Y-%m-%d", record.timestamp or 0)
        local todayDate = date("%Y-%m-%d", now)
        return recordDate == todayDate
    elseif window == "custom" then
        local customSecs = (GInviterDB.settings.dupCustomHours or 24) * 3600
        return elapsed < customSecs
    end

    return false
end

-- Blacklist Management
function DB:AddBlacklist(playerName, reason)
    local nameLower = string.lower(playerName)
    GInviterDB.blacklist[nameLower] = {
        name = playerName,
        timestamp = time(),
        reason = reason or "User Blacklisted",
        addedBy = UnitName("player")
    }
end

function DB:RemoveBlacklist(playerName)
    GInviterDB.blacklist[string.lower(playerName)] = nil
end

function DB:IsBlacklisted(playerName)
    return GInviterDB.blacklist[string.lower(playerName)] ~= nil
end

-- Player Notes & Tags
function DB:SetNote(playerName, text, tag)
    local nameLower = string.lower(playerName)
    GInviterDB.notes[nameLower] = {
        name = playerName,
        text = text or "",
        tag = tag or "General",
        timestamp = time()
    }
end

function DB:GetNote(playerName)
    return GInviterDB.notes[string.lower(playerName)]
end
