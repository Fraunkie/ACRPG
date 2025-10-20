if Debug and Debug.beginFile then Debug.beginFile("StatsPanel.lua") end
--==================================================
-- RPG Stats Panel v2  (two-column, fragment families)
--==================================================
-- Opens via chat:  -statspanel
-- Public: StatsPanel.RefreshLocal(pid) for external nudges
--==================================================

if not StatsPanel then StatsPanel = {} end
_G.StatsPanel = StatsPanel

do
    local LABEL_COLOR = "|cffffcc00"
    local WHITE = "|cffffffff"

    local FAMILY_ORDER = {"Saiyan","Namekian","Chakra","Digi","Poke","Dragonball","Pokemon","Digi","Chakra"} -- we’ll print what exists

    --──────── helpers
    local function SafeGetHero(pid)
        if PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].hero then
            return PLAYER_DATA[pid].hero
        end
        return nil
    end

    local function GetStat(pid, stat)
        if HeroStatSystem and HeroStatSystem.GetPlayerBaseStat then
            return HeroStatSystem.GetPlayerBaseStat(pid, stat)
        end
        return 0
    end

    local function GetPower(pid)
        if HeroStatSystem and HeroStatSystem.GetPowerLevel then
            return HeroStatSystem.GetPowerLevel(pid)
        end
        return (PLAYER_DATA and PLAYER_DATA[pid] and (PLAYER_DATA[pid].powerLevel or 0)) or 0
    end

    local function GetSoul(pid)
        if SoulEnergy and SoulEnergy.Get then
            return SoulEnergy.Get(pid)
        end
        return (PLAYER_DATA and PLAYER_DATA[pid] and (PLAYER_DATA[pid].soulEnergy or 0)) or 0
    end

    local function GetFragTotals(pid)
        local SF = rawget(_G, "ShardFragments")
        if SF and SF.GetTotal and SF.GetAllFamilies then
            return SF.GetTotal(pid), SF.GetAllFamilies(pid)
        end
        return (PLAYER_DATA and PLAYER_DATA[pid] and (PLAYER_DATA[pid].fragments_total or 0)) or 0, {}
    end

    --──────── text display logic
    local function refresh(pid)
        local hero  = SafeGetHero(pid)
        local name  = GetPlayerName(Player(pid))
        local power = GetPower(pid)
        local se    = GetSoul(pid)

        local hp, hpmax, mp, mpmax = 0, 0, 0, 0
        if hero and GetUnitTypeId(hero) ~= 0 then
            hp    = math.floor(GetWidgetLife(hero))
            hpmax = BlzGetUnitMaxHP(hero) or 0
            mp    = math.floor(GetUnitState(hero, UNIT_STATE_MANA))
            mpmax = BlzGetUnitMaxMana(hero) or 0
        end

        local str = GetStat(pid, "STR") or 0
        local agi = GetStat(pid, "AGI") or 0
        local int = GetStat(pid, "INT") or 0

        -- Display text to player
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Player:|r "..WHITE..name.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Power Level:|r "..WHITE..power.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Strength:|r "..WHITE..str.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Agility:|r "..WHITE..agi.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Intelligence:|r "..WHITE..int.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Life:|r "..WHITE..hp.." / "..hpmax.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Mana:|r "..WHITE..mp.." / "..mpmax.."|r")
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Soul Energy:|r "..WHITE..se.."|r")

        -- Display fragments
        local total, fam = GetFragTotals(pid)
        DisplayTextToPlayer(Player(pid), 0, 0, LABEL_COLOR.."Fragments:|r "..WHITE..total.."|r")

        -- show up to 4 meaningful families
        local printed = 0
        local used = {}
        for _, key in ipairs(FAMILY_ORDER) do
            local v = fam[key]
            if v and v > 0 and printed < 4 then
                DisplayTextToPlayer(Player(pid), 0, 0, "• "..key..": "..v)
                used[key] = true
                printed = printed + 1
            end
        end
        -- if fewer than 4, print any remaining nonzero families
        if printed < 4 then
            for k,v in pairs(fam) do
                if not used[k] and v > 0 and printed < 4 then
                    DisplayTextToPlayer(Player(pid), 0, 0, "• "..k..": "..v)
                    printed = printed + 1
                end
            end
        end
    end

    --──────── public
    function StatsPanel.Show(pid)
        refresh(pid)
    end

    function StatsPanel.Hide(pid)
        -- Do nothing for now (no UI elements to hide)
    end

    function StatsPanel.Toggle(pid)
        -- Simply show stats panel when called
        StatsPanel.Show(pid)
    end

    -- light nudge from other systems when fragments change
    function StatsPanel.RefreshLocal(pid)
        refresh(pid)
    end

    -- ESC closes panel
    local escTrig = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerEventEndCinematic(escTrig, Player(i))
    end
    TriggerAddAction(escTrig, function()
        local pid = GetPlayerId(GetTriggerPlayer())
        StatsPanel.Hide(pid)
    end)

    -- chat command
    local function setupChat()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-statspanel", true)
        end
        TriggerAddAction(trig, function()
            local pid = GetPlayerId(GetTriggerPlayer())
            StatsPanel.Toggle(pid)
        end)
    end

    OnInit.final(function()
        setupChat()
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
