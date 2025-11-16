if Debug then Debug.beginFile "ValidateTable" end
do
    ---@param table table
    ---@param required? table
    ---@param recognized? table
    ---@param reserved? table
    function ValidateTable(table, required, recognized, reserved)
        if required then
            if table == nil then
                error("Data table missing.")
            end
            for key, __ in pairs(required) do
                assert(table[key], "Required field " .. key .. " missing in data table.")
            end
        end

        if table == nil then
            return
        end

        if recognized then
            for key, __ in pairs(table) do
                if not recognized[key] then
                    if Debug then
                        print("|cffff0000Warning:|r " .. string.gsub(Debug.traceback(), "ValidateTable:\x25d+ \x25<\x25- ", "") .. ": Unrecognized field |cffffcc00" .. key .. "|r in data table.")
                    else
                        print("|cffff0000Warning:|r Unrecognized field " .. key .. " in data table.")
                    end
                end
            end
        end

        if reserved then
            for key, __ in pairs(table) do
                assert(not reserved[key],"Reserved field " .. key .. " present in data table.")
            end
        end
    end
end
if Debug then Debug.endFile() end