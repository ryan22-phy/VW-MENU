--!strict
-- Client-session settings only. No DataStore, filesystem or cross-session promise.
local SettingsManager = {}
SettingsManager.__index = SettingsManager

local STORAGE_NAME = "VWMenu_Settings_v1"
local OWNER = "VWMenu"
local VERSION = 1
local DEFAULTS: { [string]: any } = {
	reducedMotion = false,
	uiScale = 1,
	demoEnabled = false,
	demoValue = 50,
	demoChoice = "Equilibrado",
	demoDestination = "Laboratorio",
	selectedTab = "Main",
}
local CHOICES = { Equilibrado = true, Rapido = true, Preciso = true }
local DESTINATIONS = { Laboratorio = true, Praca = true, Oficina = true }
local TABS = { Main = true, Player = true, Visual = true, Teleport = true, Settings = true }
type Manager = { _folder: Folder, _values: { [string]: any } }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validate(key: string, value: any): boolean
	if key == "reducedMotion" or key == "demoEnabled" then
		return type(value) == "boolean"
	elseif key == "uiScale" then
		return finite(value) and value >= 0.8 and value <= 1.1
	elseif key == "demoValue" then
		return finite(value) and value >= 0 and value <= 100 and value % 1 == 0
	elseif key == "demoChoice" then
		return type(value) == "string" and (CHOICES :: any)[value] == true
	elseif key == "demoDestination" then
		return type(value) == "string" and (DESTINATIONS :: any)[value] == true
	elseif key == "selectedTab" then
		return type(value) == "string" and (TABS :: any)[value] == true
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
