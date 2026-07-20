-- GInviter WhisperHandler.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.WhisperHandler = {}
local WH = GInviter.WhisperHandler

WH.pendingWhispers = {} -- [playerNameLower] = { name, timestamp, timerFrame, onAffirmative, onNegative, onTimeout }

function WH:Initialize()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_WHISPER")
    self.frame:SetScript("OnEvent", function(f, event, msg, sender, ...)
        if event == "CHAT_MSG_WHISPER" then
            WH:OnIncomingWhisper(msg, sender)
        end
    end)
end

function WH:SendRecruitmentWhisper(targetName, onAffirmative, onNegative, onTimeout)
    if not targetName or targetName == "" then return end
    
    local settings = GInviter.Database:GetSettings()
    local tIdx = settings.activeTemplateIndex or 1
    local templates = settings.whisperTemplates or GInviter.Config.Defaults.whisperTemplates
    local msgText = templates[tIdx] or templates[1]

    -- Send whisper
    SendChatMessage(msgText, "WHISPER", nil, targetName)

    local targetLower = string.lower(targetName)
    local timeout = settings.whisperTimeout or 20

    -- Create timeout handler frame
    local elapsed = 0
    local timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function(f, el)
        elapsed = elapsed + el
        if elapsed >= timeout then
            f:SetScript("OnUpdate", nil)
            WH:OnWhisperTimeout(targetName)
        end
    end)

    self.pendingWhispers[targetLower] = {
        name = targetName,
        timestamp = time(),
        timerFrame = timerFrame,
        onAffirmative = onAffirmative,
        onNegative = onNegative,
        onTimeout = onTimeout,
    }
end

function WH:OnIncomingWhisper(msg, sender)
    local senderClean = string.gsub(sender, "-.*", "") -- Strip realm name if present
    local senderLower = string.lower(senderClean)
    local entry = self.pendingWhispers[senderLower]

    if not entry then return end -- Not a tracked whisper target

    -- Cancel timeout timer
    if entry.timerFrame then
        entry.timerFrame:SetScript("OnUpdate", nil)
    end
    self.pendingWhispers[senderLower] = nil

    -- Clean and parse message content
    local msgClean = string.lower(msg)
    msgClean = string.gsub(msgClean, "%p", "") -- Remove punctuation
    msgClean = string.gsub(msgClean, "^%s*(.-)%s*$", "%1") -- Trim whitespace

    local settings = GInviter.Database:GetSettings()
    local affKeywords = settings.affirmativeKeywords or GInviter.Config.Defaults.affirmativeKeywords
    local negKeywords = settings.negativeKeywords or GInviter.Config.Defaults.negativeKeywords

    local isAffirmative = false
    local isNegative = false

    -- Check word tokens
    for word in string.gmatch(msgClean, "%S+") do
        if affKeywords[word] then
            isAffirmative = true
            break
        elseif negKeywords[word] then
            isNegative = true
            break
        end
    end

    if isAffirmative then
        if entry.onAffirmative then
            entry.onAffirmative(entry.name, msg)
        end
    elseif isNegative then
        if entry.onNegative then
            entry.onNegative(entry.name, msg)
        end
    else
        -- Unrecognized response -> default to timeout/skip handling
        if entry.onNegative then
            entry.onNegative(entry.name, msg)
        end
    end
end

function WH:OnWhisperTimeout(targetName)
    local targetLower = string.lower(targetName)
    local entry = self.pendingWhispers[targetLower]
    if not entry then return end

    self.pendingWhispers[targetLower] = nil
    if entry.onTimeout then
        entry.onTimeout(entry.name)
    end
end

function WH:CancelPendingWhisper(targetName)
    local targetLower = string.lower(targetName)
    local entry = self.pendingWhispers[targetLower]
    if entry then
        if entry.timerFrame then
            entry.timerFrame:SetScript("OnUpdate", nil)
        end
        self.pendingWhispers[targetLower] = nil
    end
end
