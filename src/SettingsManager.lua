--!strict
-- Client-session settings only. No DataStore, filesystem or cross-session promise.
-- Extended with cheat-style feature settings for authorized test environments.
local SettingsManager = {}
SettingsManager.__index = SettingsManager

local STORAGE_NAME = "VWMenu_Settings_v2"
local OWNER = "VWMenu"
local VERSION = 2

-- Default settings for cheat framework
local DEFAULTS: { [string]: any } = {
	-- Main settings --
	reducedMotion = false,
	uiScale = 1,
	demoEnabled = false,
	demoValue = 50,
	demoChoice = "Equilibrado",
	demoDestination = "Laboratorio",
	selectedTab = "Main",
	positionInfoEnabled = false,
	fpsCounterEnabled = false,
	memoryUsageEnabled = false,
	pingDisplayEnabled = false,

	-- Movement settings --
	flyEnabled = false,
	flySpeed = 200,
	noclipEnabled = false,
	infiniteJump = false,
	walkSpeed = 16,
	jumpPower = 50,

	-- Visual settings --
	espEnabled = false,
	boxEspEnabled = false,
	skeletonEspEnabled = false,
	highlightEnabled = false,
	namesEnabled = false,
	distanceEnabled = false,
	healthEnabled = false,
	chamsEnabled = false,
	tracersEnabled = false,
	skeletonBonesEnabled = false,
	teamColors = true,
	highlightTransparency = 0.65,
	friendColor = "#42ADFF",
	enemyColor = "#FF4D5A",

	-- Player settings --
	godMode = false,
	invisible = false,
	nameReveal = false,

	-- Debug settings --
	debugMode = false,
}

local CHOICES = {
	Equilibrado = true,
	Rapido = true,
	Preciso = true,
}

local DESTINATIONS = {
	Laboratorio = true,
	Praca = true,
	Oficina = true,
}

-- Tabs available in the interface
local TABS = {
	Main = true,
	Movement = true,
	Visual = true,
	Player = true,
	Interface = true,
	Settings = true,
}

type Manager = { _folder: Folder, _values: { [string]: any } }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validate(key: string, value: any): boolean
	-- Boolean settings
	if key == "reducedMotion" or key == "demoEnabled" or key == "flyEnabled" or
		key == "noclipEnabled" or key == "infiniteJump" or key == "espEnabled" or
		key == "boxEspEnabled" or key == "skeletonEspEnabled" or key == "highlightEnabled" or
		key == "namesEnabled" or key == "distanceEnabled" or key == "healthEnabled" or
		key == "chamsEnabled" or key == "tracersEnabled" or key == "skeletonBonesEnabled" or
		key == "teamColors" or key == "debugMode" or key == "positionInfoEnabled" or
		key == "fpsCounterEnabled" or key == "memoryUsageEnabled" or key == "pingDisplayEnabled" or
		key == "godMode" or key == "invisible" or key == "nameReveal" then
		return type(value) == "boolean"
	end

	-- Numeric sliders
	if key == "uiScale" then
		return finite(value) and value >= 0.8 and value <= 1.1
	elseif key == "demoValue" then
		return finite(value) and value >= 0 and value <= 100 and value % 1 == 0
	elseif key == "flySpeed" then
		return finite(value) and value >= 100 and value <= 500
	elseif key == "walkSpeed" then
		return finite(value) and value >= 10 and value <= 500
	elseif key == "jumpPower" then
		return finite(value) and value >= 20 and value <= 200
	elseif key == "highlightTransparency" then
		return finite(value) and value >= 0 and value <= 1
	end

	-- String choices
	if key == "demoChoice" then
		return type(value) == "string" and (CHOICES :: any)[value] == true
	elseif key == "demoDestination" then
		return type(value) == "string" and (DESTINATIONS :: any)[value] == true
	elseif key == "selectedTab" then
		return type(value) == "string" and (TABS :: any)[value] == true
	end

	-- Hex color validation
	if key:find("Color") then
		return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
	end

	-- Visual Preset
	if key == "visualPreset" then
		return type(value) == "string" and (value == "Default" or value == "Neon" or value == "Blood" or value == "Ghost" or value == "None")
	end

	-- Theme and Interface
	if key == "theme" then
		return type(value) == "string" and (value == "Default" or value == "Dark" or value == "Neon" or value == "Void")
	end

	-- UI Preset
	if key == "uiPreset" then
		return type(value) == "string" and (value == "Default" or value == "Compact" or value == "Standard" or value == "Wide")
	end

	-- Validation Mode
	if key == "validationMode" then
		return type(value) == "string" and (value == "Strict" or value == "Normal" or value == "Lenient")
	end

	return false
end

function SettingsManager.new(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "SettingsManager requires a Player")

	local folder: Folder? = nil
	for _, child in ipairs(player:GetChildren()) do
		if child.Name == STORAGE_NAME and child:IsA("Folder")
			and child:GetAttribute("Owner") == OWNER and child:GetAttribute("Version") == VERSION then
			folder = child
			break
		end
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = STORAGE_NAME
		folder:SetAttribute("Owner", OWNER)
		folder:SetAttribute("Version", VERSION)
		folder.Parent = player
	end

	local values: { [string]: any } = {}
	for key, default in pairs(DEFAULTS) do
		local stored = folder:GetAttribute(key)
		values[key] = if validate(key, stored) then stored else default
		folder:SetAttribute(key, values[key])
	end

	return setmetatable({ _folder = folder, _values = values } :: Manager, SettingsManager)
end

function SettingsManager.Get(self: Manager, key: string): any
	return self._values[key]
end

function SettingsManager.Set(self: Manager, key: string, value: any): (boolean, string?)
	if not validate(key, value) then
		return false, "Configuracao desconhecida ou valor invalido: " .. tostring(key)
	end
	self._values[key] = value
	self._folder:SetAttribute(key, value)
	return true, nil
end

function SettingsManager.Reset(self: Manager)
	for key, value in pairs(DEFAULTS) do
		self._values[key] = value
		self._folder:SetAttribute(key, value)
	end
end

function SettingsManager.Export(self: Manager): { [string]: any }
	return table.clone(self._values)
end

-- Exposed for local diagnostics/tests; ownership is checked before reuse.
function SettingsManager.GetStorageFolder(self: Manager): Folder
	return self._folder
end

return SettingsManager