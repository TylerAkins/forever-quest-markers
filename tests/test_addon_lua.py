#!/usr/bin/env python3
"""Lightweight checks for runtime Lua files."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA_FILES = [
    "Config.lua",
    "WarEffort.lua",
    "Eligibility.lua",
    "NPCTooltips.lua",
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
        self.assertIn("## SavedVariables: ForeverQuestPinsDB, ForeverQuestPinsDB_Settings", toc)
        self.assertIn("## SavedVariablesPerCharacter: ForeverQuestPinsCharDB, ForeverQuestPinsCharacterSettings", toc)
        self.assertNotIn("LoadSavedVariablesFirst", toc)
        self.assertIn("## X-License: GPL-3.0-or-later", toc)
        self.assertIn("## X-Website: https://github.com/TylerAkins/forever-quest-markers", toc)
        self.assertIn("## X-Source: https://github.com/TylerAkins/forever-quest-markers", toc)
        self.assertIn("## X-Issues: https://github.com/TylerAkins/forever-quest-markers/issues", toc)
        for name in LUA_FILES:
            self.assertIn(name.replace("/", "\\"), toc)

    def test_player_docs_are_complete(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for heading in (
            "## Requirements",
            "## Features",
            "## Install",
            "## Settings",
            "## Commands",
            "## Beta limitations",
            "## Support",
            "## License",
        ):
            self.assertIn(heading, readme)
        self.assertIn("ForeverQuestPins", readme)
        self.assertIn("/fqp why", readme)
        self.assertIn("CVar mirror", readme)
        self.assertIn("1.60.1.69913", readme)
        self.assertIn("0.1.10–0.1.16", readme)
        self.assertIn("New users can ignore this", readme)
        self.assertIn("docs/DEVELOPMENT.md", readme)
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("## 0.1.18", changelog)
        self.assertIn("0.1.10–0.1.16", changelog)
        self.assertIn("## 0.1.17", changelog)
        self.assertIn("## 0.1.16", changelog)
        self.assertIn("## 0.1.15", changelog)
        self.assertIn("## 0.1.14", changelog)
        self.assertIn("## 0.1.13", changelog)
        self.assertIn("## 0.1.12", changelog)
        self.assertIn("## 0.1.11", changelog)
        self.assertIn("## 0.1.10", changelog)
        self.assertIn("## 0.1.9", changelog)
        self.assertIn("## 0.1.8", changelog)
        attribution = (ROOT / "ATTRIBUTION.md").read_text(encoding="utf-8")
        self.assertIn("All The Things", attribution)
        self.assertIn("GPLv3", attribution)
        development = (ROOT / "docs" / "DEVELOPMENT.md").read_text(encoding="utf-8")
        self.assertIn("## CurseForge", development)
        self.assertIn("## Releases", development)
        pkgmeta = (ROOT / ".pkgmeta").read_text(encoding="utf-8")
        self.assertNotIn("README.md", pkgmeta)
        self.assertNotIn("ATTRIBUTION.md", pkgmeta)
        self.assertIn("manual-changelog:", pkgmeta)
        self.assertIn("filename: RELEASE_NOTES.md", pkgmeta)
        self.assertIn("markup-type: markdown", pkgmeta)

    def test_single_savedvariables_name(self) -> None:
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("ForeverQuestPinsDB_Settings", toc)
        self.assertIn("ForeverQuestPinsCharacterSettings", toc)
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
        self.assertIn("function ns.HasRequiredSkill(requiredSkill)", text)
        self.assertIn('return false, "profession"', text)
        core = (ROOT / "Core.lua").read_text(encoding="utf-8")
        self.assertIn('"SKILL_LINES_CHANGED"', core)
        self.assertIn("ns.InvalidateProfessionCache()", core)

    def test_no_herebedragons_or_att_runtime_dep(self) -> None:
        combined = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in LUA_FILES)
        self.assertNotIn("HereBeDragons", combined)
        self.assertNotIn("LibStub", combined)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertNotIn("OptionalDeps", toc)
        self.assertNotIn("RequiredDeps", toc)

    def test_pins_use_normal_repeatable_and_attunement_icons(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn('NORMAL_ICON_ATLAS = "QuestNormal"', text)
        self.assertIn('REPEATABLE_ICON_ATLAS = "QuestDaily"', text)
        self.assertIn("tex:SetAtlas(name, false)", text)
        self.assertIn("tex:SetDesaturated(true)", text)
        self.assertIn("pcall(tex.SetDesaturated, tex, false)", text)
        self.assertIn("TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, 0.12, 0.72, 1.00)", text)
        self.assertIn("TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS, 1.00, 0.32, 0.08)", text)
        self.assertIn("Media\\\\QuestAvailable", text)
        self.assertIn("Media\\\\QuestRepeatable", text)
        self.assertIn("Media\\\\QuestAttunement", text)
        self.assertIn("pin:SetIgnoreParentScale(false)", text)
        self.assertIn("PIN_SIZE = 24", text)
        set_fn = text.find("local function SetPinTexture(pin)")
        next_fn = text.find("local function ReleasePin(pin)", set_fn)
        set_body = text[set_fn:next_fn]
        normal_atlas = set_body.find("TrySetAtlas(tex, NORMAL_ICON_ATLAS)")
        tinted_atlas = set_body.find("TrySetTintedAtlas(tex, NORMAL_ICON_ATLAS,")
        repeatable_atlas = set_body.find("TrySetAtlas(tex, REPEATABLE_ICON_ATLAS)")
        fallback_file = set_body.find("TrySetFile(tex, fallbackFile)")
        for position in (normal_atlas, tinted_atlas, fallback_file, repeatable_atlas):
            self.assertNotEqual(position, -1)
        self.assertLess(tinted_atlas, fallback_file)
        self.assertNotIn("TrySetFile(fill,", set_body)
        self.assertIn("EnsurePinTextures(pin)", text)
        self.assertIn('GameTooltip:AddLine("icon: " .. tostring(pin.icon or "?")', text)
        self.assertLess(fallback_file, repeatable_atlas)
        self.assertNotIn("PaintFill", text)
        self.assertNotIn("SetColorTexture", text)
        self.assertNotIn("ICON_GOSSIP", text)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertNotIn('CreateFrame("Frame"):CreateTexture()', config)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("Interface\\GossipFrame\\AvailableQuestIcon", toc)

    def test_repeatable_pins_are_blue_and_opt_out(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        pins = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn('return false, "repeatable"', eligibility)
        self.assertLess(
            eligibility.find('not ns.GetOption("showRepeatable")'),
            eligibility.find('return true, "npc-offered"'),
        )
        self.assertIn("showRepeatable = true", config)
        self.assertIn('msg == "repeatable"', config)
        self.assertIn('"showRepeatable"', config)
        self.assertIn("Show repeatable quest pins", config)
        self.assertIn("local function IsRepeatableOnly(pin)", pins)
        self.assertIn("if not data or not data.repeatable then", pins)
        self.assertIn("SetPinTexture(existing)", pins)

    def test_attunement_pins_are_orange_only_for_uniform_stacks(self) -> None:
        pins = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn("local function IsAttunementOnly(pin)", pins)
        self.assertIn("if not data or not (data.isAttunement or data.isInstanceQuest) then", pins)
        self.assertLess(pins.find("if attunement then"), pins.find("elseif repeatable then"))
        self.assertIn('pin.icon = "atlas:" .. NORMAL_ICON_ATLAS .. ":orange"', pins)

    def test_seasonal_pins_are_opt_in(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.IsEventActive(eventID)", eligibility)
        self.assertIn('return false, "seasonal"', eligibility)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn("showSeasonal = false", config)
        self.assertIn('msg == "seasonal"', config)

    def test_war_effort_pins_are_opt_out(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        war = (ROOT / "WarEffort.lua").read_text(encoding="utf-8")
        self.assertIn('return false, "war-effort"', eligibility)
        self.assertIn("showWarEffort = true", config)
        self.assertIn('msg == "wareffort"', config)
        self.assertIn("function ns.IsWarEffortQuest(questID, data)", war)
        self.assertIn("[15459]", war)

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
        self.assertIn("function ns.InitSettings()", config)
        self.assertIn("function ns.WipeSettings()", config)
        self.assertIn('local MIRROR_CVAR = "ForeverQuestPinsSettings"', config)
        self.assertIn('type(C_CVar.RegisterCVar) == "function"', config)
        self.assertIn("DecodeMirror()", config)
        self.assertIn("SaveMirror(db)", config)
        self.assertIn('"revision=" .. tostring(Revision(db))', config)
        self.assertIn("ForeverQuestPinsCharacterSettings", config)
        self.assertIn("local function ChooseSettings(account, character, legacyAccount, legacyCharacter, mirror)", config)
        self.assertIn("CopySettings(db, ForeverQuestPinsDB,", config)
        self.assertIn("CopySettings(db, ForeverQuestPinsCharDB,", config)
        self.assertIn("CopySettings(db, ForeverQuestPinsDB_Settings", config)
        self.assertIn("CopySettings(db, ForeverQuestPinsCharacterSettings", config)
        self.assertNotIn("sessionScratch", config)
        self.assertNotIn("allowCreateSettings", config)
        self.assertNotIn("ApplyDirty", config)
        self.assertNotIn("BindSavedTable", config)
        self.assertNotIn("SyncPersistedOptions", config)
        self.assertNotIn("function ns.ResolveSettings()", config)
        self.assertIn("function ns.FlushSettings()", config)
        self.assertIn('msg == "wipe"', config)
        self.assertIn("ForeverQuestPinsDB_Settings", config)
        self.assertIn("ns.db = account", config)
        self.assertNotIn("function ns.HydrateSettings()", config)
        self.assertNotIn("function ns.EnsureSettingsDB(", config)
        self.assertNotIn("RegisterProxySetting", config)
        self.assertNotIn("RegisterAddOnSetting", config)
        self.assertNotIn("RegisterVerticalLayoutCategory", config)
        self.assertIn("RegisterCanvasLayoutCategory", config)
        self.assertIn("local value = not ns.GetOption(optionKey)", config)
        self.assertIn('msg == "settings"', config)
        self.assertIn("function ns.PrintSettingsDebug()", config)
        self.assertIn("ns.settingsMode", config)
        core = (ROOT / "Core.lua").read_text(encoding="utf-8")
        loaded_at = core.find('if event == "ADDON_LOADED" then')
        loaded_end = core.find('if event == "QUEST_DATA_LOAD" then', loaded_at)
        loaded = core[loaded_at:loaded_end]
        self.assertIn("ns.InitSettings()", loaded)
        self.assertIn("ns.TryRegisterSettings()", loaded)
        login_at = core.find('if event == "PLAYER_LOGIN" then')
        login_end = core.find('if event == "PLAYER_ENTERING_WORLD" then', login_at)
        login = core[login_at:login_end]
        self.assertNotIn("ns.InitSettings", login)
        pew_at = core.find('if event == "PLAYER_ENTERING_WORLD" then')
        pew_end = core.find("ns.RequestRefresh(event)", pew_at)
        pew = core[pew_at:pew_end]
        self.assertNotIn("ns.InitSettings", pew)
        self.assertNotIn("ns.allowCreateSettings", core)
        self.assertIn('"PLAYER_LOGOUT"', core)
        self.assertIn("ns.FlushSettings()", core)

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
        self.assertIn("function ns.GetQuestDifficultyLevel(questID)", eligibility)
        self.assertIn("GetQuestDifficultyLevel", eligibility)
        self.assertIn("function ns.GetQuestDifficultyRGB(level)", eligibility)
        self.assertIn('return ("[%d] %s"):format(level, title), level', pins)
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

    def test_release_workflow_has_versioned_and_preview_artifact(self) -> None:
        text = (ROOT / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
        self.assertIn('- "v*"', text)
        self.assertIn("branches:", text)
        self.assertIn("main", text)
        self.assertIn("versioned:", text)
        self.assertIn("auto-versioned:", text)
        self.assertIn("preview:", text)
        self.assertIn("VERSION ${VERSION} does not match tag", text)
        self.assertIn("python3 tools/att_release.py validate", text)
        self.assertIn("--release-content-changed", text)
        self.assertIn("ForeverQuestPins.toc", text)
        self.assertIn("needs: preview", text)
        self.assertIn("python3 tools/att_release.py validate-tag", text)
        self.assertIn('git push origin "refs/tags/${RELEASE_TAG}"', text)
        self.assertIn('gh workflow run release.yml --ref "$RELEASE_TAG"', text)
        self.assertIn('gh release view "$RELEASE_TAG"', text)
        self.assertIn("{package-name}-preview{classic}", text)
        self.assertIn("uses: actions/upload-artifact@v7", text)
        self.assertIn("path: .release/ForeverQuestPins-preview*.zip", text)
        self.assertIn("include-hidden-files: true", text)
        self.assertNotIn("{package-name}-latest{classic}", text)
        self.assertNotIn("git tag -f latest", text)
        self.assertNotIn("gh release create latest", text)
        self.assertIn("uses: BigWigsMods/packager@v2", text)

    def test_att_update_workflow_prepares_release_only_for_quest_changes(self) -> None:
        text = (ROOT / ".github" / "workflows" / "update-att-db.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("git diff --quiet -- Database/ForeverQuests.lua", text)
        self.assertIn("python3 tools/att_release.py prepare", text)
        self.assertIn("steps.changes.outputs.quest_data == 'true'", text)
        self.assertIn("VERSION", text)
        self.assertIn("CHANGELOG.md", text)
        self.assertIn("RELEASE_NOTES.md", text)
        self.assertIn("automatically publishes", text)

        ci = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        self.assertIn("Validate automated release intent", ci)
        self.assertIn("github.event.pull_request.base.sha", ci)
        self.assertIn("python3 tools/att_release.py validate", ci)
        self.assertIn("--release-content-changed", ci)

    def test_forever_interface_workflow_is_reviewed_and_weekly(self) -> None:
        text = (
            ROOT / ".github" / "workflows" / "update-forever-interface.yml"
        ).read_text(encoding="utf-8")
        self.assertIn('cron: "0 12 * * 3"', text)
        self.assertIn("from tools.update_forever_interface import VERSIONS_URL", text)
        updater = (ROOT / "tools" / "update_forever_interface.py").read_text(
            encoding="utf-8"
        )
        self.assertIn("wow_classic_beta/versions", updater)
        self.assertIn("github.ref == 'refs/heads/main'", text)
        self.assertIn("python3 tools/update_forever_interface.py", text)
        self.assertIn("branch: forever-interface-update", text)
        self.assertIn("steps.update.outputs.changed == 'true'", text)
        self.assertIn("steps.update.outputs.changed == 'false'", text)
        self.assertIn("--delete-branch", text)
        self.assertIn("ForeverQuestPins.toc", text)
        self.assertIn("VERSION", text)
        self.assertIn("CHANGELOG.md", text)
        self.assertIn("RELEASE_NOTES.md", text)


if __name__ == "__main__":
    unittest.main()
