--[[

  Adrian L Lange grants anyone the right to use this work for any purpose,
  without any conditions, unless such conditions are required by law.

--]]

local FONT = [=[Interface\AddOns\oUF_Ryoushi\semplice.ttf]=]
local TEXTURE = [=[Interface\ChatFrame\ChatFrameBackground]=]
local BACKDROP = {
	bgFile = TEXTURE, insets = {top = -1, bottom = -1, left = -1, right = -1}
}

local function SpawnMenu(self)
	ToggleDropDownMenu(1, nil, _G[string.gsub(self.unit, '^.', string.upper)..'FrameDropDown'], 'cursor')
end

local function PostUpdatePower(element, unit, min, max)
	element:GetParent().Health:SetHeight(max ~= 0 and 16 or 19) -- XXX: adjust this to the final heights for the target frame
end

local function PostCreateAura(element, button)
	button:SetBackdrop(BACKDROP)
	button:SetBackdropColor(0, 0, 0)
	button.cd:SetReverse()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon:SetDrawLayer('ARTWORK')
end

local function PostUpdateDebuff(element, unit, button, index)
	local _, _, _, _, type = UnitAura(unit, index, button.filter)
	local color = DebuffTypeColor[type] or DebuffTypeColor.none
	button:SetBackdropColor(color.r * 3/5, color.g * 3/5, color.b * 3/5)
end

local function ShortenValue(value)
	if(value >= 1e6) then
		return ('%.2fm'):format(value / 1e6):gsub('%.?0+([km])$', '%1')
	elseif(value >= 1e4) then
		return ('%.1fk'):format(value / 1e3):gsub('%.?0+([km])$', '%1')
	else
		return value
	end
end

oUF.Tags['ryoushi:health'] = function(unit)
	local min, max = UnitHealth(unit), UnitHealthMax(unit)
	local status = not UnitIsConnected(unit) and 'Offline' or UnitIsGhost(unit) and 'Ghost' or UnitIsDead(unit) and 'Dead'

	if(status) then
		return status
	elseif(unit == 'pet') then
		return ('%s%d|r'):format(Hex(_COLORS.happiness[GetPetHappiness()]), min / max * 100)
	elseif(unit == 'player' and min ~= max) then
		return ('|cffff8080%d|r %d%%'):format(min - max, min / max * 100)
	elseif(unit == 'target' and UnitCanAttack('player', unit)) then
		return ('%s (%d%%)'):format(ShortenValue(min), min / max * 100)
	elseif(min ~= max) then
		return ('%s/%s'):format(ShortenValue(min), ShortenValue(max))
	else
		return max
	end
end

oUF.Tags['ryoushi:power'] = function(unit)
	local power = UnitPower(unit)
	if(power > 0 and not UnitIsDeadOrGhost(unit)) then
		local _, type = UnitPowerType(unit)
		local colors = _COLORS.power
		return ('%s%d|r'):format(Hex(colors[type] or colors.RUNES), power)
	end
end

oUF.TagEvents['ryoushi:name'] = 'UNIT_NAME_UPDATE UNIT_REACTION UNIT_FACTION'
oUF.Tags['ryoushi:name'] = function(unit)
	local reaction = UnitReaction(unit, 'player')
	local _, class = UnitClass(unit)

	local r, g, b = 1, 1, 1
	if(unit ~= 'target' and class) then
		r, g, b = unpack(_COLORS.class[class])
	elseif((UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) or not UnitIsConnected(unit)) then
		r, g, b = 3/5, 3/5, 3/5
	elseif(not UnitIsPlayer(unit) and reaction) then
		r, g, b = unpack(_COLORS.reaction[reaction])
	elseif(UnitFactionGroup(unit) and UnitIsEnemy(unit, 'player') and UnitIsPVP(unit)) then
		r, g, b = 1, 0, 0
	end

	return ('%s%s|r'):format(Hex(r, g, b), UnitName(unit))
end

oUF.TagEvents['ryoushi:spell'] = 'UNIT_SPELLCAST_START UNIT_SPELLLCAST_CHANNEL_START' -- XXX: check if the events respond to cast-stop
oUF.Tags['ryoushi:spell'] = function(unit)
	local cast = UnitCastingInfo(unit)
	local channel = UnitChannelInfo(unit)
	return cast or channel
end

oUF.TagEvents['ryoushi:threat'] = 'UNIT_THREAT_LIST_UPDATE'
oUF.Tags['ryoushi:threat'] = function(unit)
	local tanking, status, percent = UnitDetailedThreatSituation(unit, unit..'target')
	if(percent and percent > 0) then
		return ('%s%d%%|r'):format(Hex(GetThreatStatusColor(status)), percent)
	end
end

local UnitSpecific = {
	player = function(self)
		local castbar = CreateFrame('StatusBar', nil, self)
		castbar:SetAllPoints(self.Health)
		castbar:SetStatusBarColor(0, 0, 0, 0)
		castbar:SetTopLevel(true)
		self.Castbar = castbar

		local spark = castbar:CreateTexture(nil, 'OVERLAY')
		spark:SetSize(2, 19)
		spark:SetTexture(1, 1, 1)
		castbar.Spark = spark

		local power = self:CreateFontString(nil, 'OVERLAY')
		power:SetPoint('LEFT', self.Health, 2, 0)
		power:SetFont(FONT, 8, 'OUTLINE')
		power:SetJustifyH('LEFT')
		power.frequentUpdates = 1/10
		self:Tag(power, '[ryoushi:power][ | >ryoushi:spell]')

		local threat = self:CreateFontString(nil, 'OVERLAY')
		threat:SetPoint('CENTER', self.Health)
		threat:SetFont(FONT, 8, 'OUTLINE')
		threat:SetJustifyH('CENTER')
		self:Tag(threat, '[ryoushi:threat]')
	end,
	target = function(self)
		local power = CreateFrame('StatusBar', nil, self)
		power:SetPoint('BOTTOMRIGHT')
		power:SetPoint('BOTTOMLEFT')
		power:SetPoint('TOP', self.Health, 'BOTTOM', 0, -1)
		power:SetStatusBarTexture(TEXTURE)
		power.frequentUpdates = 1/10
		power.colorPower = true
		power.PostUpdate = PostUpdatePower
		self.Power = power

		local bg = power:CreateTexture(nil, 'BORDER')
		bg:SetAllPoints()
		bg.multiplier = 1/3
		power.bg = bg

		local name = power:CreateFontString(nil, 'OVERLAY')
		name:SetPoint('LEFT', self.Health, 2, 0)
		name:SetFont(FONT, 8, 'OUTLINE')
		name:SetJustifyH('LEFT')
		self:Tag(name, '[ryoushi:name< ][|cff0090ff>rare<|r]')

		self.Debuffs.onlyShowPlayer = true
	end,
	pet = function(self)
		local health = self:CreateFontString(nil, 'OUTLINE')
		health:SetAllPoints()
		health:SetFont(FONT, 8, 'OUTLINE')
		health:SetJustifyH('LEFT')
		health.frequentUpdates = 1/4
		self:Tag(health, '[ryoushi:health]')
	end
}

local function Shared(self, unit)
	self.colors.power.MANA = {0, 144/255, 1}

	self:RegisterForClicks('AnyUp')
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)
	self.menu = SpawnMenu

	if(unit == 'player' or unit == 'target') then
		self:SetBackdrop(BACKDROP)
		self:SetBackdropColor(0, 0, 0)

		local health = CreateFrame('StatusBar', nil, self)
		health:SetPoint('TOPRIGHT')
		health:SetPoint('TOPLEFT')
		health:SetHeight(19) -- XXX: set the height
		health:SetStatusBarTexture(TEXTURE)
		health.frequentUpdates = true
		health.colorClass = true
		health.colorTapping = true
		health.colorReaction = true
		self.Health = health

		local bg = health:CreateTexture(nil, 'BORDER')
		bg:SetAllPoints()
		bg.multiplier = 1/3
		health.bg = bg

		local value = health:CreateFontString(nil, 'OVERLAY')
		value:SetPoint('RIGHT', health, -2, 0)
		value:SetFont(FONT, 8, 'OUTLINE')
		value:SetJustifyH('RIGHT')
		value.frequentUpdates = 1/4
		self:Tag(value, '[ryoushi:health]')

		local debuffs = CreateFrame('Frame', nil, self)
		debuffs:SetPoint('TOPLEFT', self, 'TOPRIGHT', 4, 0)
		debuffs:SetSize(100, 19) -- XXX: fix the width to the max amount
		debuffs.initialAnchor = 'TOPLEFT'
		debuffs.spacing = 4
		debuffs.size = 19 -- XXX: set the size to match the frame height
		debuffs.PostUpdateIcon = PostUpdateDebuff
		self.Debuffs = debuffs

		self:SetAttribute('initial-height', 19) -- XXX: set the right height
		self:SetAttribute('initial-width', 200) -- XXX: set the right width
	else
		if(unit ~= 'pet') then
			local name = self:CreateFontString(nil, 'OVERLAY')
			name:SetAllPoints()
			name:SetFont(FONT, 8, 'OUTLINE')
			name:SetJustifyH('RIGHT')
			self:Tag(name, '[ryoushi:name]')
		end

		self:SetAttribute('initial-height', 12) -- XXX: set the right height (little less than the player/target)
		self:SetAttribute('initial-width', 100) -- XXX: set the right width (half of the player/target)
	end

	if(UnitSpecific[unit]) then
		return UnitSpecific[unit](self)
	end
end

oUF:RegisterStyle('Ryoushi', Shared)
oUF:Factory(function(self)
	self:DisableBlizzard('boss')
	self:SetActiveStyle('Ryoushi')
	self:Spawn('player') -- XXX: set the position
	self:Spawn('target') -- XXX: set the position
	self:Spawn('targettarget') -- XXX: set the position
	self:Spawn('focus') -- XXX: set the position
	self:Spawn('pet') -- XXX: set the position
end)
