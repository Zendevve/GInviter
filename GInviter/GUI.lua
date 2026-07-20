-- GInviter GUI.lua - Ultimate UX Perfection Engine
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.GUI = {}
local GUI = GInviter.GUI

GUI.scannedPlayers = {}
GUI.filteredPlayers = {}
GUI.queueList = {}
GUI.isScanning = false
GUI.searchQuery = ""
GUI.queueState = "IDLE" -- IDLE, RUNNING, PAUSED, COMPLETED

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

    -- Main Window Container (Top/Bottom Split View: 720x550)
    local f = CreateFrame("Frame", "GInviterMainFrame", UIParent)
    f:SetSize(720, 550)
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
        PlaySound("igMainMenuOptionCheckBoxOff")
        f:Hide()
        GUI:UpdateFloatingHUDState()
    end)

    -- Top Filter & Action Toolbar
    self:CreateFilterBar(f)

    -- Top Pane: Candidate Pool Table (Height: 240px)
    self:CreateCandidatePane(f)

    -- Bottom Pane: Active Queue & Whisper Deck (Height: 185px)
    self:CreateQueuePane(f)

    -- Fallback Mode Action Dock & Floating Pill
    self:CreateFallbackHUD()

    -- Toast Notification Frame
    self:CreateToastSystem()

    -- Whisper Template Dialog
    self:CreateTemplateDialog()
end

-- On-Screen Toast Notification System
function GUI:CreateToastSystem()
    local toast = CreateFrame("Frame", "GInviterToastFrame", UIParent)
    toast:SetSize(340, 34)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -50)
    toast:SetFrameStrata("TOOLTIP")
    toast:SetBackdrop(backdropObsidian)
    toast:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
    toast:SetBackdropBorderColor(0.0, 0.64, 1.0, 1.0)
    toast:Hide()

    local text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", toast, "CENTER", 0, 0)
    toast.text = text
    self.toastFrame = toast
end

function GUI:ShowToast(message, colorType)
    if not self.toastFrame then return end
    colorType = colorType or "BLUE"

    local borderColor = {0.0, 0.64, 1.0, 1.0}
    if colorType == "GREEN" then borderColor = {0.0, 0.9, 0.4, 1.0}
    elseif colorType == "AMBER" then borderColor = {1.0, 0.7, 0.0, 1.0}
    elseif colorType == "RED" then borderColor = {1.0, 0.2, 0.3, 1.0} end

    self.toastFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    self.toastFrame.text:SetText(message)
    self.toastFrame:Show()

    local elapsed = 0
    self.toastFrame:SetScript("OnUpdate", function(f, el)
        elapsed = elapsed + el
        if elapsed >= 2.5 then
            f:SetScript("OnUpdate", nil)
            f:Hide()
        end
    end)
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
    scanBtn.sFont = sFont
    self.scanBtn = scanBtn

    scanBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        if GInviter.WhoScanner.isScanning then
            GInviter.WhoScanner:StopAutoScan()
        else
            GInviter.WhoScanner:StartAutoScan()
        end
    end)

    -- Filters
    local filters = GInviter.Database:GetSettings().filters or GInviter.Config.Defaults.filters

    local cbNoGuild = CreateFrame("CheckButton", "GInviterFBarNoGuild", bar, "UICheckButtonTemplate")
    cbNoGuild:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
    _G[cbNoGuild:GetName() .. "Text"]:SetText("No Guild")
    _G[cbNoGuild:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbNoGuild:SetChecked(filters.noGuildOnly)
    cbNoGuild:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.noGuildOnly = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)

    local cbFriends = CreateFrame("CheckButton", "GInviterFBarFriends", bar, "UICheckButtonTemplate")
    cbFriends:SetPoint("LEFT", cbNoGuild, "RIGHT", 50, 0)
    _G[cbFriends:GetName() .. "Text"]:SetText("No Friends")
    _G[cbFriends:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbFriends:SetChecked(filters.excludeFriends)
    cbFriends:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeFriends = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)

    local cbIgnores = CreateFrame("CheckButton", "GInviterFBarIgnores", bar, "UICheckButtonTemplate")
    cbIgnores:SetPoint("LEFT", cbFriends, "RIGHT", 60, 0)
    _G[cbIgnores:GetName() .. "Text"]:SetText("No Ignores")
    _G[cbIgnores:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbIgnores:SetChecked(filters.excludeIgnores)
    cbIgnores:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeIgnores = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)

    local cbRecent = CreateFrame("CheckButton", "GInviterFBarRecent", bar, "UICheckButtonTemplate")
    cbRecent:SetPoint("LEFT", cbIgnores, "RIGHT", 60, 0)
    _G[cbRecent:GetName() .. "Text"]:SetText("No Recent")
    _G[cbRecent:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbRecent:SetChecked(filters.excludeRecentInvites)
    cbRecent:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeRecentInvites = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)

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
        PlaySound("igPlayerOptionCheckBoxOn")
        local count = GInviter.QueueManager:QueueBatch(GUI.scannedPlayers)
        GUI:ShowToast("Queued " .. count .. " players", "GREEN")
        GInviter.QueueManager:StartQueue()
        GUI:RefreshCandidateRows()
    end)
end

-- Live Scan Status Callback
function GUI:OnScanStatusUpdated(statusText, isScanning)
    self.isScanning = isScanning
    if self.scanBtn and self.scanBtn.sFont then
        if isScanning then
            self.scanBtn.sFont:SetText("|cff00e676" .. statusText .. "|r")
            self.scanBtn:SetBackdropColor(0.0, 0.5, 0.9, 1.0)
            self.scanBtn:SetBackdropBorderColor(0.0, 0.9, 0.4, 1.0)
        else
            self.scanBtn.sFont:SetText("Run /who Scan")
            self.scanBtn:SetBackdropColor(0.1, 0.4, 0.8, 1.0)
            self.scanBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 1.0)
        end
    end
end

-- Top Pane: Candidate Pool Table (Height: 245px)
function GUI:CreateCandidatePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 245)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -72)
    p:SetBackdrop(backdropObsidian)
    p:SetBackdropColor(0.06, 0.07, 0.1, 0.9)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.candidatePane = p

    -- Table Column Header Bar & Live Search EditBox
    local header = CreateFrame("Frame", nil, p)
    header:SetSize(704, 26)
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

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "GInviterSearchEditBox", header, "InputBoxTemplate")
    searchBox:SetSize(140, 18)
    searchBox:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")

    local sLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sLabel:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    sLabel:SetText("Search:")

    searchBox:SetScript("OnTextChanged", function(s)
        GUI.searchQuery = string.lower(s:GetText() or "")
        GUI:ApplyCandidateFilter()
    end)

    -- Scroll Frame with 35px right margin clearance
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterCandidateScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(675, 218)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 218)
    scrollFrame:SetScrollChild(content)
    self.candidateContent = content
    self.candidateRows = {}
end

function GUI:OnWhoScanCompleted(results, summary)
    self.scannedPlayers = results or {}
    self:ApplyCandidateFilter(summary)
end

function GUI:ApplyCandidateFilter(summary)
    self.filteredPlayers = {}
    local query = self.searchQuery or ""

    local eligibleCount = 0
    for _, p in ipairs(self.scannedPlayers) do
        local isMatch = true
        if query ~= "" then
            local nameLower = string.lower(p.name or "")
            local classLower = string.lower(p.class or "")
            local levelStr = tostring(p.level or "")
            if not string.find(nameLower, query) and not string.find(classLower, query) and not string.find(levelStr, query) then
                isMatch = false
            end
        end

        if isMatch then
            table.insert(self.filteredPlayers, p)
            if p.isEligible then eligibleCount = eligibleCount + 1 end
        end
    end

    if self.recruitAllBtn and self.recruitAllBtn.rFont then
        self.recruitAllBtn.rFont:SetText("[ Recruit Everyone (" .. eligibleCount .. ") ]")
    end

    self:RefreshCandidateRows()
end

function GUI:RefreshCandidateRows()
    if not self.candidateContent then return end
    local results = self.filteredPlayers or {}

    for _, row in ipairs(self.candidateRows) do row:Hide() end

    local rowHeight = 26
    self.candidateContent:SetHeight(math.max(#results * rowHeight, 218))

    for i, p in ipairs(results) do
        local row = self.candidateRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.candidateContent)
            row:SetSize(645, 24)
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
            actBtn:SetPoint("LEFT", row, "LEFT", 555, 0)
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

        -- Check if player is already in active queue
        local isQueued, qStatus = GInviter.QueueManager:IsQueued(p.name)

        if isQueued then
            row.statusText:SetText("|cff00e676[ QUEUED - " .. (qStatus or "QUEUED") .. " ]|r")
            row.actBtn:SetBackdropColor(0.0, 0.4, 0.2, 0.8)
            row.actBtn:SetBackdropBorderColor(0.0, 0.7, 0.3, 0.8)
            row.actBtn.actFont:SetText("|cff00e676[ QUEUED ]|r")
            row.actBtn:SetScript("OnClick", nil)
        elseif p.isEligible then
            local rawStatus = "Eligible"
            local truncatedStatus = TruncateString(rawStatus, 38)
            row.statusText:SetText("|cff00e676[ " .. truncatedStatus .. " ]|r")
            row.actBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            row.actBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            row.actBtn.actFont:SetText("[ + Queue ]")
            row.actBtn:SetScript("OnClick", function()
                PlaySound("igPlayerOptionCheckBoxOn")
                GInviter.QueueManager:AddToQueue(p)
                GInviter.QueueManager:StartQueue()
                GUI:RefreshCandidateRows()
            end)
        else
            local rawStatus = p.reason or "Ineligible"
            local truncatedStatus = TruncateString(rawStatus, 38)
            row.statusText:SetText("|cffff3355[" .. truncatedStatus .. "]|r")
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

-- Bottom Pane: Active Queue & Progress Deck (Height: 185px)
function GUI:CreateQueuePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 185)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -322)
    p:SetBackdrop(backdropObsidian)
    p:SetBackdropColor(0.06, 0.07, 0.1, 0.9)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.queuePane = p

    -- Queue Action Bar & Progress Dock
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(704, 30)
    bar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    bar:SetBackdrop(backdropObsidian)
    bar:SetBackdropColor(0.1, 0.12, 0.16, 1.0)
    bar:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    -- Live Progress Bar Texture Fill
    local progressBar = CreateFrame("Frame", nil, bar)
    progressBar:SetSize(1, 28)
    progressBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    progressBar:SetBackdrop(backdropObsidian)
    progressBar:SetBackdropColor(0.0, 0.5, 0.9, 0.25)
    self.qProgressBar = progressBar

    local qTitle = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qTitle:SetPoint("LEFT", bar, "LEFT", 10, 0)
    qTitle:SetText("|cff00a2ffACTIVE QUEUE|r (|cffffffff0 Pending|r)")
    self.qTitle = qTitle

    local startBtn = CreateFrame("Button", nil, bar)
    startBtn:SetSize(100, 22)
    startBtn:SetPoint("LEFT", bar, "LEFT", 220, 0)
    startBtn:SetBackdrop(backdropObsidian)
    startBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    startBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local stFont = startBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stFont:SetPoint("CENTER", startBtn, "CENTER", 0, 0)
    stFont:SetText("Start Queue")
    startBtn.stFont = stFont
    self.startBtn = startBtn
    startBtn:SetScript("OnClick", function()
        if GInviter.QueueManager.isRunning then
            GInviter.QueueManager:PauseQueue()
        else
            GInviter.QueueManager:StartQueue()
        end
    end)

    local pauseBtn = CreateFrame("Button", nil, bar)
    pauseBtn:SetSize(70, 22)
    pauseBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)
    pauseBtn:SetBackdrop(backdropObsidian)
    pauseBtn:SetBackdropColor(0.8, 0.5, 0.1, 1.0)
    pauseBtn:SetBackdropBorderColor(0.9, 0.6, 0.2, 1.0)

    local pFont = pauseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pFont:SetPoint("CENTER", pauseBtn, "CENTER", 0, 0)
    pFont:SetText("Pause")
    pauseBtn.pFont = pFont
    self.pauseBtn = pauseBtn
    pauseBtn:SetScript("OnClick", function() GInviter.QueueManager:PauseQueue() end)

    local clearBtn = CreateFrame("Button", nil, bar)
    clearBtn:SetSize(70, 22)
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
    _G[whisperCheck:GetName() .. "Text"]:SetText("Whisper")
    _G[whisperCheck:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    whisperCheck:SetChecked(GInviter.Database:GetSettings().autoWhisper)
    whisperCheck:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        GInviter.Database:GetSettings().autoWhisper = s:GetChecked()
    end)

    -- Whisper Template Edit Dialog Trigger Button
    local editTemplateBtn = CreateFrame("Button", nil, bar)
    editTemplateBtn:SetSize(75, 20)
    editTemplateBtn:SetPoint("LEFT", whisperCheck, "RIGHT", 65, 0)
    editTemplateBtn:SetBackdrop(backdropObsidian)
    editTemplateBtn:SetBackdropColor(0.12, 0.15, 0.22, 1.0)
    editTemplateBtn:SetBackdropBorderColor(0.25, 0.3, 0.4, 1.0)

    local etFont = editTemplateBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    etFont:SetPoint("CENTER", editTemplateBtn, "CENTER", 0, 0)
    etFont:SetText("Edit Text")

    editTemplateBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        if GUI.templateDialog then
            if GUI.templateDialog:IsShown() then
                GUI.templateDialog:Hide()
            else
                GUI.templateDialog:Show()
            end
        end
    end)

    -- Scroll Area with 35px right clearance
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterQueueScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(675, 150)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 150)
    scrollFrame:SetScrollChild(content)
    self.queueContent = content
    self.queueRows = {}
end

-- Live Queue State Callback
function GUI:OnQueueStateChanged(state, activeTarget, completed, total)
    self.queueState = state
    total = total or #self.queueList
    completed = completed or 0

    local pct = (total > 0) and math.min(1.0, completed / total) or 0
    if self.qProgressBar then
        self.qProgressBar:SetWidth(math.max(1, math.floor(702 * pct)))
    end

    if self.qTitle then
        if state == "RUNNING" then
            self.qTitle:SetText("|cff00e676ACTIVE QUEUE - RUNNING (" .. completed .. "/" .. total .. ")|r")
        elseif state == "PAUSED" then
            self.qTitle:SetText("|cffffcc00ACTIVE QUEUE - PAUSED (" .. completed .. "/" .. total .. ")|r")
        else
            self.qTitle:SetText("|cff00a2ffACTIVE QUEUE|r (|cffffffff" .. total .. " Pending|r)")
        end
    end

    if self.startBtn and self.startBtn.stFont then
        if state == "RUNNING" then
            self.startBtn.stFont:SetText("[ RUNNING ]")
            self.startBtn:SetBackdropColor(0.0, 0.8, 0.4, 1.0)
            self.startBtn:SetBackdropBorderColor(0.2, 1.0, 0.5, 1.0)
        elseif state == "PAUSED" then
            self.startBtn.stFont:SetText("[ RESUME ]")
            self.startBtn:SetBackdropColor(0.9, 0.6, 0.1, 1.0)
            self.startBtn:SetBackdropBorderColor(1.0, 0.7, 0.2, 1.0)
        else
            self.startBtn.stFont:SetText("Start Queue")
            self.startBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
            self.startBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)
        end
    end
end

function GUI:OnWhisperTicker(targetName, secondsRemaining)
    if self.qTitle then
        self.qTitle:SetText("|cff00a2ffWHISPERING: " .. targetName .. " (" .. secondsRemaining .. "s)|r")
    end
end

function GUI:OnQueueUpdated(queue)
    self.queueList = queue or {}
    if self.qTitle then
        self.qTitle:SetText("|cff00a2ffACTIVE QUEUE|r (|cffffffff" .. #queue .. " Pending|r)")
    end
    if not self.queueContent then return end

    for _, row in ipairs(self.queueRows) do row:Hide() end
    self.queueContent:SetHeight(math.max(#queue * 26, 150))

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
            statusText:SetPoint("LEFT", row, "LEFT", 180, 0)
            row.statusText = statusText

            -- Action buttons: Move Up, Move Down, Invite Now, Remove
            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(20, 20)
            upBtn:SetPoint("LEFT", row, "LEFT", 440, 0)
            upBtn:SetBackdrop(backdropObsidian)
            upBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
            upBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)
            local uFont = upBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            uFont:SetPoint("CENTER", upBtn, "CENTER", 0, 0)
            uFont:SetText("^")
            row.upBtn = upBtn

            local dnBtn = CreateFrame("Button", nil, row)
            dnBtn:SetSize(20, 20)
            dnBtn:SetPoint("LEFT", upBtn, "RIGHT", 4, 0)
            dnBtn:SetBackdrop(backdropObsidian)
            dnBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
            dnBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)
            local dFont = dnBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dFont:SetPoint("CENTER", dnBtn, "CENTER", 0, 0)
            dFont:SetText("v")
            row.dnBtn = dnBtn

            local nowBtn = CreateFrame("Button", nil, row)
            nowBtn:SetSize(75, 20)
            nowBtn:SetPoint("LEFT", dnBtn, "RIGHT", 6, 0)
            nowBtn:SetBackdrop(backdropObsidian)
            nowBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            nowBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            local nFont = nowBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nFont:SetPoint("CENTER", nowBtn, "CENTER", 0, 0)
            nFont:SetText("Invite Now")
            row.nowBtn = nowBtn

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(60, 20)
            removeBtn:SetPoint("LEFT", nowBtn, "RIGHT", 6, 0)
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

        row.upBtn:SetScript("OnClick", function()
            PlaySound("igPlayerOptionCheckBoxOn")
            GInviter.QueueManager:MoveQueueItem(i, -1)
        end)

        row.dnBtn:SetScript("OnClick", function()
            PlaySound("igPlayerOptionCheckBoxOn")
            GInviter.QueueManager:MoveQueueItem(i, 1)
        end)

        row.nowBtn:SetScript("OnClick", function()
            PlaySound("igPlayerOptionCheckBoxOn")
            GInviter.QueueManager:InviteNow(i)
        end)

        row.removeBtn:SetScript("OnClick", function()
            PlaySound("igPlayerOptionCheckBoxOn")
            GInviter.QueueManager:RemoveFromQueue(i)
            GUI:RefreshCandidateRows()
        end)

        row:Show()
    end

    self:RefreshCandidateRows()
end

-- Interactive Whisper Template Manager Dialog
function GUI:CreateTemplateDialog()
    local d = CreateFrame("Frame", "GInviterTemplateDialog", self.mainFrame)
    d:SetSize(420, 220)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop(backdropObsidian)
    d:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
    d:SetBackdropBorderColor(0.0, 0.64, 1.0, 1.0)
    d:Hide()

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -12)
    title:SetText("|cff00a2ffRecruitment Whisper Template|r")

    local editBox = CreateFrame("EditBox", "GInviterTemplateEditBox", d, "InputBoxTemplate")
    editBox:SetSize(390, 100)
    editBox:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -45)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")

    local settings = GInviter.Database:GetSettings()
    local tIdx = settings.activeTemplateIndex or 1
    local templates = settings.whisperTemplates or GInviter.Config.Defaults.whisperTemplates
    editBox:SetText(templates[tIdx] or templates[1])

    local saveBtn = CreateFrame("Button", nil, d)
    saveBtn:SetSize(120, 26)
    saveBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 14)
    saveBtn:SetBackdrop(backdropObsidian)
    saveBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    saveBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)

    local sFont = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sFont:SetPoint("CENTER", saveBtn, "CENTER", 0, 0)
    sFont:SetText("Save Text")

    saveBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        local text = editBox:GetText()
        if text and text ~= "" then
            templates[tIdx] = text
            GUI:ShowToast("Whisper template saved", "GREEN")
        end
        d:Hide()
    end)

    local closeBtn = CreateFrame("Button", nil, d)
    closeBtn:SetSize(90, 26)
    closeBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 14)
    closeBtn:SetBackdrop(backdropObsidian)
    closeBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    closeBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cFont:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    cFont:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOff")
        d:Hide()
    end)

    self.templateDialog = d
end

-- Fallback Mode HUD Component (Integrated Footer Dock + Floating Pill + 1-Click Keybinder)
function GUI:CreateFallbackHUD()
    -- 1. Integrated Footer Action Dock
    local dock = CreateFrame("Button", "GInviterFooterDockButton", self.mainFrame, "SecureActionButtonTemplate")
    dock:SetSize(580, 32)
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

    -- 1-Click Hotkey Binding Button on Footer
    local bindBtn = CreateFrame("Button", nil, self.mainFrame)
    bindBtn:SetSize(115, 32)
    bindBtn:SetPoint("LEFT", dock, "RIGHT", 6, 0)
    bindBtn:SetBackdrop(backdropObsidian)
    bindBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
    bindBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)
    bindBtn:Hide()

    local bFont = bindBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bFont:SetPoint("CENTER", bindBtn, "CENTER", 0, 0)
    bFont:SetText("Bind Wheel")
    bindBtn:SetScript("OnClick", function()
        SetBindingClick("MOUSEWHEELDOWN", "GInviterFooterDockButton")
        SaveBindings(GetCurrentBindingSet())
        GUI:ShowToast("Bound MouseWheelDown to Invite!", "GREEN")
    end)
    self.bindBtn = bindBtn

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
            if self.bindBtn then self.bindBtn:Show() end
        end

        if self.floatingPill then
            self.floatingPill:SetAttribute("type", "macro")
            self.floatingPill:SetAttribute("macrotext", "/ginvite " .. targetName)
            self.floatingPill.pillText:SetText("|cffffffff[ NEXT INVITE: |cff00e676" .. targetName .. "|r ]|r")
        end

        self:UpdateFloatingHUDState()
    else
        if self.footerDock then self.footerDock:Hide() end
        if self.bindBtn then self.bindBtn:Hide() end
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
