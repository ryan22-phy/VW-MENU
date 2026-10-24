--!strict
-- Short-lived client toasts. At most three are retained; timers own no manager.
local TweenService = game:GetService("TweenService")
local NotificationManager = {}
NotificationManager.__index = NotificationManager

type Toast = { frame: Frame?, tween: Tween?, cancelled: boolean }
type Manager = { _root: Frame?, _entries: { Toast }, _destroyed: boolean, _nextOrder: number }

local function textLabel(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "VWMenu_ToastText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Text = text
	label.TextSize = size
	label.Font = font
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.RichText = false
	label.Active = false
	label.ZIndex = 52
	label.Parent = parent
	return label
end

local function remove(self: Manager, toast: Toast)
	if toast.cancelled then return end
	toast.cancelled = true
	local index = table.find(self._entries, toast)
	if index then table.remove(self._entries, index) end
	if toast.tween then
		toast.tween:Cancel()
		toast.tween:Destroy()
		toast.tween = nil
	end
	if toast.frame then
		toast.frame:Destroy()
		toast.frame = nil
	end
end

function NotificationManager.new(parentScreenGui: ScreenGui, cleanup: any)
	assert(parentScreenGui:IsA("ScreenGui"), "NotificationManager requires a ScreenGui")
	local root = Instance.new("Frame")
	root.Name = "VWMenu_Notifications"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 16)
	root.Size = UDim2.new(1, -32, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = 50
	root.Parent = parentScreenGui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(320, math.huge)
	constraint.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = root
	local self = setmetatable({ _root = root, _entries = {}, _destroyed = false, _nextOrder = 0 } :: Manager, NotificationManager)
	if cleanup then cleanup:Add(self) end
	return self
end

function NotificationManager.Push(self: Manager, title: string, message: string, duration: number?): Frame?
	if self._destroyed or not self._root then return nil end
	assert(type(title) == "string" and type(message) == "string", "Toast title and message must be strings")
	local lifetime = duration or 4
	if type(lifetime) ~= "number" or lifetime ~= lifetime or math.abs(lifetime) == math.huge then lifetime = 4 end
	lifetime = math.clamp(lifetime, 1, 15)
	while #self._entries >= 3 do remove(self, self._entries[1]) end
	self._nextOrder += 1
	local frame = Instance.new("Frame")
	frame.Name = "VWMenu_Toast"
	frame.LayoutOrder = self._nextOrder
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.fromRGB(16, 29, 50)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.ZIndex = 51
	frame.Parent = self._root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(23, 54, 90)
	stroke.Transparency = 0.15
	stroke.Thickness = 1
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 11)
	padding.PaddingBottom = UDim.new(0, 11)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 4)
	bodyLayout.Parent = frame
	local heading = textLabel(frame, title, 13, Color3.fromRGB(88, 185, 255), Enum.Font.GothamMedium)
	heading.LayoutOrder = 1
	local body = textLabel(frame, message, 12, Color3.fromRGB(231, 241, 250), Enum.Font.Gotham)
	body.LayoutOrder = 2
	local tween = TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.02 })
	local toast: Toast = { frame = frame, tween = tween, cancelled = false }
	table.insert(self._entries, toast)
	tween:Play()
	-- No long-lived cleanup entry per toast and no task.cancel race. The timer
	-- captures a weak owner reference; removal clears frame/tween immediately.
	local weakOwner = setmetatable({ self }, { __mode = "v" })
	task.delay(lifetime, function()
		local owner = weakOwner[1]
		if owner and not owner._destroyed and not toast.cancelled then remove(owner, toast) end
	end)
	return frame
end

function NotificationManager.Destroy(self: Manager)
	if self._destroyed then return end
	self._destroyed = true
	while #self._entries > 0 do remove(self, self._entries[#self._entries]) end
	if self._root then self._root:Destroy(); self._root = nil end
end

return NotificationManager
