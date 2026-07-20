-- GInviter WhoScanner.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.WhoScanner = {}
local WS = GInviter.WhoScanner

WS.lastResults = {}
WS.summary = {
    total = 0,
    unguilded = 0,
    alreadyInvited = 0,
    ignored = 0,
    eligible = 0
}
WS.isScanning = false
WS.currentLevelSlice = 1

local levelBrackets = {
    {1, 10}, {11, 20}, {21, 30}, {31, 40},
    {41, 50}, {51, 60}, {61, 70}, {71, 80}
}

function WS:Initialize()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("WHO_LIST_UPDATE")
    self.frame:SetScript("OnEvent", function(f, event, ...)
        if event == "WHO_LIST_UPDATE" then
            WS:OnWhoListUpdate()
        end
    end)
end

function WS:SendQuery(whoString)
    whoString = whoString or ""
    if SetWhoToExtra then
        pcall(SetWhoToExtra, 1)
    end
    SendWho(whoString)
end

function WS:StartAutoScan()
    self.isScanning = true
    self.currentLevelSlice = 1
    self:ExecuteSliceQuery()
end

function WS:StopAutoScan()
    self.isScanning = false
end

function WS:ExecuteSliceQuery()
    if not self.isScanning then return end

    local bracket = levelBrackets[self.currentLevelSlice]
    if not bracket then
        self.currentLevelSlice = 1
        bracket = levelBrackets[1]
    end

    local query = bracket[1] .. "-" .. bracket[2]
    self:SendQuery(query)
end

function WS:OnWhoListUpdate()
    GInviter.FilterEngine:RefreshSocialCaches()

    local numResults = GetNumWhoResults()
    self.lastResults = {}
    self.summary = {
        total = numResults,
        unguilded = 0,
        alreadyInvited = 0,
        ignored = 0,
        eligible = 0
    }

    for i = 1, numResults do
        local name, guild, level, race, class, zone, classFileName = GetWhoInfo(i)
        if name and name ~= "" then
            local p = {
                name = name,
                guild = guild or "",
                level = tonumber(level) or 0,
                race = race or "",
                class = class or "",
                zone = zone or "",
                classFileName = classFileName or ""
            }

            local isEligible, reason = GInviter.FilterEngine:EvaluatePlayer(p)
            p.isEligible = isEligible
            p.reason = reason

            -- Update Summary Counts
            if not p.guild or p.guild == "" then
                self.summary.unguilded = self.summary.unguilded + 1
            end

            if reason == "Already Invited Recently" then
                self.summary.alreadyInvited = self.summary.alreadyInvited + 1
            elseif reason == "Ignored" or reason == "Blacklisted" then
                self.summary.ignored = self.summary.ignored + 1
            end

            if isEligible then
                self.summary.eligible = self.summary.eligible + 1
            end

            table.insert(self.lastResults, p)
        end
    end

    -- Trigger GUI update if UI is registered
    if GInviter.GUI and GInviter.GUI.OnWhoScanCompleted then
        GInviter.GUI:OnWhoScanCompleted(self.lastResults, self.summary)
    end

    -- Advance level slice if auto-scanning
    if self.isScanning then
        self.currentLevelSlice = self.currentLevelSlice + 1
        if self.currentLevelSlice > #levelBrackets then
            self.currentLevelSlice = 1
        end

        local delay = GInviter.Database:GetSettings().whoScanDelay or 5
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(delay, function()
                if WS.isScanning then
                    WS:ExecuteSliceQuery()
                end
            end)
        else
            -- Fallback delay timer using frame OnUpdate
            local elapsed = 0
            local timerFrame = CreateFrame("Frame")
            timerFrame:SetScript("OnUpdate", function(f, el)
                elapsed = elapsed + el
                if elapsed >= delay then
                    timerFrame:SetScript("OnUpdate", nil)
                    if WS.isScanning then
                        WS:ExecuteSliceQuery()
                    end
                end
            end)
        end
    end
end
