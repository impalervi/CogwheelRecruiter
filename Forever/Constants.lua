local addonName, NS = ...
NS = NS or {}

-- WoW: Forever (interface 16001+) runs Vanilla content on the retail client.
-- Loaded by CogwheelRecruiter_Camelot.toc only; overrides CogwheelRecruiter_Constants.lua.
-- Forever reports the retail project; the check keeps this file inert if a Classic client ever loaded it.
if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    return
end

NS.MAX_PLAYER_LEVEL = 60
NS.DEFAULT_MINIMAP_POS = 225 -- bottom left

NS.ZONE_CATEGORIES = {
    {
        name = "Starter Zones (1-15)",
        zones = {"Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle"},
        min = 1, max = 15, color = {r=0.8, g=0.8, b=0.8}
    },
    {
        name = "Early Game (15-30)",
        zones = {"The Barrens", "Westfall", "Redridge Mountains", "Duskwood", "Loch Modan", "Wetlands", "Ashenvale", "Stonetalon Mountains", "Hillsbrad Foothills", "Silverpine Forest"},
        min = 15, max = 30, color = {r=0.1, g=0.8, b=0.1}
    },
    {
        name = "Mid-Game (30-50)",
        zones = {"Tanaris", "Feralas", "The Hinterlands", "Stranglethorn Vale", "Badlands", "Swamp of Sorrows", "Dustwallow Marsh", "Desolace", "Arathi Highlands", "Alterac Mountains", "Thousand Needles", "Riverglades", "Shen'dralas"},
        min = 30, max = 50, color = {r=0.1, g=0.5, b=1.0}
    },
    {
        name = "Endgame Azeroth (50-60)",
        zones = {"Eastern Plaguelands", "Western Plaguelands", "Silithus", "Winterspring", "Burning Steppes", "Searing Gorge", "Un'Goro Crater", "Felwood", "Azshara", "Deadwind Pass", "Blasted Lands", "Mount Hyjal"},
        min = 50, max = 60, color = {r=0.6, g=0.2, b=0.8}
    },
    {
        name = "Major Cities",
        zones = {"Orgrimmar", "Stormwind City", "Ironforge", "Undercity", "Darnassus", "Thunder Bluff"},
        min = 0, max = 0, color = {r=0.5, g=0.5, b=0.5}
    },
    {
        name = "Battlegrounds",
        zones = {"Warsong Gulch", "Arathi Basin", "Alterac Valley", "Darkspear Islands"},
        min = 0, max = 0, color = {r=0.85, g=0.2, b=0.2}
    }
}
