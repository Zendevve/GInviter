-- GInviter Config.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.Config = GInviter.Config or {}

-- Default Configuration Table
GInviter.Config.Defaults = {
    -- Duplicate Protection & General Timing
    dupWindow = "today", -- "10m", "1h", "today", "custom"
    dupCustomHours = 24,
    inviteInterval = 3, -- seconds between invites in auto mode
    whoScanDelay = 5,   -- seconds between level-sliced /who queries
    
    -- Auto-Whisper Options
    autoWhisper = false,
    whisperTimeout = 20, -- seconds to wait for player response
    whisperTimeoutAction = "skip", -- "skip" or "invite"
    whisperTemplates = {
        [1] = "Hey! We're recruiting friendly active players. Would you like a guild invite?",
        [2] = "Greetings! Our guild is looking for new members for questing and dungeons. Interested in joining?",
    },
    activeTemplateIndex = 1,

    -- NLP Keywords for Auto-Whisper Response Parsing
    affirmativeKeywords = {
        ["yes"] = true, ["y"] = true, ["sure"] = true, ["inv"] = true,
        ["invite"] = true, ["ok"] = true, ["1"] = true, ["please"] = true,
        ["yep"] = true, ["yea"] = true, ["yeah"] = true, ["pls"] = true,
    },
    negativeKeywords = {
        ["no"] = true, ["n"] = true, ["pass"] = true, ["stop"] = true,
        ["full"] = true, ["busy"] = true, ["quit"] = true, ["decline"] = true,
        ["nah"] = true, ["nope"] = true,
    },

    -- Filters Default Values
    filters = {
        noGuildOnly = true,
        onlineOnly = true,
        minLevel = 1,
        maxLevel = 80,
        excludeFriends = true,
        excludeIgnores = true,
        excludeRecentInvites = true,
        excludeRecentWhispers = true,
        excludeBlacklisted = true,
        raceMask = 0xFFFF,  -- all races
        classMask = 0xFFFF, -- all classes
        guildNameFilter = "",
        playerNameFilter = "",
        zoneFilter = "",
    },

    -- Automation & Fallback Modes
    fallbackMode = false, -- force single-click macro fallback mode
    autoScanLevelSlicing = true,
    levelSliceStep = 10,
    
    -- Sync Options
    enableOfficerSync = true,

    -- UI Settings
    minimap = {
        hide = false,
        minimapPos = 220,
    }
}
