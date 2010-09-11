--[[

  Adrian L Lange grants anyone the right to use this work for any purpose,
  without any conditions, unless such conditions are required by law.

--]]

local FONT = [=[Interface\AddOns\oUF_Ryoushi\semplice.ttf]=]
local TEXTURE = [=[Interface\ChatFrame\ChatFrameBackground]=]
local BACKDROP = {bgFile = TEXTURE, edgeFile = TEXTURE, edgeSize = 1}

local function SpawnMenu(self)
	ToggleDropDownMenu(1, nil, _G[string.gsub(self.unit, '^.', string.upper)..'FrameDropDown'], 'cursor')
end

local function PostUpdatePower(element, unit, min, max)
	element:GetParent().Health:SetHeight(max ~= 0 and 16 or 19)
end

local function PostCreateAura(element, button)
	local bg = CreateFrame('Frame', nil, button)
	bg:SetPoint('TOPRIGHT', 1, 1)
	bg:SetPoint('BOTTOMLEFT', -1, -1)
	bg:SetBackdrop(BACKDROP)
	bg:SetBackdropColor(0, 0, 0, 0)
	bg:SetBackdropBorderColor(0, 0, 0)

	button.cd:SetReverse()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.count:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
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
	local status = _TAGS['offline'](unit) or _TAGS['dead'](unit)

	if(status) then
		return status
	elseif(unit == 'player' and min ~= max) then
		return ('|cffff8080-%s|r %d%%'):format(ShortenValue(math.abs(min - max)), min / max * 100)
	elseif(unit == 'target' and UnitCanAttack('player', unit)) then
		return ('%s (%d%%)'):format(ShortenValue(min), min / max * 100)
	elseif(min ~= max) then
		return ('%s/%s'):format(ShortenValue(min), ShortenValue(max))
	else
		return ShortenValue(max)
	end
end

oUF.Tags['ryoushi:power'] = function(unit)
	if(not UnitIsDeadOrGhost(unit)) then
		local power = UnitPower(unit)
		local _, type = UnitPowerType(unit)

		return ('%s%s|r'):format(Hex(_COLORS.power[type]), ShortenValue(power))
	end
end

oUF.Tags['ryoushi:pet'] = function(unit)
	return GetPetHappiness() and Hex(_COLORS.happiness[GetPetHappiness()]) .. _TAGS['perhp'](unit)
end

oUF.Tags['ryoushi:spell'] = function(unit)
	return UnitCastingInfo(unit) or UnitChannelInfo(unit)
end

local UnitSpecific = {
	player = function(self)
		local castbar = CreateFrame('StatusBar', nil, self)
		castbar:SetAllPoints(self.Health)
		castbar:SetStatusBarTexture(TEXTURE)
		castbar:SetStatusBarColor(0, 0, 0, 0)
		castbar:SetToplevel(true)
		self.Castbar = castbar

		local spark = castbar:CreateTexture(nil, 'OVERLAY')
		spark:SetSize(2, 19)
		spark:SetTexture(1, 1, 1)
		castbar.Spark = spark

		local power = self.Health:CreateFontString(nil, 'OVERLAY')
		power:SetPoint('LEFT', 2, 0)
		power:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
		power:SetJustifyH('LEFT')
		power.frequentUpdates = 1/10
		self:Tag(power, '[ryoushi:power][ | >ryoushi:spell]')
	end,
	target = function(self)
		local buffs = CreateFrame('Frame', nil, self)
		buffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, 4)
		buffs:SetSize(220, 40)
		buffs.initialAnchor = 'BOTTOMRIGHT'
		buffs.num = 22
		buffs.size = 16.32
		buffs.spacing = 4
		buffs['growth-x'] = 'LEFT'
		buffs.PostCreateIcon = PostCreateAura
		self.Buffs = buffs

		local power = CreateFrame('StatusBar', nil, self)
		power:SetPoint('BOTTOMRIGHT')
		power:SetPoint('BOTTOMLEFT')
		power:SetPoint('TOP', self.Health, 'BOTTOM', 0, -1)
		power:SetStatusBarTexture(TEXTURE)
		power.frequentUpdates = 1/10
		power.colorPower = true
		power.PostUpdate = PostUpdatePower
		self.Power = power

		local bg = CreateFrame('Frame', nil, self)
		bg:SetPoint('TOPRIGHT', power, 1, 1)
		bg:SetPoint('BOTTOMLEFT', power, -1, -1)
		bg:SetBackdrop(BACKDROP)
		bg:SetBackdropColor(0, 0, 0, 0.5)
		bg:SetBackdropBorderColor(0, 0, 0)

		local name = self.Health:CreateFontString(nil, 'OVERLAY')
		name:SetPoint('LEFT', 2, 0)
		name:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
		name:SetJustifyH('LEFT')
		self:Tag(name, '[name][ |cff0090ff>rare<|r]')

		self.Debuffs.filter = 'PLAYER|HARMFUL'
	end,
	pet = function(self)
		local health = self:CreateFontString(nil, 'OUTLINE')
		health:SetAllPoints()
		health:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
		health:SetJustifyH('LEFT')
		health.frequentUpdates = 1/4
		self:Tag(health, '[ryoushi:pet<%]')
	end
}

local function Shared(self, unit)
	self.colors.power.MANA = {0, 144/255, 1}

	self:RegisterForClicks('AnyUp')
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)
	self.menu = SpawnMenu

	if(unit == 'player' or unit == 'target') then
		local health = CreateFrame('StatusBar', nil, self)
		health:SetPoint('TOPRIGHT')
		health:SetPoint('TOPLEFT')
		health:SetHeight(19)
		health:SetStatusBarTexture(TEXTURE)
		health.frequentUpdates = true
		health.colorClass = true
		health.colorTapping = true
		health.colorReaction = true
		self.Health = health

		local bg = CreateFrame('Frame', nil, self)
		bg:SetPoint('TOPRIGHT', health, 1, 1)
		bg:SetPoint('BOTTOMLEFT', health, -1, -1)
		bg:SetBackdrop(BACKDROP)
		bg:SetBackdropColor(0, 0, 0, 0.5)
		bg:SetBackdropBorderColor(0, 0, 0)

		local value = health:CreateFontString(nil, 'OVERLAY')
		value:SetPoint('RIGHT', health, -2, 0)
		value:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
		value:SetJustifyH('RIGHT')
		value.frequentUpdates = 1/4
		self:Tag(value, '[ryoushi:health]')

		local debuffs = CreateFrame('Frame', nil, self)
		debuffs:SetPoint('TOPLEFT', self, 'TOPRIGHT', 4, 0)
		debuffs:SetSize(134, 19)
		debuffs.initialAnchor = 'TOPLEFT'
		debuffs.num = 5
		debuffs.size = 19
		debuffs.spacing = 4
		debuffs.PostCreateIcon = PostCreateAura
		self.Debuffs = debuffs

		self:SetAttribute('initial-height', 19)
		self:SetAttribute('initial-width', 220)
	else
		if(unit ~= 'pet') then
			local name = self:CreateFontString(nil, 'OVERLAY')
			name:SetAllPoints()
			name:SetFont(FONT, 8, 'OUTLINEMONOCHROME')
			name:SetJustifyH(unit == 'focus' and 'LEFT' or 'RIGHT')
			self:Tag(name, '[raidcolor][name]')
		end

		self:SetAttribute('initial-height', 12)
		self:SetAttribute('initial-width', 110)
	end

	if(UnitSpecific[unit]) then
		return UnitSpecific[unit](self)
	end
end

oUF:RegisterStyle('Ryoushi', Shared)
oUF:Factory(function(self)
	self:SetActiveStyle('Ryoushi')

	local player = self:Spawn('player')
	player:SetPoint('CENTER', -300, -100)

	local target = self:Spawn('target')
	target:SetPoint('BOTTOM', player, 'TOP', 0, 16)

	self:Spawn('targettarget'):SetPoint('TOPRIGHT', target, 'BOTTOMRIGHT', -2, -1)
	self:Spawn('focus'):SetPoint('TOPLEFT', target, 'BOTTOMLEFT', 2, -1)
	self:Spawn('pet'):SetPoint('TOPLEFT', player, 'BOTTOMLEFT', 2, -1)
end)
