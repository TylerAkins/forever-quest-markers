local cases = {}
cases["eligibility_runtime.test_completed_id_list_wins_over_account_completion"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return { [1] = 3090 } end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsQuestFlaggedCompletedOnAccount = function()
                error('account completion must not be consulted')
            end
            assert(ns.IsQuestFlaggedCompleted(3090) == true)
            assert(ns.IsQuestFlaggedCompleted(2953) == false)

end
cases["eligibility_runtime.test_empty_completed_id_list_is_authoritative"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return true end
            assert(ns.IsQuestFlaggedCompleted(2953) == false)

end
cases["eligibility_runtime.test_session_turn_in_hides_pin_when_completed_list_lags"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            local available = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == true)
            ns.NoteQuestCompleted(2953)
            ns.InvalidateCompletionCache()
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            available, reason = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == false and reason == 'completed')

end
cases["eligibility_runtime.test_session_accept_hides_offered_pin_when_log_lags"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            ns.NoteOfferedQuest(92499)
            local available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == true and reason == 'npc-offered')
            ns.NoteQuestAccepted(92499)
            assert(ns.IsOffered(92499) == false)
            assert(ns.IsOnQuest(92499) == true)
            available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == false and reason == 'in-log')
            ns.NoteQuestRemoved(92499)
            assert(ns.IsOnQuest(92499) == false)

end
cases["eligibility_runtime.test_legacy_completed_list_and_single_quest_fallback"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            GetQuestsCompleted = function()
                return { [2953] = true, [2966] = 1, [2970] = 2970 }
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(2966) == true)
            assert(ns.IsQuestFlaggedCompleted(2970) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)

end
cases["eligibility_runtime.test_single_quest_api_is_used_only_without_a_completed_list"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            C_QuestLog.IsQuestFlaggedCompleted = function(questID)
                return questID == 2953
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)

end
cases["eligibility_runtime.test_trivial_pins_hidden_when_nine_or_more_levels_below_player"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 21 })
            assert(available == false and reason == 'trivial')
            available, reason = ns.IsQuestAvailable(2, { minLevel = 22 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')

end
cases["eligibility_runtime.test_trivial_pins_use_client_quest_level_without_db_min_level"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 20 end
            UnitFactionGroup = function() return 'Horde' end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.GetQuestDifficultyLevel = function(questID)
                return questID == 8 and 5 or nil
            end
            local available, reason = ns.IsQuestAvailable(8, { faction = 'Horde' })
            assert(available == false and reason == 'trivial')

end
cases["eligibility_runtime.test_trivial_gap_uses_configured_option"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 5 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 25 })
            assert(available == false and reason == 'trivial')
            available = ns.IsQuestAvailable(2, { minLevel = 26 })
            assert(available == true)

end
cases["eligibility_runtime.book_quests_ignore_other_category_options"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("Database/BookQuests.lua"))("ForeverQuestPins", ns)

            local options = {
                showBooks = true, showNormal = false, showClass = false,
                showProfession = false, showDungeon = false, showPvP = false,
                showRepeatable = false, showSeasonal = false, showWarEffort = false,
            }
            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                if key == 'showTrivial' then return true end
                return options[key]
            end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            UnitLevel = function() return 60 end
            local available, reason = ns.IsQuestAvailable(78124, { minLevel = 1 })
            assert(available == true, reason)
            available, reason = ns.IsQuestAvailable(2, { minLevel = 1 })
            assert(available == false and reason == 'category-hidden')
            options.showBooks = false
            available, reason = ns.IsQuestAvailable(78124, { minLevel = 1 })
            assert(available == false and reason == 'book')

end
cases["eligibility_runtime.test_hidden_quest_is_unavailable_even_when_offered"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function() return true end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            ns.IsQuestHidden = function(questID) return questID == 5 end
            ns.NoteOfferedQuest(5)
            local available, reason = ns.IsQuestAvailable(5, { minLevel = 1 })
            assert(available == false and reason == 'user-hidden')
            available, reason = ns.IsQuestAvailable(6, { minLevel = 1 })
            assert(available == true)

end
cases["eligibility_runtime.test_trivial_pins_shown_when_option_enabled"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.GetOption = function(key) return key == 'showTrivial' and true or nil end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 1 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')

end
cases["eligibility_runtime.test_secret_unit_guid_does_not_crash_offer_capture"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local secretGuid = 'Creature-0-0-0-0-3139-0000000000'
            issecretvalue = function(value) return value == secretGuid end
            UnitGUID = function(unit)
                if unit == 'npc' then return secretGuid end
            end
            C_Map = {
                GetBestMapForUnit = function() return 1 end,
                GetPlayerMapPosition = function()
                    return { x = 0.5, y = 0.25 }
                end,
            }
            ns.CaptureOfferContext()
            assert(ns.lastOffer ~= nil)
            assert(ns.lastOffer.qg == nil)
            assert(ns.lastOffer.mapID == 1)
            assert(ns.lastOffer.x == 50)
            assert(ns.lastOffer.y == 25)

            issecretvalue = function() return false end
            assert(ns.NpcIDFromGUID('Creature-0-0-0-0-3139-0000000000') == 3139)
            assert(ns.NpcIDFromGUID('Vehicle-0-0-0-0-417-0000000000') == 417)

end
cases["eligibility_runtime.test_secret_npc_name_is_ignored_without_being_cached"] = function()
ns = {}; C_QuestLog = {}
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local secretName = 'secret npc name'
            issecretvalue = function(value) return value == secretName end
            C_TooltipInfo = {
                GetHyperlink = function()
                    return { lines = { { leftText = secretName } } }
                end,
            }
            assert(ns.GetNPCName(3139) == nil)

            C_TooltipInfo.GetHyperlink = function()
                return { lines = { { leftText = "Gar'Thok" } } }
            end
            assert(ns.GetNPCName(3139) == "Gar'Thok")

end
cases["pin_filters_runtime.test_category_defaults_and_saved_false_values"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            for _, key in ipairs({ "showNormal", "showClass", "showProfession", "showDungeon" }) do
                assert(ns.GetOption(key) == true)
                ns.SetOption(key, false)
            end
            ns.db = nil
            ns.InitSettings()
            for _, key in ipairs({ "showNormal", "showClass", "showProfession", "showDungeon" }) do
                assert(ns.GetOption(key) == false)
            end

end
cases["pin_filters_runtime.test_category_filters_apply_to_offered_quests_and_preserve_other_categories"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.IsOffered = function() return true end
            local examples = {
                { "showNormal", {} },
                { "showClass", { classes = { 1 } } },
                { "showProfession", { requireSkill = 164 } },
                { "showDungeon", { isInstanceQuest = true } },
                { "showPvP", { isPvPQuest = true } },
            }
            for _, example in ipairs(examples) do
                if example[1] == "showPvP" then
                    ns.SetOption("showPvP", true)
                end
                assert(ns.IsQuestAvailable(101, example[2]))
                ns.SetOption(example[1], false)
                local available, reason = ns.IsQuestAvailable(101, example[2])
                assert(not available and reason == "category-hidden")
                ns.SetOption(example[1], true)
            end
            ns.QuestTagCorrections = { [102] = 81 }
            assert(ns.IsQuestAvailable(102, {}))
            ns.SetOption("showDungeon", false)
            local available, reason = ns.IsQuestAvailable(102, {})
            assert(not available and reason == "category-hidden")
            ns.SetOption("showDungeon", true)
            ns.QuestTagCorrections = nil
            ns.InvalidateInstanceQuestCache()
            C_QuestLog.GetQuestTagInfo = function(questID)
                if questID == 103 then
                    return { tagID = 81, tagName = "Dungeon" }
                end
            end
            assert(ns.IsInstanceQuest(103, {}))
            C_QuestLog.GetQuestTagInfo = nil
            ns.InvalidateInstanceQuestCache()
            ns.QuestTagCorrections = { [104] = 41 }
            ns.SetOption("showPvP", false)
            assert(not ns.IsQuestAvailable(104, {}))
            ns.SetOption("showPvP", true)
            assert(ns.IsQuestAvailable(104, {}))
            ns.SetOption("showPvP", false)
            ns.QuestTagCorrections = nil
            ns.InvalidatePvPQuestCache()
            ns.ExcludedQuests = { [105] = true }
            local excludedAvailable, excludedReason = ns.IsQuestAvailable(105, {})
            assert(not excludedAvailable and excludedReason == "excluded")
            ns.ExcludedQuests = nil
            C_QuestLog.GetQuestTagInfo = function(questID)
                if questID == 106 then
                    return { tagID = 41, tagName = "PvP" }
                end
            end
            assert(ns.IsPvPQuest(106, {}))
            C_QuestLog.GetQuestTagInfo = nil
            ns.InvalidatePvPQuestCache()
            ns.SetOption("showNormal", false)
            for _, data in ipairs({ { repeatable = true }, { event = 1 },
                { isYearly = true }, { classes = { 1 } }, { requireSkill = 164 },
                { isInstanceQuest = true } }) do
                assert(ns.IsQuestAvailable(101, data))
            end
            ns.SetOption("showClass", false)
            assert(ns.IsQuestAvailable(101, { classes = { 1 }, isInstanceQuest = true }))
            ns.SetOption("showProfession", false)
            ns.SetOption("showClass", true)
            assert(ns.IsQuestAvailable(101, { classes = { 1 }, requireSkill = 164 }))

end
cases["pin_filters_runtime.map_filters_register_with_blizzard_tracking_menu"] = function()
    ns = {}
    print = function() end
    local registered
    Menu = {
        ModifyMenu = function(menu, callback)
            registered = { menu = menu, callback = callback }
        end,
    }
    MenuUtil = {
        CreateCheckbox = function(label, getter, setter)
            return {
                label = label,
                getter = getter,
                setter = setter,
                SetEnabled = function() end,
            }
        end,
    }
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.GetOption = function(key) return key ~= "showPvP" end
    ns.SetOption = function() end
    assert(ns.TryRegisterWorldMapDropdown())
    assert(registered and registered.menu == "MENU_WORLD_MAP_TRACKING",
        "pin filters must live in Blizzard's world map tracking menu")

    local inserted = {}
    local root = {
        CreateDivider = function() end,
        CreateTitle = function() end,
        Insert = function(_, button) inserted[#inserted + 1] = button end,
    }
    registered.callback(nil, root)
    assert(#inserted == 14, "the menu keeps the full filter set")
    local labels = {}
    for i = 1, #inserted do labels[inserted[i].label] = true end
    for _, label in ipairs({
        "Quest start",
        "Dungeon / raid quest",
        "Collectible book quest",
        "Click pins to track quest starts",
    }) do
        assert(labels[label], "missing filter: " .. label)
    end
end

cases["pin_filters_runtime.test_options_category_controls_disable_without_losing_selections"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local controls = {}
            local function newRegion()
                return setmetatable({ SetAlpha = function(self, value) self.alpha = value end },
                    { __index = function() return function() end end })
            end
            CreateFrame = function(kind)
                local frame = { built = false, shown = true, scripts = {}, Text = newRegion(), Low = newRegion(), High = newRegion() }
                frame.SetSize = function(self, width, height) self.width, self.height = width, height end
                frame.SetScript = function(self, name, callback) self.scripts[name] = callback end
                frame.GetScript = function(self, name) return self.scripts[name] end
                frame.SetEnabled = function(self, value) self.enabled = value end
                frame.SetChecked = function(self, value) self.checked = value end
                frame.Hide = function(self) self.shown = false end
                frame.Show = function(self)
                    local wasShown = self.shown
                    self.shown = true
                    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
                end
                frame.CreateFontString = function() return newRegion() end
                frame.CreateTexture = function() return newRegion() end
                setmetatable(frame, { __index = function() return function() end end })
                table.insert(controls, frame)
                return frame
            end
            Settings = {
                RegisterCanvasLayoutCategory = function() return {} end,
                RegisterCanvasLayoutSubcategory = function() return {} end,
                RegisterAddOnCategory = function() end,
            }
            assert(ns.TryRegisterSettings())
            controls[1]:Show()
            controls[2]:Show()
            controls[5]:Show()
            assert(controls[1].built, "settings controls must be built on first selection")
            local levelFilter
            for _, control in ipairs(controls) do
                if rawget(control, "isLevelRange") and control.lowValue == -9 and control.highValue == 15 then
                    levelFilter = control
                end
            end
            assert(levelFilter, "map pins need one combined level filter slider")
            assert(levelFilter.labelText:find("Hide quests 9+ levels below you", 1, true))
            assert(levelFilter.labelText:find("Show all quests above you", 1, true))
            levelFilter:SetUserValue("low", -12)
            assert(ns.GetOption("trivialLevelGap") == 12)
            levelFilter:SetUserValue("high", 6)
            assert(ns.GetOption("highLevelGap") == 6)
            assert(levelFilter.labelText:find("Hide quests 12+ levels below you", 1, true))
            assert(levelFilter.labelText:find("Hide quests 6+ levels above you", 1, true))
            ns.SetOption("showTrivial", true)
            ns.SyncSettingsCheckboxes()
            assert(levelFilter.lowActive == false, "the below handle disables while low-level pins show")
            assert(levelFilter.labelText:find("Show all quests below you", 1, true))
            ns.SetOption("showTrivial", false)
            ns.SyncSettingsCheckboxes()
            assert(levelFilter.lowActive == true)
            local enhance, nearest
            for _, control in ipairs(controls) do
                if control.optionKey == "enhanceQuestTracker" then enhance = control end
                if control.optionKey == "selectNearestQuest" then nearest = control end
            end
            assert(enhance and nearest, "the quest tracker settings must exist")
            assert(enhance.checked == false and enhance.enabled == true)
            gamepadEnabled = true
            ns.SyncSettingsCheckboxes()
            assert(enhance.enabled == false and enhance.Text.alpha == 0.5)
            assert(nearest.enabled == false and nearest.Text.alpha == 0.5)
            gamepadEnabled = false
            ns.SyncSettingsCheckboxes()
            assert(enhance.enabled == true and nearest.enabled == true)
            local trackerDropdowns = {}
            for _, control in ipairs(controls) do
                if control.trackerOptionKey == "trackerSort" or control.trackerOptionKey == "trackerFilter" then
                    trackerDropdowns[#trackerDropdowns + 1] = control
                end
            end
            assert(#trackerDropdowns == 2, "the tracker has sort and filter dropdowns")
            assert(trackerDropdowns[1].enabled == false and trackerDropdowns[2].enabled == false)
            ns.SetOption("enhanceQuestTracker", true)
            assert(trackerDropdowns[1].enabled == true and trackerDropdowns[2].enabled == true)
            ns.SetOption("enhanceQuestTracker", false)
            assert(trackerDropdowns[1].enabled == false and trackerDropdowns[2].enabled == false)
            for _, control in ipairs(controls) do
                if type(control.optionKey) == "string" then
                    assert(control.height == 26, "option rows must fit within the settings panel")
                end
            end
            ns.MapPins.Clear = function() end
            local categories = { showWorldMapPins = true, showNormal = true, showClass = true, showDungeon = true,
                showPvP = true, showProfession = true, showSeasonal = true, showWarEffort = true, showRepeatable = true,
                showBooks = true }
            ns.SetOption("showClass", false)
            ns.SetOption("enabled", false)
            local count = 0
            for _, control in ipairs(controls) do
                if categories[control.optionKey] then
                    count = count + 1
                    assert(control.enabled == false and control.Text.alpha == 0.5)
                    assert(control.checked == ns.GetOption(control.optionKey))
                end
            end
            assert(count == 10)
            ns.SetOption("enabled", true)
            for _, control in ipairs(controls) do
                if categories[control.optionKey] then
                    assert(control.enabled == true and control.Text.alpha == 1)
                end
            end
            assert(ns.GetOption("showClass") == false)

end
cases["pin_filters_runtime.test_world_map_option_survives_settings_reload"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            assert(ns.GetOption("showWorldMapPins"))
            ns.SetOption("showWorldMapPins", false)
            ns.db = nil
            ns.InitSettings()
            assert(ns.GetOption("showWorldMapPins") == false)

end
cases["pin_filters_runtime.test_gamepad_pin_callbacks_run_after_map_input_handling"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            SoftCursor = { IsShown = function() return true end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function(frameType)
                if frameType == "GameTooltip" then
                    return {
                        Hide = function() gamepadTooltipHidden = (gamepadTooltipHidden or 0) + 1 end,
                        SetOwner = function() gamepadTooltipOwners = (gamepadTooltipOwners or 0) + 1 end,
                        SetText = function() end,
                        AddLine = function() end,
                        Show = function() gamepadTooltipShown = (gamepadTooltipShown or 0) + 1 end,
                    }
                end
                return { SetScript = function() end }
            end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.GetQuestTitle = function() return "Test quest" end
            ns.TrackQuest = function(questID) tracked = questID end
            local pin = { questID = 41, data = {}, IsShown = function() return true end }
            gamepadEnabled = true

            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(#timerQueue == 0 and gamepadTooltipShown == nil,
                "gamepad tooltip display must wait for the cursor poll")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(#timerQueue == 0)
            assert(tooltipOwners == nil and tooltipHidden == nil)
            assert(gamepadTooltipHidden == nil)

            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            assert(type(timerQueue[1]) == "function")
            pin.questID = 42
            timerQueue[1]()
            table.remove(timerQueue, 1)
            assert(tracked == nil)
            pin.questID = 41

            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            timerQueue[1]()
            table.remove(timerQueue, 1)
            assert(tracked == 41)

            gamepadEnabled = true
            SoftCursor.IsShown = function() return false end
            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(tooltipOwners == nil and gamepadTooltipShown == nil,
                "Gamepad UI mouse hover must defer to the cursor poll when the soft cursor is hidden")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(tooltipHidden == nil, "Gamepad UI mouse leave must leave tooltip cleanup to the cursor poll")

            gamepadEnabled = false
            SoftCursor = nil
            tracked = nil
            ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
            assert(tooltipOwners == 1, "mouse hover must continue to use the native GameTooltip outside Gamepad UI")
            ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
            assert(tooltipHidden == 1, "mouse leave must continue to hide the native GameTooltip outside Gamepad UI")
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 41 and #timerQueue == 0)

end
cases["pin_filters_runtime.test_map_levels_and_missing_metadata"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            wipe = function(t) for k in pairs(t) do t[k] = nil end end
            WorldMapFrame = { GetMapID = function() return 947 end, IsShown = function() return true end }
            C_Map = { GetMapInfo = function() return mapInfo end }
            -- No usable canvas distinguishes allowed maps from filtered maps.
            ns.SetOption("showWorldMapPins", false)
            for _, mapType in ipairs({1, 2}) do
                mapInfo = { mapType = mapType }
                ns.MapPins:Refresh()
                assert(ns.MapPins:GetStatus().mode == "map-level-hidden")
                assert(ns.MapPins:GetStatus().count == 0)
            end
            for _, mapType in ipairs({0, 3, 4, 5, 6}) do
                mapInfo = { mapType = mapType }
                ns.MapPins:Refresh()
                assert(ns.MapPins:GetStatus().mode == "no-canvas")
            end
            mapInfo = nil
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            C_Map.GetMapInfo = nil
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            C_Map.GetMapInfo = function() return {mapType = 1} end
            ns.SetOption("showWorldMapPins", true)
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "no-canvas")
            ns.SetOption("showWorldMapPins", false)
            InCombatLockdown = function() return true end
            ns.MapPins:Refresh()
            assert(ns.MapPins:GetStatus().mode == "combat-deferred")

end
cases["pin_filters_runtime.test_trivial_gap_restores_from_mirror_and_clamps"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end
use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=5;enabled=1")

            assert(ns.InitSettings().trivialLevelGap == 5)
            ns.SetOption("trivialLevelGap", 1)
            assert(ns.GetOption("trivialLevelGap") == 3)
            ns.SetOption("trivialLevelGap", 99)
            assert(ns.GetOption("trivialLevelGap") == 15)
            ns.SetOption("trivialLevelGap", 6)
            assert(ForeverQuestPinsDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsDB_Settings.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharacterSettings.trivialLevelGap == 6)
            assert(mirror:find("trivialLevelGap=6", 1, true))

end
cases["pin_filters_runtime.test_out_of_range_mirror_gap_falls_back_to_default"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end
use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=40;enabled=1")

            assert(ns.InitSettings().trivialLevelGap == 9)

end
cases["pin_filters_runtime.test_slash_trivial_sets_gap_and_bare_command_toggles"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.SlashCommand("trivial 5")
            assert(ns.GetOption("trivialLevelGap") == 5)
            assert(said("hiding quests 5+ levels below you"))
            ns.SlashCommand("trivial 40")
            assert(ns.GetOption("trivialLevelGap") == 15)
            assert(ns.GetOption("showTrivial") == false)
            ns.SlashCommand("trivial")
            assert(ns.GetOption("showTrivial") == true)
            assert(ns.GetOption("trivialLevelGap") == 15)

end
cases["pin_filters_runtime.test_hidden_quests_are_per_character_in_account_db"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            assert(ns.HideQuests({ 101, 102, 101 }) == 2)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"][101] == true)
            assert(refreshes[#refreshes] == "quest-hidden")

            playerName = "Jaina"
            assert(not ns.IsQuestHidden(101))
            assert(ForeverQuestPinsDB.hiddenQuests["Jaina-Forever"] == nil)
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(not ns.IsQuestHidden(201))

            playerName = nil
            assert(ns.HideQuests({ 301 }) == 0)
            assert(not ns.IsQuestHidden(301))

end
cases["pin_filters_runtime.test_hidden_quests_adopt_pre_1_1_character_key"] = function()
    ns = {}
    UnitName = function() return "Thrall", "Doomhammer" end
    GetRealmName = function() return "" end
    C_CVar = nil
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()

    -- 1.0.13 keyed this character by the realm name.
    ForeverQuestPinsDB.hiddenQuests = {
        ["Thrall-Forever"] = { [101] = true, [102] = true },
        ["Jaina-Forever"] = { [201] = true },
    }
    assert(ns.IsQuestHidden(101), "a list saved before 1.1.0 is still visible")
    assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Doomhammer"][101] == true)
    assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"] == nil)

    -- A list written since the upgrade keeps both sets.
    UnitName = function() return "Jaina", "Proudmoore" end
    ForeverQuestPinsDB.hiddenQuests["Jaina-Proudmoore"] = { [202] = true }
    assert(ns.IsQuestHidden(201) and ns.IsQuestHidden(202))
    assert(ForeverQuestPinsDB.hiddenQuests["Jaina-Proudmoore"][201] == true)
    assert(ForeverQuestPinsDB.hiddenQuests["Jaina-Forever"] == nil)
end

cases["pin_filters_runtime.test_hidden_quests_survive_init_and_wipe_settings"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.HideQuests({ 101 })
            ns.SetOption("showTrivial", true)
            ns.WipeSettings()
            assert(ns.IsQuestHidden(101))

            ForeverQuestPinsCharDB._revision = 999
            ns.db = nil
            ns.InitSettings()
            assert(ns.db == ForeverQuestPinsDB)
            assert(ns.IsQuestHidden(101))

end
cases["pin_filters_runtime.test_reset_hidden_quest_pins_clears_only_current_character"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.HideQuests({ 101, 102 })
            playerName = "Jaina"
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 2)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"] == nil)
            assert(said("Restored 2 hidden quest pin(s)."))
            playerName = "Jaina"
            assert(ns.IsQuestHidden(201))
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 0)

end
cases["pin_filters_runtime.test_unhide_one_and_slash_list"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            ns.GetQuestTitle = function(questID) return questID == 101 and "Sharptusk" or nil end
            ns.HideQuests({ 102, 101 })
            local ids = ns.HiddenQuestIDs()
            assert(#ids == 2 and ids[1] == 101 and ids[2] == 102)
            ns.SlashCommand("hidden")
            assert(said("101 Sharptusk"))
            ns.SlashCommand("unhide 101")
            assert(not ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            ns.SlashCommand("unhide 999")
            assert(said("Quest 999 is not hidden"))
            ns.SlashCommand("unhide")
            assert(said("Usage: /fqp unhide"))
            ns.SlashCommand("unhidden")
            assert(said("Unknown command"))
            ns.SlashCommand("unhide all")
            assert(#ns.HiddenQuestIDs() == 0)
            ns.SlashCommand("hidden")
            assert(said("No hidden quest pins"))

end
cases["pin_filters_runtime.test_shift_click_hides_every_quest_on_stacked_pin"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 }, { id = 103 } } }
            pin.Hide = function(self) self.hidden = true end
            shift = true
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102) and ns.IsQuestHidden(103))
            assert(tooltipHidden and pin.hidden)
            assert(said("Hid 3 quest(s)."))
            assert(refreshes[#refreshes] == "quest-hidden")
            local available, reason = ns.IsQuestAvailable(102, { minLevel = 1 })
            assert(available == false and reason == "user-hidden")

end
cases["pin_filters_runtime.test_plain_click_still_tracks"] = function()

            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            C_Map = { GetMapInfo = function() return { mapType = 3 } end }
            WorldMapFrame = { GetMapID = function() return 1 end }
            gamepadEnabled = false
            timerQueue = {}
            C_Timer = { After = function(_, callback) table.insert(timerQueue, callback) end }
            InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = {
                Hide = function() tooltipHidden = (tooltipHidden or 0) + 1 end,
                SetOwner = function() tooltipOwners = (tooltipOwners or 0) + 1 end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() end,
            }
            CreateFrame = function() return { SetScript = function() end } end

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
assert(loadfile("HiddenQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end

local function use_mirror(text)
mirror = text

            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }

end

            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 } } }
            ForeverQuestPinsMapPinMixin.OnClick(pin, "RightButton")
            assert(tracked == nil)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 101)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
            tracked = nil
            ns.SetOption("enablePinTracking", false)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            ns.SetOption("enablePinTracking", true)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 101)

end
cases["quest_info_runtime.test_offered_quests_repair_starters_without_map_coordinates"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[1]={qg=200, qgs={300}, mapID=1, x=10, y=20}
            ns.SetLastOfferNPC(100,nil,nil,nil)
            for id=1,3 do ns.NoteOfferedQuest(id) end
            assert(ns.IsOffered(1) and ns.IsOffered(2) and ns.IsOffered(3))
            assert(ns.Quests[1].qg==200 and ns.Quests[1].qgs[1]==300)
            assert(ns.Quests[1].mapID==1 and ns.Quests[1].x==10)
            assert(ns.Quests[1].qgs[2]==100)
            ns.NoteOfferedQuest(1)
            assert(#ns.Quests[1].qgs==2)
            assert(next(ns.ByMap)==nil)
            ns.SetLastOfferNPC(nil,nil,nil,nil)
            ns.NoteOfferedQuest(4)
            assert(ns.Quests[4]==nil)
            ns.SetLastOfferNPC(nil,1,25,30)
            ns.NoteOfferedQuest(5)
            assert(ns.ByMap[1][1]==5 and ns.Quests[5].qg==nil)

end
cases["quest_info_runtime.test_offered_quests_fill_coordless_records"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[7]={turnIns={100}}
            ns.SetLastOfferNPC(200,2521,42,23)
            ns.NoteOfferedQuest(7)
            assert(ns.Quests[7].qg==200)
            assert(ns.Quests[7].mapID==2521 and ns.Quests[7].x==42 and ns.Quests[7].y==23)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==7)
            ns.NoteOfferedQuest(7)
            assert(#ns.ByMap[2521]==1)

end
cases["quest_info_runtime.test_npc_tooltip_deduplicates_accept_and_turn_in"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.options={showNPCTooltips=true}
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,1,1 end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            ns.NPCTooltips.GetAcceptRows=function()
                return { { id=20, text='[5] Quest 20', level=5, marker='!' } }
            end
            ns.NPCTooltips.GetTurnInRows=function()
                return { { id=20, text='[5] Quest 20', level=5, marker='?' } }
            end
            local lines={}
            GameTooltip={ AddLine=function(_, text) lines[#lines+1]=text end, Show=function() end }
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==1 and lines[1]=='! [5] Quest 20')

end
cases["quest_info_runtime.test_npc_tooltip_coordless_turn_in"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true}
            ns.Quests={ [20]={ turnIns={100}, title='Coordless' } }
            ns.active={ [20]=true }
            ns.complete={ [20]=true }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==1)

end
cases["quest_info_runtime.test_npc_tooltip_skips_instances"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.options={showNPCTooltips=true}
            function ns.GetOption(key) return ns.options[key] end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            IsInInstance=function() return true, 'party' end
            local lines={}
            GameTooltip={ AddLine=function(_, text) lines[#lines+1]=text end, Show=function() end }
            ns.NPCTooltips.GetAcceptRows=function() error('accept lookup must not run in an instance') end
            ns.NPCTooltips.GetTurnInRows=function() error('turn-in lookup must not run in an instance') end
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==0)

end
cases["quest_info_runtime.test_npc_tooltip_multiple_turn_in_npcs"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true}
            ns.Quests={ [20]={ turnIns={100,101} } }
            ns.active={ [20]=true }
            ns.complete={ [20]=true }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==1)
            assert(#ns.NPCTooltips:GetTurnInRows(101)==1)

end
cases["quest_info_runtime.test_instance_classification_prefers_runtime_tag"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.QuestTagCorrections={ [104]=81 }
            assert(ns.IsInstanceQuest(104, {}))
            C_QuestLog.GetQuestTagInfo=function()
                return { tagID=0, tagName="None" }
            end
            assert(ns.IsInstanceQuest(104, {}))
            ns.InvalidateInstanceQuestCache()
            C_QuestLog.GetQuestTagInfo=function()
                return { tagID=0, tagName="None" }
            end
            assert(ns.IsInstanceQuest(105, { isInstanceQuest=true }))
            assert(not ns.IsInstanceQuest(106, {}))

end
cases["quest_info_runtime.test_new_offered_quest_hides_when_accepted"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.SetLastOfferNPC(100,2521,42,23)
            ns.NoteOfferedQuest(92499)
            ns.NoteOfferedQuest(92499)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==92499)
            assert(ns.IsQuestAvailable(92499, ns.Quests[92499]) == true)
            C_QuestLog.IsOnQuest=function() return true end
            local available, reason=ns.IsQuestAvailable(92499, ns.Quests[92499])
            assert(available == false and reason == 'in-log')

end
cases["quest_info_runtime.test_data_title_fallback_when_client_has_no_title"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests = {
                [8171] = { title = "The Battle for Arathi Basin!" },
            }
            assert(ns.GetQuestTitle(8171) == "The Battle for Arathi Basin!")

end
cases["quest_info_runtime.test_client_title_wins_over_data_fallback"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests = { [1] = { title = "Questie name" } }
            C_QuestLog.GetTitleForQuestID = function() return "Client name" end
            assert(ns.GetQuestTitle(1) == "Client name")

end
cases["quest_info_runtime.fallback_title_is_not_client_ready"] = function()
    dofile("tests/fixtures/quest_info.lua")
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.Quests = { [1] = { title = "English title" } }
    local clientTitle
    local requests = 0
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    C_QuestLog.GetTitleForQuestID = function() return clientTitle end
    local title, ready = ns.GetQuestTitle(1)
    assert(title == "English title" and not ready)
    assert(requests == 1)
    ns.OnQuestDataLoadFailed(1)
    for _ = 1, 5 do
        title, ready = ns.GetQuestTitle(1, true)
        assert(title == "English title" and not ready)
    end
    assert(requests == 1)
    clientTitle = "Título en español"
    title, ready = ns.GetQuestTitle(1)
    assert(title == "Título en español" and ready)
end
cases["quest_info_runtime.test_failed_title_load_retries_on_lookup_and_recovers"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            CreateFrame=function()
                frame={}
                function frame:SetScript(name,fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            requests=0
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            assert(ns.GetQuestTitle(1)==nil and requests==1)

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(requests==1)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            C_QuestLog.GetTitleForQuestID=function() return 'Loaded quest' end
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            assert(ns.GetQuestTitle(1)=='Loaded quest')

end
cases["quest_info_runtime.test_level_lookup_requests_data_once_and_never_uses_minimum"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local requests=0
            C_QuestLog.GetQuestDifficultyLevel=function() return nil end
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            ns.Quests[1]={minLevel=5}
            assert(ns.GetQuestDifficultyLevel(1)==nil)
            assert(ns.GetQuestDifficultyLevel(1)==nil and requests==1)
            C_QuestLog.GetQuestDifficultyLevel=function() return 12 end
            assert(ns.GetQuestDifficultyLevel(1)==12)

end
cases["quest_info_runtime.test_required_profession_filters_only_when_skill_data_is_known"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Orc','Orc',2 end
            UnitClass=function() return 'Druid','DRUID',11 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 13 end
            IsPlayerSpell=function(spellID) return spellID == 9788 end
            GetProfessions=function() return 1,nil,nil,2 end
            GetProfessionInfo=function(index)
                local skillLine = index == 1 and 197 or 356
                return 'Profession',nil,1,75,nil,nil,skillLine
            end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            assert(ns.IsQuestAvailable(1,{requireSkill=197}) == true)
            assert(ns.IsQuestAvailable(5,{requireSkill=9788}) == true)
            local available, reason = ns.IsQuestAvailable(2,{requireSkill=164})
            assert(available == false and reason == 'profession')
            assert(ns.IsQuestAvailable(3,{requireSkill='NEW_PROFESSION'}) == true)
            GetProfessions=nil
            GetProfessionInfo=nil
            ns.InvalidateProfessionCache()
            assert(ns.IsQuestAvailable(4,{requireSkill=164}) == true)

end
cases["quest_info_runtime.test_skyborne_race_restrictions_filter_the_opposite_faction"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Skyborne','Skyborne',96 end
            UnitClass=function() return 'Hunter','HUNTER',3 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 10 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            assert(ns.IsQuestAvailable(92598,{races={96}}) == true)
            local available, reason = ns.IsQuestAvailable(92597,{races={95}})
            assert(available == false and reason == 'race')

end
cases["quest_info_runtime.test_npc_offers_quest_accept_respects_starter_and_offered"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            ns.Quests[7]={qg=197}
            assert(ns.NpcOffersQuestAccept(197, 7, ns.Quests[7]) == true)
            assert(ns.NpcOffersQuestAccept(198, 7, ns.Quests[7]) == false)
            ns.offeredQuestIDs[99]=true
            assert(ns.NpcOffersQuestAccept(555, 99, nil) == true)

end
cases["quest_info_runtime.test_npc_tooltip_accept_rows_skip_in_log_quests"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] end,
                IsQuestFlaggedCompleted=function() return false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,1,1 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.Quests[10]={qg=100}
            ns.NPCTooltips:InvalidateStarterIndex()
            local rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==1 and rows[1].id==10)
            ns.active[10]=true
            rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==0)

end
cases["quest_info_runtime.test_npc_tooltip_shows_in_log_turn_ins_and_accepts"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            ns.complete={}
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            lines={}
            GameTooltip={
                AddLine=function(_, text) lines[#lines+1]=text end,
                Show=function() end,
            }

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,0.8,0 end
            ns.Quests[10]={qg=100}
            ns.Quests[20]={turnIns={100}}
            ns.active[20]=true
            ns.complete[20]=true
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(lines[1]=='! [5] Quest 10')
            assert(lines[2]=='? [5] Quest 20')
            assert(#lines==2)

            lines={}
            GameTooltip.fqpQuestRows=nil
            ns.Quests[10]=nil
            ns.active[20]=true
            ns.complete[20]=true
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==1 and lines[1]=='? [5] Quest 20')

end
cases["quest_info_runtime.test_npc_tooltip_turn_ins_need_ready_state"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={ [20]={ turnIns={100} } }
            ns.active={ [20]=true }
            ns.complete={ [20]=false }
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100)==0)
            ns.complete[20]=true
            local rows=ns.NPCTooltips:GetTurnInRows(100)
            assert(#rows==1 and rows[1].marker=='?')

end
cases["quest_info_runtime.test_yearly_quests_stay_hidden_until_seasonal_pins_are_on"] = function()
dofile("tests/fixtures/quest_info.lua")

            ns.options={showRepeatable=true,showSeasonal=false,showWarEffort=true,showTrivial=true}
            function ns.GetOption(key) return ns.options[key] end
            UnitLevel=function() return 60 end
            C_QuestLog={
                IsOnQuest=function() return false end,
                IsQuestFlaggedCompleted=function() return false end,
            }

assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            local available, reason = ns.IsQuestAvailable(8673, {isYearly=true, minLevel=1})
            assert(available == false and reason == 'seasonal')
            available, reason = ns.IsQuestAvailable(155, {minLevel=14})
            assert(available == true and reason == 'no-prereq')

end
cases["quest_info_runtime.test_npc_id_from_secret_guid_returns_nil"] = function()
dofile("tests/fixtures/quest_info.lua")
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)

            issecretvalue=function() return true end
            assert(ns.NpcIDFromGUID('secret-guid')==nil)

end
cases["quest_info_runtime.data_load_refreshes_only_when_level_filter_flips"] = function()
    ns = { Quests = {
        [1] = { minLevel = 50 },
        [2] = { minLevel = 20 },
        [3] = { minLevel = 55 },
    } }
    local options = { showTrivial = false, trivialLevelGap = 9, highLevelGap = 15 }
    ns.GetOption = function(key) return options[key] end
    UnitLevel = function() return 60 end
    local difficulty
    C_QuestLog = {
        GetTitleForQuestID = function() return nil end,
        GetQuestDifficultyLevel = function() return difficulty end,
        RequestLoadQuestByID = function() end,
    }
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    local refreshes = {}
    ns.RequestRefresh = function(reason) refreshes[#refreshes + 1] = reason end

    -- The database minimum level made quest 1 trivial, but the loaded level
    -- does not, so the pin set changes.
    difficulty = 55
    ns.OnQuestDataLoad(1)
    assert(#refreshes == 1 and refreshes[1] == "quest-level")

    -- Both levels are trivial; the pin set does not change.
    difficulty = 48
    ns.OnQuestDataLoad(1)
    assert(#refreshes == 1)

    -- Neither level is trivial.
    difficulty = 59
    ns.OnQuestDataLoad(3)
    assert(#refreshes == 1)

    -- The high-level filter starts applying once the level loads.
    options.showTrivial = true
    options.highLevelGap = 3
    difficulty = 70
    ns.OnQuestDataLoad(2)
    assert(#refreshes == 2 and refreshes[2] == "quest-level")

    difficulty = 62
    ns.OnQuestDataLoad(2)
    assert(#refreshes == 2)
end

cases["quest_info_runtime.test_failed_data_event_does_not_trigger_success_handler"] = function()
dofile("tests/fixtures/quest_info.lua")

            CreateFrame=function()
                frame={}
                function frame:SetScript(name, fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            dataLoads=0
            ns.OnQuestDataLoad=function() dataLoads=dataLoads+1 end

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(dataLoads==0)
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            frame.OnEvent(frame,'QUEST_DATA_LOAD',1)
            assert(dataLoads==2)

end
cases["quest_info_runtime.test_combat_hides_without_layout_changes_and_restores_original_alpha"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == false)
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)
            tracker.collapsed = true
            tracker.alpha = 0
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == true)

end
cases["quest_info_runtime.test_disabling_option_during_combat_restores_tracker"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            inCombat = true
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0)
            ns.hideTracker = false
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0.65)
            tracker.alpha = 0.8
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.8)

end
cases["quest_info_runtime.test_disabled_option_leaves_tracker_untouched"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            ns.hideTracker = false
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65)

end
cases["quest_info_runtime.test_missing_tracker_can_be_retried_and_original_frame_is_restored"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = {}
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = tracker
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(false)
            assert(tracker.alpha == 0.65)

end
cases["quest_info_runtime.test_quest_completion_and_level_up_refresh_leave_collapse_unchanged"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            refreshes = 0
            ns.MapPins = {Refresh=function(_, reason)
                assert(reason == 'PLAYER_LEVEL_UP' or reason == 'QUEST_TURNED_IN')
                refreshes = refreshes + 1
            end}
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'QUEST_TURNED_IN', 1)
            frame.OnUpdate(frame, 0.2)
            frame.OnEvent(frame, 'PLAYER_LEVEL_UP')
            frame.OnUpdate(frame, 0.2)
            assert(refreshes == 2 and tracker.alpha == 0)
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)

end
cases["quest_info_runtime.test_nameplate_events_update_icons_without_requesting_map_refresh"] = function()

            ns = {}
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            added, removed = nil, nil
            ns.Nameplates = {
                UpdateUnit = function(_, unit) added = unit end,
                ReleaseUnit = function(_, unit) removed = unit end,
            }

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            refreshes = 0
            ns.RequestRefresh = function() refreshes = refreshes + 1 end
            frame.OnEvent(frame, 'NAME_PLATE_UNIT_ADDED', 'nameplate1')
            frame.OnEvent(frame, 'NAME_PLATE_UNIT_REMOVED', 'nameplate1')
            assert(added == 'nameplate1' and removed == 'nameplate1')
            assert(refreshes == 0)

end
cases["quest_info_runtime.test_map_refresh_skips_quest_state_cache_invalidation"] = function()

            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker

assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

            completion = 0
            profession = 0
            starter = 0
            ns.InvalidateCompletionCache = function() completion = completion + 1 end
            ns.InvalidateProfessionCache = function() profession = profession + 1 end
            ns.NPCTooltips = {
                InvalidateStarterIndex=function() starter = starter + 1 end,
            }
            ns.MapPins = {Refresh=function() end}
            nameplates = 0
            ns.Nameplates = {RefreshAll=function() nameplates = nameplates + 1 end}
            ns.RefreshNow('map-show')
            ns.RefreshNow('map-changed')
            ns.RefreshNow('canvas-zero')
            assert(completion == 0 and profession == 0 and starter == 0 and nameplates == 0)
            ns.RefreshNow('quest-hidden')
            assert(completion == 0 and profession == 0 and starter == 0 and nameplates == 1)
            ns.RefreshNow('QUEST_TURNED_IN')
            assert(completion == 1 and profession == 1 and starter == 0 and nameplates == 2)

end
cases["quest_links_runtime.test_url_selection_and_validation"] = function()

            ns = {}
            CLOSE = "Close"
            StaticPopupDialogs = {}
            editBox = {
                SetText = function(_, text) copiedText = text end,
                SetFocus = function() focused = true end,
                HighlightText = function() selected = true end,
            }
            StaticPopup_Show = function(name, _, _, data)
                local dialog = { GetEditBox = function() return editBox end }
                StaticPopupDialogs[name].OnShow(dialog, data)
                return dialog
            end

assert(loadfile("QuestLinks.lua"))("ForeverQuestPins", ns)

            assert(ns.ShowWowheadQuestURL(8383))
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            assert(focused and selected)
            for _, id in ipairs({ 0, -1, 1.5, "8383", math.huge, 0/0 }) do
                assert(not ns.ShowWowheadQuestURL(id))
            end
            assert(not ns.ShowWowheadQuestURL(nil))
            assert(ns.ShowWowheadQuestURL(6))
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")

end
cases["quest_links_runtime.test_delayed_registration_menu_scope_and_captured_quest"] = function()

            ns = {}
            CLOSE = "Close"
            StaticPopupDialogs = {}
            editBox = {
                SetText = function(_, text) copiedText = text end,
                SetFocus = function() focused = true end,
                HighlightText = function() selected = true end,
            }
            StaticPopup_Show = function(name, _, _, data)
                local dialog = { GetEditBox = function() return editBox end }
                StaticPopupDialogs[name].OnShow(dialog, data)
                return dialog
            end

assert(loadfile("QuestLinks.lua"))("ForeverQuestPins", ns)

            assert(not ns.TryRegisterQuestLinks())
            local owner = {}
            local hooks = {}
            local registrations = 0
            QuestObjectiveTracker = {
                OnBlockHeaderEnter = function() end,
                OnBlockHeaderLeave = function() end,
                GetContextMenuParent = function() return owner end,
            }
            hooksecurefunc = function(_, name, callback) hooks[name] = callback end
            Menu = { ModifyMenu = function(tag, callback)
                assert(tag == "MENU_QUEST_OBJECTIVE_TRACKER")
                registrations = registrations + 1
                modify = callback
            end }
            assert(ns.TryRegisterQuestLinks())
            assert(ns.TryRegisterQuestLinks() and registrations == 1)
            local buttons = {}
            local root = {
                CreateDivider = function() end,
                CreateButton = function(_, label, callback)
                    assert(label == "Copy Wowhead URL")
                    table.insert(buttons, callback)
                end,
            }
            modify(owner, root)
            assert(#buttons == 0)
            local block = { id = 8383 }
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify({}, root)
            assert(#buttons == 0)
            modify(owner, root)
            assert(#buttons == 1)
            block.id = 6
            hooks.OnBlockHeaderLeave(QuestObjectiveTracker, block)
            buttons[1]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            modify(owner, root)
            assert(#buttons == 1)
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify(owner, root)
            buttons[2]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")

end
cases["waypoints_runtime.test_start_coordinates_and_native_accept_handoff"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            assert(ns.TrackQuest(1))
            assert(waypoint.uiMapID==1412 and waypoint.position.x==54.4/100)
            assert(waypoint.position.y==60.4/100 and userTracked)
            onQuest=true
            ns.UpdateWaypoint()
            assert(waypoint==nil and trackedQuest==1 and added==0)
            ns.UpdateWaypoint()
            assert(added==0)
            ns.OnWaypointQuestEnded(1)
            assert(trackedQuest==0)

end
cases["waypoints_runtime.tracking_waits_out_of_combat"] = function()
    ns = { Quests = { [1] = { mapID = 1412, x = 54.4, y = 60.4 } } }
    local provider = "blizzard"
    local inCombat = true
    local waypoint, trackedQuest, userTracked
    ns.GetOption = function() return provider end
    ns.GetQuestTitle = function() return "A Quest" end
    ns.IsOnQuest = function() return false end
    ns.AddOnActionsRestricted = function() return inCombat end
    UiMapPoint = { CreateFromCoordinates = function(map, x, y)
        return { uiMapID = map, position = { x = x, y = y } }
    end }
    C_Map = {
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point) waypoint = point end,
        GetUserWaypoint = function() return waypoint end,
        ClearUserWaypoint = function() waypoint = nil end,
    }
    C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function(value) userTracked = value end,
        IsSuperTrackingUserWaypoint = function() return userTracked end,
        SetSuperTrackedQuestID = function(id) trackedQuest = id end,
        GetSuperTrackedQuestID = function() return trackedQuest end,
    }
    C_QuestLog = { GetNextWaypoint = function() end }
    assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)
    print = function() end

    local ok, message = ns.TrackQuest(1)
    assert(ok == false, "tracking is refused in combat")
    assert(message == "Quest tracking is unavailable in combat.")
    assert(waypoint == nil and trackedQuest == nil, "no waypoint or super-track write in combat")

    inCombat = false
    assert(ns.TrackQuest(1))
    assert(waypoint and waypoint.uiMapID == 1412)
    assert(userTracked == true)

    inCombat = true
    ns.ClearWaypoint()
    assert(waypoint ~= nil, "clearing waits until combat ends")
    inCombat = false
    ns.ClearWaypoint()
    assert(waypoint == nil)
end

cases["waypoints_runtime.test_manual_pin_and_quest_changes_are_respected"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            ns.TrackQuest(1)
            waypoint=UiMapPoint.CreateFromCoordinates(1,0.2,0.3)
            onQuest=true
            ns.UpdateWaypoint()
            assert(trackedQuest==nil and waypoint.uiMapID==1)
            ns.ClearWaypoint()
            assert(waypoint.uiMapID==1)
            assert(ns.TrackQuest(1))
            trackedQuest=2
            ns.ClearWaypoint()
            assert(trackedQuest==2)

end
cases["waypoints_runtime.test_other_quest_tracking_cancels_accept_handoff"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            ns.TrackQuest(1)
            C_SuperTrack.SetSuperTrackedQuestID(2)
            onQuest=true
            ns.UpdateWaypoint()
            assert(trackedQuest==2)

end
cases["waypoints_runtime.test_tomtom_updates_objective_turnin_and_removes_only_owned_uid"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"
            assert(ns.TrackQuest(1))
            assert(added==1 and not last.opts.persistent and last.opts.crazy)
            local start=last
            onQuest=true; nextMap=1411; nextX=0.4; nextY=0.5
            ns.UpdateWaypoint()
            assert(added==2 and removedUID==start and last.map==1411)
            ns.UpdateWaypoint()
            assert(added==2)
            nextX=0.6
            ns.UpdateWaypoint()
            assert(added==3 and last.x==0.6)
            ns.OnWaypointQuestEnded(2)
            assert(removed==2)
            ns.OnWaypointQuestEnded(1)
            assert(removed==3)

end
cases["waypoints_runtime.test_missing_objective_does_not_reuse_start_and_recovers"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"; ns.TrackQuest(1); onQuest=true
            ns.UpdateWaypoint()
            assert(removed==1 and added==1)
            nextMap=1412; nextX=0.3; nextY=0.4
            ns.UpdateWaypoint()
            assert(added==2)

end
cases["waypoints_runtime.test_missing_provider_unsupported_map_and_invalid_location"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            provider="tomtom"; TomTom=nil
            assert(not ns.TrackQuest(1) and #messages==1)
            provider="blizzard"; C_Map.CanSetUserWaypointOnMap=function() return false end
            assert(not ns.TrackQuest(1) and waypoint==nil)
            C_Map.SetUserWaypoint=nil
            assert(not ns.TrackQuest(1))
            ns.Quests[1].x=101
            assert(not ns.TrackQuest(1))
            assert(not ns.TrackQuest(nil))

end
cases["waypoints_runtime.test_provider_setting_persists_and_validates"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)
assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            assert(ns.InitSettings().waypointProvider=="blizzard")
            ns.SetOption("waypointProvider","tomtom")
            assert(ForeverQuestPinsCharDB.waypointProvider=="tomtom")
            assert(ForeverQuestPinsDB_Settings.waypointProvider=="tomtom")
            ns.SetOption("waypointProvider","invalid")
            assert(ns.GetOption("waypointProvider")=="tomtom")
            ns.WipeSettings()
            assert(ns.GetOption("waypointProvider")=="blizzard")

end
cases["waypoints_runtime.test_provider_recovers_from_cvar_mirror"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            mirror="revision=42;waypointProvider=tomtom;enabled=1"
            C_CVar={GetCVar=function() return mirror end,
                SetCVar=function(_,text) mirror=text end, RegisterCVar=function() end}

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            assert(ns.InitSettings().waypointProvider=="tomtom")
            assert(mirror:find("waypointProvider=tomtom",1,true))
            ns.SetOption("waypointProvider","blizzard")
            assert(mirror:find("waypointProvider=blizzard",1,true))

end
cases["waypoints_runtime.test_navigation_checkbox_uses_shared_cvar_without_overriding_it"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            onQuest=false
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.GetQuestTitle=function() return "A Quest" end
            ns.IsOnQuest=function() return onQuest end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
                SetSuperTrackedQuestID=function(id) trackedQuest=id; userTracked=false end,
                GetSuperTrackedQuestID=function() return trackedQuest end,
            }
            C_QuestLog={GetNextWaypoint=function() return nextMap,nextX,nextY end}
            added=0; removed=0
            TomTom={
                AddWaypoint=function(self,map,x,y,opts)
                    added=added+1
                    last={map=map,x=x,y=y,opts=opts}
                    return last
                end,
                RemoveWaypoint=function(self,uid) removed=removed+1; removedUID=uid end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            navigation="0"
            C_CVar={GetCVar=function(key)
                    if key=="showInGameNavigation" then return navigation end
                    return ""
                end,
                SetCVar=function(key,value)
                    if key=="showInGameNavigation" then navigation=value end
                end,
                RegisterCVar=function() end}

assert(loadfile("Config.lua"))("ForeverQuestPins", ns)

            ns.InitSettings()
            assert(navigation=="0" and not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",true)
            assert(navigation=="1" and ns.GetOption("showInGameNavigation"))
            navigation="0"
            assert(not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",false)
            assert(navigation=="0")
            C_CVar=nil
            assert(not ns.GetOption("showInGameNavigation"))
            ns.SetOption("showInGameNavigation",true)
            assert(#messages==1)

end
local function tooltipHas(text)
    for _, line in ipairs(tooltipLines or {}) do
        if line == text then
            return true
        end
    end
    return false
end

local function setupPinRendering()
    options = { enabled = true, showWorldMapPins = true, showUnexplored = true,
        showRepeatable = true, showNormal = true, showClass = true, showProfession = true,
        showDungeon = true, showSeasonal = true, showWarEffort = true, showTrivial = true,
        showSpawnClusters = true, iconScale = 100 }
    local function texture()
        return {
            SetAllPoints = function() end, Hide = function(self) self.shown = false end,
            Show = function(self) self.shown = true end,
            IsShown = function(self) return self.shown == true end,
            ClearAllPoints = function() end,
            SetPoint = function(self, ...) self.point = { ... } end,
            SetSize = function(self, width, height) self.width, self.height = width, height end,
            SetAtlas = function(self, name) self.atlas = name end,
            SetTexture = function(self, name) self.file = name end,
            SetColorTexture = function(self, r, g, b, a) self.colorTexture = { r, g, b, a } end,
            SetDesaturated = function(self, value) self.desaturated = value end,
            SetVertexColor = function(self, r, g, b, a) self.color = { r, g, b, a } end,
            SetDrawLayer = function() end, SetBlendMode = function() end,
            SetAlpha = function(self, value) self.alpha = value end,
            SetTexCoord = function(self, left, right, top, bottom)
                self.texCoord = { left, right, top, bottom }
            end,
        }
    end
    local function fontString()
        return {
            SetPoint = function() end, SetJustifyH = function() end,
            SetShadowColor = function() end, SetShadowOffset = function() end,
            SetTextColor = function() end, SetDrawLayer = function() end,
            SetScale = function() end, SetAlpha = function() end,
            SetText = function(self, text) self.text = text end,
            GetText = function(self) return self.text end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
            IsShown = function(self) return self.shown == true end,
        }
    end
    local function frame()
        return {
            SetScript = function(self, event, fn) self.scripts = self.scripts or {}; self.scripts[event] = fn end,
            RegisterForClicks = function() end,
            EnableMouse = function(self, enabled) self.mouseEnabled = enabled; self.clickEnabled = enabled end,
            SetMouseClickEnabled = function(self, enabled) self.clickEnabled = enabled end, SetParent = function(self, parent) self.parent = parent end,
            CreateTexture = function(self)
                local created = texture()
                self.textures = self.textures or {}
                self.textures[#self.textures + 1] = created
                return created
            end,
            CreateFontString = function() return fontString() end,
            SetSize = function(self, width, height) self.width, self.height = width, height end,
            SetScale = function(self, scale) self.scale = scale end,
            GetScale = function(self) return self.scale or 1 end,
            GetEffectiveScale = function(self) return self.scale or 1 end,
            GetCenter = function(self) return self.centerX, self.centerY end,
            GetLeft = function(self) return self.left or 0 end,
            GetTop = function(self) return self.top or 0 end,
            SetIgnoreParentScale = function() end, SetFrameLevel = function(self, level) self.frameLevel = level end,
            SetFrameStrata = function(self, strata) self.strata = strata end, SetAlpha = function() end,
            Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
            IsShown = function(self) return self.shown == true end,
            ClearAllPoints = function() end,
            SetPoint = function(self, ...) self.point = { ... } end, GetParent = function(self) return self.parent end,
            GetFrameLevel = function(self) return self.frameLevel or 1 end, GetFrameStrata = function() return "LOW" end,
        }
    end
    local canvas = frame()
    canvas.GetWidth = function() return 1000 end
    canvas.GetHeight = function() return 800 end
    UIParent = frame()
    UIParent.GetEffectiveScale = function() return 1 end
    cloudFrames = {}
    mapCanvas = canvas
    local map = frame()
    map.GetCanvas = function() return canvas end
    map.GetMapID = function() return 1 end
    map.IsShown = function() return true end
    map.ScrollContainer = {}
    WorldMapFrame = map
    CreateFrame = function(frameType, _, parent)
        local created = frame()
        created.parent = parent
        if frameType == "Frame" and not parent then
            mapWatch = created
        elseif parent == UIParent then
            cloudFrames[#cloudFrames + 1] = created
        elseif parent then
            pin = created
            created.centerX, created.centerY = 500, 400
        end
        return created
    end
    C_QuestLog = {
        GetAllCompletedQuestIDs = function() return {} end,
        IsOnQuest = function() return false end,
    }
    C_Map = {
        GetMapInfo = function() return { mapType = 3 } end,
        GetPlayerMapPosition = function()
            return { GetXY = function() return 0.5, 0.5 end }
        end,
    }
    tooltipLines = {}
    GameTooltip = {
        SetOwner = function() end,
        SetText = function(_, text) tooltipLines = { text } end,
        AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
        Show = function() end, Hide = function() end,
    }
    UnitLevel = function() return 60 end
    UnitFactionGroup = function() return "Alliance" end
    wipe = function(value) for key in pairs(value) do value[key] = nil end end
    trackedQuestID = nil
    trackedData = nil
    ns = {
        Quests = { [101] = { mapID = 1, x = 50, y = 50, repeatable = true } },
        ByMap = { [1] = { 101 } },
        GetOption = function(key) return options[key] end,
        GetQuestTitle = function() return "Repeatable test quest" end,
        PrefetchQuestInfo = function() end,
        RequestRefresh = function() end,
        IsQuestHidden = function() return false end,
        TrackQuest = function(questID, data) trackedQuestID, trackedData = questID, data end,
    }
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)
end

cases["map_pins_runtime.tracking_respects_map_level"] = function()
    setupPinRendering()
    local mapType = 3
    C_Map.GetMapInfo = function() return { mapType = mapType } end
    ns.MapPins:Refresh("zone")
    assert(pin.mouseEnabled == true and pin.clickEnabled == true)
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    trackedQuestID = nil
    for _, value in ipairs({ 1, 2 }) do
        mapType = value
        ns.MapPins:Refresh("world")
        assert(pin.mouseEnabled == true and pin.clickEnabled == false)
        pin.scripts.OnClick(pin, "LeftButton")
        assert(trackedQuestID == nil)
    end
    options.trackOnWorldMaps = true
    ns.MapPins:Refresh("allowed")
    assert(pin.mouseEnabled == true and pin.clickEnabled == true)
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    options.enablePinTracking = false
    ns.MapPins:Refresh("disabled")
    assert(pin.mouseEnabled == true and pin.clickEnabled == false)
    pin.scripts.OnEnter(pin)
    assert(tooltipLines[1] == "Quest")
    for _, line in ipairs(tooltipLines) do
        assert(not line:find("Click to track", 1, true))
    end
end

cases["map_pins_runtime.map_never_post_hooks_world_map_frame"] = function()
    setupPinRendering()
    local hooked = {}
    hooksecurefunc = function(_, name)
        hooked[#hooked + 1] = name
    end
    ns.MapPins:HookMap()
    assert(#hooked == 0,
        "post-hooking WorldMapFrame taints the rest of Blizzard's map execution (hooked: "
            .. table.concat(hooked, ", ") .. ")")
    -- Open detection is the OnUpdate watch, not a Show hook.
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    ns.MapPins:Refresh("map-show")
    assert(ns.MapPins:GetStatus().count > 0, "the watch still notices an open map")
end

cases["map_pins_runtime.combat_defers_map_work"] = function()
    setupPinRendering()
    local combat = true
    InCombatLockdown = function() return combat end
    local originalGetMapID = WorldMapFrame.GetMapID
    local originalGetCanvas = WorldMapFrame.GetCanvas
    local originalGetWidth = mapCanvas.GetWidth
    local originalGetHeight = mapCanvas.GetHeight
    local function refuseInCombat(name, original)
        return function(...)
            if combat then
                error(name .. " must not run in combat")
            end
            return original(...)
        end
    end
    WorldMapFrame.GetMapID = refuseInCombat("GetMapID", originalGetMapID)
    WorldMapFrame.GetCanvas = refuseInCombat("GetCanvas", originalGetCanvas)
    WorldMapFrame.GetCanvasScale = refuseInCombat("GetCanvasScale", function() return 1 end)
    mapCanvas.GetWidth = refuseInCombat("GetWidth", originalGetWidth)
    mapCanvas.GetHeight = refuseInCombat("GetHeight", originalGetHeight)
    local refreshReasons = {}
    ns.RequestRefresh = function(reason) refreshReasons[#refreshReasons + 1] = reason end

    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(#refreshReasons == 0, "combat must not open or refresh the map")

    combat = false
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(refreshReasons[#refreshReasons] == "map-show",
        "the deferred map open runs after combat")
end

cases["map_pins_runtime.shift_click_hides_on_click_through_maps"] = function()
    setupPinRendering()
    local shiftHeld = false
    local hidden = {}
    IsShiftKeyDown = function() return shiftHeld end
    ns.HideQuests = function(ids)
        for i = 1, #ids do
            hidden[ids[i]] = true
        end
        return #ids
    end
    hooksecurefunc = function() end
    C_Map.GetMapInfo = function() return { mapType = 2 } end

    ns.MapPins:HookMap()
    ns.MapPins:Refresh("continent")
    assert(pin.clickEnabled == false, "plain clicks stay click-through on a continent map")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("Shift-click to hide this marker."))
    assert(not tooltipHas("Click to track this quest start."))

    shiftHeld = true
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(pin.clickEnabled == true, "holding Shift lets the pin receive the hide click")
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == nil)
    assert(hidden[101])

    shiftHeld = false
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(pin.clickEnabled == false, "releasing Shift restores click-through")
end

cases["map_pins_runtime.delayed_title_updates_hover_without_request_loop"] = function()
    setupPinRendering()
    ns.Quests[101].title = "English title"
    local clientTitle
    local requests = 0
    C_QuestLog.GetTitleForQuestID = function() return clientTitle end
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    ns.MapPins:Refresh("title")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("English title"))
    ns.OnQuestDataLoadFailed(101)
    local previousRequests = requests
    for _ = 1, 5 do ns.MapPins:SnapToQuestGivers() end
    assert(requests == previousRequests)
    clientTitle = "Título en español"
    ns.MapPins:SnapToQuestGivers()
    assert(tooltipHas("Título en español"))
end

cases["map_pins_runtime.icon_scale_changes_rendered_pin_size"] = function()
    setupPinRendering()
    options.iconScale = 100
    ns.MapPins:Refresh("size")
    assert(pin.width == 24 and pin.height == 24)
    options.iconScale = 50
    ns.MapPins:Refresh("size")
    assert(pin.width == 12 and pin.height == 12)
    options.iconScale = 150
    ns.MapPins:Refresh("size")
    assert(pin.width == 36 and pin.height == 36)
end

cases["map_pins_runtime.gamepad_hover_uses_saved_pin_center_and_private_tooltip"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    pin._fqpGetCenter = function() return 320, 240 end
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 325, 240 end
    SoftCursor = { IsShown = function() return true end }
    assert(ns.MapPins:FindGamepadCursorPin() == pin, "addon hover lookup must still find the pin")
    local gamepadTooltipShown, gamepadTooltipHidden = 0, 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() gamepadTooltipShown = gamepadTooltipShown + 1 end,
                Hide = function() gamepadTooltipHidden = gamepadTooltipHidden + 1 end,
            }
        end
        return { SetScript = function() end }
    end
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    ns.MapPins:UpdateGamepadHover()
    assert(gamepadTooltipShown == 1, "gamepad hover must display the private quest tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 400, 240 end
    assert(ns.MapPins:FindGamepadCursorPin() == nil, "cursor lookup must ignore pins outside Blizzard's hover radius")
    ns.MapPins:UpdateGamepadHover()
    assert(gamepadTooltipHidden == 1, "leaving the pin must hide the private quest tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 320, 240 end
    SoftCursor.IsShown = function() return false end
    assert(ns.MapPins:FindGamepadCursorPin() == nil, "cursor lookup must stop when the soft cursor is hidden")
    SoftCursor.IsShown = function() return true end
    GetCVarBool = function() return true end
    assert(ns.MapPins:FindGamepadCursorPin() == pin, "addon map tooltips must remain available when Blizzard suppresses its gamepad tooltips")
    GetCVarBool = nil
end

cases["map_pins_runtime.gamepad_hover_uses_normalized_world_map_cursor"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.5, 0.5 end

    assert(WorldMapFrame.ScrollContainer.GetGamepadCursorPosition == nil,
        "the Forever client exposes normalized cursor position on WorldMapFrame")
    assert(ns.MapPins:FindGamepadCursorPin() == pin,
        "gamepad hover must resolve a pin using the normalized map cursor")
end

cases["map_pins_runtime.gamepad_ui_mouse_hover_uses_map_cursor"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return true end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end
    GetCVarBool = function() return true end

    local tooltipShown = 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetAnchorType = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() tooltipShown = tooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "mouse hover inside the map must show an addon tooltip while Gamepad UI is enabled")
end

cases["map_pins_runtime.gamepad_ui_mouse_enter_defers_to_private_tooltip_poll"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return false end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end

    local globalTooltipOwners, privateTooltipShown = 0, 0
    GameTooltip = {
        SetOwner = function() globalTooltipOwners = globalTooltipOwners + 1 end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
    }
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() privateTooltipShown = privateTooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    assert(globalTooltipOwners == 0,
        "Gamepad UI must defer mouse-enter tooltips even when the soft cursor is hidden")
    ns.MapPins:UpdateGamepadHover()
    assert(privateTooltipShown == 1,
        "the cursor poll must show the private tooltip after the mouse-enter event")
end

cases["map_pins_runtime.gamepad_mode_transition_replaces_existing_mouse_tooltip"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    local gamepadEnabled = false
    InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
    SoftCursor = { IsShown = function() return false end, IsMoving = function() return false end }
    WorldMapFrame.GetNormalizedGamepadCursorPosition = function() return 0.8, 0.8 end
    WorldMapFrame.GetNormalizedCursorPosition = function() return 0.5, 0.5 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end

    local privateTooltipShown = 0
    CreateFrame = function(frameType)
        if frameType == "GameTooltip" then
            return {
                SetOwner = function() end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() privateTooltipShown = privateTooltipShown + 1 end,
                Hide = function() end,
            }
        end
        return { SetScript = function() end }
    end

    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    gamepadEnabled = true
    ns.MapPins:UpdateGamepadHover()
    assert(privateTooltipShown == 1,
        "the gamepad poll must replace an existing mouse tooltip when the input mode changes")
end

cases["map_pins_runtime.pins_never_use_blizzard_pin_pool"] = function()
    setupPinRendering()
    local previousMixin = MapCanvasPinMixin
    local previousAcquirePin = WorldMapFrame.AcquirePin
    local previousRemovePin = WorldMapFrame.RemovePin
    local previousInputUtil = InputUtil
    local acquireCalls, removeCalls = 0, 0
    -- The client exposes these; calling AcquirePin from addon code taints the
    -- canvas pin pools even when the acquisition itself succeeds.
    MapCanvasPinMixin = { GetCenter = function(self) return self.centerX, self.centerY end }
    WorldMapFrame.AcquirePin = function()
        acquireCalls = acquireCalls + 1
        error("map pins must not use WorldMapFrame:AcquirePin")
    end
    WorldMapFrame.RemovePin = function() removeCalls = removeCalls + 1 end

    -- Mouse mode on a non-stitched map: the path that used to acquire one of
    -- Blizzard's pins and taint the canvas pin pools.
    InputUtil = { IsGamepadUIEnabled = function() return false end }
    ns.MapPins:Refresh("mouse-test")
    assert(acquireCalls == 0, "ordinary map pins must stay out of Blizzard's pin pool")
    assert(pin and pin.parent == mapCanvas,
        "pins must be ordinary frames parented to the map canvas")
    assert(pin.scripts.OnClick == ForeverQuestPinsMapPinMixin.OnClick,
        "ordinary pins must keep the addon's click handler")

    ns.MapPins:Clear()
    assert(removeCalls == 0, "ordinary pins must not call WorldMapFrame:RemovePin")
    assert(pin.parent == UIParent,
        "released pins must leave the canvas so Blizzard's pin work never walks addon frames")

    InputUtil = { IsGamepadUIEnabled = function() return true end }
    ns.MapPins:Refresh("gamepad-test")
    assert(acquireCalls == 0, "gamepad pins must stay out of Blizzard's pin pool")

    WorldMapFrame.AcquirePin = previousAcquirePin
    WorldMapFrame.RemovePin = previousRemovePin
    MapCanvasPinMixin = previousMixin
    InputUtil = previousInputUtil
end

cases["map_pins_runtime.gamepad_pins_clear_discovered_map_art"] = function()
    setupPinRendering()
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    WorldMapFrame.GetPinFrameLevelsManager = function()
        return {
            GetValidFrameLevel = function(_, frameLevelType)
                if frameLevelType == "PIN_FRAME_LEVEL_AREA_POI" then return 2023 end
                return 2000
            end,
        }
    end

    ns.MapPins:Refresh("gamepad-test")
    assert(pin, "gamepad pins must stay ordinary frames")
    assert(pin.frameLevel == 2023,
        "gamepad pins must use the map's pin level so discovered-area art cannot cover them")

    WorldMapFrame.GetPinFrameLevelsManager = nil
    InputUtil = nil
    ns.MapPins:Refresh("gamepad-test")
    assert(pin.frameLevel == 401,
        "a client without the pin level table must keep the canvas offset")

    OpenMapAPI = {
        IsStitched = function() return true end,
        WorldFromMap = function(_, x, y) return x, y end,
        MapFromWorld = function(_, u, v) return u, v end,
        ArtTopLevel = function() return 9900 end,
    }
    ns.MapPins:Refresh("gamepad-test")
    assert(pin.frameLevel == 9901,
        "stitched map art levels must stay above the pin floor")
end

cases["map_pins_runtime.gamepad_cursor_poll_owns_tooltip_lifecycle"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("gamepad-test")
    local tooltipShown, tooltipHidden, tooltipOwner, tooltipName = 0, 0, nil, nil
    CreateFrame = function(frameType, name)
        if frameType == "GameTooltip" then
            tooltipName = name
            return {
                SetOwner = function(_, owner, anchor)
                    tooltipOwner = { owner = owner, anchor = anchor }
                end,
                SetFrameStrata = function() end,
                SetText = function() end,
                AddLine = function() end,
                Show = function() tooltipShown = tooltipShown + 1 end,
                Hide = function() tooltipHidden = tooltipHidden + 1 end,
            }
        end
        return { SetScript = function() end }
    end
    local timerQueue = {}
    C_Timer = { After = function(_, callback) timerQueue[#timerQueue + 1] = callback end }
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    SoftCursor = { IsShown = function() return true end }
    local pinX, pinY = pin._fqpGetCenter(pin)
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return pinX, pinY end
    ForeverQuestPinsMapPinMixin.OnMouseEnter(pin)
    assert(#timerQueue == 0 and tooltipShown == 0,
        "gamepad pin enter must leave tooltip ownership to the cursor poll")
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "the cursor poll must show the quest tooltip for the pin under the cursor")
    assert(tooltipOwner and tooltipOwner.owner == pin and tooltipOwner.anchor == "ANCHOR_RIGHT",
        "the private gamepad tooltip must be anchored to the hovered pin")
    assert(tooltipName == "ForeverQuestPinsGamepadTooltip",
        "the private tooltip must have a frame name so its template text regions are created")
    ForeverQuestPinsMapPinMixin.OnMouseLeave(pin)
    assert(tooltipHidden == 0, "pin leave must not immediately hide the gamepad tooltip")
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipShown == 1, "the cursor poll must not duplicate the active pin tooltip")
    WorldMapFrame.ScrollContainer.GetGamepadCursorPosition = function() return 300, 300 end
    ns.MapPins:UpdateGamepadHover()
    assert(tooltipHidden == 1, "moving the gamepad cursor off the pin must hide the tooltip")
end

cases["map_pins_runtime.repeatable_pin_is_blue_and_hidden_when_opted_out"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("test")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal:blue")
    assert(pin.Texture.desaturated == true)
    assert(pin.Texture.color[1] == 0.12 and pin.Texture.color[2] == 0.72 and pin.Texture.color[3] == 1.00)
    options.showRepeatable = false
    ns.MapPins:Refresh("test-filter")
    assert(ns.MapPins:GetStatus().count == 0)
    assert(ns.MapPins:GetStatus().paintedIDs[101] == nil)
end

cases["map_pins_runtime.repeatable_plus_normal_stack_stays_yellow_and_labels_repeatable"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = { mapID = 1, x = 50, y = 50, title = "Repeatable test quest", repeatable = true },
        [102] = { mapID = 1, x = 50, y = 50, title = "Normal test quest" },
    }
    ns.ByMap = { [1] = { 101, 102 } }
    ns.MapPins:Refresh("mixed-stack")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("Repeatable test quest (Repeatable)"), "the repeatable quest must be named in the stack")
    assert(tooltipHas("Normal test quest"), "the normal quest must keep its plain title")
end

cases["map_pins_runtime.normal_stack_stays_yellow"] = function()
    setupPinRendering()
    ns.Quests = {
        [102] = { mapID = 1, x = 50, y = 50, title = "Normal test quest" },
    }
    ns.ByMap = { [1] = { 102 } }
    ns.MapPins:Refresh("normal-stack")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal")
end

cases["map_pins_runtime.book_quest_pins_honor_show_books"] = function()
    setupPinRendering()
    assert(loadfile("Database/BookQuests.lua"))("ForeverQuestPins", ns)
    ns.Quests = {
        [78124] = { mapID = 1, x = 50, y = 50, title = "Nar'thalas Almanac", minLevel = 1 },
    }
    ns.ByMap = { [1] = { 78124 } }
    options.showBooks = true
    options.showBookIcon = true
    ns.MapPins:Refresh("book-on")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "Interface\\AddOns\\ForeverQuestPins\\Media\\QuestBook")
    assert(not pin.Texture.texCoord or (pin.Texture.texCoord[1] == 0 and pin.Texture.texCoord[2] == 1),
        "the bundled book icon must not be cropped")
    assert(pin.Fill.shown == true, "the book pin must draw its drop shadow")
    assert(pin.Fill.file == "Interface\\AddOns\\ForeverQuestPins\\Media\\QuestBook")
    assert(pin.Fill.color[1] == 0 and pin.Fill.color[2] == 0 and pin.Fill.color[3] == 0
        and pin.Fill.color[4] == 0.38)
    options.showBooks = false
    ns.MapPins:Refresh("book-off")
    assert(ns.MapPins:GetStatus().count == 0)
    assert(ns.MapPins:GetStatus().paintedIDs[78124] == nil)
end

cases["map_pins_runtime.book_pin_mixed_with_normal_keeps_quest_icon"] = function()
    setupPinRendering()
    assert(loadfile("Database/BookQuests.lua"))("ForeverQuestPins", ns)
    ns.Quests = {
        [78124] = { mapID = 1, x = 50, y = 50, title = "Nar'thalas Almanac", minLevel = 1 },
        [102] = { mapID = 1, x = 50, y = 50, title = "Normal test quest" },
    }
    ns.ByMap = { [1] = { 78124, 102 } }
    options.showBooks = true
    options.showBookIcon = true
    ns.MapPins:Refresh("book-mixed")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal")
end

cases["map_pins_runtime.book_pin_icon_is_off_by_default"] = function()
    setupPinRendering()
    assert(loadfile("Database/BookQuests.lua"))("ForeverQuestPins", ns)
    ns.Quests = {
        [78124] = { mapID = 1, x = 50, y = 50, title = "Nar'thalas Almanac", minLevel = 1 },
    }
    ns.ByMap = { [1] = { 78124 } }
    options.showBooks = true
    ns.MapPins:Refresh("book-default")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(ns.MapPins:GetStatus().icon == "atlas:QuestNormal")
    assert(pin.Fill.shown == false, "the book shadow must stay off without the icon option")
end

cases["map_pins_runtime.repeatable_does_not_override_special_categories"] = function()
    setupPinRendering()
    UnitClass = function() return "Mage", "MAGE", 8 end
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    local function RefreshWith(extra)
        ns.Quests = {
            [101] = { mapID = 1, x = 50, y = 50, title = "Repeatable test quest", repeatable = true },
            [103] = extra,
        }
        ns.ByMap = { [1] = { 101, 103 } }
        ns.MapPins:Refresh("special-stack")
        assert(ns.MapPins:GetStatus().count == 1)
        local icon = ns.MapPins:GetStatus().icon
        assert(icon == "atlas:QuestNormal",
            "repeatable must not mask a special category: " .. tostring(icon))
        return icon
    end
    assert(RefreshWith({ mapID = 1, x = 50, y = 50, title = "Instance", isInstanceQuest = true }))
    assert(RefreshWith({ mapID = 1, x = 50, y = 50, title = "Class", classes = { 8 } }))
    assert(RefreshWith({ mapID = 1, x = 50, y = 50, title = "Profession", requireSkill = 171 }))
end

cases["map_pins_runtime.nearby_spawn_points_share_one_counted_pin_and_hover_cloud"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = {
            mapID = 1, x = 50, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 50.4, 50.1, 1 }, { 50.8, 50.2, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cluster")
    local status = ns.MapPins:GetStatus()
    assert(status.count == 1, "cluster pins " .. tostring(status.count))
    assert(pin.spawnCount == 3, "spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil, "count badge should not be drawn")
    assert(status.cloudCount == 0, "cloud before hover " .. tostring(status.cloudCount))

    pin.scripts.OnEnter(pin)
    assert(status.cloudCount == 3, "cloud after hover " .. tostring(status.cloudCount))
    assert(tooltipHas("3 possible spawn locations"), "tooltip count line")
    pin.scripts.OnLeave(pin)
    assert(status.cloudCount == 0, "cloud after leave " .. tostring(status.cloudCount))
end

cases["pin_filters_runtime.spawn_cluster_option_defaults_on_and_persists_off"] = function()
    ns = {}
    C_CVar = nil
    ForeverQuestPinsDB = nil
    ForeverQuestPinsCharDB = nil
    ForeverQuestPinsDB_Settings = nil
    ForeverQuestPinsCharacterSettings = nil
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()
    assert(ns.GetOption("showSpawnClusters") == true)
    ns.SetOption("showSpawnClusters", false)
    ns.db = nil
    ns.InitSettings()
    assert(ns.GetOption("showSpawnClusters") == false)
end

cases["config_runtime.books_default_off_and_slash_toggle_persists"] = function()
    ns = {}
    C_CVar = nil
    ForeverQuestPinsDB = nil
    ForeverQuestPinsCharDB = nil
    ForeverQuestPinsDB_Settings = nil
    ForeverQuestPinsCharacterSettings = nil
    GetLocale = function() return "enUS" end
    local printed = {}
    print = function(message) printed[#printed + 1] = tostring(message) end
    assert(loadfile("Localization.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()
    assert(ns.GetOption("showBooks") == false)
    assert(ns.GetOption("showBookIcon") == false)
    ns.SlashCommand("books")
    assert(ns.GetOption("showBooks") == true)
    assert(printed[#printed]:find("Show collectible book quest pins: on", 1, true),
        "slash command must print the current state: " .. tostring(printed[#printed]))
    ns.db = nil
    ns.InitSettings()
    assert(ns.GetOption("showBooks") == true)
    ns.SlashCommand("books")
    assert(ns.GetOption("showBooks") == false)
    assert(printed[#printed]:find("Show collectible book quest pins: off", 1, true),
        "the second toggle must print the off state: " .. tostring(printed[#printed]))
    ns.SetOption("showBookIcon", true)
    ns.db = nil
    ns.InitSettings()
    assert(ns.GetOption("showBookIcon") == true, "the book icon option must survive a reload")
end

cases["map_pins_runtime.spawn_cloud_dots_use_map_pixels"] = function()
    setupPinRendering()
    -- Zoomed canvas: the map scales the canvas, so cloud dots must keep using
    -- plain map pixels instead of the pin's counter-scale.
    mapCanvas.scale = 2
    ns.Quests = {
        [101] = {
            mapID = 1, x = 50, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 50.4, 50, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cloud")
    -- The hovered pin sits at the canvas point for (0.5, 0.5) at zoom 2.
    pin.GetEffectiveScale = function() return 1 end
    pin.centerX, pin.centerY = 1000, 0
    pin.scripts.OnEnter(pin)
    assert(#cloudFrames == 2, "cloud dots " .. tostring(#cloudFrames))
    assert(cloudFrames[1].strata == "FULLSCREEN_DIALOG", "dot strata " .. tostring(cloudFrames[1].strata))
    local anchor = cloudFrames[1]
    local second = cloudFrames[2]
    assert(anchor.point[2] == UIParent and anchor.point[3] == "BOTTOMLEFT")
    assert(math.abs(anchor.point[4] - 1000) < 0.001, "anchor dot x " .. tostring(anchor.point[4]))
    assert(math.abs(anchor.point[5] - 0) < 0.001, "anchor dot y " .. tostring(anchor.point[5]))
    assert(math.abs(second.point[4] - 1008) < 0.001, "second dot x " .. tostring(second.point[4]))
    assert(math.abs(second.point[5] - 0) < 0.001, "second dot y " .. tostring(second.point[5]))
end

cases["map_pins_runtime.spawn_cloud_tracks_scaled_map_and_ui"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = { mapID = 1, x = 50, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 50.4, 50.2, 1 } } },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true
    ns.MapPins:Refresh("scaled-spawn-cloud")
    UIParent.GetEffectiveScale = function() return 0.8 end
    local mapScale, zoom = 1, 1
    mapCanvas.GetEffectiveScale = function() return 0.8 * mapScale * zoom end
    pin.GetEffectiveScale = function() return 0.8 * mapScale end
    for _, scenario in ipairs({ { 0.7, 1 }, { 1.4, 1 }, { 0.7, 2 }, { 1.4, 2 } }) do
        mapScale, zoom = scenario[1], scenario[2]
        -- The center returned by a scaled frame is in that frame's own units.
        pin.centerX, pin.centerY = 600 / mapScale, 400 / mapScale
        pin.scripts.OnEnter(pin)
        local anchor, second = cloudFrames[1], cloudFrames[2]
        assert(math.abs(anchor.point[4] - 600) < 0.001, "anchor x at scale " .. mapScale)
        assert(math.abs(anchor.point[5] - 400) < 0.001, "anchor y at scale " .. mapScale)
        assert(math.abs(second.point[4] - (600 + 4 * mapScale * zoom)) < 0.001, "spawn x at scale " .. mapScale)
        assert(math.abs(second.point[5] - (400 - 1.6 * mapScale * zoom)) < 0.001, "spawn y at scale " .. mapScale)
    end
end

cases["map_pins_runtime.tooltip_lists_duplicate_quest_titles_once"] = function()
    setupPinRendering()
    local crateIDs = { 91899, 91900, 91901, 91902, 91904, 91905, 91906, 91907 }
    local titles, levels = {}, {}
    local ids = {}
    ns.Quests = {}
    for i = 1, #crateIDs do
        local questID = crateIDs[i]
        ns.Quests[questID] = { mapID = 1, x = 50, y = 50, minLevel = 1 }
        ids[#ids + 1] = questID
        titles[questID] = "A Sealed Crate"
        levels[questID] = 60
    end
    ns.Quests[93862] = { mapID = 1, x = 50, y = 50, minLevel = 1 }
    ids[#ids + 1] = 93862
    titles[93862] = "Crate Return"
    levels[93862] = 60
    -- The same title at another level is a different line, not a duplicate.
    ns.Quests[99999] = { mapID = 1, x = 50, y = 50, minLevel = 1 }
    ids[#ids + 1] = 99999
    titles[99999] = "A Sealed Crate"
    levels[99999] = 50
    ns.ByMap = { [1] = ids }

    ns.GetQuestTitle = function(questID) return titles[questID] end
    ns.GetQuestDifficultyLevel = function(questID) return levels[questID] end

    ns.MapPins:Refresh("duplicate-titles")
    assert(ns.MapPins:GetStatus().count == 1, "quests share one pin")
    assert(#pin.quests == #ids, "pin keeps every quest: " .. tostring(#pin.quests))

    local function countLine(text)
        local total = 0
        for i = 1, #tooltipLines do
            if tooltipLines[i] == text then
                total = total + 1
            end
        end
        return total
    end

    pin.scripts.OnEnter(pin)
    assert(countLine("[60] A Sealed Crate") == 1, "duplicate title lines")
    assert(countLine("[50] A Sealed Crate") == 1, "same title at another level")
    assert(countLine("[60] Crate Return") == 1, "distinct title line")

    options.debug = true
    pin.scripts.OnEnter(pin)
    local debugIDs = 0
    for i = 1, #tooltipLines do
        if tooltipLines[i]:find("^Quest ID: ") then
            debugIDs = debugIDs + 1
        end
    end
    assert(debugIDs == #ids, "debug keeps every quest id: " .. tostring(debugIDs))
end

cases["map_pins_runtime.stacked_quests_keep_separate_spawn_counts"] = function()
    setupPinRendering()
    local coords = { { 50, 50, 1 }, { 50.4, 50.1, 1 }, { 50.8, 50.2, 1 } }
    ns.Quests = {
        [101] = { mapID = 1, x = 50, y = 50, title = "First quest", coords = coords },
        [102] = { mapID = 1, x = 50, y = 50, title = "Second quest", coords = coords },
    }
    ns.ByMap = { [1] = { 101, 102 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-stack")
    local status = ns.MapPins:GetStatus()
    assert(status.count == 1, "stacked pins " .. tostring(status.count))
    assert(status.paintedIDs[101] and status.paintedIDs[102])
    assert(pin.spawnCount == 3, "stacked spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil, "count badge should not be drawn")
end

cases["map_pins_runtime.spawn_points_include_primary_coord"] = function()
    setupPinRendering()
    -- The database stores the first spawn as mapID/x/y and only the remaining
    -- spawns in coords. All of them belong in the pin's spawn list.
    ns.Quests = {
        [101] = {
            mapID = 1, x = 20, y = 50, title = "Spawn test",
            coords = { { 50, 50, 1 }, { 80, 50, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = false

    ns.MapPins:Refresh("spawn-primary")
    assert(ns.MapPins:GetStatus().count == 1)
    assert(pin.spawnCount == 3, "primary spawn missing: " .. tostring(pin.spawnCount))
end

cases["map_pins_runtime.unexplored_pins_follow_option"] = function()
    setupPinRendering()
    ns.Quests = { [101] = { mapID = 1, x = 50, y = 50, title = "Unexplored test" } }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = false
    CreateVector2D = function(x, y) return { x = x, y = y } end
    C_MapExplorationInfo = {
        GetExploredAreaIDsAtPosition = function() return nil end,
    }

    options.showUnexplored = true
    ns.MapPins:Refresh("unexplored-shown")
    assert(ns.MapPins:GetStatus().count == 1)

    options.showUnexplored = false
    ns.MapPins:Refresh("unexplored-hidden")
    assert(ns.MapPins:GetStatus().count == 0)

    C_MapExplorationInfo.GetExploredAreaIDsAtPosition = function() return { 1 } end
    ns.MapPins:Refresh("explored-shown")
    assert(ns.MapPins:GetStatus().count == 1)
end

cases["map_pins_runtime.enemy_capital_spawns_hidden_for_player_faction"] = function()
    setupPinRendering()
    -- One quest offered in both capitals; each faction should see only its
    -- own city spawn.
    ns.Quests = {
        [101] = { mapID = 1454, x = 20, y = 50, coords = { { 80, 50, 1453 } } },
    }
    ns.ByMap = { [1454] = { 101 }, [1453] = { 101 } }
    ns.ProjectToViewedMap = function(_, x, y) return x / 100, y / 100 end
    options.showSpawnClusters = false

    ns.GetPlayerFaction = function() return "Horde" end
    ns.MapPins:Refresh("enemy-city")
    assert(ns.MapPins:GetStatus().count == 1 and pin.spawnCount == 1)
    assert(pin.nx == 0.2)

    ns.GetPlayerFaction = function() return "Alliance" end
    ns.MapPins:Refresh("enemy-city")
    assert(ns.MapPins:GetStatus().count == 1 and pin.spawnCount == 1)
    assert(pin.nx == 0.8)

    ns.GetPlayerFaction = nil
    ns.MapPins:Refresh("enemy-city")
    assert(ns.MapPins:GetStatus().count == 1 and pin.spawnCount == 2)

    -- A single spawn on the other faction's city map is kept; dungeon and
    -- neutral starts use that shape.
    ns.Quests = { [102] = { mapID = 1455, x = 60, y = 50 } }
    ns.ByMap = { [1455] = { 102 } }
    ns.GetPlayerFaction = function() return "Horde" end
    ns.MapPins:Refresh("enemy-city")
    assert(ns.MapPins:GetStatus().count == 1 and ns.MapPins:GetStatus().paintedIDs[102])
end

cases["map_pins_runtime.spawn_cluster_count_is_capped_per_quest"] = function()
    setupPinRendering()
    local coords = {}
    for i = 1, 10 do
        coords[i] = { 5 + (i * 10), 50, 1 }
    end
    ns.Quests = {
        [101] = { mapID = 1, x = 5, y = 50, title = "Spawn test", coords = coords },
    }
    ns.ByMap = { [1] = { 101 } }
    options.showSpawnClusters = true

    ns.MapPins:Refresh("spawn-cap")
    assert(ns.MapPins:GetStatus().count == 6, "capped cluster pins " .. tostring(ns.MapPins:GetStatus().count))
end

cases["map_pins_runtime.distant_spawn_points_cluster_or_collapse_to_one_pin"] = function()
    setupPinRendering()
    ns.Quests = {
        [101] = {
            mapID = 1, x = 20, y = 50, title = "Spawn test",
            coords = { { 20, 50, 1 }, { 50, 50, 1 }, { 80, 50, 1 } },
        },
    }
    ns.ByMap = { [1] = { 101 } }

    options.showSpawnClusters = true
    ns.MapPins:Refresh("spawn-clusters")
    assert(ns.MapPins:GetStatus().count == 3, "distant cluster pins " .. tostring(ns.MapPins:GetStatus().count))
    assert(pin.spawnCount == 1)
    assert(pin.Badge == nil)

    options.showSpawnClusters = false
    ns.MapPins:Refresh("spawn-single")
    assert(ns.MapPins:GetStatus().count == 1, "single pin count " .. tostring(ns.MapPins:GetStatus().count))
    assert(pin.spawnCount == 3, "single pin spawn count " .. tostring(pin.spawnCount))
    assert(pin.Badge == nil)
    assert(pin.nx == 0.5 and pin.ny == 0.5, "anchor " .. tostring(pin.nx) .. "," .. tostring(pin.ny))

    pin.scripts.OnEnter(pin)
    assert(ns.MapPins:GetStatus().cloudCount == 0)
    assert(tooltipHas("3 possible spawn locations"), "single pin tooltip count line")
    pin.scripts.OnClick(pin, "LeftButton")
    assert(trackedQuestID == 101)
    assert(trackedData.mapID == 1 and trackedData.x == 50 and trackedData.y == 50)
end

cases["localization.client_locale_and_fallback"] = function()
    local spanishKeys
    local commands = {
        frFR = "Commandes", ptBR = "Comandos", zhCN = "命令", zhTW = "命令",
        koKR = "명령", itIT = "Comandi", ruRU = "Команды",
    }
    for _, locale in ipairs({ "enUS", "esES", "esMX", "deDE", "frFR", "ptBR", "zhCN", "zhTW", "koKR", "itIT", "ruRU", "unknown" }) do
        local localNS = {}
        GetLocale = function() return locale end
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        if locale == "esES" or locale == "esMX" then
            assert(localNS.L["Show quest start pins"] == "Mostrar marcadores de inicio de misión")
            assert(localNS.L["Quest %d (title unavailable)"]:format(123) == "Misión 123 (título no disponible)")
            local festival = localNS.L["Event quests appear only while the event is live. Darkmoon Faire stays hidden on Forever."]
            assert(festival:find("Feria de la Luna Negra", 1, true))
            assert(localNS.L["Dungeon / raid quest"]:find(locale == "esES" and "mazmorra" or "calabozo", 1, true))
        elseif locale == "deDE" then
            assert(localNS.L["Show quest start pins"] == "Queststart-Markierungen anzeigen")
            assert(localNS.L["Quest %d (title unavailable)"]:format(123) == "Quest 123 (Titel nicht verfügbar)")
            assert(localNS.L["Dungeon / raid quest"] == "Dungeon- / Schlachtzugsquest")
        elseif locale == "enUS" or locale == "unknown" then
            assert(localNS.L["Show quest start pins"] == "Show quest start pins")
        end
        if locale == "esES" then spanishKeys = localNS.L end
        if locale ~= "enUS" and locale ~= "unknown" then
            if commands[locale] then
                assert(localNS.L["Commands:"]:find(commands[locale], 1, true), locale)
            end
            for key in pairs(spanishKeys) do
                assert(rawget(localNS.L, key), "missing " .. locale .. " translation: " .. key)
            end
            for english, translated in pairs(localNS.L) do
                local function formats(value)
                    local found = {}
                    for token in value:gmatch("%%[%+%-%.%d]*[a-zA-Z%%]") do found[#found + 1] = token end
                    return table.concat(found, ",")
                end
                assert(formats(english) == formats(translated), english)
                if english:find("/fqp", 1, true) then
                    assert(translated:find("/fqp", 1, true), locale .. ": " .. english)
                end
                local command = english:match("^%s+/fqp%s+([%a]+)")
                if command then
                    assert(translated:find("/fqp " .. command, 1, true), locale .. ": " .. english)
                end
            end
        end
        assert(localNS.L["Missing translation"] == "Missing translation")
    end
end

cases["localization.quest_categories_and_help"] = function()
    local expected = {
        zhCN = { "职业任务", "专业任务", "主城" },
        zhTW = { "職業任務", "專業任務", "主城" },
        koKR = { "직업 퀘스트", "전문 기술 퀘스트", "대도시" },
    }
    for locale, values in pairs(expected) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(localNS.L["Class quest"] == values[1], locale)
        assert(localNS.L["Profession quest"] == values[2], locale)
        assert(localNS.L["  /fqp wareffort Toggle AQ war effort pins in capitals (off by default)"]:find(values[3], 1, true), locale)
    end
    for locale, city in pairs({ frFR = "capitales", ptBR = "capitais", itIT = "capitali", ruRU = "столицах" }) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(localNS.L["  /fqp wareffort Toggle AQ war effort pins in capitals (off by default)"]:find(city, 1, true), locale)
    end
    for locale, skip in pairs({ frFR = "ignorer", itIT = "ignorare" }) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(localNS.L["Accept quests automatically when you talk to an NPC. Hold Shift to skip."]:find(skip, 1, true), locale)
        assert(localNS.L["Turn in completed quests automatically. Does not pick when there are multiple rewards. Hold Shift to skip."]:find(skip, 1, true), locale)
    end
    for _, locale in ipairs({ "esES", "deDE", "frFR", "ptBR", "zhCN", "zhTW", "koKR", "itIT", "ruRU" }) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(localNS.L["Show collectible book quest pins"] ~= "Show collectible book quest pins", locale)
        assert(localNS.L["Show book icon for book quest pins"] ~= "Show book icon for book quest pins", locale)
        assert(localNS.L["Show all quests below you"] ~= "Show all quests below you", locale)
        assert(localNS.L["Replaces the yellow marker with a book icon when every quest on the pin is a library book pickup."] ~= "Replaces the yellow marker with a book icon when every quest on the pin is a library book pickup.", locale)
        assert(localNS.L["Collectible book quest"] ~= "Collectible book quest", locale)
        assert(localNS.L["  /fqp books    Toggle collectible book quest pins (off by default)"]:find("/fqp books", 1, true), locale)
        assert(localNS.L["(Repeatable)"] ~= "(Repeatable)", locale)
    end
end

cases["localization.map_legend_and_help"] = function()
    for _, locale in ipairs({ "frFR", "ptBR", "zhCN", "zhTW", "koKR", "itIT", "ruRU" }) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        local questLabels = { ptBR = "Missão", zhCN = "任务", zhTW = "任務", koKR = "퀘스트", itIT = "Missione" }
        if questLabels[locale] then
            assert(localNS.L["Quest"] == questLabels[locale], locale)
            assert(localNS.L["Quest "] == questLabels[locale] .. " ", locale)
        end
        if locale == "frFR" then
            assert(localNS.L["Show AQ war effort pins"] == "Afficher les marqueurs de l’effort de guerre d’AQ")
            assert(localNS.L["Would pin on map "] == "Serait affiché sur la carte ")
            assert(localNS.L["List quests you can accept or turn in from this NPC (accept eligibility matches start pins; turn-ins require an active, complete quest)."]:find("mêmes conditions", 1, true))
        elseif locale == "koKR" then
            assert(localNS.L["Ordinary quest starts without repeatable, seasonal, AQ, class, profession, or dungeon / raid categories."]:find("전문 기술", 1, true))
        elseif locale == "zhCN" then
            assert(localNS.L["Ordinary quest starts without repeatable, seasonal, AQ, class, profession, or dungeon / raid categories."]:find("职业、专业", 1, true))
        elseif locale == "zhTW" then
            assert(localNS.L["Ordinary quest starts without repeatable, seasonal, AQ, class, profession, or dungeon / raid categories."]:find("職業、專業", 1, true))
        end
    end
end

cases["config_runtime.taint_scan_names_the_addon_that_wrote_a_field"] = function()
    local ns = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    local lines = {}
    print = function(line) lines[#lines + 1] = line end
    WorldMapFrame = { mapID = 1427, pinPools = {} }
    issecurevariable = function(tbl, key)
        if tbl == WorldMapFrame and key == "mapID" then
            return false, "ForeverQuestPins"
        end
        return true
    end
    ns.db = {}
    ns.RunTaintScan()
    local text = table.concat(lines, "\n")
    assert(text:find("WorldMapFrame.mapID <- ForeverQuestPins", 1, true), text)
    assert(ns.db._taintScan and ns.db._taintScan:find("WorldMapFrame.mapID", 1, true),
        "the report is saved so it can be read after a reload")
end

cases["localization.level_gap_help"] = function()
    local expected = {
        ptBR = { "número informado", "abaixo", "acima" },
        ruRU = { "указанное число", "ниже", "выше" },
    }
    for locale, words in pairs(expected) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(loadfile("Config.lua"))("ForeverQuestPins", localNS)
        local lines = {}
        print = function(line) lines[#lines + 1] = line end
        localNS.SlashCommand("help")
        local text = table.concat(lines, "\n")
        for _, word in ipairs(words) do
            assert(text:find(word, 1, true), locale .. ": " .. word)
        end
    end
end

cases["localization.turnin_toggle_output"] = function()
    local expected = {
        frFR = { "Remettre les quêtes automatiquement", "activé", "désactivé" },
        ptBR = { "Entregar missões automaticamente", "ativado", "desativado" },
        zhCN = { "自动交付任务", "已开启", "已关闭" },
        zhTW = { "自動回報任務", "已開啟", "已關閉" },
        koKR = { "퀘스트 자동 제출", "켜짐", "꺼짐" },
        itIT = { "Consegna automaticamente le missioni", "attivato", "disattivato" },
        ruRU = { "Автоматическая сдача заданий", "включено", "выключено" },
    }
    for locale, values in pairs(expected) do
        GetLocale = function() return locale end
        local localNS = {}
        assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
        assert(loadfile("Config.lua"))("ForeverQuestPins", localNS)
        local value, lines = false, {}
        localNS.GetOption = function() return value end
        localNS.SetOption = function(_, newValue) value = newValue end
        print = function(line) lines[#lines + 1] = line end
        localNS.SlashCommand("turnin")
        assert(lines[1]:find(values[1] .. ": " .. values[2], 1, true), locale .. ": " .. lines[1])
        localNS.SlashCommand("turnin")
        assert(lines[2]:find(values[1] .. ": " .. values[3], 1, true), locale .. ": " .. lines[2])
    end
end

cases["localization.german_command_output"] = function()
    GetLocale = function() return "deDE" end
    local localNS = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
    assert(loadfile("Config.lua"))("ForeverQuestPins", localNS)
    local lines = {}
    print = function(line) lines[#lines + 1] = line end
    localNS.SlashCommand("help")
    assert(table.concat(lines, "\n"):find("Befehle:", 1, true))
    lines = {}
    localNS.Quests = { [1] = { mapID = 1, x = 10, y = 20 } }
    localNS.IsQuestAvailable = function() return true, "ok" end
    localNS.IsQuestFlaggedCompleted = function() return false end
    localNS.IsOnQuest = function() return false end
    localNS.PrintQuestWhy(1)
    assert(table.concat(lines, "\n"):find("Quest 1: würde angezeigt (ok)", 1, true))
end

cases["quest_info_runtime.localized_tag_uses_static_classification"] = function()
    dofile("tests/fixtures/quest_info.lua")
    GetLocale = function() return "esES" end
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    C_QuestLog.GetQuestTagInfo = function() return { tagName = "Mazmorra" } end
    assert(ns.IsInstanceQuest(101, { isInstanceQuest = true }))
    assert(not ns.IsInstanceQuest(102, {}))
end

cases["localization.spanish_command_output"] = function()
    GetLocale = function() return "esMX" end
    local localNS = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", localNS)
    assert(loadfile("Config.lua"))("ForeverQuestPins", localNS)
    local lines = {}
    print = function(line) lines[#lines + 1] = line end
    localNS.SlashCommand("help")
    assert(table.concat(lines, "\n"):find("Comandos:", 1, true))
    lines = {}
    localNS.Quests = { [1] = { mapID = 1, x = 10, y = 20 } }
    localNS.IsQuestAvailable = function() return true, "ok" end
    localNS.IsQuestFlaggedCompleted = function() return false end
    localNS.IsOnQuest = function() return false end
    localNS.PrintQuestWhy(1)
    assert(table.concat(lines, "\n"):find("Misión 1: se mostraría (ok)", 1, true))
end

cases["events_runtime.test_window_boundaries_and_new_year_wrap"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [1] = "Winter Veil" },
        events = { ["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } } },
        overrides = {},
        lunar = {},
        disabled = {},
        warEffort = {},
    }
    local function stateAt(month, day, hour, minute)
        ns.CalendarNow = function()
            return { month = month, day = day, hour = hour, minute = minute, year = 2026, source = "test" }
        end
        return ns.GetEventState(1)
    end
    local active, reason = stateAt(12, 15, 10, 0)
    assert(active == true and reason == "event-active")
    active, reason = stateAt(12, 15, 9, 59)
    assert(active == false and reason == "event-window")
    active, reason = stateAt(1, 2, 10, 0)
    assert(active == true, reason)
    active, reason = stateAt(1, 2, 10, 1)
    assert(active == false and reason == "event-window")
    active, reason = stateAt(7, 1, 12, 0)
    assert(active == false and reason == "event-window")
end

cases["events_runtime.test_quest_override_narrows_base_window"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [8744] = "Winter Veil" },
        events = { ["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } } },
        overrides = { [8744] = { { 12, 25, 0, 0 }, { 1, 2, 23, 59 } } },
        lunar = {},
        disabled = {},
        warEffort = {},
    }
    local function stateAt(month, day, hour, minute)
        ns.CalendarNow = function()
            return { month = month, day = day, hour = hour, minute = minute, year = 2026, source = "test" }
        end
        return ns.GetEventState(8744)
    end
    local active, reason, detail = stateAt(12, 20, 12, 0)
    assert(active == false and reason == "event-window")
    assert(detail and detail.override, "override detail is missing")
    active, reason = stateAt(12, 25, 0, 0)
    assert(active == true, reason)
    active, reason = stateAt(1, 1, 12, 0)
    assert(active == true, reason)
    active, reason = stateAt(1, 2, 10, 1)
    assert(active == false and reason == "event-window")
end

cases["events_runtime.test_disabled_event_and_missing_lunar_year"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [1] = "Darkmoon Faire", [2] = "Lunar Festival" },
        events = {},
        overrides = {},
        lunar = { [2026] = { { 2, 16, 6, 0 }, { 3, 9, 6, 0 } } },
        disabled = { ["Darkmoon Faire"] = true },
        warEffort = {},
    }
    ns.CalendarNow = function()
        return { month = 6, day = 1, hour = 12, minute = 0, year = 2027, source = "test" }
    end
    local active, reason = ns.GetEventState(1)
    assert(active == false and reason == "event-disabled")
    active, reason = ns.GetEventState(2)
    assert(active == false and reason == "lunar-year-unknown")
    ns.CalendarNow = function()
        return { month = 2, day = 16, hour = 6, minute = 0, year = 2026, source = "test" }
    end
    active, reason = ns.GetEventState(2)
    assert(active == true and reason == "event-active")
end

cases["events_runtime.test_missing_calendar_api_hides_events"] = function()
    ns = {}
    C_DateAndTime = nil
    date = nil
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [1] = "Winter Veil" },
        events = { ["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } } },
        overrides = {},
        lunar = {},
        disabled = {},
        warEffort = {},
    }
    local active, reason = ns.GetEventState(1)
    assert(active == false and reason == "calendar-unknown")
end

cases["events_runtime.test_calendar_now_prefers_calendar_time"] = function()
    ns = {}
    C_DateAndTime = {
        GetCurrentCalendarTime = function()
            return { month = 2, monthDay = 16, hour = 6, minute = 5, year = 2026 }
        end,
        GetTodaysDate = function() error("GetTodaysDate must not be called") end,
    }
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    local now = ns.CalendarNow()
    assert(now.month == 2 and now.day == 16 and now.hour == 6 and now.minute == 5)
    assert(now.source == "C_DateAndTime.GetCurrentCalendarTime")
    C_DateAndTime.GetCurrentCalendarTime = nil
    C_DateAndTime.GetTodaysDate = function() return 3, 1, 2026 end
    now = ns.CalendarNow()
    assert(now.month == 3 and now.day == 1 and now.hour == 0 and now.minute == 0)
    assert(now.source == "C_DateAndTime.GetTodaysDate")
    C_DateAndTime = nil
    date = function(format)
        assert(format == "*t")
        return { month = 4, day = 2, hour = 7, min = 8, year = 2026 }
    end
    now = ns.CalendarNow()
    assert(now.month == 4 and now.day == 2 and now.hour == 7 and now.minute == 8)
    assert(now.source == "date")
end

cases["eligibility_runtime.test_seasonal_option_and_window"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [6961] = "Winter Veil" },
        events = { ["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } } },
        overrides = {},
        lunar = {},
        disabled = {},
        warEffort = {},
    }
    ns.options = { showSeasonal = true, showRepeatable = true, showWarEffort = true, showWarEffortAlways = false, showTrivial = true }
    function ns.GetOption(key) return ns.options[key] end
    UnitLevel = function() return 60 end
    C_QuestLog = {
        IsOnQuest = function() return false end,
        IsQuestFlaggedCompleted = function() return false end,
    }
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.CalendarNow = function()
        return { month = 7, day = 1, hour = 12, minute = 0, year = 2026, source = "test" }
    end
    local available, reason = ns.IsQuestAvailable(6961, { isYearly = true, minLevel = 1 })
    assert(available == false and reason == "event-window")
    ns.CalendarNow = function()
        return { month = 12, day = 20, hour = 12, minute = 0, year = 2026, source = "test" }
    end
    available, reason = ns.IsQuestAvailable(6961, { isYearly = true, minLevel = 1 })
    assert(available == true, reason)
    ns.options.showSeasonal = false
    available, reason = ns.IsQuestAvailable(6961, { isYearly = true, minLevel = 1 })
    assert(available == false and reason == "seasonal")
end

cases["eligibility_runtime.test_war_effort_phase_confirmation"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = {},
        events = {},
        overrides = {},
        lunar = {},
        disabled = {},
        warEffort = { [8811] = true },
    }
    ns.options = { showSeasonal = false, showWarEffort = true, showWarEffortAlways = false, showRepeatable = true, showTrivial = true }
    function ns.GetOption(key) return ns.options[key] end
    UnitLevel = function() return 60 end
    C_QuestLog = {
        IsOnQuest = function() return false end,
        IsQuestFlaggedCompleted = function() return false end,
    }
    assert(loadfile("WarEffort.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.offeredQuestIDs = {}
    local available, reason = ns.IsQuestAvailable(8811, { minLevel = 1 })
    assert(available == false and reason == "war-effort-unconfirmed")
    ns.NoteOfferedQuest(8811)
    assert(ns.HasConfirmedWarEffort() == true)
    available, reason = ns.IsQuestAvailable(8811, { minLevel = 1 })
    assert(available == true, reason)
    ns.options.showWarEffort = false
    ns.offeredQuestIDs = {}
    available, reason = ns.IsQuestAvailable(8811, { minLevel = 1 })
    assert(available == false and reason == "war-effort")
end

cases["eligibility_runtime.test_war_effort_override_log_scan_and_old_range"] = function()
    ns = {}
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = {},
        events = {},
        overrides = {},
        lunar = {},
        disabled = {},
        warEffort = { [8811] = true, [8792] = true },
    }
    ns.options = { showSeasonal = false, showWarEffort = true, showWarEffortAlways = true, showRepeatable = true, showTrivial = true }
    function ns.GetOption(key) return ns.options[key] end
    UnitLevel = function() return 60 end
    local onQuest = false
    C_QuestLog = {
        IsOnQuest = function(id) return onQuest and id == 8811 end,
        IsQuestFlaggedCompleted = function() return false end,
    }
    assert(loadfile("WarEffort.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    local available, reason = ns.IsQuestAvailable(8811, { minLevel = 1 })
    assert(available == true, reason)
    ns.ResetWarEffortState()
    ns.options.showWarEffortAlways = false
    onQuest = true
    available, reason = ns.IsQuestAvailable(8792, { minLevel = 1 })
    assert(available == true, reason)
    assert(ns.IsWarEffortQuest(8789, { qg = 15380 }) == false)
end

cases["quest_info_runtime.test_why_reports_event_window_and_aq_phase"] = function()
    ns = {}
    GetLocale = function() return "enUS" end
    assert(loadfile("Localization.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Events.lua"))("ForeverQuestPins", ns)
    ns.EventPolicy = {
        byQuest = { [8744] = "Winter Veil" },
        events = { ["Winter Veil"] = { { 12, 15, 10, 0 }, { 1, 2, 10, 0 } } },
        overrides = { [8744] = { { 12, 25, 0, 0 }, { 1, 2, 23, 59 } } },
        lunar = {},
        disabled = {},
        warEffort = { [8811] = true },
    }
    assert(loadfile("WarEffort.lua"))("ForeverQuestPins", ns)
    ns.CalendarNow = function()
        return { month = 7, day = 1, hour = 12, minute = 0, year = 2026, source = "test" }
    end
    ns.Quests = {
        [8744] = { mapID = 1412, x = 10, y = 20, minLevel = 1 },
        [8811] = { mapID = 1455, x = 30, y = 40, minLevel = 1 },
    }
    ns.GetQuestTitle = function(questID) return "Quest " .. questID end
    ns.IsQuestFlaggedCompleted = function() return false end
    ns.IsOnQuest = function() return false end
    ns.IsQuestAvailable = function(_, _, reason) return false, ns.whyReason end
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.db = { showWarEffortAlways = false }
    local lines = {}
    print = function(line) lines[#lines + 1] = tostring(line) end

    ns.whyReason = "event-window"
    ns.PrintQuestWhy(8744)
    local text = table.concat(lines, "\n")
    assert(text:find("event Winter Veil: not live (event-window)", 1, true), text)
    assert(text:find("window 15/12 10:00-02/01 10:00", 1, true), text)
    assert(text:find("override 25/12 00:00-02/01 23:59", 1, true), text)
    assert(text:find("server time 2026-07-01 12:00 from test", 1, true), text)

    lines = {}
    ns.whyReason = "war-effort-unconfirmed"
    ns.PrintQuestWhy(8811)
    text = table.concat(lines, "\n")
    assert(text:find("AQ war effort: no war effort quest offered or in log", 1, true), text)
    assert(text:find("use /fqp wareffort always", 1, true), text)
end

cases["events_runtime.test_generated_event_policy_loads"] = function()
    ns = {}
    assert(loadfile("Database/EventPolicy.lua"))("ForeverQuestPins", ns)
    local policy = assert(ns.EventPolicy, "EventPolicy table is missing")
    local function count(values)
        local total = 0
        for _ in pairs(values) do total = total + 1 end
        return total
    end
    assert(count(policy.byQuest) == 220)
    assert(count(policy.events) == 6)
    assert(count(policy.overrides) == 11)
    assert(count(policy.lunar) == 10)
    assert(policy.disabled["Darkmoon Faire"] == true)
    assert(policy.warEffort[8811] == true)
    assert(policy.warEffort[8792] == true)
    assert(policy.warEffort[8789] == nil)
    assert(policy.byQuest[8744] == "Winter Veil")
    assert(policy.overrides[8744][1][1] == 12 and policy.overrides[8744][1][2] == 25)
    assert(policy.lunarYears.first == 2019 and policy.lunarYears.last == 2028)
end

cases["setup_runtime.preserves_current_settings_and_stages_choices"] = function()
    local options = {
        enabled = false, autoAccept = true, showRepeatable = false,
        autoAcceptLevelOffset = 1, autoAcceptMinLevelOffset = -10,
    }
    local writes, completed, printed = {}, 0, {}
    ns = { db = {}, WhatsNew = { version = "1.2.3", lines = { "A feature" } } }
    ns.GetOption = function(key) return options[key] or false end
    ns.SetOption = function(key, value) writes[key] = value; options[key] = value end
    ns.WipeSettings = function() writes.defaults = true end
    ns.SaveWelcomeState = function(done, version)
        if done then completed = completed + 1; ns.db._setupComplete = true end
        if version then ns.db._newsVersion = version end
    end
    print = function(text) table.insert(printed, text) end
    local gamepadEnabled = false
    InputUtil = { IsGamepadUIEnabled = function() return gamepadEnabled end }
    local controls = {}
    local function region()
        return setmetatable({}, { __index = function() return function() end end })
    end
    CreateFrame = function(kind, name, parent, template)
        local object = { Text = region(), Low = region(), High = region(), scripts = {}, template = template }
        object.SetScript = function(self, event, fn) self.scripts[event] = fn end
        object.CreateFontString = function() return region() end
        object.CreateTexture = function() return region() end
        object.SetText = function(self, text) self.label = text end
        object.SetChecked = function(self, value) self.checked = value end
        object.GetChecked = function(self) return self.checked end
        object.SetValue = function(self, value)
            self.value = value
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
        end
        object.EnableMouse = function(self, enabled) self.mouseEnabled = enabled end
        object.SetEnabled = function(self, enabled) self.enabled = enabled end
        object.Show = function(self) self.shown = true end
        object.Hide = function(self) self.shown = false end
        object.SetShown = function(self, shown) self.shown = shown end
        setmetatable(object, { __index = function() return function() end end })
        table.insert(controls, object)
        return object
    end
    local config = {}
    assert(loadfile("Config.lua"))("ForeverQuestPins", config)
    ns.CreateLevelRangeSlider = config.CreateLevelRangeSlider
    controls = {}
    assert(loadfile("Setup.lua"))("ForeverQuestPins", ns)
    ns.StartWelcome()
    assert(#printed == 2 and ns.db._newsVersion == "1.2.3")
    local function button(label)
        for _, control in ipairs(controls) do
            if control.template == "UIPanelButtonTemplate" and control.label == label then return control end
        end
        error("missing button " .. label)
    end
    button("Use Current Settings").scripts.OnClick()
    assert(completed == 1 and next(writes) == nil)
    ns.StartWelcome()
    assert(#printed == 2 and completed == 1)
    ns.ShowSetup()
    button("Choose Options").scripts.OnClick()
    local enabled
    for _, control in ipairs(controls) do if control.key == "enabled" then enabled = control end end
    assert(enabled and enabled.checked == false)
    enabled.checked = true
    enabled.scripts.OnClick(enabled)
    assert(next(writes) == nil, "guided choices must remain staged")
    button("Next").scripts.OnClick()
    button("Next").scripts.OnClick()
    local sparkle
    for _, control in ipairs(controls) do
        if control.key == "sparkleQuestItems" then sparkle = control end
    end
    assert(sparkle and sparkle.shown, "the setup guide must offer quest item sparkles")
    assert(sparkle.checked == false, "sparkles start unchecked")
    sparkle.checked = true
    sparkle.scripts.OnClick(sparkle)
    assert(next(writes) == nil, "the sparkle choice must remain staged")
    button("Next").scripts.OnClick()
    local enhance, nearest
    for _, control in ipairs(controls) do
        if control.key == "enhanceQuestTracker" then enhance = control end
        if control.key == "selectNearestQuest" then nearest = control end
    end
    assert(enhance and enhance.shown, "the setup guide must offer the quest tracker")
    assert(nearest and nearest.shown, "the setup guide must offer the nearest quest option")
    nearest.checked = true
    nearest.scripts.OnClick(nearest)
    assert(next(writes) == nil, "the tracker choice must remain staged")
    gamepadEnabled = true
    button("Back").scripts.OnClick()
    button("Next").scripts.OnClick()
    assert(enhance.enabled == false and nearest.enabled == false,
        "the setup guide must disable tracker choices in gamepad UI")
    gamepadEnabled = false
    button("Back").scripts.OnClick()
    button("Next").scripts.OnClick()
    assert(enhance.enabled == true and nearest.enabled == true)
    button("Next").scripts.OnClick()
    local range, limit
    for _, control in ipairs(controls) do
        if rawget(control, "isLevelRange") then range = control end
        if control.key == "autoAcceptRangeEnabled" then limit = control end
    end
    assert(range and range.shown and not range.active)
    assert(range.lowValue == -10 and range.highValue == 1)
    limit.checked = true
    limit.scripts.OnClick(limit)
    assert(range.active)
    range:SetUserValue("high", 3)
    range:SetUserValue("low", -5)
    -- The low handle cannot pass the high handle.
    range:SetUserValue("low", 4)
    assert(range.lowValue == 3)
    range:SetUserValue("low", -5)
    assert(next(writes) == nil, "level limit must remain staged")
    button("Back").scripts.OnClick()
    button("Next").scripts.OnClick()
    assert(range.lowValue == -5 and range.highValue == 3 and range.active)
    gamepadEnabled = true
    button("Apply").scripts.OnClick()
    assert(writes.enhanceQuestTracker == nil and writes.selectNearestQuest == nil,
        "Apply must not write tracker options in gamepad UI")
    gamepadEnabled = false
    assert(writes.enabled == true and writes.autoAccept == nil and options.autoAccept == true)
    assert(writes.autoAcceptRangeEnabled == true and writes.autoAcceptLevelOffset == 3)
    assert(writes.autoAcceptMinLevelOffset == -5)
    assert(writes.sparkleQuestItems == true)
    ns.ShowSetup()
    button("Use Defaults").scripts.OnClick()
    assert(writes.defaults == true)
end

cases["auto_quests_runtime.level_range_limits_both_ends"] = function()
    local options = { autoAcceptRangeEnabled = true, autoAcceptLevelOffset = 5, autoAcceptMinLevelOffset = -5 }
    ns = {}
    ns.GetOption = function(key) return options[key] end
    ns.defaults = { autoAcceptLevelOffset = 1, autoAcceptMinLevelOffset = -10 }
    UnitLevel = function() return 20 end
    CreateFrame = function()
        return setmetatable({}, { __index = function() return function() end end })
    end
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.GetOption = function(key) return options[key] end
    assert(loadfile("AutoQuests.lua"))("ForeverQuestPins", ns)
    local allows = function(level) return ns.AutoQuests:AllowsLevel(nil, level) end
    assert(allows(15) and allows(20) and allows(25))
    assert(not allows(14) and not allows(26))
    -- A maximum below the minimum collapses the window to the maximum.
    options.autoAcceptLevelOffset, options.autoAcceptMinLevelOffset = -3, 0
    assert(allows(17) and not allows(16) and not allows(18))
    options.autoAcceptRangeEnabled = false
    assert(allows(1) and allows(60))
end

cases["auto_quests_runtime.skip_grey_uses_game_flag_then_green_range"] = function()
    local options = { autoAcceptSkipGrey = true, autoAcceptRangeEnabled = false }
    ns = {}
    ns.GetOption = function(key) return options[key] end
    UnitLevel = function() return 20 end
    GetQuestGreenRange = function() return 7 end
    C_QuestLog = { IsQuestTrivial = function(questID) return questID == 99 end }
    CreateFrame = function()
        return setmetatable({}, { __index = function() return function() end end })
    end
    assert(loadfile("AutoQuests.lua"))("ForeverQuestPins", ns)
    local auto = ns.AutoQuests
    -- The gossip list's own flag wins over everything else.
    assert(not auto:AllowsQuest(nil, 20, true))
    assert(auto:AllowsQuest(99, 5, false))
    -- Then the game's per-quest check.
    assert(not auto:AllowsQuest(99, 20))
    assert(auto:AllowsQuest(98, 20))
    -- Then the green range when only a level is known.
    C_QuestLog = nil
    assert(auto:AllowsQuest(nil, 13) and not auto:AllowsQuest(nil, 12))
    -- Unknown levels are not treated as grey.
    assert(auto:AllowsQuest(nil, nil))
    options.autoAcceptSkipGrey = false
    assert(auto:AllowsQuest(nil, 1, true))
end

cases["auto_quests_runtime.min_level_offset_mirrors_and_clamps"] = function()
    local mirror = "revision=3;waypointProvider=blizzard;autoAcceptMinLevelOffset=-4;enabled=1"
    C_CVar = {
        GetCVar = function() return mirror end,
        SetCVar = function(_, value) mirror = value end,
        RegisterCVar = function() end,
    }
    ForeverQuestPinsDB, ForeverQuestPinsCharDB = {}, {}
    ForeverQuestPinsDB_Settings, ForeverQuestPinsCharacterSettings = {}, {}
    ns = {}
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    assert(ns.InitSettings().autoAcceptMinLevelOffset == -4)
    ns.SetOption("autoAcceptMinLevelOffset", -99)
    assert(ns.GetOption("autoAcceptMinLevelOffset") == -10)
    ns.SetOption("autoAcceptMinLevelOffset", 7)
    assert(ns.GetOption("autoAcceptMinLevelOffset") == 5)
    ns.SetOption("autoAcceptMinLevelOffset", -6)
    assert(mirror:find("autoAcceptMinLevelOffset=-6", 1, true))
end

cases["auto_quests_runtime.book_quests_skip_when_option_off"] = function()
    local options = { showBooks = true, autoAcceptSkipGrey = false }
    ns = {}
    ns.GetOption = function(key) return options[key] end
    CreateFrame = function()
        return setmetatable({}, { __index = function() return function() end end })
    end
    assert(loadfile("AutoQuests.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Database/BookQuests.lua"))("ForeverQuestPins", ns)
    ns.IsBookQuestHidden = function(questID)
        return options.showBooks == false and ns.IsBookQuest(questID) == true
    end
    assert(ns.AutoQuests:AllowsQuest(78124, 1))
    options.showBooks = false
    assert(not ns.AutoQuests:AllowsQuest(78124, 1))
    assert(ns.AutoQuests:AllowsQuest(2, 1))
end

cases["setup_runtime.markers_survive_settings_recovery_without_changing_options"] = function()
    local mirror = ""
    C_CVar = {
        GetCVar = function() return mirror end,
        SetCVar = function(_, value) mirror = value end,
        RegisterCVar = function() end,
    }
    ForeverQuestPinsDB = { enabled = false, autoAccept = true, _revision = 9 }
    ForeverQuestPinsCharDB = {}
    ForeverQuestPinsDB_Settings = {}
    ForeverQuestPinsCharacterSettings = {}
    ns = {}
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()
    assert(ns.GetOption("enabled") == false and ns.GetOption("autoAccept") == true)
    local revision = ns.db._revision
    ns.SaveWelcomeState(true, "1.2.3")
    assert(ns.db._revision == revision and ns.GetOption("enabled") == false and ns.GetOption("autoAccept") == true)
    assert(mirror:find("setupComplete=1", 1, true) and mirror:find("newsVersion=1.2.3", 1, true))
    ForeverQuestPinsDB, ForeverQuestPinsCharDB = {}, {}
    ForeverQuestPinsDB_Settings, ForeverQuestPinsCharacterSettings = {}, {}
    ns.db = nil
    ns.InitSettings()
    assert(ns.db._setupComplete == true and ns.db._newsVersion == "1.2.3")
    assert(ns.GetOption("enabled") == false and ns.GetOption("autoAccept") == true)
end

cases["map_pins_runtime.openmap_keeps_pins_across_host_changes"] = function()
    setupPinRendering()
    local mapID = 1
    local stitched = true
    WorldMapFrame.GetMapID = function() return mapID end
    OpenMapAPI = {
        IsStitched = function() return stitched end,
        WorldFromMap = function(id, x, y) return x / 2 + (id - 1) / 2, y end,
        MapFromWorld = function(id, u, v) return (u - (id - 1) / 2) * 2, v end,
    }
    ns.Quests[102] = { mapID = 2, x = 50, y = 50 }
    ns.ByMap[2] = { 102 }
    ns.MapPins:Refresh("initial")
    assert(ns.MapPins:GetStatus().count == 2)
    local original = pin
    mapID = 2
    ns.MapPins:Refresh("map-changed")
    assert(pin == original and original.shown)
    assert(ns.MapPins:GetStatus().count == 2)
    assert(math.abs(original.point[4] - 500) < 0.001)
    InCombatLockdown = function() return true end
    ns.MapPins:Refresh("QUEST_TURNED_IN")
    assert(ns.MapPins:GetStatus().mode == "combat-deferred" and original.shown)
    InCombatLockdown = function() return false end
    ns.Quests[102] = nil
    ns.MapPins:Refresh("QUEST_TURNED_IN")
    assert(ns.MapPins:GetStatus().count == 1)
    stitched = false
    ns.MapPins:Refresh("map-display")
    assert(ns.MapPins:GetStatus().count == 0)
    mapID = 1
    ns.MapPins:Refresh("map-changed")
    assert(ns.MapPins:GetStatus().count == 1)
end

cases["map_pins_runtime.map_change_during_sliced_stitched_paint_repaints"] = function()
    setupPinRendering()
    local timerQueue = {}
    C_Timer = { After = function(_, callback) timerQueue[#timerQueue + 1] = callback end }
    local function runTimers()
        local queued = timerQueue
        timerQueue = {}
        for i = 1, #queued do queued[i]() end
    end
    local canvasScale = 1
    local mapID = 1
    OpenMapAPI = {
        IsStitched = function() return true end,
        WorldFromMap = function(id, x, y) return x / 2 + (id - 1) / 2, y end,
        MapFromWorld = function(id, u, v) return (u - (id - 1) / 2) * 2, v end,
    }
    WorldMapFrame.GetMapID = function() return mapID end
    WorldMapFrame.GetCanvasScale = function() return canvasScale end
    ns.ProjectToViewedMap = function(_, x, y) return x / 100, y / 100 end
    local refreshes = {}
    ns.RequestRefresh = function(reason) refreshes[#refreshes + 1] = reason end
    for i = 1, 80 do
        local questID = 1000 + i
        ns.Quests[questID] = { mapID = 1, x = (i % 10) * 8 + 3, y = math.floor(i / 10) * 8 + 3 }
        ns.ByMap[1][#ns.ByMap[1] + 1] = questID
    end
    ns.MapPins:HookMap()
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    runTimers()
    refreshes = {}

    -- 81 candidates: the first batch stops at the 60-item cap when the
    -- profiler is unavailable, leaving a pending batch.
    ns.MapPins:Refresh("initial")
    assert(ns.MapPins:GetStatus().count == 60 and ns.MapPins:GetStatus().mode == "painting")
    assert(#timerQueue == 1)

    mapID = 2
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(ns.MapPins:GetStatus().count == 0 and ns.MapPins:GetStatus().mode == "map-changing")
    assert(refreshes[#refreshes] == "map-changed", "map change must request a repaint")
    runTimers()
    assert(ns.MapPins:GetStatus().mode == "map-changing", "cancelled batch must not run")

    ns.MapPins:Refresh("map-changed")
    assert(ns.MapPins:GetStatus().mode == "painting", "follow-up refresh must paint the new map")
    runTimers()
    assert(ns.MapPins:GetStatus().mode == "canvas" and ns.MapPins:GetStatus().count == 81)

    -- A display-state change (canvas scale) on the same map reprojects the
    -- partial set instead of restarting it.
    ns.MapPins:Refresh("initial")
    assert(ns.MapPins:GetStatus().count == 60 and #timerQueue == 1)
    refreshes = {}
    canvasScale = 2
    mapWatch.scripts.OnUpdate(mapWatch, 0.1)
    assert(ns.MapPins:GetStatus().mode == "painting", "a scale change must not cancel the paint")
    assert(#refreshes == 0, "reprojecting the same map needs no new refresh")
    runTimers()
    assert(ns.MapPins:GetStatus().mode == "canvas" and ns.MapPins:GetStatus().count == 81)

    -- A quest-level refresh during an active paint must not restart it.
    ns.MapPins:Refresh("initial")
    assert(ns.MapPins:GetStatus().count == 60 and #timerQueue == 1)
    refreshes = {}
    ns.MapPins:Refresh("quest-level")
    assert(ns.MapPins:GetStatus().count == 60 and ns.MapPins:GetStatus().mode == "painting")
    runTimers()
    assert(ns.MapPins:GetStatus().count == 81 and ns.MapPins:GetStatus().mode == "canvas")
    assert(refreshes[#refreshes] == "quest-level", "paint completion must request the deferred refresh")
    ns.MapPins:Refresh("quest-level")
    assert(ns.MapPins:GetStatus().mode == "painting")
    runTimers()
    assert(ns.MapPins:GetStatus().mode == "canvas" and ns.MapPins:GetStatus().count == 81)
end

cases["quest_info_runtime.test_npc_nameplate_state_prefers_in_log_states"] = function()
ns = {}
local objectiveLines = {}
C_TooltipInfo = {
    GetUnit = function()
        return { lines = objectiveLines }
    end,
}
assert(loadfile("NPCTooltips.lua"))("ForeverQuestPins", ns)

            ns.Quests = { [20] = { qg = 100, turnIns = { 100 } } }
            ns.NpcOffersQuestAccept = function() return true end
            ns.IsQuestAvailable = function() return true end
            ns.IsOnQuest = function() return true end
            ns.IsQuestReadyForTurnIn = function() return true end
            ns.IsQuestFlaggedCompleted = function() return false end
            ns.IsQuestHidden = function() return false end
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "turnin")

            ns.IsQuestReadyForTurnIn = function() return false end
            objectiveLines = { { type = 8, leftText = "Hillsbrad Miner slain", rightText = "3/10" } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "objective")

            objectiveLines = { { type = 8, leftText = "Hillsbrad Miner slain", rightText = "10/10" } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "accept")

            ns.NpcOffersQuestAccept = function() return false end
            ns.IsQuestAvailable = function() return false end
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, leftText = "Hillsbrad Miner slain", leftColor = { r = 0.5, g = 0.5, b = 0.5 } } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, leftColor = { GetRGB = function() return 0.5, 0.5, 0.5 end } } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, completed = true } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, completed = false } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "objective")

            objectiveLines = { { type = 8, numFulfilled = 10, numRequired = 10 } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, numFulfilled = 3, numRequired = 10 } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "objective")

            issecretvalue = function(value) return value == "secret" end
            objectiveLines = { { type = 8, leftText = "secret" } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)

            objectiveLines = { { type = 8, leftColor = { r = "secret", g = 0.5, b = 0.5 } } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == nil)
            issecretvalue = nil

            objectiveLines = { { type = 8, rightText = "10/10" }, { type = 8, rightText = "1/2" } }
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "objective")

            objectiveLines = {}
            ns.NpcOffersQuestAccept = function() return true end
            ns.IsQuestAvailable = function() return true end
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") == "accept")
            assert(ns.NPCTooltips:GetNpcQuestState(101, "nameplate1") == nil)

            ns.GetQuestTitle = function(questID) return "Book " .. questID end
            ns.IsQuestReadyForTurnIn = function() return true end
            ns.IsBookQuestHidden = function(questID) return questID == 20 end
            assert(ns.NPCTooltips:GetNpcQuestState(100, "nameplate1") ~= "turnin")
            ns.NPCTooltips:InvalidateStarterIndex()
            assert(#ns.NPCTooltips:GetTurnInRows(100) == 0)

end
cases["quest_info_runtime.test_nameplate_icons_follow_option_and_quest_state"] = function()
ns = {}
local options = { showNameplateIcons = true }
local created = {}
local nameRegion = {}
local healthBar = {}
local plate = { namePlateUnitToken = "nameplate1", UnitFrame = { name = nameRegion, healthBar = healthBar } }
local plates = { ["nameplate1"] = plate }

local function NewTexture()
    local texture = {}
    function texture:SetAllPoints() end
    function texture:SetAtlas(atlas) self.atlas = atlas end
    function texture:SetTexture(path) self.path = path end
    function texture:SetTexCoord() end
    function texture:SetDesaturated() end
    function texture:SetVertexColor() end
    function texture:SetAlpha() end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    return texture
end
local function NewFrame()
    local frame = {}
    created[#created + 1] = frame
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:CreateTexture() self.icon = NewTexture(); return self.icon end
    function frame:SetParent(parent) self.parent = parent end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    return frame
end

CreateFrame = function() return NewFrame() end
C_Texture = { GetAtlasInfo = function(atlas) return atlas == "QuestNormal" and {} or nil end }
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function()
        local list = {}
        for _, current in pairs(plates) do list[#list + 1] = current end
        return list
    end,
}
UnitGUID = function() return "Creature-0-0-0-0-100-0000000000" end
ns.GetOption = function(key) return options[key] end
ns.NpcIDFromGUID = function() return 100 end
ns.NPCTooltips = {
    GetNpcQuestState = function(_, npcID) return npcID == 100 and "accept" or nil end,
}
assert(loadfile("Nameplates.lua"))("ForeverQuestPins", ns)

            ns.Nameplates:UpdateUnit("nameplate1")
            assert(#created == 1)
            local frame = created[1]
            assert(frame.parent == plate and frame.shown)
            assert(frame.point[1] == "RIGHT" and frame.point[2] == healthBar)
            assert(frame.point[3] == "LEFT" and frame.point[4] == -2)
            assert(frame.icon.atlas == "QuestNormal")

            options.showNameplateIcons = false
            ns.Nameplates:UpdateUnit("nameplate1")
            assert(not frame.shown and frame.parent == nil)

            options.showNameplateIcons = true
            ns.NPCTooltips.GetNpcQuestState = function() return "turnin" end
            ns.Nameplates:UpdateUnit("nameplate1")
            assert(frame.shown and frame.icon.path == "Interface\\GossipFrame\\ActiveQuestIcon")

            ns.NPCTooltips.GetNpcQuestState = function() return "objective" end
            ns.Nameplates:UpdateUnit("nameplate1")
            assert(frame.shown and frame.icon.path == "Interface\\QuestFrame\\UI-Quest-BulletPoint")

            ns.Nameplates:RefreshAll()
            assert(frame.shown)
            plates["nameplate1"] = nil
            ns.Nameplates:RefreshAll()
            assert(not frame.shown and frame.parent == nil)

end
cases["eligibility_runtime.test_excluded_quests_database_hides_reward_quests"] = function()
    ns = {}; C_QuestLog = {}
    assert(loadfile("Database/ExcludedQuests.lua"))("ForeverQuestPins", ns)
    assert(ns.ExcludedQuests[60860])
    assert(ns.ExcludedQuests[60870])
    assert(ns.ExcludedQuests[96339])
    assert(ns.ExcludedQuests[96383])
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    C_QuestLog.IsQuestFlaggedCompleted = function() return false end
    C_QuestLog.IsOnQuest = function() return false end
    UnitLevel = function() return 60 end
    ns.GetOption = function() return true end
    local available, reason = ns.IsQuestAvailable(60860, { minLevel = 1 })
    assert(available == false and reason == "excluded")
    available, reason = ns.IsQuestAvailable(60870, { minLevel = 1 })
    assert(available == false and reason == "excluded")
    available, reason = ns.IsQuestAvailable(96339, { minLevel = 1 })
    assert(available == false and reason == "excluded")
    available, reason = ns.IsQuestAvailable(96383, { minLevel = 1 })
    assert(available == false and reason == "excluded")
    available, reason = ns.IsQuestAvailable(60861, { minLevel = 1 })
    assert(available == true)
end
cases["eligibility_runtime.test_pvp_quest_tag_and_option"] = function()
    ns = {}; C_QuestLog = {}
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    C_QuestLog.IsQuestFlaggedCompleted = function() return false end
    C_QuestLog.IsOnQuest = function() return false end
    UnitLevel = function() return 60 end
    local options = { showPvP = false, showNormal = true, showTrivial = true, trivialLevelGap = 9 }
    ns.GetOption = function(key) return options[key] end
    local available, reason = ns.IsQuestAvailable(200, { isPvPQuest = true, minLevel = 1 })
    assert(available == false and reason == "category-hidden")
    options.showPvP = true
    available, reason = ns.IsQuestAvailable(200, { isPvPQuest = true, minLevel = 1 })
    assert(available == true)
    options.showPvP = false
    C_QuestLog.GetQuestTagInfo = function(questID)
        if questID == 201 then
            return { tagID = 41, tagName = "PvP" }
        end
    end
    assert(ns.IsPvPQuest(201, {}))
    available, reason = ns.IsQuestAvailable(201, { minLevel = 1 })
    assert(available == false and reason == "category-hidden")
    options.showPvP = true
    available, reason = ns.IsQuestAvailable(201, { minLevel = 1 })
    assert(available == true)
end
cases["map_pins_runtime.test_unexplored_map_position_and_option"] = function()
    ns = {}
    CreateFrame = function() return { SetScript = function() end } end
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    assert(loadfile("MapPins.lua"))("ForeverQuestPins", ns)

    assert(ns.GetOption("showUnexplored") == true, "default shows unexplored areas")

    assert(ns.IsMapPositionExplored(1453, 50, 50) == true, "city maps are always explored")
    assert(ns.IsMapPositionExplored(nil, 50, 50) == true, "missing map ID defaults to explored")
    assert(ns.IsMapPositionExplored(1, nil, 50) == true, "missing coordinates default to explored")

    C_MapExplorationInfo = nil
    CreateVector2D = nil
    assert(ns.IsMapPositionExplored(1, 50, 50) == true, "missing API defaults to explored")

    C_MapExplorationInfo = {
        GetExploredAreaIDsAtPosition = function(mapID, position)
            if mapID == 1 and position.x == 0.5 and position.y == 0.5 then
                return { 123 }
            end
            return nil
        end
    }
    CreateVector2D = function(x, y) return { x = x, y = y } end

    assert(ns.IsMapPositionExplored(1, 50, 50) == true, "explored position")
    assert(ns.IsMapPositionExplored(1, 20, 20) == false, "unexplored position")
end
cases["waypoints_runtime.test_can_track_quest_reports_failures_without_side_effects"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4}}}
            provider="blizzard"
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.IsOnQuest=function() return false end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            local ok, message = ns.CanTrackQuest(1)
            assert(ok == true and message == nil)
            assert(waypoint == nil, "validation must not set a waypoint")

            provider="tomtom"; TomTom=nil
            ok, message = ns.CanTrackQuest(1)
            assert(ok == false and message:find("TomTom", 1, true))

            provider="blizzard"; C_Map.CanSetUserWaypointOnMap=function() return false end
            ok, message = ns.CanTrackQuest(1)
            assert(ok == false and message:find("does not allow", 1, true))

            C_Map.CanSetUserWaypointOnMap=function() return true end
            C_Map.SetUserWaypoint=nil
            ok, message = ns.CanTrackQuest(1)
            assert(ok == false and message:find("unavailable", 1, true))

            C_Map.SetUserWaypoint=function(point) waypoint=point end
            ns.Quests[2]={mapID=1412,x=101,y=50}
            ok, message = ns.CanTrackQuest(2)
            assert(ok == false and message:find("location", 1, true))

            ok, message = ns.CanTrackQuest(nil)
            assert(ok == false and message == nil)
            assert(#messages == 0, "validation must not print")

end
cases["waypoints_runtime.test_track_quest_quiet_failure_preserves_existing_waypoint"] = function()

            ns={Quests={[1]={mapID=1412,x=54.4,y=60.4},[2]={mapID=1412,x=101,y=50}}}
            provider="blizzard"
            messages={}
            print=function(message) table.insert(messages,message) end
            ns.GetOption=function() return provider end
            ns.IsOnQuest=function() return false end
            UiMapPoint={CreateFromCoordinates=function(map,x,y)
                return {uiMapID=map,position={x=x,y=y}}
            end}
            C_Map={
                CanSetUserWaypointOnMap=function() return true end,
                SetUserWaypoint=function(point) waypoint=point end,
                GetUserWaypoint=function() return waypoint end,
                ClearUserWaypoint=function() waypoint=nil end,
            }
            C_SuperTrack={
                SetSuperTrackedUserWaypoint=function(value) userTracked=value end,
                IsSuperTrackingUserWaypoint=function() return userTracked end,
            }

assert(loadfile("Waypoints.lua"))("ForeverQuestPins", ns)

            assert(ns.TrackQuest(1))
            local existing = waypoint
            assert(existing and existing.uiMapID == 1412 and userTracked)

            local ok, message = ns.TrackQuest(2, nil, true)
            assert(ok == false and message ~= nil)
            assert(#messages == 0, "quiet failures must not print")
            assert(waypoint == existing, "a failed track must keep the current waypoint")
            assert(userTracked == true)

            ok, message = ns.TrackQuest(2)
            assert(ok == false and message ~= nil)
            assert(#messages == 1, "loud failures still report once")
            assert(waypoint == existing)

            ns.OnWaypointQuestEnded(1)
            assert(waypoint == nil, "the previous selection is still owned")

end
cases["breadcrumbs_runtime.test_candidate_rules_ignore_display_filters"] = function()

            ns={Quests={
                [500]={sourceQuestSingle={10,11,12,13,14,15,16,17,18,19,20,21,22,23,24}},
                [10]={isBreadcrumb=true,mapID=1411,minLevel=1},
                [11]={isBreadcrumb=true,mapID=1411},
                [12]={isBreadcrumb=true,mapID=1411},
                [13]={isBreadcrumb=true,mapID=1411},
                [14]={isBreadcrumb=true,mapID=1411},
                [15]={isBreadcrumb=true,mapID=1411,altQuests={31}},
                [16]={isBreadcrumb=true,mapID=1411,altQuests={32}},
                [17]={isBreadcrumb=true,mapID=1411,races={1}},
                [18]={isBreadcrumb=true,mapID=1411,classes={1}},
                [19]={isBreadcrumb=true,mapID=1411,faction="Alliance"},
                [20]={isBreadcrumb=true,mapID=1411,minLevel=99},
                [21]={isBreadcrumb=true,mapID=1411,requireSkill=197},
                [22]={mapID=1411},
                [23]={isBreadcrumb=true,mapID=1456},
                [24]={isBreadcrumb=true,mapID=1411,minLevel=3,isPvPQuest=true},
                [600]={sourceQuestSingle={25,26}},
                [25]={isBreadcrumb=true,mapID=1411},
                [26]={mapID=1411},
            }}
            completed={[11]=true,[31]=true}
            inLog={[12]=true,[32]=true}
            playerMap=1456
            options={showTrivial=false,showPvP=false,showNormal=false,showSeasonal=false}
            ns.IsQuestFlaggedCompleted=function(questID) return completed[questID] or false end
            ns.IsOnQuest=function(questID) return inLog[questID] or false end
            ns.IsQuestHidden=function(questID) return questID==13 end
            ns.ExcludedQuests={[14]=true}
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 2 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return false end
            ns.GetOption=function(key) return options[key] end
            UnitLevel=function() return 40 end
            C_Map={GetBestMapForUnit=function() return playerMap end}

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            local candidates=ns.Breadcrumbs.CollectCandidates(500)
            assert(#candidates==3)
            assert(candidates[1]==10 and candidates[2]==23 and candidates[3]==24)

            local best=ns.Breadcrumbs.FindSkippedBreadcrumb(500)
            assert(best==23, "the current map wins over data order")
            playerMap=1411
            best=ns.Breadcrumbs.FindSkippedBreadcrumb(500)
            assert(best==10)
            playerMap=999
            best=ns.Breadcrumbs.FindSkippedBreadcrumb(500)
            assert(best==10, "fallback keeps data order")

            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(999)==nil)
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(nil)==nil)

            assert(#ns.Breadcrumbs.CollectCandidates(600)==1)
            completed[26]=true
            assert(#ns.Breadcrumbs.CollectCandidates(600)==0,
                "a completed non-breadcrumb route means the breadcrumb did not gate the quest")

end
cases["breadcrumbs_runtime.test_alternate_routes_and_multi_breadcrumb_lists"] = function()

            ns={Quests={
                [6383]={sourceQuestSingle={235,742},title="The Ashenvale Hunt"},
                [235]={isBreadcrumb=true,altQuests={742,6382},mapID=1454,title="The Ashenvale Hunt"},
                [742]={isBreadcrumb=true,altQuests={235,6382},mapID=1456,title="The Ashenvale Hunt"},
                [788]={sourceQuestSingle={4641},title="Cutting Teeth"},
                [4641]={isBreadcrumb=true,mapID=1411,title="Your Place In The World"},
            }}
            completed={}
            inLog={}
            playerMap=1456
            ns.IsQuestFlaggedCompleted=function(questID) return completed[questID] or false end
            ns.IsOnQuest=function(questID) return inLog[questID] or false end
            ns.IsQuestHidden=function() return false end
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 2 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return true end
            ns.GetOption=function() return true end
            UnitLevel=function() return 40 end
            C_Map={GetBestMapForUnit=function() return playerMap end}

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            local candidates=ns.Breadcrumbs.CollectCandidates(6383)
            assert(#candidates==2 and candidates[1]==235 and candidates[2]==742)
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(6383)==742)
            playerMap=1454
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(6383)==235)

            completed[742]=true
            assert(#ns.Breadcrumbs.CollectCandidates(6383)==0)
            completed[742]=nil
            inLog[742]=true
            assert(#ns.Breadcrumbs.CollectCandidates(6383)==0)

            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(788)==4641)
            completed[4641]=true
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(788)==nil)

end
local function InstallDialogStubs(nsState, created)
    local function NewWidget(kind, name)
        local widget={kind=kind,scripts={},shown=true,text=""}
        if name then _G[name]=widget end
        function widget:SetSize(width,height) self.width,self.height=width,height end
        function widget:SetWidth(width) self.width=width end
        function widget:SetHeight(height) self.height=height end
        function widget:GetWidth() return self.width or 0 end
        function widget:GetHeight() return self.height or 0 end
        function widget:SetPoint(...) self.points={...} end
        function widget:ClearAllPoints() self.points=nil end
        function widget:SetBackdrop() end
        function widget:SetBackdropBorderColor() end
        function widget:SetFrameStrata() end
        function widget:SetClampedToScreen() end
        function widget:EnableMouse() end
        function widget:SetScript(script,handler) self.scripts[script]=handler end
        function widget:GetScript(script) return self.scripts[script] end
        function widget:Show()
            self.shown=true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function widget:Hide()
            if not self.shown then return end
            self.shown=false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function widget:IsShown() return self.shown end
        function widget:SetShown(value) if value then self:Show() else self:Hide() end end
        function widget:SetText(text) self.text=text end
        function widget:GetText() return self.text end
        function widget:GetTextWidth() return #self.text*6 end
        function widget:SetEnabled(value) self.enabled=value end
        function widget:IsEnabled() return self.enabled~=false end
        function widget:SetJustifyH() end
        function widget:SetSpacing() end
        function widget:SetColorTexture() end
        function widget:Raise() end
        function widget:CreateTexture()
            local texture=NewWidget("texture")
            created[#created+1]=texture
            return texture
        end
        function widget:CreateFontString()
            local text=NewWidget("fontstring")
            function text:GetStringWidth() return #self.text*6 end
            function text:GetStringHeight() return self.text~="" and 16 or 0 end
            created[#created+1]=text
            return text
        end
        if kind=="Button" then widget.enabled=true end
        return widget
    end

    UIParent=NewWidget("frame")
    UISpecialFrames={}
    GameTooltip={
        SetOwner=function() end,
        SetText=function() end,
        AddLine=function() end,
        Show=function() end,
        Hide=function() end,
    }
    CreateFrame=function(kind,name,parent,template)
        local widget=NewWidget(kind,name)
        widget.parent=parent
        created[#created+1]=widget
        return widget
    end
    timers={}
    C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
    C_Map={
        GetBestMapForUnit=function() return 1411 end,
        GetMapInfo=function(mapID)
            if mapID==1411 then return {name="Durotar"} end
            if mapID==1455 then return {name="The Barrens"} end
        end,
    }
end
local function FindWidget(created, kind, text)
    for i=1,#created do
        local widget=created[i]
        if widget.kind==kind and widget.text==text then return widget end
    end
end
local function HasWidgetText(created, kind, fragment)
    for i=1,#created do
        local widget=created[i]
        if widget.kind==kind and widget.text:find(fragment,1,true) then return true end
    end
    return false
end
local function HasMessage(messages, fragment)
    for i=1,#messages do
        if messages[i]:find(fragment,1,true) then return true end
    end
    return false
end

cases["breadcrumbs_runtime.test_dialog_queue_ignore_escape_and_option"] = function()

            created={}
            ns={Quests={
                [800]={sourceQuestSingle={400},title="Follow-up A"},
                [400]={isBreadcrumb=true,mapID=1411,title="Breadcrumb A"},
                [801]={sourceQuestSingle={401},title="Follow-up B"},
                [401]={isBreadcrumb=true,mapID=1411,title="Breadcrumb B"},
                [1796]={title="Components for the Enchanted Gold Bloodrobe",mapID=1413},
                [4736]={isBreadcrumb=true,mapID=1455,title="In Search of Menara Voidrender"},
            }}
            options={warnSkippedBreadcrumb=true,debug=false}
            ns.GetOption=function(key) return options[key] end
            ns.GetQuestTitle=function(questID) return ns.Quests[questID] and ns.Quests[questID].title end
            ns.IsQuestFlaggedCompleted=function() return false end
            ns.IsOnQuest=function() return false end
            ns.IsQuestHidden=function() return false end
            ns.IsQuestReadyForTurnIn=function() return false end
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 2 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return true end
            ns.CanTrackQuest=function() return true end
            ns.TrackQuest=function(questID) tracked=questID; return true end
            UnitLevel=function() return 40 end
            InstallDialogStubs(ns, created)

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            ns.Breadcrumbs.HandleAccepted(800)
            local panel=_G.ForeverQuestPinsBreadcrumb
            assert(panel and panel.shown)
            assert(FindWidget(created,"Button","Set Waypoint"))
            assert(FindWidget(created,"Button","Ignore"))
            assert(not FindWidget(created,"Button","Abandon Quest"))
            assert(HasWidgetText(created,"fontstring","You accepted"))
            assert(HasWidgetText(created,"fontstring","Breadcrumb A"))
            assert(HasWidgetText(created,"fontstring","Follow-up A"))
            assert(HasWidgetText(created,"fontstring","(Durotar)"))
            assert(not HasWidgetText(created,"fontstring","The breadcrumb starts in"))
            assert(HasWidgetText(created,"fontstring","Breadcrumb Quest Skipped"))
            assert(#UISpecialFrames==1 and UISpecialFrames[1]=="ForeverQuestPinsBreadcrumb")

            local waypoint=FindWidget(created,"Button","Set Waypoint")
            local ignore=FindWidget(created,"Button","Ignore")
            assert(waypoint.width==ignore.width,
                "the actions share one width")
            assert(ignore.points[2]==waypoint,
                "the actions share one row")
            assert(panel.height and panel.height<220,
                "an empty status line must not pad the dialog")
            assert(panel.height==-waypoint.points[3]+24+16,
                "the frame ends one button pad below the action row")

            ns.Breadcrumbs.HandleAccepted(801)
            assert(panel.shown)
            assert(HasWidgetText(created,"fontstring","Breadcrumb A"))
            local panels=0
            for i=1,#created do
                if created[i]==panel then panels=panels+1 end
            end
            assert(panels==1, "rapid accepts reuse one dialog")

            FindWidget(created,"Button","Ignore"):GetScript("OnClick")()
            assert(panel.shown, "the queued notice replaces the ignored one")
            assert(HasWidgetText(created,"fontstring","Breadcrumb B"))
            assert(not HasWidgetText(created,"fontstring","Breadcrumb A"))

            FindWidget(created,"Button","Ignore"):GetScript("OnClick")()
            assert(not panel.shown)
            ns.Breadcrumbs.HandleAccepted(800)
            assert(not panel.shown, "ignore suppresses the follow-up for the session")

            ns.Breadcrumbs.ShowPreview()
            assert(panel.shown)
            assert(HasWidgetText(created,"fontstring","In Search of Menara Voidrender"))
            panel:Hide()
            assert(not panel.shown, "Escape hides without reopening the preview")
            assert(FindWidget(created,"Button","Set Waypoint"))

            options.warnSkippedBreadcrumb=false
            ns.Breadcrumbs.HandleAccepted(801)
            assert(not panel.shown, "the option suppresses new notices")
            ns.Breadcrumbs.ShowPreview()
            assert(panel.shown, "the preview ignores the option")
            panel:Hide()

            assert(#UISpecialFrames==1, "the dialog name is registered once")

end
cases["breadcrumbs_runtime.test_dialog_waypoint_and_quest_log_abandon"] = function()

            created={}
            ns={Quests={
                [800]={sourceQuestSingle={4736},title="Follow-up"},
                [1796]={title="Components for the Enchanted Gold Bloodrobe",mapID=1413},
                [4736]={isBreadcrumb=true,mapID=1455,title="In Search of Menara Voidrender"},
            }}
            canTrack=true
            trackMessage=nil
            ns.GetOption=function(key) return key=="warnSkippedBreadcrumb" and true or false end
            ns.GetQuestTitle=function(questID) return ns.Quests[questID] and ns.Quests[questID].title end
            ns.IsQuestFlaggedCompleted=function() return false end
            ns.IsQuestHidden=function() return false end
            ns.IsOnQuest=function(questID) return questID==800 end
            ns.IsQuestReadyForTurnIn=function() return false end
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 9 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return true end
            ns.CanTrackQuest=function() return canTrack,trackMessage end
            ns.TrackQuest=function(questID) tracked=questID; return true end
            UnitLevel=function() return 40 end
            InstallDialogStubs(ns, created)

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            ns.Breadcrumbs.HandleAccepted(800)
            local panel=_G.ForeverQuestPinsBreadcrumb
            local waypoint=FindWidget(created,"Button","Set Waypoint")
            assert(panel.shown and waypoint)
            assert(not FindWidget(created,"Button","Abandon Quest"),
                "the dialog no longer abandons the quest from addon code")
            assert(waypoint.enabled==true)
            assert(waypoint.disabledReason==nil,
                "an enabled waypoint must not carry a disabled tooltip")

            waypoint:GetScript("OnClick")()
            assert(tracked==4736 and not panel.shown)

            canTrack=false
            trackMessage="No quest location is available yet."
            ns.Breadcrumbs.HandleAccepted(800)
            assert(panel.shown and waypoint.enabled==false)
            assert(waypoint.disabledReason=="No quest location is available yet.")
            canTrack=true
            trackMessage=nil
            tracked=nil
            ns.Breadcrumbs.OnQuestEnded(800)
            assert(not panel.shown, "ending the follow-up closes the notice")
            assert(tracked==4736, "the quest log abandon sets a waypoint to the breadcrumb")

            tracked=nil
            ns.Breadcrumbs.HandleAccepted(800)
            assert(panel.shown)
            ns.Breadcrumbs.OnQuestEnded(800)
            assert(not panel.shown and tracked==4736,
                "the quest log abandon path sets a waypoint")

end
cases["breadcrumbs_runtime.test_preview_is_inert"] = function()

            created={}
            ns={Quests={
                [1796]={sourceQuestSingle={4736},title="Components for the Enchanted Gold Bloodrobe",mapID=1413},
                [4736]={isBreadcrumb=true,mapID=1455,title="In Search of Menara Voidrender"},
            }}
            tracked=nil
            ns.GetOption=function(key) return key=="warnSkippedBreadcrumb" and true or false end
            ns.GetQuestTitle=function(questID) return ns.Quests[questID] and ns.Quests[questID].title end
            ns.IsQuestFlaggedCompleted=function() return false end
            ns.IsQuestHidden=function() return false end
            ns.IsOnQuest=function(questID) return questID==1796 end
            ns.IsQuestReadyForTurnIn=function() return false end
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 9 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return true end
            ns.CanTrackQuest=function() return true end
            ns.TrackQuest=function(questID) tracked=questID; return true end
            UnitLevel=function() return 40 end
            InstallDialogStubs(ns, created)

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            ns.Breadcrumbs.ShowPreview()
            local panel=_G.ForeverQuestPinsBreadcrumb
            local waypoint=FindWidget(created,"Button","Set Waypoint")
            assert(panel.shown and waypoint)
            assert(not FindWidget(created,"Button","Abandon Quest"))
            assert(waypoint.enabled==false)
            assert(waypoint.disabledReason:find("Preview only.",1,true))

            waypoint:GetScript("OnClick")()
            assert(tracked==nil, "a preview never creates a waypoint")
            assert(panel.shown)

            ns.Breadcrumbs.HandleAccepted(1796)
            assert(panel.shown and waypoint.enabled==true,
                "a real notice replaces an inert preview with the same breadcrumb")
            assert(waypoint.disabledReason==nil)
            assert(HasWidgetText(created,"fontstring","Components for the Enchanted Gold Bloodrobe"))

            panel:Hide()
            assert(not panel.shown, "Escape dismisses a real notice")
            ns.Breadcrumbs.HandleAccepted(1796)
            assert(not panel.shown, "Escape suppresses the follow-up for the session")

end
cases["breadcrumbs_runtime.test_accepting_breadcrumb_clears_notice_and_queue"] = function()

            created={}
            ns={Quests={
                [800]={sourceQuestSingle={400},title="Follow-up A"},
                [400]={isBreadcrumb=true,mapID=1411,title="Breadcrumb A"},
                [801]={sourceQuestSingle={401},title="Follow-up B"},
                [401]={isBreadcrumb=true,mapID=1411,title="Breadcrumb B"},
                [803]={sourceQuestSingle={235,742},title="Follow-up C"},
                [235]={isBreadcrumb=true,mapID=1454,altQuests={742},title="Breadcrumb C1"},
                [742]={isBreadcrumb=true,mapID=1456,altQuests={235},title="Breadcrumb C2"},
                [802]={sourceQuestSingle={402},title="Follow-up D"},
                [402]={isBreadcrumb=true,mapID=1411,title="Breadcrumb D"},
            }}
            onQuest={}
            options={warnSkippedBreadcrumb=true,debug=false}
            ns.GetOption=function(key) return options[key] end
            ns.GetQuestTitle=function(questID) return ns.Quests[questID] and ns.Quests[questID].title end
            ns.IsQuestFlaggedCompleted=function() return false end
            ns.IsQuestHidden=function() return false end
            ns.IsOnQuest=function(questID) return onQuest[questID] or false end
            ns.IsQuestReadyForTurnIn=function() return false end
            ns.GetPlayerRaceID=function() return 2 end
            ns.GetPlayerClassID=function() return 2 end
            ns.GetPlayerFaction=function() return "Horde" end
            ns.HasRequiredSkill=function() return true end
            ns.CanTrackQuest=function() return true end
            ns.TrackQuest=function() return true end
            UnitLevel=function() return 40 end
            InstallDialogStubs(ns, created)

assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            ns.Breadcrumbs.OnQuestAccepted(800)
            assert(#timers==1, "accept checks wait one tick for the quest log")
            assert(_G.ForeverQuestPinsBreadcrumb==nil, "the dialog is not built before the check")
            timers[1]()
            local panel=_G.ForeverQuestPinsBreadcrumb
            assert(panel and panel.shown)
            assert(HasWidgetText(created,"fontstring","Breadcrumb A"))

            onQuest[400]=true
            ns.Breadcrumbs.OnQuestAccepted(400)
            assert(not panel.shown, "accepting the named breadcrumb closes the notice")

            onQuest[400]=nil
            timers={}
            ns.Breadcrumbs.OnQuestAccepted(800)
            timers[1]()
            assert(panel.shown, "a breadcrumb accept does not suppress the follow-up")

            ns.Breadcrumbs.HandleAccepted(801)
            assert(HasWidgetText(created,"fontstring","Breadcrumb A"))
            onQuest[401]=true
            ns.Breadcrumbs.OnQuestAccepted(401)
            assert(panel.shown and HasWidgetText(created,"fontstring","Breadcrumb A"),
                "accepting a breadcrumb drops only queued notices that named it")
            assert(not HasWidgetText(created,"fontstring","Breadcrumb B"))

            FindWidget(created,"Button","Ignore"):GetScript("OnClick")()
            assert(not panel.shown, "the dropped queued notice never appears")

            options.warnSkippedBreadcrumb=false
            timers={}
            ns.Breadcrumbs.OnQuestAccepted(800)
            assert(#timers==0, "the option gate stops the accept check")

            options.warnSkippedBreadcrumb=true
            onQuest[401]=nil
            timers={}
            ns.Breadcrumbs.OnQuestAccepted(802)
            timers[1]()
            ns.Breadcrumbs.HandleAccepted(801)
            assert(HasWidgetText(created,"fontstring","Breadcrumb D"))
            ns.Breadcrumbs.OnQuestEnded(801)
            assert(panel.shown and HasWidgetText(created,"fontstring","Breadcrumb D"),
                "ending a follow-up drops only its queued notice")
            ns.Breadcrumbs.OnQuestEnded(802)
            assert(not panel.shown, "ending the visible follow-up closes the notice")

            timers={}
            ns.Breadcrumbs.OnQuestAccepted(803)
            timers[1]()
            assert(panel.shown and HasWidgetText(created,"fontstring","Breadcrumb C1"))
            onQuest[742]=true
            ns.Breadcrumbs.OnQuestAccepted(742)
            assert(not panel.shown, "an alternate breadcrumb also settles the notice")

end
cases["breadcrumbs_runtime.test_shipped_database_breadcrumb_edges"] = function()

            ns={}
            completed={}
            C_QuestLog={
                GetAllCompletedQuestIDs=function() return completed end,
                IsQuestFlaggedCompleted=function(questID) return completed[questID] or false end,
                IsOnQuest=function() return false end,
            }
            UnitLevel=function() return 40 end
            UnitFactionGroup=function() return "Horde" end
            UnitRace=function() return "Orc","Orc",2 end
            UnitClass=function() return "Warlock","WARLOCK",9 end
            playerMap=1458
            C_Map={GetBestMapForUnit=function() return playerMap end}
            ns.GetOption=function(key) return key~="debug" end

assert(loadfile("Database/ForeverQuests.lua"))("ForeverQuestPins", ns)
assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
assert(loadfile("Breadcrumbs.lua"))("ForeverQuestPins", ns)

            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(788)==4641)
            completed[4641]=true
            ns.InvalidateCompletionCache()
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(788)==nil)
            completed[4641]=nil
            ns.InvalidateCompletionCache()

            completed[742]=true
            ns.InvalidateCompletionCache()
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(6383)==nil,
                "a completed alternate breadcrumb suppresses the warning")
            completed[742]=nil
            ns.InvalidateCompletionCache()

            local candidates=ns.Breadcrumbs.CollectCandidates(1801)
            assert(#candidates==2 and candidates[1]==2996 and candidates[2]==3001)
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(1801)==3001)

            candidates=ns.Breadcrumbs.CollectCandidates(1796)
            assert(#candidates==2 and candidates[1]==4737 and candidates[2]==4739)
            playerMap=1454
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(1796)==4737)

            playerMap=1442
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(6543)==6542)

            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(2)==nil,
                "a non-breadcrumb prerequisite is not a breadcrumb warning")

            completed[1782]=true
            ns.InvalidateCompletionCache()
            assert(ns.Breadcrumbs.FindSkippedBreadcrumb(1710)==nil,
                "a completed shared route means 1703 did not gate 1710")

end
cases["map_pins_runtime.display_updates_keep_the_existing_pin_set"] = function()
    setupPinRendering()
    ns.MapPins:Refresh("initial")
    local status = ns.MapPins:GetStatus()
    assert(status.mode == "canvas" and status.count == 1 and pin.shown)
    local painted = status.refreshes
    assert(painted and painted > 0)

    ns.MapPins:Refresh("map-display")
    ns.MapPins:Refresh("map-changed")
    status = ns.MapPins:GetStatus()
    assert(status.refreshes == painted, "display updates must not rebuild the same view")
    assert(status.displaySkips == 2)
    assert(pin.shown, "pins stay visible between display updates")

    ns.MapPins:Refresh("manual")
    status = ns.MapPins:GetStatus()
    assert(status.refreshes == painted + 1, "a real refresh still repaints")
    assert(status.displaySkips == 2)

    OpenMapAPI = {
        IsStitched = function() return true end,
        WorldFromMap = function(_, x, y) return x, y end,
        MapFromWorld = function(_, u, v) return u, v end,
    }
    painted = ns.MapPins:GetStatus().refreshes
    ns.MapPins:Refresh("map-display")
    assert(ns.MapPins:GetStatus().refreshes == painted + 1,
        "switching OpenMap mode still repaints")
end

cases["map_pins_runtime.breadcrumb_quests_are_labelled_in_tooltips"] = function()
    setupPinRendering()
    ns.Quests[101].isBreadcrumb = true
    ns.MapPins:Refresh("breadcrumb")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("Breadcrumb quest"))
    assert(not tooltipHas("Includes a breadcrumb quest"))

    ns.Quests[101].isBreadcrumb = nil
    ns.Quests[102] = { mapID = 1, x = 50, y = 50, isBreadcrumb = true }
    ns.ByMap[1][#ns.ByMap[1] + 1] = 102
    ns.MapPins:Refresh("mixed")
    pin.scripts.OnEnter(pin)
    assert(tooltipHas("Includes a breadcrumb quest"),
        "a mixed stack must not claim every quest is a breadcrumb")
    assert(not tooltipHas("Breadcrumb quest"))
end

cases["core_runtime.restricted_actions_cover_combat_and_client_restrictions"] = function()
    ns = {}
    CreateFrame = function()
        return {
            SetScript = function() end,
            RegisterEvent = function() end,
        }
    end
    InCombatLockdown = function() return false end
    UnitAffectingCombat = function() return false end
    assert(loadfile("Core.lua"))("ForeverQuestPins", ns)

    assert(ns.AddOnActionsRestricted() == false, "out of combat with no restrictions is allowed")

    InCombatLockdown = function() return true end
    assert(ns.AddOnActionsRestricted() == true, "combat blocks addon actions")

    InCombatLockdown = function() error("unavailable") end
    UnitAffectingCombat = function(unit) return unit == "player" end
    assert(ns.AddOnActionsRestricted() == true, "unit combat state is the fallback")

    UnitAffectingCombat = function() return false end
    Enum = { AddOnRestrictionType = { Combat = 11, Encounter = 12, ChallengeMode = 13, PvPMatch = 14 } }
    local active = { [12] = true }
    C_RestrictedActions = {
        IsAddOnRestrictionActive = function(kind) return active[kind] == true end,
    }
    assert(ns.AddOnActionsRestricted() == true, "an encounter blocks addon actions")

    active = {}
    assert(ns.AddOnActionsRestricted() == false, "inactive restrictions are allowed")

    Enum = nil
    C_RestrictedActions = { IsAddOnRestrictionActive = function() return true end }
    assert(ns.AddOnActionsRestricted() == false, "clients without restriction kinds are allowed")

    C_RestrictedActions = nil
    assert(ns.AddOnActionsRestricted() == false, "clients without restricted-action APIs are allowed")
end

local SPARKLE_CVAR = "outlineModeShowLootEffectWhenDisabled"
local SPARKLE_MIRROR_CVAR = "ForeverQuestPinsSettings"

local function sparkleFixture(initialValue, mirrorText)
    local state = {
        cvar = initialValue or "0",
        mirror = mirrorText or "",
        reads = {},
        writes = {},
        unexpected = {},
        messages = {},
        timers = {},
    }
    -- Sparkle may touch only the one loot CVar. Config also mirrors settings
    -- through its own CVar; nothing else is acceptable. Record violations
    -- instead of throwing, because Sparkle wraps its CVar calls in pcall.
    local function check(key)
        if key ~= SPARKLE_CVAR and key ~= SPARKLE_MIRROR_CVAR then
            state.unexpected[#state.unexpected + 1] = tostring(key)
        end
    end
    C_CVar = {
        GetCVar = function(key)
            check(key)
            state.reads[#state.reads + 1] = key
            if key == SPARKLE_CVAR then
                return state.cvar
            end
            return state.mirror
        end,
        SetCVar = function(key, value)
            check(key)
            state.writes[#state.writes + 1] = { key = key, value = value }
            if key == SPARKLE_CVAR then
                state.cvar = value
            elseif key == SPARKLE_MIRROR_CVAR then
                state.mirror = value
            end
        end,
        RegisterCVar = function() end,
    }
    CreateFrame = function()
        local frame = {}
        function frame:SetScript(name, fn) self[name] = fn end
        function frame:RegisterEvent(name)
            self.events = self.events or {}
            self.events[name] = true
        end
        state.frame = frame
        return frame
    end
    C_Timer = {
        After = function(delay, callback)
            state.timers[#state.timers + 1] = { delay = delay, callback = callback }
        end,
    }
    InCombatLockdown = function() return state.combat == true end
    UnitAffectingCombat = function() return false end
    print = function(message) state.messages[#state.messages + 1] = message end

    function state.assertClean()
        assert(#state.unexpected == 0,
            "unexpected CVar access: " .. table.concat(state.unexpected, ", "))
    end
    function state.targetWrites()
        state.assertClean()
        local values = {}
        for _, write in ipairs(state.writes) do
            if write.key == SPARKLE_CVAR then
                values[#values + 1] = write.value
            end
        end
        return values
    end
    function state.fire(event, ...)
        assert(state.frame and state.frame.OnEvent, "Sparkle frame did not register an event handler")
        state.frame.OnEvent(state.frame, event, ...)
        state.assertClean()
    end
    function state.runTimers()
        state.assertClean()
        local pending = state.timers
        state.timers = {}
        for _, timer in ipairs(pending) do
            timer.callback()
        end
        state.assertClean()
        return pending
    end
    return state
end

local function loadSparkleAddon()
    ns = {}
    ForeverQuestPinsDB = ForeverQuestPinsDB or {}
    ForeverQuestPinsCharDB = ForeverQuestPinsCharDB or {}
    ForeverQuestPinsDB_Settings = ForeverQuestPinsDB_Settings or {}
    ForeverQuestPinsCharacterSettings = ForeverQuestPinsCharacterSettings or {}
    assert(loadfile("Config.lua"))("ForeverQuestPins", ns)
    assert(loadfile("Sparkle.lua"))("ForeverQuestPins", ns)
    ns.InitSettings()
end

cases["sparkle_runtime.default_is_off_and_existing_settings_survive"] = function()
    local state = sparkleFixture("0")
    ForeverQuestPinsDB = { _revision = 7, enabled = false, showPvP = true, trivialLevelGap = 5 }
    loadSparkleAddon()

    local db = ns.GetSettings()
    assert(db.sparkleQuestItems == false, "sparkles default off")
    assert(db.enabled == false and db.showPvP == true and db.trivialLevelGap == 5,
        "existing options survive")
    assert(db._revision == 7, "adding a default does not bump the revision")
    assert(state.mirror:find("sparkleQuestItems=0", 1, true), "the mirror gains the new option")

    state.fire("PLAYER_LOGIN")
    assert(#state.targetWrites() == 0, "the default leaves the client's own setting alone")
    assert(#state.messages == 0, "a fresh install does not see the restart notice")
    assert(db._revision == 7, "applying the CVar does not bump the revision")
    state.assertClean()
end

cases["sparkle_runtime.enabling_writes_only_the_loot_sparkle_cvar"] = function()
    local state = sparkleFixture("0")
    loadSparkleAddon()

    state.fire("PLAYER_LOGIN")
    assert(#state.targetWrites() == 0)
    ns.SetOption("sparkleQuestItems", true)
    local writes = state.targetWrites()
    assert(#writes == 1 and writes[1] == "1")
    ns.SetOption("sparkleQuestItems", true)
    assert(#state.targetWrites() == 1, "an already-on option does not rewrite the CVar")
    state.assertClean()
end

cases["sparkle_runtime.outline_cvars_are_never_read_or_written"] = function()
    local state = sparkleFixture("1")
    loadSparkleAddon()

    state.fire("PLAYER_LOGIN")
    ns.SetOption("sparkleQuestItems", false)
    ns.SetOption("sparkleQuestItems", true)
    state.cvar = "0"
    state.fire("CVAR_UPDATE", "graphicsquality", "3")
    state.runTimers()

    for _, key in ipairs(state.reads) do
        assert(key == SPARKLE_CVAR or key == SPARKLE_MIRROR_CVAR)
    end
    assert(table.concat(state.targetWrites(), ",") == "0,1,1")
    state.assertClean()
end

cases["sparkle_runtime.graphics_quality_change_reapplies_after_delay"] = function()
    local state = sparkleFixture("1")
    loadSparkleAddon()
    ns.SetOption("sparkleQuestItems", true)

    state.fire("PLAYER_LOGIN")
    state.runTimers()
    assert(#state.targetWrites() == 0, "login leaves an already-on CVar alone")

    state.cvar = "0"
    state.fire("CVAR_UPDATE", "graphicsquality", "3")
    assert(#state.targetWrites() == 0, "the write waits for the delayed apply")
    local timers = state.runTimers()
    assert(#timers == 1)
    assert(state.cvar == "1", "a graphics preset is repaired")

    state.cvar = "0"
    state.fire("CVAR_UPDATE", "raidgraphicsquality", "2")
    state.runTimers()
    assert(state.cvar == "1")

    state.cvar = "0"
    state.fire("CVAR_UPDATE", "sound", "0")
    assert(#state.timers == 0, "unrelated CVars do not schedule an apply")
    state.assertClean()
end

cases["sparkle_runtime.combat_change_defers_until_regen"] = function()
    local state = sparkleFixture("0")
    loadSparkleAddon()

    ns.SetOption("sparkleQuestItems", true)
    local writesBefore = #state.targetWrites()
    state.combat = true
    state.cvar = "0"
    ns.ApplySparkleSetting()
    assert(#state.targetWrites() == writesBefore, "no CVar apply during combat")
    state.combat = false
    state.fire("PLAYER_REGEN_ENABLED")
    assert(state.cvar == "1")

    state.combat = true
    ns.SetOption("sparkleQuestItems", false)
    assert(state.cvar == "1", "the change waits for combat to end")
    assert(#state.messages == 0)
    state.combat = false
    state.fire("PLAYER_REGEN_ENABLED")
    assert(state.cvar == "0")
    assert(#state.messages == 1, "the restart warning waits for combat to end")
    state.assertClean()
end

cases["sparkle_runtime.disabling_writes_zero_and_warns_once"] = function()
    local state = sparkleFixture("0")
    loadSparkleAddon()

    state.fire("PLAYER_LOGIN")
    assert(#state.messages == 0)

    ns.SetOption("sparkleQuestItems", true)
    assert(state.cvar == "1")
    ns.SetOption("sparkleQuestItems", false)
    assert(state.cvar == "0")
    assert(state.mirror:find("sparkleQuestItems=0", 1, true), "the mirror stores the off value")
    assert(#state.messages == 1)
    assert(state.messages[1]:find("Restart the game", 1, true))

    ns.ApplySparkleSetting()
    state.fire("PLAYER_LOGIN")
    assert(#state.messages == 1, "repeat logins stay quiet while the option is off")

    ns.SetOption("sparkleQuestItems", true)
    assert(state.cvar == "1")
    ns.SetOption("sparkleQuestItems", false)
    assert(#state.messages == 2, "turning it back on re-arms the warning")

    ns.WipeSettings()
    assert(ns.GetOption("sparkleQuestItems") == false, "Use Defaults leaves sparkles off")
    assert(state.cvar == "0")
    assert(#state.messages == 2, "the CVar is already off, so no second notice")
    state.assertClean()
end

cases["sparkle_runtime.stored_off_setting_leaves_the_client_alone"] = function()
    local state = sparkleFixture("1", "revision=9;sparkleQuestItems=0;enabled=1")
    loadSparkleAddon()

    assert(ns.GetOption("sparkleQuestItems") == false, "the stored off value wins")
    state.fire("PLAYER_LOGIN")
    assert(state.cvar == "1", "login must not touch the client's own sparkle setting")
    assert(#state.messages == 0, "no restart notice for a player who never turned it on")
    state.assertClean()
end

cases["sparkle_runtime.missing_cvar_or_api_is_safe"] = function()
    local state = sparkleFixture("1")
    loadSparkleAddon()
    local cvarAPI = C_CVar

    C_CVar = nil
    state.fire("PLAYER_LOGIN")
    state.runTimers()
    ns.SetOption("sparkleQuestItems", true)
    ns.SetOption("sparkleQuestItems", false)
    assert(#state.targetWrites() == 0)
    assert(#state.messages == 0, "no warning when the CVar API is missing")
    assert(ns.ApplySparkleSetting() == false)
    assert(ns.DisableSparkleSetting() == false)

    C_CVar = cvarAPI
    ns.SetOption("sparkleQuestItems", true)
    local writes = #state.targetWrites()

    C_CVar = { GetCVar = function() return nil end }
    assert(ns.ApplySparkleSetting() == false)
    assert(#state.targetWrites() == writes)

    C_CVar = {
        GetCVar = function() return nil end,
        SetCVar = function() error("must not write when the CVar is missing") end,
    }
    assert(ns.ApplySparkleSetting() == false)
    state.assertClean()
end

cases["sparkle_runtime.diagnostics_report_cvar_state"] = function()
    local state = sparkleFixture("1")
    loadSparkleAddon()
    UnitRace = function() return nil, "Human", 1 end
    UnitClass = function() return nil, "Warrior", 1 end
    UnitFactionGroup = function() return "Alliance" end
    UnitLevel = function() return 60 end

    ns.PrintAPIProbe()
    local probe = table.concat(state.messages, "\n")
    assert(probe:find("C_CVar.GetCVar: yes", 1, true))
    assert(probe:find(SPARKLE_CVAR .. ": 1", 1, true))

    state.messages = {}
    C_CVar = nil
    ns.PrintAPIProbe()
    probe = table.concat(state.messages, "\n")
    assert(probe:find("C_CVar.GetCVar: no", 1, true))
    assert(probe:find(SPARKLE_CVAR .. ": missing", 1, true))

    state.messages = {}
    C_CVar = { GetCVar = function() return nil end }
    ns.PrintAPIProbe()
    probe = table.concat(state.messages, "\n")
    assert(probe:find(SPARKLE_CVAR .. ": missing", 1, true))

    state.messages = {}
    ns.PrintSettingsDebug()
    local settings = table.concat(state.messages, "\n")
    assert(settings:find("sparkleQuestItems raw=false effective=false", 1, true))
    state.assertClean()
end

local function trackerQuest(id, title, level, isComplete)
    return {
        id = id,
        title = title,
        level = level,
        isComplete = isComplete,
        GetID = function(self) return self.id end,
        IsComplete = function(self) return self.isComplete == true end,
    }
end

local function trackerDataFixture()
    ns = { Quests = {}, db = {} }
    local options = {
        enhanceQuestTracker = true,
        trackerSort = "blizzard",
        trackerFilter = "all",
    }
    ns.GetOption = function(key) return options[key] end
    ns.SetOption = function(key, value) options[key] = value end
    ns.CharacterKey = function() return "Hero-Realm" end
    ns.IsInstanceQuest = function(questID) return questID == 105 end
    assert(loadfile("TrackerData.lua"))("ForeverQuestPins", ns)
    return ns, options
end

local function installTrackerQuestLog()
    C_QuestLog = {
        GetHeaderIndexForQuest = function(questID)
            return ({ [101] = 2, [102] = 1, [103] = 1, [104] = 3 })[questID]
        end,
        GetInfo = function(index)
            return ({
                [1] = { isHeader = true, title = "Ashenvale" },
                [2] = { isHeader = true, title = "Darkshore" },
                [3] = { isHeader = true, title = "The Barrens" },
            })[index]
        end,
        GetLogIndexForQuestID = function(questID) return 10 + (questID or 0) end,
        GetDistanceSqToQuest = function(questID)
            return ({ [101] = 100, [102] = 50, [103] = 200, [104] = 10 })[questID], true
        end,
        GetNextWaypoint = function(questID)
            return ({ [101] = 2, [102] = 1, [103] = 1, [104] = 3 })[questID]
        end,
        GetTitleForQuestID = function(questID) return "Quest " .. tostring(questID) end,
        GetQuestDifficultyLevel = function() return nil end,
    }
    C_Map = {
        GetBestMapForUnit = function() return 10 end,
        GetMapInfo = function(mapID)
            return ({
                [1] = { name = "Ashenvale", mapType = 3, parentMapID = 100 },
                [2] = { name = "Darkshore", mapType = 3, parentMapID = 100 },
                [3] = { name = "The Barrens", mapType = 3, parentMapID = 100 },
                [10] = { name = "Blackfathom Deeps", mapType = 4, parentMapID = 1 },
                [100] = { name = "Kalimdor", mapType = 2, parentMapID = 200 },
                [200] = { name = "Azeroth", mapType = 1, parentMapID = 0 },
            })[mapID]
        end,
    }
    Enum = { UIMapType = { World = 1, Continent = 2 } }
    InCombatLockdown = function() return false end
    UnitAffectingCombat = function() return false end
end

local function trackerIDs(entries)
    local ids = {}
    for i = 1, #entries do
        ids[i] = tostring(entries[i].questID)
    end
    return table.concat(ids, ",")
end

cases["tracker_runtime.zone_groups_sorts_and_filters"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    local infos = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
        { quest = trackerQuest(102, "Beta", 10), index = 2 },
        { quest = trackerQuest(103, "Gamma", 30), index = 3 },
        { quest = trackerQuest(104, "Delta", 5), index = 4 },
        { quest = trackerQuest(105, "Epsilon", nil), index = 5 },
    }

    local entries = data.EnhanceQuestWatchInfos(nil, infos)
    assert(#entries == 5)
    assert(entries[1].zoneName == "Ashenvale", "the current zone group goes first")
    assert(entries[2].zoneName == "Ashenvale")
    assert(entries[3].zoneName == "Darkshore")
    assert(entries[4].zoneName == "The Barrens")
    assert(entries[5].zoneName == "Other")

    options.trackerSort = "distance"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103,104,101,105")
    options.trackerSort = "level"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103,104,101,105")
    options.trackerSort = "title"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103,101,104,105")
    options.trackerSort = "blizzard"

    options.trackerFilter = "current"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103")
    options.trackerFilter = "instance"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "105")
    options.trackerFilter = "all"
    assert(#data.EnhanceQuestWatchInfos(nil, infos) == 5)
    infos[1].isTracked = false
    options.trackerFilter = "tracked"
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103,104,105")
    infos[1].isTracked = nil
end

cases["tracker_runtime.completed_filter_shows_only_complete_quests"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    options.trackerFilter = "completed"
    local infos = {
        { quest = trackerQuest(101, "Alpha", 20, false), index = 1 },
        { quest = trackerQuest(102, "Beta", 10, true), index = 2 },
        { quest = trackerQuest(103, "Gamma", 30, true), index = 3 },
    }
    assert(trackerIDs(data.EnhanceQuestWatchInfos(nil, infos)) == "102,103")
end

cases["tracker_runtime.combat_reuses_cached_annotations"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    options.trackerSort = "blizzard"
    local infos = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
        { quest = trackerQuest(102, "Beta", 10), index = 2 },
    }
    data.EnhanceQuestWatchInfos(nil, infos)

    C_QuestLog.GetHeaderIndexForQuest = function() error("must not query headers in combat") end
    C_QuestLog.GetDistanceSqToQuest = function() error("must not query distance in combat") end
    InCombatLockdown = function() return true end
    UnitAffectingCombat = function() return true end

    local entries = data.EnhanceQuestWatchInfos(nil, infos)
    assert(entries[1].zoneName == "Ashenvale", "combat keeps the cached zone")
    assert(entries[2].zoneName == "Darkshore")
end

cases["tracker_runtime.combat_places_new_quests_under_other"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    local first = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
    }
    data.EnhanceQuestWatchInfos(nil, first)
    C_QuestLog.GetHeaderIndexForQuest = function() error("must not query headers in combat") end
    C_QuestLog.GetDistanceSqToQuest = function() error("must not query distance in combat") end
    InCombatLockdown = function() return true end
    UnitAffectingCombat = function() return true end
    local both = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
        { quest = trackerQuest(106, "New", 30), index = 2 },
    }
    local entries = data.EnhanceQuestWatchInfos(nil, both)
    assert(entries[1].zoneName == "Darkshore")
    assert(entries[2].zoneName == "Other")
end

cases["tracker_runtime.missing_distance_api_keeps_groups"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    C_QuestLog.GetDistanceSqToQuest = nil
    options.trackerSort = "distance"
    local infos = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
        { quest = trackerQuest(102, "Beta", 10), index = 2 },
        { quest = trackerQuest(103, "Gamma", 30), index = 3 },
        { quest = trackerQuest(104, "Delta", 5), index = 4 },
        { quest = trackerQuest(105, "Epsilon", nil), index = 5 },
    }
    local entries = data.EnhanceQuestWatchInfos(nil, infos)
    assert(#entries == 5)
    assert(entries[1].zoneName == "Ashenvale")
    assert(entries[5].zoneName == "Other")
end

cases["tracker_runtime.missing_grouping_keeps_flat_order"] = function()
    local data, options = trackerDataFixture()
    installTrackerQuestLog()
    C_QuestLog.GetInfo = nil
    local infos = {
        { quest = trackerQuest(101, "Alpha", 20), index = 1 },
        { quest = trackerQuest(102, "Beta", 10), index = 2 },
    }
    local entries = data.EnhanceQuestWatchInfos(nil, infos)
    assert(#entries == 2)
    assert(entries[1].zoneName == nil)
end

cases["tracker_runtime.header_falls_back_to_the_log_index"] = function()
    local data = trackerDataFixture()
    installTrackerQuestLog()
    C_QuestLog.GetHeaderIndexForQuest = nil
    C_QuestLog.GetLogIndexForQuestID = function() return 3 end
    assert(data.QuestHeaderTitle(101) == "Darkshore")
end

cases["tracker_runtime.collapsed_zones_persist_per_character"] = function()
    local data = trackerDataFixture()
    data.SetZoneCollapsed("Ashenvale", true)
    assert(data.IsZoneCollapsed("Ashenvale") == true)
    data.CharacterKey = function() return "Other-Realm" end
    assert(data.IsZoneCollapsed("Ashenvale") == false)
    data.CharacterKey = function() return "Hero-Realm" end
    assert(data.IsZoneCollapsed("Ashenvale") == true)
    data.ToggleZoneCollapsed("Ashenvale")
    assert(data.IsZoneCollapsed("Ashenvale") == false)
end

cases["tracker_runtime.module_registration_and_gamepad_fallback"] = function()
    local options = {
        enhanceQuestTracker = false,
        trackerSort = "blizzard",
        trackerFilter = "all",
        trackerBottomInset = 15,
        selectNearestQuest = false,
    }
    local collapsed = {}
    ns = {
        db = {},
        L = setmetatable({}, { __index = function(_, key) return key end }),
        GetOption = function(key) return options[key] end,
        SetOption = function(key, value) options[key] = value end,
        IsZoneCollapsed = function(zone) return collapsed[zone] == true end,
        ToggleZoneCollapsed = function(zone) collapsed[zone] = not collapsed[zone] end,
        EnhanceQuestWatchInfos = function(_, infos) return infos end,
        HookQuestLinkModule = function() end,
        AddOnActionsRestricted = function() return false end,
        CharacterKey = function() return "Hero-Realm" end,
    }
    local frames = {}
    local added, removed = 0, 0
    local function fakeFrame(kind, name, parent, template)
        local frame = {
            kind = kind, name = name, parent = parent, template = template,
            scripts = {}, events = {}, shown = true, height = 0,
        }
        function frame:SetScript(event, fn) self.scripts[event] = fn end
        function frame:GetScript(event) return self.scripts[event] end
        function frame:HookScript(event, fn)
            local previous = self.scripts[event]
            self.scripts[event] = function(...)
                if previous then previous(...) end
                return fn(...)
            end
        end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event)
            self.events[event] = nil
            self.unregisteredEvents = self.unregisteredEvents or {}
            self.unregisteredEvents[event] = true
        end
        function frame:SetPoint(point, relativeTo, relativePoint, x, y)
            self.points = self.points or {}
            self.points[#self.points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
        function frame:ClearAllPoints() self.points = {} end
        function frame:SetParent(parent) self.parent = parent end
        function frame:GetParent() return self.parent end
        function frame:SetHeight(height) self.height = height end
        function frame:GetHeight() return self.height or 0 end
        function frame:SetWidth(width) self.width = width end
        function frame:GetWidth() return self.width or 0 end
        function frame:SetSize(width, height) self.width, self.height = width, height end
        function frame:GetPoint() return "TOPRIGHT", UIParent, "TOPRIGHT", -20, -20 end
        function frame:SetScale() end
        function frame:GetScale() return 1 end
        function frame:SetAlpha() end
        function frame:GetAlpha() return 1 end
        function frame:SetFrameStrata() end
        function frame:GetFrameStrata() return "MEDIUM" end
        function frame:SetFrameLevel(level) self.frameLevel = level end
        function frame:GetFrameLevel() return self.frameLevel or 1 end
        function frame:SetClampedToScreen(value) self.clampedToScreen = value end
        function frame:GetClampedToScreen() return self.clampedToScreen or false end
        function frame:SetMovable(value) self.movable = value end
        function frame:SetResizable(value) self.resizable = value end
        function frame:SetUserPlaced(value) self.userPlaced = value end
        function frame:SetDontSavePosition(value) self.dontSavePosition = value end
        function frame:RegisterForDrag() end
        function frame:StartMoving() end
        function frame:StopMovingOrSizing() end
        function frame:EnableMouse(enabled)
            self.mouseEnabled = enabled ~= false
            self.mouseClickEnabled = self.mouseEnabled
        end
        function frame:SetMouseClickEnabled(enabled)
            self.mouseClickEnabled = enabled
        end
        function frame:EnableMouseWheel(enabled)
            self.wheelEnabled = enabled ~= false
        end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:SetShown(shown) self.shown = shown end
        function frame:IsShown() return self.shown end
        function frame:SetVerticalScroll(value) self.scroll = value end
        function frame:GetVerticalScroll() return self.scroll or 0 end
        function frame:GetVerticalScrollRange() return self.range or 0 end
        function frame:UpdateScrollChildRect()
            local child = self.scrollChild
            if child and child.GetHeight then
                self.range = math.max(0, (child:GetHeight() or 0) - (self.height or 0))
            end
        end
        function frame:SetScrollChild(child) self.scrollChild = child end
        function frame:SetHeader(text) self.headerText = text end
        function frame:CreateFontString()
            return {
                SetPoint = function() end,
                SetText = function() end,
                SetShadowColor = function() end,
                SetShadowOffset = function() end,
                SetTextColor = function() end,
                SetFontObject = function() end,
            }
        end
        if template == "ObjectiveTrackerModuleTemplate" then
            frame.Header = fakeFrame("Frame", nil, frame)
            frame.ContentsFrame = fakeFrame("Frame", nil, frame)
            frame.headerHeight = 25
            frame.contentsHeight = 25
            frame.MarkDirty = function() frame.dirty = (frame.dirty or 0) + 1 end
            frame.HasContents = function() return true end
        end
        frames[#frames + 1] = frame
        return frame
    end
    CreateFrame = fakeFrame
    CreateFromMixins = function(...)
        local result = {}
        for i = 1, select("#", ...) do
            local source = select(i, ...)
            if type(source) == "table" then
                for key, value in pairs(source) do result[key] = value end
            end
        end
        return result
    end
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            local source = select(i, ...)
            if type(source) == "table" then
                for key, value in pairs(source) do target[key] = value end
            end
        end
        return target
    end
    local questClicks = 0
    local secureDelegates = 0
    local secureClickCalls = 0
    CreateSecureDelegate = function(handler)
        secureDelegates = secureDelegates + 1
        return function(...)
            secureClickCalls = secureClickCalls + 1
            return handler(...)
        end
    end
    QuestObjectiveTrackerMixin = {
        events = { "QUEST_LOG_UPDATE" },
        BuildQuestWatchInfos = function() return {} end,
        LayoutContents = function() end,
        OnBlockHeaderClick = function() questClicks = questClicks + 1 end,
        OnBlockHeaderEnter = function() end,
        OnBlockHeaderLeave = function() end,
        SetContainer = function(self, container)
            self.parentContainer = container
            self:SetParent(container)
        end,
        Update = function(self, availableHeight, dirtyUpdate)
            self.availableHeight = availableHeight
            self.dirty = false
            return self.contentsHeight or 0
        end,
        IsCollapsed = function(self) return self.collapsed == true end,
    }
    ObjectiveTrackerModuleMixin = {
        LayoutBlock = function(_, block) block.used = true; return true end,
        SetCollapsed = function(self, collapsed) self.collapsed = collapsed end,
        AnchorBlock = function(_, block) block.anchoredOffset = block.offsetX end,
    }
    ObjectiveTrackerFrame = fakeFrame("Frame", "ObjectiveTrackerFrame")
    ObjectiveTrackerFrame.modules = {}
    ObjectiveTrackerFrame.height = 800
    function ObjectiveTrackerFrame:AddModule(module)
        table.insert(self.modules, module)
        if module.SetContainer then module:SetContainer(self) end
        added = added + 1
    end
    function ObjectiveTrackerFrame:RemoveModule(module)
        for i = 1, #self.modules do
            if self.modules[i] == module then
                table.remove(self.modules, i)
                removed = removed + 1
                return
            end
        end
    end
    function ObjectiveTrackerFrame:HasModule(module)
        for i = 1, #self.modules do
            if self.modules[i] == module then return true end
        end
        return false
    end
    function ObjectiveTrackerFrame:IsCollapsed() return false end
    QuestObjectiveTracker = fakeFrame("Frame", "QuestObjectiveTracker")
    QuestObjectiveTracker.uiOrder = 4
    QuestObjectiveTracker.events = { "QUEST_LOG_UPDATE" }
    function QuestObjectiveTracker:MarkDirty() self.dirty = true end
    function QuestObjectiveTracker:GetContextMenuParent() return ObjectiveTrackerFrame end
    QuestObjectiveTracker.shown = true
    ProfessionsRecipeTracker = fakeFrame("Frame", "ProfessionsRecipeTracker")
    ProfessionsRecipeTracker.uiOrder = 9
    ProfessionsRecipeTracker.headerHeight = 25
    ProfessionsRecipeTracker.contentsHeight = 25
    ProfessionsRecipeTracker.shown = false
    function ProfessionsRecipeTracker:SetContainer(container)
        self.parentContainer = container
        self:SetParent(container)
    end
    function ProfessionsRecipeTracker:Update(availableHeight)
        self.availableHeight = availableHeight
        self.dirty = false
        if availableHeight >= self.headerHeight then
            self.height = self.headerHeight
            self:Show()
        else
            self.height = 0
            self:Hide()
        end
        return self.height, false
    end
    ObjectiveTrackerManager = { moduleToContainerMap = {} }
    function ObjectiveTrackerManager:SetModuleContainer(module, container)
        local previous = self.moduleToContainerMap[module]
        if previous then previous:RemoveModule(module) end
        self.moduleToContainerMap[module] = container
        container:AddModule(module)
    end
    function ObjectiveTrackerManager:GetContainerForModule(module)
        return self.moduleToContainerMap[module]
    end
    ObjectiveTrackerManager.moduleToContainerMap[QuestObjectiveTracker] = ObjectiveTrackerFrame
    ObjectiveTrackerManager.moduleToContainerMap[ProfessionsRecipeTracker] = ObjectiveTrackerFrame
    ObjectiveTrackerFrame.modules[1] = QuestObjectiveTracker
    ObjectiveTrackerFrame.modules[2] = ProfessionsRecipeTracker

    local watches = 0
    C_QuestLog = {
        GetNumQuestWatches = function() return watches end,
        GetQuestIDForQuestWatchIndex = function() return nil end,
    }
    QuestCache = {}
    C_XMLUtil = { GetTemplateInfo = function() return {} end }
    TRACKER_HEADER_QUESTS = "Quests"
    ObjectiveTrackerHeaderFont = {}
    ObjectiveTrackerLineFont = {}
    OBJECTIVE_TRACKER_COLOR = {
        Header = { r = 1, g = 1, b = 1 },
        HeaderHighlight = { r = 1, g = 1, b = 1 },
    }
    InCombatLockdown = function() return false end
    UnitAffectingCombat = function() return false end
    local gamepad = false
    local gamepadInit, gamepadUninit
    local transitionRegistered = false
    InputUtil = {
        IsGamepadUIEnabled = function() return gamepad end,
        RegisterForInterfaceTransitions = function() transitionRegistered = true end,
        RegisterGamepadInit = function(_, callback) gamepadInit = callback end,
        RegisterGamepadUninit = function(_, callback) gamepadUninit = callback end,
    }
    C_Timer = {}
    hooksecurefunc = function() end

    assert(loadfile("Tracker.lua"))("ForeverQuestPins", ns)
    assert(ns.TryRegisterQuestTracker())
    assert(transitionRegistered, "gamepad subscribers must register interface transitions first")
    local ourModule
    local standaloneTracker
    for _, frame in ipairs(frames) do
        if frame.name == "FQPQuestObjectiveTracker" then ourModule = frame end
        if frame.name == "FQPStandaloneTracker" then standaloneTracker = frame end
    end
    assert(ourModule, "the addon must create its tracker module")
    assert(standaloneTracker, "the addon must create its standalone tracker container")
    assert(#ObjectiveTrackerFrame.modules == 2
        and ObjectiveTrackerFrame:HasModule(QuestObjectiveTracker)
        and ObjectiveTrackerFrame:HasModule(ProfessionsRecipeTracker),
        "the beta starts off with Blizzard's quest and professions modules")

    options.enhanceQuestTracker = true
    ns.ApplyTrackerState()
    assert(#ObjectiveTrackerFrame.modules == 0,
        "the standalone tracker removes Blizzard's modules from its container")
    assert(standaloneTracker.module == ourModule,
        "the standalone tracker owns the custom quest module")
    assert(standaloneTracker.professionsModule == ProfessionsRecipeTracker,
        "the standalone tracker owns the tracked professions module")
    assert(ProfessionsRecipeTracker.parentContainer == standaloneTracker,
        "the professions module moves into the standalone tracker")
    assert(ProfessionsRecipeTracker.availableHeight == 392,
        "professions are capped at half the tracker height")
    assert(ProfessionsRecipeTracker.shown == true,
        "the professions module remains visible below the quest module")
    assert(ourModule.availableHeight == 750,
        "the quest module gets the tracker height above the professions module")
    assert(QuestObjectiveTracker.shown == false)
    assert(ObjectiveTrackerManager:GetContainerForModule(ourModule) == standaloneTracker,
        "the standalone module's context menu parent is its own container")
    assert(secureDelegates >= 1, "the tracker builds secure delegates for quest clicks and module moves")
    assert(ns.trackerClickSecured == "delegate", "the client's secure delegate is used for quest clicks")
    assert(ourModule.OnBlockHeaderClick ~= QuestObjectiveTrackerMixin.OnBlockHeaderClick,
        "quest clicks run through a secure delegate rather than a tainted direct call")
    secureClickCalls = 0
    ourModule.OnBlockHeaderClick(ourModule, {}, "LeftButton")
    assert(secureClickCalls == 1 and questClicks == 1,
        "the secure delegate still calls Blizzard's quest click handler")
    assert(QuestObjectiveTracker.unregisteredEvents
        and QuestObjectiveTracker.unregisteredEvents.QUEST_LOG_UPDATE,
        "Blizzard's quest events are suspended while our module is active")
    ourModule.events.QUEST_LOG_UPDATE = true

    local wheelBlock = fakeFrame("Frame", nil, ourModule)
    wheelBlock.HeaderButton = fakeFrame("Button", nil, wheelBlock)
    wheelBlock.ItemButton = fakeFrame("Button", nil, wheelBlock)
    wheelBlock.poiButton = fakeFrame("Button", nil, wheelBlock)
    wheelBlock.zoneCollapseButton = fakeFrame("Button", nil, wheelBlock)
    ourModule:EnableBlockWheel(wheelBlock)
    assert(wheelBlock.mouseEnabled == true, "the block keeps hover and wheel input")
    assert(wheelBlock.mouseClickEnabled == false,
        "the block must not swallow clicks meant for its quest item button")
    assert(wheelBlock.wheelEnabled == true, "the block still scrolls")
    assert(wheelBlock.scripts.OnMouseWheel, "the block handles the wheel")
    for _, child in ipairs({ wheelBlock.HeaderButton, wheelBlock.ItemButton, wheelBlock.poiButton, wheelBlock.zoneCollapseButton }) do
        assert(child.wheelEnabled == true, "each row control scrolls")
        assert(child.scripts.OnMouseWheel, "each row control handles the wheel")
    end
    local zoneBlock = fakeFrame("Frame", nil, ourModule)
    zoneBlock.zoneName = "Ashenvale"
    ourModule:EnableBlockWheel(zoneBlock)
    assert(zoneBlock.mouseClickEnabled == true,
        "zone headers keep their row click so the area beside the collapse arrow toggles")
    local popupBlock = fakeFrame("Frame", nil, ourModule)
    popupBlock.template = "AutoQuestPopUpBlockTemplate"
    ourModule:EnableBlockWheel(popupBlock)
    assert(popupBlock.mouseClickEnabled == true,
        "auto-quest popups keep their row click so the popup opens")
    local reusedBlock = fakeFrame("Frame", nil, ourModule)
    ourModule:EnableBlockWheel(reusedBlock)
    assert(reusedBlock.mouseClickEnabled == false,
        "a plain block starts without row clicks")
    reusedBlock.zoneName = "Darkshore"
    ourModule:EnableBlockWheel(reusedBlock)
    assert(reusedBlock.mouseClickEnabled == true,
        "a pooled block that becomes a zone header gets its row click back")

    options.enhanceQuestTracker = false
    ns.ApplyTrackerState()
    assert(#ObjectiveTrackerFrame.modules == 2
        and ObjectiveTrackerFrame:HasModule(QuestObjectiveTracker)
        and ObjectiveTrackerFrame:HasModule(ProfessionsRecipeTracker),
        "disabling the beta restores both Blizzard modules")
    assert(standaloneTracker.module == nil, "disabling the beta clears the standalone tracker")
    assert(standaloneTracker.professionsModule == nil,
        "disabling the beta clears the standalone professions module")
    assert(ProfessionsRecipeTracker.parentContainer == ObjectiveTrackerFrame,
        "the professions module returns to Blizzard's tracker")
    assert(ourModule.shown == false)
    assert(QuestObjectiveTracker.events.QUEST_LOG_UPDATE == true,
        "Blizzard's quest events are restored with its module")
    assert(ourModule.unregisteredEvents and ourModule.unregisteredEvents.QUEST_LOG_UPDATE,
        "our module's quest events are suspended while the beta is off")

    gamepad = true
    options.enhanceQuestTracker = true
    ns.ApplyTrackerState()
    assert(#ObjectiveTrackerFrame.modules == 2
        and ObjectiveTrackerFrame:HasModule(QuestObjectiveTracker)
        and ObjectiveTrackerFrame:HasModule(ProfessionsRecipeTracker),
        "gamepad UI must keep Blizzard's tracker")
    assert(standaloneTracker.module == nil, "gamepad UI hides the standalone tracker")

    gamepad = false
    ns.ApplyTrackerState()
    assert(#ObjectiveTrackerFrame.modules == 0,
        "the standalone tracker replaces Blizzard's modules")
    assert(standaloneTracker.module == ourModule)
    assert(standaloneTracker.professionsModule == ProfessionsRecipeTracker)
    assert(ourModule.events.QUEST_LOG_UPDATE == true,
        "our module's quest events are restored with the beta")

    gamepad = true
    InCombatLockdown = function() return true end
    gamepadInit()
    assert(#ObjectiveTrackerFrame.modules == 2
        and ObjectiveTrackerFrame:HasModule(QuestObjectiveTracker)
        and ObjectiveTrackerFrame:HasModule(ProfessionsRecipeTracker),
        "gamepad init must restore Blizzard's modules even in combat")
    assert(standaloneTracker.module == nil, "gamepad init hides the standalone tracker")
    assert(standaloneTracker.professionsModule == nil,
        "gamepad init restores the professions module to Blizzard's tracker")

    gamepad = false
    InCombatLockdown = function() return false end
    options.enhanceQuestTracker = true
    ns.ApplyTrackerState()
    assert(#ObjectiveTrackerFrame.modules == 0, "the standalone tracker stays active")
    assert(standaloneTracker.module == ourModule)
    assert(standaloneTracker.professionsModule == ProfessionsRecipeTracker,
        "the standalone tracker keeps the professions module after combat")
    local eventFrame
    for _, frame in ipairs(frames) do
        if frame.events and frame.events.PLAYER_REGEN_DISABLED then eventFrame = frame end
    end
    assert(eventFrame, "the tracker registers combat events")
    assert(eventFrame.events.QUEST_ACCEPTED, "the tracker listens for quest accepts")
    assert(eventFrame.events.QUEST_LOG_UPDATE, "the tracker listens for quest log updates")
    assert(eventFrame.events.QUEST_WATCH_LIST_CHANGED, "the tracker listens for watch list changes")
    local dirtyBefore = ourModule.dirty or 0
    eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", 12345)
    assert((ourModule.dirty or 0) == dirtyBefore + 1,
        "a quest event marks the tracker dirty when the module events miss it")
    InCombatLockdown = function() return true end
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_DISABLED")
    assert(standaloneTracker.module == ourModule,
        "combat keeps the standalone tracker instead of reverting to Blizzard's")
    assert(#ObjectiveTrackerFrame.modules == 0,
        "Blizzard's quest module stays removed during combat")
    InCombatLockdown = function() return false end
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
    assert(standaloneTracker.module == ourModule,
        "the standalone tracker remains active after combat")

    ourModule.bottomInset = nil
    ourModule.availableHeight = 125
    ourModule.contentsHeight = 425
    ourModule:UpdateScrollViewport()
    assert(ourModule.contentsHeight == 110, "the module height leaves room above the action bars")
    assert(ourModule.ScrollFrame.height == 85)
    assert(ourModule.ScrollFrame.shown == true)
    assert(ourModule.ContentsFrame.height == 416, "content keeps its full height plus scroll padding")
    ourModule:Scroll(-1)
    assert(ourModule.ScrollFrame.scroll == 36)
    ourModule:Scroll(1)
    assert(ourModule.ScrollFrame.scroll == 0)

    ourModule.bottomInset = 0
    ourModule.availableHeight = 125
    ourModule.contentsHeight = 425
    ourModule:UpdateScrollViewport()
    assert(ourModule.contentsHeight == 125,
        "the quest module fills the space above the professions module")
    assert(ourModule.ScrollFrame.height == 100)
    ourModule.bottomInset = nil

    ourModule.availableHeight = 500
    ourModule.contentsHeight = 125
    ourModule:UpdateScrollViewport()
    assert(ourModule.contentsHeight == 133, "short content keeps the module near its content height")
    assert(ourModule.ScrollFrame.height == 108, "the scroll viewport follows short content")
    assert(ourModule.ContentsFrame.height == 108, "short content has no scroll range")
    assert(ourModule.ScrollFrame.range == 0, "short content does not scroll")

    ourModule.collapsed = true
    ourModule.shown = true
    standaloneTracker:Update()
    local collapsedPoint = ProfessionsRecipeTracker.points[1]
    assert(collapsedPoint and collapsedPoint.point == "TOPLEFT"
        and collapsedPoint.relativeTo == ourModule
        and collapsedPoint.y == -35,
        "collapsed quests keep the professions header just below the quest header")
    ourModule.collapsed = false

    local zoneInfos = {
        { zoneName = "Ashenvale", quest = { id = 102 } },
        { zoneName = "Ashenvale", quest = { id = 103 } },
        { zoneName = "Darkshore", quest = { id = 101 } },
    }
    ourModule.ScrollFrame.width = 260
    ourModule:UpdateScrollContentSize()
    assert(ourModule.ContentsFrame.width == 252, "content width leaves room for the item button overhang")
    local autoBlock = { offsetX = -20 }
    ourModule:AnchorBlock(autoBlock)
    assert(autoBlock.offsetX == 0, "auto quest popup offset is clamped inside the scroll content")
    ns.EnhanceQuestWatchInfos = function() return zoneInfos end
    local headers = {}
    function ourModule:GetBlock(id)
        local block = headers[id]
        if not block then
            block = fakeFrame("Frame", id, ourModule)
            block.ids = id
            block.HeaderText = {
                SetFontObject = function() end,
                SetPoint = function() end,
                SetText = function(self, text) self.text = text end,
                SetTextColor = function() end,
                SetMaxLines = function() end,
                GetHeight = function() return 18 end,
                SetShadowColor = function() end,
                SetShadowOffset = function() end,
            }
            block.HeaderButton = fakeFrame("Button", nil, block)
            function block:SetHeader(text) self.header = text; self.height = 18 end
            headers[id] = block
        end
        return block
    end
    local seen = {}
    ourModule:EnumQuestWatchData(function(_, quest)
        seen[#seen + 1] = quest.id
        return true
    end)
    assert(#seen == 3)
    assert(headers["zone:Ashenvale"] and headers["zone:Darkshore"])
    assert(headers["zone:Ashenvale"].offsetX == 7, "zone headers align with the Quests header")
    assert(headers["zone:Ashenvale"].OnHeaderClick,
        "zone headers own their click instead of the module's quest handler")
    collapsed["Darkshore"] = true
    seen = {}
    ourModule:EnumQuestWatchData(function(_, quest)
        seen[#seen + 1] = quest.id
        return true
    end)
    assert(#seen == 2 and seen[1] == 102 and seen[2] == 103)

    options.trackerFilter = "current"
    watches = 18
    ns.EnhanceQuestWatchInfos = function() return {} end
    seen = {}
    ourModule:EnumQuestWatchData(function()
        seen[#seen + 1] = true
    end)
    assert(#seen == 0)
    local empty = headers["fqp-filter-empty"]
    assert(empty and empty.HeaderText.text == "No quests match this filter.",
        "a zero-match filter must keep the module header available")
    assert(empty.offsetX == 7, "the empty-filter message aligns with zone headers")

    local function nearestQuest(id)
        return { GetID = function() return id end }
    end
    local selected
    C_SuperTrack = {
        SetSuperTrackedQuestID = function(id) selected = id; return true end,
        GetSuperTrackedQuestID = function() return 0 end,
    }
    C_QuestLog.GetDistanceSqToQuest = function(id) return id == 101 and 10 or 100, true end
    QuestObjectiveTrackerMixin.BuildQuestWatchInfos = function()
        return { { quest = nearestQuest(101) }, { quest = nearestQuest(102) } }
    end

    gamepad = false
    InCombatLockdown = function() return false end
    options.enhanceQuestTracker = true
    ns.ApplyTrackerState()
    ns.EnhanceQuestWatchInfos = function()
        return { { quest = nearestQuest(102) } }
    end
    assert(ns.SelectNearestQuest())
    assert(selected == 102, "nearest selection must use the beta tracker's filtered list")

    selected = nil
    options.enhanceQuestTracker = false
    options.trackerFilter = "current"
    ns.ApplyTrackerState()
    assert(ns.SelectNearestQuest())
    assert(selected == 101, "nearest selection must ignore a saved filter while the beta is off")
end

cases["tracker_runtime.beta_opt_in_resets_once_then_survives"] = function()
    GetLocale = function() return "enUS" end
    C_CVar = nil
    ForeverQuestPinsDB_Settings = {}
    ForeverQuestPinsCharacterSettings = {}
    ForeverQuestPinsCharDB = {}
    ForeverQuestPinsDB = { enhanceQuestTracker = true, _revision = 1 }
    local first = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", first)
    assert(loadfile("Config.lua"))("ForeverQuestPins", first)
    first.InitSettings()
    assert(first.GetOption("enhanceQuestTracker") == false, "the old beta opt-in is reset once")
    assert(ForeverQuestPinsDB._trackerBetaSeenV2 == true)
    first.db.trackerCollapsedZones = { ["Hero-Realm"] = { Tanaris = true } }
    first.WipeSettings()
    assert(first.db.trackerCollapsedZones == nil, "Use Defaults clears collapsed tracker zones")

    local second = {}
    ForeverQuestPinsDB = { enhanceQuestTracker = true, _trackerBetaSeenV2 = true, _revision = 1 }
    ForeverQuestPinsCharDB = {}
    ForeverQuestPinsDB_Settings = {}
    ForeverQuestPinsCharacterSettings = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", second)
    assert(loadfile("Config.lua"))("ForeverQuestPins", second)
    second.InitSettings()
    assert(second.GetOption("enhanceQuestTracker") == true, "a later opt-in survives")
end

cases["tracker_runtime.beta_marker_survives_in_cvar_mirror"] = function()
    GetLocale = function() return "enUS" end
    ForeverQuestPinsDB = {}
    ForeverQuestPinsCharDB = {}
    ForeverQuestPinsDB_Settings = {}
    ForeverQuestPinsCharacterSettings = {}
    local mirrorText = "revision=7;enhanceQuestTracker=1;trackerBetaSeen=1;trackerSort=blizzard;trackerFilter=all"
    C_CVar = {
        GetCVar = function() return mirrorText end,
        SetCVar = function(_, text) mirrorText = text end,
        RegisterCVar = function() end,
    }
    local addon = {}
    assert(loadfile("Localization.lua"))("ForeverQuestPins", addon)
    assert(loadfile("Config.lua"))("ForeverQuestPins", addon)
    addon.InitSettings()
    assert(addon.GetOption("enhanceQuestTracker") == true,
        "the mirror marker must protect the saved opt-in")
    assert(mirrorText:find("trackerBetaSeen=1", 1, true),
        "the beta marker must be written back to the mirror")
    assert(mirrorText:find("trackerCollapseReset=1", 1, true),
        "the collapse reset marker must be written back to the mirror")
end

cases["spoken_tracker_runtime.attaches_play_button_to_quest_blocks"] = function()
    local function fakeButton(parent)
        local button = { shown = false, points = {} }
        function button:SetSize(width, height) self.width, self.height = width, height end
        function button:SetHitRectInsets() end
        function button:ClearAllPoints() self.points = {} end
        function button:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function button:CreateTexture()
            local texture = {}
            function texture:SetPoint(...) self.point = { ... } end
            function texture:SetColorTexture(...) self.color = { ... } end
            return texture
        end
        function button:SetFrameLevel(level) self.frameLevel = level end
        function button:Show() self.shown = true end
        function button:Hide() self.shown = false end
        function button:IsShown() return self.shown end
        button.parent = parent
        return button
    end

    CreateFrame = function()
        return {
            RegisterEvent = function() end,
            SetScript = function() end,
        }
    end
    hooksecurefunc = function(target, key, hook)
        local original = target[key]
        target[key] = function(...)
            local result = original and original(...)
            hook(...)
            return result
        end
    end

    Spoken = {
        RegisterCallback = function() end,
        DressBoxButton = function(_, button)
            button.SetBox = function(self, atlas, width, height)
                self.box = { atlas = atlas, width = width, height = height }
            end
            button.SetState = function() end
        end,
    }
    local ui
    ui = {
        shows = true,
        FollowQueue = function() end,
        ShowsTrackerButton = function(self, questID) return self.shows and questID == 123 end,
        BindPlayButton = function(self, button, questID, title, origin)
            self.bound = { button = button, questID = questID, title = title, origin = origin }
            button.questID = questID
        end,
        SetPlayButtonState = function() end,
        UpdateTrackerButtons = function() end,
    }
    VoiceOver = {
        Utils = {
            CreateDetachedFrame = function(_, _, _, parent) return fakeButton(parent) end,
        },
        QuestOverlayUI = ui,
    }

    local module = { usedBlocks = {} }
    function module:AddBlock(block)
        self.usedBlocks["ObjectiveTrackerBlockTemplate"] = self.usedBlocks["ObjectiveTrackerBlockTemplate"] or {}
        self.usedBlocks["ObjectiveTrackerBlockTemplate"][block.id] = block
    end
    local block = { id = 123, GetFrameLevel = function() return 5 end }

    local ns = { GetOption = function() return false end }
    assert(loadfile("SpokenTracker.lua"))("ForeverQuestPins", ns)
    ns.InstallSpokenTrackerBridge(module)
    module:AddBlock(block)
    assert(ui.bound and ui.bound.questID == 123, "a quest block gets a Spoken play button")
    assert(ui.bound.button:IsShown(), "the Spoken play button is shown")
    assert(ui.bound.button.frameLevel == 8, "the play button sits above the quest row")
    assert(ui.bound.button.box and ui.bound.button.box.atlas == "QuestLog-icon-ticksquare")

    ui.shows = false
    module:AddBlock(block)
    assert(not ui.bound.button:IsShown(), "a quest with no Spoken line hides the play button")

    Spoken = nil
    VoiceOver = nil
    module:AddBlock({ id = 124, GetFrameLevel = function() return 5 end })
end

cases["quest_item_runtime.uses_the_super_tracked_quest_item"] = function()
    ns = {}
    C_SuperTrack = {
        GetSuperTrackedQuestID = function() return 42 end,
    }
    C_QuestLog = {
        GetLogIndexForQuestID = function(questID)
            assert(questID == 42, "the super-tracked quest wins")
            return 3
        end,
    }
    local used
    GetQuestLogSpecialItemInfo = function(index)
        assert(index == 3)
        return 123, "texture", 1, nil, true
    end
    UseQuestLogSpecialItem = function(index) used = index end
    assert(loadfile("QuestItemKeybind.lua"))("ForeverQuestPins", ns)
    assert(ns.UseTrackedQuestItem() == true)
    assert(used == 3, "the quest log item is used")
end

cases["quest_item_runtime.ignores_missing_items_and_quests"] = function()
    ns = {}
    C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end }
    C_QuestLog = {
        GetSelectedQuest = function() return 7 end,
        GetQuestIDForLogIndex = function() return 0 end,
        GetLogIndexForQuestID = function() return 4 end,
    }
    local used = false
    GetQuestLogSpecialItemInfo = function() return nil end
    UseQuestLogSpecialItem = function() used = true end
    assert(loadfile("QuestItemKeybind.lua"))("ForeverQuestPins", ns)
    assert(ns.UseTrackedQuestItem() == false)
    assert(used == false, "a quest without a special item is ignored")

    C_QuestLog.GetSelectedQuest = function() return 0 end
    assert(ns.UseTrackedQuestItem() == false, "no selected quest is a quiet false")
end

cases["eligibility_runtime.dungeon_chain_quests_count_as_instance_quests"] = function()
    ns = {}; C_QuestLog = {}
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.QuestTagCorrections = {}
    ns.DungeonChains = {
        quests = {
            [65] = { dungeons = { "The Deadmines" }, chains = {} },
        },
    }
    assert(ns.IsInstanceQuest(65, {}) == true,
        "a required pre-quest for a dungeon chain is a dungeon pin")
    assert(ns.IsInstanceQuest(66, {}) == false,
        "quests outside a dungeon chain keep the client tag")
end

cases["quest_finder_runtime.breadcrumbs_respect_alt_quests_and_locations"] = function()
    ns = {}
    C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetMapInfo = function(mapID)
            return ({
                [1] = { name = "Zone One", mapType = 3 },
                [2] = { name = "Zone Two", mapType = 3 },
            })[mapID]
        end,
    }
    C_QuestLog = { GetQuestDifficultyLevel = function() return 10 end }
    ns.GetOption = function() return true end
    ns.IsMapPositionExplored = function() return true end
    ns.IsQuestFlaggedCompleted = function() return false end
    ns.IsOnQuest = function(questID) return questID == 101 end
    ns.IsQuestAvailable = function() return true end
    ns.IsInstanceQuest = function() return false end
    ns.IsPvPQuest = function() return false end
    ns.IsBookQuest = function() return false end
    ns.GetQuestDifficultyRGB = function() return 1, 0.82, 0 end
    ns.Quests = {
        [100] = {
            title = "Shared Breadcrumb",
            isBreadcrumb = true,
            mapID = 1, x = 10, y = 20,
            coords = { { 10, 20, 1 }, { 30, 40, 2 } },
            altQuests = { 101 },
        },
    }
    assert(loadfile("QuestFinder.lua"))("ForeverQuestPins", ns)
    assert(#ns.QuestFinder.BreadcrumbEntries(nil) == 0,
        "an alternate breadcrumb already in the log hides the shared breadcrumb")
    ns.IsOnQuest = function() return false end
    local entries = ns.QuestFinder.BreadcrumbEntries(2)
    assert(#entries == 1)
    assert(entries[1].location.mapID == 2, "the selected zone chooses its own location")
    assert(entries[1].subtitle:find("Zone Two", 1, true))
end

cases["quest_finder_runtime.dungeon_chains_are_numbered"] = function()
    ns = {}
    C_Map = {
        GetBestMapForUnit = function() return 1 end,
        GetMapInfo = function(mapID)
            return ({ [1] = { name = "Dungeon", mapType = 4 } })[mapID]
        end,
    }
    C_QuestLog = { GetQuestDifficultyLevel = function() return 10 end }
    ns.GetOption = function() return true end
    ns.IsQuestFlaggedCompleted = function() return false end
    ns.IsOnQuest = function() return false end
    ns.IsInstanceQuest = function() return true end
    ns.IsPvPQuest = function() return false end
    ns.IsBookQuest = function() return false end
    ns.GetQuestDifficultyRGB = function() return 1, 0.82, 0 end
    ns.Quests = {
        [200] = { mapID = 1, x = 10, y = 10, title = "Dungeon Quest" },
        [201] = { mapID = 1, x = 20, y = 20, title = "Pre One" },
    }
    ns.DungeonChains = {
        order = { "Test Dungeon" },
        dungeons = {
            ["Test Dungeon"] = {
                name = "Test Dungeon",
                level = "1-2",
                quests = {
                    {
                        id = 200,
                        name = "Dungeon Quest",
                        level = 20,
                        mapID = 1, x = 10, y = 10,
                        chain = {
                            { id = 201, name = "Pre One", level = 10, mapID = 1, x = 20, y = 20 },
                            { id = 202, name = "Pre Two", level = 12 },
                        },
                    },
                },
            },
        },
    }
    assert(loadfile("QuestFinder.lua"))("ForeverQuestPins", ns)
    local entries = ns.QuestFinder.DungeonQuestEntries("Test Dungeon")
    assert(#entries == 4, "header, dungeon quest, and two chain steps")
    assert(entries[2].title == "Dungeon Quest")
    assert(entries[3].subtitle:find("Chain #1 of 3", 1, true))
    assert(entries[4].subtitle:find("Chain #2 of 3", 1, true))
    assert(entries[4].location == nil, "a chain step without a map has no pin")

    local all = ns.QuestFinder.AllDungeonEntries()
    assert(#all == 2, "the all-dungeons view lists the header and direct quests only")
    assert(all[1].kind == "header" and all[1].dungeon == "Test Dungeon")
    assert(all[2].title == "Dungeon Quest")
end

cases["quest_item_runtime.falls_back_to_the_quest_log_selection"] = function()
    ns = {}
    C_QuestLog = {
        GetLogIndexForQuestID = function(questID)
            assert(questID == 55, "the selected quest ID comes from the quest log title")
            return 2
        end,
    }
    GetQuestLogSelection = function() return 4 end
    GetQuestLogTitle = function(index)
        assert(index == 4)
        return "A Quest", 20, 0, false, false, false, 0, 55
    end
    local used
    GetQuestLogSpecialItemInfo = function(index) return 99, "texture", 1, nil, true end
    UseQuestLogSpecialItem = function(index) used = index end
    assert(loadfile("QuestItemKeybind.lua"))("ForeverQuestPins", ns)
    assert(ns.UseTrackedQuestItem() == true)
    assert(used == 2)
end

cases["minimap_button_runtime.left_click_opens_finder_and_right_click_opens_settings"] = function()
    ns = { db = {} }
    local shown = true
    local openedFinder, openedSettings = 0, 0
    ns.ShowQuestFinder = function() openedFinder = openedFinder + 1 end
    ns.OpenSettings = function() openedSettings = openedSettings + 1 end
    ns.GetOption = function(key)
        if key == "showMinimapButton" then return shown end
        return true
    end
    local function texture()
        return {
            SetSize = function() end,
            SetPoint = function() end,
            SetTexture = function() end,
        }
    end
    local minimap = {
        GetWidth = function() return 140 end,
        GetCenter = function() return 0, 0 end,
        GetEffectiveScale = function() return 1 end,
        HookScript = function() end,
    }
    Minimap = minimap
    GetCursorPosition = function() return 0, 0 end
    GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
    }
    local buttons = {}
    CreateFrame = function(kind, name, parent)
        local frame = { kind = kind, name = name, parent = parent, scripts = {}, shown = true }
        function frame:SetSize() end
        function frame:SetPoint() end
        function frame:ClearAllPoints() end
        function frame:SetFrameStrata() end
        function frame:SetFrameLevel() end
        function frame:EnableMouse() end
        function frame:RegisterForClicks() end
        function frame:RegisterForDrag() end
        function frame:SetHighlightTexture() end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:IsShown() return self.shown end
        function frame:CreateTexture() return texture() end
        function frame:RegisterEvent() end
        buttons[#buttons + 1] = frame
        return frame
    end
    assert(loadfile("MinimapButton.lua"))("ForeverQuestPins", ns)
    ns.RefreshMinimapButton()
    local button
    for _, frame in ipairs(buttons) do
        if frame.name == "ForeverQuestPinsMinimapButton" then button = frame end
    end
    assert(button and button.shown, "the minimap button is created and shown")
    button.scripts.OnClick(button, "LeftButton")
    assert(openedFinder == 1, "left-click opens Quest Finder")
    button.scripts.OnClick(button, "RightButton")
    assert(openedSettings == 1, "right-click opens settings")
    shown = false
    ns.RefreshMinimapButton()
    assert(button.shown == false, "the button can be hidden from settings")
end

cases["eligibility_runtime.finder_availability_skips_level_loads"] = function()
    ns = {}; C_QuestLog = {}
    assert(loadfile("Eligibility.lua"))("ForeverQuestPins", ns)
    ns.QuestTagCorrections = {}
    ns.GetOption = function(key)
        if key == "showTrivial" then return false end
        if key == "trivialLevelGap" then return 9 end
        if key == "highLevelGap" then return 15 end
        return true
    end
    UnitLevel = function() return 60 end
    local requests = 0
    C_QuestLog.RequestLoadQuestByID = function() requests = requests + 1 end
    C_QuestLog.GetQuestDifficultyLevel = function() return nil end
    local available = ns.IsQuestAvailable(123, { minLevel = 55 }, { skipLevelRequest = true })
    assert(available == true)
    assert(requests == 0, "Quest Finder must not request a difficulty load for every quest")
end

local name = assert(os.getenv("FQP_LUA_CASE"), "FQP_LUA_CASE is required")
assert(cases[name], "unknown LuaJIT case: " .. name)()
print("PASS " .. name)
