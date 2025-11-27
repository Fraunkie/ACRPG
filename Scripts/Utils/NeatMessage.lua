if Debug then Debug.beginFile "NeatTextMessages" end
do
    --[[
    ===========================================================================================
                                        Neat Text Messages
                                            by Antares
   
                Recreation of the default text messages with more customizability.
           
                                            How to import:
    Copy this library into your map. To get better looking messages with text shadow and an optional
    tooltip-like box around the text, copy the "NeatTextMessage.fdf" and "NeatMessageTemplates.toc" 
	files from the test map into your map without a subpath.
   
    Edit the parameters in the config section to your liking.
   
    Replace all DisplayTextToForce calls etc. with the appropriate function from this library.
	
	GUI users: You can use the REPLACE_BLIZZARD_FUNCTION_CALLS feature. This will replace all calls
    automatically. You don't need to do anything else. This feature requires the Hook library. The
	text messages created by the replacement will use the default window and format.
   
    WARNING: Calling neat message functions (but not clear functions) from within local player code
    with REPLACE_BLIZZARD_FUNCTION_CALLS will cause a desync!
   
    Default text formatting can be overwritten by setting up NeatFormats. Examples are given in the
    test section. All formatting parameters that aren't set for a NeatFormat will use the default
    values instead.
   
    NeatMessage creator functions return an integer. This integer is a pointer to the created message
    that can be used to edit, extend, or remove the message. The returned integer is asynchronous
    and will be 0 for all players for whom the message isn't displayed.
   
    You can set up additional text windows with NeatWindow.create. If you create a neat message
    without specifying the window in which it should be created, it will always be created in the
    default window specified in the config.

    ===========================================================================================
    API
    ===========================================================================================
   
    NeatMessage(whichMessage)
    NeatMessageToPlayer(whichPlayer, whichMessage)
    NeatMessageToForce(whichForce, whichMessage)
   
    NeatMessageTimed(duration, whichMessage)
    NeatMessageToPlayerTimed(whichPlayer, duration, whichMessage)
    NeatMessageToForceTimed(whichForce, duration, whichMessage)
   
    NeatMessageFormatted(whichMessage, whichFormat)
    NeatMessageToPlayerFormatted(whichPlayer, whichMessage, whichFormat)
    NeatMessageToForceFormatted(whichForce, whichMessage, whichFormat)
   
    NeatMessageTimedFormatted(duration, whichMessage, whichFormat)
    NeatMessageToPlayerTimedFormatted(whichPlayer, duration, whichMessage, whichFormat)
    NeatMessageToForceTimedFormatted(whichForce, duration, whichMessage, whichFormat)
   
    NeatMessageInWindow(whichMessage, whichWindow)
    NeatMessageToPlayerInWindow(whichPlayer, whichMessage, whichWindow)
    NeatMessageToForceInWindow(whichForce, whichMessage, whichWindow)
   
    NeatMessageTimedInWindow(duration, whichMessage, whichWindow)
    NeatMessageToPlayerTimedInWindow(whichPlayer, duration, whichMessage, whichWindow)
    NeatMessageToForceTimedInWindow(whichForce, duration, whichMessage, whichWindow)
   
    NeatMessageFormattedInWindow(whichMessage, whichFormat, whichWindow)
    NeatMessageToPlayerFormattedInWindow(whichPlayer, whichMessage, whichFormat, whichWindow)
    NeatMessageToForceFormattedInWindow(whichForce, whichMessage, whichFormat, whichWindow)
   
    NeatMessageTimedFormattedInWindow(duration, whichMessage, whichFormat, whichWindow)
    NeatMessageToPlayerTimedFormattedInWindow(whichPlayer, duration, whichMessage, whichFormat, whichWindow)
    NeatMessageToForceTimedFormattedInWindow(whichForce, duration, whichMessage, whichFormat, whichWindow)
   
    ===========================================================================================
   
    EditNeatMessage(messagePointer, newText)
    AddNeatMessageTimeRemaining(messagePointer, additionalTime)
    SetNeatMessageTimeRemaining(messagePointer, newTime)
    RemoveNeatMessage(messagePointer)
    AutoSetNeatMessageTimeRemaining(messagePointer, accountForTimeElapsed)
    IsMessageDisplayed(messagePointer)
   
    NeatMessageAddIcon(messagePointer, width, height, orientation, texture)
        (valid arguments for orientation are "topleft", "topright", "bottomleft", "bottomright")
    NeatMessageHideIcon(messagePointer)
   
    ClearNeatMessages()
    ClearNeatMessagesForPlayer(whichPlayer)
    ClearNeatMessagesForForce(whichForce)
    ClearNeatMessagesInWindow(whichWindow)
    ClearNeatMessagesForPlayerInWindow(whichPlayer, whichWindow)
    ClearNeatMessagesForForceInWindow(whichForce, whichWindow)
   
    set myFormat = NeatFormat.create()
    set myFormat.spacing =
    set myFormat.fadeOutTime =
    set myFormat.fadeInTime =
    set myFormat.fontSize =
    set myFormat.minDuration =
    set myFormat.durationIncrease =
    set myFormat.verticalAlignment =
    set myFormat.horizontalAlignment =
    set myFormat.isBoxed =
    call myFormat:copy(copiedFormat)
   
    set myWindow = NeatWindow.create(xPosition, yPosition, width, height, maxMessages, topToBottom)

    ===========================================================================================
    ]]



    --=========================================================================================
    --Config
    --=========================================================================================

    --Default text formatting. Can be overwritten by setting up neatFormats.
    local MESSAGE_MINIMUM_DURATION                       = 2.5                      ---@type number --Display duration of a message with zero characters.
    local MESSAGE_DURATION_INCREASE_PER_CHARACTER        = 0.12                     ---@type number
    local TEXT_MESSAGE_FONT_SIZE                         = 14                       ---@type number
    local SPACING_BETWEEN_MESSAGES                       = 0.0                      ---@type number
    local FADE_IN_TIME                                   = 0.0                      ---@type number
    local FADE_OUT_TIME                                  = 1.8                      ---@type number
    local VERTICAL_ALIGNMENT                             = TEXT_JUSTIFY_MIDDLE      ---@type textaligntype --TEXT_JUSTIFY_BOTTOM, TEXT_JUSTIFY_MIDDLE, or TEXT_JUSTIFY_TOP
    local HORIZONTAL_ALIGNMENT                           = TEXT_JUSTIFY_CENTER      ---@type textaligntype --TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_CENTER, or TEXT_JUSTIFY_RIGHT
    local BOXED_MESSAGES                                 = false                     ---@type boolean --Create tooltip box around text messages? Requires .fdf file and INCLUDE_FDF enabled.

    --Default text window parameters.
    TEXT_MESSAGE_X_POSITION                              = 0.125                    ---@type number --0 = left, 0.8 = right (bottom-left corner)
    TEXT_MESSAGE_Y_POSITION                              = 0.3                     ---@type number --0 = bottom, 0.6 = top (bottom-left corner)
    TEXT_MESSAGE_BLOCK_MAX_HEIGHT                        = 0.2                      ---@type number --Maximum height of the entire text message block. Messages pushed out of that area will be removed.
    TEXT_MESSAGE_BLOCK_WIDTH                             = 0.45                     ---@type number 
    MAX_TEXT_MESSAGES                                    = 5                        ---@type integer --Maximum number of messages on the screen at the same time. If you want a non-scrolling window, simply set this number to 1.
    MESSAGE_ORDER_TOP_TO_BOTTOM                          = false                    ---@type boolean --Set true if new messages should appear above old messages.

    --Config
    local INCLUDE_FDF                                    = true                     ---@type boolean --NeatMessage.fdf has been imported?
    local COPY_TO_MESSAGE_LOG                            = false                     ---@type boolean --(Only singleplayer) Copies messages to message log by printing out the message with DisplayTextToPlayer, then clearing all text. Will interfere with other default text messages.
    local REPLACE_BLIZZARD_FUNCTION_CALLS                = true                     ---@type boolean --Replaces Display(Timed)TextToForce, ClearTextMessages, and ClearTextMessagesBJ.
    local TOOLTIP_ABILITY                                = 'Amls'                   ---@type string --For REPLACE_BLIZZARD_FUNCTION_CALLS only. Any unused ability for which the library can change the tooltip to extract the TRIGSTR from.

    --=========================================================================================

    local isSinglePlayer                                 = nil                      ---@type boolean
    local masterTimer                                    = nil                      ---@type timer
    local numMessagesOnScreen                            = 0                        ---@type integer
    local messageCounter                                 = 0                        ---@type integer
    local frameOfMessage                                 = {}                       ---@type integer[]
    local windowOfMessage                                = {}                       ---@type NeatWindow[]
    local clearTextTimer                                 = nil                      ---@type timer
    local doNotClear                                     = false                    ---@type boolean

    local TIME_STEP                                      = 0.05                     ---@type number 

    DEFAULT_NEAT_FORMAT                                  = nil                      ---@type NeatFormat 
    DEFAULT_NEAT_WINDOW                                  = nil                      ---@type NeatWindow
    local neatWindow                                     = {}                       ---@type NeatWindow[] 
    local numNeatWindows                                 = 0                        ---@type integer

    local ChangeTextFormatting                           = nil                      ---@type function
    local ChangeText                                     = nil                      ---@type function

    ---@class NeatFormat
    NeatFormat = {
        spacing = SPACING_BETWEEN_MESSAGES,                         ---@type number
        fadeOutTime = FADE_OUT_TIME,                                 ---@type number
        fadeInTime = FADE_IN_TIME,                                  ---@type number
        fontSize = TEXT_MESSAGE_FONT_SIZE,                          ---@type number
        minDuration = MESSAGE_MINIMUM_DURATION,                     ---@type number
        durationIncrease = MESSAGE_DURATION_INCREASE_PER_CHARACTER, ---@type number
        verticalAlignment = VERTICAL_ALIGNMENT,                     ---@type textaligntype
        horizontalAlignment = HORIZONTAL_ALIGNMENT,                 ---@type textaligntype
        isBoxed = BOXED_MESSAGES                                    ---@type boolean
    }

    local NeatFormatMt = {__index = NeatFormat}

    ---@return NeatFormat
    function NeatFormat.create()
        local new = {}
        setmetatable(new, NeatFormatMt)
        return new
    end

    ---@param copiedFormat NeatFormat
    function NeatFormat:copy(copiedFormat)
        self.spacing = copiedFormat.spacing
        self.fadeOutTime = copiedFormat.fadeOutTime
        self.fadeInTime = copiedFormat.fadeInTime
        self.fontSize = copiedFormat.fontSize
        self.minDuration = copiedFormat.minDuration
        self.durationIncrease = copiedFormat.durationIncrease
        self.verticalAlignment = copiedFormat.verticalAlignment
        self.horizontalAlignment = copiedFormat.horizontalAlignment
        self.isBoxed = copiedFormat.isBoxed
    end

    ---@class NeatWindow
    NeatWindow = {
        xPosition = nil,
        yPosition = nil,
        maxHeight = nil,
        width = nil,
        maxTextMessages = nil,
        isTopToBottom = nil,

        textMessageFrame = nil,
        textMessageText = nil,
        textMessageBox = nil,
        textCarryingFrame = nil,
        textMessageIcon = nil,
        messageFormat = nil,
        messageTimeRemaining = nil,
        messageTimeElapsed = nil,
        textHeight = nil,
        textMessageIconOrientation = nil,
        messageOfFrame = 0,
    }

    local neatWindowMt = {__index = NeatWindow}

    ---@param xPosition number
    ---@param yPosition number
    ---@param width number
    ---@param maxHeight number
    ---@param maxTextMessages integer
    ---@param isTopToBottom boolean
    ---@return NeatWindow
    function NeatWindow.create(xPosition, yPosition, width, maxHeight, maxTextMessages, isTopToBottom)
        local new = {}
        setmetatable(new, neatWindowMt)

        new.xPosition = xPosition
        new.yPosition = yPosition
        new.maxHeight = maxHeight
        new.width = width
        new.maxTextMessages = maxTextMessages
        new.isTopToBottom = isTopToBottom
        if isTopToBottom then
            new.yPosition = new.yPosition + maxHeight
        end

        numNeatWindows = numNeatWindows + 1
        neatWindow[numNeatWindows] = new

        new.textMessageFrame = {}
        new.textMessageText = {}
        new.textMessageBox = {}
        new.textCarryingFrame = {}
        new.textMessageIcon = {}
        new.messageFormat = {}
        new.textMessageIconOrientation = {}
        new.textHeight = {}
        new.messageTimeRemaining = {}
        new.messageTimeElapsed = {}
        new.messageOfFrame = {}

        local parent = TasFullScreenParent or BlzGetFrameByName("ConsoleUIBackdrop", 0)

        for i = 1, maxTextMessages do
            if INCLUDE_FDF then
                new.textMessageFrame[i] = BlzCreateFrame("TextMessage", parent, 0, 0)
                new.textMessageText[i] = BlzGetFrameByName("TextMessageValue", 0)
                new.textMessageBox[i] = BlzGetFrameByName("TextMessageBox", 0)
                BlzFrameSetSize(new.textMessageText[i], width, 0)
                BlzFrameSetScale(new.textMessageText[i], TEXT_MESSAGE_FONT_SIZE/10.)
                BlzFrameSetAbsPoint(new.textMessageFrame[i], FRAMEPOINT_BOTTOMLEFT, xPosition, yPosition)
                BlzFrameSetTextAlignment(new.textMessageText[i] , VERTICAL_ALIGNMENT , HORIZONTAL_ALIGNMENT)
                BlzFrameSetVisible( new.textMessageFrame[i] , false )
                BlzFrameSetEnable(new.textMessageFrame[i],false)
                BlzFrameSetEnable(new.textMessageText[i],false)
                BlzFrameSetLevel(new.textMessageText[i],1)
                BlzFrameSetLevel(new.textMessageBox[i],0)
                new.textCarryingFrame[i] = new.textMessageText[i]
                new.textMessageIcon[i] = BlzCreateFrameByType("BACKDROP", "textMessageIcon" .. i , parent, "", 0)
                BlzFrameSetEnable(new.textMessageIcon[i],false)
                BlzFrameSetVisible(new.textMessageIcon[i],false)
                new.messageFormat[i] = DEFAULT_NEAT_FORMAT
                new.messageOfFrame[i] = 0
                new.textHeight[i] = 0
                new.messageTimeRemaining[i] = 0
                new.messageTimeElapsed[i] = 0
                new.messageOfFrame[i] = 0
                ChangeTextFormatting(new, i, DEFAULT_NEAT_FORMAT)
                ChangeText(new, i, "")
            else
                new.textMessageFrame[i] = BlzCreateFrameByType("TEXT", "textMessageFrame" , parent, "", 0)
                BlzFrameSetScale(new.textMessageFrame[i], TEXT_MESSAGE_FONT_SIZE/10.)
                BlzFrameSetTextAlignment(new.textMessageFrame[i] , VERTICAL_ALIGNMENT , HORIZONTAL_ALIGNMENT)
                BlzFrameSetAbsPoint(new.textMessageFrame[i], FRAMEPOINT_BOTTOMLEFT, xPosition, yPosition)
                BlzFrameSetVisible( new.textMessageFrame[i] , false )
                BlzFrameSetEnable(new.textMessageFrame[i],false)
                new.textCarryingFrame[i] = new.textMessageFrame[i]
                new.textMessageIcon[i] = BlzCreateFrameByType("BACKDROP", "textMessageIcon" .. i , parent, "", 0)
                BlzFrameSetEnable(new.textMessageIcon[i],false)
                BlzFrameSetVisible(new.textMessageIcon[i],false)
                new.messageFormat[i] = DEFAULT_NEAT_FORMAT
                new.messageOfFrame[i] = 0
                new.textHeight[i] = 0
                new.messageTimeRemaining[i] = 0
                new.messageTimeElapsed[i] = 0
                new.messageOfFrame[i] = 0
                ChangeTextFormatting(new, i, DEFAULT_NEAT_FORMAT)
                ChangeText(new, i, "")
            end
        end

        return new
    end

--=========================================================================================

    function ClearText()
        doNotClear = true
        ClearTextMessages()
        doNotClear = false
    end

    ---@param whichString string
    ---@return integer
    local function GetAdjustedStringLength(whichString)
        local rawLength = string.len(whichString) ---@type integer
        local adjustedLength = rawLength ---@type integer
        local j = 1 ---@type integer
        local secondCharacter ---@type string
        while j <= rawLength - 10 do
            if string.sub(whichString, j, j) == "|" then
                secondCharacter = string.lower(string.sub(whichString, j+1, j+1))
                if secondCharacter == "c" then
                    adjustedLength = adjustedLength - 10
                    j = j + 10
                elseif secondCharacter == "r" then
                    adjustedLength = adjustedLength - 2
                    j = j + 2
                end
            else
                j = j + 1
            end
        end
        return adjustedLength
    end

    ---@param w NeatWindow
    ---@param whichFrame integer
    ---@param whichFormat NeatFormat
    ChangeTextFormatting = function(w, whichFrame, whichFormat)
        if whichFormat == 0 then
            return
        end
        w.messageFormat[whichFrame] = whichFormat
        BlzFrameSetScale(w.textCarryingFrame[whichFrame], whichFormat.fontSize/10.)
        BlzFrameSetTextAlignment( w.textCarryingFrame[whichFrame], whichFormat.verticalAlignment, whichFormat.horizontalAlignment )
    end

    ---@param w NeatWindow
    ---@param whichFrame integer
    ---@param whichText string
    ChangeText = function(w, whichFrame, whichText)
        BlzFrameSetText( w.textCarryingFrame[whichFrame] , whichText )
        if w.maxTextMessages == 1 then
            BlzFrameSetSize( w.textCarryingFrame[whichFrame] , w.width / (w.messageFormat[whichFrame].fontSize/10.) , w.maxHeight / (w.messageFormat[whichFrame].fontSize/10.) )
        else
            BlzFrameSetSize( w.textCarryingFrame[whichFrame] , w.width / (w.messageFormat[whichFrame].fontSize/10.) , 0 )
        end

        if INCLUDE_FDF then
            BlzFrameSetSize( w.textMessageFrame[whichFrame] , BlzFrameGetWidth(w.textMessageText[whichFrame]) + 0.008 , BlzFrameGetHeight(w.textMessageText[whichFrame]) + 0.009 )
            BlzFrameSetPoint( w.textMessageBox[whichFrame] , FRAMEPOINT_BOTTOMLEFT , w.textMessageFrame[whichFrame] , FRAMEPOINT_BOTTOMLEFT , 0 , -0.0007*(w.messageFormat[whichFrame].fontSize-13) )
            BlzFrameSetPoint( w.textMessageBox[whichFrame] , FRAMEPOINT_TOPRIGHT , w.textMessageFrame[whichFrame] , FRAMEPOINT_TOPRIGHT , 0 , 0 )
        end

        if whichText == "" then
            BlzFrameSetVisible( w.textMessageFrame[whichFrame] , false )
            BlzFrameSetAlpha( w.textMessageFrame[whichFrame] , 255 )
        else
            BlzFrameSetVisible( w.textMessageFrame[whichFrame] , true )
        end
    end

    ---@param w NeatWindow
    ---@param whichFrame integer
    ---@param collapseFrame boolean
    local function HideTextMessage(w, whichFrame, collapseFrame)
        if BlzFrameGetText(w.textCarryingFrame[whichFrame]) ~= "" then
            numMessagesOnScreen = numMessagesOnScreen - 1
        end

        ChangeText(w,whichFrame,"")
        w.messageTimeRemaining[whichFrame] = 0
        frameOfMessage[w.messageOfFrame[whichFrame]] = nil
        w.messageOfFrame[whichFrame] = 0
        if collapseFrame then
            w.textHeight[whichFrame] = 0
        end
        if w.textMessageIconOrientation[whichFrame] ~= nil then
            BlzFrameSetVisible( w.textMessageIcon[whichFrame] , false )
            BlzFrameSetAlpha( w.textMessageIcon[whichFrame] , 255 )
        end
    end

    local function FadeoutLoop()
        local w ---@type NeatWindow

        if numMessagesOnScreen == 0 then
            return
        end

        for j = 1, numNeatWindows do
            w = neatWindow[j]
            for i = 1, w.maxTextMessages do
                if w.messageTimeRemaining[i] > 0 then
                    w.messageTimeRemaining[i] = w.messageTimeRemaining[i] - TIME_STEP
                    w.messageTimeElapsed[i] = w.messageTimeElapsed[i] + TIME_STEP
                    if w.messageTimeRemaining[i] < w.messageFormat[i].fadeOutTime then
                        if w.messageTimeRemaining[i] < 0 then
                            HideTextMessage(w,i,false)
                        else
                            BlzFrameSetAlpha( w.textMessageFrame[i] , math.floor(255*w.messageTimeRemaining[i]/w.messageFormat[i].fadeOutTime) )
                        end
                    elseif w.messageTimeElapsed[i] < w.messageFormat[i].fadeInTime then
                        BlzFrameSetAlpha( w.textMessageFrame[i] , math.floor(255*w.messageTimeElapsed[i]/w.messageFormat[i].fadeInTime) )
                    end
                    if w.textMessageIconOrientation[i] ~= nil then
                        BlzFrameSetAlpha( w.textMessageIcon[i] , BlzFrameGetAlpha(w.textMessageFrame[i]) )
                    end
                end
            end
        end
    end

    ---@param w NeatWindow
    local function RepositionAllMessages(w)
        local yOffset = {}
        --=========================================================================================
        --Get message heights
        --=========================================================================================

        yOffset[1] = 0
        for i = 2, w.maxTextMessages do
            yOffset[i] = yOffset[i-1] + w.textHeight[i-1]
        end

        --=========================================================================================
        --Reposition messages
        --=========================================================================================

        for i = 1, w.maxTextMessages do
            if yOffset[i] + w.textHeight[i] > w.maxHeight then
                HideTextMessage(w,i,true)
            elseif w.isTopToBottom then
                BlzFrameSetAbsPoint( w.textMessageFrame[i] , FRAMEPOINT_BOTTOMLEFT , w.xPosition , w.yPosition - w.textHeight[i] - yOffset[i] )
            else
                BlzFrameSetAbsPoint( w.textMessageFrame[i] , FRAMEPOINT_BOTTOMLEFT , w.xPosition , w.yPosition + yOffset[i] )
            end
        end
    end

    ---@param whichText string
    ---@param forcedDuration number
    ---@param whichFormat NeatFormat
    ---@param w NeatWindow
    ---@return integer
    local function AddTextMessage(whichText, forcedDuration, whichFormat, w)
        local tempFrame ---@type framehandle

        if whichText == "" then
            return 0
        end

        if COPY_TO_MESSAGE_LOG and isSinglePlayer then
            DisplayTextToPlayer( GetLocalPlayer() , 0 , 0 , whichText .. [[
            ]] )
            ClearTextMessages()
        end

        if BlzFrameGetText(w.textCarryingFrame[w.maxTextMessages]) == "" then
            numMessagesOnScreen = numMessagesOnScreen + 1
        end

        --=========================================================================================
        --Transfer messages to next frame
        --=========================================================================================

        tempFrame = w.textMessageIcon[w.maxTextMessages]

        for i = w.maxTextMessages - 1, 1, -1 do
            w.messageTimeRemaining[i+1] = w.messageTimeRemaining[i]
            w.messageTimeElapsed[i+1] = w.messageTimeElapsed[i]
            ChangeTextFormatting(w, i+1, w.messageFormat[i])
            ChangeText(w, i+1, BlzFrameGetText(w.textCarryingFrame[i]))
            if w.messageOfFrame[i] ~= 0 then
                w.messageOfFrame[i+1] = w.messageOfFrame[i]
                frameOfMessage[w.messageOfFrame[i+1]] = i + 1
            end
            if w.messageTimeRemaining[i+1] < w.messageFormat[i+1].fadeOutTime then
                BlzFrameSetAlpha( w.textMessageFrame[i+1] , math.floor(255*w.messageTimeRemaining[i+1]/w.messageFormat[i+1].fadeOutTime) )
            else
                BlzFrameSetAlpha( w.textMessageFrame[i+1] , 255 )
            end
            BlzFrameSetVisible( w.textMessageFrame[i+1] , true )
            if INCLUDE_FDF then
                BlzFrameSetVisible( w.textMessageBox[i+1] , BlzFrameIsVisible(w.textMessageBox[i]) )
            end
            w.textHeight[i+1] = w.textHeight[i]

            w.textMessageIcon[i+1] = w.textMessageIcon[i]
            w.textMessageIconOrientation[i+1] = w.textMessageIconOrientation[i]

            if w.textMessageIconOrientation[i] ~= nil then
                if w.textMessageIconOrientation[i+1] == "topleft" then
                    BlzFrameSetPoint( w.textMessageIcon[i+1] , FRAMEPOINT_TOPRIGHT , w.textMessageFrame[i+1] , FRAMEPOINT_TOPLEFT , 0 , 0 )
                elseif w.textMessageIconOrientation[i+1] == "topright" then
                    BlzFrameSetPoint( w.textMessageIcon[i+1] , FRAMEPOINT_TOPLEFT , w.textMessageFrame[i+1] , FRAMEPOINT_TOPRIGHT , 0 , 0 )
                elseif w.textMessageIconOrientation[i+1] == "bottomleft" then
                    BlzFrameSetPoint( w.textMessageIcon[i+1] , FRAMEPOINT_BOTTOMRIGHT , w.textMessageFrame[i+1] , FRAMEPOINT_BOTTOMLEFT , 0 , 0 )
                elseif w.textMessageIconOrientation[i+1] == "bottomright" then
                    BlzFrameSetPoint( w.textMessageIcon[i+1] , FRAMEPOINT_BOTTOMLEFT , w.textMessageFrame[i+1] , FRAMEPOINT_BOTTOMRIGHT , 0 , 0 )
                end
            end
        end

        w.textMessageIcon[1] = tempFrame

        --=========================================================================================
        --Setup new message
        --=========================================================================================

        ChangeTextFormatting(w, 1, whichFormat)
        ChangeText(w, 1, whichText)
        w.textHeight[1] = BlzFrameGetHeight(w.textMessageFrame[1]) + math.max(whichFormat.spacing , w.messageFormat[1].spacing)
        if INCLUDE_FDF then
            BlzFrameSetVisible( w.textMessageBox[1], whichFormat.isBoxed )
        end

        if forcedDuration ~= 0 then
            w.messageTimeRemaining[1] = forcedDuration + whichFormat.fadeOutTime
        else
            w.messageTimeRemaining[1] = whichFormat.minDuration + whichFormat.durationIncrease*GetAdjustedStringLength(whichText) + whichFormat.fadeOutTime
        end
        w.messageTimeElapsed[1] = 0

        if whichFormat.fadeInTime > 0 then
            BlzFrameSetAlpha(w.textMessageFrame[1] , 0)
        else
            BlzFrameSetAlpha(w.textMessageFrame[1] , 255)
        end
        BlzFrameSetVisible( w.textMessageFrame[1] , true )

        w.textMessageIconOrientation[1] = nil

        messageCounter = messageCounter + 1

        w.messageOfFrame[1] = messageCounter
        frameOfMessage[messageCounter] = 1
        windowOfMessage[messageCounter] = w

        if w.maxTextMessages > 1 then
            RepositionAllMessages(w)
        end

        return messageCounter
    end

    local function Init()
        Require.optionally "TasFullScreenFrame"

        local p ---@type integer
        local numPlayers ---@type integer

        if INCLUDE_FDF then
            BlzLoadTOCFile("NeatMessageTemplates.toc")
        end

        masterTimer = CreateTimer()
        TimerStart( masterTimer , TIME_STEP , true , FadeoutLoop )

        DEFAULT_NEAT_FORMAT = NeatFormat.create()
        DEFAULT_NEAT_WINDOW = NeatWindow.create(TEXT_MESSAGE_X_POSITION, TEXT_MESSAGE_Y_POSITION, TEXT_MESSAGE_BLOCK_WIDTH, TEXT_MESSAGE_BLOCK_MAX_HEIGHT, MAX_TEXT_MESSAGES, MESSAGE_ORDER_TOP_TO_BOTTOM)

        if COPY_TO_MESSAGE_LOG then
            p = 0
            numPlayers = 1
            while p <= 23 do
                if GetPlayerSlotState(Player(p)) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(Player(p)) == MAP_CONTROL_USER then
                    numPlayers = numPlayers + 1
                end
                p = p + 1
            end

            isSinglePlayer = numPlayers == 1
        end

        if REPLACE_BLIZZARD_FUNCTION_CALLS then
            local hook = Require.optionally "Hook"
            if hook then
                clearTextTimer = CreateTimer()
                function Hook:DisplayTextToForce(whichForce, message)
                    local extractedString
                    BlzSetAbilityTooltip( FourCC(TOOLTIP_ABILITY), message, 0)
                    extractedString = BlzGetAbilityTooltip(FourCC(TOOLTIP_ABILITY), 0)
                    NeatMessageToForce(whichForce, extractedString)
                    TimerStart(clearTextTimer, 0.0, false, ClearText)
                end

                function Hook:DisplayTimedTextToForce(whichForce, duration, message)
                    local extractedString
                    BlzSetAbilityTooltip( FourCC(TOOLTIP_ABILITY), message, 0)
                    extractedString = BlzGetAbilityTooltip(FourCC(TOOLTIP_ABILITY), 0)
                    NeatMessageToForceTimed( whichForce , duration , extractedString )
                    TimerStart(clearTextTimer, 0.0, false, ClearText)
                end

                function Hook:ClearTextMessagesBJ(whichForce)
                    self.old(whichForce)
                    ClearNeatMessagesForForce(whichForce)
                end

                function Hook:ClearTextMessages()
                    self.old()
                    ClearNeatMessages()
                end
            else
                error("REPLACE_BLIZZARD_FUNCTION_CALLS requires Hook library.")
            end
        end
    end

    --===========================================================================================
    --API
    --===========================================================================================

    --Constructors
    --===========================================================================================

    ---@param message string
    ---@return integer
    function NeatMessage(message)
        return AddTextMessage(message, 0, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
    end

    ---@param whichPlayer player
    ---@param message string
    ---@return integer
    function NeatMessageToPlayer(whichPlayer, message)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message , 0, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param whichForce force
    ---@param message string
    ---@return integer
    function NeatMessageToForce(whichForce, message)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, 0, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param duration number
    ---@param message string
    ---@return integer
    function NeatMessageTimed(duration, message)
        return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
    end

    ---@param whichPlayer player
    ---@param duration number
    ---@param message string
    ---@return integer
    function NeatMessageToPlayerTimed(whichPlayer, duration, message)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param whichForce force
    ---@param duration number
    ---@param message string
    ---@return integer
    function NeatMessageToForceTimed(whichForce, duration, message)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageFormatted(message, whichFormat)
        return AddTextMessage(message, 0, whichFormat, DEFAULT_NEAT_WINDOW)
    end

    ---@param whichPlayer player
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageToPlayerFormatted(whichPlayer, message, whichFormat)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message , 0, whichFormat, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param whichForce force
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageToForceFormatted(whichForce, message, whichFormat)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, 0, whichFormat, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param whichPlayer player
    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageToPlayerTimedFormatted(whichPlayer, duration, message, whichFormat)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message, duration, whichFormat, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param whichForce force
    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageToForceTimedFormatted(whichForce, duration, message, whichFormat)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, duration, whichFormat, DEFAULT_NEAT_WINDOW)
        end
        return 0
    end

    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@return integer
    function NeatMessageTimedFormatted(duration, message, whichFormat)
        return AddTextMessage(message, duration, whichFormat, DEFAULT_NEAT_WINDOW)
    end

    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageInWindow(message, whichWindow)
        return AddTextMessage(message, 0, DEFAULT_NEAT_FORMAT, whichWindow)
    end

    ---@param whichPlayer player
    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToPlayerInWindow(whichPlayer, message, whichWindow)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message , 0, DEFAULT_NEAT_FORMAT, whichWindow)
        end
        return 0
    end

    ---@param whichForce force
    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToForceInWindow(whichForce, message, whichWindow)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, 0, DEFAULT_NEAT_FORMAT, whichWindow)
        end
        return 0
    end

    ---@param duration number
    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageTimedInWindow(duration, message, whichWindow)
        return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, whichWindow)
    end

    ---@param whichPlayer player
    ---@param duration number
    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToPlayerTimedInWindow(whichPlayer, duration, message, whichWindow)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, whichWindow)
        end
        return 0
    end

    ---@param whichForce force
    ---@param duration number
    ---@param message string
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToForceTimedInWindow(whichForce, duration, message, whichWindow)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, duration, DEFAULT_NEAT_FORMAT, whichWindow)
        end
        return 0
    end

    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageFormattedInWindow(message, whichFormat, whichWindow)
        return AddTextMessage(message, 0, whichFormat, whichWindow)
    end

    ---@param whichPlayer player
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToPlayerFormattedInWindow(whichPlayer, message, whichFormat, whichWindow)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message , 0, whichFormat, whichWindow)
        end
        return 0
    end

    ---@param whichForce force
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToForceFormattedInWindow(whichForce, message, whichFormat, whichWindow)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, 0, whichFormat, whichWindow)
        end
        return 0
    end

    ---@param whichPlayer player
    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToPlayerTimedFormattedInWindow(whichPlayer, duration, message, whichFormat, whichWindow)
        if GetLocalPlayer() == whichPlayer then
            return AddTextMessage(message, duration, whichFormat, whichWindow)
        end
        return 0
    end

    ---@param whichForce force
    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageToForceTimedFormattedInWindow(whichForce, duration, message, whichFormat, whichWindow)
        if IsPlayerInForce( GetLocalPlayer() , whichForce ) then
            return AddTextMessage(message, duration, whichFormat, whichWindow)
        end
        return 0
    end

    ---@param duration number
    ---@param message string
    ---@param whichFormat NeatFormat
    ---@param whichWindow NeatWindow
    ---@return integer
    function NeatMessageTimedFormattedInWindow(duration, message, whichFormat, whichWindow)
        return AddTextMessage(message, duration, whichFormat, whichWindow)
    end

    --Utility
    --===========================================================================================

    ---@param messagePointer integer
    ---@param newText string
    function EditNeatMessage(messagePointer, newText)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 

        if messagePointer == 0 or whichFrame == nil then
            return
        end

        ChangeText(whichWindow, whichFrame, newText)
        whichWindow.textHeight[whichFrame] = BlzFrameGetHeight(whichWindow.textMessageFrame[whichFrame]) + math.max(whichWindow.messageFormat[whichFrame].spacing , whichWindow.messageFormat[whichFrame+1].spacing)

        RepositionAllMessages(whichWindow)
    end

    ---@param messagePointer integer
    ---@param additionalTime number
    function AddNeatMessageTimeRemaining(messagePointer, additionalTime)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 

        if messagePointer == 0 or whichFrame == nil then
            return
        end

        whichWindow.messageTimeRemaining[whichFrame] = math.max(whichWindow.messageTimeRemaining[whichFrame] + additionalTime, whichWindow.messageFormat[whichFrame].fadeOutTime)
    end

    ---@param messagePointer integer
    ---@param newTime number
    function SetNeatMessageTimeRemaining(messagePointer, newTime)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 

        if messagePointer == 0 or whichFrame == nil then
            return
        end

        whichWindow.messageTimeRemaining[whichFrame] = math.max(newTime, whichWindow.messageFormat[whichFrame].fadeOutTime)
    end

    ---@param messagePointer integer
    ---@param accountForTimeElapsed boolean
    function AutoSetNeatMessageTimeRemaining(messagePointer, accountForTimeElapsed)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 
        local whichFormat = whichWindow.messageFormat[whichFrame] ---@type NeatFormat 

        if messagePointer == 0 or whichFrame == nil then
            return
        end

        whichWindow.messageTimeRemaining[whichFrame] = whichFormat.minDuration + whichFormat.durationIncrease*GetAdjustedStringLength(BlzFrameGetText(whichWindow.textCarryingFrame[whichFrame])) + whichFormat.fadeOutTime
        if accountForTimeElapsed then
            whichWindow.messageTimeRemaining[whichFrame] = math.max(whichWindow.messageTimeRemaining[whichFrame] - whichWindow.messageTimeElapsed[whichFrame], whichFormat.fadeOutTime)
        end
    end

    ---@param messagePointer integer
    function RemoveNeatMessage(messagePointer)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 

        if messagePointer == 0 or whichFrame == nil then
            return
        end

        whichWindow.messageTimeRemaining[whichFrame] = whichWindow.messageFormat[whichFrame].fadeOutTime
    end

    ---@param messagePointer integer
    ---@return boolean
    function IsNeatMessageDisplayed(messagePointer)
        return frameOfMessage[messagePointer] ~= nil
    end

    ---@param messagePointer integer
    ---@param width number
    ---@param height number
    ---@param orientation string
    ---@param texture string
    function NeatMessageAddIcon(messagePointer, width, height, orientation, texture)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer 
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow 

        BlzFrameSetVisible( whichWindow.textMessageIcon[whichFrame] , true )
        BlzFrameSetAlpha( whichWindow.textMessageIcon[whichFrame] , 255 )
        BlzFrameSetSize( whichWindow.textMessageIcon[whichFrame] , width , height )
        if orientation == "topleft" then
            BlzFrameSetPoint( whichWindow.textMessageIcon[whichFrame] , FRAMEPOINT_TOPRIGHT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_TOPLEFT , 0 , 0 )
        elseif orientation == "topright" then
            BlzFrameSetPoint( whichWindow.textMessageIcon[whichFrame] , FRAMEPOINT_TOPLEFT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_TOPRIGHT , 0 , 0 )
        elseif orientation == "bottomleft" then
            BlzFrameSetPoint( whichWindow.textMessageIcon[whichFrame] , FRAMEPOINT_BOTTOMRIGHT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_BOTTOMLEFT , 0 , 0 )
        elseif orientation == "bottomright" then
            BlzFrameSetPoint( whichWindow.textMessageIcon[whichFrame] , FRAMEPOINT_BOTTOMLEFT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_BOTTOMRIGHT , 0 , 0 )
        else
            print("Invalid icon orientation...")
            return
        end
        BlzFrameSetTexture( whichWindow.textMessageIcon[whichFrame] , texture , 0 , true )
        whichWindow.textMessageIconOrientation[whichFrame] = orientation

        if BlzFrameGetHeight( whichWindow.textMessageFrame[whichFrame] ) < height then
            BlzFrameSetSize( whichWindow.textCarryingFrame[whichFrame] , whichWindow.width / (whichWindow.messageFormat[whichFrame].fontSize/10.) , height - 0.018 )
            if INCLUDE_FDF then
                BlzFrameSetSize( whichWindow.textMessageFrame[whichFrame] , BlzFrameGetWidth(whichWindow.textMessageText[whichFrame]) + 0.008 , BlzFrameGetHeight(whichWindow.textMessageText[whichFrame]) + 0.009 )
                BlzFrameSetPoint( whichWindow.textMessageBox[whichFrame] , FRAMEPOINT_BOTTOMLEFT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_BOTTOMLEFT , 0 , -0.0007*(whichWindow.messageFormat[whichFrame].fontSize-13) )
                BlzFrameSetPoint( whichWindow.textMessageBox[whichFrame] , FRAMEPOINT_TOPRIGHT , whichWindow.textMessageFrame[whichFrame] , FRAMEPOINT_TOPRIGHT , 0 , 0 )
            end
            whichWindow.textHeight[whichFrame] = BlzFrameGetHeight(whichWindow.textMessageFrame[whichFrame]) + math.max(whichWindow.messageFormat[whichFrame].spacing , whichWindow.messageFormat[whichFrame+1].spacing)
            RepositionAllMessages(whichWindow)
        end
    end

    ---@param messagePointer integer
    function NeatMessageHideIcon(messagePointer)
        local whichFrame = frameOfMessage[messagePointer] ---@type integer
        local whichWindow = windowOfMessage[messagePointer] ---@type NeatWindow

        BlzFrameSetVisible( whichWindow.textMessageIcon[whichFrame] , false )
        whichWindow.textMessageIconOrientation[whichFrame] = nil
    end

    ---@param whichPlayer player
    function ClearNeatMessagesForPlayer(whichPlayer)
        if GetLocalPlayer() == whichPlayer then
            for j = 1, numNeatWindows do
                for i = 1, neatWindow[j].maxTextMessages do
                    HideTextMessage(neatWindow[j], i, true)
                end
            end
        end
    end

    function ClearNeatMessages()
        if doNotClear then
            return
        end
        for j = 1, numNeatWindows do
            for i = 1, neatWindow[j].maxTextMessages do
                HideTextMessage(neatWindow[j], i, true)
            end
        end
    end

    ---@param whichForce force
    function ClearNeatMessagesForForce(whichForce)
        if IsPlayerInForce(GetLocalPlayer() , whichForce) then
            for j = 1, numNeatWindows do
                for i = 1, neatWindow[j].maxTextMessages do
                    HideTextMessage(neatWindow[j], i, true)
                end
            end
        end
    end

    ---@param whichPlayer player
    ---@param whichWindow NeatWindow
    function ClearNeatMessagesForPlayerInWindow(whichPlayer, whichWindow)
        if GetLocalPlayer() == whichPlayer then
            for i = 1, whichWindow.maxTextMessages do
                HideTextMessage(whichWindow, i, true)
            end
        end
    end

    ---@param whichWindow NeatWindow
    function ClearNeatMessagesInWindow(whichWindow)
        for i = 1, whichWindow.maxTextMessages do
            HideTextMessage(whichWindow, i, true)
        end
    end

    ---@param whichForce force
    ---@param whichWindow NeatWindow
    function ClearNeatMessagesForForceInWindow(whichForce, whichWindow)
        if IsPlayerInForce(GetLocalPlayer() , whichForce) then
            for i = 1, whichWindow.maxTextMessages do
                HideTextMessage(whichWindow, i, true)
            end
        end
    end

    OnInit.final("NeatTextMessages", Init)
end