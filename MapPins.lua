local ADDON_NAME, ns = ...

ns.MapPins = ns.MapPins or {}
local MapPins = ns.MapPins

-- Retail available-quest bang (same atlas as 0.1.1). Keep native size off so
-- the pin stays PIN_SIZE. Gossip AvailableQuestIcon is not used: it can bind
-- with no pixels and hide a working atlas. Bundled TGA only if SetAtlas errors.
local ICON_ATLAS = "QuestNormal"
local ICON_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAvailable"
local PIN_SIZE = 24
local LIVE_SNAP_GAP = 0.5
-- Normalized map units. Morin Cloudstalker's patrol is ~0.12 from village to crate.
local LIVE_NEAR = 0.20

-- Extra static ends of known patrols. ATT stores one coord (usually the village).
-- Morin Cloudstalker (2988) walks Bloodhoof 54.4,60.4 ↔ crate 53.8,48.3.
local PATROL_EXTRA = {
    [2988] = {
        { mapID = 1412, x = 53.8, y = 48.3 },
    },
}

local pool = {}
local active = {}
local hoveredPin
local liveAccum = 0
local canvasCache
local canvasCacheName
local lastStatus = {
    viewedMap = nil,
    count = 0,
    mode = "none",
    lastError = nil,
    icon = nil,
    parent = nil,
    paintedIDs = {},
}

local BLIZZARD_PIN_TEMPLATES = {
    "GroupMembersPinTemplate",
    "WorldMapUnitPinTemplate",
    "QuestPinTemplate",
    "AreaPOIPinTemplate",
    "DungeonEntrancePinTemplate",
    "FlightPointPinTemplate",
    "WaypointLocationPinTemplate",
    "MapHighlightPinTemplate",
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

local function InvalidateCanvas()
    canvasCache = nil
    canvasCacheName = nil
end

local function AcceptCanvas(frame, name)
    if not frame then
        return nil
    end
    lastStatus.parent = name
    if frame.GetWidth and (frame:GetWidth() or 0) >= 1 then
        canvasCache = frame
        canvasCacheName = name
    end
    return frame
end

-- Same parent Blizzard uses for the player arrow / quest pins. Never the
-- ScrollContainer viewport: that is window-pixel space and drifts on resize.
local function CanvasFromBlizzardPins()
    if not (WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate) then
        return nil
    end
    for i = 1, #BLIZZARD_PIN_TEMPLATES do
        local template = BLIZZARD_PIN_TEMPLATES[i]
        local found
        local ok = pcall(function()
            for pin in WorldMapFrame:EnumeratePinsByTemplate(template) do
                local parent = pin and pin.GetParent and pin:GetParent()
                if parent then
                    found = parent
                    break
                end
            end
        end)
        if ok and found then
            return AcceptCanvas(found, "blizzard:" .. template)
        end
    end
    return nil
end

local function IsUsableCanvas(frame)
    if not frame or not WorldMapFrame then
        return false
    end
    -- The map art, never the window or the scroll viewport. Those stretch with
    -- the quest-log layout so north-edge pins (A Sacred Burial) vanish unless
    -- the map is maximized.
    if frame == WorldMapFrame then
        return false
    end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll and frame == scroll and scroll.Child then
        return false
    end
    return true
end

local function GetCanvas()
    if canvasCache and canvasCache.GetWidth and (canvasCache:GetWidth() or 0) >= 1 and IsUsableCanvas(canvasCache) then
        lastStatus.parent = canvasCacheName
        return canvasCache
    end
    lastStatus.parent = nil
    if not WorldMapFrame then
        return nil
    end
    if WorldMapFrame.GetCanvas then
        local canvas = WorldMapFrame:GetCanvas()
        if IsUsableCanvas(canvas) then
            return AcceptCanvas(canvas, "WorldMapFrame:GetCanvas")
        end
    end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll then
        if IsUsableCanvas(scroll.Child) then
            return AcceptCanvas(scroll.Child, "ScrollContainer.Child")
        end
        if scroll.GetCanvas then
            local canvas = scroll:GetCanvas()
            if IsUsableCanvas(canvas) then
                return AcceptCanvas(canvas, "ScrollContainer:GetCanvas")
            end
        end
    end
    local blizzard = CanvasFromBlizzardPins()
    if blizzard and IsUsableCanvas(blizzard) then
        return blizzard
    end
    if IsUsableCanvas(WorldMapDetailFrame) then
        return AcceptCanvas(WorldMapDetailFrame, "WorldMapDetailFrame")
    end
    if IsUsableCanvas(WorldMapButton) then
        return AcceptCanvas(WorldMapButton, "WorldMapButton")
    end
    return nil
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

local function TrySetAtlas(tex, name)
    if not tex or not tex.SetAtlas or not name then
        return false
    end
    local ok = pcall(function()
        tex:SetAtlas(name, false)
        if tex.SetDrawLayer then
            tex:SetDrawLayer("OVERLAY", 7)
        end
        if tex.SetBlendMode then
            pcall(tex.SetBlendMode, tex, "BLEND")
        end
        if tex.SetVertexColor then
            tex:SetVertexColor(1, 1, 1, 1)
        end
        if tex.SetAlpha then
            tex:SetAlpha(1)
        end
        if tex.SetAllPoints then
            tex:SetAllPoints()
        end
        tex:Show()
    end)
    return ok and true or false
end

local function TrySetFile(tex, path)
    if not tex or not tex.SetTexture or not path then
        return false
    end
    local ok = pcall(function()
        if tex.SetDrawLayer then
            tex:SetDrawLayer("OVERLAY", 7)
        end
        if tex.SetBlendMode then
            pcall(tex.SetBlendMode, tex, "BLEND")
        end
        if tex.SetTexCoord then
            tex:SetTexCoord(0, 1, 0, 1)
        end
        tex:SetTexture(path)
        if tex.SetVertexColor then
            tex:SetVertexColor(1, 1, 1, 1)
        end
        if tex.SetAlpha then
            tex:SetAlpha(1)
        end
        if tex.SetAllPoints then
            tex:SetAllPoints()
        end
        tex:Show()
    end)
    return ok and true or false
end

local function SetPinTexture(pin)
    local tex = pin.Texture
    if not tex then
        lastStatus.icon = "none"
        return
    end
    if pin.Fill and pin.Fill.Hide then
        pin.Fill:Hide()
    end
    if TrySetAtlas(tex, ICON_ATLAS) then
        lastStatus.icon = "atlas:" .. ICON_ATLAS
        return
    end
    if TrySetFile(tex, ICON_FILE) or TrySetFile(tex, ICON_FILE .. ".tga") then
        lastStatus.icon = "QuestAvailable.tga"
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
    pin.attNx = nil
    pin.attNy = nil
    pin.live = nil
    pin.titleReady = nil
    pin.quests = nil
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
    lastStatus.paintedIDs = {}
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
    if not pin.questID and not (pin.quests and pin.quests[1]) then
        return
    end
    hoveredPin = pin
    local quests = pin.quests
    if not quests or #quests == 0 then
        quests = { { id = pin.questID, data = pin.data, reason = pin.reason } }
    end
    for i = 1, #quests do
        ns.PrefetchQuestInfo(quests[i].id, quests[i].data)
    end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    local debugOn = ns.GetOption("debug")
    local primaryTitle = ns.GetQuestTitle(quests[1].id)
    if primaryTitle then
        GameTooltip:SetText(primaryTitle, 1, 0.82, 0)
    elseif debugOn then
        GameTooltip:SetText("Quest " .. tostring(quests[1].id), 1, 0.82, 0)
    else
        GameTooltip:SetText("Quest", 1, 0.82, 0)
    end
    for i = 2, #quests do
        local extraTitle = ns.GetQuestTitle(quests[i].id)
        if extraTitle then
            GameTooltip:AddLine(extraTitle, 1, 0.82, 0)
        elseif debugOn then
            GameTooltip:AddLine("Quest " .. tostring(quests[i].id), 1, 0.82, 0)
        end
    end
    local qg = QuestGiverID(quests[1].data or pin.data)
    local npcName = qg and ns.GetNPCName(qg) or nil
    if npcName then
        GameTooltip:AddLine(npcName, 1, 1, 1)
    elseif debugOn and qg then
        GameTooltip:AddLine("Quest giver NPC " .. tostring(qg), 0.8, 0.8, 0.8)
    end
    if debugOn then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Debug", 0.4, 0.8, 1)
        for i = 1, #quests do
            GameTooltip:AddLine("Quest ID: " .. tostring(quests[i].id), 0.6, 0.8, 1)
        end
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
    if not hoveredPin then
        return
    end
    if hoveredPin.questID == questID then
        ShowTooltip(hoveredPin)
        return
    end
    local quests = hoveredPin.quests
    if quests then
        for i = 1, #quests do
            if quests[i].id == questID then
                ShowTooltip(hoveredPin)
                return
            end
        end
    end
end

local function IsNormalized(x, y)
    return x and y and x >= 0 and y >= 0 and x <= 1 and y <= 1 and not (x == 0 and y == 0)
end

local function GetCanvasScale(parent)
    if WorldMapFrame and WorldMapFrame.GetCanvasScale then
        local scale = WorldMapFrame:GetCanvasScale()
        if type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    if parent and parent.GetScale then
        local scale = parent:GetScale()
        if type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    return 1
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
    return width * nx, -height * ny
end

local function RaisePin(pin, parent)
    parent = parent or pin:GetParent()
    if pin.UseFrameLevelType then
        pcall(pin.UseFrameLevelType, pin, "PIN_FRAME_LEVEL_AREA_POI")
    end
    local base = 0
    if parent and parent.GetFrameLevel then
        base = parent:GetFrameLevel() or 0
    end
    -- Map detail layers sit well above the canvas default; +20 was under the art
    -- so some bangs disappeared depending on zoom/layer order.
    pin:SetFrameLevel(base + 400)
    -- Keep the pin on the canvas strata. HIGH pulled pins out of the map child
    -- and they stopped compositing on Forever's world map.
    if pin.SetFrameStrata and parent and parent.GetFrameStrata then
        local strata = parent:GetFrameStrata()
        if strata then
            pcall(pin.SetFrameStrata, pin, strata)
        end
    end
end

local function ApplyPinPoint(pin, parent)
    parent = parent or pin:GetParent() or GetCanvas()
    local ox, oy = CanvasOffsets(parent, pin.nx, pin.ny)
    if not ox then
        return false
    end
    if parent and pin.GetParent and pin:GetParent() ~= parent then
        pin:SetParent(parent)
    end
    -- Match MapCanvas ApplyPinPosition: pin scale counters canvas zoom so the
    -- bang stays PIN_SIZE on screen in both windowed and maximized layouts.
    local canvasScale = GetCanvasScale(parent)
    if pin.SetIgnoreParentScale then
        pin:SetIgnoreParentScale(false)
    end
    pin:SetScale(1 / canvasScale)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    local pinScale = pin.GetScale and pin:GetScale() or 1
    if not pinScale or pinScale == 0 then
        pinScale = 1
    end
    RaisePin(pin, parent)
    pin:SetAlpha(1)
    pin:Show()
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", parent, "TOPLEFT", ox / pinScale, oy / pinScale)
    return true
end

function MapPins:RepositionAll()
    local canvas = GetCanvas()
    for i = 1, #active do
        ApplyPinPoint(active[i], canvas)
    end
end

local function AcquirePin(parent)
    local pin = table.remove(pool)
    if not pin then
        pin = CreateFrame("Button", nil, parent)
        pin:RegisterForClicks("LeftButtonUp")
        if pin.EnableMouse then
            pin:EnableMouse(true)
        end
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
    if pin.SetIgnoreParentScale then
        pin:SetIgnoreParentScale(false)
    end
    pin:SetScale(1)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    RaisePin(pin, parent)
    SetPinTexture(pin)
    return pin
end

local function SameSpot(ax, ay, bx, by)
    if not ax or not ay or not bx or not by then
        return false
    end
    local dx = ax - bx
    local dy = ay - by
    return (dx * dx + dy * dy) < (0.002 * 0.002)
end

local function PlacePin(parent, nx, ny, questID, data, reason, live)
    for i = 1, #active do
        local existing = active[i]
        if SameSpot(existing.nx, existing.ny, nx, ny) then
            existing.quests = existing.quests or { { id = existing.questID, data = existing.data, reason = existing.reason } }
            existing.quests[#existing.quests + 1] = { id = questID, data = data, reason = reason }
            ns.PrefetchQuestInfo(questID, data)
            return true
        end
    end
    local pin = AcquirePin(parent)
    pin.questID = questID
    pin.data = data
    pin.reason = reason
    pin.nx = nx
    pin.ny = ny
    pin.attNx = nx
    pin.attNy = ny
    pin.live = live and true or nil
    pin.quests = { { id = questID, data = data, reason = reason } }
    pin.titleReady = ns.GetQuestTitle(questID) and true or nil
    ApplyPinPoint(pin, parent)
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
    local seen = {}
    local function emit(mapID, x, y)
        if not mapID or not x or not y then
            return
        end
        local key = tostring(mapID) .. ":" .. tostring(x) .. ":" .. tostring(y)
        if seen[key] then
            return
        end
        seen[key] = true
        fn(mapID, x, y)
    end
    if data.coords then
        for i = 1, #data.coords do
            local coord = data.coords[i]
            emit(coord[3] or data.mapID, coord[1], coord[2])
        end
    else
        emit(data.mapID, data.x, data.y)
    end
    local qg = QuestGiverID(data)
    local extras = qg and PATROL_EXTRA[qg]
    if extras then
        for i = 1, #extras do
            local extra = extras[i]
            emit(extra.mapID or data.mapID, extra.x, extra.y)
        end
    end
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
    -- GetPlayerMapPosition is player-only on retail-style clients. Using it for
    -- target/nameplate can return the player's point (or a dummy 0-1 value) and
    -- v0.1.4 then replaced Morin's ATT bang with that, so 764 vanished.
    if unit == "player" and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
        if ok then
            local x, y = MapPosFromVector(pos)
            if IsNormalized(x, y) then
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
                    if IsNormalized(x, y) then
                        if uiMapID == mapID then
                            return x, y
                        end
                        if uiMapID and ns.ProjectToViewedMap then
                            local nx, ny = ns.ProjectToViewedMap(uiMapID, x * 100, y * 100, mapID)
                            if nx and ny then
                                return nx, ny
                            end
                        end
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

-- Live snap only while the NPC is actually visible. Never reuse a stale last
-- position: that was replacing The Venture Co. (764) with a continent coord
-- that sat off the Mulgore map.
function ns.TryQuestGiverPosition(npcID, viewedMapID)
    if not npcID or not viewedMapID then
        return nil, nil
    end
    local units = { "target", "focus", "mouseover", "npc", "questnpc" }
    for i = 1, #units do
        local unit = units[i]
        if UnitMatchesNpc(unit, npcID) then
            local x, y = UnitMapPosition(unit, viewedMapID)
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
                    local x, y = UnitMapPosition(unit, viewedMapID)
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
            local x, y = UnitMapPosition(unit, viewedMapID)
            if x then
                return x, y
            end
        end
    end
    return nil, nil
end

local function Dist2(ax, ay, bx, by)
    if not ax or not ay or not bx or not by then
        return nil
    end
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function MapPins:SnapToQuestGivers()
    local viewedMapID = lastStatus.viewedMap
    local parent = GetCanvas()
    if not viewedMapID or not parent or #active == 0 then
        return
    end
    local liveByNpc = {}
    for i = 1, #active do
        local pin = active[i]
        local qg = QuestGiverID(pin.data)
        if qg and not liveByNpc[qg] then
            local x, y = ns.TryQuestGiverPosition(qg, viewedMapID)
            if x and y then
                liveByNpc[qg] = { x = x, y = y }
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
    local nearest = {}
    local nearLimit = LIVE_NEAR * LIVE_NEAR
    for i = 1, #active do
        local pin = active[i]
        local qg = QuestGiverID(pin.data)
        local live = qg and liveByNpc[qg]
        if live then
            local d2 = Dist2(pin.attNx or pin.nx, pin.attNy or pin.ny, live.x, live.y)
            if d2 and d2 <= nearLimit then
                local best = nearest[qg]
                if not best or d2 < best.d2 then
                    nearest[qg] = { pin = pin, d2 = d2 }
                end
            end
        end
    end
    local chosen = {}
    for qg, best in pairs(nearest) do
        chosen[best.pin] = liveByNpc[qg]
    end
    for i = 1, #active do
        local pin = active[i]
        local live = chosen[pin]
        if live then
            pin.nx = live.x
            pin.ny = live.y
            pin.live = true
            ApplyPinPoint(pin, parent)
        elseif pin.live then
            pin.nx = pin.attNx or pin.nx
            pin.ny = pin.attNy or pin.ny
            pin.live = nil
            ApplyPinPoint(pin, parent)
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
    lastStatus.paintedIDs = {}

    local byMap = ns.ByMap or {}
    local quests = ns.Quests or {}
    local painted = 0
    local seen = {}
    local maps = CandidateMapIDs(viewedMapID, byMap)

    local function consider(questID)
        if not questID or seen[questID] then
            return
        end
        seen[questID] = true
        local data = quests[questID]
        if not data then
            return
        end
        local available, why = ns.IsQuestAvailable(questID, data)
        if not available then
            return
        end
        EachCoord(data, function(questMapID, x, y)
            local nx, ny = ns.ProjectToViewedMap(questMapID, x, y, viewedMapID)
            if nx and ny then
                if PlacePin(canvas, nx, ny, questID, data, why, false) then
                    painted = painted + 1
                    lastStatus.paintedIDs[questID] = true
                end
            end
        end)
    end

    for mapIndex = 1, #maps do
        local mapID = maps[mapIndex]
        local list = byMap[mapID]
        if list then
            for i = 1, #list do
                consider(list[i])
            end
        end
    end
    if ns.offeredQuestIDs then
        for questID in pairs(ns.offeredQuestIDs) do
            consider(questID)
        end
    end

    lastStatus.count = painted
    lastStatus.mode = "canvas"
    if ns.GetOption("debug") and reason then
        -- Keep this cheap; stats are available via /fqp stats.
    end
end

local function HookSize(frame)
    if not frame or not frame.HookScript or frame.ForeverQuestPinsSizeHooked then
        return
    end
    frame.ForeverQuestPinsSizeHooked = true
    frame:HookScript("OnSizeChanged", function()
        InvalidateCanvas()
        MapPins:RepositionAll()
    end)
end

function MapPins:HookMap()
    if self.hooked or not WorldMapFrame then
        return
    end
    self.hooked = true
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            InvalidateCanvas()
            ns.RequestRefresh("map-changed")
        end)
    end
    if WorldMapFrame.OnCanvasScaleChanged then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
            InvalidateCanvas()
            MapPins:RepositionAll()
        end)
    end
    if WorldMapFrame.SynchronizeDisplayState then
        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", function()
            InvalidateCanvas()
            ns.RequestRefresh("map-display")
        end)
    end
    WorldMapFrame:HookScript("OnShow", function()
        InvalidateCanvas()
        HookSize(GetCanvas())
        ns.RequestRefresh("map-show")
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                InvalidateCanvas()
                ns.RequestRefresh("map-show-layout")
            end)
        end
    end)
    WorldMapFrame:HookScript("OnHide", function()
        InvalidateCanvas()
        MapPins:Clear()
    end)
    WorldMapFrame:HookScript("OnUpdate", function(_, elapsed)
        if #active == 0 then
            liveAccum = 0
            return
        end
        MapPins:RepositionAll()
        liveAccum = liveAccum + elapsed
        if liveAccum < LIVE_SNAP_GAP then
            return
        end
        liveAccum = 0
        MapPins:SnapToQuestGivers()
    end)
    HookSize(WorldMapFrame)
    HookSize(WorldMapFrame.ScrollContainer)
    HookSize(WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    HookSize(WorldMapDetailFrame)
    HookSize(GetCanvas())
end
