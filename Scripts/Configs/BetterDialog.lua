do
    
    --[[
    ===========================================================================================
                                        Better Dialogs
                                          by Antares
   
            		Create dialogs with button tooltips and cycle buttons.
           
                                        How to import:
									Requires TotalInitialization

    Copy this library into your map. Extract the .fdf files and the .toc file and import them
	into your map without a subfolder.
   
    The frame size values in the Config are designed to closely emulate the standard dialog.
	Edit them if you want to change the layout. You can also choose between standard tooltip 
	and EscMenu style tooltips.

	You can change the values in the .fdf files, such as the border size (BackdropCornerSize),
	the tooltip text size (FrameFont), textbox position (SetPoint) etc. Preset values might
	not be appropriate for every race UI.

	===========================================================================================

									How to create a dialog:
    
    Dialog creation functions expect a table that contains all data of the dialog buttons as an
	input argument. The table is a sequence containing:
	[1] ButtonTitle 1 (type string or table)
	[2] ButtonTooltip 1 (type string or table)
	[3] ButtonCallback 1 (type function)
	[4] ButtonTitle 2
	...

	If a string is passed as the argument for the buttonTitle, it is a regular dialog button. 
	Alternatively, you can pass a table as the argument to change the button into a cycle button. 
	When clicked, the button changes text to the next string in the sequence. The number of 
	strings stored in the sequence will determine the amount of states the button cycles through 
	before returning to the original state.
	
	If a button is defined as a cycle button, the tooltip can either be static (if a string is 
	passed) or cycling (if a string sequence is passed). If the tooltip is cycling, the table
	should have the same number of strings stored as the table of button titles. To omit the
	tooltip for a button, pass "".

	The button callback is the function that is executed upon clicking the button. It is expected
	to be function with three arguments:

    function myCallback(whichDialog, buttonName, whichPlayer)

	buttonName specifies the title of the button that was clicked. This allows you to use the
	same callback function for all buttons and execute the correct code based on which button
	was clicked. whichPlayer specifies the player that clicked the button. Alternatively, you can
	use a different callback function for each button.

	For cycling buttons, buttonName specifies the title that the button just cycled into.

	If the clicked button is supposed to close the associated dialog, include
	CloseDialog(whichDialog)
	in the callback function.

	If a dialog is created for multiple players, each player sees a completely different copy of
	that dialog.

	Examples are given in the test map.

    ===========================================================================================
    API
    ===========================================================================================
 
    CreateBetterDialogForPlayer(whichPlayer, dialogTitle, buttonData)
    CreateBetterDialogForForce(whichForce, dialogTitle, buttonData)
    CreateBetterDialogForAll(dialogTitle, buttonData)

	CloseDialog(whichDialog)
	CloseOpenDialogForPlayer(whichPlayer)
	GetOpenDialogOfPlayer(whichPlayer)
	SaveAndHideOpenDialogForPlayer(whichPlayer)
	ShowDialogToPlayer(whichDialog, whichPlayer)

    ===========================================================================================
    ]]

	--===========================================================================================
	--CONFIG
	--===========================================================================================

    local DIALOG_X                          = 0.4		--X-position of dialog center.
    local DIALOG_Y                          = 0.3		--Y-position of dialog center.
    local DIALOG_WIDTH                      = 0.285		--Should be integer multiple of BackdropCornerSize
    local DIALOG_BOTTOM_GAP                 = 0.045		--Gap between bottom of lowest button and bottom of dialog.
	local DIALOG_BORDER_TILE_SIZE			= 0.0475	--Fixes height of dialog to integer multiple of this value to ensure that texture is tiled smoothly. (same behavior as normal dialog)

    local DIALOG_TITLE_Y_OFFSET             = -0.07		--Gap between top of dialog and dialog title.

    local BUTTON_HEIGHT                     = 0.035
    local BUTTON_WIDTH                      = 0.225
    local BUTTON_SPACING                    = 0.003		--Gap between buttons.
    local BUTTON_Y_OFFSET                   = -0.07		--Gap between top of dialog and first button.
    
    local TOOLTIP_Y_OFFSET                  = -0.005	--Difference in y-position of top edge of dialog and tooltip.
    local TOOLTIP_WIDTH                     = 0.244		--Should be integer multiple of BackdropCornerSize
    local TOOLTIP_FRAME_HEIGHT_BUFFER       = 0.045		--Difference in height between tooltip border and tooltip text box.
	local TOOLTIP_STYLE						= "EscMenu" --"EscMenu" or "Tooltip"

	--===========================================================================================

    local BUTTON_X_OFFSET                   = (DIALOG_WIDTH - BUTTON_WIDTH)/2

	local CurrentlyOpenDialog = {}
	local ButtonTriggers = {}
	local ViewingPlayer = {}

	local function PlayButtonClickForPlayer(whichPlayer)
		local s = CreateSound("Sound\\Interface\\BigButtonClick.flac", false, false, false, 10, 10, "DefaultEAXON" )
		local volume
		if GetLocalPlayer() == whichPlayer then
			volume = 100
		else
			volume = 0
		end
		SetSoundVolumeBJ(s, volume)
		StartSound(s)
		KillSoundWhenDone(s)
	end

	local function SetupDialog(whichPlayer, dialogTitle, buttonTitles, buttonTooltips, buttonCallbacks)

        local numberOfButtons = #buttonTitles

		--===========================================================================================
		--Setup Dialog Background
		--===========================================================================================

		local dialogHeightEstimate = -BUTTON_Y_OFFSET + DIALOG_BOTTOM_GAP + numberOfButtons*BUTTON_HEIGHT + (numberOfButtons-1)*BUTTON_SPACING

		local dialogHeight = math.floor(dialogHeightEstimate/DIALOG_BORDER_TILE_SIZE + 0.5)*DIALOG_BORDER_TILE_SIZE
		local heightDifference = dialogHeight - dialogHeightEstimate

        local dialogParent = BlzCreateFrame("BetterDialog", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0) ---@type framehandle
		BlzFrameSetScale(dialogParent, 1)
		BlzFrameSetAbsPoint(dialogParent, FRAMEPOINT_TOPLEFT , DIALOG_X - DIALOG_WIDTH/2 , DIALOG_Y + dialogHeight/2 )
		BlzFrameSetAbsPoint(dialogParent, FRAMEPOINT_BOTTOMRIGHT , DIALOG_X + DIALOG_WIDTH/2 , DIALOG_Y - dialogHeight/2 )
		BlzFrameSetVisible( dialogParent, true )

		--===========================================================================================
		--Setup Dialog Title
		--===========================================================================================

		local dialogTitleFrame = BlzCreateFrameByType("TEXT", "dialogTitle", dialogParent, "", 0) ---@type framehandle
		BlzFrameSetText(dialogTitleFrame, dialogTitle)
		BlzFrameSetScale(dialogTitleFrame, 1.6)
		BlzFrameSetPoint(dialogTitleFrame, FRAMEPOINT_TOPLEFT, dialogParent, FRAMEPOINT_TOPLEFT, 0, 0)
		BlzFrameSetPoint(dialogTitleFrame, FRAMEPOINT_BOTTOMRIGHT, dialogParent, FRAMEPOINT_TOPRIGHT, 0, DIALOG_TITLE_Y_OFFSET - heightDifference/2)
        BlzFrameSetTextAlignment(dialogTitleFrame, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)

		--===========================================================================================

        local tooltipText ---@type framehandle

        local buttonFrames = {}
        local buttonTriggers = {}
        local buttonTooltipFrames = {}

        for i = 1, numberOfButtons do

			--===========================================================================================
			--Setup Dialog Button
			--===========================================================================================

			local isCycleButton ---@type boolean
			local cycleButtonState ---@type integer

            if type(buttonTitles[i]) == "table" then
				buttonFrames[i] = BlzCreateFrameByType("GLUETEXTBUTTON", buttonTitles[i][1] , dialogParent, "ScriptDialogButton", 0)
                isCycleButton = true
                BlzFrameSetText(buttonFrames[i], buttonTitles[i][1])
				cycleButtonState = 1
			elseif type(buttonTitles[i]) == "string" then
				buttonFrames[i] = BlzCreateFrameByType("GLUETEXTBUTTON", buttonTitles[i] , dialogParent, "ScriptDialogButton", 0)
                isCycleButton = false
                BlzFrameSetText(buttonFrames[i], buttonTitles[i])
            end
            BlzFrameSetPoint( buttonFrames[i], FRAMEPOINT_TOPLEFT, dialogParent, FRAMEPOINT_TOPLEFT, BUTTON_X_OFFSET , BUTTON_Y_OFFSET - (i-1)*(BUTTON_HEIGHT + BUTTON_SPACING) - heightDifference/2 )
            BlzFrameSetPoint( buttonFrames[i], FRAMEPOINT_BOTTOMRIGHT, dialogParent, FRAMEPOINT_TOPLEFT, BUTTON_X_OFFSET + BUTTON_WIDTH , BUTTON_Y_OFFSET - BUTTON_HEIGHT - (i-1)*(BUTTON_HEIGHT + BUTTON_SPACING) - heightDifference/2 )

			--===========================================================================================
			--Setup Button Tooltip
			--===========================================================================================

			if buttonTooltips[i] ~= "" then
				buttonTooltipFrames[i] = BlzCreateFrame("BetterDialogTooltip" .. TOOLTIP_STYLE, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), 0, 0)
				BlzFrameSetAbsPoint( buttonTooltipFrames[i] , FRAMEPOINT_TOPLEFT , DIALOG_X + DIALOG_WIDTH/2 , DIALOG_Y + dialogHeight/2 + TOOLTIP_Y_OFFSET )
				BlzFrameSetTooltip( buttonFrames[i] , buttonTooltipFrames[i] )
				tooltipText = BlzFrameGetChild(buttonTooltipFrames[i], 0)
				
				if type(buttonTooltips[i]) == "table" then
					BlzFrameSetText( tooltipText, buttonTooltips[i][1] )
				else
					BlzFrameSetText( tooltipText, buttonTooltips[i] )
				end
				BlzFrameSetSize( tooltipText , TOOLTIP_WIDTH - 0.045 , 0.0 )
				BlzFrameSetSize(buttonTooltipFrames[i] , TOOLTIP_WIDTH , BlzFrameGetHeight(tooltipText) + TOOLTIP_FRAME_HEIGHT_BUFFER)
			end

			--===========================================================================================
			--Setup Callback Function
			--===========================================================================================

			buttonTriggers[i] = CreateTrigger()
			BlzTriggerRegisterFrameEvent(buttonTriggers[i], buttonFrames[i], FRAMEEVENT_CONTROL_CLICK)
			TriggerAddAction(buttonTriggers[i], function()
				PlayButtonClickForPlayer(whichPlayer)
				if isCycleButton then
					cycleButtonState = ModuloInteger(cycleButtonState, #buttonTitles[i]) + 1
					BlzFrameSetText(buttonFrames[i], buttonTitles[i][cycleButtonState])
					if type(buttonTooltips[i]) == "table" then
						tooltipText = BlzFrameGetChild(buttonTooltipFrames[i], 0)
						BlzFrameSetText( tooltipText, buttonTooltips[i][cycleButtonState] )
						BlzFrameSetSize( tooltipText , TOOLTIP_WIDTH - 0.045 , 0.0 )
						BlzFrameSetSize(buttonTooltipFrames[i] , TOOLTIP_WIDTH , BlzFrameGetHeight(tooltipText) + TOOLTIP_FRAME_HEIGHT_BUFFER)
					end
					buttonCallbacks[i](dialogParent, buttonTitles[i][cycleButtonState], GetTriggerPlayer())
				else
					buttonCallbacks[i](dialogParent, buttonTitles[i], GetTriggerPlayer())
				end
			end)
        end

		--===========================================================================================

		ButtonTriggers[dialogParent] = buttonTriggers
		CurrentlyOpenDialog[whichPlayer] = dialogParent
		ViewingPlayer[dialogParent] = whichPlayer

        BlzFrameSetVisible(dialogParent, GetLocalPlayer() == whichPlayer)
	end

	local function SetupButtons(buttonData)
        local buttonTitles = {}
        local buttonTooltips = {}
        local buttonCallbacks = {}
		local j = 1
        for i = 1, #buttonData - 2, 3 do
			if type(buttonData[i]) == "string" or type(buttonData[i]) == "table" then
            	buttonTitles[j] = buttonData[i]
			else
				print(type(buttonData[i]) .. " passed as argument for button title. Expected string or table...")
				return
			end
			if type(buttonData[i+1]) == "string" or type(buttonData[i+1]) == "table" then
            	buttonTooltips[j] = buttonData[i+1]
			else
				print(type(buttonData[i+1]) .. " passed as argument for button tooltip. Expected string or table...")
				return
			end
			if type(buttonData[i+2]) == "function" then
            	buttonCallbacks[j] = buttonData[i+2]
			else
				print(type(buttonData[i+2]) .. " passed as argument for button callback. Expected function...")
				return
			end
            j = j + 1
        end
		return buttonTitles, buttonTooltips, buttonCallbacks
	end

	--===========================================================================================
	--API
	--===========================================================================================

	---@param dialogTitle string
	---@param buttonData table
    function CreateBetterDialogForAll(dialogTitle, buttonData)
		local buttonTitles, buttonTooltips, buttonCallbacks = SetupButtons(buttonData)
		for i = 0, 23 do
			if GetPlayerSlotState(Player(i)) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(Player(i)) == MAP_CONTROL_USER then
				CloseDialog(CurrentlyOpenDialog[Player(i)])
				SetupDialog(Player(i), dialogTitle, buttonTitles, buttonTooltips, buttonCallbacks)
			end
		end
    end

	---@param whichForce table | force
	---@param dialogTitle string
	---@param buttonData table
    function CreateBetterDialogForForce(whichForce, dialogTitle, buttonData)
		local buttonTitles, buttonTooltips, buttonCallbacks = SetupButtons(buttonData)
		if type(whichForce) == "table" then
			for i = 1, #whichForce do
				SetupDialog(whichForce[i], dialogTitle, buttonTitles, buttonTooltips, buttonCallbacks)
			end
		else
			for i = 0, 23 do
				if IsPlayerInForce(Player(i), whichForce) then
					CloseDialog(CurrentlyOpenDialog[Player(i)])
					SetupDialog(Player(i), dialogTitle, buttonTitles, buttonTooltips, buttonCallbacks)
				end
			end
		end
    end

	---@param whichPlayer player
	---@param dialogTitle string
	---@param buttonData table
	---@return framehandle
    function CreateBetterDialogForPlayer(whichPlayer, dialogTitle, buttonData)
		local buttonTitles, buttonTooltips, buttonCallbacks = SetupButtons(buttonData)
		CloseDialog(CurrentlyOpenDialog[whichPlayer])
        SetupDialog(whichPlayer, dialogTitle, buttonTitles, buttonTooltips, buttonCallbacks)
		return CurrentlyOpenDialog[whichPlayer]
    end

	---@param whichDialog framehandle
	function CloseDialog(whichDialog)
		if whichDialog == nil then
			return
		end

		for j = 1, #ButtonTriggers[whichDialog] do
			DestroyTrigger(ButtonTriggers[whichDialog][j])
		end
		BlzFrameSetVisible(whichDialog, false)
		CurrentlyOpenDialog[ViewingPlayer[whichDialog]] = nil
	end

	---@param whichPlayer player
	function CloseOpenDialogForPlayer(whichPlayer)
		CloseDialog(CurrentlyOpenDialog[whichPlayer])
	end

	---@param whichPlayer player
	---@return framehandle
	function GetOpenDialogOfPlayer(whichPlayer)
		return CurrentlyOpenDialog[whichPlayer]
	end

	---@param whichPlayer player
	---@return framehandle
	function SaveAndHideOpenDialogForPlayer(whichPlayer)
		local whichDialog = CurrentlyOpenDialog[whichPlayer]
		if GetLocalPlayer() == whichPlayer then
			BlzFrameSetVisible(whichDialog, false)
		end
		CurrentlyOpenDialog[whichPlayer] = nil
		return whichDialog
	end

	---@param whichDialog framehandle
	---@param whichPlayer player
	function ShowDialogToPlayer(whichDialog, whichPlayer)
		CloseOpenDialogForPlayer(whichPlayer)
		if GetLocalPlayer() == whichPlayer then
			BlzFrameSetVisible(whichDialog, true)
		end
		CurrentlyOpenDialog[whichPlayer] = whichDialog
	end

	OnInit.main(function()
		BlzLoadTOCFile("BetterDialogTemplates.toc")
	end)

	--===========================================================================================
end