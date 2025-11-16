if Debug and Debug.beginFile then Debug.beginFile("TaskAcceptanceDisplay.lua") end
--@@debug
--==================================================
-- Task Acceptance Display Script
-- This script will display task information when accepted
--==================================================

if not TaskDisplay then TaskDisplay = {} end
_G.TaskDisplay = TaskDisplay

do
    -- Cache to store leaderboard frames for each player
    local LeaderboardCache = {}

    -- Style Constants (Adjust these for positioning)
    local BG_TEX = "ui\\TaskPanelmenu.blp"
    local TITLE_SCALE = 1  -- Title size (adjust as needed)
    local TEXT_SCALE = 0.8  -- Text size (adjust as needed)
    local GOLD_COLOR = "|cFFFFD700"  -- Gold text color for title
    local WHITE_COLOR = "|cFFFFFFFF"  -- White text color for objective and progress


    -- Dynamic positioning constants (adjust for task menu placement)
    local LETTER_POS_X = 0.52  -- Starting X position for the task menu
    local LETTER_POS_Y = 0.15  -- Starting Y position for the task menu

    -- Adjustable positions for Header, Body, and Progress text
    local HEADER_X = 0.035  -- X position for Header
    local HEADER_Y = -0.04  -- Y position for Header

    -- Adjusted Y values to position the Body and Progress below the Header
    local BODY_X = 0.035  -- X position for Body
    local BODY_Y = -0.08  -- Y position for Body (below the Header)

    local PROG_X = 0.035  -- X position for Progress
    local PROG_Y = -0.12  -- Y position for Progress (further below the Body)
    -- Panel size constants
    local PANEL_WIDTH = 0.18  -- Panel width (adjust as needed)
    local PANEL_HEIGHT = 0.14  -- Panel height (adjust as needed)

    -- State (per player instance)
    local TASKMENU = {}

    -- UI Helper Functions
    local function mkBackdrop(parent, w, h, tex, a)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex or BG_TEX, 0, true)
        
        -- Set the alpha to 0 to make the backdrop invisible
        BlzFrameSetAlpha(f, 0)  -- Make the background invisible
        
        if a then BlzFrameSetAlpha(f, a) end
        return f
    end
    
    local function mkText(parent, txt, scale, alignL, alignV)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetScale(t, scale or TEXT_SCALE)
        BlzFrameSetTextAlignment(t, alignL or TEXT_JUSTIFY_LEFT, alignV or TEXT_JUSTIFY_TOP)
        BlzFrameSetText(t, txt or "")
        return t
    end

    -- Create Invisible Leaderboard to Anchor Panel
    local function SetupLeaderboardFrame(pid)
        -- Check if the leaderboard already exists for this player
        if LeaderboardCache[pid] then
            return LeaderboardCache[pid]  -- Return the existing leaderboard
        end

        -- Create the Leaderboard frame for each player
        CreateLeaderboardBJ(bj_FORCE_ALL_PLAYERS, "title")
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

    -- TASKMENU Lifecycle (per player)
    local function destroyTASKMENU(pid)
        local inst = TASKMENU[pid]
        if not inst then return end
        local fields = {
            "panel", "header", "body", "prog"
        }
        for i=1, #fields do
            local f = inst[fields[i]]
            if f then BlzDestroyFrame(f) end
        end
        TASKMENU[pid] = nil
    end

    local function ensureTASKMENU(pid, parent)
        local inst = TASKMENU[pid]
        if inst and inst.parent == parent then return inst end
        destroyTASKMENU(pid)

        -- Create an invisible leaderboard as an anchor
        local leaderboard = SetupLeaderboardFrame(pid)

        -- Create content panel for task info with adjusted size and position
        local panel = mkBackdrop(leaderboard, PANEL_WIDTH, PANEL_HEIGHT, BG_TEX, 255)

        -- Set the position based on dynamic coordinates (using Game UI position)
        BlzFrameSetPoint(panel, FRAMEPOINT_TOPRIGHT, BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), FRAMEPOINT_CENTER, LETTER_POS_X, LETTER_POS_Y)

        -- Static text placeholders for task title, objective, and progress
        local header = mkText(panel, "", TITLE_SCALE, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, HEADER_X, HEADER_Y)

        local body = mkText(panel, "", TEXT_SCALE)
        BlzFrameSetPoint(body, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, BODY_X, BODY_Y)

        local prog = mkText(panel, "", TEXT_SCALE)
        BlzFrameSetPoint(prog, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, PROG_X, PROG_Y)

        TASKMENU[pid] = {
            parent = parent,
            panel = panel,
            header = header,
            body = body,
            prog = prog,
            _mode = "idle",
        }
        return TASKMENU[pid]
    end

    -- Set Task Information (Title, Objective, Progress)
    local function setHeader(inst, title)
        BlzFrameSetText(inst.header, GOLD_COLOR .. title)  -- Title in gold color
    end

    local function setBody(inst, txt)
        BlzFrameSetText(inst.body, WHITE_COLOR .. txt)  -- Objective text in white
    end

    local function setProg(inst, progress, goal)
        BlzFrameSetText(inst.prog, "Progress: " .. tostring(progress or 0) .. " / " .. tostring(goal or 0))
    end

    -- Display Task Information for the Player
    function TaskDisplay.ShowTask(pid)
        local inst = ensureTASKMENU(pid, BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0))  -- Attach to UI

        -- Retrieve the current task
        local task = HFILQuests.GetCurrent(pid)

        -- Ensure task description is set (fallback to title if missing)
        local description = task.desc

        -- Only set the title once in the header (do not repeat in body)
        setHeader(inst, task.title or "Task")  -- Set title in header
        setBody(inst, description or "No Description Set")  -- Set description in body

        -- Update progress based on task data (this is where progress comes from HFILQuests)
        setProg(inst, task.progress or 0, task.goal or 0)
    end

    -- Update Progress Dynamically
    function TaskDisplay.UpdateProgress(pid)
        local inst = TASKMENU[pid]
        local task = HFILQuests.GetCurrent(pid)  -- Retrieve the current task from HFILQuests
        if inst and task then
            -- Ensure we are updating the correct progress from HFILQuests data
            setProg(inst, task.progress or 0, task.goal or 0)
        end
    end

    -- Task Completion and Cleanup
    function TaskDisplay.CompleteTask(pid)
        local inst = TASKMENU[pid]
        if inst then
            setHeader(inst, "Task Complete")
            setBody(inst, "Well done! You have completed the task.")
            setProg(inst, 0, 0)
            -- Optionally hide or clean up the task panel
            BlzFrameSetVisible(inst.panel, false)  -- Hide the task panel when complete
        end
    end

    -- Refresh Function (Call this to update task information)
    function TaskDisplay.Refresh(pid)
        local inst = TASKMENU[pid]
        local curTask = HFILQuests.GetCurrent(pid)  -- Get current task data

        if curTask then
            -- Update the task display with current task data
            setHeader(inst, curTask.title or "Task")  -- Set title
            setBody(inst, curTask.description or "Description was not set")  -- Set description
            setProg(inst, curTask.progress or 0, curTask.goal or 0)  -- Update progress
        else
            -- No active task, reset UI
            setHeader(inst, "HFIL Tasks")
            setBody(inst, "Press Get Task to receive two choices.")
            setProg(inst, 0, 0)
        end
    end

    local function periodicUpdate()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local currentTask = HFILQuests.GetCurrent(pid)  -- Get the current task for the player
            if currentTask and currentTask.id then  -- Check if the player has an active task
                -- Call the refresh function for each player with an active task
                TaskDisplay.Refresh(pid)
            end
        end
    end

    -- Trigger the periodic update every 0.03 seconds or as needed
    TimerStart(CreateTimer(), 0.03, true, periodicUpdate)

    -- Initialization (Trigger Setup)
    OnInit.final(function()
        -- Debug message
    end)

end

if Debug and Debug.endFile then Debug.endFile() end
