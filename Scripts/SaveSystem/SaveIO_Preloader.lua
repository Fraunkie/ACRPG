if Debug and Debug.beginFile then Debug.beginFile("SaveIO_Preloader.lua") end
--==================================================
-- SaveIO_Preloader.lua
-- Preload file read/write using ability tooltip chunks.
-- WC3-safe: payload MUST NOT contain backslash or double-quote.
-- Higher-level codec avoids those characters by design.
--==================================================

if not SaveIO then SaveIO = {} end
_G.SaveIO = SaveIO

do
    local ABIL = {
        FourCC('Amls'), FourCC('Aroc'), FourCC('Amic'), FourCC('Amil'), FourCC('Aclf'),
        FourCC('Acmg'), FourCC('Adef'), FourCC('Adis'), FourCC('Afbt'), FourCC('Afbk'),
    }
    local ABIL_COUNT = #ABIL
    local CHUNK = 200

    local function invalidCharIn(s)
        local i, n = 0, string.len(s or "")
        while i < n do
            local c = string.sub(s, i+1, i+1)
            if c == "\\" or c == "\"" then return c end
            i = i + 1
        end
        return nil
    end

    local function writeChunks(filename, text)
        local bad = invalidCharIn(text or "")
        if bad then
            print("[SaveIO] refused char in payload: " .. bad .. " file " .. filename)
            return false
        end

        PreloadGenClear()
        PreloadGenStart()

        local i, c = 0, 0
        local len = string.len(text or "")
        if len == 0 then
            Preload("\" )\n//")
        end

        while i < len and c < ABIL_COUNT do
            local chunk = string.sub(text, i+1, math.min(i+CHUNK, len))
            Preload("\" )\ncall BlzSetAbilityTooltip(" .. tostring(ABIL[c+1]) .. ", \"-" .. chunk .. "\", 0)\n//")
            i = i + CHUNK
            c = c + 1
        end

        Preload("\" )\nendfunction\nfunction a takes nothing returns nothing\n//")
        PreloadGenEnd(filename)
        return true
    end

    local function readChunks(filename)
        local orig = {}
        for i = 1, ABIL_COUNT do
            orig[i] = BlzGetAbilityTooltip(ABIL[i], 0)
        end

        Preloader(filename)

        local out = {}
        for i = 1, ABIL_COUNT do
            local cur = BlzGetAbilityTooltip(ABIL[i], 0)
            if cur == orig[i] then break end
            if string.sub(cur, 1, 1) == "-" then cur = string.sub(cur, 2) end
            BlzSetAbilityTooltip(ABIL[i], orig[i], 0)
            out[#out+1] = cur
        end

        return table.concat(out, "")
    end

    function SaveIO.Write(baseDir, filename, contents)
        filename = (baseDir or "Animecraft") .. "\\" .. (filename or "slot1") .. ".pld"
        return writeChunks(filename, contents or "")
    end

    function SaveIO.Read(baseDir, filename)
        filename = (baseDir or "Animecraft") .. "\\" .. (filename or "slot1") .. ".pld"
        return readChunks(filename)
    end

    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
        InitBroker.SystemReady("SaveIO_Preloader")
    end
end

if Debug and Debug.endFile then Debug.endFile() end
