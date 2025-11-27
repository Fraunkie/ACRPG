--[[ TasFullScreenFrame V2 by Tasyen
This helps in creating Frames that can Leave 4:3 of Screen and helps in attaching to the left/right border of the window. Works in Warcraft 3 V1.31.1 and V1.36.

Creates 2 Frames TasFullScreenFrame & TasFullScreenParent.
TasFullScreenFrame can be used as relative Frame in BlzFrameSetPoint. It can not be a parent as it is hidden.
TasFullScreenParent is used as parent in CreateFrame to make your Frames able to leave 4:3. Do not use it for SimpleFrames.
TasFullScreenParentScaled like TasFullScreenParent but scales with UI scale option.

when Leaderboard/Multiboard are the anchestor, then they need to be visible otherwise your frames will not be visible. They can be hidden when your frame shows&creates Leaderboard/Multiboard after TasFullScreenFrameInit run.
Multiboard is used when there already exists a Multiboard when TasFullScreenFrameInit runs.

credits Niklas, ScrewTheTrees

Example
function Test()
    local frame = BlzCreateFrame("ScriptDialogButton", TasFullScreenParent, 0, 0)
    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, 0, 0.3)

    frame = BlzCreateFrame("ScriptDialogButton", TasFullScreenParentScaled, 0, 0)
    BlzFrameSetPoint(frame, FRAMEPOINT_TOPLEFT, TasFullScreenFrame, FRAMEPOINT_LEFT, 0, 0.10)
end
]]
do
    local AutoRun = true --(true) will create Itself at 0s, (false) you need to TasFullScreenFrameInit()
    local UpdateRate = 0.5 -- How fast to update the size of TasFullScreenFrame
    local lastXSize = 0
    -- provides the parent that can Leave 4:3 and with that our frames
    local function GetParent()
        -- try to use "ConsoleUIBackdrop" can not happen in V1.31.1
        local parent = BlzGetFrameByName("ConsoleUIBackdrop", 0)
        if GetHandleId(parent) > 0 then return parent end

        -- ConsoleUIBackdrop failed, therefore use a Multiboard
        parent = BlzGetFrameByName("Multiboard", 0)
        if GetHandleId(parent) > 0 then return parent end

        -- Multiboard failed, therefore use a Leaderboard
        -- try attaching to a existing one
        parent = BlzGetFrameByName("Leaderboard", 0)
        if GetHandleId(parent) > 0 then return parent end

        -- create a Leaderboard and make it not seeable
        CreateLeaderboardBJ(bj_FORCE_ALL_PLAYERS, "title")
        parent = BlzGetFrameByName("Leaderboard", 0)
        BlzFrameSetSize(parent, 0, 0)
        BlzFrameSetVisible(BlzGetFrameByName("LeaderboardBackdrop", 0), false)
        BlzFrameSetVisible(BlzGetFrameByName("LeaderboardTitle", 0), false)
        return parent
    end

    local function Update()
        -- update the full screen frame to current Resolution
        local y = BlzGetLocalClientHeight()
        if y ~= 0 then
            BlzFrameSetSize(TasFullScreenFrame, BlzGetLocalClientWidth()/y*0.6, 0.6)
        end
        local newSize = BlzFrameGetWidth(BlzGetFrameByName("ConsoleUIBackdrop", 0))
        if newSize ~= lastXSize then
            lastXSize = newSize
            BlzFrameSetScale(TasFullScreenParent, 1)
            BlzFrameSetScale(TasFullScreenParentScaled, newSize/0.8)
        end
    end
    
    local function InitFrames()
        -- Make the TasFullScreenFrames
        -- to allow TasFullScreenParent to expand over 4:3 it needs a Parent that can do such GetParent() gives us that one
        BlzGetFrameByName("ConsoleUIBackdrop", 0)
        local parent = GetParent()
        local frame = BlzCreateFrameByType("FRAME", "TasFullScreenParent", parent, "", 0)
        TasFullScreenParent = frame
        TasFullScreenParentScaled = BlzCreateFrameByType("FRAME", "TasFullScreenParentScaled", parent, "", 0)	    
        BlzFrameSetScale(TasFullScreenParent, 1)

        -- Lets make another Frame which size is the whole screen
        -- it is hidden to not take control and dont have visuals.
        -- as child of TasFullScreenParent it can expand outside of 4:3
        frame = BlzCreateFrameByType("FRAME", "TasFullScreenFrame", frame, "", 0)
        BlzFrameSetVisible(frame, false)
        BlzFrameSetSize(frame, 0.8, 0.6)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_BOTTOM, 0.4, 0)
        TasFullScreenFrame = frame
    end

    -- this would be an outside thing that calls the others
    function TasFullScreenFrameInit()
        InitFrames()
        if FrameLoaderAdd then FrameLoaderAdd(InitFrames) end
        TimerStart(CreateTimer(), UpdateRate, true, Update)
    end
    if AutoRun then
        if OnInit then -- Total Initialization v5.2.0.1 by Bribe
            OnInit.final("TasFullScreenFrame", TasFullScreenFrameInit)
        else -- without
            local real = MarkGameStarted
            function MarkGameStarted()
                real()
                TasFullScreenFrameInit()
            end
        end
    end
end