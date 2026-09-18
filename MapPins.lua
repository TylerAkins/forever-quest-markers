local ADDON_NAME, ns = ...

ns.MapPins = ns.MapPins or {}
local MapPins = ns.MapPins

-- Blizzard’s retail world-map / minimap available-quest bang, then the gossip
-- yellow !, then the bundled TGA only if neither client texture exists.
local ICON_ATLAS = "QuestNormal"
local ICON_GOSSIP = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_FALLBACK = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAvailable"
local PIN_SIZE = 32

local pool = {}
local active = {}
local lastStatus = {
    viewedMap = nil,
    count = 0,
    mode = "none",
    lastError = nil,
    icon = nil,
}

local function Norm(x, y)
    if not x or not y then
        return nil, nil
    end
    if x > 1 or y > 1 then
        return x / 100, y / 100
    end
    return x, y
end

local function GetCanvas()
    if not WorldMapFrame then
        return nil
    end
    if WorldMapFrame.ScrollContainer then
        return WorldMapFrame.ScrollContainer.GetCanvas and WorldMapFrame.ScrollContainer:GetCanvas()
            or WorldMapFrame.ScrollContainer
    end
    if WorldMapDetailFrame then
        return WorldMapDetailFrame
    end
    return WorldMapFrame
end

function ns.GetViewedMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local mapID = WorldMapFrame:GetMapID()
        if mapID then
            return mapID
        end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
    return nil
end

-- Project ATT 0-100 coordinates onto the currently viewed UiMapID.
-- Needs C_Map.GetMapRectOnMap for continent / parent maps. If that API is
-- missing, pins only appear when the viewed map equals the quest map.
function ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
    local nx, ny = Norm(x, y)
    if not nx or not ny or not questMapID or not viewedMapID then
        return nil, nil
    end
    if questMapID == viewedMapID then
        return nx, ny
    end
    if not (C_Map and C_Map.GetMapRectOnMap) then
        return nil, nil
    end
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(questMapID, viewedMapID)
    if not minX or (minX == 0 and maxX == 0 and minY == 0 and maxY == 0) then
        return nil, nil
    end
    return minX + ((maxX - minX) * nx), minY + ((maxY - minY) * ny)
end

local function AtlasExists(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(name) ~= nil
    end
    -- No lookup API: try SetAtlas and keep it if it does not error.
    return true
end

local function TrySetAtlas(tex, name)
    if not tex.SetAtlas or not AtlasExists(name) then
        return false
    end
    local ok = pcall(function()
        tex:SetAtlas(name, true)
        tex:SetAllPoints()
    end)
    return ok and true or false
end

local function TrySetFile(tex, path)
    if not tex.SetTexture or not path then
        return false
    end
    local ok = pcall(function()
        if tex.SetTexCoord then
            tex:SetTexCoord(0, 1, 0, 1)
        end
        tex:SetTexture(path)
        tex:SetAllPoints()
    end)
    return ok and true or false
end

local function SetPinTexture(pin)
    local tex = pin.Texture
    if not tex then
        return
    end
    if TrySetAtlas(tex, ICON_ATLAS) then
        lastStatus.icon = "atlas:" .. ICON_ATLAS
        return
    end
    if TrySetFile(tex, ICON_GOSSIP) then
        lastStatus.icon = "texture:AvailableQuestIcon"
        return
    end
    if TrySetFile(tex, ICON_FALLBACK) then
        lastStatus.icon = "texture:QuestAvailable.tga"
        return
    end
    lastStatus.icon = "none"
end

local function ReleasePin(pin)
    pin:Hide()
    pin:ClearAllPoints()
    pin.questID = nil
    pin.data = nil
    pin.reason = nil
    pool[#pool + 1] = pin
end

function MapPins:Clear()
    for i = 1, #active do
        ReleasePin(active[i])
    end
    wipe(active)
    lastStatus.count = 0
end

local function ShowTooltip(pin)
    if not pin.questID then
        return
    end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    local title = ns.GetQuestTitle(pin.questID)
    GameTooltip:SetText(title or ("Quest " .. tostring(pin.questID)), 1, 0.82, 0)
    if not title then
        GameTooltip:AddLine("Quest #" .. tostring(pin.questID), 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Quest ID: " .. tostring(pin.questID), 0.7, 0.7, 0.7)
    end
    local data = pin.data
    if data then
        local qg = data.qg
        if not qg and data.qgs then
            qg = data.qgs[1]
        end
        if qg then
            GameTooltip:AddLine("Quest giver NPC " .. tostring(qg), 0.8, 0.8, 0.8)
        end
    end
    if ns.GetOption("debug") then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Debug", 0.4, 0.8, 1)
        GameTooltip:AddLine("reason: " .. tostring(pin.reason or "?"), 0.6, 0.8, 1)
        if data then
            if data.sourceQuests then
                local parts = {}
                for i = 1, #data.sourceQuests do
                    parts[i] = tostring(data.sourceQuests[i])
                end
                GameTooltip:AddLine("sourceQuests: " .. table.concat(parts, ", "), 0.6, 0.8, 1)
            end
            if data.faction then
                GameTooltip:AddLine("faction: " .. tostring(data.faction), 0.6, 0.8, 1)
            end
            if data.minLevel then
                GameTooltip:AddLine("minLevel: " .. tostring(data.minLevel), 0.6, 0.8, 1)
            end
            GameTooltip:AddLine(("map %s @ %.1f, %.1f"):format(tostring(data.mapID), data.x or 0, data.y or 0), 0.6, 0.8, 1)
        end
    end
    GameTooltip:Show()
end

local function AcquirePin(parent)
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Button", nil, parent)
        pin:SetSize(PIN_SIZE, PIN_SIZE)
        pin:RegisterForClicks("LeftButtonUp")
        pin.Texture = pin:CreateTexture(nil, "OVERLAY")
        pin.Texture:SetAllPoints()
        pin:SetScript("OnEnter", ShowTooltip)
        pin:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    pin:SetParent(parent)
    pin:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 20)
    SetPinTexture(pin)
    return pin
end

local function PlacePin(parent, nx, ny, questID, data, reason)
    local pin = AcquirePin(parent)
    pin.questID = questID
    pin.data = data
    pin.reason = reason
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", parent, "TOPLEFT", parent:GetWidth() * nx, -parent:GetHeight() * ny)
    pin:Show()
    active[#active + 1] = pin
end

local function CandidateMapIDs(viewedMapID, byMap)
    local maps = {}
    local seen = {}
    local function add(mapID)
        if mapID and not seen[mapID] then
            seen[mapID] = true
            maps[#maps + 1] = mapID
        end
    end
    add(viewedMapID)
    if C_Map and C_Map.GetMapChildrenInfo then
        local children = C_Map.GetMapChildrenInfo(viewedMapID, nil, true)
        if type(children) == "table" then
            for i = 1, #children do
                local info = children[i]
                local childID = type(info) == "table" and (info.mapID or info[1]) or info
                add(childID)
            end
        end
    end
    -- Continent / parent views: try every known quest map and let
    -- ProjectToViewedMap drop maps that do not belong on this canvas.
    if type(byMap) == "table" then
        for mapID in pairs(byMap) do
            add(mapID)
        end
    end
    return maps
end

local function EachCoord(data, fn)
    if data.coords then
        for i = 1, #data.coords do
            local coord = data.coords[i]
            fn(coord[3] or data.mapID, coord[1], coord[2])
        end
        return
    end
    fn(data.mapID, data.x, data.y)
end

function MapPins:GetStatus()
    return lastStatus
end

function MapPins:Refresh(reason)
    self:Clear()
    lastStatus.lastError = nil
    lastStatus.mode = "canvas"

    if not ns.GetOption("enabled") then
        lastStatus.mode = "disabled"
        return
    end
    if not WorldMapFrame or (WorldMapFrame.IsShown and not WorldMapFrame:IsShown()) then
        lastStatus.mode = "hidden"
        return
    end

    local viewedMapID = ns.GetViewedMapID()
    lastStatus.viewedMap = viewedMapID
    if not viewedMapID then
        lastStatus.lastError = "no-map-id"
        lastStatus.mode = "no-map"
        return
    end

    local canvas = GetCanvas()
    if not canvas or not canvas.GetWidth then
        lastStatus.lastError = "no-canvas"
        lastStatus.mode = "no-canvas"
        return
    end

    local byMap = ns.ByMap or {}
    local quests = ns.Quests or {}
    local painted = 0
    local seen = {}
    local maps = CandidateMapIDs(viewedMapID, byMap)

    for mapIndex = 1, #maps do
        local mapID = maps[mapIndex]
        local list = byMap[mapID]
        if list then
            for i = 1, #list do
                local questID = list[i]
                if not seen[questID] then
                    seen[questID] = true
                    local data = quests[questID]
                    if data then
                        local available, why = ns.IsQuestAvailable(questID, data)
                        if available then
                            EachCoord(data, function(questMapID, x, y)
                                local nx, ny = ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
                                if nx and ny then
                                    PlacePin(canvas, nx, ny, questID, data, why)
                                    painted = painted + 1
                                end
                            end)
                        elseif ns.GetOption("debug") and why == "low-level" then
                            -- Intentionally silent; /fqp debug is for tooltips of visible pins.
                        end
                    end
                end
            end
        end
    end

    lastStatus.count = painted
    lastStatus.mode = "canvas"
    if ns.GetOption("debug") and reason then
        -- Keep this cheap; stats are available via /fqp stats.
    end
end

function MapPins:HookMap()
    if self.hooked or not WorldMapFrame then
        return
    end
    self.hooked = true
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            ns.RequestRefresh("map-changed")
        end)
    end
    WorldMapFrame:HookScript("OnShow", function()
        ns.RequestRefresh("map-show")
    end)
    WorldMapFrame:HookScript("OnHide", function()
        MapPins:Clear()
    end)
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.HookScript then
        WorldMapFrame.ScrollContainer:HookScript("OnSizeChanged", function()
            ns.RequestRefresh("map-size")
        end)
    end
end
