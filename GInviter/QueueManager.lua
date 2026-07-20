-- GInviter QueueManager.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.QueueManager = {}
local QM = GInviter.QueueManager

QM.queue = {}           -- Array of player tables: { name, level, class, race, guild, status }
QM.isRunning = false
QM.currentIndex = 1
QM.timerFrame = nil

function QM:Initialize()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("CHAT_MSG_SYSTEM")
    self.frame:SetScript("OnEvent", function(f, event, msg, ...)
        if event == "CHAT_MSG_SYSTEM" then
            QM:OnSystemMessage(msg)
        end
    end)

    self.timerFrame = CreateFrame("Frame")
end

function QM:AddToQueue(player)
    if not player or not player.name then return end
    
    -- Check if player is already in queue
    for i, p in ipairs(self.queue) do
        if string.lower(p.name) == string.lower(player.name) then
            return false, "Already in queue"
        end
    end

    local entry = {
        name = player.name,
        level = player.level or 0,
        class = player.class or "UNKNOWN",
        race = player.race or "",
        guild = player.guild or "",
        status = "QUEUED", -- QUEUED, WHISPERING, INVITING, INVITED, ACCEPTED, DECLINED, SKIPPED, FAILED
    }

    table.insert(self.queue, entry)

    if GInviter.GUI and GInviter.GUI.OnQueueUpdated then
        GInviter.GUI:OnQueueUpdated(self.queue)
    end

    return true, "Queued"
end

function QM:QueueBatch(playerList)
    local count = 0
    for _, p in ipairs(playerList) do
        if p.isEligible then
            local added = self:AddToQueue(p)
            if added then
                count = count + 1
            end
        end
    end
    return count
end

function QM:RemoveFromQueue(indexOrName)
    if type(indexOrName) == "number" then
        if self.queue[indexOrName] then
            table.remove(self.queue, indexOrName)
        end
    elseif type(indexOrName) == "string" then
        for i, p in ipairs(self.queue) do
            if string.lower(p.name) == string.lower(indexOrName) then
                table.remove(self.queue, i)
                break
            end
        end
    end

    if GInviter.GUI and GInviter.GUI.OnQueueUpdated then
        GInviter.GUI:OnQueueUpdated(self.queue)
    end
end

function QM:ClearQueue()
    self.queue = {}
    self.isRunning = false
    self.currentIndex = 1
    if self.timerFrame then
        self.timerFrame:SetScript("OnUpdate", nil)
    end

    if GInviter.GUI and GInviter.GUI.OnQueueUpdated then
        GInviter.GUI:OnQueueUpdated(self.queue)
    end
end

function QM:StartQueue()
    if #self.queue == 0 then return end
    self.isRunning = true
    self.currentIndex = 1
    self:ProcessNextQueueItem()
end

function QM:PauseQueue()
    self.isRunning = false
    if self.timerFrame then
        self.timerFrame:SetScript("OnUpdate", nil)
    end
end

function QM:ResumeQueue()
    if #self.queue == 0 then return end
    self.isRunning = true
    self:ProcessNextQueueItem()
end

function QM:GetNextEligibleEntry()
    for i = self.currentIndex, #self.queue do
        local entry = self.queue[i]
        if entry and entry.status == "QUEUED" then
            self.currentIndex = i
            return entry, i
        end
    end
    return nil, nil
end

function QM:ProcessNextQueueItem()
    if not self.isRunning then return end

    local entry, idx = self:GetNextEligibleEntry()
    if not entry then
        -- End of queue
        self.isRunning = false
        if GInviter.GUI and GInviter.GUI.OnQueueFinished then
            GInviter.GUI:OnQueueFinished()
        end
        return
    end

    local settings = GInviter.Database:GetSettings()

    -- Check if Fallback Mode is forced or active
    if settings.fallbackMode then
        if GInviter.GUI and GInviter.GUI.SetFallbackTarget then
            GInviter.GUI:SetFallbackTarget(entry.name)
        end
        return
    end

    if settings.autoWhisper then
        entry.status = "WHISPERING"
        if GInviter.GUI and GInviter.GUI.OnQueueUpdated then GInviter.GUI:OnQueueUpdated(self.queue) end

        GInviter.WhisperHandler:SendRecruitmentWhisper(
            entry.name,
            -- On Affirmative
            function(targetName, replyMsg)
                entry.status = "INVITING"
                QM:ExecuteDirectInvite(entry)
            end,
            -- On Negative
            function(targetName, replyMsg)
                entry.status = "DECLINED"
                GInviter.Database:RecordInvite(targetName, "DECLINED", entry.level, entry.class)
                GInviter.Database:IncrementStat("declined")
                QM:ScheduleNextItem()
            end,
            -- On Timeout
            function(targetName)
                local action = settings.whisperTimeoutAction or "skip"
                if action == "invite" then
                    entry.status = "INVITING"
                    QM:ExecuteDirectInvite(entry)
                else
                    entry.status = "SKIPPED"
                    QM:ScheduleNextItem()
                end
            end
        )
    else
        entry.status = "INVITING"
        self:ExecuteDirectInvite(entry)
    end
end

function QM:ExecuteDirectInvite(entry)
    if not entry then return end
    
    local success, err = pcall(function()
        GuildInvite(entry.name)
    end)

    if not success then
        -- Server blocked automated API call -> trigger Fallback Mode seamlessly
        entry.status = "QUEUED"
        GInviter.Database:GetSettings().fallbackMode = true
        if GInviter.GUI and GInviter.GUI.SetFallbackTarget then
            GInviter.GUI:SetFallbackTarget(entry.name)
        end
        return
    end

    entry.status = "INVITED"
    GInviter.Database:RecordInvite(entry.name, "INVITED", entry.level, entry.class)
    GInviter.Database:IncrementStat("invited")
    GInviter.Database:IncrementStat("pending")

    if GInviter.GUI and GInviter.GUI.OnQueueUpdated then
        GInviter.GUI:OnQueueUpdated(self.queue)
    end

    self:ScheduleNextItem()
end

function QM:ScheduleNextItem()
    if not self.isRunning then return end

    local interval = GInviter.Database:GetSettings().inviteInterval or 3
    local elapsed = 0

    self.timerFrame:SetScript("OnUpdate", function(f, el)
        elapsed = elapsed + el
        if elapsed >= interval then
            f:SetScript("OnUpdate", nil)
            QM.currentIndex = QM.currentIndex + 1
            QM:ProcessNextQueueItem()
        end
    end)
end

function QM:OnSystemMessage(msg)
    if not msg then return end

    -- "X has joined the guild."
    local joinedPlayer = string.match(msg, "^(.-) has joined the guild%.")
    if joinedPlayer then
        GInviter.Database:UpdateInviteResult(joinedPlayer, "ACCEPTED")
        GInviter.Database:IncrementStat("accepted")
        self:UpdateQueueStatusByName(joinedPlayer, "ACCEPTED")
        return
    end

    -- "X declines your guild invitation."
    local declinedPlayer = string.match(msg, "^(.-) declines your guild invitation%.")
    if declinedPlayer then
        GInviter.Database:UpdateInviteResult(declinedPlayer, "DECLINED")
        GInviter.Database:IncrementStat("declined")
        self:UpdateQueueStatusByName(declinedPlayer, "DECLINED")
        return
    end

    -- "X is already in a guild."
    local guildedPlayer = string.match(msg, "^(.-) is already in a guild%.")
    if guildedPlayer then
        GInviter.Database:UpdateInviteResult(guildedPlayer, "GUILDED")
        GInviter.Database:IncrementStat("alreadyGuilded")
        self:UpdateQueueStatusByName(guildedPlayer, "GUILDED")
        return
    end
end

function QM:UpdateQueueStatusByName(playerName, status)
    for i, p in ipairs(self.queue) do
        if string.lower(p.name) == string.lower(playerName) then
            p.status = status
            break
        end
    end

    if GInviter.GUI and GInviter.GUI.OnQueueUpdated then
        GInviter.GUI:OnQueueUpdated(self.queue)
    end
end
