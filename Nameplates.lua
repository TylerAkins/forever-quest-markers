local ADDON_NAME, ns = ...

ns.Nameplates = ns.Nameplates or {}
local Nameplates = ns.Nameplates

local ICON_SIZE = 16
local NAME_OFFSET_X = -2
local NORMAL_ICON_ATLAS = "QuestNormal"
local TURNIN_ICON_ATLAS = "QuestTurnin"
local NORMAL_ICON_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QuestAvailable"
local TURNIN_ICON_FILE = "Interface\\GossipFrame\\ActiveQuestIcon"
local OBJECTIVE_ICON_FILE = "Interface\\QuestFrame\\UI-Quest-BulletPoint"
local QUEST_OBJECTIVE_LINE = (Enum and Enum.TooltipDataLineType
    and Enum.TooltipDataLineType.QuestObjective) or 8

local active = {}
local pool = {}

local function AcquireFrame()
    local frame = table.remove(pool)
    if frame then
        return frame
    end
    frame = CreateFrame("Frame")
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints(frame)
    return frame
end

local function ReleaseFrame(unit)
    local frame = active[unit]
    if not frame then
        return
    end
    active[unit] = nil
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(nil)
    pool[#pool + 1] = frame
end

local function AtlasExists(atlas)
    return C_Texture
        and type(C_Texture.GetAtlasInfo) == "function"
        and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function SetAtlasIcon(texture, atlas)
    return pcall(function()
        texture:SetAtlas(atlas, false)
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetAlpha(1)
        texture:Show()
    end)
end

local function SetFileIcon(texture, path)
    return pcall(function()
        texture:SetTexture(path)
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetAlpha(1)
        texture:Show()
    end)
end

local function PaintIcon(frame, state)
    local texture = frame.icon
    texture:Hide()
    if state == "accept" then
        if AtlasExists(NORMAL_ICON_ATLAS) and SetAtlasIcon(texture, NORMAL_ICON_ATLAS) then
            return true
        end
        return SetFileIcon(texture, NORMAL_ICON_FILE)
    end
    if state == "turnin" then
        if AtlasExists(TURNIN_ICON_ATLAS) and SetAtlasIcon(texture, TURNIN_ICON_ATLAS) then
            return true
        end
        return SetFileIcon(texture, TURNIN_ICON_FILE)
    end
    if state == "objective" then
        return SetFileIcon(texture, OBJECTIVE_ICON_FILE)
    end
    return false
end

-- Keep the icon at a consistent spot beside the health bar. Nameplates can show
-- the name above or inside the bar, so anchoring to the name text moves it.
local function AnchorToNameplate(frame, nameplate)
    frame:ClearAllPoints()
    local unitFrame = nameplate.UnitFrame
    local healthBar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
    if healthBar then
        frame:SetPoint("RIGHT", healthBar, "LEFT", NAME_OFFSET_X, 0)
    elseif unitFrame then
        frame:SetPoint("RIGHT", unitFrame, "LEFT", NAME_OFFSET_X, 0)
    else
        frame:SetPoint("RIGHT", nameplate, "LEFT", NAME_OFFSET_X, 0)
    end
end

function Nameplates:UpdateUnit(unit)
    if not unit then
        return
    end
    if not ns.GetOption("showNameplateIcons") then
        ReleaseFrame(unit)
        return
    end

    local guid = UnitGUID and UnitGUID(unit)
    local npcID = guid and ns.NpcIDFromGUID and ns.NpcIDFromGUID(guid)
    if not npcID then
        ReleaseFrame(unit)
        return
    end

    local tooltips = ns.NPCTooltips
    local state = tooltips and tooltips.GetNpcQuestState and tooltips:GetNpcQuestState(npcID, unit)
    if not state then
        ReleaseFrame(unit)
        return
    end

    local nameplate = C_NamePlate
        and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then
        ReleaseFrame(unit)
        return
    end

    local frame = active[unit] or AcquireFrame()
    active[unit] = frame
    frame:SetParent(nameplate)
    if frame.SetFrameLevel and nameplate.GetFrameLevel then
        frame:SetFrameLevel(nameplate:GetFrameLevel() + 5)
    end
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    AnchorToNameplate(frame, nameplate)
    if not PaintIcon(frame, state) then
        ReleaseFrame(unit)
        return
    end
    frame:Show()
end

function Nameplates:ReleaseUnit(unit)
    ReleaseFrame(unit)
end

function Nameplates:Clear()
    local units = {}
    for unit in pairs(active) do
        units[#units + 1] = unit
    end
    for i = 1, #units do
        ReleaseFrame(units[i])
    end
end

function Nameplates:RefreshAll()
    if not ns.GetOption("showNameplateIcons") then
        self:Clear()
        return
    end
    local getPlates = C_NamePlate and C_NamePlate.GetNamePlates
    if not getPlates then
        self:Clear()
        return
    end
    local plates = getPlates()
    if type(plates) ~= "table" then
        self:Clear()
        return
    end

    local seen = {}
    for i = 1, #plates do
        local plate = plates[i]
        local unit = plate
            and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        if unit then
            seen[unit] = true
            self:UpdateUnit(unit)
        end
    end

    local stale = {}
    for unit in pairs(active) do
        if not seen[unit] then
            stale[#stale + 1] = unit
        end
    end
    for i = 1, #stale do
        ReleaseFrame(stale[i])
    end
end

function Nameplates:Debug()
    local function SafeText(value)
        if value == nil then
            return "nil"
        end
        if issecretvalue and issecretvalue(value) then
            return "<secret>"
        end
        return tostring(value)
    end
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    print(("Forever Quest Pins nameplates: option=%s plates=%d"):format(
        tostring(ns.GetOption("showNameplateIcons")), #plates))
    for i = 1, #plates do
        local plate = plates[i]
        local unit = plate
            and (plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
        if unit then
            local guid = UnitGUID and UnitGUID(unit)
            local npcID = guid and ns.NpcIDFromGUID and ns.NpcIDFromGUID(guid)
            local state = npcID
                and ns.NPCTooltips
                and ns.NPCTooltips.GetNpcQuestState
                and ns.NPCTooltips:GetNpcQuestState(npcID, unit)
            local frame = active[unit]
            print(("  %s npc=%s state=%s frame=%s shown=%s"):format(
                tostring(unit), tostring(npcID), tostring(state),
                tostring(frame ~= nil),
                tostring(frame and frame:IsShown())))
            if C_TooltipInfo and C_TooltipInfo.GetUnit then
                local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
                if ok and type(data) == "table" and type(data.lines) == "table" then
                    local types = {}
                    for j = 1, #data.lines do
                        local line = data.lines[j]
                        types[#types + 1] = tostring(line.type)
                        if line.type == QUEST_OBJECTIVE_LINE then
                            local color = line.leftColor
                            local r, g, b
                            if color and color.GetRGB then
                                r, g, b = color:GetRGB()
                            else
                                r, g, b = color and color.r, color and color.g, color and color.b
                            end
                            print(("    objective: left=%s right=%s completed=%s fulfilled=%s required=%s color=%s,%s,%s"):format(
                                SafeText(line.leftText), SafeText(line.rightText),
                                SafeText(line.completed), SafeText(line.numFulfilled),
                                SafeText(line.numRequired), SafeText(r), SafeText(g), SafeText(b)))
                        end
                    end
                    print("    tooltip line types: " .. table.concat(types, ","))
                end
            end
        end
    end
end
