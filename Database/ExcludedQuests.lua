local ADDON_NAME, ns = ...

-- Quests that should never show map pins.
ns.ExcludedQuests = {
    [60860] = true, -- Your Reward has Arrived!
    [60870] = true, -- A Special Gift (alternate of 60860)
}
