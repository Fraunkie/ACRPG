if Debug and Debug.beginFile then Debug.beginFile("TeleportConfig.lua") end
--==================================================
-- TeleportConfig.lua (v1.2)
-- Canonical teleport node registry
-- • Defines hub + zone nodes, coords, and returns
-- • Merges with GameBalance tables (pretty, coords, icons, desc)
-- • Used by TeleportSystem + ZoneTeleporterNPC
--==================================================

if not TeleportConfig then TeleportConfig = {} end
_G.TeleportConfig = TeleportConfig

do
    --------------------------------------------------
    -- Internal tables
    --------------------------------------------------
    local NODES, PRETTY, COORDS, LINKS, RETURNS = {}, {}, {}, {}, {}
    local ICONS,  DESCS  = {}, {}

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
    local function setIcon(id, blp) if id and blp then ICONS[id] = blp end end
    local function setDesc(id, txt) if id and txt then DESCS[id] = txt end end

    --------------------------------------------------
    -- Load GameBalance references
    --------------------------------------------------
    local GB  = GameBalance or {}
    local IDS = GB.TELEPORT_NODE_IDS or {}
    IDS.YEMMA        = IDS.YEMMA        or "YEMMA"
    IDS.NEO_CAPSULE_CITY          = IDS.NEO_CAPSULE_CITY          or "NEO_CAPSULE_CITY"
    IDS.KAMI_LOOKOUT = IDS.KAMI_LOOKOUT or "KAMI_LOOKOUT"
    IDS.SPIRIT_REALM = IDS.SPIRIT_REALM or "SPIRIT_REALM"
    IDS.HFIL         = IDS.HFIL         or "HFIL"
    IDS.VIRIDIAN     = IDS.VIRIDIAN     or "VIRIDIAN"
    IDS.FILE_ISLAND  = IDS.FILE_ISLAND  or "FILE_ISLAND"
    IDS.LAND_OF_FIRE = IDS.LAND_OF_FIRE or "LAND_OF_FIRE"

    --------------------------------------------------
    -- Hubs
    --------------------------------------------------
    addNode(IDS.YEMMA, "Yemma`s Bureau", (GB.HUB_COORDS or {}).YEMMA)
    -- Icon + description (from your assets & copy)
    setIcon(IDS.YEMMA, "ReplaceableTextures\\CommandButtons\\BTNKingYemma.blp")
    setDesc(IDS.YEMMA,
        "“The Desk at the Brink”  " ..
        "Suspended over golden clouds at the world’s edge, the Bureau remains the first stop for every spirit and the last before HFIL. " ..
        "The Snake Way still stretches outward, its glow fading into distortion, while Yemma guards the gates with one hand on a stamp and the other on his temper.  " ..
        "\n\n“Edge of the universe or not, the paperwork still has to be signed.” — King Yemma"
    )

    --------------------------------------------------
    -- Zones (world areas)
    --------------------------------------------------a
    addNode(IDS.HFIL, "HFIL", (GB.ZONE_COORDS or {}).HFIL)
    -- Icon + description (from your assets & lore)
    setIcon(IDS.HFIL, "ReplaceableTextures\\CommandButtons\\BTNHFILTeleport.blp")
    setDesc(IDS.HFIL,
        "HFIL — “The Twisted Afterrealm”  " ..
        "Once the pit where the unworthy were cast, HFIL now writhes under the Convergence’s influence. " ..
        "The plains churn with restless spirits, graveyards breathe, and glowing pools feed the Ascension Gate that links death and rebirth. " ..
        "It is both prison and forge — a place where souls either awaken… or vanish forever.  " ..
        "\n\n“I tried keeping order down here, but the universe exploded and no one filed the paperwork.” — King Yemma"
    )
    addNode(IDS.NEO_CAPSULE_CITY, "Neo Capsule City", (GB.ZONE_COORDS or {}).NEO_CAPSULE_CITY)
    setIcon(IDS.NEO_CAPSULE_CITY, "ReplaceableTextures\\CommandButtons\\BTNNeoCapsuleCityTeleport.blp")
    setDesc(IDS.NEO_CAPSULE_CITY,
        "Neo Capsule City — “The Four-Fold Haven”  " ..
        "Saved from the brink of annihilation by Bulma’s temporal shield, West City fused with fragments of other realms to form a living crossroads of science and spirit. " ..
        "From Capsule towers to ramen streets, from power plants to data halls, it stands as the beating heart of the new world — proof that brilliance and chaos can coexist under one sky." ..
        "\n\n“Hey, I tried to save everyone — figured if the universe was gonna implode, we might as well have decent Wi‑Fi and takeout from four worlds.” — Bulma Briefs")
    addNode(IDS.VIRIDIAN, "Viridian Forest", (GB.ZONE_COORDS or {}).VIRIDIAN)
    addNode(IDS.FILE_ISLAND, "File Island", (GB.ZONE_COORDS or {}).FILE_ISLAND)
    addNode(IDS.LAND_OF_FIRE, "Land of Fire", (GB.ZONE_COORDS or {}).LAND_OF_FIRE)

    --------------------------------------------------
    -- Hub <-> Zone links
    --------------------------------------------------
    link(IDS.YEMMA, IDS.HFIL)
    link(IDS.YEMMA, IDS.NEO_CAPSULE_CITY)
    link(IDS.KAMI_LOOKOUT, IDS.VIRIDIAN)
    link(IDS.KAMI_LOOKOUT, IDS.FILE_ISLAND)
    link(IDS.KAMI_LOOKOUT, IDS.LAND_OF_FIRE)

    --------------------------------------------------
    -- Zone Return Mappings (used by ZoneTeleporterNPC)
    --------------------------------------------------
    mapReturn(IDS.HFIL, IDS.YEMMA)
    mapReturn(IDS.NEO_CAPSULE_CITY, IDS.YEMMA)
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
    function TeleportConfig.SetIcon(id, blp) setIcon(id, blp) end
    function TeleportConfig.SetDesc(id, txt) setDesc(id, txt) end
    function TeleportConfig.Link(a, b) link(a, b) end
    function TeleportConfig.MapReturn(a, b) mapReturn(a, b) end
    function TeleportConfig.GetAll()
        return { NODES = NODES, PRETTY = PRETTY, COORDS = COORDS, LINKS = LINKS, RETURNS = RETURNS, ICONS = ICONS, DESCS = DESCS }
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

        GameBalance.NODE_ICONS = GameBalance.NODE_ICONS or {}
        for k,v in pairs(ICONS) do GameBalance.NODE_ICONS[k] = v end

        GameBalance.NODE_DESC = GameBalance.NODE_DESC or {}
        for k,v in pairs(DESCS) do GameBalance.NODE_DESC[k] = v end

        _G.TeleportLinks = _G.TeleportLinks or {}
        for a,set in pairs(LINKS) do
            _G.TeleportLinks[a] = _G.TeleportLinks[a] or {}
            for b,_ in pairs(set) do _G.TeleportLinks[a][b] = true end
        end

        if _G.ZoneTeleporterNPC and ZoneTeleporterNPC.MapReturn then
            for k,v in pairs(RETURNS) do ZoneTeleporterNPC.MapReturn(k,v) end
        end

        dprint("merged teleport nodes, hubs, returns, icons, desc")
        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportConfig")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
