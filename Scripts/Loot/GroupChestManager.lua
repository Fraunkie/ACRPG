if Debug and Debug.beginFile then Debug.beginFile("GroupChestManager.lua") end
--==================================================
-- GroupChestManager.lua
-- One shared group chest per kill (when a group item procs).
-- Players near the kill (and/or with threat) can /roll or /pass.
-- Highest roll wins; if nobody rolls before timeout, item drops at chest.
-- • Safe for editor (no percent signs, no top-level natives that blow up)
-- • Announces only to players who enabled loot chat
--==================================================

if not GroupChestManager then GroupChestManager = {} end
_G.GroupChestManager = GroupChestManager

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local ROLL_MIN, ROLL_MAX       = 1, 100
    local TIMEOUT_SEC              = 20.0
    local RADIUS_NEAR              = 1200.0
    local REQUIRE_THREAT           = true      -- if ThreatSystem is present
    local MIN_THREAT_TO_QUALIFY    = 1
    local CHEST_FX                 = "Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl"
    local WIN_FX                   = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- sessions[id] = {
    --   id, x, y,
    --   item = { rawcode, name, rarity },
    --   participants = { pid,... },  -- who can roll
    --   rolls = { [pid] = {val=number} or {pass=true} },
    --   timer = timer
    -- }
    local sessions = {}
    local nextId = 1

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Chest] " .. tostring(s)) end
    end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function pidOf(p) return p and GetPlayerId(p) or nil end

    local function heroOf(pid)
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(pid)
            if pd and validUnit(pd.hero) then return pd.hero end
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function dist2xy(u, x, y)
        local ux, uy = GetUnitX(u), GetUnitY(u)
        local dx, dy = ux - x, uy - y
        return dx*dx + dy*dy
    end

    local function playFXOnce(path, x, y)
        if not path or path == "" then return end
        local e = AddSpecialEffect(path, x, y)
        DestroyEffect(e)
    end

    local function createItemAt(rawcode, x, y)
        if not rawcode or rawcode == "" then return nil end
        local ok, it = pcall(function() return CreateItem(FourCC(rawcode), x, y) end)
        if ok then return it end
        dprint("CreateItem failed for " .. tostring(rawcode))
        return nil
    end

    local function lootChatOn(pid)
        if not _G.PlayerData then return true end
        return PlayerData.GetField(pid, "lootChatEnabled", true) ~= false
    end

    local function sayToLootChat(msg)
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if lootChatOn(pid) then
                    DisplayTextToPlayer(Player(pid), 0, 0, msg)
                end
            end
        end
    end

    local function collectParticipantsAt(x, y, dead)
        local list = {}
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                local h = heroOf(pid)
                if validUnit(h) and dist2xy(h, x, y) <= (RADIUS_NEAR * RADIUS_NEAR) then
                    if REQUIRE_THREAT and rawget(_G, "ThreatSystem") and dead then
                        local th = ThreatSystem.GetThreat(h, dead) or 0
                        if th >= MIN_THREAT_TO_QUALIFY then
                            list[#list + 1] = pid
                        end
                    else
                        list[#list + 1] = pid
                    end
                end
            end
        end
        return list
    end

    local function everyoneDecided(sess)
        for i = 1, #sess.participants do
            local pid = sess.participants[i]
            local r = sess.rolls[pid]
            if not r then return false end
        end
        return true
    end

    local function pickWinner(sess)
        local winnerPid, best = nil, -1
        for pid, r in pairs(sess.rolls) do
            if r.val and r.val > best then
                best = r.val; winnerPid = pid
            end
        end
        return winnerPid, best
    end

    local function closeSession(sess, reason)
        -- Determine winner or drop at chest
        local winnerPid, best = pickWinner(sess)
        if winnerPid then
            local h = heroOf(winnerPid)
            if validUnit(h) then
                local x, y = GetUnitX(h), GetUnitY(h)
                createItemAt(sess.item.rawcode, x, y)
                playFXOnce(WIN_FX, x, y)
                local name = sess.item.name or sess.item.rawcode or "item"
                sayToLootChat("Loot roll won by player " .. tostring(winnerPid) .. " with " .. tostring(best) .. " (" .. name .. ")")
            else
                -- Winner has no hero? Drop at chest
                createItemAt(sess.item.rawcode, sess.x, sess.y)
                sayToLootChat("Loot roll winner unavailable; item dropped at chest")
            end
        else
            -- No rolls; drop at chest
            createItemAt(sess.item.rawcode, sess.x, sess.y)
            if reason == "timeout" then
                sayToLootChat("No rolls received; item dropped at chest")
            else
                sayToLootChat("All passed; item dropped at chest")
            end
        end

        -- Cleanup
        if sess.timer then DestroyTimer(sess.timer) end
        sessions[sess.id] = nil
    end

    local function ensureSessionTimer(sess)
        if sess.timer then return end
        sess.timer = CreateTimer()
        TimerStart(sess.timer, TIMEOUT_SEC, false, function()
            local ok, err = pcall(function() closeSession(sess, "timeout") end)
            if not ok then dprint("timeout close err " .. tostring(err)) end
        end)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function GroupChestManager.ActiveSessions()
        local ids = {}
        for id,_ in pairs(sessions) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end

    -- Spawn from a dead unit + rolled item (called by LootSystem_Bridge)
    function GroupChestManager.Spawn(dead, item)
        if not validUnit(dead) or not item or not item.rawcode then return nil end
        local x, y = GetUnitX(dead), GetUnitY(dead)
        local parts = collectParticipantsAt(x, y, dead)
        if #parts == 0 then return nil end

        local id = nextId; nextId = nextId + 1
        local sess = {
            id = id, x = x, y = y, item = item,
            participants = parts, rolls = {}, timer = nil
        }
        sessions[id] = sess
        ensureSessionTimer(sess)

        playFXOnce(CHEST_FX, x, y)
        local name = item.name or item.rawcode or "item"
        sayToLootChat("Group loot chest created (id " .. tostring(id) .. "): " .. name)
        return id
    end

    -- Spawn via ProcBus event (alternative wiring)
    -- e = { x, y, participants=?, item=?, timeoutSec=? }
    local function onGroupChestStart(e)
        if not e or not e.item or not e.item.rawcode then return end
        local x, y = e.x or 0, e.y or 0
        local parts = {}
        if type(e.participants) == "table" and #e.participants > 0 then
            for i = 1, #e.participants do parts[i] = e.participants[i] end
        else
            parts = collectParticipantsAt(x, y, nil)
        end
        if #parts == 0 then return end
        local id = nextId; nextId = nextId + 1
        local sess = {
            id = id, x = x, y = y, item = e.item,
            participants = parts, rolls = {}, timer = nil
        }
        sessions[id] = sess
        if type(e.timeoutSec) == "number" and e.timeoutSec > 0 then
            TIMEOUT_SEC = e.timeoutSec
        end
        ensureSessionTimer(sess)

        playFXOnce(CHEST_FX, x, y)
        local name = e.item.name or e.item.rawcode or "item"
        sayToLootChat("Group loot chest created (id " .. tostring(id) .. "): " .. name)
    end

    function GroupChestManager.Roll(pid, id)
        local sess = sessions[id]; if not sess then return false end
        -- Is pid allowed?
        local allowed = false
        for i = 1, #sess.participants do if sess.participants[i] == pid then allowed = true break end end
        if not allowed then return false end
        -- Already decided?
        if sess.rolls[pid] then return false end

        local val = GetRandomInt(ROLL_MIN, ROLL_MAX)
        sess.rolls[pid] = { val = val }
        sayToLootChat("Player " .. tostring(pid) .. " rolled " .. tostring(val) .. " on chest " .. tostring(id))

        if everyoneDecided(sess) then
            closeSession(sess, "early")
        end
        return true
    end

    function GroupChestManager.Pass(pid, id)
        local sess = sessions[id]; if not sess then return false end
        local allowed = false
        for i = 1, #sess.participants do if sess.participants[i] == pid then allowed = true break end end
        if not allowed then return false end
        if sess.rolls[pid] then return false end

        sess.rolls[pid] = { pass = true }
        sayToLootChat("Player " .. tostring(pid) .. " passed on chest " .. tostring(id))

        if everyoneDecided(sess) then
            closeSession(sess, "early")
        end
        return true
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            local PB = rawget(_G, "ProcBus")
            if PB and PB.On then
                PB.On("OnGroupLootChestStart", onGroupChestStart)
            end
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("GroupChestManager")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
