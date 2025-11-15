if Debug and Debug.beginFile then Debug.beginFile("LetterLeaderboardDisplay.lua") end

do
    -- Constants
    local TEX_PATH = "UI\\letters\\"  -- Path to the letter textures
    local LETTER_SIZE = 0.012  -- Size of the letter
    local LETTER_POS_X = 0.35  -- Starting X Position of the letter
    local LETTER_POS_Y = 0.12  -- Starting Y Position of the letter
    ----------------------------------------------------------------
    local BG_TEX = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"

    -- Function to create the Leaderboard parent frame
    local function SetupLeaderboardFrame()
        -- Create the Leaderboard frame
        CreateLeaderboardBJ(bj_FORCE_ALL_PLAYERS, "title")
        local parent = BlzGetFrameByName("Leaderboard", 0)
        
        -- Set the Leaderboard frame size to 0 (hidden initially)
        BlzFrameSetSize(parent, 0, 0)
        
        -- Hide unwanted parts of the leaderboard (e.g., backdrop and title)
        BlzFrameSetVisible(BlzGetFrameByName("LeaderboardBackdrop", 0), false)
        BlzFrameSetVisible(BlzGetFrameByName("LeaderboardTitle", 0), false)

        -- Return the parent frame
        return parent
    end

    -- Function to display each letter on the screen
    local function DisplayLetter(letter, objective, parent)
    local tex = TEX_PATH .. letter  -- Construct texture path for the letter

    -- Create the frame to display the letter inside the multiboard
    local taskframe = BlzCreateFrameByType("BACKDROP", "textbox", parent, "", 0)
    local frame = BlzCreateFrameByType("BACKDROP", "LetterFrame", taskframe, "", 0)
    local objectiveTextFrame = BlzCreateFrameByType("TEXT", "", parent, "", 0)

    -- Set the texture path for the letter frame
    BlzFrameSetTexture(frame, tex, 0, true)
    BlzFrameSetTexture(taskframe, BG_TEX, 0, true)
 

    -- Set the size and position for the letter
    BlzFrameSetSize(frame, LETTER_SIZE, LETTER_SIZE)
    BlzFrameSetPoint(frame, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), FRAMEPOINT_CENTER, LETTER_POS_X, LETTER_POS_Y)

    -- Make the frame visible
    BlzFrameSetVisible(frame, true)
    BlzFrameSetVisible(taskframe, true)

    -- Update the X position for the next letter
    LETTER_POS_X = LETTER_POS_X + LETTER_SIZE * 0.4  -- Space between letters

    -- Set the objective text and position

    BlzFrameSetText(objectiveTextFrame, objective) -- This will now display the full objective text
    BlzFrameSetPoint(objectiveTextFrame, FRAMEPOINT_TOPLEFT, taskframe, FRAMEPOINT_TOPLEFT, 0.01, -0.04)  -- Below title
    BlzFrameSetVisible(objectiveTextFrame, true) -- Make the text frame visible
	DisplayTextToPlayer(Player(0),0,0,objective)
end
    --==================================================
    -- API
    --==================================================
    function Tasktext(text, objective)
        local parentFrame = SetupLeaderboardFrame()
        local phrase = text
        local obj = objective
        for i = 1, #phrase do
            local char = string.sub(phrase, i, i)
            if char ~= " " then  -- Skip spaces
                DisplayLetter(char, obj, parentFrame)
            else
                -- Add space between words
                LETTER_POS_X = LETTER_POS_X + LETTER_SIZE * 0.4
            end
        end
    end

    -- Function to display task title and objective
    local function DisplayTaskInfo(pid, taskTitle, taskObjectives)
        Tasktext(taskTitle, taskObjectives)
    end

    -- Function to handle task acceptance
    function OnTaskAccepted(pid)
        local task = HFILQuests.GetCurrent(pid)  -- Assuming HFILQuests holds the current task for the player

        if task then
            -- Get task title and objectives
            local taskTitle = task.title or "No Title"
            local taskObjectives = "Objective: " .. (task.progress and task.goal or "Unknown")

            -- Display task info using Tasktext() for title and static text for objectives
            DisplayTaskInfo(pid, taskTitle, taskObjectives)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "No task currently assigned.")
        end
    end

    -- Function to update task info
    local function UpdateTaskInfo(pid)
        local task = HFILQuests.GetCurrent(pid)

        if task then
            local taskTitle = task.title or "No Title"
            local taskObjectives = "Objective: "
            -- Update task info
            DisplayTaskInfo(pid, taskTitle, taskObjectives)
        end
    end

    -- Periodic update (every 0.03 seconds or as needed)

    --==================================================
    -- OnInit: Initialize task display on map load
    --==================================================
    OnInit.final(function()
        -- Example call: Trigger this after GetTask is clicked (this is just a placeholder)
        local pid = 0  -- Example player id, replace it with actual player id when implementing
        OnTaskAccepted(pid)

        -- Debug message
        if Debug then
            Debug.Print("Task Display initialized globally and Task info is being shown!")
        end
    end)
end
if Debug and Debug.endFile then Debug.endFile() end
