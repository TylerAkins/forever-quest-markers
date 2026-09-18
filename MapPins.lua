local ADDON_NAME, ns = ...

ns.MapPins = ns.MapPins or {}
local MapPins = ns.MapPins

-- Blizzard’s retail world-map / minimap available-quest bang, then the gossip
-- yellow !, then the bundled TGA only if neither client texture exists.
local ICON_ATLAS = "QuestNormal"
local ICON_GOSSIP = "Interface\\GossipFrame\\AvailableQuestIcon"
local ICON_FALLBACK = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAvailable"
local PIN_SIZE = 32
local LIVE_SNAP_GAP = 0.5

local pool = {}
local active = {}
local hoveredPin
local liveAccum = 0
local lastLive = {}
local lastStatus = {
    viewedMap = nil,
    count = 0,
    mode = "none",
    lastError = nil,
    icon = nil,
    parent = nil,
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

-- The map *art* frame, never the scroll viewport. Parenting to ScrollContainer
-- places pins in window-pixel space, so they drift when the map is resized,
-- zoomed, or reopened.
local function GetCanvas()
    lastStatus.parent = nil
    if not WorldMapFrame then
        return nil
    end
    if WorldMapFrame.GetCanvas then
        local canvas = WorldMapFrame:GetCanvas()
        if canvas then
            lastStatus.parent = "WorldMapFrame:GetCanvas"
            return canvas
        end
    end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll then
        if scroll.Child then
            lastStatus.parent = "ScrollContainer.Child"
            return scroll.Child
        end
        if scroll.GetCanvas then
            local canvas = scroll:GetCanvas()
            if canvas then
                lastStatus.parent = "ScrollContainer:GetCanvas"
                return canvas
            end
        end
    end
    if WorldMapDetailFrame then
        lastStatus.parent = "WorldMapDetailFrame"
        return WorldMapDetailFrame
    end
    if WorldMapButton then
        lastStatus.parent = "WorldMapButton"
        return WorldMapButton
    end
    if scroll then
        lastStatus.parent = "ScrollContainer"
        return scroll
    end
    lastStatus.parent = "WorldMapFrame"
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
    pin.nx = nil
    pin.ny = nil
    pin.live = nil
    pin.titleReady = nil
    pool[#pool + 1] = pin
end

function MapPins:Clear()
    if hoveredPin then
        hoveredPin = nil
    end
    for i = 1, #active do
        ReleasePin(active[i])
    end
    wipe(active)
    lastStatus.count = 0
end

local function QuestGiverID(data)
    if not data then
        return nil
    end
    if data.qg then
        return data.qg
    end
    if data.qgs then
        return data.qgs[1]
    end
    return nil
end

local function ShowTooltip(pin)
    if not pin.questID then
        return
    end
    hoveredPin = pin
    ns.PrefetchQuestInfo(pin.questID, pin.data)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    local title = ns.GetQuestTitle(pin.questID)
    local debugOn = ns.GetOption("debug")
    if title then
        GameTooltip:SetText(title, 1, 0.82, 0)
    elseif debugOn then
        GameTooltip:SetText("Quest " .. tostring(pin.questID), 1, 0.82, 0)
    else
        GameTooltip:SetText("Quest", 1, 0.82, 0)
    end
    local qg = QuestGiverID(pin.data)
    local npcName = qg and ns.GetNPCName(qg) or nil
    if npcName then
        GameTooltip:AddLine(npcName, 1, 1, 1)
    elseif debugOn and qg then
        GameTooltip:AddLine("Quest giver NPC " .. tostring(qg), 0.8, 0.8, 0.8)
    end
    if debugOn then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Debug", 0.4, 0.8, 1)
        GameTooltip:AddLine("Quest ID: " .. tostring(pin.questID), 0.6, 0.8, 1)
        if qg then
            GameTooltip:AddLine("NPC ID: " .. tostring(qg), 0.6, 0.8, 1)
        end
        GameTooltip:AddLine("reason: " .. tostring(pin.reason or "?"), 0.6, 0.8, 1)
        GameTooltip:AddLine("parent: " .. tostring(lastStatus.parent or "?"), 0.6, 0.8, 1)
        if pin.live then
            GameTooltip:AddLine("position: live NPC", 0.6, 0.8, 1)
        end
        local data = pin.data
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
        if pin.nx and pin.ny then
            GameTooltip:AddLine(("normalized %.3f, %.3f"):format(pin.nx, pin.ny), 0.6, 0.8, 1)
        end
    end
    GameTooltip:Show()
end

function MapPins:OnTitleLoaded(questID)
    if hoveredPin and hoveredPin.questID == questID then
        ShowTooltip(hoveredPin)
    end
end

local function CanvasOffsets(parent, nx, ny)
    if not parent or not nx or not ny or not parent.GetWidth then
        return nil, nil
    end
    local width = parent:GetWidth()
    local height = parent:GetHeight()
    if not width or not height or width < 1 or height < 1 then
        return nil, nil
    end
    -- SetPoint offsets are in the parent's unscaled space (same as Blizzard
    -- ApplyPinPosition with pin scale 1).
    return width * nx, -height * ny
end

local function ApplyPinPoint(pin, parent)
    parent = parent or pin:GetParent()
    local ox, oy = CanvasOffsets(parent, pin.nx, pin.ny)
    if not ox then
        return false
    end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", parent, "TOPLEFT", ox, oy)
    return true
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
        pin:SetScript("OnLeave", function(self)
            if hoveredPin == self then
                hoveredPin = nil
            end
            GameTooltip:Hide()
        end)
    end
    pin:SetParent(parent)
    pin:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 20)
    SetPinTexture(pin)
    return pin
end

local function PlacePin(parent, nx, ny, questID, data, reason, live)
    local ox, oy = CanvasOffsets(parent, nx, ny)
    if not ox then
        return false
    end
    local pin = AcquirePin(parent)
    pin.questID = questID
    pin.data = data
    pin.reason = reason
    pin.nx = nx
    pin.ny = ny
    pin.live = live and true or nil
    pin.titleReady = ns.GetQuestTitle(questID) and true or nil
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", parent, "TOPLEFT", ox, oy)
    pin:Show()
    active[#active + 1] = pin
    ns.PrefetchQuestInfo(questID, data)
    return true
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

local function NpcIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    return tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        or tonumber(guid:match("Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

local function MapPosFromVector(pos)
    if not pos then
        return nil, nil
    end
    if pos.GetXY then
        local x, y = pos:GetXY()
        if x and y then
            return x, y
        end
    end
    if pos.x and pos.y then
        return pos.x, pos.y
    end
    return nil, nil
end

local function UnitMapPosition(unit, mapID)
    if not unit or not mapID then
        return nil, nil
    end
    if UnitExists and not UnitExists(unit) then
        return nil, nil
    end
    if C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
        if ok then
            local x, y = MapPosFromVector(pos)
            if x and y and x > 0 and y > 0 then
                return x, y
            end
        end
    end
    if UnitPosition and C_Map and C_Map.GetMapPosFromWorldPos then
        local ok, posY, posX, _, instance = pcall(UnitPosition, unit)
        if ok and posX and posY then
            local world
            if CreateVector2D then
                world = CreateVector2D(posX, posY)
            end
            if world then
                local ok2, uiMapID, mapPos = pcall(C_Map.GetMapPosFromWorldPos, instance, world)
                if ok2 then
                    local x, y = MapPosFromVector(mapPos)
                    if x and (uiMapID == nil or uiMapID == mapID) then
                        return x, y
                    end
                end
            end
        end
    end
    return nil, nil
end

local function UnitMatchesNpc(unit, npcID)
    if not UnitGUID then
        return false
    end
    return NpcIDFromGUID(UnitGUID(unit)) == npcID
end

-- When a quest giver is on screen (target, mouseover, nameplate), put the pin
-- on the NPC instead of ATT's single static coordinate. Patrol NPCs such as
-- Morin Cloudstalker otherwise sit at the village end of their path.
function ns.TryQuestGiverPosition(npcID, viewedMapID)
    if not npcID or not viewedMapID then
        return nil, nil
    end
    local function remember(x, y)
        if x and y then
            lastLive[npcID] = { x = x, y = y, mapID = viewedMapID }
            return x, y
        end
        return nil, nil
    end
    local units = { "target", "focus", "mouseover", "npc", "questnpc" }
    for i = 1, #units do
        local unit = units[i]
        if UnitMatchesNpc(unit, npcID) then
            local x, y = remember(UnitMapPosition(unit, viewedMapID))
            if x then
                return x, y
            end
        end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if type(plates) == "table" then
            for i = 1, #plates do
                local plate = plates[i]
                local unit = plate and (plate.namePlateUnitToken or plate.unitToken)
                if unit and UnitMatchesNpc(unit, npcID) then
                    local x, y = remember(UnitMapPosition(unit, viewedMapID))
                    if x then
                        return x, y
                    end
                end
            end
        end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitMatchesNpc(unit, npcID) then
            local x, y = remember(UnitMapPosition(unit, viewedMapID))
            if x then
                return x, y
            end
        end
    end
    local saved = lastLive[npcID]
    if saved and saved.mapID == viewedMapID then
        return saved.x, saved.y
    end
    return nil, nil
end

function MapPins:SnapToQuestGivers()
    local viewedMapID = lastStatus.viewedMap
    local parent = GetCanvas()
    if not viewedMapID or not parent or #active == 0 then
        return
    end
    for i = 1, #active do
        local pin = active[i]
        local qg = QuestGiverID(pin.data)
        if qg then
            local x, y = ns.TryQuestGiverPosition(qg, viewedMapID)
            if x and y then
                pin.nx = x
                pin.ny = y
                pin.live = true
                ApplyPinPoint(pin, parent)
            end
        end
        if pin.questID and not pin.titleReady then
            local title = ns.GetQuestTitle(pin.questID)
            if title then
                pin.titleReady = true
                MapPins:OnTitleLoaded(pin.questID)
            end
        end
    end
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
    if (canvas:GetWidth() or 0) < 1 or (canvas:GetHeight() or 0) < 1 then
        lastStatus.lastError = "canvas-zero"
        lastStatus.mode = "canvas-zero"
        lastStatus.zeroRetries = (lastStatus.zeroRetries or 0) + 1
        if lastStatus.zeroRetries <= 8 and ns.RequestRefresh then
            ns.RequestRefresh("canvas-zero")
        end
        return
    end
    lastStatus.zeroRetries = 0

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
                            local qg = QuestGiverID(data)
                            local liveX, liveY = ns.TryQuestGiverPosition(qg, viewedMapID)
                            if liveX then
                                if PlacePin(canvas, liveX, liveY, questID, data, why, true) then
                                    painted = painted + 1
                                end
                            else
                                EachCoord(data, function(questMapID, x, y)
                                    local nx, ny = ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
                                    if nx and ny then
                                        if PlacePin(canvas, nx, ny, questID, data, why, false) then
                                            painted = painted + 1
                                        end
                                    end
                                end)
                            end
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

local function HookSize(frame, reason)
    if not frame or not frame.HookScript or frame.ForeverQuestPinsSizeHooked then
        return
    end
    frame.ForeverQuestPinsSizeHooked = true
    frame:HookScript("OnSizeChanged", function()
        ns.RequestRefresh(reason)
    end)
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
    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
            local canvas = GetCanvas()
            for i = 1, #active do
                ApplyPinPoint(active[i], canvas)
            end
        end)
    end
    WorldMapFrame:HookScript("OnShow", function()
        HookSize(GetCanvas(), "canvas-size")
        ns.RequestRefresh("map-show")
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                ns.RequestRefresh("map-show-layout")
            end)
        end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        MapPins:Clear()
    end)
    WorldMapFrame:HookScript("OnUpdate", function(_, elapsed)
        if #active == 0 then
            liveAccum = 0
            return
        end
        liveAccum = liveAccum + elapsed
        if liveAccum < LIVE_SNAP_GAP then
            return
        end
        liveAccum = 0
        MapPins:SnapToQuestGivers()
    end)
    HookSize(WorldMapFrame.ScrollContainer, "map-size")
    HookSize(WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child, "canvas-size")
    HookSize(WorldMapDetailFrame, "detail-size")
    local canvas = GetCanvas()
    if canvas then
        HookSize(canvas, "canvas-size")
    end
end
