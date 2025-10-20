if Debug and Debug.beginFile then Debug.beginFile("StatsPanel.lua") end
--==================================================
-- StatsPanel.lua
-- Minimal stats readout for each player's hero.
-- • Listens to HeroStatsChanged and prints a compact line
-- • Show(pid) and Hide(pid) to toggle periodic refresh
--==================================================

if not StatsPanel then StatsPanel = {} end
_G.StatsPanel = StatsPanel

do
    local ACTIVE = {}      -- pid -> true
    local TICK = 1.0

    local function valid(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end
    local function safeText(pid, msg)
        if GetLocalPlayer() == Player(pid) then
            DisplayTextToPlayer(Player(pid), 0, 0, msg)
        end
    end

    local function render(pid)
        local hero = nil
        if _G.PlayerData and PlayerData.GetHero then
            hero = PlayerData.GetHero(pid)
        end
        if not valid(hero) then return end

        local hs = _G.HeroStatSystem
        if not hs then return end
        local p = hs.Get(hero, "power") or 0
        local d = hs.Get(hero, "defense") or 0
        local s = hs.Get(hero, "speed") or 0
        local c = hs.Get(hero, "crit") or 0

        safeText(pid, "[Stats] P " .. tostring(p) ..
                        " D " .. tostring(d) ..
                        " S " .. tostring(s) ..
                        " C " .. tostring(c))
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function StatsPanel.Show(pid)
        ACTIVE[pid] = true
        render(pid)
    end

    function StatsPanel.Hide(pid)
        ACTIVE[pid] = nil
    end

    function StatsPanel.Toggle(pid)
        if ACTIVE[pid] then
            StatsPanel.Hide(pid)
        else
            StatsPanel.Show(pid)
        end
    end

    --------------------------------------------------
    -- Event hookups
    --------------------------------------------------
    local function onHeroStatsChanged(e)
        if not e or not valid(e.unit) then return end
        local p = GetPlayerId(GetOwningPlayer(e.unit))
        if ACTIVE[p] then
            render(p)
        end
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("HeroStatsChanged", onHeroStatsChanged)
        end

        local tm = CreateTimer()
        TimerStart(tm, TICK, true, function()
            for pid, on in pairs(ACTIVE) do
                if on then render(pid) end
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("StatsPanel")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
