PermAlmalexia = {
	name = "PermAlmalexia",
	options = {
		type = "panel",
		name = "PermAlmalexia: Permanent Mementos",
		author = "mouton",
		version = "1.0"
	},
	settings = {},
	defaultSettings = {
		mementos = {
			-- https://esoitem.uesp.net/viewlog.php?record=collectibles
			[341]  = {abilityId = 26829, name = GetCollectibleName(341),  delay = 1000, cooldown = 2800 }, -- Almalexia
			[336]  = {abilityId = 21226, name = GetCollectibleName(336),  delay = 500, cooldown = 3200 }, -- Finvir
			[594]  = {abilityId = 85344, name = GetCollectibleName(594),  delay = 2000, cooldown = 100 }, -- Storm Atronach Aura
			[596]  = {abilityId = 85349, name = GetCollectibleName(596),  delay = 500, cooldown = 100 }, -- Storm Atronach Transform
			[758]  = {abilityId = 86978, name = GetCollectibleName(758),  delay = 500, cooldown = 100 }, -- Floral Swirl Aura
			[759]  = {abilityId = 86977, name = GetCollectibleName(759),  delay = 500, cooldown = 100 }, -- Wild Hunt Transform
			[760]  = {abilityId = 86976, name = GetCollectibleName(760),  delay = 500, cooldown = 100 }, -- Wild Hunt Leaf-Dance Aura
			[1183] = {abilityId = 92868, name = GetCollectibleName(1183), delay = 500, cooldown = 100 }, -- Dwemervamidium Mirage
-- 			[1384] = {abilityId = 97274, name = GetCollectibleName(1384), delay = 500, cooldown = 100 }, -- Swarm of Crows - Not working anymore as no more ability effect
		},
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


function PA.isEffectStillActive()
	local active = false
	for i = 1, GetNumBuffs("player") do
		local buffName, startTime, endTime, buffSlot, stackCount, iconFile, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
		active = active or PA.getMementoFromEffect(abilityId)
	end
	return active;
end

function PA.getMementoFromEffect(abilityId)
	for mementoId, ability in pairs(PA.settings.mementos) do
		if ability.abilityId == abilityId then
			return mementoId
		end
	end	
	return false
end

function PA.useCollectible(mementoId)
	-- Do not trigger while mounted, dead or so, it fails with a bump sound.
	if not (IsMounted() or IsUnitReincarnating("player") or IsUnitSwimming("player") or IsUnitDead("player") or GetUnitStealthState("player") ~= STEALTH_STATE_NONE) then
		fromCallback = true
		UseCollectible(mementoId)
	else
		PA.d('Player cannot activate collectibles at the moment.')
	end

	local callback = function ()
		PA.checkCollectibleActivation()
	end
	local remaining, duration = GetCollectibleCooldownAndDuration(PA.settings.mementoId)
	zo_callLater(callback, math.max(remaining, PA.settings.mementos[PA.settings.mementoId].delay * math.max(1, PAfailure)))
end

function PA.delayCollectible()
	if PArunning and PAcallback == false and PA.settings.mementoId then
		local callback = function ()
			PA.useCollectible(PA.settings.mementoId)
			PAcallback = false
		end

		-- Cooldown when memento is finished
		local remaining, duration = GetCollectibleCooldownAndDuration(PA.settings.mementoId)
		PAcallback = zo_callLater(callback, math.max(remaining, PA.settings.mementos[PA.settings.mementoId].cooldown))
	end
end

function PA.checkCollectibleActivation()
	if not PA.isEffectStillActive() then
		PA.d('Collectible was NOT active, trying again soon...')
		PA.delayCollectible()
	end
end

function PA.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
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
		EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_EFFECT_CHANGED, PA.OnEffectChanged)
		EVENT_MANAGER:AddFilterForEvent(PA.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
	else
		PA.settings.debug = false
		EVENT_MANAGER:UnregisterForEvent(PA.name)
	end
end

function PA.d(...)
	if PA.settings.debug then
		d(...)
	end
end

function PA.OnAddOnLoaded(event, addonName)
	if addonName ~= PA.name then return end

	PA:Initialize()
end

function PA.init()
	if PArunning then
		PA.checkCollectibleActivation()
	end
end

function PA:Initialize()
	PA.settings = ZO_SavedVars:NewAccountWide(PA.name .. "Variables", PA.defaultSettings.variableVersion, nil, PA.defaultSettings)

	EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_PLAYER_ACTIVATED, PA.init )

	for mementoId, ability in pairs(PA.settings.mementos) do
		local eventName = PA.name .. mementoId
		EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, PA.OnEffectChanged)
		EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, ability.abilityId)
	end

	EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_COLLECTIBLE_USE_RESULT, PA.OnCollectibleUse )
	EVENT_MANAGER:UnregisterForEvent(PA.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(PA.name, EVENT_ADD_ON_LOADED, PA.OnAddOnLoaded)
