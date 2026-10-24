-- Run this ModuleScript from the CLIENT Command Bar in a local Studio play session:
-- require(path.to.Support)(path.to.Modules, game:GetService("Players").LocalPlayer)
-- Tests only this client's temporary objects and the owned settings folder.
return function(modules: Instance, player: Player)
	local CleanupManager = require(modules:WaitForChild("CleanupManager"))
	local SettingsManager = require(modules:WaitForChild("SettingsManager"))
	local total = 0
	local function check(condition: boolean, message: string)
		total += 1
		assert(condition, message)
	end

	local order = {}
	local cleanup = CleanupManager.new()
	cleanup:Add(function() table.insert(order, "first") end)
	cleanup:Add(function() table.insert(order, "second") end)
	local removed = function() error("Removed callback must not run") end
	cleanup:Add(removed)
	check(cleanup:Remove(removed), "Remove should find a registered item")
	check(not cleanup:Remove(removed), "Remove should not find an absent item")
	local immediateCount = 0
	local immediate = function() immediateCount += 1 end
	cleanup:Add(immediate)
	cleanup:Remove(immediate, true)
	check(immediateCount == 1, "Remove(cleanNow) must clean exactly once")
	local event = Instance.new("BindableEvent")
	local connection = event.Event:Connect(function() end)
	cleanup:Add(event)
	cleanup:Add(connection)
	cleanup:Destroy()
	cleanup:Destroy()
	check(not connection.Connected, "Destroy must disconnect RBXScriptConnections")
	check(#order == 2 and order[1] == "second" and order[2] == "first", "Cleanup must be LIFO and idempotent")
	cleanup:Add(function() immediateCount += 1 end)
	check(immediateCount == 2, "Adding after Destroy must clean immediately")
	local custom = { count = 0 }
	function custom:Release() self.count += 1 end
	local customCleanup = CleanupManager.new()
	customCleanup:Add(custom, "Release")
	customCleanup:Destroy()
	check(custom.count == 1, "Explicit cleanup method must be invoked with self")
	local protectedCleanup = CleanupManager.new()
	local afterFailure = false
	protectedCleanup:Add(function() afterFailure = true end)
	protectedCleanup:Add(function() error("Intentional cleanup failure used by Support.spec") end)
	protectedCleanup:Destroy()
	check(afterFailure, "A cleanup failure must not prevent later cleanup")

	local settings = SettingsManager.new(player)
	local original = settings:Export()
	settings:Reset()
	check(settings:Get("demoValue") == 50, "Default value mismatch")
	check(settings:Get("demoDestination") == "Laboratorio", "Default destination mismatch")
	local invalid = {
		{ "reducedMotion", "true" }, { "uiScale", 0 / 0 },
		{ "uiScale", math.huge }, { "uiScale", -math.huge },
		{ "uiScale", 0.79 }, { "uiScale", 1.11 },
		{ "demoValue", -1 }, { "demoValue", 101 }, { "demoValue", 4.5 },
		{ "demoChoice", "Unknown" }, { "demoDestination", "Unknown" },
		{ "selectedTab", "Unknown" }, { "unknownKey", true },
	}
	for _, item in ipairs(invalid) do
		local accepted, reason = settings:Set(item[1], item[2])
		check(not accepted and type(reason) == "string", "Invalid setting was accepted: " .. item[1])
	end
	check(settings:Get("uiScale") == 1, "Invalid writes must preserve existing values")
	check(settings:Set("uiScale", 0.8), "Minimum scale should be valid")
	check(settings:Set("demoValue", 0), "Minimum slider value should be valid")
	check(settings:Set("demoValue", 100), "Maximum slider value should be valid")
	check(settings:Set("demoEnabled", true), "Boolean setting should be valid")
	check(settings:Set("selectedTab", "Visual"), "Known tab should be valid")
	local snapshot = settings:Export()
	snapshot.demoValue = 12
	check(settings:Get("demoValue") == 100, "Export must return an independent copy")
	local rerun = SettingsManager.new(player)
	check(rerun:Get("demoEnabled") == true and rerun:Get("selectedTab") == "Visual", "Settings must survive manager reinitialization in the same client session")
	check(rerun:Get("demoValue") == 100, "Rerun must preserve valid values")
	local folder = rerun:GetStorageFolder()
	check(folder:GetAttribute("Owner") == "VWMenu" and folder:GetAttribute("Version") == 1, "Settings folder must carry explicit ownership and schema version")
	folder:SetAttribute("demoValue", "invalid")
	local invalidStored = SettingsManager.new(player)
	check(invalidStored:Get("demoValue") == 50, "Invalid persisted attributes must be ignored")
	for key, value in pairs(original) do
		local accepted = invalidStored:Set(key, value)
		check(accepted, "Could not restore original setting: " .. key)
	end
	local foreignFolder = Instance.new("Folder")
	foreignFolder.Name = "VWMenu_Settings_v1"
	foreignFolder:SetAttribute("Sentinel", "foreign")
	foreignFolder.Parent = player
	local afterForeign = SettingsManager.new(player)
	check(afterForeign:GetStorageFolder() == folder, "Manager must reuse only its owned versioned folder")
	check(foreignFolder:GetAttribute("Sentinel") == "foreign" and foreignFolder:GetAttribute("Owner") == nil, "Manager must not modify unrelated instances with matching names")
	foreignFolder:Destroy()
	print(string.format("VW MENU support: %d assertions passed.", total))
	return total
end
