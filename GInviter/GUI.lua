-- GInviter GUI.lua - 100/100 Total UX Perfection Engine
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

-- 3-Tier Layered Depth Backdrops
local backdropBase = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

-- Modal Overlay Scrim (blocks background interaction during dialogs)
local function CreateModalScrim(modal)
    local scrim = CreateFrame("Frame", nil, UIParent)
    scrim:SetAllPoints(UIParent)
    scrim:SetFrameStrata("DIALOG")
    scrim:SetFrameLevel(modal:GetFrameLevel() - 1)
    scrim:EnableMouse(true)
    scrim:SetBackdrop(backdropBase)
    scrim:SetBackdropColor(0, 0, 0, 0.5)
    scrim:SetBackdropBorderColor(0, 0, 0, 0)
    scrim:Hide()
    modal:SetScript("OnShow", function() scrim:Show() end)
    modal:SetScript("OnHide", function() scrim:Hide() end)
end

function GUI:Initialize()
    if self.mainFrame then return end

    -- Main Window Container (Top/Bottom Split View: 720x570)
    local f = CreateFrame("Frame", "GInviterMainFrame", UIParent)
    f:SetSize(720, 570)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetBackdrop(backdropBase)
    f:SetBackdropColor(0.03, 0.03, 0.05, 0.98) -- Base Tier #08080d
    f:SetBackdropBorderColor(0.10, 0.11, 0.15, 1.0)
    f:Hide()
    tinsert(UISpecialFrames, "GInviterMainFrame")

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

    -- Title Bar Header Action Buttons (Settings & History Modals)
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOff")
        f:Hide()
        GUI:UpdateFloatingHUDState()
    end)

    local settingsBtn = CreateFrame("Button", nil, titleBar)
    settingsBtn:SetSize(24, 24)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    settingsBtn:SetBackdrop(backdropBase)
    settingsBtn:SetBackdropColor(0.08, 0.10, 0.15, 1.0)
    settingsBtn:SetBackdropBorderColor(0.20, 0.40, 0.80, 1.0)
    local sIcon = settingsBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sIcon:SetPoint("CENTER", settingsBtn, "CENTER", 0, 0)
    sIcon:SetText("|TInterface\\Icons\\INV_Misc_Gear_01:14|t")
    settingsBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        GUI:ToggleSettingsDialog()
    end)
    settingsBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("Settings Panel", 1, 1, 1)
        GameTooltip:AddLine("Configure timing, whisper rules, and sound effects", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local historyBtn = CreateFrame("Button", nil, titleBar)
    historyBtn:SetSize(24, 24)
    historyBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -4, 0)
    historyBtn:SetBackdrop(backdropBase)
    historyBtn:SetBackdropColor(0.08, 0.10, 0.15, 1.0)
    historyBtn:SetBackdropBorderColor(0.20, 0.40, 0.80, 1.0)
    local hIcon = historyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hIcon:SetPoint("CENTER", historyBtn, "CENTER", 0, 0)
    hIcon:SetText("|TInterface\\Icons\\INV_Misc_Note_02:14|t")
    historyBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        GUI:ToggleHistoryDialog()
    end)
    historyBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("Invite History & Stats", 1, 1, 1)
        GameTooltip:AddLine("View today's recruitment stats and recent log", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    historyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Top Filter & Action Toolbar
    self:CreateFilterBar(f)

    -- Scan Summary Dashboard Row
    self:CreateSummaryDashboard(f)

    -- Top Pane: Candidate Pool Table (Height: 220px)
    self:CreateCandidatePane(f)

    -- Section Divider (Candidate → Queue visual separator)
    local divider = CreateFrame("Frame", nil, f)
    divider:SetSize(704, 2)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -325)
    divider:SetBackdrop(backdropBase)
    divider:SetBackdropColor(0.0, 0.64, 1.0, 0.3)
    divider:SetBackdropBorderColor(0, 0, 0, 0)

    -- Bottom Pane: Active Queue & Whisper Deck (Height: 180px)
    self:CreateQueuePane(f)

    -- Fallback Mode Action Dock & Floating Pill
    self:CreateFallbackHUD()

    -- Toast Notification Frame
    self:CreateToastSystem()

    -- Modal Dialogs
    self:CreateBatchConfirmDialog()
    self:CreateSettingsDialog()
    self:CreateHistoryDialog()
    self:CreateTemplateDialog()
end

-- On-Screen Slide-Down Toast Notification System
function GUI:CreateToastSystem()
    local toast = CreateFrame("Frame", "GInviterToastFrame", UIParent)
    toast:SetSize(360, 36)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -50)
    toast:SetFrameStrata("TOOLTIP")
    toast:SetBackdrop(backdropBase)
    toast:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
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
    self.toastFrame.text:SetText("|TInterface\\Icons\\ACHIEVEMENT_GuildPERK_EveryoneIn:16|t  " .. message)
    self.toastFrame:Show()

    -- F6-5: Toast queue — auto-dismiss after 3s with fade
    if self.toastTimer then
        self.toastFrame:SetScript("OnUpdate", nil)
    end
    local elapsed = 0
    self.toastTimer = true
    self.toastFrame:SetScript("OnUpdate", function(f, el)
        elapsed = elapsed + el
        if elapsed >= 2.5 and elapsed < 3.0 then
            local alpha = 1.0 - ((elapsed - 2.5) / 0.5)
            f:SetAlpha(math.max(0, alpha))
        elseif elapsed >= 3.0 then
            f:SetScript("OnUpdate", nil)
            f:Hide()
            f:SetAlpha(1.0)
            self.toastTimer = nil
        end
    end)
end

-- Top Filter & Action Toolbar
function GUI:CreateFilterBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(704, 40)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -32)
    bar:SetBackdrop(backdropBase)
    bar:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    bar:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

    -- Run Scan Button
    local scanBtn = CreateFrame("Button", nil, bar)
    scanBtn:SetSize(120, 26)
    scanBtn:SetPoint("LEFT", bar, "LEFT", 8, 0)
    scanBtn:SetBackdrop(backdropBase)
    scanBtn:SetBackdropColor(0.08, 0.10, 0.15, 1.0)
    scanBtn:SetBackdropBorderColor(0.20, 0.40, 0.80, 1.0)

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

    -- Filters with spatial consistency (50px gaps) and GameTooltips
    local filters = GInviter.Database:GetSettings().filters or GInviter.Config.Defaults.filters

    local cbNoGuild = CreateFrame("CheckButton", "GInviterFBarNoGuild", bar, "UICheckButtonTemplate")
    cbNoGuild:SetPoint("LEFT", scanBtn, "RIGHT", 10, 0)
    _G[cbNoGuild:GetName() .. "Text"]:SetText("No Guild")
    _G[cbNoGuild:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbNoGuild:SetChecked(filters.noGuildOnly)
    cbNoGuild:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.noGuildOnly = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)
    cbNoGuild:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("No Guild Only", 1, 1, 1)
        GameTooltip:AddLine("Only include candidates who are not currently in a guild", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cbNoGuild:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cbFriends = CreateFrame("CheckButton", "GInviterFBarFriends", bar, "UICheckButtonTemplate")
    cbFriends:SetPoint("LEFT", cbNoGuild, "RIGHT", 20, 0)
    _G[cbFriends:GetName() .. "Text"]:SetText("No Friends")
    _G[cbFriends:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbFriends:SetChecked(filters.excludeFriends)
    cbFriends:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeFriends = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)
    cbFriends:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Exclude Friends", 1, 1, 1)
        GameTooltip:AddLine("Skip players on your personal friends list", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cbFriends:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cbIgnores = CreateFrame("CheckButton", "GInviterFBarIgnores", bar, "UICheckButtonTemplate")
    cbIgnores:SetPoint("LEFT", cbFriends, "RIGHT", 20, 0)
    _G[cbIgnores:GetName() .. "Text"]:SetText("No Ignores")
    _G[cbIgnores:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbIgnores:SetChecked(filters.excludeIgnores)
    cbIgnores:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeIgnores = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)
    cbIgnores:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Exclude Ignores & Blacklist", 1, 1, 1)
        GameTooltip:AddLine("Skip ignored or blacklisted players", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cbIgnores:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local cbRecent = CreateFrame("CheckButton", "GInviterFBarRecent", bar, "UICheckButtonTemplate")
    cbRecent:SetPoint("LEFT", cbIgnores, "RIGHT", 20, 0)
    _G[cbRecent:GetName() .. "Text"]:SetText("No Recent")
    _G[cbRecent:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbRecent:SetChecked(filters.excludeRecentInvites)
    cbRecent:SetScript("OnClick", function(s)
        PlaySound("igPlayerOptionCheckBoxOn")
        filters.excludeRecentInvites = s:GetChecked()
        GUI:ApplyCandidateFilter()
    end)
    cbRecent:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Exclude Recent Invites", 1, 1, 1)
        GameTooltip:AddLine("Skip players invited within duplicate protection window", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    cbRecent:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Visually Dominant Gold/Amber Primary CTA Button
    local recruitAllBtn = CreateFrame("Button", nil, bar)
    recruitAllBtn:SetSize(185, 30)
    recruitAllBtn:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    recruitAllBtn:SetBackdrop(backdropBase)
    recruitAllBtn:SetBackdropColor(0.85, 0.65, 0.10, 1.0)
    recruitAllBtn:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)

    local rFont = recruitAllBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    rFont:SetPoint("CENTER", recruitAllBtn, "CENTER", 0, 0)
    rFont:SetText("|TInterface\\Icons\\Achievement_GuildPERK_EveryoneIn:16|t |cffffffffQueue All Eligible|r")
    recruitAllBtn.rFont = rFont
    self.recruitAllBtn = recruitAllBtn

    recruitAllBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        local count = 0
        for _, p in ipairs(GUI.scannedPlayers) do
            if p.isEligible then count = count + 1 end
        end
        if count == 0 then
            GUI:ShowToast("No eligible candidates to queue", "AMBER")
            return
        end
        GUI:ShowBatchConfirmDialog(count)
    end)
end

-- Scan Summary Dashboard Row (Height 26px)
function GUI:CreateSummaryDashboard(parent)
    local dash = CreateFrame("Frame", nil, parent)
    dash:SetSize(704, 26)
    dash:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -74)
    dash:SetBackdrop(backdropBase)
    dash:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    dash:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)

    local b1 = dash:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b1:SetPoint("LEFT", dash, "LEFT", 10, 0)
    b1:SetText("|cff00a2ffTOTAL: 0|r")
    self.sumTotal = b1

    local b2 = dash:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b2:SetPoint("LEFT", dash, "LEFT", 130, 0)
    b2:SetText("|cffa0a0a0UNGUILDED: 0|r")
    self.sumUnguilded = b2

    local b3 = dash:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b3:SetPoint("LEFT", dash, "LEFT", 270, 0)
    b3:SetText("|cffffb300RECENT INVITED: 0|r")
    self.sumRecent = b3

    local b4 = dash:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b4:SetPoint("LEFT", dash, "LEFT", 430, 0)
    b4:SetText("|cffff3355IGNORED: 0|r")
    self.sumIgnored = b4

    local b5 = dash:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b5:SetPoint("LEFT", dash, "LEFT", 565, 0)
    b5:SetText("|cff00e676ELIGIBLE: 0|r")
    self.sumEligible = b5
end

function GUI:UpdateSummaryDashboard(summary)
    summary = summary or { total = 0, unguilded = 0, alreadyInvited = 0, ignored = 0, eligible = 0 }
    if self.sumTotal then self.sumTotal:SetText("|cff00a2ffTOTAL: " .. (summary.total or 0) .. "|r") end
    if self.sumUnguilded then self.sumUnguilded:SetText("|cffa0a0a0UNGUILDED: " .. (summary.unguilded or 0) .. "|r") end
    if self.sumRecent then self.sumRecent:SetText("|cffffb300RECENT INVITED: " .. (summary.alreadyInvited or 0) .. "|r") end
    if self.sumIgnored then self.sumIgnored:SetText("|cffff3355IGNORED: " .. (summary.ignored or 0) .. "|r") end
    if self.sumEligible then self.sumEligible:SetText("|cff00e676ELIGIBLE: " .. (summary.eligible or 0) .. "|r") end
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
            self.scanBtn:SetBackdropColor(0.08, 0.10, 0.15, 1.0)
            self.scanBtn:SetBackdropBorderColor(0.20, 0.40, 0.80, 1.0)
        end
    end
    -- F6-4: Update candidate pane empty state during active scan
    if self.emptyFrame and #(self.filteredPlayers or {}) == 0 then
        if isScanning then
            self.emptyFrame:Show()
            if self.emptyFrame.title then
                self.emptyFrame.title:SetText("|cff00a2ff" .. statusText .. "|r")
            end
            if self.emptyFrame.sub then
                self.emptyFrame.sub:SetText("Scanning for unguilded players...")
            end
        else
            if self.emptyFrame.title then
                self.emptyFrame.title:SetText("|cff00a2ffNo Candidates Loaded|r")
            end
            if self.emptyFrame.sub then
                self.emptyFrame.sub:SetText("Click Run /who Scan to search for unguilded players.")
            end
        end
    end
end

-- Top Pane: Candidate Pool Table (Height: 220px)
function GUI:CreateCandidatePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 220)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -102)
    p:SetBackdrop(backdropBase)
    p:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.candidatePane = p

    -- Table Column Header Bar & Live Search EditBox
    local header = CreateFrame("Frame", nil, p)
    header:SetSize(704, 26)
    header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    header:SetBackdrop(backdropBase)
    header:SetBackdropColor(0.08, 0.10, 0.14, 1.0)
    header:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    local th1 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    th1:SetPoint("LEFT", header, "LEFT", 10, 0)
    th1:SetText("PLAYER")

    local th2 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    th2:SetPoint("LEFT", header, "LEFT", 135, 0)
    th2:SetText("CLASS / LV")

    local th3 = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    th3:SetPoint("LEFT", header, "LEFT", 250, 0)
    th3:SetText("STATUS")

    -- Search EditBox (180x22px)
    local searchBox = CreateFrame("EditBox", "GInviterSearchEditBox", header, "InputBoxTemplate")
    searchBox:SetSize(180, 22)
    searchBox:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("GameFontHighlightSmall")

    local sLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sLabel:SetPoint("RIGHT", searchBox, "LEFT", -6, 0)
    sLabel:SetText("Filter:")

    searchBox:SetScript("OnTextChanged", function(s)
        GUI.searchQuery = string.lower(s:GetText() or "")
        GUI:ApplyCandidateFilter()
    end)

    -- Scroll Frame with 35px right margin clearance
    local scrollFrame = CreateFrame("ScrollFrame", "GInviterCandidateScroll", p, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(675, 194)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 194)
    scrollFrame:SetScrollChild(content)
    self.candidateContent = content
    self.candidateRows = {}

    -- Empty State Guidance Frame
    local emptyFrame = CreateFrame("Frame", nil, content)
    emptyFrame:SetSize(600, 140)
    emptyFrame:SetPoint("CENTER", content, "CENTER", 0, 0)

    local eIcon = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    eIcon:SetPoint("CENTER", emptyFrame, "CENTER", 0, 20)
    eIcon:SetText("|TInterface\\Icons\\INV_Shirt_GuildTabard_01:32|t")

    local eTitle = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    eTitle:SetPoint("TOP", eIcon, "BOTTOM", 0, -6)
    eTitle:SetText("|cff00a2ffNo Candidates Loaded|r")

    local eSub = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eSub:SetPoint("TOP", eTitle, "BOTTOM", 0, -4)
    eSub:SetText("Click [ Run /who Scan ] to search for unguilded players.")

    emptyFrame.title = eTitle
    emptyFrame.sub = eSub
    self.emptyFrame = emptyFrame
end

function GUI:OnWhoScanCompleted(results, summary)
    self.scannedPlayers = results or {}
    self:UpdateSummaryDashboard(summary)
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
        self.recruitAllBtn.rFont:SetText("|TInterface\\Icons\\Achievement_GuildPERK_EveryoneIn:16|t |cffffffffQueue All (" .. eligibleCount .. ")|r")
    end

    self:RefreshCandidateRows()
end

function GUI:RefreshCandidateRows()
    if not self.candidateContent then return end
    local results = self.filteredPlayers or {}

    if #results == 0 then
        if self.emptyFrame then self.emptyFrame:Show() end
        for _, row in ipairs(self.candidateRows) do row:Hide() end
        return
    else
        if self.emptyFrame then self.emptyFrame:Hide() end
    end

    for _, row in ipairs(self.candidateRows) do row:Hide() end

    local rowHeight = 26
    self.candidateContent:SetHeight(math.max(#results * rowHeight, 194))

    for i, p in ipairs(results) do
        local row = self.candidateRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.candidateContent)
            row:SetSize(645, 24)
            row:SetBackdrop(backdropBase)

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
            actBtn:SetBackdrop(backdropBase)

            local actFont = actBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            actFont:SetPoint("CENTER", actBtn, "CENTER", 0, 0)
            actBtn.actFont = actFont
            row.actBtn = actBtn

            self.candidateRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.candidateContent, "TOPLEFT", 0, -(i - 1) * 26)
        local baseR, baseG, baseB = (i % 2 == 0 and 0.06 or 0.09), (i % 2 == 0 and 0.07 or 0.1), (i % 2 == 0 and 0.09 or 0.13)
        row:SetBackdropColor(baseR, baseG, baseB, 0.9)
        row:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)

        -- Row Hover Highlight (+15% brightness boost)
        row:SetScript("OnEnter", function(s)
            s:SetBackdropColor(baseR + 0.08, baseG + 0.08, baseB + 0.08, 1.0)
            s:SetBackdropBorderColor(0.0, 0.64, 1.0, 0.8)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(p.name .. " (Lv" .. p.level .. " " .. p.class .. ")", 1, 1, 1)
            GameTooltip:AddLine("Status: " .. (p.isEligible and "|cff00e676Eligible|r" or ("|cffff3355" .. p.reason .. "|r")), 1, 1, 1)
            if p.guild and p.guild ~= "" then GameTooltip:AddLine("Guild: " .. p.guild, 0.7, 0.7, 0.7) end
            if p.zone and p.zone ~= "" then GameTooltip:AddLine("Zone: " .. p.zone, 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function(s)
            s:SetBackdropColor(baseR, baseG, baseB, 0.9)
            s:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)
            GameTooltip:Hide()
        end)

        local colorStr = GetClassColorStr(p.classFileName, p.class)
        row.nameText:SetText(colorStr .. p.name .. "|r")
        row.classText:SetText("Lv" .. p.level .. " " .. p.class)

        -- Check if player is already in active queue
        local isQueued, qStatus = GInviter.QueueManager:IsQueued(p.name)

        if isQueued then
            row.statusText:SetText("|cff00e676QUEUED - " .. (qStatus or "QUEUED") .. "|r")
            row.actBtn:SetBackdropColor(0.0, 0.4, 0.2, 0.8)
            row.actBtn:SetBackdropBorderColor(0.0, 0.7, 0.3, 0.8)
            row.actBtn.actFont:SetText("|cff00e676QUEUED|r")
            row.actBtn:SetScript("OnClick", nil)
        elseif p.isEligible then
            row.statusText:SetText("|cff00e676Eligible|r")
            row.actBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            row.actBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            row.actBtn.actFont:SetText("+ Queue")
            row.actBtn:SetScript("OnClick", function()
                PlaySound("igPlayerOptionCheckBoxOn")
                GInviter.QueueManager:AddToQueue(p)
                GUI:ShowToast(p.name .. " added to queue", "BLUE")
                GUI:RefreshCandidateRows()
            end)
        else
            local rawStatus = p.reason or "Ineligible"
            local truncatedStatus = TruncateString(rawStatus, 38)
            row.statusText:SetText("|cffff3355" .. truncatedStatus .. "|r")
            row.actBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.8)
            row.actBtn:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)
            row.actBtn.actFont:SetText("Skip")
            row.actBtn:SetScript("OnClick", nil)
        end

        row:Show()
    end
end

-- Bottom Pane: Active Queue & Progress Deck (Height: 180px)
function GUI:CreateQueuePane(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(704, 180)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -328)
    p:SetBackdrop(backdropBase)
    p:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    p:SetBackdropBorderColor(0.15, 0.16, 0.22, 1.0)
    self.queuePane = p

    -- Queue Action Bar & Progress Dock
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(704, 30)
    bar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    bar:SetBackdrop(backdropBase)
    bar:SetBackdropColor(0.08, 0.10, 0.14, 1.0)
    bar:SetBackdropBorderColor(0.18, 0.2, 0.26, 1.0)

    -- Live Progress Bar Texture Fill
    local progressBar = CreateFrame("Frame", nil, bar)
    progressBar:SetSize(1, 28)
    progressBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    progressBar:SetBackdrop(backdropBase)
    progressBar:SetBackdropColor(0.0, 0.5, 0.9, 0.25)
    self.qProgressBar = progressBar

    local qTitle = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    qTitle:SetPoint("LEFT", bar, "LEFT", 10, 0)
    qTitle:SetText("|cff00a2ffACTIVE QUEUE|r (|cffffffff0 Pending|r)")
    self.qTitle = qTitle

    local startBtn = CreateFrame("Button", nil, bar)
    startBtn:SetSize(100, 22)
    startBtn:SetPoint("LEFT", bar, "LEFT", 220, 0)
    startBtn:SetBackdrop(backdropBase)
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
    pauseBtn:SetBackdrop(backdropBase)
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
    clearBtn:SetBackdrop(backdropBase)
    clearBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    clearBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cFont:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
    cFont:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        GInviter.QueueManager:ClearQueue()
        GUI:ShowToast("Queue cleared", "AMBER")
    end)

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
    editTemplateBtn:SetBackdrop(backdropBase)
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
    scrollFrame:SetSize(675, 148)
    scrollFrame:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(660, 148)
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
            self.startBtn.stFont:SetText("|cff00e676RUNNING|r")
            self.startBtn:SetBackdropColor(0.0, 0.8, 0.4, 1.0)
            self.startBtn:SetBackdropBorderColor(0.2, 1.0, 0.5, 1.0)
        elseif state == "PAUSED" then
            self.startBtn.stFont:SetText("|cffffcc00RESUME|r")
            self.startBtn:SetBackdropColor(0.9, 0.6, 0.1, 1.0)
            self.startBtn:SetBackdropBorderColor(1.0, 0.7, 0.2, 1.0)
        else
            self.startBtn.stFont:SetText("Start Queue")
            self.startBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
            self.startBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)
        end
    end
    self:RefreshCandidateRows()
end

function GUI:OnQueueFinished()
    local stats = GInviter.Database:GetStats()
    self:ShowToast("Queue complete! " .. (stats.invited or 0) .. " invited, " .. (stats.accepted or 0) .. " joined", "GREEN")
    PlaySound("LevelUp")
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
    self.queueContent:SetHeight(math.max(#queue * 26, 148))

    for i, p in ipairs(queue) do
        local row = self.queueRows[i]
        if not row then
            row = CreateFrame("Frame", nil, self.queueContent)
            row:SetSize(645, 24)
            row:SetBackdrop(backdropBase)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.nameText = nameText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("LEFT", row, "LEFT", 180, 0)
            row.statusText = statusText

            -- Action buttons (Resized to 26x24 minimum targets)
            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(26, 24)
            upBtn:SetPoint("LEFT", row, "LEFT", 430, 0)
            upBtn:SetBackdrop(backdropBase)
            upBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
            upBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)
            local uFont = upBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            uFont:SetPoint("CENTER", upBtn, "CENTER", 0, 0)
            uFont:SetText("|cffffffffU|r")
            row.upBtn = upBtn

            local dnBtn = CreateFrame("Button", nil, row)
            dnBtn:SetSize(26, 24)
            dnBtn:SetPoint("LEFT", upBtn, "RIGHT", 6, 0)
            dnBtn:SetBackdrop(backdropBase)
            dnBtn:SetBackdropColor(0.15, 0.18, 0.24, 1.0)
            dnBtn:SetBackdropBorderColor(0.3, 0.35, 0.45, 1.0)
            local dFont = dnBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            dFont:SetPoint("CENTER", dnBtn, "CENTER", 0, 0)
            dFont:SetText("|cffffffffD|r")
            row.dnBtn = dnBtn

            local nowBtn = CreateFrame("Button", nil, row)
            nowBtn:SetSize(85, 24)
            nowBtn:SetPoint("LEFT", dnBtn, "RIGHT", 6, 0)
            nowBtn:SetBackdrop(backdropBase)
            nowBtn:SetBackdropColor(0.0, 0.5, 0.25, 1.0)
            nowBtn:SetBackdropBorderColor(0.1, 0.7, 0.35, 1.0)
            local nFont = nowBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nFont:SetPoint("CENTER", nowBtn, "CENTER", 0, 0)
            nFont:SetText("Invite Now")
            row.nowBtn = nowBtn

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(65, 24)
            removeBtn:SetPoint("LEFT", nowBtn, "RIGHT", 6, 0)
            removeBtn:SetBackdrop(backdropBase)
            removeBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
            removeBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1.0)
            local rmFont = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rmFont:SetPoint("CENTER", removeBtn, "CENTER", 0, 0)
            rmFont:SetText("Remove")
            row.removeBtn = removeBtn

            self.queueRows[i] = row
        end

        row:SetPoint("TOPLEFT", self.queueContent, "TOPLEFT", 0, -(i - 1) * 26)
        local baseR, baseG, baseB = (i % 2 == 0 and 0.06 or 0.09), (i % 2 == 0 and 0.07 or 0.1), (i % 2 == 0 and 0.09 or 0.13)
        row:SetBackdropColor(baseR, baseG, baseB, 0.9)
        row:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)

        row:SetScript("OnEnter", function(s)
            s:SetBackdropColor(baseR + 0.08, baseG + 0.08, baseB + 0.08, 1.0)
            s:SetBackdropBorderColor(0.0, 0.64, 1.0, 0.8)
        end)
        row:SetScript("OnLeave", function(s)
            s:SetBackdropColor(baseR, baseG, baseB, 0.9)
            s:SetBackdropBorderColor(0.12, 0.14, 0.18, 0.5)
        end)

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

-- Modal 1: Batch Recruit Confirmation Dialog
function GUI:CreateBatchConfirmDialog()
    local d = CreateFrame("Frame", "GInviterBatchConfirmDialog", self.mainFrame)
    d:SetSize(400, 160)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop(backdropBase)
    d:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
    d:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0)
    d:Hide()
    tinsert(UISpecialFrames, "GInviterBatchConfirmDialog")

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", d, "TOP", 0, -16)
    title:SetText("|cffffd700Confirm Batch Queue|r")

    local text = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", title, "BOTTOM", 0, -12)
    text:SetText("Queue N eligible candidates for recruitment?")
    d.msgText = text

    local sub = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", text, "BOTTOM", 0, -4)
    sub:SetText("This will prepare auto-whispers and guild invitations.")

    local confirmBtn = CreateFrame("Button", nil, d)
    confirmBtn:SetSize(140, 28)
    confirmBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 40, 16)
    confirmBtn:SetBackdrop(backdropBase)
    confirmBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    confirmBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)
    local cFont = confirmBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cFont:SetPoint("CENTER", confirmBtn, "CENTER", 0, 0)
    cFont:SetText("Confirm Queue")

    confirmBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        local count = GInviter.QueueManager:QueueBatch(GUI.scannedPlayers)
        GUI:ShowToast("Queued " .. count .. " players", "GREEN")
        GInviter.QueueManager:StartQueue()
        GUI:RefreshCandidateRows()
        d:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, d)
    cancelBtn:SetSize(110, 28)
    cancelBtn:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -40, 16)
    cancelBtn:SetBackdrop(backdropBase)
    cancelBtn:SetBackdropColor(0.6, 0.2, 0.2, 1.0)
    cancelBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1.0)
    local caFont = cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caFont:SetPoint("CENTER", cancelBtn, "CENTER", 0, 0)
    caFont:SetText("Cancel")

    cancelBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOff")
        d:Hide()
    end)

    CreateModalScrim(d)
    self.batchConfirmDialog = d
end

function GUI:ShowBatchConfirmDialog(count)
    if self.batchConfirmDialog then
        self.batchConfirmDialog.msgText:SetText("Queue " .. count .. " eligible candidates for recruitment?")
        self.batchConfirmDialog:Show()
    end
end

-- Modal 2: Settings Panel Modal
function GUI:CreateSettingsDialog()
    local d = CreateFrame("Frame", "GInviterSettingsDialog", self.mainFrame)
    d:SetSize(420, 360)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop(backdropBase)
    d:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
    d:SetBackdropBorderColor(0.0, 0.64, 1.0, 1.0)
    d:Hide()
    tinsert(UISpecialFrames, "GInviterSettingsDialog")

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -14)
    title:SetText("|cff00a2ffGInviter Settings|r")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)

    local settings = GInviter.Database:GetSettings()

    -- Section: Timing
    local secTiming = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secTiming:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -44)
    secTiming:SetText("|cffffcc00Timing|r")

    -- 1. Invite Interval Input
    local l1 = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l1:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -64)
    l1:SetText("Invite Interval (seconds):")

    local ebInterval = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    ebInterval:SetSize(60, 20)
    ebInterval:SetPoint("LEFT", l1, "RIGHT", 14, 0)
    ebInterval:SetNumber(settings.inviteInterval or 3)
    ebInterval:SetAutoFocus(false)

    -- 2. Scan Delay Input
    local l2 = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l2:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -96)
    l2:SetText("Who Scan Delay (seconds):")

    local ebScanDelay = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    ebScanDelay:SetSize(60, 20)
    ebScanDelay:SetPoint("LEFT", l2, "RIGHT", 14, 0)
    ebScanDelay:SetNumber(settings.whoScanDelay or 5)
    ebScanDelay:SetAutoFocus(false)

    -- Section: Whisper Behavior
    local secWhisper = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secWhisper:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -128)
    secWhisper:SetText("|cffffcc00Whisper Behavior|r")

    -- 3. Whisper Timeout Input
    local l3 = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l3:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -148)
    l3:SetText("Whisper Timeout (seconds):")

    local ebWhisperTimeout = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    ebWhisperTimeout:SetSize(60, 20)
    ebWhisperTimeout:SetPoint("LEFT", l3, "RIGHT", 14, 0)
    ebWhisperTimeout:SetNumber(settings.whisperTimeout or 20)
    ebWhisperTimeout:SetAutoFocus(false)

    -- 4. Timeout Action Checkbox
    local cbTimeoutAction = CreateFrame("CheckButton", "GInviterSetTimeoutAction", d, "UICheckButtonTemplate")
    cbTimeoutAction:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -180)
    _G[cbTimeoutAction:GetName() .. "Text"]:SetText("Direct Invite on Whisper Timeout")
    _G[cbTimeoutAction:GetName() .. "Text"]:SetFontObject("GameFontHighlightSmall")
    cbTimeoutAction:SetChecked(settings.whisperTimeoutAction == "invite")

    -- Save Settings Button
    local saveBtn = CreateFrame("Button", nil, d)
    saveBtn:SetSize(120, 26)
    saveBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 20, 16)
    saveBtn:SetBackdrop(backdropBase)
    saveBtn:SetBackdropColor(0.0, 0.6, 0.3, 1.0)
    saveBtn:SetBackdropBorderColor(0.1, 0.8, 0.4, 1.0)
    local sFont = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sFont:SetPoint("CENTER", saveBtn, "CENTER", 0, 0)
    sFont:SetText("Save Settings")

    saveBtn:SetScript("OnClick", function()
        PlaySound("igPlayerOptionCheckBoxOn")
        settings.inviteInterval = tonumber(ebInterval:GetText()) or 3
        settings.whoScanDelay = tonumber(ebScanDelay:GetText()) or 5
        settings.whisperTimeout = tonumber(ebWhisperTimeout:GetText()) or 20
        settings.whisperTimeoutAction = cbTimeoutAction:GetChecked() and "invite" or "skip"
        GUI:ShowToast("Settings saved successfully!", "GREEN")
        d:Hide()
    end)

    CreateModalScrim(d)
    self.settingsDialog = d
end

function GUI:ToggleSettingsDialog()
    if self.settingsDialog then
        if self.settingsDialog:IsShown() then self.settingsDialog:Hide() else self.settingsDialog:Show() end
    end
end

-- Modal 3: Invite History & Daily Stats Modal
function GUI:CreateHistoryDialog()
    local d = CreateFrame("Frame", "GInviterHistoryDialog", self.mainFrame)
    d:SetSize(520, 360)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop(backdropBase)
    d:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
    d:SetBackdropBorderColor(0.0, 0.64, 1.0, 1.0)
    d:Hide()
    tinsert(UISpecialFrames, "GInviterHistoryDialog")

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -14)
    title:SetText("|cff00a2ffRecruitment History & Stats|r")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)

    local statsHeader = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsHeader:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -42)
    d.statsHeader = statsHeader

    local scrollFrame = CreateFrame("ScrollFrame", "GInviterHistoryScroll", d, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(475, 250)
    scrollFrame:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -70)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(460, 250)
    scrollFrame:SetScrollChild(content)
    d.historyContent = content
    d.historyRows = {}

    CreateModalScrim(d)
    self.historyDialog = d
end

function GUI:ToggleHistoryDialog()
    if self.historyDialog then
        if self.historyDialog:IsShown() then
            self.historyDialog:Hide()
        else
            self:RefreshHistoryDialog()
            self.historyDialog:Show()
        end
    end
end

function GUI:RefreshHistoryDialog()
    if not self.historyDialog then return end

    local stats = GInviter.Database:GetStats()
    if self.historyDialog.statsHeader then
        self.historyDialog.statsHeader:SetText("|cff00a2ffInvited: " .. (stats.invited or 0) .. "|r  |  |cff00e676Joined: " .. (stats.accepted or 0) .. "|r  |  |cffff3355Declined: " .. (stats.declined or 0) .. "|r  |  |cffffb300Guilded: " .. (stats.alreadyGuilded or 0) .. "|r")
    end

    local historyList = GInviter.Database:GetAllHistory()
    local content = self.historyDialog.historyContent
    if not content then return end

    for _, row in ipairs(self.historyDialog.historyRows) do row:Hide() end
    content:SetHeight(math.max(#historyList * 24, 250))

    for i, entry in ipairs(historyList) do
        local row = self.historyDialog.historyRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(450, 22)
            row:SetBackdrop(backdropBase)

            local t1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            t1:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.t1 = t1

            local t2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t2:SetPoint("LEFT", row, "LEFT", 180, 0)
            row.t2 = t2

            local t3 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t3:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.t3 = t3

            self.historyDialog.historyRows[i] = row
        end

        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * 24)
        row:SetBackdropColor(i % 2 == 0 and 0.06 or 0.09, i % 2 == 0 and 0.07 or 0.1, i % 2 == 0 and 0.09 or 0.13, 0.9)

        row.t1:SetText(entry.name .. " (Lv" .. (entry.level or 0) .. ")")
        local resColor = (entry.result == "ACCEPTED") and "|cff00e676" or ((entry.result == "DECLINED") and "|cffff3355" or "|cff00a2ff")
        row.t2:SetText(resColor .. (entry.result or "INVITED") .. "|r")

        local timeStr = entry.timestamp and date("%H:%M:%S", entry.timestamp) or ""
        row.t3:SetText("|cffa0a0a0" .. timeStr .. "|r")

        row:Show()
    end
end

-- Modal 4: Interactive Whisper Template Manager Dialog
function GUI:CreateTemplateDialog()
    local d = CreateFrame("Frame", "GInviterTemplateDialog", self.mainFrame)
    d:SetSize(420, 220)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    d:SetFrameStrata("DIALOG")
    d:SetBackdrop(backdropBase)
    d:SetBackdropColor(0.07, 0.08, 0.11, 0.98)
    d:SetBackdropBorderColor(0.0, 0.64, 1.0, 1.0)
    d:Hide()
    tinsert(UISpecialFrames, "GInviterTemplateDialog")

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
    saveBtn:SetBackdrop(backdropBase)
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
    closeBtn:SetBackdrop(backdropBase)
    closeBtn:SetBackdropColor(0.7, 0.2, 0.2, 1.0)
    closeBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

    local cFont = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cFont:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    cFont:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOff")
        d:Hide()
    end)

    CreateModalScrim(d)
    self.templateDialog = d
end

-- Fallback Mode HUD Component (Consolidated Draggable Pill HUD)
function GUI:CreateFallbackHUD()
    local pill = CreateFrame("Button", "GInviterFloatingPillButton", UIParent, "SecureActionButtonTemplate")
    pill:SetSize(260, 42)
    pill:SetPoint("TOP", UIParent, "TOP", 0, -100)
    pill:SetFrameStrata("FULLSCREEN_DIALOG")
    pill:SetBackdrop(backdropBase)
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
        if self.floatingPill then
            self.floatingPill:SetAttribute("type", "macro")
            self.floatingPill:SetAttribute("macrotext", "/ginvite " .. targetName)
            self.floatingPill.pillText:SetText("|cffffffff[ NEXT INVITE: |cff00e676" .. targetName .. "|r ]|r")
            self.floatingPill:Show()
        end
    else
        if self.floatingPill then self.floatingPill:Hide() end
    end
end

function GUI:UpdateFloatingHUDState()
    if not self.currentTarget then
        if self.floatingPill then self.floatingPill:Hide() end
        return
    end
    if self.floatingPill then self.floatingPill:Show() end
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
