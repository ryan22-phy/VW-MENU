--!strict
-- Owns resources for one controller. Destroy is protected, LIFO and idempotent.
local CleanupManager = {}
CleanupManager.__index = CleanupManager

type Entry = { item: any, methodName: string? }
type Manager = { _items: { Entry }, _destroyed: boolean }

local function clean(entry: Entry)
	local success, failure = pcall(function()
		local item = entry.item
		if entry.methodName then
			local method = item[entry.methodName]
			assert(type(method) == "function", "Cleanup method is not a function")
			method(item)
		elseif typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif type(item) == "function" then
			item()
		elseif type(item) == "table" and type(item.Destroy) == "function" then
			item:Destroy()
		else
			error("Unsupported cleanup resource")
		end
	end)
	if not success then
		warn("[VW MENU] Cleanup failed: " .. tostring(failure))
	end
end

function CleanupManager.new()
	return setmetatable({ _items = {}, _destroyed = false } :: Manager, CleanupManager)
end

function CleanupManager.Add(self: Manager, item: any, methodName: string?): any
	local entry: Entry = { item = item, methodName = methodName }
	if self._destroyed then
		clean(entry)
	else
		table.insert(self._items, entry)
	end
	return item
end

-- Remove every registration for this resource; optional cleanup happens once.
function CleanupManager.Remove(self: Manager, item: any, cleanNow: boolean?): boolean
	local found: Entry? = nil
	for index = #self._items, 1, -1 do
		local entry = self._items[index]
		if entry.item == item then
			found = found or entry
			table.remove(self._items, index)
		end
	end
	if found and cleanNow then
		clean(found)
	end
	return found ~= nil
end

function CleanupManager.Destroy(self: Manager)
	if self._destroyed then return end
	self._destroyed = true
	local entries = self._items
	self._items = {}
	for index = #entries, 1, -1 do
		clean(entries[index])
	end
	table.clear(entries)
end

return CleanupManager
