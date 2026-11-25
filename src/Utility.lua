-- Universal utility functions for VW MENU framework.
-- Helper functions, type checkers, and common operations.

local Utility = {}

-- // Type checking \\ --
function Utility.IsNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Utility.IsVector(value)
	return type(value) == "Vector3" or type(value) == "Vector2"
end

function Utility.IsCFrame(value)
	return type(value) == "userdata" and value.IsA and value:IsA("CFrame")
end

function Utility.IsTable(value)
	return type(value) == "table"
end

function Utility.IsInstance(value)
	return value and value.IsA and typeof(value) == "Instance"
end

function Utility.IsBoolean(value)
	return type(value) == "boolean"
end

function Utility.IsString(value)
	return type(value) == "string"
end

function Utility.IsFunction(value)
	return type(value) == "function"
end

-- // Math utilities \\ --
function Utility.ClampAngle(angle)
	-- Clamp angle to -pi to pi
	while angle > math.pi do angle = angle - 2 * math.pi end
	while angle < -math.pi do angle = angle + 2 * math.pi end
	return angle
end

function Utility.Vec3ToAngle(vector)
	-- Convert Vector3 to angles
	local magnitude = vector.Magnitude
	if magnitude == 0 then return 0, 0, 0 end
	local pitch = math.asin(vector.Y / magnitude)
	local yaw = math.atan2(vector.X, vector.Z)
	return pitch, yaw, 0
end

function Utility.AngleToVec(pitch, yaw)
	-- Convert angles to Vector3 direction
	local sp, cp = math.sin(pitch), math.cos(pitch)
	return Vector3.new(sp * math.sin(yaw), cp, sp * math.cos(yaw))
end

function Utility.Lerp(start, endValue, alpha)
	return start + (endValue - start) * alpha
end

function Utility.Clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Utility.MapValue(value, inMin, inMax, outMin, outMax)
	return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin)
end

function Utility.Remap(value, inMin, inMax, outMin, outMax)
	return Utility.MapValue(value, inMin, inMax, outMin, outMax)
end

function Utility.Sign(value)
	if value > 0 then return 1 end
	if value < 0 then return -1 end
	return 0
end

-- // Color utilities \\ --
function Utility.Color3ToHex(color)
	if not color then return "#FFFFFF" end
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Utility.HexToColor3(hex)
	if type(hex) ~= "string" then return Color3.new(1, 1, 1) end
	hex = hex:gsub("^#", "")
	if #hex ~= 6 then return Color3.new(1, 1, 1) end
	local r = tonumber("0x" .. hex:sub(1, 2)) / 255
	local g = tonumber("0x" .. hex:sub(3, 4)) / 255
	local b = tonumber("0x" .. hex:sub(5, 6)) / 255
	return Color3.new(r, g, b)
end

function Utility.InterpolateColor(fromColor, toColor, alpha)
	fromColor = fromColor or Color3.new(1, 1, 1)
	toColor = toColor or Color3.new(1, 1, 1)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

function Utility.ColorToHSV(color)
	local r, g, b = color.R, color.G, color.B
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local delta = max - min

	local h, s, v

	v = max

	if max == 0 then
		s = 0
	else
		s = delta / max
	end

	if delta == 0 then
		h = 0
	else
		if max == r then
			h = (g - b) / delta + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / delta + 2
		else
			h = (r - g) / delta + 4
		end
		h = h / 6
	end

	return h, s, v
end

function Utility.HSVToColor(h, s, v)
	local r, g, b

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	if i == 0 then r, g, b = v, t, p
	elseif i == 1 then r, g, b = q, v, p
	elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v
	elseif i == 4 then r, g, b = t, p, v
	else r, g, b = v, p, q
	end

	return Color3.new(r, g, b)
end

-- // Distance utilities \\ --
function Utility.StudsToMeters(studs)
	return studs * 0.28
end

function Utility.MetersToStuds(meters)
	return meters / 0.28
end

function Utility.Get3DDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

function Utility.Get2DDistance(pos1, pos2)
	local diff = pos1 - pos2
	return math.sqrt(diff.X^2 + diff.Y^2)
end

function Utility.GetAngleBetween(pos1, pos2, origin)
	local v1 = (pos1 - origin).Unit
	local v2 = (pos2 - origin).Unit
	return math.acos(v1:Dot(v2))
end

-- // String utilities \\ --
function Utility.FormatTime(seconds)
	if seconds < 60 then return string.format("%.0fs", seconds) end
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60
	return string.format("%dm %ds", minutes, seconds)
end

function Utility.WordWrap(text, maxWidth)
	local words = {}
	for word in text:gmatch("%S+") do
		table.insert(words, word)
	end

	local lines = {}
	local currentLine = ""

	for _, word in ipairs(words) do
		local testLine = currentLine == "" and word or currentLine .. " " .. word
		if #testLine <= maxWidth then
			currentLine = testLine
		else
			if currentLine ~= "" then
				table.insert(lines, currentLine)
			end
			currentLine = word
		end
	end

	if currentLine ~= "" then
		table.insert(lines, currentLine)
	end

	return table.concat(lines, "\n")
end

function Utility.Capitalize(text)
	if not text or text == "" then return "" end
	return text:gsub("^%l", string.upper)
end

function Utility.ToLower(text)
	if not text then return "" end
	return text:lower()
end

function Utility.ToUpper(text)
	if not text then return "" end
	return text:upper()
end

function Utility.StartsWith(text, prefix)
	if not text then return false end
	return text:sub(1, #prefix) == prefix
end

function Utility.EndsWith(text, suffix)
	if not text then return false end
	return text:sub(-#suffix) == suffix
end

function Utility.Split(text, delimiter)
	local result = {}
	for part in text:gmatch("[^" .. delimiter .. "]+") do
		table.insert(result, part)
	end
	return result
end

function Utility.Join(parts, delimiter)
	return table.concat(parts, delimiter)
end

-- // Array/Table utilities \\ --
function Utility.TableContains(table, value)
	for _, v in ipairs(table) do
		if v == value then return true end
	end
	return false
end

function Utility.TableCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = Utility.TableCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Utility.TableFlatten(orig)
	local result = {}
	for _, v in ipairs(orig) do
		if type(v) == "table" then
			for _, item in ipairs(v) do
				table.insert(result, item)
			end
		else
			table.insert(result, v)
		end
	end
	return result
end

function Utility.TableKeys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	return keys
end

function Utility.TableValues(t)
	local values = {}
	for _, v in pairs(t) do
		table.insert(values, v)
	end
	return values
end

function Utility.TableSize(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

function Utility.TableClear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function Utility.TableFilter(t, predicate)
	local result = {}
	for k, v in pairs(t) do
		if predicate(k, v) then
			result[k] = v
		end
	end
	return result
end

function Utility.TableMap(t, mapper)
	local result = {}
	for k, v in pairs(t) do
		result[k] = mapper(k, v)
	end
	return result
end

function Utility.TableSort(t, comparator)
	local keys = Utility.TableKeys(t)
	table.sort(keys, comparator)
	local result = {}
	for _, k in ipairs(keys) do
		table.insert(result, t[k])
	end
	return result
end

-- // Time utilities \\ --
function Utility.GetTimestamp()
	return tick()
end

function Utility.GetReadableTimestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

function Utility.TimeSince(timestamp)
	return tick() - timestamp
end

-- // Random utilities \\ --
function Utility.RandomColor()
	return Color3.new(math.random(), math.random(), math.random())
end

function Utility.RandomHexColor()
	return string.format("#%06X", math.random(0, 0xFFFFFF))
end

function Utility.RandomInt(min, max)
	return math.random(min, max)
end

function Utility.RandomFloat(min, max)
	return min + (max - min) * math.random()
end

function Utility.RandomChoice(choices)
	if #choices == 0 then return nil end
	return choices[math.random(1, #choices)]
end

-- // Instance utilities \\ --
function Utility.ClearAllChildren(parent)
	if not parent then return end
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

function Utility.GetDescendantsOfClass(parent, className)
	local results = {}
	for _, child in ipairs(parent:GetDescendants()) do
		if child:IsA(className) then
			table.insert(results, child)
		end
	end
	return results
end

function Utility.FindFirstChildWithAttribute(parent, attributeName, attributeValue)
	for _, child in ipairs(parent:GetChildren()) do
		local attr = child:GetAttribute(attributeName)
		if attr == attributeValue then
			return child
		end
	end
	return nil
end

function Utility.GetDescendantsWithTag(parent, tag)
	local results = {}
	for _, descendant in ipairs(parent:GetDescendants()) do
		local attribute = descendant:GetAttribute("Tag")
		if attribute == tag then
			table.insert(results, descendant)
		end
	end
	return results
end

function Utility.CloneInstance(instance, parent)
	if not instance or not instance:IsA("Instance") then return nil end

	local clone = instance:Clone()
	if parent then
		clone.Parent = parent
	end
	return clone
end

-- // Validation utilities \\ --
function Utility.ValidateHexColor(hex)
	if type(hex) ~= "string" then return false end
	return hex:match("^#%x%x%x%x%x%x$") ~= nil
end

function Utility.ValidateUUID(uuid)
	if type(uuid) ~= "string" then return false end
	return uuid:match("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$") ~= nil
end

function Utility.IsValidEmail(email)
	if type(email) ~= "string" then return false end
	return email:match("^[^%@]+@[^%@]+%.[^%@]+$") ~= nil
end

function Utility.IsValidUrl(url)
	if type(url) ~= "string" then return false end
	return url:match("^https?://") ~= nil
end

-- // Format utilities \\ --
function Utility.FormatNumber(num, decimalPlaces)
	decimalPlaces = decimalPlaces or 0
	return string.format("%." .. decimalPlaces .. "f", num)
end

function Utility.FormatBytes(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	elseif bytes < 1024^2 then
		return string.format("%.2f KB", bytes / 1024)
	elseif bytes < 1024^3 then
		return string.format("%.2f MB", bytes / 1024^2)
	else
		return string.format("%.2f GB", bytes / 1024^3)
	end
end

function Utility.PadLeft(text, length, padChar)
	padChar = padChar or " "
	if #text >= length then return text end
	return string.rep(padChar, length - #text) .. text
end

function Utility.PadRight(text, length, padChar)
	padChar = padChar or " "
	if #text >= length then return text end
	return text .. string.rep(padChar, length - #text)
end

-- // Object utilities \\ --
function Utility.CreateObject(className, properties, parent)
	local obj = Instance.new(className)
	for propName, propValue in pairs(properties or {}) do
		obj[propName] = propValue
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

function Utility.DestroyAll(tag)
	-- Destroy all objects with a specific tag
	local tagAttribute = tag or "Destroyable"
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:GetAttribute("Tag") == tagAttribute then
			obj:Destroy()
		end
	end
end

-- // Deep copy utilities \\ --
function Utility.DeepCopy(obj, seen)
	if type(obj) ~= "table" then return obj end
	if seen and seen[obj] then return seen[obj] end

	seen = seen or {}
	local copy = {}
	seen[obj] = copy

	for k, v in pairs(obj) do
		copy[Utility.DeepCopy(k, seen)] = Utility.DeepCopy(v, seen)
	end

	return setmetatable(copy, Utility.DeepCopy(getmetatable(obj), seen))
end

return Utility