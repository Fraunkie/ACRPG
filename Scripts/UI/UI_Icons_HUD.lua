if Debug and Debug.beginFile then Debug.beginFile("UI_Icons_HUD.lua") end
--==================================================
-- UI_Icons_HUD.lua
-- Placeholder icon registry (safe for Warcraft III)
-- All entries are empty; fill with imported .blp paths later.
--==================================================

UIIcons_HUD = {
	ACCEPT          = "",  -- example: "war3mapImported\\ui_accept.blp"
	CANCEL          = "",
	QUESTION        = "",
	INFO            = "",
	CLOSE           = "",
	GEAR            = "",

	CREATE_SOUL     = "",
	SKIP_INTRO      = "",
	FULL_INTRO      = "",
	TELEPORT        = "",
	QUEST_BOOK      = "",
	BAG             = "",
	STATS_PANEL     = "",

	STAR            = "",
	ORB_BLUE        = "",
	ORB_RED         = "",
	ORB_GREEN       = "",
	CRYSTAL         = "",
	BOOK            = "",
}

_G.UIIcons_HUD = UIIcons_HUD

if Debug and Debug.endFile then Debug.endFile() end
