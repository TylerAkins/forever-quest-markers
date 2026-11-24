local ADDON_NAME, ns = ...

-- Library book pickup quests in WoW Forever. Their objective is
-- "Collect '<book title>' and bring it to ..." and they start from a book,
-- scroll, tome, or similar object. This list is hand-maintained because the
-- generated QuestieDB artifact carries no objective text. The Friend of the
-- Library turn-ins (78150, 79536, 82208, 84394) are rewards for collecting
-- books, not book pickups, so they are not in this category.
ns.BookQuests = {
    [78124] = true, -- Nar'thalas Almanac
    [78127] = true, -- The Dalaran Digest
    [78142] = true, -- Bewitchments and Glamours
    [78143] = true, -- Secrets of the Dreamers
    [78145] = true, -- Arcanic Systems Manual
    [78146] = true, -- Goaz Scrolls
    [78147] = true, -- Crimes Against Anatomy
    [78148] = true, -- Runes of the Sorcerer-Kings
    [78149] = true, -- Fury of the Land
    [79091] = true, -- Archmage Antonidas: The Unabridged Autobiography
    [79092] = true, -- Archmage Theocritus' Research Journal
    [79093] = true, -- Rumi of Gnomeregan: The Collected Works
    [79094] = true, -- The Lessons of Ta'zo
    [79095] = true, -- The Apothecary's Metaphysical Primer
    [79096] = true, -- Ataeric: On Arcane Curiosities
    [79097] = true, -- Baxtan: On Destructive Magics
    [79535] = true, -- Basilisks: Should Petrification be Feared?
    [79947] = true, -- Geomancy: The Stone-Cold Truth
    [79948] = true, -- Defensive Magics 101
    [79949] = true, -- A Web of Lies: Debunking Myths and Legends
    [79950] = true, -- Demons and You
    [79951] = true, -- Mummies: A Guide to the Unsavory Undead
    [79952] = true, -- RwlRwlRwlRwl!
    [79953] = true, -- A Ludite's Guide to Caring for Your Demonic Pet
    [81947] = true, -- Sanguine Sorcery
    [81949] = true, -- Legends of the Tidesages
    [81951] = true, -- The Liminal and the Arcane
    [81952] = true, -- Everyday Etiquette
    [81953] = true, -- Stonewrought Design
    [81954] = true, -- Venomous Journeys
    [81955] = true, -- A Mind of Metal
    [81956] = true, -- Conjurer's Codex
    [84395] = true, -- Undead Potatoes
    [84396] = true, -- Magma or Lava?
    [84397] = true, -- Northern Kalimdor - A Comprehensive Guide
    [84398] = true, -- A Study of the Light
    [84399] = true, -- Ka-Boom!
    [84400] = true, -- The Knight and the Lady
    [84401] = true, -- Scourge: Undead Menace or Misunderstood?
    [84402] = true, -- Necromancy 101
}

function ns.IsBookQuest(questID)
    questID = tonumber(questID)
    return questID ~= nil and ns.BookQuests[questID] == true
end
