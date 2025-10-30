if Debug and Debug.beginFile then Debug.beginFile("TeleportConfig.lua") end
--==================================================
-- TeleportConfig.lua (v1.1)
-- Canonical teleport node registry
-- • Defines hub + zone nodes, coords, and returns
-- • Merges with GameBalance tables
-- • Used by TeleportSystem + ZoneTeleporterNPC
--==================================================

if not TeleportConfig then TeleportConfig = {} end
_G.TeleportConfig = TeleportConfig

do
    --------------------------------------------------
    -- Internal tables
    --------------------------------------------------
    local NODES, PRETTY, COORDS, LINKS, RETURNS = {}, {}, {}, {}, {}

    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[TPConfig] " .. tostring(s)) end
    end

    local function ensureSet(t, k) t[k] = t[k] or {}; return t[k] end
    local function addNode(id, pretty, xyz)
        if not id or id == "" then return end
        NODES[id] = id
        if pretty then PRETTY[id] = pretty end
        if xyz and xyz.x and xyz.y then
            COORDS[id] = { x = xyz.x, y = xyz.y, z = xyz.z or 0.0 }
        end
    end
    local function link(a, b)
        if not a or not b then return end
        ensureSet(LINKS, a)[b] = true
        ensureSet(LINKS, b)[a] = true
    end
    local function mapReturn(a, b)
        if a and b and a ~= "" and b ~= "" then RETURNS[a] = b end
    end

    --------------------------------------------------
    -- Load GameBalance references
    --------------------------------------------------
    local GB = GameBalance or {}
    local IDS = GB.TELEPORT_NODE_IDS or {}
    IDS.YEMMA        = IDS.YEMMA        or "YEMMA"
    IDS.KAMI_LOOKOUT = IDS.KAMI_LOOKOUT or "KAMI_LOOKOUT"
    IDS.SPIRIT_REALM = IDS.SPIRIT_REALM or "SPIRIT_REALM"
    IDS.HFIL         = IDS.HFIL         or "HFIL"
    IDS.VIRIDIAN     = IDS.VIRIDIAN     or "VIRIDIAN"
    IDS.FILE_ISLAND  = IDS.FILE_ISLAND  or "FILE_ISLAND"
    IDS.LAND_OF_FIRE = IDS.LAND_OF_FIRE or "LAND_OF_FIRE"

    --------------------------------------------------
    -- Hubs
    --------------------------------------------------
    addNode(IDS.YEMMA, "King Yemma's Desk", (GB.HUB_COORDS or {}).YEMMA)
    addNode(IDS.KAMI_LOOKOUT, "Kami's Lookout", (GB.HUB_COORDS or {}).KAMI_LOOKOUT)

    --------------------------------------------------
    -- Zones (world areas)
    --------------------------------------------------
    addNode(IDS.HFIL, "HFIL", (GB.ZONE_COORDS or {}).HFIL)
    addNode(IDS.VIRIDIAN, "Viridian Forest", (GB.ZONE_COORDS or {}).VIRIDIAN)
    addNode(IDS.FILE_ISLAND, "File Island", (GB.ZONE_COORDS or {}).FILE_ISLAND)
    addNode(IDS.LAND_OF_FIRE, "Land of Fire", (GB.ZONE_COORDS or {}).LAND_OF_FIRE)

    --------------------------------------------------
    -- Hub <-> Zone links
    --------------------------------------------------
    link(IDS.YEMMA, IDS.HFIL)
    link(IDS.KAMI_LOOKOUT, IDS.VIRIDIAN)
    link(IDS.KAMI_LOOKOUT, IDS.FILE_ISLAND)
    link(IDS.KAMI_LOOKOUT, IDS.LAND_OF_FIRE)

    --------------------------------------------------
    -- Zone Return Mappings (used by ZoneTeleporterNPC)
    --------------------------------------------------
    mapReturn(IDS.HFIL, IDS.YEMMA)
    mapReturn(IDS.VIRIDIAN, IDS.KAMI_LOOKOUT)
    mapReturn(IDS.FILE_ISLAND, IDS.KAMI_LOOKOUT)
    mapReturn(IDS.LAND_OF_FIRE, IDS.KAMI_LOOKOUT)

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function TeleportConfig.AddNode(id, pretty, x, y, z)
        addNode(id, pretty, x and { x = x, y = y, z = z } or nil)
    end
    function TeleportConfig.SetPretty(id, pretty)
        if id and id ~= "" then PRETTY[id] = pretty end
    end
    function TeleportConfig.SetCoord(id, x, y, z)
        if id and id ~= "" then
            COORDS[id] = { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
        end
    end
    function TeleportConfig.Link(a, b) link(a, b) end
    function TeleportConfig.MapReturn(a, b) mapReturn(a, b) end
    function TeleportConfig.GetAll()
        return { NODES = NODES, PRETTY = PRETTY, COORDS = COORDS, LINKS = LINKS, RETURNS = RETURNS }
    end

    --------------------------------------------------
    -- Init merge
    --------------------------------------------------
    OnInit.final(function()
        GameBalance = GameBalance or {}
        GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {}
        for k,v in pairs(NODES) do GameBalance.TELEPORT_NODE_IDS[k] = v end
        GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {}
        for k,v in pairs(PRETTY) do GameBalance.NODE_PRETTY[k] = v end
        GameBalance.NODE_COORDS = GameBalance.NODE_COORDS or {}
        for k,v in pairs(COORDS) do
            GameBalance.NODE_COORDS[k] = { x=v.x, y=v.y, z=v.z or 0.0 }
        end

        _G.TeleportLinks = _G.TeleportLinks or {}
        for a,set in pairs(LINKS) do
            _G.TeleportLinks[a] = _G.TeleportLinks[a] or {}
            for b,_ in pairs(set) do _G.TeleportLinks[a][b] = true end
        end

        if _G.ZoneTeleporterNPC and ZoneTeleporterNPC.MapReturn then
            for k,v in pairs(RETURNS) do ZoneTeleporterNPC.MapReturn(k,v) end
        end

        dprint("merged teleport nodes, hubs, and returns")
        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportConfig")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
