if Debug and Debug.beginFile then Debug.beginFile("CharacterCreation_Adapter.lua") end
--==================================================
-- CharacterCreation_Adapter.lua
-- • Bridge between CharacterCreation and Save/Load system
-- • Handles future save slot loading, new soul creation, and persistence
-- • Currently stubs out with dev-safe placeholders
--==================================================

if not CharacterCreation_Adapter then CharacterCreation_Adapter = {} end
_G.CharacterCreation_Adapter = CharacterCreation_Adapter

do
    local SAVE_DIR = "AnimecraftSaves" -- placeholder folder for future save integration

    --------------------------------------------------
    -- Internal references
    --------------------------------------------------
    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    --------------------------------------------------
    -- Future: Load Save Slot
    --------------------------------------------------
    function CharacterCreation_Adapter.LoadSoul(pid, slotName)
        local p = Player(pid)
        DisplayTextToPlayer(p, 0, 0, "Attempting to load soul slot: " .. tostring(slotName))

        -- TODO: integrate with SaveLoadSystem later
        if SaveLoadSystem and SaveLoadSystem.Load then
            pcall(SaveLoadSystem.Load, pid, slotName)
            return
        end

        -- Fallback message
        DisplayTextToPlayer(p, 0, 0, "No save system detected; using placeholder soul.")
        if CharacterCreation and CharacterCreation.Begin then
            pcall(CharacterCreation.Begin, pid)
        end
    end

    --------------------------------------------------
    -- Future: Save Soul Slot
    --------------------------------------------------
    function CharacterCreation_Adapter.SaveSoul(pid)
        local p = Player(pid)
        local pd = PD(pid)
        DisplayTextToPlayer(p, 0, 0, "Saving soul data for " .. GetPlayerName(p) .. "...")

        -- TODO: implement real save serialization
        if SaveLoadSystem and SaveLoadSystem.Save then
            pcall(SaveLoadSystem.Save, pid, pd)
        else
            DisplayTextToPlayer(p, 0, 0, "Placeholder: Saved locally in memory only.")
        end
    end

    --------------------------------------------------
    -- Hook from CharacterCreation Menu
    --------------------------------------------------
    function CharacterCreation_Adapter.OnMenuChoice(pid, choice)
        -- choice can be: "new", "load", "cancel"
        if choice == "new" then
            DisplayTextToPlayer(Player(pid), 0, 0, "Creating new soul...")
            if CharacterCreation and CharacterCreation.Begin then
                pcall(CharacterCreation.Begin, pid)
            end
        elseif choice == "load" then
            CharacterCreation_Adapter.LoadSoul(pid, "slot1")
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Cancelled soul creation.")
        end
    end

    --------------------------------------------------
    -- DevMode commands (for testing)
    --------------------------------------------------
    OnInit.final(function()
        local trigSave = CreateTrigger()
        local trigLoad = CreateTrigger()

        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trigSave, Player(i), "-savesoul", true)
            TriggerRegisterPlayerChatEvent(trigLoad, Player(i), "-loadsoul", true)
        end

        TriggerAddAction(trigSave, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            CharacterCreation_Adapter.SaveSoul(pid)
        end)

        TriggerAddAction(trigLoad, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            CharacterCreation_Adapter.LoadSoul(pid, "slot1")
        end)

        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("CharacterCreation_Adapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
