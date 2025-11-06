do

    function Accept(whichDialog, buttonName, whichPlayer)
    local pid = GetPlayerId(whichPlayer)
    

    -- Define the Goku shard ID (or other shards you might use)
    local GOKU_SHARD_ID = FourCC("I00W")  -- Goku's shard ID (adjust if necessary)
    local VEGETA_SHARD_ID = FourCC("I015")  -- Vegeta's shard ID (adjust if necessary)

    -- Check if the player has a charged Goku shard
    local isGokuShardCharged = PLAYER_DATA[pid] and PLAYER_DATA[pid].chargedShards and PLAYER_DATA[pid].chargedShards[GOKU_SHARD_ID] == true

    -- Check if the player has a charged Vegeta shard
    local isVegetaShardCharged = PLAYER_DATA[pid] and PLAYER_DATA[pid].chargedShards and PLAYER_DATA[pid].chargedShards[VEGETA_SHARD_ID] == true

    -- If Goku's shard is charged, proceed with Goku ascension logic
    if isGokuShardCharged then
        DisplayTextToPlayer(whichPlayer, 0, 0, "Goku Ascension Accepted!")
        local unitid = FourCC("H000")
        local u = PlayerData.GetHero(pid)
        local spawnX = GetUnitX(u)
        local spawnY = GetUnitY(u)
        local f = GetUnitFacing(u)
        local hero = CreateUnit(Player(pid), unitid, spawnX, spawnY, f)
        PlayerData.SetHero(pid,hero)
        SlotPicker.ClearLoadout(pid)
        CustomSpellBar.BindHero(pid, hero)
        RemoveUnit(u)
        
        

        local actorData = {
        identifier = "heroActor",  -- Unique identifier for the actor
        interactions = { h004 = test },  -- Define interactions (like being near an object)
        flags = { radius = 500, anchor = hero }  -- Attach the actor to the new hero
    }
        ALICE_Create(hero, actorData.identifier, actorData.interactions)
        
        -- Execute Goku ascension logic (change unit, reset talents, etc.)
        -- Example: ChangeUnitToGoku(pid)

    -- If Vegeta's shard is charged, proceed with Vegeta ascension logic
    elseif isVegetaShardCharged then
        DisplayTextToPlayer(whichPlayer, 0, 0, "Vegeta Ascension Accepted!")
        -- Execute Vegeta ascension logic (change unit, reset talents, etc.)
        -- Example: ChangeUnitToVegeta(pid)

    else
        -- If no charged shard is found, close the dialog or check for another shard
        DisplayTextToPlayer(whichPlayer, 0, 0, "You need a charged Goku or Vegeta shard to ascend!")
        CloseDialog(whichDialog)  -- Close the dialog
        -- Alternatively, you can check for other shards or just keep the dialog open for more checks.
    end

    -- Always close the dialog after processing
    CloseDialog(whichDialog)
end


    function Close(whichDialog, buttonName, whichPlayer)
        -- Close the dialog
        CloseDialog(whichDialog)
    end

    function CreateAscensionForPlayer(pid)
        -- Create the dialog for the player and pass the correct callback
        CreateBetterDialogForPlayer(Player(pid), "Ascend",
            {
                -- Button 1
                {"Ascend"},  -- Button Title
                {[[ Start your Ascension.|r]]},  -- Tooltip
                Accept,  -- Callback (no `itemid` needed)
                
                -- Button 2
                {"Close"},  -- Button Title
                "Closes the menu.",  -- Tooltip
                Close  -- Callback
            }
        )
    end

    if OnInit and OnInit.final then
        OnInit.final(function()
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("Ascension Dialog Loaded")
            end
        end)
    end
end