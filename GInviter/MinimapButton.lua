-- GInviter MinimapButton.lua
local addonName, addon = ...
GInviter = GInviter or {}
GInviter.MinimapButton = {}
local MB = GInviter.MinimapButton

function MB:Initialize()
    local button = CreateFrame("Button", "GInviterMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\ACHIEVEMENT_GUILDPERK_EVERYONE_IN")

    -- Border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    self.button = button

    -- Dragging Logic
    local isDragging = false
    button:SetScript("OnDragStart", function(s)
        isDragging = true
        s:SetScript("OnUpdate", function(self)
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local xmax, ymax = Minimap:GetRight(), Minimap:GetTop()
            local scale = Minimap:GetEffectiveScale()
            xpos, ypos = xpos/scale, ypos/scale
            local cx, cy = (xmin + xmax)/2, (ymin + ymax)/2
            local angle = math.atan2(ypos - cy, xpos - cx)
            local degrees = math.floor(math.deg(angle))
            if degrees < 0 then degrees = degrees + 360 end

            GInviter.Database:GetSettings().minimap.minimapPos = degrees
            MB:UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(s)
        isDragging = false
        s:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(s, btn)
        if btn == "LeftButton" then
            if GInviter.GUI then
                GInviter.GUI:Toggle()
            end
        elseif btn == "RightButton" then
            -- Quick scan trigger
            GInviter.WhoScanner:SendQuery("1-80")
        end
    end)

    button:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("GInviter", 0.2, 0.6, 1.0)
        GameTooltip:AddLine("Left-Click: Open Recruiter Dashboard", 1, 1, 1)
        GameTooltip:AddLine("Right-Click: Quick /who Scan", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(s)
        GameTooltip:Hide()
    end)

    self:UpdatePosition()
end

function MB:UpdatePosition()
    if not self.button then return end
    local settings = GInviter.Database:GetSettings()
    if settings.minimap and settings.minimap.hide then
        self.button:Hide()
        return
    else
        self.button:Show()
    end

    local angle = math.rad(settings.minimap.minimapPos or 220)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    
    local diagRadius = 103.13708498985
    local radius = 80

    if shape == "SQUARE" then
        x = math.max(-radius, math.min(radius, x * diagRadius))
        y = math.max(-radius, math.min(radius, y * diagRadius))
    else
        x = x * radius
        y = y * radius
    end

    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
