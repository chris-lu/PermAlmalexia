PermAlmalexia = {
	name = "PermAlmalexia",
	options = {
		type = "panel",
		name = "PermAlmalexia: Permanent Mementos",
		author = "mouton",
		version = "1.0.4"
	},
	mementos = {
		-- https://esoitem.uesp.net/viewlog.php?record=collectibles
--		[336]  = { abilityId = false, name = GetCollectibleName(336), delay = 500, cooldown = 200 }, -- Finvir
		[336]  = { abilityId = 21226, name = GetCollectibleName(336), delay = 500, cooldown = 3200 }, -- Finvir
		[341]  = { abilityId = 26829, name = GetCollectibleName(341), delay = 1000, cooldown = 2800 }, -- Almalexia
		[347]  = { abilityId = 41950, name = GetCollectibleName(347), delay = 500, cooldown = 3000 }, -- Fetish of Anger
		[594]  = { abilityId = 85344, name = GetCollectibleName(594), delay = 2000, cooldown = 100 }, -- Storm Atronach Aura
		[758]  = { abilityId = 86978, name = GetCollectibleName(758), delay = 500, cooldown = 100 }, -- Floral Swirl Aura
		[759]  = { abilityId = 86977, name = GetCollectibleName(759), delay = 500, cooldown = 100 }, -- Wild Hunt Transform
		[760]  = { abilityId = 86976, name = GetCollectibleName(760), delay = 500, cooldown = 100 }, -- Wild Hunt Leaf-Dance Aura
		[1183] = { abilityId = 92868, name = GetCollectibleName(1183), delay = 500, cooldown = 100 }, -- Dwemervamidium Mirage
		[10371] = { abilityId = 170722, name = GetCollectibleName(10371), delay = 500, cooldown = 100 }, -- Fargrave Occult Curio

	    [596]  = { abilityId = false, name = GetCollectibleName(596), delay = 500, cooldown = 200 }, -- Storm Atronach Transform - Not working anymore as no more ability effect
		[1384] = { abilityId = false, name = GetCollectibleName(1384), delay = 500, cooldown = 200 }, -- Swarm of Crows - Not working anymore as no more ability effect - was 97274
		[9361] = { abilityId = false, name = GetCollectibleName(9361), delay = 500, cooldown = 200 }, -- Inferno Cleats
	},
	settings = {
		mementoId = 0,
	},
	defaultSettings = {
		mementoId = 0,
		variableVersion = 1,
		debug = false,
	}
}

local PA = PermAlmalexia
local PArunning = false;
local PAcallback = false;
local PAfailure = 0;
local fromCallback = false;

-- Workflow
-- Event Based (prefered) : OnEffectChanged -> (fade) delayCollectible -> useCollectible -> Prev_ZO_CollectibleData_Use
-- Activation based (inventory only) : UseCollectible -> delayCollectible -> useCollectible -> delayCollectible

local Prev_ZO_CollectibleData_Use = UseCollectible
function UseCollectible(collectibleId, actorCategory)
	-- Workaround for mementos without effects. Can only be triggered from inventory
	if PA.mementos[collectibleId] and not PA.mementos[collectibleId].abilityId then
		PA.d('Catching collectible call: ' .. collectibleId)
		PA.settings.mementoId = collectibleId
		if PArunning == false then
			CHAT_SYSTEM:AddMessage(zo_strformat(PERMALMALEXIA_START_MEMENTO, PA.mementos[collectibleId].name))
		end
		PArunning = true
		PA.delayCollectible()
	else
		PA.d('Not catching for: ' .. collectibleId)
		Prev_ZO_CollectibleData_Use(collectibleId, actorCategory)
	end
end


function PA.isEffectStillActive()
	local active = false
	for i = 1, GetNumBuffs("player") do
		local buffName, startTime, endTime, buffSlot, stackCount, iconFile, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
		active = active or PA.getMementoFromEffect(abilityId) ~= false
	end
	return active;
end

function PA.getMementoFromEffect(abilityId)
	-- Do not get back mementos without abilityId
	for mementoId, ability in pairs(PA.mementos) do
		if ability.abilityId and ability.abilityId == abilityId then
			return mementoId
		end
	end
	return false
end

function PA.useCollectible(mementoId)
	if PArunning and PAcallback == false then
		-- Do not trigger while mounted, dead or so, it fails with a bump sound.
		if not (IsMounted() or IsUnitReincarnating("player") or IsUnitSwimming("player") or IsUnitDead("player") or GetUnitStealthState("player") ~= STEALTH_STATE_NONE) then
			fromCallback = true
			Prev_ZO_CollectibleData_Use(mementoId)
		else
			PA.d('Player cannot activate collectibles at the moment.')
		end

		local callback = function()
			PAcallback = false
			-- Use abilityId when available as it's more reliable
			if PA.mementos[mementoId].abilityId then
				PA.checkCollectibleActivation()
			-- Try to catch with overwritten function if not.
			else
				PA.delayCollectible()
			end
		end
		local remaining, duration = GetCollectibleCooldownAndDuration(mementoId)
		PAcallback = zo_callLater(callback, math.max(remaining, PA.mementos[mementoId].delay * math.max(1, PAfailure)))
	end
end

function PA.delayCollectible()
	if PArunning and PAcallback == false and PA.settings.mementoId then
		local callback = function()
			PAcallback = false
			PA.useCollectible(PA.settings.mementoId)
		end

		-- Cooldown when memento is finished
		local remaining, duration = GetCollectibleCooldownAndDuration(PA.settings.mementoId)
		PAcallback = zo_callLater(callback, math.max(remaining, PA.mementos[PA.settings.mementoId].cooldown))
	end
end

function PA.checkCollectibleActivation()
	if not PA.isEffectStillActive() then
		PA.d('Collectible was NOT active, trying again soon...')
		PA.delayCollectible()
	end
end

function PA.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
	                        iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId,
	                        sourceType)
	-- Only refresh if we started manually
	if PArunning == true and changeType == EFFECT_RESULT_FADED then
		local mementoId = PA.getMementoFromEffect(abilityId)
		if mementoId then
			PA.settings.mementoId = mementoId
			return PA.delayCollectible()
		end
	elseif changeType == EFFECT_RESULT_GAINED then
		local mementoId = PA.getMementoFromEffect(abilityId)
		if mementoId then
			PA.settings.mementoId = mementoId
			if PArunning == false then
				CHAT_SYSTEM:AddMessage(zo_strformat(PERMALMALEXIA_START, effectName))
			end
			PArunning = true
		elseif sourceType == COMBAT_UNIT_TYPE_PLAYER then
			PA.d(zo_strformat('Effect starting: <<1>> [<<2>>]', effectName, abilityId))
		end
	end
end

function PA.OnCollectibleUse(eventCode, result, isAttemptingActivation)
	-- This is a manual call? We cancel the run (ugly workaround as too few info is retrieved here)
	if PArunning == true then
		if result ~= 0 then
			if not fromCallback then
				CHAT_SYSTEM:AddMessage(zo_strformat(PERMALMALEXIA_END))
				PArunning = false
				if PAcallback then
					zo_removeCallLater(PAcallback)
				end
				PAcallback = false
			else
				PAfailure = PAfailure + 1
			end
		else
			PAfailure = 0
		end
	end

	fromCallback = false
end

function PA.debug(is_debug)
	-- For debugging all effects
	if is_debug then
		PA.settings.debug = true
	else
		PA.settings.debug = false
	end
end

function PA.d(...)
	if PA.settings.debug then
		d(...)
	end
end


-- Inpired by Memento Miner from @Phinix
-- /script PermAlmalexia.listMementos()
function PA.listMementos()
	if PA.settings.debug then
		local tData = {}
		local allCollectibles = ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects({ function() return true end }, { ZO_CollectibleData.IsSlottable })

		for _, collectibleData in ipairs(allCollectibles)  do
			-- https://wiki.esoui.com/Globals#CollectibleCategoryType
			local tAbility = collectibleData:GetReferenceId() -- data object returns ability ID from this function
			local tDuration = GetAbilityDuration(tAbility) -- duration of the memento in milliseconds
			if tDuration > 0 then
				tData[collectibleData.collectibleId] = {
					-- create data object for each matching memento and add to output table
					name          = collectibleData.name,
					collectibleId = collectibleData.collectibleId,
					abilityId     = tAbility,
					duration      = tDuration,
				}
				PA.d(tData[collectibleData.collectibleId])
			end
		end
		-- commits the output table to saved variables, /reloadui to save, then open \Documents\Elder Scrolls Online\live\SavedVariables\MementoMiner.lua
		PA.settings.debug = tData

		PA.d("Process complete. Please /reloadui")
	end
end

function PA.OnAddOnLoaded(event, addonName)
	if addonName ~= PA.name then return end

	PA:Initialize()
end

function PA.init()
	PA.d(PArunning, PA.isEffectStillActive())
	if PArunning then
		PA.checkCollectibleActivation()
	end
end

function PA:Initialize()
	PA.settings = ZO_SavedVars:NewAccountWide(PA.name .. "Variables", PA.defaultSettings.variableVersion, nil, PA.defaultSettings)

	EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_PLAYER_ACTIVATED, PA.init)

	for mementoId, ability in pairs(PA.mementos) do
		local eventName = PA.name .. mementoId
		EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, PA.OnEffectChanged)
		EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, ability.abilityId)
		EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
	end

	EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_COLLECTIBLE_USE_RESULT, PA.OnCollectibleUse)
	EVENT_MANAGER:UnregisterForEvent(PA.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_ADD_ON_LOADED, PA.OnAddOnLoaded)
