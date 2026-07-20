-- GInviter GUI.lua - Geist Obsidian Dark Dual-Pane Redesign
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.GUI = {}
local GUI = GInviter.GUI

GUI.activeTab = 1
GUI.scannedPlayers = {}
GUI.queueList = {}

-- Standard WoW 3.3.5 Class Colors (RGB Hex)
local CLASS_COLORS = {
    ["WARRIOR"]     = "|cffC79C6E",
    ["PALADIN"]     = "|cffF58CBA",
    ["HUNTER"]      = "|cffABD473",
    ["ROGUE"]       = "|cffFFF569",
    ["PRIEST"]     = "|cffFFFFFF",
    ["DEATHKNIGHT"] = "|cffC41F3B",
    ["SHAMAN"]      = "|cff0070DE",
    ["MAGE"]        = "|cff69CCF0",
    ["WARLOCK"]     = "|cff9482C9",
    ["DRUID"]       = "|cffFF7D0A",
}

local function GetClassColorStr(classFileName)
    if not classFileName then return "|cffffffff" end
    local clean = string.upper(string.gsub(classFileName, "%s+", ""))
    return CLASS_COLORS[clean] or "|cffffffff"
end

local backdropObsidian = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

function GUI:Initialize()
    if self.mainFrame then return end

    -- Main Window Container (Dual-Pane layout: 700x500)
    local f = CreateFrame("Frame", "GInviterMainFrame", UIParent)
    f:SetSize(700, 500)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetBackdrop(backdropObsidian)
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.98) -- #0c0d12 Obsidian
    f:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0) -- Hairline #252a38
    f:Hide()

    self.mainFrame = f

    -- Header & Title Bar (Dedicated Drag Handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetSize(700, 36)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetMovable(true)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 16, 0)
    titleText:SetText("|cff00a2ffGInviter|r  |cff8f8f8fGuild Recruitment Engine|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        GUI:UpdateFloatingHUDState()
    end)

    -- Left Sidebar (Quick Filters & Stats)
    self:CreateSidebar(f)

    -- Right Main Viewport (Tabbed Navigation)
    self:CreateMainViewport(f)

    -- Fallback HUD (Integrated Footer + Floating Pill)
    self:CreateFallbackHUD()

    -- Select Default Tab
    self:SelectTab(1)
end

-- Left Sidebar Component
function GUI:CreateSidebar(parent)
    local sb = CreateFrame("Frame", nil, parent)
    sb:SetSize(190, 452)
    sb:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -40)
    sb:SetBackdrop(backdropObsidian)
    sb:SetBackdropColor(0.08, 0.09, 0.12, 0.9) -- #161922 Card container
    sb:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

    -- Section 1: Quick Stats Cards
    local statHeader = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statHeader:SetPoint("TOPLEFT", sb, "TOPLEFT", 12, -10)
    statHeader:SetText("|cff00a2ffLIVE SCAN STATS|r")

    local statBox = CreateFrame("Frame", nil, sb)
    statBox:SetSize(166, 70)
    statBox:SetPoint("TOPLEFT", statHeader, "BOTTOMLEFT", 0, -6)
    statBox:SetBackdrop(backdropObsidian)
    statBox:SetBackdropColor(0.05, 0.05, 0.07, 0.8)
    statBox:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

    local sideStatText = statBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sideStatText:SetPoint("TOPLEFT", statBox, "TOPLEFT", 8, -8)
    sideStatText:SetText("Scanned: |cffffffff0|r\nUnguilded: |cff00e6760|r\nEligible: |cff00a2ff0|r\nInvited: |cffffcc000|r")
    self.sideStatText = sideStatText

    -- Section 2: Quick Filter Controls
    local filterHeader = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterHeader:SetPoint("TOPLEFT", statBox, "BOTTOMLEFT", 0, -14)
    filterHeader:SetText("|cff00a2ffSMART FILTERS|r")

    local filters = GInviter.Database:GetSettings().filters or GInviter.Config.Defaults.filters

    local cbNoGuild = CreateFrame("CheckButton", "GInviterSBNoGuild", sb, "UICheckButtonTemplate")
    cbNoGuild:SetPoint("TOPLEFT", filterHeader, "BOTTOMLEFT", -4, -4)
    _G[cbNoGuild:GetName() .. "Text"]:SetText("No Guild Only")
    _G[cbNoGuild:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbNoGuild:SetChecked(filters.noGuildOnly)
    cbNoGuild:SetScript("OnClick", function(s) filters.noGuildOnly = s:GetChecked() end)

    local cbFriends = CreateFrame("CheckButton", "GInviterSBFriends", sb, "UICheckButtonTemplate")
    cbFriends:SetPoint("TOPLEFT", cbNoGuild, "BOTTOMLEFT", 0, 2)
    _G[cbFriends:GetName() .. "Text"]:SetText("Exclude Friends")
    _G[cbFriends:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbFriends:SetChecked(filters.excludeFriends)
    cbFriends:SetScript("OnClick", function(s) filters.excludeFriends = s:GetChecked() end)

    local cbIgnores = CreateFrame("CheckButton", "GInviterSBIgnores", sb, "UICheckButtonTemplate")
    cbIgnores:SetPoint("TOPLEFT", cbFriends, "BOTTOMLEFT", 0, 2)
    _G[cbIgnores:GetName() .. "Text"]:SetText("Exclude Ignores")
    _G[cbIgnores:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbIgnores:SetChecked(filters.excludeIgnores)
    cbIgnores:SetScript("OnClick", function(s) filters.excludeIgnores = s:GetChecked() end)

    local cbRecentInv = CreateFrame("CheckButton", "GInviterSBRecentInv", sb, "UICheckButtonTemplate")
    cbRecentInv:SetPoint("TOPLEFT", cbIgnores, "BOTTOMLEFT", 0, 2)
    _G[cbRecentInv:GetName() .. "Text"]:SetText("Exclude Recent")
    _G[cbRecentInv:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbRecentInv:SetChecked(filters.excludeRecentInvites)
    cbRecentInv:SetScript("OnClick", function(s) filters.excludeRecentInvites = s:GetChecked() end)

    local cbBlacklist = CreateFrame("CheckButton", "GInviterSBBlacklist", sb, "UICheckButtonTemplate")
    cbBlacklist:SetPoint("TOPLEFT", cbRecentInv, "BOTTOMLEFT", 0, 2)
    _G[cbBlacklist:GetName() .. "Text"]:SetText("Exclude Blacklist")
    _G[cbBlacklist:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbBlacklist:SetChecked(filters.excludeBlacklisted)
    cbBlacklist:SetScript("OnClick", function(s) filters.excludeBlacklisted = s:GetChecked() end)

    -- Section 3: Duplicate Window Selector
    local dupHeader = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dupHeader:SetPoint("TOPLEFT", cbBlacklist, "BOTTOMLEFT", 4, -12)
    dupHeader:SetText("|cff00a2ffDUPLICATE WINDOW|r")

    local dupBtn = CreateFrame("Button", nil, sb)
    dupBtn:SetSize(166, 24)
    dupBtn:SetPoint("TOPLEFT", dupHeader, "BOTTOMLEFT", 0, -6)
    dupBtn:SetBackdrop(backdropObsidian)
    dupBtn:SetBackdropColor(0.12, 0.14, 0.18, 1.0)
    dupBtn:SetBackdropBorderColor(0.2, 0.22, 0.28, 1.0)

    local dupText = dupBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dupText:SetPoint("CENTER", dupBtn, "CENTER", 0, 0)
    dupText:SetText("Window: |cffffcc00" .. (GInviter.Database:GetSettings().dupWindow or "today") .. "|r")

    dupBtn:SetScript("OnClick", function()
        local cur = GInviter.Database:GetSettings().dupWindow
        local nextVal = "10m"
        if cur == "10m" then nextVal = "1h"
        elseif cur == "1h" then nextVal = "today"
        elseif cur == "today" then nextVal = "custom"
        else nextVal = "10m" end
        GInviter.Database:GetSettings().dupWindow = nextVal
        dupText:SetText("Window: |cffffcc00" .. nextVal .. "|r")
    end)
end

-- Right Main Viewport Component
function GUI:CreateMainViewport(parent)
    local vp = CreateFrame("Frame", nil, parent)
    vp:SetSize(488, 452)
    vp:SetPoint("TOPLEFT", parent, "TOPLEFT", 204, -40)
    self.mainViewport = vp

    -- Tab Bar
    local tabNames = { "Candidate Pool", "Active Queue", "Stats & History" }
    self.tabButtons = {}

    for i, name in ipairs(tabNames) do
        local btn = CreateFrame("Button", nil, vp)
        btn:SetSize(155, 28)
        btn:SetPoint("TOPLEFT", vp, "TOPLEFT", (i - 1) * 160, 0)
        btn:SetBackdrop(backdropObsidian)
        btn:SetBackdropColor(0.08, 0.09, 0.12, 0.9)
        btn:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

        local font = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        font:SetPoint("CENTER", btn, "CENTER", 0, 0)
        font:SetText(name)
        btn.font = font

        btn:SetScript("OnClick", function() GUI:SelectTab(i) end)
        self.tabButtons[i] = btn
    end

    -- Tab Panels
    self:CreateCandidatePanel(vp)
    self:CreateQueuePanel(vp)
    self:CreateStatsPanel(vp)
end

function GUI:SelectTab(tabIndex)
    self.activeTab = tabIndex
    for i, btn in ipairs(self.tabButtons) do
        if i == tabIndex then
            btn:SetBackdropColor(0.0, 0.5, 0.9, 1.0) -- Electric Azure Accent
            btn:SetBackdropBorderColor(0.2, 0.7, 1.0, 1.0)
            btn.font:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropColor(0.08, 0.09, 0.12, 0.9)
            btn:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
            btn.font:SetTextColor(0.6, 0.6, 0.6, 1)
        end
    end

    if self.candidatePanel then self.candidatePanel:Hide() end
    if self.queuePanel then self.queuePanel:Hide() end
    if self.statsPanel then self.statsPanel:Hide() end

    if tabIndex == 1 and self.candidatePanel then self.candidatePanel:Show() end
    if tabIndex == 2 and self.queuePanel then self.queuePanel:Show() end
    if tabIndex == 3 and self.statsPanel then
        self.statsPanel:Show()
        self:RefreshStatsDisplay()
    end
end

-- Tab 1: Candidate Pool Panel
function GUI:CreateCandidatePanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(488, 416)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -36)
    self.candidatePanel = p

    -- Action Header
    local scanBtn = CreateFrame("Button", nil, p)
    scanBtn:SetSize(140, 26)
    scanBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    scanBtn:SetBackdrop(backdropObsidian)
    scanBtn:SetBackdropColor(0.1, 0.4, 0.8, 1.0)
    scanBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 1.0)

    local sFont = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sFont:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    sFont:SetText("Run /who Scan")
    scanBtn:SetScript("OnClick", function() GInviter.WhoScanner:StartAutoScan() end)

    local recruitAllBtn = CreateFrame("Button", nil, p)
    recruitAllBtn:SetSize(160, 26)
    recruitAllBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    recruitAllBtn:SetBackdrop(backdropObsidian)
    recruitAllBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    recruitAllBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local rFont = recruitAllBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rFont:SetPoint("CENTER", recruitAllBtn, "CENTER", 0, 0)
    rFont:SetText("[ Recruit Everyone ]")
    recruitAllBtn:SetScript("OnClick", function()
        local count = GInviter.QueueManager:QueueBatch(GUI.scannedPlayers)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00a2ff[GInviter]|r Queued " .. count .. " eligible players.")
        GInviter.QueueManager:StartQueue()
        GUI:SelectTab(2)
    end)

    -- Data Table Header
    local tableHeader = CreateFrame("Frame", nil, p)
    tableHeader:SetSize(488, 22)
    tableHeader:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -34)
    tableHeader:SetBackdrop(backdropObsidian)
    tableHeader:SetBackdropColor(0.1, 0.12, 0.16, 1.0)
    tableHeader:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    local th1 = tableHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th1:SetPoint("LEFT", tableHeader, "LEFT", 8, 0)
    th1:SetText("|cff8f8f8fPLAYER|r")

    local th2 = tableHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th2:SetPoint("LEFT", tableHeader, "LEFT", 140, 0)
    th2:SetText("|cff8f8f8fCLASS / LV|r")

    local th3 = tableHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th3:SetPoint("LEFT", tableHeader, "LEFT", 250, 0)
    th3:SetText("|cff8f8f8fSTATUS|r")

    local th4 = tableHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th4:SetPoint("RIGHT", tableHeader, "RIGHT", -20, 0)
    th4:SetText("|cff8f8f8fACTION|r")

    -- Scroll Area
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterCandidateScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(465, 350)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -60)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(465, 350)
    scrollFrame:SetScrollChild(content)
    self.candidateContent = content
    self.candidateRows = {}
end

function GUI:OnWhoScanCompleted(results, summary)
    self.scannedPlayers = results or {}
    if self.sideStatText then
        self.sideStatText:SetText("Scanned: |cffffffff" .. (summary.total or 0) ..
            "|r\nUnguilded: |cff00e676" .. (summary.unguilded or 0) ..
            "|r\nEligible: |cff00a2ff" .. (summary.eligible or 0) ..
            "|r\nInvited: |cffffcc00" .. (summary.alreadyInvited or 0) .. "|r")
    end

    for _, row in ipairs(self.candidateRows) do row:Hide() end

    local rowHeight = 26
    self.candidateContent:SetHeight(math.max(#results * rowHeight, 350))

    for i, p in ipairs(results) do
        local row = self.candidateRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.candidateContent)
            row:SetSize(465, 24)
            row:SetBackdrop(backdropObsidian)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.nameText = nameText

            local classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            classText:SetPoint("LEFT", row, "LEFT", 140, 0)
            row.classText = classText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("LEFT", row, "LEFT", 250, 0)
            row.statusText = statusText

            local actBtn = CreateFrame("Button", nil, row)
            actBtn:SetSize(75, 20)
            actBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            actBtn:SetBackdrop(backdropObsidian)

            local actFont = actBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            actFont:SetPoint("CENTER", actBtn, "CENTER", 0, 0)
            actBtn.actFont = actFont
            row.actBtn = actBtn

            self.candidateRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.candidateContent, "TOPLEFT", 0, -(i - 1) * 26)
        row:SetBackdropColor(i % 2 == 0 and 0.06 or 0.09, i % 2 == 0 and 0.07 or 0.1, i % 2 == 0 and 0.09 or 0.13, 0.9)
        row:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)

        local colorStr = GetClassColorStr(p.classFileName)
        row.nameText:SetText(colorStr .. p.name .. "|r")
        row.classText:SetText("Lv" .. p.level .. " " .. p.class)

        if p.isEligible then
            row.statusText:SetText("|cff00e676[ Eligible ]|r")
            row.actBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            row.actBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            row.actBtn.actFont:SetText("[ + Queue ]")
            row.actBtn:SetScript("OnClick", function()
                GInviter.QueueManager:AddToQueue(p)
                GInviter.QueueManager:StartQueue()
            end)
        else
            row.statusText:SetText("|cffff3355[" .. (p.reason or "Ineligible") .. "]|r")
            row.actBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.8)
            row.actBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)
            row.actBtn.actFont:SetText("Skip")
            row.actBtn:SetScript("OnClick", nil)
        end

        row:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name .. " (Lv" .. p.level .. " " .. p.class .. ")", 1, 1, 1)
            GameTooltip:AddLine("Status: " .. (p.isEligible and "|cff00e676Eligible|r" or ("|cffff3355" .. p.reason .. "|r")), 1, 1, 1)
            if p.guild and p.guild ~= "" then GameTooltip:AddLine("Guild: " .. p.guild, 0.7, 0.7, 0.7) end
            if p.zone and p.zone ~= "" then GameTooltip:AddLine("Zone: " .. p.zone, 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Show()
    end
end

-- Tab 2: Queue Panel
function GUI:CreateQueuePanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(488, 416)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -36)
    p:Hide()
    self.queuePanel = p

    -- Action Bar
    local startBtn = CreateFrame("Button", nil, p)
    startBtn:SetSize(100, 26)
    startBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    startBtn:SetBackdrop(backdropObsidian)
    startBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    startBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local stFont = startBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stFont:SetPoint("CENTER", startBtn, "CENTER", 0, 0)
    stFont:SetText("Start Queue")
    startBtn:SetScript("OnClick", function() GInviter.QueueManager:StartQueue() end)

    local pauseBtn = CreateFrame("Button", nil, p)
    pauseBtn:SetSize(80, 26)
    pauseBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
    pauseBtn:SetBackdrop(backdropObsidian)
    pauseBtn:SetBackdropColor(0.8, 0.5, 0.1, 1.0)
    pauseBtn:SetBackdropBorderColor(0.9, 0.6, 0.2, 1.0)

    local pFont = pauseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pFont:SetPoint("CENTER", pauseBtn, "CENTER", 0, 0)
    pFont:SetText("Pause")
    pauseBtn:SetScript("OnClick", function() GInviter.QueueManager:PauseQueue() end)

    local clearBtn = CreateFrame("Button", nil, p)
    clearBtn:SetSize(80, 26)
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 8, 0)
    clearBtn:SetBackdrop(backdropObsidian)
    clearBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    clearBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cFont:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    cFont:SetText("Clear")
    clearBtn:SetScript("OnClick", function() GInviter.QueueManager:ClearQueue() end)

    -- Auto Whisper Checkbox
    local whisperCheck = CreateFrame("CheckButton", "GInviterVPAutoWhisper", p, "UICheckButtonTemplate")
    whisperCheck:SetPoint("LEFT", clearBtn, "RIGHT", 14, 0)
    _G[whisperCheck:GetName() .. "Text"]:SetText("Auto-Whisper")
    _G[whisperCheck:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    whisperCheck:SetChecked(GInviter.Database:GetSettings().autoWhisper)
    whisperCheck:SetScript("OnClick", function(s)
        GInviter.Database:GetSettings().autoWhisper = s:GetChecked()
    end)

    -- Queue List ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterVPQueueScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(465, 375)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -36)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(465, 375)
    scrollFrame:SetScrollChild(content)
    self.queueContent = content
    self.queueRows = {}
end

function GUI:OnQueueUpdated(queue)
    self.queueList = queue or {}
    if not self.queueContent then return end

    for _, row in ipairs(self.queueRows) do row:Hide() end
    self.queueContent:SetHeight(math.max(#queue * 26, 375))

    for i, p in ipairs(queue) do
        local row = self.queueRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.queueContent)
            row:SetSize(465, 24)
            row:SetBackdrop(backdropObsidian)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.nameText = nameText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("LEFT", row, "LEFT", 200, 0)
            row.statusText = statusText

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(60, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            removeBtn:SetBackdrop(backdropObsidian)
            removeBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
            removeBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1.0)

            local rmFont = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rmFont:SetPoint("CENTER", removeBtn, "CENTER", 0, 0)
            rmFont:SetText("Remove")
            row.removeBtn = removeBtn

            self.queueRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.queueContent, "TOPLEFT", 0, -(i - 1) * 26)
        row:SetBackdropColor(i % 2 == 0 and 0.06 or 0.09, i % 2 == 0 and 0.07 or 0.1, i % 2 == 0 and 0.09 or 0.13, 0.9)
        row:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)

        row.nameText:SetText(p.name .. " (Lv" .. (p.level or 0) .. ")")
        row.statusText:SetText("|cff00a2ff" .. (p.status or "QUEUED") .. "|r")
        row.removeBtn:SetScript("OnClick", function() GInviter.QueueManager:RemoveFromQueue(i) end)

        row:Show()
    end
end

-- Tab 3: Stats Panel
function GUI:CreateStatsPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(488, 416)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -36)
    p:Hide()
    self.statsPanel = p

    local statsHeader = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    statsHeader:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -10)
    statsHeader:SetText("|cff00a2ffToday's Recruitment Overview|r")

    local statsText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", statsHeader, "BOTTOMLEFT", 0, -10)
    statsText:SetText("Invited: 0  |  Accepted: 0  |  Declined: 0  |  Guilded: 0")
    self.statsText = statsText
end

function GUI:RefreshStatsDisplay()
    if not self.statsText then return end
    local st = GInviter.Database:GetStats()
    self.statsText:SetText("Invited: |cffffffff" .. (st.invited or 0) ..
        "|r   Accepted: |cff00e676" .. (st.accepted or 0) ..
        "|r   Declined: |cffff3355" .. (st.declined or 0) ..
        "|r   Guilded: |cffffcc00" .. (st.alreadyGuilded or 0) .. "|r")
end

-- Dual-View Fallback Mode HUD Component (Integrated Footer + Floating Pill)
function GUI:CreateFallbackHUD()
    -- 1. Integrated Footer Action Dock
    local dock = CreateFrame("Button", "GInviterFooterDockButton", self.mainFrame, "SecureActionButtonTemplate")
    dock:SetSize(684, 32)
    dock:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 8, 8)
    dock:SetBackdrop(backdropObsidian)
    dock:SetBackdropColor(0.8, 0.2, 0.1, 0.95)
    dock:SetBackdropBorderColor(1.0, 0.4, 0.2, 1.0)
    dock:Hide()

    local dockText = dock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dockText:SetPoint("CENTER", dock, "CENTER", 0, 0)
    dockText:SetText("[ Fallback Mode - Click to Invite: None ]")
    dock.dockText = dockText
    self.footerDock = dock

    -- 2. Independent Floating HUD Pill
    local pill = CreateFrame("Button", "GInviterFloatingPillButton", UIParent, "SecureActionButtonTemplate")
    pill:SetSize(240, 40)
    pill:SetPoint("TOP", UIParent, "TOP", 0, -100)
    pill:SetFrameStrata("FULLSCREEN_DIALOG")
    pill:SetBackdrop(backdropObsidian)
    pill:SetBackdropColor(0.8, 0.2, 0.1, 0.95)
    pill:SetBackdropBorderColor(1.0, 0.4, 0.2, 1.0)
    pill:EnableMouse(true)
    pill:RegisterForDrag("LeftButton")
    pill:SetScript("OnDragStart", function(s) s:StartMoving() end)
    pill:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    pill:SetMovable(true)
    pill:Hide()

    local pillText = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pillText:SetPoint("CENTER", pill, "CENTER", 0, 0)
    pillText:SetText("[ Next Invite: None ]")
    pill.pillText = pillText
    self.floatingPill = pill
end

function GUI:SetFallbackTarget(targetName)
    self.currentTarget = targetName
    if targetName then
        if self.footerDock then
            self.footerDock:SetAttribute("type", "macro")
            self.footerDock:SetAttribute("macrotext", "/ginvite " .. targetName)
            self.footerDock.dockText:SetText("|cffffffff[ FALLBACK MODE - CLICK TO INVITE: |cff00e676" .. targetName .. "|r ]|r")
            self.footerDock:Show()
        end

        if self.floatingPill then
            self.floatingPill:SetAttribute("type", "macro")
            self.floatingPill:SetAttribute("macrotext", "/ginvite " .. targetName)
            self.floatingPill.pillText:SetText("|cffffffff[ NEXT INVITE: |cff00e676" .. targetName .. "|r ]|r")
        end

        self:UpdateFloatingHUDState()
    else
        if self.footerDock then self.footerDock:Hide() end
        if self.floatingPill then self.floatingPill:Hide() end
    end
end

function GUI:UpdateFloatingHUDState()
    if not self.currentTarget then
        if self.floatingPill then self.floatingPill:Hide() end
        return
    end

    -- If main dashboard is hidden/minimized, show floating HUD pill
    if self.mainFrame and not self.mainFrame:IsShown() then
        if self.floatingPill then self.floatingPill:Show() end
    else
        if self.floatingPill then self.floatingPill:Hide() end
    end
end

function GUI:Toggle()
    if self.mainFrame then
        if self.mainFrame:IsShown() then
            self.mainFrame:Hide()
        else
            self.mainFrame:Show()
        end
        self:UpdateFloatingHUDState()
    end
end
