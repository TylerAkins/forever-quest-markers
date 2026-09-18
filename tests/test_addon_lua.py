#!/usr/bin/env python3
"""Lightweight checks for runtime Lua files."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA_FILES = [
    "Config.lua",
    "Eligibility.lua",
    "MapPins.lua",
    "AutoQuests.lua",
    "Core.lua",
    "Database/Metadata.lua",
    "Database/ForeverQuests.lua",
]


class AddonLuaTests(unittest.TestCase):
    def test_toc_load_order(self) -> None:
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("## Interface: 16001", toc)
        self.assertIn("## SavedVariables: ForeverQuestPinsDB_Settings", toc)
        self.assertNotIn("ForeverQuestPinsDB\n", toc)
        for name in LUA_FILES:
            self.assertIn(name.replace("/", "\\"), toc)

    def test_single_savedvariables_name(self) -> None:
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("ForeverQuestPinsDB_Settings", toc)
        forever = (ROOT / "Database" / "ForeverQuests.lua").read_text(encoding="utf-8")
        self.assertNotIn("ForeverQuestPinsDB_Settings", forever)

    def test_balanced_braces_and_addon_table(self) -> None:
        for rel in LUA_FILES:
            text = (ROOT / rel).read_text(encoding="utf-8")
            self.assertEqual(text.count("{"), text.count("}"), f"{rel} braces")
            self.assertEqual(text.count("("), text.count(")"), f"{rel} parens")
            self.assertIn("local ADDON_NAME, ns = ...", text)

    def test_eligibility_function_exists(self) -> None:
        text = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.IsQuestAvailable(questID, data)", text)
        self.assertIn("sourceQuestNumRequired", text)
        self.assertIn("function ns.HasQuestCompletionAPI()", text)
        self.assertIn("GetQuestsCompleted", text)
        self.assertIn("GetAllCompletedQuestIDs", text)
        self.assertIn("function ns.IsSourceSatisfied(questID)", text)
        self.assertIn("function ns.HasQuestGiver(data)", text)
        self.assertIn("Object-started prereqs", text)
        self.assertIn("The Venture Co.", text)
        self.assertIn("Supervisor Fizsprocket", text)

    def test_no_herebedragons_or_att_runtime_dep(self) -> None:
        combined = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in LUA_FILES)
        self.assertNotIn("HereBeDragons", combined)
        self.assertNotIn("LibStub", combined)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertNotIn("OptionalDeps", toc)
        self.assertNotIn("RequiredDeps", toc)

    def test_pins_prefer_blizzard_quest_icon(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        atlas_at = text.find('ICON_ATLAS = "QuestNormal"')
        gossip_at = text.find("Interface\\\\GossipFrame\\\\AvailableQuestIcon")
        fallback_at = text.find("Media\\\\QuestAvailable")
        self.assertNotEqual(atlas_at, -1)
        self.assertNotEqual(gossip_at, -1)
        self.assertNotEqual(fallback_at, -1)
        self.assertLess(atlas_at, gossip_at)
        self.assertLess(gossip_at, fallback_at)
        self.assertIn("tex:SetAtlas(name, false)", text)
        self.assertIn("pin:SetIgnoreParentScale(false)", text)
        self.assertIn("PIN_SIZE = 24", text)
        self.assertIn("TrySetFile(tex, ICON_GOSSIP)", text)
        self.assertIn("TrySetFile(tex, ICON_FALLBACK)", text)
        set_fn = text.find("local function SetPinTexture(pin)")
        gossip_try = text.find("TrySetFile(tex, ICON_GOSSIP)", set_fn)
        atlas_try = text.find("TrySetAtlas(tex, ICON_ATLAS)", set_fn)
        self.assertLess(gossip_try, atlas_try)
        self.assertIn("function AtlasLooksReal(name)", text)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertNotIn('CreateFrame("Frame"):CreateTexture()', config)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("Interface\\GossipFrame\\AvailableQuestIcon", toc)

    def test_seasonal_pins_are_opt_in(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.IsEventActive(eventID)", eligibility)
        self.assertIn('return false, "seasonal"', eligibility)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn("showSeasonal = false", config)
        self.assertIn('msg == "seasonal"', config)

    def test_pins_try_every_known_map_on_the_viewed_canvas(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn("local function CandidateMapIDs(viewedMapID, byMap)", text)
        self.assertIn("for mapID in pairs(byMap) do", text)

    def test_auto_quest_options(self) -> None:
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn("autoAccept = false", config)
        self.assertIn("autoTurnIn = false", config)
        self.assertIn('msg == "accept"', config)
        self.assertIn('msg == "turnin"', config)
        self.assertIn('CreateOptionCheckbox', config)
        auto = (ROOT / "AutoQuests.lua").read_text(encoding="utf-8")
        self.assertIn('"GOSSIP_SHOW"', auto)
        self.assertIn("NoteOfferedQuest", auto)
        self.assertIn("CaptureOfferContext", auto)
        self.assertIn("function TryAcceptDetail()", auto)
        self.assertIn("function TryChooseReward()", auto)
        self.assertIn("GetNumQuestChoices", auto)
        self.assertIn("if choices > 1 then", auto)
        self.assertIn("IsShiftKeyDown", auto)
        self.assertIn("AcceptQuest", auto)
        self.assertIn("GetQuestReward", auto)
        self.assertIn("ConfirmAcceptQuest", auto)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertLess(toc.find("AutoQuests.lua"), toc.find("Core.lua"))

    def test_debug_option_in_settings_panel(self) -> None:
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn("debug = false", config)
        self.assertIn("Debug tooltips", config)
        self.assertLess(config.find('"autoTurnIn"'), config.find("Debug tooltips"))
        self.assertIn('msg == "debug"', config)

    def test_tooltips_use_names_unless_debug(self) -> None:
        pins = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.GetNPCName(npcID)", eligibility)
        self.assertIn("function ns.PrefetchQuestInfo(questID, data)", eligibility)
        self.assertIn("RequestLoadQuestByID", eligibility)
        self.assertIn("function ns.OnQuestDataLoad(questID)", eligibility)
        self.assertIn("ns.GetNPCName(qg)", pins)
        self.assertIn("GameTooltip:AddLine(npcName, 1, 1, 1)", pins)
        debug_flag_at = pins.find("if debugOn then")
        quest_id_at = pins.find('GameTooltip:AddLine("Quest ID: "')
        self.assertNotEqual(debug_flag_at, -1)
        self.assertNotEqual(quest_id_at, -1)
        self.assertLess(debug_flag_at, quest_id_at)
        self.assertNotIn(
            'GameTooltip:AddLine("Quest giver NPC " .. tostring(qg), 0.8, 0.8, 0.8)',
            pins[:debug_flag_at],
        )
        core = (ROOT / "Core.lua").read_text(encoding="utf-8")
        self.assertIn("QUEST_DATA_LOAD", core)

    def test_pins_parent_to_map_canvas_not_viewport(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        get_canvas_fn = text.find("local function GetCanvas()")
        get_canvas_at = text.find("WorldMapFrame:GetCanvas", get_canvas_fn)
        child_at = text.find("scroll.Child", get_canvas_fn)
        detail_at = text.find("WorldMapDetailFrame", get_canvas_fn)
        self.assertNotEqual(get_canvas_at, -1)
        self.assertNotEqual(child_at, -1)
        self.assertNotEqual(detail_at, -1)
        self.assertLess(get_canvas_at, child_at)
        self.assertLess(child_at, detail_at)
        self.assertNotIn('lastStatus.parent = "ScrollContainer"', text)
        self.assertIn("EnumeratePinsByTemplate", text)
        self.assertIn("SetIgnoreParentScale(false)", text)
        self.assertIn("function GetCanvasScale(parent)", text)
        self.assertIn("function IsUsableCanvas(frame)", text)
        self.assertIn("function SameSpot(ax, ay, bx, by)", text)
        self.assertIn("SynchronizeDisplayState", text)
        self.assertIn("ProjectToViewedMap", text)
        self.assertIn("function RaisePin(pin, parent)", text)
        self.assertIn("function MapPins:RepositionAll()", text)
        self.assertIn("function ns.TryQuestGiverPosition(npcID, viewedMapID)", text)
        self.assertIn("function MapPins:SnapToQuestGivers()", text)
        self.assertIn("OnCanvasScaleChanged", text)
        self.assertIn("canvas-zero", text)
        self.assertIn("map-show-layout", text)

    def test_object_started_prereqs_and_morin_patrol(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("not in the log and its own source quests are met", eligibility)
        self.assertIn("function ns.InvalidateCompletionCache()", eligibility)
        pins = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn("PATROL_EXTRA", pins)
        self.assertIn("[2988]", pins)
        self.assertIn("LIVE_NEAR", pins)
        self.assertIn("function AtlasLooksReal(name)", pins)
        self.assertIn("paintedIDs", pins)
        self.assertNotIn("local liveX, liveY = ns.TryQuestGiverPosition", pins)
        self.assertNotIn("lastLive[npcID]", pins)
        self.assertIn('unit == "player"', pins)
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("data.isBreadcrumb", eligibility)
        self.assertIn("function ns.NoteOfferedQuest(questID)", eligibility)
        self.assertIn('return true, "npc-offered"', eligibility)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn('msg:match("^why%s+(%d+)$")', config)
        self.assertIn("function ns.PrintQuestWhy(questID)", config)
        self.assertIn('msg == "available"', config)
        self.assertIn("function ns.PrintAvailableOnMap()", config)
        db = (ROOT / "Database" / "ForeverQuests.lua").read_text(encoding="utf-8")
        self.assertIn("[749] = { mapID=1412, x=54.4, y=60.4, qg=2988", db)
        self.assertIn("[751] = { mapID=1412, x=53.8, y=48.3, sourceQuests={ 749 }", db)
        self.assertNotRegex(db, r"\[751\] = \{[^}]*qg=")
        self.assertIn("[764] = { mapID=1412, x=54.4, y=60.4, qg=2988, sourceQuests={ 751 }", db)
        self.assertIn("[765] = { mapID=1412, x=54.4, y=60.4, qg=2988, sourceQuests={ 751 }", db)
        self.assertIn("[788] = { mapID=1411, x=42, y=68.4, qg=3143, sourceQuests={ 4641 }", db)
        self.assertIn("[4641] = { mapID=1411, x=43.2, y=68.4, qg=10176", db)

    def test_release_workflow_has_versioned_and_latest(self) -> None:
        text = (ROOT / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
        self.assertIn('- "v*"', text)
        self.assertIn("branches:", text)
        self.assertIn("main", text)
        self.assertIn("versioned:", text)
        self.assertIn("latest:", text)
        self.assertIn("{package-name}-latest{classic}", text)
        self.assertIn('git tag -f latest', text)
        self.assertIn("gh release create latest", text)
        self.assertIn("uses: BigWigsMods/packager@v2", text)


if __name__ == "__main__":
    unittest.main()
