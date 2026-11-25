-- Interface utilities: search, themes, module manager.
-- Independent features that work across multiple authorized experiences.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = {}
Interface.__index = Interface

-- // Search functionality \\ --
function Interface.new(searchCallback, context)
	local self = setmetatable({
		SearchQuery = "",
		SearchResults = {},
		_RecentSearch = {},
		_MaxRecent = 10,
		.OnSearchChange = searchCallback or function() end,
		_Context = context or {},
		_TabIndex = 1,
		_Tabs = {},
		_SelectedTab = "Main",
	}, Interface)
	return self
end

function Interface:SetSearchQuery(query)
	self.SearchQuery = query or ""

	-- Update recent searches
	if self.SearchQuery ~= "" and not self._RecentSearch[self.SearchQuery] then
		table.insert(self._RecentSearch, 1, self.SearchQuery)
		if #self._RecentSearch > self._MaxRecent then
			table.remove(self._RecentSearch)
		end
	end

	self:_performSearch()
end

function Interface:GetSearchResults()
	return self.SearchResults or {}
end

function Interface:GetRecentSearches()
	return self._RecentSearch or {}
end

function Interface:ClearRecentSearches()
	self._RecentSearch = {}
end

function Interface:_performSearch()
	-- Default search: filter features by name/description
	local query = self.SearchQuery:lower()
	local results = {}

	-- This will be called from the UI controller to filter tabs/features
	-- Actual implementation depends on the registered features

	self.SearchResults = results
	self:_onSearchChange()
end

function Interface:_onSearchChange()
	if self.OnSearchChange then
		self.OnSearchChange(self.SearchQuery, self.SearchResults)
	end
end

-- // Tab Management \\
function Interface:SetTabIndex(index)
	self._TabIndex = index
end

function Interface:GetTabIndex()
	return self._TabIndex
end

function Interface:RegisterTab(id, name)
	if not self._Tabs[id] then
		self._Tabs[id] = { Name = name, Id = id }
	end
	return self._Tabs[id]
end

function Interface:GetCurrentTab()
	return self._SelectedTab
end

function Interface:SetCurrentTab(tabId)
	if self._Tabs[tabId] then
		self._SelectedTab = tabId
		return true
	end
	return false
end

function Interface:SelectNextTab()
	local tabIds = {}
	for id in pairs(self._Tabs) do
		table.insert(tabIds, id)
	end

	if #tabIds == 0 then return end

	table.sort(tabIds)
	local currentIndex = table.find(tabIds, self._SelectedTab) or 0
	local nextIndex = (currentIndex % #tabIds) + 1
	self._SelectedTab = tabIds[nextIndex]

	return self._SelectedTab
end

function Interface:SelectPreviousTab()
	local tabIds = {}
	for id in pairs(self._Tabs) do
		table.insert(tabIds, id)
	end

	if #tabIds == 0 then return end

	table.sort(tabIds)
	local currentIndex = table.find(tabIds, self._SelectedTab) or 1
	local prevIndex = currentIndex == 1 and #tabIds or currentIndex - 1
	self._SelectedTab = tabIds[prevIndex]

	return self._SelectedTab
end

-- // Theme system \\ -
Interface.Themes = {
	Dark = {
		background = Color3.fromRGB(11, 14, 20),
		panel = Color3.fromRGB(16, 36, 65),
		secondary = Color3.fromRGB(25, 55, 88),
		accent = Color3.fromRGB(66, 173, 255),
		text = Color3.fromRGB(231, 241, 250),
		muted = Color3.fromRGB(146, 168, 191),
		off = Color3.fromRGB(57, 75, 96),
	},
	Neon = {
		background = Color3.fromRGB(10, 10, 10),
		panel = Color3.fromRGB(20, 20, 30),
		secondary = Color3.fromRGB(30, 30, 45),
		accent = Color3.fromRGB(0, 220, 255),
		text = Color3.fromRGB(220, 240, 255),
		muted = Color3.fromRGB(180, 180, 200),
		off = Color3.fromRGB(50, 50, 70),
	},
	Void = {
		background = Color3.fromRGB(5, 5, 5),
		panel = Color3.fromRGB(15, 15, 15),
		secondary = Color3.fromRGB(25, 25, 25),
		accent = Color3.fromRGB(100, 100, 255),
		text = Color3.fromRGB(200, 200, 210),
		muted = Color3.fromRGB(120, 120, 130),
		off = Color3.fromRGB(40, 40, 40),
	},
}

function Interface:SetTheme(themeName)
	local theme = self.Themes[themeName]
	if not theme then
		warn("[Interface] Unknown theme: " .. tostring(themeName))
		return false
	end

	self.CurrentTheme = theme
	self:_applyTheme()
	return true
end

function Interface:GetCurrentTheme()
	return self.CurrentTheme
end

function Interface:GetAvailableThemes()
	local themes = {}
	for name, _ in pairs(self.Themes) do
		table.insert(themes, name)
	end
	return themes
end

function Interface:_applyTheme()
	-- Apply theme to UI elements
	-- This will be called via the Context UI controller
	if self._Context and self._Context.UI then
		-- Theme application logic would go here
		-- For now, just notify through callbacks
		if self.OnThemeChange then
			self.OnThemeChange(self.CurrentTheme)
		end
	end
end

function Interface:RegisterTheme(name, colors)
	-- Allow registering custom themes
	self.Themes[name] = colors
	return true
end

-- // Module Manager \\ --
function Interface:LoadModule(moduleName)
	local success, module = pcall(function()
		return require(self._Context.Parent:FindFirstChild(moduleName))
	end)

	if success and module then
		return module
	else
		warn("[Interface] Failed to load module: " .. moduleName)
		return nil
	end
end

function Interface:IsModuleAvailable(moduleName)
	local module = self._Context.Parent:FindFirstChild(moduleName)
	return module ~= nil
end

-- // Profile/Config management \\ --
function Interface.CreateProfile(name, settings)
	return {
		Name = name or "Untitled",
		Settings = settings or {},
		CreatedAt = tick(),
		ModifiedAt = tick(),
	}
end

function Interface:SaveProfile(profile, displayName)
	-- Session-only storage (no DataStore)
	-- In a real implementation, this could use player:GetAttribute() or a module
	self._CurrentProfile = profile
	if displayName then
		self._CurrentProfile.Name = displayName
	end
	self._CurrentProfile.ModifiedAt = tick()
	return true
end

function Interface:LoadProfile(name)
	if self._CurrentProfile and self._CurrentProfile.Name == name then
		return self._CurrentProfile
	end

	-- Return default profile
	return self.CreateProfile(name or "Default", {
		-- Default settings
	})
end

function Interface:ApplyProfileSettings(profile, context)
	if not profile or not profile.Settings then return end

	-- Apply each setting to the appropriate module
	for key, value in pairs(profile.Settings) do
		local setter = context[key .. "Set"]
		if setter and type(setter) == "function" then
			setter(context, key, value)
		end
	end
end

-- // Notifications helper \\ --
function Interface:ShowNotification(title, text, duration)
	duration = duration or 3

	-- Integration with NotificationManager
	local notify = self._Context.Parent and
		require(self._Context.Parent.Parent.NotificationManager)

	if notify then
		notify:Push(title, text, duration)
	else
		warn("[Interface] Notification: " .. title .. " - " .. text)
	end
end

-- // Performance monitoring \\ --
function Interface:StartPerformanceMonitor(callback, interval)
	interval = interval or 1
	self._PerfConn = RunService.Heartbeat:Connect(function()
		self._PerfAccumulator = (self._PerfAccumulator or 0) + interval
		if self._PerfAccumulator >= interval then
			local fps = RunService:GetFPS()
			if callback then
				callback(fps)
			end
			self._PerfAccumulator = 0
		end
	end)
end

function Interface:StopPerformanceMonitor()
	if self._PerfConn then
		self._PerfConn:Disconnect()
		self._PerfConn = nil
	end
end

-- // Keybinds management \\ --
function Interface:RegisterKeybind(keyCode, description, callback, toggleMode)
	-- toggleMode: "hold", "toggle", "press"
	if not self._Keybinds then
		self._Keybinds = {}
	end

	self._Keybinds[keyCode.Value] = {
		KeyCode = keyCode,
		Description = description,
		Callback = callback,
		Mode = toggleMode or "press",
		Active = false,
	}

	-- Connect to input if not already
	if not self._InputConn then
		self._InputConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			local bind = self._Keybinds[input.KeyCode.Value]
			if bind then
				if bind.Mode == "toggle" then
					bind.Active = not bind.Active
					if bind.Active then
						bind.Callback(true)
					end
				elseif bind.Mode == "hold" then
					bind.Active = true
					bind.Callback(true)
				end
			end
		end)
		self._InputEndedConn = UserInputService.InputEnded:Connect(function(input)
			local bind = self._Keybinds[input.KeyCode.Value]
			if bind then
				if bind.Mode == "toggle" then
					-- Do nothing
				elseif bind.Mode == "hold" then
					bind.Active = false
					bind.Callback(false)
				end
			end
		end)
	end

	return true
end

function Interface:UnregisterKeybind(keyCode)
	if self._Keybinds then
		self._Keybinds[keyCode.Value] = nil
	end
end

function Interface:RebindKeybind(keyCode, newCode)
	local bind = self._Keybinds[keyCode]
	if bind then
		self._Keybinds[newCode] = bind
		self._Keybinds[keyCode] = nil
		bind.KeyCode = newCode
		return true
	end
	return false
end

function Interface:GetRegisteredKeybinds()
	return self._Keybinds or {}
end

function Interface:ClearAllKeybinds()
	self._Keybinds = {}
end

-- // Session ID \\ --
function Interface:GetSessionId()
	if not self._SessionId then
		self._SessionId = HttpService:GenerateGUID(false)
	end
	return self._SessionId
end

-- // Profile management \\ --
function Interface:GetProfiles()
	if self._Profiles then
		return self._Profiles
	end
	self._Profiles = {}
	return self._Profiles
end

function Interface:AddProfile(name, settings)
	local profiles = self:GetProfiles()
	profiles[name] = self.CreateProfile(name, settings)
	return profiles[name]
end

function Interface:RemoveProfile(name)
	if self._Profiles and self._Profiles[name] then
		self._Profiles[name] = nil
		return true
	end
	return false
end

-- // Cleanup \\ --
function Interface:Destroy()
	-- Cleanup connections
	if self._InputConn then
		self._InputConn:Disconnect()
		self._InputConn = nil
	end
	if self._InputEndedConn then
		self._InputEndedConn:Disconnect()
		self._InputEndedConn = nil
	end
	if self._PerfConn then
		self._PerfConn:Disconnect()
		self._PerfConn = nil
	end
	if self._RainbowConn then
		self._RainbowConn:Disconnect()
		self._RainbowConn = nil
	end
	if self._UpdateThread then
		if self._UpdateThread.Connected then
			self._UpdateThread:Disconnect()
		end
		self._UpdateThread = nil
	end
end

return Interface