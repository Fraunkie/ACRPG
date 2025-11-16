do
	local availableList = {}
	local activeList = {}
	
	local function RequestDummy(x,y,whichPlayer,abilityId)
		local t
		local u

		if #availableList == 0 then
			u = CreateUnit(whichPlayer, FourCC('udum'), x, y, 0 )
			activeList[#activeList + 1] = u
			t = CreateTimer()
		else
			u = availableList[#availableList]
			activeList[#activeList + 1] = u
			availableList[#availableList] = nil
			SetUnitX(u, x)
			SetUnitY(u, y)
		end

		local index = #activeList

		TimerStart(t, 0.25, false, function()
			UnitRemoveAbility(u, abilityId)

			if index < #activeList then
				activeList[index] = activeList[#activeList]
			end

			activeList[#activeList] = nil
			availableList[#availableList + 1] = u
			DestroyTimer(t)
		end)

		return activeList[#activeList]
	end

	---@param source unit
	---@param target unit
	---@param ability string | integer
	---@param order string | integer
    ---@param level? integer
	---@return unit
	function DummyTargetUnit(source, target, ability, order, level)
        ability = type(ability) == "string" and FourCC(ability) or ability
        order = type(order) == "string" and OrderId(order) or order
		local x = GetUnitX(source)
		local y = GetUnitY(source)
		local whichPlayer = GetOwningPlayer(source)
		local dummy = RequestDummy(x, y, whichPlayer, ability)
		UnitAddAbility(dummy, ability)
        if level then
		    SetUnitAbilityLevel(dummy, ability, level)
        end
		IssueTargetOrderById(dummy, order, target)
		return dummy
	end
end