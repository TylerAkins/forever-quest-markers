-- Hand-maintained zone level ranges from Leatrix_Maps.
-- Source: Leatrix_Maps/Leatrix_Maps.lua, the "Level range table" used by
-- "Show zone levels". City entries are false so the addon does not invent a
-- level range for them. Maps not listed here fall back to the range computed
-- from quest minimum levels.
--
-- Update this table when Leatrix_Maps changes its zone levels.

local ADDON_NAME, ns = ...
ns.ZoneLevels = {
    -- Eastern Kingdoms
    [1416] = { min = 30, max = 40 }, -- Alterac Mountains
    [1417] = { min = 30, max = 40 }, -- Arathi Highlands
    [1418] = { min = 35, max = 45 }, -- Badlands
    [1419] = { min = 45, max = 55 }, -- Blasted Lands
    [1428] = { min = 50, max = 58 }, -- Burning Steppes
    [1430] = { min = 55, max = 60 }, -- Deadwind Pass
    [1426] = { min = 1, max = 10 },  -- Dun Morogh
    [1431] = { min = 18, max = 30 }, -- Duskwood
    [1423] = { min = 53, max = 60 }, -- Eastern Plaguelands
    [1429] = { min = 1, max = 10 },  -- Elwynn Forest
    [1424] = { min = 20, max = 30 }, -- Hillsbrad Foothills
    [1455] = false,                  -- Ironforge
    [1432] = { min = 10, max = 20 }, -- Loch Modan
    [1433] = { min = 15, max = 25 }, -- Redridge Mountains
    [1427] = { min = 43, max = 50 }, -- Searing Gorge
    [1421] = { min = 10, max = 20 }, -- Silverpine Forest
    [1453] = false,                  -- Stormwind City
    [1434] = { min = 30, max = 45 }, -- Stranglethorn Vale
    [1435] = { min = 35, max = 45 }, -- Swamp of Sorrows
    [1425] = { min = 40, max = 50 }, -- The Hinterlands
    [1420] = { min = 1, max = 10 },  -- Tirisfal Glades
    [1458] = false,                  -- Undercity
    [1436] = { min = 10, max = 20 }, -- Westfall
    [1422] = { min = 51, max = 58 }, -- Western Plaguelands
    [1437] = { min = 20, max = 30 }, -- Wetlands

    -- Kalimdor
    [1440] = { min = 18, max = 30 }, -- Ashenvale
    [1447] = { min = 45, max = 55 }, -- Azshara
    [1439] = { min = 10, max = 20 }, -- Darkshore
    [1457] = false,                  -- Darnassus
    [1443] = { min = 30, max = 40 }, -- Desolace
    [1411] = { min = 1, max = 10 },  -- Durotar
    [1445] = { min = 35, max = 45 }, -- Dustwallow Marsh
    [1448] = { min = 48, max = 55 }, -- Felwood
    [1444] = { min = 40, max = 50 }, -- Feralas
    [1450] = false,                  -- Moonglade
    [1412] = { min = 1, max = 10 },  -- Mulgore
    [1454] = false,                  -- Orgrimmar
    [1451] = { min = 55, max = 60 }, -- Silithus
    [1442] = { min = 15, max = 27 }, -- Stonetalon Mountains
    [1446] = { min = 40, max = 50 }, -- Tanaris
    [1438] = { min = 1, max = 10 },  -- Teldrassil
    [1413] = { min = 10, max = 25 }, -- The Barrens
    [1441] = { min = 25, max = 35 }, -- Thousand Needles
    [1456] = false,                  -- Thunder Bluff
    [1449] = { min = 48, max = 55 }, -- Un'Goro Crater
    [1452] = { min = 55, max = 60 }, -- Winterspring

    -- Forever
    [2482] = { min = 60, max = 60 }, -- Hyjal
    [2521] = { min = 1, max = 12 },  -- Zephras Isle
    [2548] = { min = 35, max = 45 }, -- Riverglades
    [2652] = { min = 35, max = 45 }, -- Shen'dralas
}
