-- GInviter Core.lua
local addonName, addon = ...
GInviter = GInviter or {}

local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_LOGIN")

coreFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        GInviter.Database:Initialize()
    elseif event == "PLAYER_LOGIN" then
        GInviter.WhoScanner:Initialize()
        GInviter.WhisperHandler:Initialize()
        GInviter.QueueManager:Initialize()
        GInviter.SyncManager:Initialize()
        GInviter.MinimapButton:Initialize()
        GInviter.GUI:Initialize()

        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffGInviter|r v1.0.0 loaded! Type |cffffcc00/ginviter|r or |cffffcc00/ginvite|r to open recruiter dashboard.")
    end
end)

-- Slash Command Handler
SLASH_GINVITER1 = "/ginviter"
SLASH_GINVITER2 = "/ginvite"

SlashCmdList["GINVITER"] = function(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")

    if msg == "start" then
        GInviter.QueueManager:StartQueue()
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter]|r Recruitment queue started.")
    elseif msg == "stop" or msg == "pause" then
        GInviter.QueueManager:PauseQueue()
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter]|r Recruitment queue paused.")
    elseif msg == "clear" then
        GInviter.QueueManager:ClearQueue()
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter]|r Recruitment queue cleared.")
    elseif msg == "stats" then
        local st = GInviter.Database:GetStats()
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter Stats]|r Invited: " .. st.invited .. " | Accepted: " .. st.accepted .. " | Declined: " .. st.declined .. " | Guilded: " .. st.alreadyGuilded)
    elseif msg ~= "" then
        -- Direct single target invite command: /ginvite PlayerName
        GInviter.QueueManager:AddToQueue({ name = msg, level = 0, class = "UNKNOWN", isEligible = true })
        GInviter.QueueManager:StartQueue()
    else
        -- Toggle Dashboard UI
        GInviter.GUI:Toggle()
    end
end
