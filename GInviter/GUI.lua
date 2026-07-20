-- GInviter GUI.lua - Top/Bottom Split View Redesign
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.GUI = {}
local GUI = GInviter.GUI

GUI.scannedPlayers = {}
GUI.queueList = {}

-- Standard WoW 3.3.5 Class Colors (RGB Hex)
local CLASS_COLORS = {
    ["WARRIOR"]     = "|cffC79C6E",
    ["PALADIN"]     = "|cffF58CBA",
    ["HUNTER"]      = "|cffABD473",
    ["ROGUE"]       = "|cffFFF569",
    ["PRIEST"]      = "|cffFFFFFF",
    ["DEATHKNIGHT"] = "|cffC41F3B",
    ["SHAMAN"]      = "|cff0070DE",
    ["MAGE"]        = "|cff69CCF0",
    ["WARLOCK"]     = "|cff9482C9",
    ["DRUID"]       = "|cffFF7D0A",
}

local function GetClassColorStr(classFileName, className)
    local ref = (classFileName and classFileName ~= "") and classFileName or className
    if not ref then return "|cffffffff" end
    local clean = string.upper(string.gsub(ref, "%s+", ""))
    return CLASS_COLORS[clean] or "|cffffffff"
end

local function TruncateString(str, maxChars)
    if not str then return "" end
    if #str > maxChars then
        return string.sub(str, 1, maxChars - 3) .. "..."
    end
    return str
end

local backdropObsidian = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

function GUI:Initialize()
    if self.mainFrame then return end

    -- Main Window Container (Top/Bottom Split View: 720x540)
    local f = CreateFrame("Frame", "GInviterMainFrame", UIParent)
    f:SetSize(720, 540)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetBackdrop(backdropObsidian)
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.98) -- #0c0d12 Obsidian
    f:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0) -- Hairline #252a38
    f:Hide()

    self.mainFrame = f

    -- Title Bar (Dedicated Drag Handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetSize(720, 32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetMovable(true)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 14, 0)
    titleText:SetText("|cff00a2ffGInviter|r  |cff8f8f8fRecruitment Engine|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        GUI:UpdateFloatingHUDState()
    end)

    -- Top Filter & Action Bar
    self:CreateFilterBar(f)

    -- Top Pane: Candidate Pool Table (Height: 240px)
    self:CreateCandidatePane(f)

    -- Bottom Pane: Active Queue & Whisper Deck (Height: 185px)
    self:CreateQueuePane(f)

    -- Fallback Mode Action Dock & Floating Pill
    self:CreateFallbackHUD()
end

-- Top Filter & Action Toolbar
function GUI:CreateFilterBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(704, 38)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -32)
    bar:SetBackdrop(backdropObsidian)
    bar:SetBackdropColor(0.08, 0.09, 0.12, 0.9)
    bar:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

    -- Run Scan Button
    local scanBtn = CreateFrame("Button", nil, bar)
    scanBtn:SetSize(120, 24)
    scanBtn:SetPoint("LEFT", bar, "LEFT", 8, 0)
    scanBtn:SetBackdrop(backdropObsidian)
    scanBtn:SetBackdropColor(0.1, 0.4, 0.8, 1.0)
    scanBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 1.0)

    local sFont = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sFont:SetPoint("CENTER", scanBtn, "CENTER", 0, 0)
    sFont:SetText("Run /who Scan")
    scanBtn:SetScript("OnClick", function() GInviter.WhoScanner:StartAutoScan() end)

    -- Filters
    local filters = GInviter.Database:GetSettings().filters or GInviter.Config.Defaults.filters

    local cbNoGuild = CreateFrame("CheckButton", "GInviterFBarNoGuild", bar, "UICheckButtonTemplate")
    cbNoGuild:SetPoint("LEFT", scanBtn, "RIGHT", 10, 0)
    _G[cbNoGuild:GetName() .. "Text"]:SetText("No Guild")
    _G[cbNoGuild:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbNoGuild:SetChecked(filters.noGuildOnly)
    cbNoGuild:SetScript("OnClick", function(s) filters.noGuildOnly = s:GetChecked() end)

    local cbFriends = CreateFrame("CheckButton", "GInviterFBarFriends", bar, "UICheckButtonTemplate")
    cbFriends:SetPoint("LEFT", cbNoGuild, "RIGHT", 55, 0)
    _G[cbFriends:GetName() .. "Text"]:SetText("No Friends")
    _G[cbFriends:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbFriends:SetChecked(filters.excludeFriends)
    cbFriends:SetScript("OnClick", function(s) filters.excludeFriends = s:GetChecked() end)

    local cbIgnores = CreateFrame("CheckButton", "GInviterFBarIgnores", bar, "UICheckButtonTemplate")
    cbIgnores:SetPoint("LEFT", cbFriends, "RIGHT", 65, 0)
    _G[cbIgnores:GetName() .. "Text"]:SetText("No Ignores")
    _G[cbIgnores:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbIgnores:SetChecked(filters.excludeIgnores)
    cbIgnores:SetScript("OnClick", function(s) filters.excludeIgnores = s:GetChecked() end)

    local cbRecent = CreateFrame("CheckButton", "GInviterFBarRecent", bar, "UICheckButtonTemplate")
    cbRecent:SetPoint("LEFT", cbIgnores, "RIGHT", 65, 0)
    _G[cbRecent:GetName() .. "Text"]:SetText("No Recent")
    _G[cbRecent:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbRecent:SetChecked(filters.excludeRecentInvites)
    cbRecent:SetScript("OnClick", function(s) filters.excludeRecentInvites = s:GetChecked() end)

    -- Recruit Everyone Primary CTA Button
    local recruitAllBtn = CreateFrame("Button", nil, bar)
    recruitAllBtn:SetSize(160, 26)
    recruitAllBtn:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    recruitAllBtn:SetBackdrop(backdropObsidian)
    recruitAllBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    recruitAllBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local rFont = recruitAllBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rFont:SetPoint("CENTER", recruitAllBtn, "CENTER", 0, 0)
    rFont:SetText("[ Recruit Everyone ]")
    recruitAllBtn.rFont = rFont
    self.recruitAllBtn = recruitAllBtn

    recruitAllBtn:SetScript("OnClick", function()
        local count = GInviter.QueueManager:QueueBatch(GUI.scannedPlayers)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00a2ff[GInviter]|r Queued " .. count .. " eligible players.")
        GInviter.QueueManager:StartQueue()
    end)
end

-- Top Pane: Candidate Pool Table (Height: 235px)
function GUI:CreateCandidatePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 235)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -72)
    p:SetBackdrop(backdropObsidian)
    p:SetBackdropColor(0.06, 0.07, 0.1, 0.9)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.candidatePane = p

    -- Table Column Header Bar
    local header = CreateFrame("Frame", nil, p)
    header:SetSize(704, 22)
    header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    header:SetBackdrop(backdropObsidian)
    header:SetBackdropColor(0.1, 0.12, 0.16, 1.0)
    header:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    local th1 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th1:SetPoint("LEFT", header, "LEFT", 10, 0)
    th1:SetText("|cff8f8f8fPLAYER|r")

    local th2 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th2:SetPoint("LEFT", header, "LEFT", 135, 0)
    th2:SetText("|cff8f8f8fCLASS / LV|r")

    local th3 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th3:SetPoint("LEFT", header, "LEFT", 250, 0)
    th3:SetText("|cff8f8f8fSTATUS & REASON|r")

    local th4 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    th4:SetPoint("LEFT", header, "LEFT", 565, 0)
    th4:SetText("|cff8f8f8fACTION|r")

    -- Scroll Frame with 35px right margin clearance for scrollbar
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterCandidateScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(675, 210)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -22)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 210)
    scrollFrame:SetScrollChild(content)
    self.candidateContent = content
    self.candidateRows = {}
end

function GUI:OnWhoScanCompleted(results, summary)
    self.scannedPlayers = results or {}
    if self.recruitAllBtn and self.recruitAllBtn.rFont then
        local eligibleCount = (summary and summary.eligible) or 0
        self.recruitAllBtn.rFont:SetText("[ Recruit Everyone (" .. eligibleCount .. ") ]")
    end

    for _, row in ipairs(self.candidateRows) do row:Hide() end

    local rowHeight = 26
    self.candidateContent:SetHeight(math.max(#results * rowHeight, 210))

    for i, p in ipairs(results) do
        local row = self.candidateRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.candidateContent)
            row:SetSize(645, 24) -- 645px row width (30px clear gap before frame right edge)
            row:SetBackdrop(backdropObsidian)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.nameText = nameText

            local classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            classText:SetPoint("LEFT", row, "LEFT", 135, 0)
            row.classText = classText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("LEFT", row, "LEFT", 250, 0)
            row.statusText = statusText

            local actBtn = CreateFrame("Button", nil, row)
            actBtn:SetSize(85, 20)
            actBtn:SetPoint("LEFT", row, "LEFT", 555, 0) -- Fixed X position, zero overlap
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

        local colorStr = GetClassColorStr(p.classFileName, p.class)
        row.nameText:SetText(colorStr .. p.name .. "|r")
        row.classText:SetText("Lv" .. p.level .. " " .. p.class)

        -- Strict Status Truncation (Max 38 characters to prevent bleed)
        local rawStatus = p.isEligible and "Eligible" or (p.reason or "Ineligible")
        local truncatedStatus = TruncateString(rawStatus, 38)

        if p.isEligible then
            row.statusText:SetText("|cff00e676[ " .. truncatedStatus .. " ]|r")
            row.actBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            row.actBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            row.actBtn.actFont:SetText("[ + Queue ]")
            row.actBtn:SetScript("OnClick", function()
                GInviter.QueueManager:AddToQueue(p)
                GInviter.QueueManager:StartQueue()
            end)
        else
            row.statusText:SetText("|cffff3355[" .. truncatedStatus .. "]|r")
            row.actBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.8)
            row.actBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)
            row.actBtn.actFont:SetText("Skip")
            row.actBtn:SetScript("OnClick", nil)
        end

        -- Full Tooltip
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

-- Bottom Pane: Active Queue & Whisper Deck (Height: 185px)
function GUI:CreateQueuePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 185)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -312)
    p:SetBackdrop(backdropObsidian)
    p:SetBackdropColor(0.06, 0.07, 0.1, 0.9)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.queuePane = p

    -- Queue Action Bar
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(704, 26)
    bar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    bar:SetBackdrop(backdropObsidian)
    bar:SetBackdropColor(0.1, 0.12, 0.16, 1.0)
    bar:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    local qTitle = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qTitle:SetPoint("LEFT", bar, "LEFT", 10, 0)
    qTitle:SetText("|cff00a2ffACTIVE RECRUITMENT QUEUE|r")
    self.qTitle = qTitle

    local startBtn = CreateFrame("Button", nil, bar)
    startBtn:SetSize(90, 20)
    startBtn:SetPoint("LEFT", bar, "LEFT", 220, 0)
    startBtn:SetBackdrop(backdropObsidian)
    startBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    startBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local stFont = startBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stFont:SetPoint("CENTER", startBtn, "CENTER", 0, 0)
    stFont:SetText("Start Queue")
    startBtn:SetScript("OnClick", function() GInviter.QueueManager:StartQueue() end)

    local pauseBtn = CreateFrame("Button", nil, bar)
    pauseBtn:SetSize(70, 20)
    pauseBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)
    pauseBtn:SetBackdrop(backdropObsidian)
    pauseBtn:SetBackdropColor(0.8, 0.5, 0.1, 1.0)
    pauseBtn:SetBackdropBorderColor(0.9, 0.6, 0.2, 1.0)

    local pFont = pauseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pFont:SetPoint("CENTER", pauseBtn, "CENTER", 0, 0)
    pFont:SetText("Pause")
    pauseBtn:SetScript("OnClick", function() GInviter.QueueManager:PauseQueue() end)

    local clearBtn = CreateFrame("Button", nil, bar)
    clearBtn:SetSize(70, 20)
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 6, 0)
    clearBtn:SetBackdrop(backdropObsidian)
    clearBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    clearBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cFont:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    cFont:SetText("Clear")
    clearBtn:SetScript("OnClick", function() GInviter.QueueManager:ClearQueue() end)

    -- Auto Whisper Checkbox
    local whisperCheck = CreateFrame("CheckButton", "GInviterQAutoWhisper", bar, "UICheckButtonTemplate")
    whisperCheck:SetPoint("LEFT", clearBtn, "RIGHT", 14, 0)
    _G[whisperCheck:GetName() .. "Text"]:SetText("Auto-Whisper")
    _G[whisperCheck:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    whisperCheck:SetChecked(GInviter.Database:GetSettings().autoWhisper)
    whisperCheck:SetScript("OnClick", function(s)
        GInviter.Database:GetSettings().autoWhisper = s:GetChecked()
    end)

    -- Scroll Area with 35px right clearance
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterQueueScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(675, 155)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 155)
    scrollFrame:SetScrollChild(content)
    self.queueContent = content
    self.queueRows = {}
end

function GUI:OnQueueUpdated(queue)
    self.queueList = queue or {}
    if self.qTitle then
        self.qTitle:SetText("|cff00a2ffACTIVE QUEUE|r (|cffffffff" .. #queue .. " Pending|r)")
    end
    if not self.queueContent then return end

    for _, row in ipairs(self.queueRows) do row:Hide() end
    self.queueContent:SetHeight(math.max(#queue * 26, 155))

    for i, p in ipairs(queue) do
        local row = self.queueRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.queueContent)
            row:SetSize(645, 24)
            row:SetBackdrop(backdropObsidian)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.nameText = nameText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("LEFT", row, "LEFT", 250, 0)
            row.statusText = statusText

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(70, 20)
            removeBtn:SetPoint("LEFT", row, "LEFT", 555, 0)
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

-- Fallback Mode HUD Component (Integrated Footer Dock + Floating Pill)
function GUI:CreateFallbackHUD()
    -- 1. Integrated Footer Action Dock
    local dock = CreateFrame("Button", "GInviterFooterDockButton", self.mainFrame, "SecureActionButtonTemplate")
    dock:SetSize(704, 32)
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
    pill:SetSize(250, 42)
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
