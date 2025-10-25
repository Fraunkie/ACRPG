if Debug and Debug.beginFile then Debug.beginFile("AnimationRegistry.lua") end
--==================================================
-- AnimationRegistry.lua
-- Version: v1.07 (2025-10-24)
-- Name or index based animation playback per hero or unit
-- Clears common animation tags before play
-- Includes override for H000: walkIndex=22, idleIndex=25
--==================================================

do
    AnimRegistry = AnimRegistry or {}
    local REG = {}

    -- Register by heroType or unit name
    function AnimRegistry.Register(key, tbl)
        if type(key) ~= "string" or type(tbl) ~= "table" then return end
        REG[key] = tbl
    end

    -- Register by unit type rawcode
    AnimRegistry.ByUnitType = AnimRegistry.ByUnitType or {}

    -- Common animation tags that can block playback
    local COMMON_TAGS = {"alternate","second","third","fourth","fifth","swim","upgrade","defend"}
    function AnimRegistry.ClearCommonTags(u)
        for i = 1, #COMMON_TAGS do
            AddUnitAnimationProperties(u, COMMON_TAGS[i], false)
        end
    end

    -- Fallback name variants when no override exists
    local VARIANTS = {
        walk   = {"Walk","Run","walk","run"},
        idle   = {"Stand","Stand - 2","Idle","idle"},
        attack = {"Attack","Attack Slam","Spell","attack","spell"},
        death  = {"Death","death"},
        hit    = {"Stand Hit","Hit","stand hit","hit"},
    }

    local function playByName(u, name, speed)
        SetUnitAnimation(u, name)
        SetUnitTimeScale(u, speed or 1.0)
    end
    local function playByIndex(u, idx, speed)
        SetUnitAnimationByIndex(u, idx)
        SetUnitTimeScale(u, speed or 1.0)
    end

    local function resolveKey(u)
        if not u then return nil end
        local pid = GetPlayerId(GetOwningPlayer(u))
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].heroType then
            return PLAYER_DATA[pid].heroType
        end
        local nm = GetUnitName(u)
        if nm and nm ~= "" then return nm end
        return nil
    end
    local function getEntry(u)
        local raw = GetUnitTypeId(u)
        return AnimRegistry.ByUnitType[raw] or REG[resolveKey(u)]
    end

    local function playResolved(u, label, speed)
        AnimRegistry.ClearCommonTags(u)
        local entry = getEntry(u)
        if entry then
            local idxKey, nameKey = (label.."Index"), label
            if entry[idxKey] ~= nil then
                playByIndex(u, entry[idxKey], speed or 1.0)
                return true
            end
            if entry[nameKey] ~= nil then
                playByName(u, entry[nameKey], speed or 1.0)
                return true
            end
        end
        local list = VARIANTS[label]
        if list then
            for i = 1, #list do playByName(u, list[i], speed or 1.0) end
            return true
        end
        return false
    end

    -- Public API
    function AnimRegistry.PlayWalk(u)    playResolved(u, "walk",   1.0) end
    function AnimRegistry.PlayIdle(u)    playResolved(u, "idle",   1.0) end
    function AnimRegistry.PlayAttack(u)  playResolved(u, "attack", 1.0) end
    function AnimRegistry.PlayDeath(u)   playResolved(u, "death",  1.0) end
    function AnimRegistry.PlayHit(u)     playResolved(u, "hit",    1.0) end

    -- Per unit override for your custom model
    AnimRegistry.ByUnitType[FourCC('H001')] = {
        walkIndex = 22,
        idleIndex = 0,
    }
end

if Debug and Debug.endFile then Debug.endFile() end
