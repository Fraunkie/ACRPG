if Debug and Debug.beginFile then Debug.beginFile("WorldFlags.lua") end
--==================================================
-- WorldFlags.lua
-- Per-player world flags (simple store used by YemmaHub)
--==================================================

do
    WorldFlags = WorldFlags or {}
    _G.WorldFlags = WorldFlags

    local STORE = STORE or {} -- [pid] -> { [flag]=true }

    local function ensure(pid)
        STORE[pid] = STORE[pid] or {}
        return STORE[pid]
    end

    function WorldFlags.Set(pid, flag, value)
        local t = ensure(pid)
        t[flag] = value and true or nil
    end

    function WorldFlags.Has(pid, flag)
        local t = ensure(pid)
        return t[flag] == true
    end

    function WorldFlags.Clear(pid, flag)
        local t = ensure(pid)
        t[flag] = nil
    end

    function WorldFlags.List(pid)
        local t = ensure(pid)
        local out = {}
        for k, v in pairs(t) do if v then out[#out+1] = k end end
        table.sort(out)
        return out
    end
end

if Debug and Debug.endFile then Debug.endFile() end
