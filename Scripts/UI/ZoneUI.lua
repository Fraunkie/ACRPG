if Debug and Debug.beginFile then Debug.beginFile("ZoneUI.lua") end
--==================================================
-- ZoneUI.lua
-- Version v0.01
-- ==================================================

-- Constants (Configurable)
local ZONE_UI_WIDTH = 0.28  -- Width of the panel (percentage of screen)
local ZONE_UI_HEIGHT = 0.17 -- Height of the panel (percentage of screen)
local ZONE_TITLE_Y_OFFSET = 0.05  -- Vertical offset for title
local POWER_LEVEL_Y_OFFSET = 0.03 -- Vertical offset for power level text
local ZONE_UI_X = 0.00
local ZONE_UI_Y = 0.00
local BG_TEX = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
local TITLE_SCALE = 1  -- Title size (adjust as needed)
local TEXT_SCALE = 0.8  -- Text size (adjust as needed)
local GOLD_COLOR = "|cFFFFD700"  -- Gold text color for title
local WHITE_COLOR = "|cFFFFFFFF"  -- White text color for objective and progress

-- Default zone info
local DEFAULT_ZONE_NAME = "HFIL"  -- Starting zone name (Home for Infinite Losers)

-- State for each player's Zone UI
ZoneUI = ZoneUI or {}
_G.ZoneUI = ZoneUI
local zones = {}  -- pid -> { panel, zoneName, powerLevelText }

-- Cache for Leaderboard frames (to handle multiple leaderboards)
local LeaderboardCache = {}
local ZoneTable = {
    YEMMA = {
        zonename = "YEMMA",
        prettyname = " Yemma's Station",
    },  
    HFIL = {
            zonename = "HFIL",
            prettyname = "Home For Infinit Losers",
        },
    NEO_CAPSULE_CITY = {
        zonename = "NEO_CAPSULE_CITY",
        prettyname = "Neo Capsule City",
    },
}
-- ==================================================
-- HELPER FUNCTIONS
-- ==================================================

-- Ensure valid unit check
local function validUnit(u)
    return u and GetUnitTypeId(u) ~= 0
end

-- Calculate average power level for the zone
local function getAveragePowerLevel(zone)
    local totalPower = 0
    local playerCount = 0

    -- Iterate through all players to calculate the average power level in the zone
    for pid = 0, bj_MAX_PLAYERS - 1 do
        local pd = PlayerData.Get(pid)  -- Using the correct method as per your instructions
        if pd and pd.zone == zone then
            local powerLevel = pd.stats.power or 0
            totalPower = totalPower + powerLevel
            playerCount = playerCount + 1
        end
    end

    if playerCount > 0 then
        return totalPower / playerCount
    else
        return 0
    end
end

-- Function to get pretty zone names
local function getzonePretty(pid)
    local pd = PlayerData.Get(pid)
    local zone = pd.zone

    if zone == "HFIL" then 
        return "Home For Infinite Losers"
    elseif zone == "YEMMA" then 
        return "Yemma's Station"
    else
        return "No zone name set"
    end
end

-- Create an invisible leaderboard for each player
local function createLeaderboard(pid)
    -- Check if the leaderboard already exists for this player
    if LeaderboardCache[pid] then
        return LeaderboardCache[pid]  -- Return the existing leaderboard
    end

    -- Create a new Leaderboard frame for each player
    CreateLeaderboardBJ(bj_FORCE_ALL_PLAYERS, "Zone UI")
    local parent = BlzGetFrameByName("Leaderboard", pid)

    -- Set the Leaderboard frame size to 0 (hidden initially)
    BlzFrameSetSize(parent, 0, 0)

    -- Hide unwanted parts of the leaderboard (e.g., backdrop and title)
    BlzFrameSetVisible(BlzGetFrameByName("LeaderboardBackdrop", pid), false)
    BlzFrameSetVisible(BlzGetFrameByName("LeaderboardTitle", pid), false)

    -- Store the leaderboard in the cache for future access
    LeaderboardCache[pid] = parent

    -- Return the parent frame for use
    return parent
end

-- ==================================================
-- CREATE ZONE UI PANEL FUNCTION (Using Custom Leaderboard)
-- ==================================================

local function createZoneUIPanel(pid)
    -- Create the leaderboard (invisible parent frame for each player)
    local leaderboard = createLeaderboard(pid)

    -- Create the Zone Panel as a child of the leaderboard frame
    local ZoneUiPanel = BlzCreateFrameByType("BACKDROP", "ZoneUiPanel_"..pid, leaderboard, "", 0)

    -- Set the panel size and position relative to the leaderboard frame
    BlzFrameSetSize(ZoneUiPanel, ZONE_UI_WIDTH, ZONE_UI_HEIGHT)
    BlzFrameSetTexture(ZoneUiPanel, BG_TEX, 0, true)
    BlzFrameSetPoint(ZoneUiPanel, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), FRAMEPOINT_CENTER, ZONE_UI_X, ZONE_UI_Y)  -- Centered

    -- Create the Zone Title Frame (using the updated getzonePretty function)
    local title = BlzCreateFrameByType("TEXT", "ZoneTitle_"..pid, ZoneUiPanel, "", 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, ZoneUiPanel, FRAMEPOINT_TOP, 0, -ZONE_TITLE_Y_OFFSET)
    BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
    BlzFrameSetText(title, getzonePretty(pid))  -- Using the updated function to get the zone name

    -- Create the Average Power Level Frame
    local powerLevelText = BlzCreateFrameByType("TEXT", "PowerLevelText_"..pid, ZoneUiPanel, "", 0)
    BlzFrameSetPoint(powerLevelText, FRAMEPOINT_TOP, title, FRAMEPOINT_BOTTOM, 0, -POWER_LEVEL_Y_OFFSET)
    BlzFrameSetTextAlignment(powerLevelText, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
    BlzFrameSetText(powerLevelText, "Average Power Level: 0")

    -- Store the panel and initial state for the player
    zones[pid] = zones[pid] or {}  -- Ensure the table exists for the player
    zones[pid].panel = ZoneUiPanel
    zones[pid].zoneName = DEFAULT_ZONE_NAME
    zones[pid].powerLevelText = powerLevelText
end

-- ==================================================
-- PUBLIC API FUNCTIONS
-- ==================================================

-- Open the Zone UI panel for the player (pid)
function ZoneUI.Open(pid)
    -- Create the Zone UI panel for the player if it doesn't exist
    if not zones[pid] then
        createZoneUIPanel(pid)
    end
    -- Ensure the panel is visible
    if zones[pid] then
        BlzFrameSetVisible(zones[pid].panel, true)
    else
        print("Error: zones[pid] is nil!")
    end
    -- Update the panel with the current zone information
    ZoneUI.Update(pid)
end

-- Close the Zone UI panel for the player (pid)
function ZoneUI.Close(pid)
    if zones[pid] then
        BlzFrameSetVisible(zones[pid].panel, false)
    else
        print("Error: zones[pid] is nil!")
    end
end

-- Update the Zone UI panel (e.g., refresh power level)
function ZoneUI.Update(pid)
    if zones[pid] then
        -- Fetch the current zone name directly from PlayerData
        local pd = PlayerData.Get(pid)
        local zone = pd.zone  -- Get the zone directly from PlayerData

        -- Get the pretty zone name using your getzonePretty function
        local prettyZoneName = getzonePretty(pid)

        -- Update the UI with the pretty zone name
        BlzFrameSetText(zones[pid].zoneNameText, prettyZoneName)  -- Assuming you have a zone name frame

        -- Calculate the average power level for the zone
        local avgPower = getAveragePowerLevel(zone)
        BlzFrameSetText(zones[pid].powerLevelText, "Average Power Level: " .. tostring(math.floor(avgPower)))
    else
        print("Error: zones[pid] is nil!")
    end
end

-- Change the zone for the player (pid)
function ZoneUI.SetZone(pid, zoneName)
    if zones[pid] then
        zones[pid].zoneName = zoneName
        BlzFrameSetText(zones[pid].panel, zoneName)  -- Update the zone title
        ZoneUI.Update(pid)  -- Update the average power level display
    else
        print("Error: zones[pid] is nil!")
    end
end

-- Update the power level display for the player (pid)
function ZoneUI.UpdatePowerLevel(pid)
    ZoneUI.Update(pid)
end

-- Periodic update function for Zone UI (to refresh data at intervals)
local function periodicUpdate()
    for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
        -- Ensure the player has a valid Zone UI
        if zones[pid] then
            -- Update the zone information dynamically
            ZoneUI.Update(pid)  -- Call the existing update function to refresh the UI
        end
    end
end

-- Start the periodic update every 1 second (or adjust the interval as needed)
TimerStart(CreateTimer(), 1.0, true, periodicUpdate)

if Debug and Debug.endFile then Debug.endFile() end
