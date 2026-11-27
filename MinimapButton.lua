local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Match the LibDBIcon minimap button used by Forever addons. The button is a
-- child of Minimap, so it follows the minimap's position and scale.

local BUTTON_SIZE = 31
local BORDER_SIZE = 50
local BACKGROUND_SIZE = 24
local ICON_SIZE = 18
local ICON_TEXTURE = "Interface\\GossipFrame\\AvailableQuestIcon"
local TRACKING_BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local TRACKING_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local DEFAULT_ANGLE = 200

local button

local function NormalizeAngle(angle)
    if type(angle) ~= "number" or angle ~= angle then
        angle = DEFAULT_ANGLE
    end
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end
    return angle
end

local function GetAngle()
    local db = ns.db
    if type(db) == "table" then
        return NormalizeAngle(db.minimapButtonPosition)
    end
    return DEFAULT_ANGLE
end

local function SetAngle(angle)
    local db = ns.db
    if type(db) == "table" then
        db.minimapButtonPosition = NormalizeAngle(angle)
    end
end

local function PlaceButton(angle)
    if not button or not Minimap then
        return
    end
    local radius = (Minimap:GetWidth() / 2) + 5
    local radians = NormalizeAngle(angle) * math.pi / 180
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * radius, math.sin(radians) * radius)
end

local function ShowTooltip(self)
    if not GameTooltip then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Forever Quest Pins", 1, 0.82, 0)
    GameTooltip:AddLine(L["Left-click: Quest Finder"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: addon settings"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag to move around the minimap."], 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function CreateButton()
    if button or not Minimap or not CreateFrame then
        return
    end
    local btn = CreateFrame("Button", "ForeverQuestPinsMinimapButton", Minimap)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(9)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local disc = btn:CreateTexture(nil, "BACKGROUND")
    disc:SetSize(BACKGROUND_SIZE, BACKGROUND_SIZE)
    disc:SetPoint("CENTER")
    disc:SetTexture(TRACKING_BACKGROUND)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON_TEXTURE)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(BORDER_SIZE, BORDER_SIZE)
    border:SetTexture(TRACKING_BORDER)
    border:SetPoint("TOPLEFT")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if ns.OpenSettings then
                ns.OpenSettings()
            end
        elseif ns.ShowQuestFinder then
            ns.ShowQuestFinder()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local angle = GetAngle()
        if ns.SetOption then
            ns.SetOption("minimapButtonPosition", angle)
        else
            SetAngle(angle)
        end
        PlaceButton(angle)
    end)
    btn:SetScript("OnUpdate", function(self)
        if not self.isDragging then
            return
        end
        local centerX, centerY = Minimap:GetCenter()
        local cursorX, cursorY = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cursorX, cursorY = cursorX / scale, cursorY / scale
        local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
        local angle = math.deg(atan2(cursorY - centerY, cursorX - centerX))
        SetAngle(angle)
        PlaceButton(angle)
    end)
    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", function()
            PlaceButton(GetAngle())
        end)
    end

    button = btn
    PlaceButton(GetAngle())
end

function ns.RefreshMinimapButton()
    if not ns.db then
        return
    end
    if not button then
        CreateButton()
    end
    if not button then
        return
    end
    if ns.GetOption and ns.GetOption("showMinimapButton") == false then
        button:Hide()
    else
        PlaceButton(GetAngle())
        button:Show()
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    ns.RefreshMinimapButton()
end)
