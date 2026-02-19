local addonName, NS = ...
NS = NS or {}

NS.CLASS_LIST = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID"
}

NS.ZONE_CATEGORIES = {
    {
        name = "Starter Zones (1-15)",
        zones = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Azuremyst Isle", "Durotar", "Mulgore", "Tirisfal Glades", "Eversong Woods"},
        min = 1, max = 15, color = {r=0.8, g=0.8, b=0.8}
    },
    {
        name = "Early Game (15-30)",
        zones = {"The Barrens", "Westfall", "Redridge Mountains", "Duskwood", "Loch Modan", "Wetlands", "Ashenvale", "Stonetalon Mountains", "Hillsbrad Foothills", "Silverpine Forest", "Ghostlands", "Bloodmyst Isle"},
        min = 15, max = 30, color = {r=0.1, g=0.8, b=0.1}
    },
    {
        name = "Mid-Game (30-50)",
        zones = {"Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Stranglethorn Vale", "Badlands", "Swamp of Sorrows", "Dustwallow Marsh", "Desolace", "Arathi Highlands", "Alterac Mountains", "Thousand Needles"},
        min = 30, max = 50, color = {r=0.1, g=0.5, b=1.0}
    },
    {
        name = "Endgame Azeroth (50-60)",
        zones = {"Eastern Plaguelands", "Western Plaguelands", "Silithus", "Winterspring", "Burning Steppes", "Searing Gorge", "Un'Goro Crater", "Felwood", "Azshara", "Deadwind Pass", "Blasted Lands"},
        min = 50, max = 60, color = {r=0.6, g=0.2, b=0.8}
    },
    {
        name = "Outland (58-70)",
        zones = {"Hellfire Peninsula", "Zangarmarsh", "Terokkar Forest", "Nagrand", "Blade's Edge Mountains", "Netherstorm", "Shadowmoon Valley", "Isle of Quel'Danas"},
        min = 58, max = 70, color = {r=1.0, g=0.5, b=0.0}
    },
    {
        name = "Major Cities",
        zones = {"Orgrimmar", "Stormwind City", "Ironforge", "Undercity", "Darnassus", "Thunder Bluff", "Silvermoon City", "The Exodar", "Shattrath City"},
        min = 0, max = 0, color = {r=0.5, g=0.5, b=0.5}
    }
}
