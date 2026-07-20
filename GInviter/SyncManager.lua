-- GInviter SyncManager.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.SyncManager = {}
local SM = GInviter.SyncManager

local SYNC_PREFIX = "GInviterSync"

-- Base64 Alphabet for String Export/Import
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function SM:Initialize()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(SYNC_PREFIX)
    end
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:SetScript("OnEvent", function(f, event, prefix, msg, channel, sender)
        if event == "CHAT_MSG_ADDON" and prefix == SYNC_PREFIX then
            SM:OnAddonMessage(msg, sender, channel)
        end
    end)
end

function SM:SendSyncMessage(action, data)
    if not IsInGuild() then return end
    local settings = GInviter.Database:GetSettings()
    if not settings.enableOfficerSync then return end

    local payload = action .. ":" .. (data or "")
    SendAddonMessage(SYNC_PREFIX, payload, "GUILD")
end

function SM:OnAddonMessage(msg, sender, channel)
    if sender == UnitName("player") then return end -- Ignore self

    local action, data = string.match(msg, "^(%A+):?(.*)$")
    if not action then return end

    if action == "ADD_BLACKLIST" then
        local targetName, reason = string.match(data, "^(.-);(.*)$")
        if targetName and targetName ~= "" then
            GInviter.Database:AddBlacklist(targetName, (reason or "Officer Sync") .. " (by " .. sender .. ")")
            DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter]|r Blacklist synced: " .. targetName .. " by " .. sender)
        end
    elseif action == "REMOVE_BLACKLIST" then
        if data and data ~= "" then
            GInviter.Database:RemoveBlacklist(data)
        end
    end
end

-- Base64 Encoding and Decoding for String Sharing
function SM:ExportToString(tbl)
    local str = ""
    for k, v in pairs(tbl) do
        str = str .. tostring(k) .. "=" .. tostring(v) .. ";"
    end

    -- Simple base64 encoder
    return (str:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#str % 3 + 1])
end

function SM:ImportFromString(b64Str)
    b64Str = string.gsub(b64Str, '[^'..b64chars..'=]', '')
    local str = b64Str:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b64chars:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end)

    local res = {}
    for pair in string.gmatch(str, "([^;]+)") do
        local k, v = string.match(pair, "^(.-)=(.*)$")
        if k and v then
            res[k] = v
        end
    end
    return res
end
