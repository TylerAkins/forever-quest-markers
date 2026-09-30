"""Exercise waypoint providers and quest lifecycle using Lua 5.1 API doubles."""
from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class WaypointTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
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
        ''')
        self.lua.execute((ROOT / 'Waypoints.lua').read_text(), 'ForeverQuestPins', self.lua.globals().ns)

    def test_start_coordinates_and_native_accept_handoff(self):
        self.lua.execute('''
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
        ''')

    def test_manual_pin_and_quest_changes_are_respected(self):
        self.lua.execute('''
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
        ''')

    def test_other_quest_tracking_cancels_accept_handoff(self):
        self.lua.execute('''
            ns.TrackQuest(1)
            C_SuperTrack.SetSuperTrackedQuestID(2)
            onQuest=true
            ns.UpdateWaypoint()
            assert(trackedQuest==2)
        ''')

    def test_tomtom_updates_objective_turnin_and_removes_only_owned_uid(self):
        self.lua.execute('''
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
        ''')

    def test_missing_objective_does_not_reuse_start_and_recovers(self):
        self.lua.execute('''
            provider="tomtom"; ns.TrackQuest(1); onQuest=true
            ns.UpdateWaypoint()
            assert(removed==1 and added==1)
            nextMap=1412; nextX=0.3; nextY=0.4
            ns.UpdateWaypoint()
            assert(added==2)
        ''')

    def test_missing_provider_unsupported_map_and_invalid_location(self):
        self.lua.execute('''
            provider="tomtom"; TomTom=nil
            assert(not ns.TrackQuest(1) and #messages==1)
            provider="blizzard"; C_Map.CanSetUserWaypointOnMap=function() return false end
            assert(not ns.TrackQuest(1) and waypoint==nil)
            C_Map.SetUserWaypoint=nil
            assert(not ns.TrackQuest(1))
            ns.Quests[1].x=101
            assert(not ns.TrackQuest(1))
            assert(not ns.TrackQuest(nil))
        ''')

    def test_provider_setting_persists_and_validates(self):
        self.lua.execute((ROOT / 'Config.lua').read_text(), 'ForeverQuestPins', self.lua.globals().ns)
        self.lua.execute('''
            assert(ns.InitSettings().waypointProvider=="blizzard")
            ns.SetOption("waypointProvider","tomtom")
            assert(ForeverQuestPinsCharDB.waypointProvider=="tomtom")
            assert(ForeverQuestPinsDB_Settings.waypointProvider=="tomtom")
            ns.SetOption("waypointProvider","invalid")
            assert(ns.GetOption("waypointProvider")=="tomtom")
            ns.WipeSettings()
            assert(ns.GetOption("waypointProvider")=="blizzard")
        ''')

    def test_provider_recovers_from_cvar_mirror(self):
        self.lua.execute("""
            mirror="revision=42;waypointProvider=tomtom;enabled=1"
            C_CVar={GetCVar=function() return mirror end,
                SetCVar=function(_,text) mirror=text end, RegisterCVar=function() end}
        """)
        self.lua.execute((ROOT / 'Config.lua').read_text(), 'ForeverQuestPins', self.lua.globals().ns)
        self.lua.execute("""
            assert(ns.InitSettings().waypointProvider=="tomtom")
            assert(mirror:find("waypointProvider=tomtom",1,true))
            ns.SetOption("waypointProvider","blizzard")
            assert(mirror:find("waypointProvider=blizzard",1,true))
        """)

    def test_navigation_checkbox_uses_shared_cvar_without_overriding_it(self):
        self.lua.execute("""
            navigation="0"
            C_CVar={GetCVar=function(key)
                    if key=="showInGameNavigation" then return navigation end
                    return ""
                end,
                SetCVar=function(key,value)
                    if key=="showInGameNavigation" then navigation=value end
                end,
                RegisterCVar=function() end}
        """)
        self.lua.execute((ROOT / 'Config.lua').read_text(), 'ForeverQuestPins', self.lua.globals().ns)
        self.lua.execute("""
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
        """)


if __name__ == '__main__':
    unittest.main()
