if Debug and Debug.beginFile then Debug.beginFile("CharacterCreation_Adapter.lua") end
--==================================================
-- CharacterCreation_Adapter.lua (SAFE)
-- • No automatic unit creation
-- • Load only loads; failures do NOT create a hero
-- • Create action is explicit via CharacterCreation.Begin(pid)
-- • Slot-based save/load; chat helpers for testing
--==================================================

if not CharacterCreation_Adapter then CharacterCreation_Adapter = {} end
_G.CharacterCreation_Adapter = CharacterCreation_Adapter

do
    local DEFAULT_SLOT = 1

    local function PD(pid)
        if _G.PlayerData and PlayerData.Get then return PlayerData.Get(pid) end
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    local function openSlotsUI(pid)
        if CharacterCreation_UI and CharacterCreation_UI.ShowMenu then
            pcall(CharacterCreation_UI.ShowMenu, pid)
        end
    end

    --------------------------------------------------
    -- Public API (explicit actions only)
    --------------------------------------------------

    -- Try to load a slot. On failure, DO NOT create a hero.
    -- Returns true on success, false on failure.
    function CharacterCreation_Adapter.LoadSoul(pid, slotName)
        local slot = tonumber(slotName) or DEFAULT_SLOT
        if not SaveLoadSystem or not SaveLoadSystem.Load then
            DisplayTextToPlayer(Player(pid), 0, 0, "Save system not available.")
            -- Do nothing else.
            return false
        end

        local ok, err = SaveLoadSystem.Load(pid, slot)
        if ok then
            DisplayTextToPlayer(Player(pid), 0, 0, "Loaded slot " .. tostring(slot) .. ".")
            return true
        end

        if err == "epoch_mismatch" then
            DisplayTextToPlayer(Player(pid), 0, 0, "Old save detected. Please create a new soul.")
            -- Show slots UI so player can choose or save later
            openSlotsUI(pid)
            return false
        end

        if err == "not_found" then
            DisplayTextToPlayer(Player(pid), 0, 0, "No save found in slot " .. tostring(slot) .. ".")
            openSlotsUI(pid)
            return false
        end

        DisplayTextToPlayer(Player(pid), 0, 0, "Load failed: " .. tostring(err))
        return false
    end

    -- Save current state to slot (no unit creation)
    function CharacterCreation_Adapter.SaveSoul(pid, slotName)
        local slot = tonumber(slotName) or DEFAULT_SLOT
        if not SaveLoadSystem or not SaveLoadSystem.Save then
            DisplayTextToPlayer(Player(pid), 0, 0, "Save system not available.")
            return false
        end
        local ok, err = SaveLoadSystem.Save(pid, PD(pid), slot)
        if ok then
            DisplayTextToPlayer(Player(pid), 0, 0, "Saved slot " .. tostring(slot) .. ".")
            return true
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "Save failed: " .. tostring(err))
            return false
        end
    end

    -- Explicit new soul creation (only call this from your UI Create button)
    function CharacterCreation_Adapter.CreateNewSoul(pid)
        if CharacterCreation and CharacterCreation.Begin then
            pcall(CharacterCreation.Begin, pid)
        else
            DisplayTextToPlayer(Player(pid), 0, 0, "CharacterCreation system not available.")
        end
    end

    -- Optional: an auto entry BootFlow can call.
    -- Attempts to load; on failure, only opens slot UI (no hero creation).
    function CharacterCreation_Adapter.TryAutoLoad(pid, slotName)
        local ok = CharacterCreation_Adapter.LoadSoul(pid, slotName or DEFAULT_SLOT)
        if not ok then
            openSlotsUI(pid) -- let the player decide to Create or pick another slot
        end
        return ok
    end

    --------------------------------------------------
    -- Dev chat helpers (non-intrusive)
    --------------------------------------------------
    OnInit.final(function()
        local tSave = CreateTrigger()
        local tLoad = CreateTrigger()
        local tNew  = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(tSave, Player(i), "-save", false)
            TriggerRegisterPlayerChatEvent(tLoad, Player(i), "-load", false)
            TriggerRegisterPlayerChatEvent(tNew,  Player(i), "-new",  true)
        end

        TriggerAddAction(tSave, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local msg = GetEventPlayerChatString()
            local slot = tonumber(string.sub(msg, 6)) or 1
            CharacterCreation_Adapter.SaveSoul(pid, slot)
        end)

        TriggerAddAction(tLoad, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local msg = GetEventPlayerChatString()
            local slot = tonumber(string.sub(msg, 6)) or 1
            CharacterCreation_Adapter.LoadSoul(pid, slot)
        end)

        TriggerAddAction(tNew, function()
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            CharacterCreation_Adapter.CreateNewSoul(pid)
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CharacterCreation_Adapter")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
