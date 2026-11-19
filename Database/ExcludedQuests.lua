local ADDON_NAME, ns = ...

-- Quests that should never show map pins.
ns.ExcludedQuests = {
    [60860] = true, -- Your Reward has Arrived!
    [60870] = true, -- A Special Gift (alternate of 60860)
    [96339] = true, -- Legacy Reward: Replica Ironforge Air Rifle
    [96383] = true, -- Legacy Reward: Spectral Bear Cub
}
