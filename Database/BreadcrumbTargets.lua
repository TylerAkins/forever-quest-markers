-- Hand-maintained breadcrumb target overrides.
--
-- Most breadcrumbs already point at their follow-up quest, and Quest Finder
-- uses that quest's zone as the target. Add an entry here when the follow-up
-- starts somewhere other than the zone the breadcrumb is meant for, or when
-- the follow-up is missing from the database.
--
-- Key: breadcrumb quest ID. Value: target UiMapID, or a list of target map IDs.

local ADDON_NAME, ns = ...
ns.BreadcrumbTargets = {
    -- A Call to Arms: The Plaguelands!
    -- The Horde versions hand in at the Bulwark on the Tirisfal border, but
    -- players browse for this breadcrumb under Western Plaguelands.
    [5093] = 1422,
    [5094] = 1422,
    [5095] = 1422,
}
