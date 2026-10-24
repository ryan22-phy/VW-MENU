-- Independent VW MENU presentation layer. All gameplay remains outside this module.
-- The caller owns cleanup and registers every connection through cleanup:Add().
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local UIController = {}
UIController.__index = UIController

local C = {
	Background = Color3.fromRGB(9, 13, 20),
	Panel = Color3.fromRGB(16, 29, 50),
	Secondary = Color3.fromRGB(23, 54, 90),
	Accent = Color3.fromRGB(88, 185, 255),
	Hover = Color3.fromRGB(128, 206, 255),
	Text = Color3.fromRGB(231, 241, 250),
	Muted = Color3.fromRGB(146, 168, 191),
	Off = Color3.fromRGB(57, 75, 96),
}

local function make(className, props, parent)
	local item = Instance.new(className)
	for property, value in pairs(props) do item[property] = value end
	item.Parent = parent
	return item
end

local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function label(parent, name, text, size, color, position, dimensions)
	return make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Text = text,
		Font = Enum.Font.Gotham, TextSize = size, TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = position or UDim2.new(), Size = dimensions or UDim2.fromScale(1, 1),
	}, parent)
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function UIController:_connect(signal, callback)
	return self._cleanup:Add(signal:Connect(callback))
end

function UIController:_tween(object, values, duration)
	local previous = self._tweens[object]
	if previous then previous:Cancel() end
	if self._reducedMotion then
		for property, value in pairs(values) do object[property] = value end
		self._tweens[object] = nil
		return
	end
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), values)
	self._tweens[object] = tween
	tween:Play()
end

function UIController:_invoke(callback, ...)
	if not callback then return end
	local ok, problem = pcall(callback, ...)
	if not ok then warn("[VW MENU] Callback: " .. tostring(problem)) end
end

function UIController:_button(parent, name, text, dimensions, position)
	local button = make("TextButton", {
		Name = name, Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = C.Text, BackgroundColor3 = C.Secondary, BorderSizePixel = 0,
		AutoButtonColor = false, Size = dimensions, Position = position or UDim2.new(),
		Selectable = true,
	}, parent)
	corner(button)
	local hoverStroke = make("UIStroke", {
		Color = C.Hover, Thickness = 1, Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	table.insert(self._focusables, button)
	self:_connect(button.MouseEnter, function()
		self:_tween(button, { BackgroundColor3 = C.Off })
		self:_tween(hoverStroke, { Transparency = 0.6 })
	end)
	self:_connect(button.MouseLeave, function()
		self:_tween(button, { BackgroundColor3 = C.Secondary })
		self:_tween(hoverStroke, { Transparency = 1 })
	end)
	return button
end

function UIController.new(parent, cleanup)
	assert(parent and parent:IsA("PlayerGui"), "UIController requires a PlayerGui")
	assert(cleanup and type(cleanup.Add) == "function", "UIController requires cleanup:Add")
	local self = setmetatable({
		_cleanup = cleanup, _tweens = {}, _open = true, _reducedMotion = false,
		_userScale = 1, _effectiveScale = 1, _controlKeys = {}, _openDropdown = nil,
		Tabs = {}, Controls = {}, _tabOrder = {}, _positioned = false,
		_focusables = {}, _keyboardActions = {},
	}, UIController)

	self.Gui = make("ScreenGui", {
		Name = "VWMenu_Client_v1", ResetOnSpawn = false, DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false,
	}, parent)
	self.Gui:SetAttribute("Owner", "VWMenu")
	self.Gui:SetAttribute("Version", 1)
	cleanup:Add(self.Gui)
	self._safe = make("Frame", { Name = "SafeArea", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, self.Gui)
	self.Window = make("CanvasGroup", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(610, 390), BackgroundColor3 = C.Background,
		BorderSizePixel = 0, GroupTransparency = 0, ClipsDescendants = true,
	}, self._safe)
	corner(self.Window, 9)
	make("UIStroke", { Color = C.Secondary, Thickness = 1, Transparency = 0.25 }, self.Window)
	self._scale = make("UIScale", { Scale = 1 }, self.Window)

	local header = make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 61) }, self.Window)
	local drag = make("TextButton", { Name = "DragHandle", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -56, 1, 0) }, header)
	make("Frame", { Name = "Indicator", BackgroundColor3 = C.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 21), Size = UDim2.fromOffset(3, 18) }, header)
	local title = label(header, "Brand", "VW MENU", 17, C.Text, UDim2.fromOffset(31, 12), UDim2.fromOffset(155, 24))
	title.Font = Enum.Font.GothamBold
	label(header, "Subtitle", "CONTROL PANEL", 9, C.Muted, UDim2.fromOffset(32, 35), UDim2.fromOffset(155, 13))
	make("Frame", { Name = "HeaderDivider", BorderSizePixel = 0, BackgroundColor3 = C.Secondary, Position = UDim2.new(0, 16, 1, -1), Size = UDim2.new(1, -32, 0, 1) }, header)
	local close = self:_button(header, "Close", "×", UDim2.fromOffset(44, 44), UDim2.new(1, -51, 0, 8))
	close.TextSize = 22
	close.BackgroundTransparency = 1
	self:_connect(close.Activated, function() self:SetOpen(false) end)
	self._keyboardActions[close] = function() self:SetOpen(false) end

	self._sidebar = make("Frame", { Name = "Sidebar", BackgroundColor3 = C.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 61), Size = UDim2.new(0, 155, 1, -61) }, self.Window)
	self._nav = make("ScrollingFrame", {
		Name = "Navigation", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 13), Size = UDim2.new(1, -20, 1, -54),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.Secondary,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, self._sidebar)
	make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, self._nav)
	self._footer = label(self._sidebar, "Shortcut", "CTRL  /  TOGGLE", 9, C.Muted, UDim2.new(0, 16, 1, -30), UDim2.new(1, -24, 0, 15))
	self._content = make("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(173, 76), Size = UDim2.new(1, -191, 1, -90) }, self.Window)

	-- This touch target lives outside the animated CanvasGroup and survives closing.
	self._launcher = self:_button(self._safe, "Launcher", "VW", UDim2.fromOffset(48, 44), UDim2.new(1, -62, 1, -59))
	self._launcher.ZIndex = 20
	self._launcher.TextColor3 = C.Accent
	self:_connect(self._launcher.Activated, function() self:SetOpen(not self._open) end)
	self._keyboardActions[self._launcher] = function() self:SetOpen(not self._open) end

	self:_connect(drag.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		self._drag = { Input = input, Start = Vector2.new(input.Position.X, input.Position.Y),
			Center = self.Window.AbsolutePosition + self.Window.AbsoluteSize / 2 - self._safe.AbsolutePosition }
	end)
	self:_connect(UserInputService.InputChanged, function(input)
		local point = Vector2.new(input.Position.X, input.Position.Y)
		if self._drag and (input == self._drag.Input or input.UserInputType == Enum.UserInputType.MouseMovement) then
			self:_place(self._drag.Center + point - self._drag.Start)
		end
		if self._sliderDrag and (input == self._sliderDrag.Input or input.UserInputType == Enum.UserInputType.MouseMovement) then
			self._sliderDrag.Update(point.X)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then self._controlKeys[input.KeyCode] = nil end
		if self._drag and (input == self._drag.Input or input.UserInputType == Enum.UserInputType.MouseButton1) then self._drag = nil end
		if self._sliderDrag and (input == self._sliderDrag.Input or input.UserInputType == Enum.UserInputType.MouseButton1) then self._sliderDrag = nil end
	end)
	self:_connect(UserInputService.InputBegan, function(input, processed)
		local key = input.KeyCode
		if key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
			local held = next(self._controlKeys) ~= nil
			self._controlKeys[key] = true
			if not held and not processed and not UserInputService:GetFocusedTextBox() then self:SetOpen(not self._open) end
			return
		end
		if processed or UserInputService:GetFocusedTextBox() then return end
		if key == Enum.KeyCode.Tab then
			self:_moveFocus(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
			return
		end
		if key == Enum.KeyCode.Return or key == Enum.KeyCode.Space then
			local selected = GuiService.SelectedObject
			local action = self._keyboardActions[selected]
			if action and (self._open or selected == self._launcher) then action() end
			return
		end
		if not self._open then return end
		if key == Enum.KeyCode.Escape and self._openDropdown then self._openDropdown.Close() end
		local slider = self._focusedSlider
		if slider and GuiService.SelectedObject == slider.Instance and (key == Enum.KeyCode.Left or key == Enum.KeyCode.Right) then
			slider.Set(slider.Get() + (key == Enum.KeyCode.Right and slider.Step or -slider.Step), true)
		end
	end)
	self:_connect(UserInputService.WindowFocusReleased, function()
		self._controlKeys = {}; self._drag = nil; self._sliderDrag = nil
	end)
	self:_connect(self._safe:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layout() end)
	cleanup:Add(function()
		if self._visibilityThread then pcall(task.cancel, self._visibilityThread); self._visibilityThread = nil end
		for _, tween in pairs(self._tweens) do tween:Cancel() end
		table.clear(self._tweens)
		self._drag = nil; self._sliderDrag = nil; self._openDropdown = nil
	end)
	self:_layout()
	return self
end

function UIController:_moveFocus(backwards)
	local visible = {}
	for _, button in ipairs(self._focusables) do
		local current, showing = button, true
		if not self._open and button:IsDescendantOf(self.Window) then showing = false end
		while current and current ~= self.Gui do
			if current:IsA("GuiObject") and not current.Visible then showing = false; break end
			current = current.Parent
		end
		if showing and current == self.Gui then table.insert(visible, button) end
	end
	if #visible == 0 then return end
	local index = table.find(visible, GuiService.SelectedObject) or (backwards and 1 or 0)
	GuiService.SelectedObject = visible[((index - 1 + (backwards and -1 or 1)) % #visible) + 1]
end

function UIController:_place(center, size)
	local available = self._safe.AbsoluteSize
	local dimensions = size or Vector2.new(self.Window.Size.X.Offset * self._effectiveScale, self.Window.Size.Y.Offset * self._effectiveScale)
	local half = dimensions / 2
	self.Window.Position = UDim2.fromOffset(
		math.clamp(center.X, math.min(half.X + 8, available.X / 2), math.max(available.X - half.X - 8, available.X / 2)),
		math.clamp(center.Y, math.min(half.Y + 8, available.Y / 2), math.max(available.Y - half.Y - 8, available.Y / 2)))
	self._positioned = true
end

function UIController:_layout()
	local available = self._safe.AbsoluteSize
	if available.X <= 0 or available.Y <= 0 then return end
	local scale = math.min(self._userScale, (available.X - 16) / 280, (available.Y - 16) / 240)
	scale = math.max(scale, 0.1)
	local width = math.min(610, (available.X - 24) / scale)
	local height = math.min(390, (available.Y - 24) / scale)
	local sidebar = width < 490 and 108 or 155
	local center = self._positioned and self.Window.AbsolutePosition + self.Window.AbsoluteSize / 2 - self._safe.AbsolutePosition or available / 2
	self._effectiveScale = scale
	self._scale.Scale = scale
	self.Window.Size = UDim2.fromOffset(width, height)
	self._sidebar.Size = UDim2.new(0, sidebar, 1, -61)
	self._content.Position = UDim2.fromOffset(sidebar + 14, 75)
	self._content.Size = UDim2.new(1, -sidebar - 28, 1, -89)
	self._footer.Text = sidebar < 120 and "CTRL / VW" or "CTRL  /  TOGGLE"
	for _, tab in pairs(self.Tabs) do
		tab.Icon.Visible = sidebar >= 120
		tab.Caption.Position = UDim2.fromOffset(sidebar < 120 and 12 or 36, 0)
		tab.Caption.Size = UDim2.new(1, sidebar < 120 and -20 or -42, 1, 0)
	end
	self:_place(center, Vector2.new(width * scale, height * scale))
end

function UIController:GetGui() return self.Gui end
function UIController:IsOpen() return self._open end
function UIController:SetReducedMotion(value) self._reducedMotion = value == true end
function UIController:SetScale(value)
	if not finite(value) then return end
	self._userScale = math.clamp(value, 0.75, 1.25)
	self:_layout()
end

function UIController:SetOpen(value)
	value = value == true
	if self._open == value then return end
	self._open = value
	self._drag = nil; self._sliderDrag = nil
	local selected = GuiService.SelectedObject
	if not value and selected and selected:IsDescendantOf(self.Window) then GuiService.SelectedObject = nil end
	if self._openDropdown then self._openDropdown.Close() end
	self._launcher.TextColor3 = value and C.Accent or C.Text
	self.Window.Visible = true
	-- CanvasGroup keeps layout stable; only its composited opacity is animated.
	self:_tween(self.Window, { GroupTransparency = value and 0 or 1 }, 0.18)
	local expected = value
	local pending = self._visibilityThread
	if pending then pcall(task.cancel, pending) end
	if not value then
		self._visibilityThread = task.delay(self._reducedMotion and 0 or 0.18, function()
			self._visibilityThread = nil
			if self._open == expected and self.Gui.Parent then self.Window.Visible = false end
		end)
	else
		self._visibilityThread = nil
	end
end

function UIController:AddTab(id, title, description, icon)
	assert(type(id) == "string" and not self.Tabs[id], "Tab Id must be unique")
	local order = #self._tabOrder + 1
	local button = self:_button(self._nav, "Tab_" .. id, "", UDim2.new(1, 0, 0, 44))
	button.LayoutOrder = order
	button.BackgroundTransparency = 1
	local marker = make("Frame", { Name = "Selected", BackgroundColor3 = C.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(2, 20), Visible = false }, button)
	local glyph = label(button, "Icon", icon or "·", 15, C.Muted, UDim2.fromOffset(13, 0), UDim2.new(0, 18, 1, 0))
	local caption = label(button, "Caption", title, 12, C.Muted, UDim2.fromOffset(36, 0), UDim2.new(1, -42, 1, 0))
	local page = make("CanvasGroup", { Name = "Page_" .. id, BackgroundTransparency = 1, GroupTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, self._content)
	local heading = label(page, "Heading", title, 18, C.Text, UDim2.new(), UDim2.new(1, 0, 0, 26))
	heading.Font = Enum.Font.GothamMedium
	label(page, "Description", description or "", 10, C.Muted, UDim2.fromOffset(0, 29), UDim2.new(1, 0, 0, 29)).TextWrapped = true
	local scroll = make("ScrollingFrame", {
		Name = "Controls", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 65), Size = UDim2.new(1, 0, 1, -65),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.Secondary,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, page)
	make("UIPadding", { PaddingRight = UDim.new(0, 7), PaddingBottom = UDim.new(0, 6) }, scroll)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, scroll)
	self.Tabs[id] = { Button = button, Page = page, Scroll = scroll, Marker = marker, Icon = glyph, Caption = caption, Count = 0 }
	table.insert(self._tabOrder, id)
	self:_connect(button.Activated, function() self:SelectTab(id) end)
	self._keyboardActions[button] = function() self:SelectTab(id) end
	self:_layout()
	if not self._selectedTab then self:SelectTab(id) end
	return self.Tabs[id]
end

function UIController:SelectTab(id)
	assert(self.Tabs[id], "Unknown tab: " .. tostring(id))
	if self._openDropdown then self._openDropdown.Close() end
	self._selectedTab = id
	for tabId, tab in pairs(self.Tabs) do
		local selected = tabId == id
		local focused = GuiService.SelectedObject
		if not selected and focused and focused:IsDescendantOf(tab.Page) then GuiService.SelectedObject = self.Tabs[id].Button end
		tab.Page.Visible = selected
		self:_tween(tab.Page, { GroupTransparency = selected and 0 or 1 }, 0.14)
		tab.Marker.Visible = selected
		self:_tween(tab.Button, { BackgroundTransparency = selected and 0 or 1 })
		self:_tween(tab.Caption, { TextColor3 = selected and C.Text or C.Muted })
		tab.Icon.TextColor3 = selected and C.Accent or C.Muted
	end
	self:_invoke(self.OnTabChanged, id)
end

function UIController:_row(tabId, config, height, reserve)
	local tab = assert(self.Tabs[tabId], "Unknown tab")
	assert(type(config.Id) == "string" and not self.Controls[config.Id], "Control Id must be unique")
	tab.Count = tab.Count + 1
	local row = make("Frame", { Name = "Control_" .. config.Id, BackgroundColor3 = C.Panel, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height), LayoutOrder = tab.Count }, tab.Scroll)
	corner(row)
	label(row, "Title", config.Title or config.Id, 12, C.Text, UDim2.fromOffset(12, 9), UDim2.new(1, -(reserve or 24), 0, 20))
	local description = label(row, "Description", config.Description or "", 10, C.Muted, UDim2.fromOffset(12, 30), UDim2.new(1, -(reserve or 24), 0, height - 35))
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextTruncate = Enum.TextTruncate.None
	return row
end

function UIController:AddToggle(tabId, config)
	local row = self:_row(tabId, config, 68, 78)
	local hit = self:_button(row, "Toggle", "", UDim2.fromOffset(58, 48), UDim2.new(1, -65, 0.5, -24))
	hit.BackgroundTransparency = 1
	local track = make("Frame", { Name = "Track", BackgroundColor3 = C.Off, BorderSizePixel = 0, Size = UDim2.fromOffset(38, 20), Position = UDim2.fromOffset(10, 14) }, hit)
	corner(track, 10)
	local knob = make("Frame", { Name = "Thumb", BackgroundColor3 = C.Text, BorderSizePixel = 0, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3) }, track)
	corner(knob, 7)
	local value = config.Value == true
	local handle = { Instance = row }
	function handle.Get() return value end
	function handle.Set(first, second, third)
		local nextValue, fireCallback = first, second
		if first == handle then nextValue, fireCallback = second, third end
		local previous = value
		value = nextValue == true
		self:_tween(track, { BackgroundColor3 = value and C.Accent or C.Off })
		self:_tween(knob, { Position = UDim2.fromOffset(value and 21 or 3, 3), BackgroundColor3 = value and C.Background or C.Text })
		hit:SetAttribute("Value", value)
		if fireCallback and previous ~= value then self:_invoke(config.OnChanged, value) end
	end
	self:_connect(hit.Activated, function() handle.Set(not value, true) end)
	self._keyboardActions[hit] = function() handle.Set(not value, true) end
	handle.Set(value)
	self.Controls[config.Id] = handle
	return handle
end

function UIController:AddSlider(tabId, config)
	local minimum, maximum = config.Min or 0, config.Max or 100
	local step = config.Step or 1
	assert(finite(minimum) and finite(maximum) and maximum > minimum and finite(step) and step > 0, "Invalid slider bounds")
	local row = self:_row(tabId, config, 98, 24)
	row.Description.Size = UDim2.new(1, -24, 0, 21)
	local numberLabel = label(row, "Value", "", 11, C.Accent, UDim2.new(1, -70, 0, 10), UDim2.fromOffset(57, 18))
	numberLabel.TextXAlignment = Enum.TextXAlignment.Right
	row.Title.Size = UDim2.new(1, -90, 0, 20)
	local hit = self:_button(row, "Slider", "", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 51))
	hit.BackgroundTransparency = 1
	local track = make("Frame", { Name = "Track", BorderSizePixel = 0, BackgroundColor3 = C.Secondary, Position = UDim2.new(0, 7, 0.5, -2), Size = UDim2.new(1, -14, 0, 4) }, hit)
	corner(track, 2)
	local fill = make("Frame", { Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = C.Accent, Size = UDim2.new(0, 0, 1, 0) }, track)
	corner(fill, 2)
	local thumb = make("Frame", { Name = "Thumb", BorderSizePixel = 0, BackgroundColor3 = C.Text, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Position = UDim2.fromScale(0, 0.5) }, track)
	corner(thumb, 6)
	local value = minimum
	local handle = { Instance = hit, Row = row, Step = step }
	function handle.Get() return value end
	function handle.Set(first, second, third)
		local nextValue, fireCallback = first, second
		if first == handle then nextValue, fireCallback = second, third end
		if not finite(nextValue) then return end
		local previous = value
		value = math.clamp(minimum + math.floor((math.clamp(nextValue, minimum, maximum) - minimum) / step + 0.5) * step, minimum, maximum)
		local alpha = (value - minimum) / (maximum - minimum)
		fill.Size = UDim2.fromScale(alpha, 1)
		thumb.Position = UDim2.fromScale(alpha, 0.5)
		numberLabel.Text = string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
		hit:SetAttribute("Value", value)
		if fireCallback and previous ~= value then self:_invoke(config.OnChanged, value) end
	end
	local function update(x)
		if track.AbsoluteSize.X > 0 then handle.Set(minimum + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (maximum - minimum), true) end
	end
	self:_connect(hit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._focusedSlider = handle
			self._sliderDrag = { Input = input, Update = update }
			update(input.Position.X)
		end
	end)
	self:_connect(hit.SelectionGained, function() self._focusedSlider = handle end)
	self:_connect(hit.SelectionLost, function() if self._focusedSlider == handle then self._focusedSlider = nil end end)
	handle.Set(config.Value or minimum)
	self.Controls[config.Id] = handle
	return handle
end

function UIController:AddButton(tabId, config)
	local row = self:_row(tabId, config, 104, 24)
	row.Description.Size = UDim2.new(1, -24, 0, 20)
	local button = self:_button(row, "Action", config.ButtonText or "Executar", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 54))
	local handle = { Instance = row }
	function handle.Activate()
		self:_tween(button, { TextColor3 = C.Accent })
		self:_invoke(config.OnActivated)
	end
	self:_connect(button.Activated, handle.Activate)
	self._keyboardActions[button] = handle.Activate
	self.Controls[config.Id] = handle
	return handle
end

function UIController:AddDropdown(tabId, config)
	local options = config.Options or {}
	assert(#options > 0, "Dropdown requires options")
	local valid = {}
	for _, option in ipairs(options) do assert(type(option) == "string", "Dropdown options must be strings"); valid[option] = true end
	local row = self:_row(tabId, config, 110, 24)
	row.Description.Size = UDim2.new(1, -24, 0, 22)
	local button = self:_button(row, "Dropdown", "", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 56))
	button.TextXAlignment = Enum.TextXAlignment.Left
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, button)
	local list = make("ScrollingFrame", { Name = "Options", BackgroundColor3 = C.Background, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 104), Size = UDim2.new(1, -24, 0, math.min(#options * 44, 176)), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 3, Visible = false }, row)
	corner(list)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local expanded, value = false, valid[config.Value] and config.Value or options[1]
	local handles = {}
	local handle = { Instance = row }
	function handle.Get() return value end
	function handle.Set(first, second, third)
		local nextValue, fireCallback = first, second
		if first == handle then nextValue, fireCallback = second, third end
		if not valid[nextValue] then return end
		local previous = value
		value = nextValue
		button.Text = value .. (expanded and "   −" or "   +")
		for option, optionButton in pairs(handles) do optionButton.TextColor3 = option == value and C.Accent or C.Text end
		button:SetAttribute("Value", value)
		if fireCallback and previous ~= value then self:_invoke(config.OnChanged, value) end
	end
	function handle.Close()
		expanded = false; list.Visible = false; row.Size = UDim2.new(1, 0, 0, 110)
		button.Text = value .. "   +"
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(list) then GuiService.SelectedObject = button end
		if self._openDropdown == handle then self._openDropdown = nil end
	end
	for index, option in ipairs(options) do
		local item = self:_button(list, "Option_" .. index, option, UDim2.new(1, -3, 0, 44))
		item.LayoutOrder = index; item.BackgroundTransparency = 1
		handles[option] = item
		self:_connect(item.Activated, function() handle.Set(option, true); handle.Close() end)
		self._keyboardActions[item] = function() handle.Set(option, true); handle.Close() end
	end
	local function toggle()
		if expanded then handle.Close(); return end
		if self._openDropdown then self._openDropdown.Close() end
		expanded = true; self._openDropdown = handle; list.Visible = true
		row.Size = UDim2.new(1, 0, 0, 110 + math.min(#options * 44, 176))
		button.Text = value .. "   −"
	end
	self:_connect(button.Activated, toggle)
	self._keyboardActions[button] = toggle
	handle.Set(value)
	self.Controls[config.Id] = handle
	return handle
end

return UIController
