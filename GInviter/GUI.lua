-- GInviter GUI.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.GUI = {}
local GUI = GInviter.GUI

GUI.activeTab = 1
GUI.scannedPlayers = {}
GUI.queueList = {}

local backdropStyle = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

function GUI:Initialize()
    if self.mainFrame then return end

    -- Main Window Container
    local f = CreateFrame("Frame", "GInviterMainFrame", UIParent)
    f:SetSize(620, 440)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetBackdrop(backdropStyle)
    f:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
    f:SetBackdropBorderColor(0.2, 0.22, 0.28, 1.0)
    f:Hide()

    self.mainFrame = f

    -- Dedicated Title Bar (Drag Handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetSize(620, 32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetMovable(true)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    titleText:SetText("|cff3399ffGInviter|r  |cff888888Recruiter Dashboard|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Create Navigation Tabs
    self:CreateTabButtons()

    -- Create Tab Content Panels
    self:CreateDashboardPanel()
    self:CreateQueuePanel()
    self:CreateFiltersPanel()
    self:CreateStatsPanel()

    -- Create Fallback Mode Secure Action Button
    self:CreateFallbackHUD()

    -- Select Default Tab
    self:SelectTab(1)
end

function GUI:CreateTabButtons()
    local f = self.mainFrame
    local tabNames = { "Dashboard", "Smart Queue", "Smart Filters", "Stats & History" }
    self.tabButtons = {}

    for i, name in ipairs(tabNames) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(125, 26)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + (i - 1) * 130, -32)
        btn:SetBackdrop(backdropStyle)
        btn:SetBackdropColor(0.12, 0.14, 0.18, 1.0)
        btn:SetBackdropBorderColor(0.25, 0.28, 0.35, 1.0)

        local font = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        font:SetPoint("CENTER", btn, "CENTER", 0, 0)
        font:SetText(name)
        btn.font = font

        btn:SetScript("OnClick", function()
            GUI:SelectTab(i)
        end)

        self.tabButtons[i] = btn
    end
end

function GUI:SelectTab(tabIndex)
    self.activeTab = tabIndex
    for i, btn in ipairs(self.tabButtons) do
        if i == tabIndex then
            btn:SetBackdropColor(0.2, 0.4, 0.8, 1.0)
            btn:SetBackdropBorderColor(0.4, 0.6, 1.0, 1.0)
            btn.font:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropColor(0.12, 0.14, 0.18, 1.0)
            btn:SetBackdropBorderColor(0.25, 0.28, 0.35, 1.0)
            btn.font:SetTextColor(0.7, 0.7, 0.7, 1)
        end
    end

    if self.dashboardPanel then self.dashboardPanel:Hide() end
    if self.queuePanel then self.queuePanel:Hide() end
    if self.filtersPanel then self.filtersPanel:Hide() end
    if self.statsPanel then self.statsPanel:Hide() end

    if tabIndex == 1 and self.dashboardPanel then self.dashboardPanel:Show() end
    if tabIndex == 2 and self.queuePanel then self.queuePanel:Show() end
    if tabIndex == 3 and self.filtersPanel then self.filtersPanel:Show() end
    if tabIndex == 4 and self.statsPanel then
        self.statsPanel:Show()
        self:RefreshStatsDisplay()
    end
end

-- Tab 1: Dashboard Panel
function GUI:CreateDashboardPanel()
    local p = CreateFrame("Frame", nil, self.mainFrame)
    p:SetSize(596, 365)
    p:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 12, -63)
    self.dashboardPanel = p

    -- Summary Cards Panel
    local summaryBox = CreateFrame("Frame", nil, p)
    summaryBox:SetSize(596, 40)
    summaryBox:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    summaryBox:SetBackdrop(backdropStyle)
    summaryBox:SetBackdropColor(0.12, 0.14, 0.18, 0.8)
    summaryBox:SetBackdropBorderColor(0.2, 0.22, 0.28, 1.0)

    local summaryText = summaryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summaryText:SetPoint("LEFT", summaryBox, "LEFT", 12, 0)
    summaryText:SetText("Results: |cffffffff0|r   Unguilded: |cff33ff330|r   Already Invited: |cffffcc000|r   Ignored: |cff8888880|r   Eligible: |cff00ccff0|r")
    self.summaryText = summaryText

    -- Recruit Everyone Button
    local recruitAllBtn = CreateFrame("Button", nil, p)
    recruitAllBtn:SetSize(160, 28)
    recruitAllBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -45)
    recruitAllBtn:SetBackdrop(backdropStyle)
    recruitAllBtn:SetBackdropColor(0.1, 0.6, 0.3, 1.0)
    recruitAllBtn:SetBackdropBorderColor(0.2, 0.8, 0.4, 1.0)

    local rFont = recruitAllBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rFont:SetPoint("CENTER", recruitAllBtn, "CENTER", 0, 0)
    rFont:SetText("[ Recruit Everyone ]")

    recruitAllBtn:SetScript("OnClick", function()
        local count = GInviter.QueueManager:QueueBatch(GUI.scannedPlayers)
        DEFAULT_CHAT_FRAME:AddMessage("|cff3399ff[GInviter]|r Queued " .. count .. " eligible players.")
        GInviter.QueueManager:StartQueue()
        GUI:SelectTab(2) -- Switch to Queue tab
    end)

    -- Refresh Scan Button
    local refreshBtn = CreateFrame("Button", nil, p)
    refreshBtn:SetSize(130, 28)
    refreshBtn:SetPoint("TOPRIGHT", recruitAllBtn, "TOPLEFT", -10, 0)
    refreshBtn:SetBackdrop(backdropStyle)
    refreshBtn:SetBackdropColor(0.2, 0.4, 0.8, 1.0)
    refreshBtn:SetBackdropBorderColor(0.3, 0.5, 0.9, 1.0)

    local refFont = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    refFont:SetPoint("CENTER", refreshBtn, "CENTER", 0, 0)
    refFont:SetText("Run /who Scan")

    refreshBtn:SetScript("OnClick", function()
        GInviter.WhoScanner:StartAutoScan()
    end)

    -- Scanned Player List ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterDashboardScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(565, 280)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -80)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(565, 280)
    scrollFrame:SetScrollChild(content)
    self.dashboardContent = content
    self.dashboardRows = {}
end

function GUI:OnWhoScanCompleted(results, summary)
    self.scannedPlayers = results or {}
    if self.summaryText then
        self.summaryText:SetText("Results: |cffffffff" .. (summary.total or 0) .. 
            "|r   Unguilded: |cff33ff33" .. (summary.unguilded or 0) .. 
            "|r   Invited: |cffffcc00" .. (summary.alreadyInvited or 0) .. 
            "|r   Ignored: |cff888888" .. (summary.ignored or 0) .. 
            "|r   Eligible: |cff00ccff" .. (summary.eligible or 0) .. "|r")
    end

    -- Render Rows
    for _, row in ipairs(self.dashboardRows) do row:Hide() end

    local rowHeight = 26
    self.dashboardContent:SetHeight(math.max(#results * rowHeight, 280))

    for i, p in ipairs(results) do
        local row = self.dashboardRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.dashboardContent)
            row:SetSize(565, 24)
            row:SetBackdrop(backdropStyle)
            
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.nameText = nameText

            local infoText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            infoText:SetPoint("LEFT", row, "LEFT", 160, 0)
            row.infoText = infoText

            local actionBtn = CreateFrame("Button", nil, row)
            actionBtn:SetSize(80, 20)
            actionBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            actionBtn:SetBackdrop(backdropStyle)
            
            local actFont = actionBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            actFont:SetPoint("CENTER", actionBtn, "CENTER", 0, 0)
            actionBtn.actFont = actFont
            row.actionBtn = actionBtn

            self.dashboardRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.dashboardContent, "TOPLEFT", 0, -(i - 1) * 26)
        row:SetBackdropColor(i % 2 == 0 and 0.1 or 0.14, i % 2 == 0 and 0.11 or 0.16, i % 2 == 0 and 0.15 or 0.2, 0.8)
        row:SetBackdropBorderColor(0.2, 0.22, 0.28, 0.5)

        row.nameText:SetText(p.name or "Unknown")
        row.infoText:SetText("Lv" .. (p.level or 0) .. " " .. (p.class or "") .. (p.guild and p.guild ~= "" and (" <" .. p.guild .. ">") or ""))

        if p.isEligible then
            row.actionBtn:SetBackdropColor(0.1, 0.5, 0.2, 1.0)
            row.actionBtn:SetBackdropBorderColor(0.2, 0.7, 0.3, 1.0)
            row.actionBtn.actFont:SetText("[ Invite ]")
            row.actionBtn:SetScript("OnClick", function()
                GInviter.QueueManager:AddToQueue(p)
                GInviter.QueueManager:StartQueue()
            end)
        else
            row.actionBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            row.actionBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
            row.actionBtn.actFont:SetText(p.reason or "Ineligible")
            row.actionBtn:SetScript("OnClick", nil)
        end

        -- Tooltip explaining ineligibility
        row:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name .. " (Lv" .. p.level .. " " .. p.class .. ")", 1, 1, 1)
            GameTooltip:AddLine("Status: " .. (p.isEligible and "|cff33ff33Eligible|r" or ("|cffff3333" .. p.reason .. "|r")), 1, 1, 1)
            if p.guild and p.guild ~= "" then GameTooltip:AddLine("Guild: " .. p.guild, 0.7, 0.7, 0.7) end
            if p.zone and p.zone ~= "" then GameTooltip:AddLine("Zone: " .. p.zone, 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Show()
    end
end

-- Tab 2: Smart Queue Panel
function GUI:CreateQueuePanel()
    local p = CreateFrame("Frame", nil, self.mainFrame)
    p:SetSize(596, 365)
    p:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 12, -63)
    p:Hide()
    self.queuePanel = p

    -- Queue Action Bar
    local startBtn = CreateFrame("Button", nil, p)
    startBtn:SetSize(110, 26)
    startBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    startBtn:SetBackdrop(backdropStyle)
    startBtn:SetBackdropColor(0.1, 0.6, 0.3, 1.0)
    startBtn:SetBackdropBorderColor(0.2, 0.8, 0.4, 1.0)

    local stFont = startBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stFont:SetPoint("CENTER", startBtn, "CENTER", 0, 0)
    stFont:SetText("Start / Resume")
    startBtn:SetScript("OnClick", function() GInviter.QueueManager:StartQueue() end)

    local pauseBtn = CreateFrame("Button", nil, p)
    pauseBtn:SetSize(90, 26)
    pauseBtn:SetPoint("LEFT", startBtn, "RIGHT", 10, 0)
    pauseBtn:SetBackdrop(backdropStyle)
    pauseBtn:SetBackdropColor(0.8, 0.5, 0.1, 1.0)
    pauseBtn:SetBackdropBorderColor(0.9, 0.6, 0.2, 1.0)

    local pFont = pauseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pFont:SetPoint("CENTER", pauseBtn, "CENTER", 0, 0)
    pFont:SetText("Pause")
    pauseBtn:SetScript("OnClick", function() GInviter.QueueManager:PauseQueue() end)

    local clearBtn = CreateFrame("Button", nil, p)
    clearBtn:SetSize(90, 26)
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 10, 0)
    clearBtn:SetBackdrop(backdropStyle)
    clearBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    clearBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cFont:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    cFont:SetText("Clear Queue")
    clearBtn:SetScript("OnClick", function() GInviter.QueueManager:ClearQueue() end)

    -- Auto Whisper Checkbox
    local whisperCheck = CreateFrame("CheckButton", "GInviterAutoWhisperCheck", p, "UICheckButtonTemplate")
    whisperCheck:SetPoint("LEFT", clearBtn, "RIGHT", 20, 0)
    _G[whisperCheck:GetName() .. "Text"]:SetText("Auto-Whisper")
    whisperCheck:SetChecked(GInviter.Database:GetSettings().autoWhisper)
    whisperCheck:SetScript("OnClick", function(s)
        GInviter.Database:GetSettings().autoWhisper = s:GetChecked()
    end)

    -- Queue List ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterQueueScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(565, 320)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -38)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(565, 320)
    scrollFrame:SetScrollChild(content)
    self.queueContent = content
    self.queueRows = {}
end

function GUI:OnQueueUpdated(queue)
    self.queueList = queue or {}
    if not self.queueContent then return end

    for _, row in ipairs(self.queueRows) do row:Hide() end

    self.queueContent:SetHeight(math.max(#queue * 26, 320))

    for i, p in ipairs(queue) do
        local row = self.queueRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.queueContent)
            row:SetSize(565, 24)
            row:SetBackdrop(backdropStyle)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.nameText = nameText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            statusText:SetPoint("LEFT", row, "LEFT", 220, 0)
            row.statusText = statusText

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(60, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            removeBtn:SetBackdrop(backdropStyle)
            removeBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
            removeBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1.0)

            local rmFont = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rmFont:SetPoint("CENTER", removeBtn, "CENTER", 0, 0)
            rmFont:SetText("Remove")
            row.removeBtn = removeBtn

            self.queueRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.queueContent, "TOPLEFT", 0, -(i - 1) * 26)
        row:SetBackdropColor(i % 2 == 0 and 0.1 or 0.14, i % 2 == 0 and 0.11 or 0.16, i % 2 == 0 and 0.15 or 0.2, 0.8)
        row:SetBackdropBorderColor(0.2, 0.22, 0.28, 0.5)

        row.nameText:SetText(p.name .. " (Lv" .. (p.level or 0) .. " " .. (p.class or "") .. ")")
        row.statusText:SetText(p.status or "QUEUED")
        row.removeBtn:SetScript("OnClick", function()
            GInviter.QueueManager:RemoveFromQueue(i)
        end)

        row:Show()
    end
end

-- Tab 3: Filters Panel
function GUI:CreateFiltersPanel()
    local p = CreateFrame("Frame", nil, self.mainFrame)
    p:SetSize(596, 365)
    p:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 12, -63)
    p:Hide()
    self.filtersPanel = p

    local filters = GInviter.Database:GetSettings().filters or GInviter.Config.Defaults.filters

    -- Filter Checkboxes
    local cbNoGuild = CreateFrame("CheckButton", "GInviterFilterNoGuild", p, "UICheckButtonTemplate")
    cbNoGuild:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    _G[cbNoGuild:GetName() .. "Text"]:SetText("No Guild Only")
    cbNoGuild:SetChecked(filters.noGuildOnly)
    cbNoGuild:SetScript("OnClick", function(s) filters.noGuildOnly = s:GetChecked() end)

    local cbFriends = CreateFrame("CheckButton", "GInviterFilterFriends", p, "UICheckButtonTemplate")
    cbFriends:SetPoint("TOPLEFT", cbNoGuild, "BOTTOMLEFT", 0, -5)
    _G[cbFriends:GetName() .. "Text"]:SetText("Exclude Friends")
    cbFriends:SetChecked(filters.excludeFriends)
    cbFriends:SetScript("OnClick", function(s) filters.excludeFriends = s:GetChecked() end)

    local cbIgnores = CreateFrame("CheckButton", "GInviterFilterIgnores", p, "UICheckButtonTemplate")
    cbIgnores:SetPoint("TOPLEFT", cbFriends, "BOTTOMLEFT", 0, -5)
    _G[cbIgnores:GetName() .. "Text"]:SetText("Exclude Ignore List")
    cbIgnores:SetChecked(filters.excludeIgnores)
    cbIgnores:SetScript("OnClick", function(s) filters.excludeIgnores = s:GetChecked() end)

    local cbRecentInv = CreateFrame("CheckButton", "GInviterFilterRecentInv", p, "UICheckButtonTemplate")
    cbRecentInv:SetPoint("TOPLEFT", cbIgnores, "BOTTOMLEFT", 0, -5)
    _G[cbRecentInv:GetName() .. "Text"]:SetText("Exclude Recent Invites")
    cbRecentInv:SetChecked(filters.excludeRecentInvites)
    cbRecentInv:SetScript("OnClick", function(s) filters.excludeRecentInvites = s:GetChecked() end)

    local cbBlacklist = CreateFrame("CheckButton", "GInviterFilterBlacklist", p, "UICheckButtonTemplate")
    cbBlacklist:SetPoint("TOPLEFT", cbRecentInv, "BOTTOMLEFT", 0, -5)
    _G[cbBlacklist:GetName() .. "Text"]:SetText("Exclude Blacklisted Players")
    cbBlacklist:SetChecked(filters.excludeBlacklisted)
    cbBlacklist:SetScript("OnClick", function(s) filters.excludeBlacklisted = s:GetChecked() end)

    -- Duplicate Protection Window Selector Text
    local dupLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dupLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 300, -15)
    dupLabel:SetText("Duplicate Protection Window:")

    local dupOptionBtn = CreateFrame("Button", nil, p)
    dupOptionBtn:SetSize(140, 24)
    dupOptionBtn:SetPoint("TOPLEFT", dupLabel, "BOTTOMLEFT", 0, -8)
    dupOptionBtn:SetBackdrop(backdropStyle)
    dupOptionBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
    dupOptionBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)

    local dupText = dupOptionBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dupText:SetPoint("CENTER", dupOptionBtn, "CENTER", 0, 0)
    dupText:SetText(GInviter.Database:GetSettings().dupWindow or "today")

    dupOptionBtn:SetScript("OnClick", function()
        local cur = GInviter.Database:GetSettings().dupWindow
        local nextVal = "10m"
        if cur == "10m" then nextVal = "1h"
        elseif cur == "1h" then nextVal = "today"
        elseif cur == "today" then nextVal = "custom"
        else nextVal = "10m" end
        GInviter.Database:GetSettings().dupWindow = nextVal
        dupText:SetText(nextVal)
    end)
end

-- Tab 4: Stats & History Panel
function GUI:CreateStatsPanel()
    local p = CreateFrame("Frame", nil, self.mainFrame)
    p:SetSize(596, 365)
    p:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 12, -63)
    p:Hide()
    self.statsPanel = p

    -- Stats Summary Header
    local statsHeader = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    statsHeader:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    statsHeader:SetText("Today's Recruitment Statistics")

    local statsText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", statsHeader, "BOTTOMLEFT", 0, -8)
    statsText:SetText("Invited: 0  |  Accepted: 0  |  Declined: 0  |  Guilded: 0  |  Ignored: 0")
    self.statsText = statsText
end

function GUI:RefreshStatsDisplay()
    if not self.statsText then return end
    local st = GInviter.Database:GetStats()
    self.statsText:SetText("Invited: |cffffffff" .. (st.invited or 0) ..
        "|r  |  Accepted: |cff33ff33" .. (st.accepted or 0) ..
        "|r  |  Declined: |cffff3333" .. (st.declined or 0) ..
        "|r  |  Guilded: |cffffcc00" .. (st.alreadyGuilded or 0) ..
        "|r  |  Ignored: |cff888888" .. (st.ignored or 0) .. "|r")
end

-- Fallback Mode Secure Action Button HUD
function GUI:CreateFallbackHUD()
    local hud = CreateFrame("Button", "GInviterFallbackButton", UIParent, "SecureActionButtonTemplate")
    hud:SetSize(220, 44)
    hud:SetPoint("TOP", UIParent, "TOP", 0, -120)
    hud:SetFrameStrata("FULLSCREEN_DIALOG")
    hud:SetBackdrop(backdropStyle)
    hud:SetBackdropColor(0.8, 0.2, 0.1, 0.95)
    hud:SetBackdropBorderColor(1.0, 0.4, 0.2, 1.0)
    hud:Hide()

    local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", hud, "TOP", 0, -6)
    title:SetText("[ Fallback Mode - Click to Invite ]")

    local targetText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("BOTTOM", hud, "BOTTOM", 0, 6)
    targetText:SetText("Next Target: None")
    hud.targetText = targetText

    self.fallbackHUD = hud
end

function GUI:SetFallbackTarget(targetName)
    if not self.fallbackHUD then return end
    if targetName then
        self.fallbackHUD:SetAttribute("type", "macro")
        self.fallbackHUD:SetAttribute("macrotext", "/ginvite " .. targetName)
        self.fallbackHUD.targetText:SetText("Next Target: |cffffffff" .. targetName .. "|r")
        self.fallbackHUD:Show()
    else
        self.fallbackHUD:Hide()
    end
end

function GUI:Toggle()
    if self.mainFrame then
        if self.mainFrame:IsShown() then
            self.mainFrame:Hide()
        else
            self.mainFrame:Show()
        end
    end
end
