if Debug and Debug.beginFile then Debug.beginFile("SpiritDrive.lua") end
--==================================================
-- SpiritDrive.lua
-- Player-only Spirit Drive (rage) store and helpers.
-- • Ignores non-human pids (no SD to creeps/neutral)
-- • Reads defaults from GameBalance when present
--==================================================

do
    if not SpiritDrive then SpiritDrive = {} end
    _G.SpiritDrive = SpiritDrive

    local function MaxDefault()
        local gb = _G.GameBalance
        if gb and gb.SD_MAX_DEFAULT then return gb.SD_MAX_DEFAULT end
        return 100
    end

    local function IsHumanPid(pid)
        if pid == nil then return false end
        if pid < 0 or pid >= bj_MAX_PLAYERS then return false end
        local pl = Player(pid)
        return GetPlayerController(pl) == MAP_CONTROL_USER
    end

    -- Backing store kept in PlayerData fields
    local function ensurePD(pid)
        if not _G.PlayerData or not PlayerData.Get then return nil end
        return PlayerData.Get(pid)
    end

    function SpiritDrive.Get(pid)
        local pd = ensurePD(pid)
        local v = pd and pd.spiritDrive or 0
        local m = pd and (pd.spiritMax or MaxDefault()) or MaxDefault()
        return v, m
    end

    function SpiritDrive.Set(pid, value)
        if not IsHumanPid(pid) then return SpiritDrive.Get(pid) end
        local pd = ensurePD(pid); if not pd then return 0, MaxDefault() end
        local max = pd.spiritMax or MaxDefault()
        local v = math.max(0, math.min(value or 0, max))
        pd.spiritDrive = v
        return v, max
    end

    function SpiritDrive.Add(pid, amount)
        if not IsHumanPid(pid) then return SpiritDrive.Get(pid) end
        local v, m = SpiritDrive.Get(pid)
        amount = amount or 0
        if amount == 0 then return v, m end
        local nv = v + amount
        if nv < 0 then nv = 0 end
        if nv > m then nv = m end
        return SpiritDrive.Set(pid, nv)
    end

    -- Optional: decay tick (respect GameBalance knobs if you use them)
    local function startDecay()
        local gb = _G.GameBalance
        local delay = gb and gb.SD_OUT_OF_COMBAT_DELAY or 5.0
        local rate  = gb and gb.SD_DRAIN_RATE or 4.0
        local t = CreateTimer()
        TimerStart(t, 1.0, true, function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if IsHumanPid(pid) then
                    local pd = ensurePD(pid)
                    if pd and pd.spiritDrive and pd.spiritDrive > 0 then
                        -- simplistic decay model; plug into your OOC detection as needed
                        if pd._sd_ooc_since and (os.clock() - pd._sd_ooc_since) >= delay then
                            local v, m = SpiritDrive.Get(pid)
                            local nv = v - rate
                            if nv < 0 then nv = 0 end
                            SpiritDrive.Set(pid, nv)
                        end
                    end
                end
            end
        end)
    end

    -- Public helpers for combat code to signal OOC transitions
    function SpiritDrive.MarkInCombat(pid)
        local pd = ensurePD(pid); if not pd then return end
        pd._sd_ooc_since = nil
    end
    function SpiritDrive.MarkOutOfCombat(pid)
        local pd = ensurePD(pid); if not pd then return end
        pd._sd_ooc_since = os.clock()
    end

    OnInit.final(function()
        startDecay()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritDrive")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
