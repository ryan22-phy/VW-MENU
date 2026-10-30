-- VW MENU v2 | LocalScript cliente | testes autorizados
-- Gerado por tools/build-v2.mjs. Edite src/v2/ e gere novamente.

local __config = (function()
-- Configuration is engine-independent; colors are canonical #RRGGBB strings.
local Config = {}
Config.__index = Config
local report = warn or print

Config.Defaults = table.freeze({
    AimEnabled = false, SmoothSpeed = 6, FOVRadius = 100,
    ShowFOV = true, WallCheck = true, TeamCheck = true,
    TargetLock = false, TargetPart = "Head",
    ESPEnabled = false, Highlight = true, Boxes = true, NameTags = true,
    ShowHealth = true, ShowDistance = true, TeamColors = true, ShowTeammates = true,
    FriendColor = "#42ADFF", EnemyColor = "#FF4D5A", HighlightTransparency = 0.65,
    FOVColor = "#42ADFF", FOVThickness = 1.5, FOVTransparency = 0.4,
    NameColor = "#E7F1FA", BoxColor = "#42ADFF", HighlightColor = "#42ADFF",
    NameColorMode = "Team / Relation", BoxColorMode = "Team / Relation",
    HighlightColorMode = "Team / Relation", ReducedMotion = false,
})
Config.Ranges = table.freeze({
    SmoothSpeed = {1, 30, 1}, FOVRadius = {30, 400, 1},
    HighlightTransparency = {0, 1, 0.05}, FOVThickness = {1, 5, 0.5},
    FOVTransparency = {0, 1, 0.05},
})
local choices = {
    TargetPart = {Head = true, HumanoidRootPart = true},
    NameColorMode = {["Team / Relation"] = true, Custom = true},
    BoxColorMode = {["Team / Relation"] = true, Custom = true},
    HighlightColorMode = {["Team / Relation"] = true, Custom = true},
}

function Config.new()
    return setmetatable({Values = table.clone(Config.Defaults), Listeners = {}, Dead = false}, Config)
end

function Config:Get(key)
    return self.Values[key]
end

function Config:_emit(key, value)
    for callback in pairs(table.clone(self.Listeners)) do
        if self.Listeners[callback] then
            local ok, problem = pcall(callback, key, value)
            if not ok then
                self.LastError = tostring(problem)
                report("[VW MENU] Config: " .. self.LastError)
            end
        end
    end
end

function Config:Set(key, value)
    if self.Dead then return false, "Config descarregada" end
    local default = Config.Defaults[key]
    if default == nil or type(value) ~= type(default) then return false, "Tipo ou chave inválidos" end
    local range = Config.Ranges[key]
    if range then
        if value ~= value or math.abs(value) == math.huge then return false, "Número não finito" end
        value = math.clamp(range[1] + math.floor((math.clamp(value, range[1], range[2]) - range[1]) / range[3] + 0.5) * range[3], range[1], range[2])
    elseif choices[key] then
        if not choices[key][value] then return false, "Opção inválida" end
    elseif type(default) == "string" then
        if not value:match("^#%x%x%x%x%x%x$") then return false, "Use #RRGGBB" end
        value = string.upper(value)
    end
    if self.Values[key] ~= value then
        self.Values[key] = value
        self:_emit(key, value)
    end
    return true
end

function Config:Subscribe(callback)
    assert(not self.Dead, "Config descarregada")
    self.Listeners[callback] = true
    return function() self.Listeners[callback] = nil end
end

function Config:Reset()
    if self.Dead then return end
    self.Values = table.clone(Config.Defaults)
    self:_emit("Reset", nil)
end

function Config:Destroy()
    self.Dead = true
    table.clear(self.Listeners)
end

return Config
end)()

local __cleanup = (function()
-- All connections, instances, callbacks and render bindings belong to this tree.
local Cleanup = {}
Cleanup.__index = Cleanup
local report = warn or print

function Cleanup.new(root)
    local self = setmetatable({Items = {}, NextId = 0, Dead = false}, Cleanup)
    self.Root = root or self
    if not root then self.Connections = 0 end
    return self
end

function Cleanup:_dispose(entry)
    if entry.Connection then self.Root.Connections -= 1 end
    local ok, problem = pcall(entry.Dispose)
    if not ok then
        self.Root.LastError = tostring(problem)
        report("[VW MENU] Cleanup: " .. self.Root.LastError)
    end
end

function Cleanup:Add(resource)
    local kind = typeof(resource)
    local connection = kind == "RBXScriptConnection"
        or (type(resource) == "table" and type(resource.Disconnect) == "function")
    local dispose
    if connection then dispose = function() resource:Disconnect() end
    elseif kind == "Instance" then dispose = function() resource:Destroy() end
    elseif type(resource) == "function" then dispose = resource
    elseif type(resource) == "table" and type(resource.Destroy) == "function" then
        dispose = function() resource:Destroy() end
    else error("Cleanup: recurso sem descarregamento", 2) end
    local entry = {Dispose = dispose, Connection = connection}
    if connection then self.Root.Connections += 1 end
    if self.Dead then self:_dispose(entry)
    else
        self.NextId += 1
        self.Items[self.NextId] = entry
    end
    return resource
end

function Cleanup:Remove(key)
    local entry = self.Items[key]
    if not entry then return end
    self.Items[key] = nil
    self:_dispose(entry)
end

function Cleanup:Scope(key)
    assert(not self.Dead, "Cleanup já descarregado")
    self:Remove(key)
    local child = Cleanup.new(self.Root)
    child.Parent, child.ParentKey = self, key
    self.Items[key] = {Dispose = function() child:Destroy() end}
    return child
end

function Cleanup:ConnectionCount()
    return self.Root.Connections
end

function Cleanup:Destroy()
    if self.Dead then return end
    self.Dead = true
    -- Swap first: cleanup callbacks may themselves release sibling scopes.
    local items = self.Items
    self.Items = {}
    for _, entry in pairs(items) do self:_dispose(entry) end
    if self.Parent then self.Parent.Items[self.ParentKey] = nil end
end

return Cleanup
end)()

local __tracker = (function()
local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

function PlayerTracker.sameTeam(a, b)
    return not a.Neutral and not b.Neutral and a.Team ~= nil and a.Team == b.Team
end

function PlayerTracker.new(services, cleanup)
    local self = setmetatable({Records = {}, Listeners = {}, Services = services, Cleanup = cleanup}, PlayerTracker)
    cleanup:Add(function() table.clear(self.Listeners); table.clear(self.Records) end)
    cleanup:Add(services.Players.PlayerAdded:Connect(function(player) self:_add(player) end))
    cleanup:Add(services.Players.PlayerRemoving:Connect(function(player) self:_remove(player) end))
    for _, player in ipairs(services.Players:GetPlayers()) do self:_add(player) end
    return self
end

function PlayerTracker:Subscribe(callback)
    self.Listeners[callback] = true
    return function() self.Listeners[callback] = nil end
end

function PlayerTracker:_emit(record, reason)
    for callback in pairs(self.Listeners) do callback(record, reason) end
end

function PlayerTracker:IsTeammate(player)
    return PlayerTracker.sameTeam(self.Services.Players.LocalPlayer, player)
end

function PlayerTracker:IsAlive(record)
    return record ~= nil and record.Character ~= nil
        and record.Character:IsDescendantOf(self.Services.Workspace)
        and record.Humanoid ~= nil and record.Humanoid.Health > 0
        and record.Root ~= nil and record.Root:IsDescendantOf(record.Character)
end

function PlayerTracker:_clearCharacter(record)
    record.Scope:Remove("character")
    record.Character, record.Humanoid, record.Head, record.Root = nil, nil, nil, nil
    self:_emit(record, "character")
end

function PlayerTracker:_character(record, character)
    if record.Character == character then return end
    self:_clearCharacter(record)
    if not character then return end
    record.Character = character
    local scope = record.Scope:Scope("character")
    local function refresh()
        if record.Character ~= character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid ~= record.Humanoid then
            scope:Remove("humanoid")
            record.Humanoid = humanoid
            if humanoid then
                local life = scope:Scope("humanoid")
                life:Add(humanoid.HealthChanged:Connect(function() self:_emit(record, "health") end))
                life:Add(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function() self:_emit(record, "health") end))
            end
        end
        local head, root = character:FindFirstChild("Head"), character:FindFirstChild("HumanoidRootPart")
        record.Head = head and head:IsA("BasePart") and head or nil
        record.Root = root and root:IsA("BasePart") and root or nil
        self:_emit(record, "parts")
    end
    local function onChild(child)
        -- ESP-owned Highlights must not trigger recursive overlay construction.
        if child:IsA("Humanoid") or child.Name == "Head" or child.Name == "HumanoidRootPart" then refresh() end
    end
    scope:Add(character.ChildAdded:Connect(onChild))
    scope:Add(character.ChildRemoved:Connect(onChild))
    scope:Add(character.AncestryChanged:Connect(function() self:_emit(record, "ancestry") end))
    refresh()
end

function PlayerTracker:_add(player)
    if self.Records[player] then return end
    local scope = self.Cleanup:Scope(player)
    local record = {Player = player, Scope = scope}
    self.Records[player] = record
    scope:Add(player.CharacterAdded:Connect(function(character) self:_character(record, character) end))
    scope:Add(player.CharacterRemoving:Connect(function(character)
        if record.Character == character then self:_clearCharacter(record) end
    end))
    for _, property in ipairs({"Team", "TeamColor", "Neutral", "DisplayName"}) do
        scope:Add(player:GetPropertyChangedSignal(property):Connect(function() self:_emit(record, "team") end))
    end
    if player.Character then self:_character(record, player.Character) end
    self:_emit(record, "added")
end

function PlayerTracker:_remove(player)
    local record = self.Records[player]
    if not record then return end
    self.Records[player] = nil
    self:_emit(record, "removed")
    record.Scope:Destroy()
    record.Character, record.Root, record.Head, record.Humanoid = nil, nil, nil, nil
end

return PlayerTracker
end)()

local __aim = (function()
local AimController = {}
AimController.__index = AimController

function AimController.alpha(speed, deltaTime)
    return 1 - math.exp(-speed * math.max(0, deltaTime))
end

function AimController.screenDistance(x, y, z, onScreen, centerX, centerY, radius)
    if not onScreen or z <= 0 then return nil end
    local distance = (x - centerX)^2 + (y - centerY)^2
    return distance <= radius^2 and distance or nil
end

local function createCircle(parent, cleanup)
    -- Drawing is optional and never required by the standard LocalScript path.
    local api = Drawing
    if type(api) == "table" and type(api.new) == "function" then
        local circle
        local ok = pcall(function()
            circle = api.new("Circle")
            circle.Filled = false
            circle.Visible = false
            circle.Position, circle.Radius = Vector2.new(0, 0), 100
            circle.Color, circle.Thickness, circle.Transparency = Color3.fromRGB(66, 173, 255), 1.5, 0.6
        end)
        if ok and circle then
            cleanup:Add(function() circle.Visible = false; circle:Remove() end)
            return function(config, camera)
                circle.Visible = config:Get("ShowFOV") and camera ~= nil
                if not camera then return end
                circle.Position = camera.ViewportSize / 2
                circle.Radius = config:Get("FOVRadius")
                circle.Color = Color3.fromHex(config:Get("FOVColor"))
                circle.Thickness = config:Get("FOVThickness")
                circle.Transparency = 1 - config:Get("FOVTransparency")
            end, "Drawing"
        end
        if circle then pcall(function() circle:Remove() end) end
    end
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "FOV", false, true
    gui.DisplayOrder = 80
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
    -- Keep each ScreenGui directly in PlayerGui for ResetOnSpawn persistence.
    gui.Parent = parent.Parent
    cleanup:Add(gui)
    local circle = Instance.new("Frame")
    circle.Name, circle.BackgroundTransparency, circle.BorderSizePixel = "Circle", 1, 0
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(1, 0), circle
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode, stroke.Parent = Enum.ApplyStrokeMode.Border, circle
    return function(config, camera)
        circle.Visible = config:Get("ShowFOV") and camera ~= nil
        if not camera then return end
        local center = camera.ViewportSize / 2
        circle.Position = UDim2.fromOffset(center.X, center.Y)
        local diameter = 2 * config:Get("FOVRadius")
        circle.Size = UDim2.fromOffset(diameter, diameter)
        stroke.Color = Color3.fromHex(config:Get("FOVColor"))
        stroke.Thickness = config:Get("FOVThickness")
        stroke.Transparency = config:Get("FOVTransparency")
    end, "ScreenGui"
end

function AimController.new(context)
    local self = setmetatable({Context = context, Holding = false, Bound = false, Dead = false}, AimController)
    local s, cleanup = context.Services, context.Cleanup
    self.Params = RaycastParams.new()
    self.Params.FilterType = Enum.RaycastFilterType.Exclude
    self.Params.IgnoreWater = true
    self.BindingName = "VWMenu_Aim_" .. context.Id
    self.DrawCircle, self.FOVBackend = createCircle(context.Root, cleanup)
    cleanup:Add(function() self.Dead = true; self.Holding = false; self.Target = nil end)
    cleanup:Add(s.UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed
            and not s.UserInputService:GetFocusedTextBox() and context.Config:Get("AimEnabled") then
            self.Holding = true
            self:_syncBinding()
        end
    end))
    cleanup:Add(s.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then self:Release() end
    end))
    cleanup:Add(s.UserInputService.WindowFocusReleased:Connect(function() self:Release() end))
    cleanup:Add(s.UserInputService.TextBoxFocused:Connect(function() self:Release() end))
    cleanup:Add(s.GuiService.MenuOpened:Connect(function() self:Release() end))
    cleanup:Add(s.VRService:GetPropertyChangedSignal("VREnabled"):Connect(function() self:_syncBinding() end))
    cleanup:Add(context.Config:Subscribe(function(key)
        if not context.Config:Get("AimEnabled") or key == "Reset" then self.Holding = false; self.Target = nil end
        self.DrawCircle(context.Config, s.Workspace.CurrentCamera)
        self:_syncBinding()
    end))
    cleanup:Add(context.Tracker:Subscribe(function(record, reason)
        if record.Player == s.Players.LocalPlayer then self:_updateFilter(); self:_syncBinding() end
        if self.Target == record and (reason == "removed" or not context.Tracker:IsAlive(record)) then self.Target = nil end
    end))
    cleanup:Add(s.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() self:_cameraChanged() end))
    self:_cameraChanged()
    return self
end

function AimController:_updateFilter()
    local s = self.Context.Services
    local exclude = {}
    if s.Players.LocalPlayer.Character then table.insert(exclude, s.Players.LocalPlayer.Character) end
    if s.Workspace.CurrentCamera then table.insert(exclude, s.Workspace.CurrentCamera) end
    self.Params.FilterDescendantsInstances = exclude
end

function AimController:_cameraChanged()
    local context = self.Context
    local scope = context.Cleanup:Scope("camera")
    local camera = context.Services.Workspace.CurrentCamera
    self.Target = nil
    self:_updateFilter()
    if camera then
        scope:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self.DrawCircle(context.Config, camera) end))
        scope:Add(camera:GetPropertyChangedSignal("CameraType"):Connect(function() self:_syncBinding() end))
    end
    self.DrawCircle(context.Config, camera)
    self:_syncBinding()
end

function AimController:Release()
    self.Holding, self.Target = false, nil
    self:_syncBinding()
end

function AimController:_canAim()
    local context, s = self.Context, self.Context.Services
    local camera = s.Workspace.CurrentCamera
    return not self.Dead and self.Holding and context.Config:Get("AimEnabled")
        and camera ~= nil and camera.CameraType ~= Enum.CameraType.Scriptable
        and not s.VRService.VREnabled and not s.UserInputService:GetFocusedTextBox()
        and context.Tracker:IsAlive(context.Tracker.Records[s.Players.LocalPlayer])
end

function AimController:_syncBinding()
    local shouldBind = self:_canAim()
    if shouldBind == self.Bound then return end
    self.Context.Cleanup:Remove("render")
    self.Bound = false
    if not shouldBind then self.Target = nil; return end
    local scope = self.Context.Cleanup:Scope("render")
    local runService = self.Context.Services.RunService
    runService:BindToRenderStep(self.BindingName, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        local ok, problem = pcall(self._step, self, deltaTime)
        if not ok then
            self.LastError = tostring(problem)
            warn("[VW MENU] Aim interrompido: " .. self.LastError)
            self:Release()
        end
    end)
    self.Bound = true
    scope:Add(function() runService:UnbindFromRenderStep(self.BindingName); self.Bound = false end)
end

function AimController:_candidate(record, camera)
    local context, config = self.Context, self.Context.Config
    if record.Player == context.Services.Players.LocalPlayer or not context.Tracker:IsAlive(record)
        or (config:Get("TeamCheck") and context.Tracker:IsTeammate(record.Player)) then return nil end
    local part
    if config:Get("TargetPart") == "Head" then part = record.Head else part = record.Root end
    if not part or not part:IsDescendantOf(record.Character) then return nil end
    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    local center = camera.ViewportSize / 2
    local distance = AimController.screenDistance(point.X, point.Y, point.Z, onScreen, center.X, center.Y, config:Get("FOVRadius"))
    if distance == nil then return nil end
    return part, distance
end

function AimController:_visible(record, part, camera)
    if not self.Context.Config:Get("WallCheck") then return true end
    local origin = camera.CFrame.Position
    local result = self.Context.Services.Workspace:Raycast(origin, part.Position - origin, self.Params)
    return result == nil or result.Instance:IsDescendantOf(record.Character)
end

function AimController:_select(camera)
    if self.Context.Config:Get("TargetLock") and self.Target then
        local part = self:_candidate(self.Target, camera)
        if part and self:_visible(self.Target, part, camera) then return self.Target, part end
    end
    local nearest, target, targetPart = math.huge, nil, nil
    for _, record in pairs(self.Context.Tracker.Records) do
        local part, distance = self:_candidate(record, camera)
        if part and distance < nearest and self:_visible(record, part, camera) then
            nearest, target, targetPart = distance, record, part
        end
    end
    return target, targetPart
end

function AimController:_step(deltaTime)
    if not self:_canAim() then self:_syncBinding(); return end
    local camera = self.Context.Services.Workspace.CurrentCamera
    local target, part = self:_select(camera)
    self.Target = target
    if not part then return end
    local current = camera.CFrame
    if (part.Position - current.Position).Magnitude < 0.001 then return end
    camera.CFrame = current:Lerp(CFrame.lookAt(current.Position, part.Position), AimController.alpha(self.Context.Config:Get("SmoothSpeed"), deltaTime))
end

return AimController
end)()

local __esp = (function()
local ESPController = {}
ESPController.__index = ESPController

local keys = {
    ESPEnabled = true, Highlight = true, Boxes = true, NameTags = true,
    ShowHealth = true, ShowDistance = true, TeamColors = true, ShowTeammates = true,
    FriendColor = true, EnemyColor = true, HighlightTransparency = true,
    NameColor = true, BoxColor = true, HighlightColor = true,
    NameColorMode = true, BoxColorMode = true, HighlightColorMode = true,
}

function ESPController.new(context)
    local self = setmetatable({Context = context, Overlays = {}, Count = 0, Running = false, Elapsed = 0}, ESPController)
    context.Cleanup:Add(function() table.clear(self.Overlays); self.Count = 0 end)
    context.Cleanup:Add(context.Config:Subscribe(function(key)
        if keys[key] or key == "Reset" then self:_palette(); self:_refreshAll() end
    end))
    context.Cleanup:Add(context.Tracker:Subscribe(function(record, reason)
        if reason == "removed" then self:_remove(record)
        elseif record.Player == context.Services.Players.LocalPlayer then self:_refreshAll()
        else self:_refresh(record) end
        self:_syncHeartbeat()
    end))
    self:_palette()
    self:_refreshAll()
    return self
end

function ESPController:_palette()
    self.Palette = {}
    for _, key in ipairs({"FriendColor", "EnemyColor", "NameColor", "BoxColor", "HighlightColor"}) do
        self.Palette[key] = Color3.fromHex(self.Context.Config:Get(key))
    end
end

function ESPController:_color(record, component)
    local config, player = self.Context.Config, record.Player
    if config:Get(component .. "ColorMode") == "Custom" then return self.Palette[component .. "Color"] end
    if config:Get("TeamColors") and not player.Neutral and player.Team then return player.TeamColor.Color end
    return self.Context.Tracker:IsTeammate(player) and self.Palette.FriendColor or self.Palette.EnemyColor
end

function ESPController:_eligible(record)
    return self.Context.Config:Get("ESPEnabled")
        and record.Player ~= self.Context.Services.Players.LocalPlayer
        and self.Context.Tracker:IsAlive(record)
        and (self.Context.Config:Get("ShowTeammates") or not self.Context.Tracker:IsTeammate(record.Player))
end

function ESPController:_remove(record)
    local overlay = self.Overlays[record]
    if not overlay then return end
    self.Overlays[record] = nil
    self.Count -= 1
    overlay.Scope:Destroy()
end

function ESPController:_component(overlay, key, enabled, className, parent)
    if not enabled then
        overlay.Scope:Remove(key)
        overlay[key] = nil
        return nil
    end
    if not overlay[key] then
        local scope = overlay.Scope:Scope(key)
        local instance = Instance.new(className)
        instance.Name = "VWMenu_" .. key
        scope:Add(instance)
        overlay[key] = instance
        instance.Parent = parent
    end
    return overlay[key]
end

function ESPController:_refresh(record)
    if not self:_eligible(record) then self:_remove(record); return end
    local config = self.Context.Config
    local hasTag = config:Get("NameTags") or config:Get("ShowHealth") or config:Get("ShowDistance")
    if not config:Get("Highlight") and not config:Get("Boxes") and not hasTag then self:_remove(record); return end
    local overlay = self.Overlays[record]
    if overlay and overlay.Character ~= record.Character then self:_remove(record); overlay = nil end
    if not overlay then
        local scope = self.Context.Cleanup:Scope(record.Player)
        local folder = Instance.new("Folder")
        folder.Name = "ESP_" .. record.Player.UserId
        folder.Parent = self.Context.Root
        scope:Add(folder)
        overlay = {Scope = scope, Folder = folder, Character = record.Character}
        self.Overlays[record] = overlay
        self.Count += 1
    end
    local highlight = self:_component(overlay, "Highlight", config:Get("Highlight"), "Highlight", record.Character)
    if highlight then
        highlight.Adornee = record.Character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor, highlight.OutlineColor = self:_color(record, "Highlight"), self:_color(record, "Highlight")
        highlight.FillTransparency, highlight.OutlineTransparency = config:Get("HighlightTransparency"), 0.1
    end
    local box = self:_component(overlay, "Box", config:Get("Boxes"), "BoxHandleAdornment", overlay.Folder)
    if box then
        box.Adornee = record.Root
        box.AlwaysOnTop, box.ZIndex, box.Transparency = true, 1, 0.78
        box.Color3 = self:_color(record, "Box")
    end
    local tag = self:_component(overlay, "Tag", hasTag, "BillboardGui", overlay.Folder)
    if tag then
        tag.Adornee = record.Head or record.Root
        tag.Size, tag.AlwaysOnTop = UDim2.fromOffset(240, 50), true
        tag.StudsOffsetWorldSpace = Vector3.new(0, record.Head and 1.9 or 3.5, 0)
        tag.ResetOnSpawn = false
        tag.LightInfluence = 0
        local text = tag:FindFirstChild("Text")
        if not text then
            text = Instance.new("TextLabel")
            text.Name, text.BackgroundTransparency = "Text", 1
            text.Size, text.Font, text.TextSize = UDim2.fromScale(1, 1), Enum.Font.GothamMedium, 13
            text.TextStrokeTransparency, text.TextStrokeColor3 = 0.3, Color3.new(0, 0, 0)
            text.RichText, text.Parent = false, tag
        end
        text.TextColor3 = self:_color(record, "Name")
    end
    self:_update(record, overlay, self:_origin())
end

function ESPController:_origin()
    local context = self.Context
    local localRecord = context.Tracker.Records[context.Services.Players.LocalPlayer]
    if localRecord and localRecord.Root then return localRecord.Root.Position end
    local camera = context.Services.Workspace.CurrentCamera
    return camera and camera.CFrame.Position or nil
end

function ESPController:_update(record, overlay, origin)
    if not self:_eligible(record) or record.Character ~= overlay.Character then self:_remove(record); return end
    if overlay.Box then
        local bounds, size = record.Character:GetBoundingBox()
        overlay.Box.Adornee = record.Root
        overlay.Box.CFrame = record.Root.CFrame:ToObjectSpace(bounds)
        overlay.Box.Size = size
    end
    if overlay.Tag then
        local config, lines, details = self.Context.Config, {}, {}
        if config:Get("NameTags") then
            local p = record.Player
            table.insert(lines, p.DisplayName == p.Name and p.Name or (p.DisplayName .. " (@" .. p.Name .. ")"))
        end
        if config:Get("ShowHealth") then
            table.insert(details, string.format("%d / %d HP", math.max(0, math.floor(record.Humanoid.Health)), math.max(0, math.floor(record.Humanoid.MaxHealth))))
        end
        if config:Get("ShowDistance") and origin then
            table.insert(details, string.format("%d studs", math.floor((record.Root.Position - origin).Magnitude + 0.5)))
        end
        if #details > 0 then table.insert(lines, table.concat(details, "  ·  ")) end
        local text = table.concat(lines, "\n")
        if overlay.Tag.Text.Text ~= text then overlay.Tag.Text.Text = text end
    end
end

function ESPController:_refreshAll()
    for _, record in pairs(self.Context.Tracker.Records) do self:_refresh(record) end
    self:_syncHeartbeat()
end

function ESPController:_syncHeartbeat()
    local shouldRun = self.Context.Config:Get("ESPEnabled") and next(self.Overlays) ~= nil
    if shouldRun == self.Running then return end
    self.Context.Cleanup:Remove("heartbeat")
    self.Running = false
    if not shouldRun then return end
    local scope = self.Context.Cleanup:Scope("heartbeat")
    self.Running, self.Elapsed = true, 0
    scope:Add(function() self.Running = false end)
    scope:Add(self.Context.Services.RunService.Heartbeat:Connect(function(deltaTime)
        self.Elapsed += deltaTime
        if self.Elapsed < 0.1 then return end
        self.Elapsed %= 0.1
        local origin = self:_origin()
        local ok, problem = pcall(function()
            for record, overlay in pairs(self.Overlays) do self:_update(record, overlay, origin) end
        end)
        if not ok then
            self.LastError = tostring(problem)
            warn("[VW MENU] ESP interrompido: " .. self.LastError)
            self.Context.Config:Set("ESPEnabled", false)
        else self:_syncHeartbeat() end
    end))
end

return ESPController
end)()

local __ui = (function()
-- Native UI components reused from the existing VW MENU presentation layer.
-- The caller owns cleanup and registers every connection through cleanup:Add().
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local UIController = {}
UIController.__index = UIController

local C = {
	Background = Color3.fromRGB(11, 14, 20),
	Panel = Color3.fromRGB(16, 36, 65),
	Secondary = Color3.fromRGB(25, 55, 88),
	Accent = Color3.fromRGB(66, 173, 255),
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
	assert(parent and (parent:IsA("PlayerGui") or parent:FindFirstAncestorOfClass("PlayerGui")), "UIController requires PlayerGui ancestry")
	assert(cleanup and type(cleanup.Add) == "function", "UIController requires cleanup:Add")
	local self = setmetatable({
		_cleanup = cleanup, _tweens = {}, _open = true, _reducedMotion = false,
		_userScale = 1, _effectiveScale = 1, _controlKeys = {}, _openDropdown = nil,
		Tabs = {}, Controls = {}, _tabOrder = {}, _positioned = false,
		_focusables = {}, _keyboardActions = {},
	}, UIController)

	self.Gui = make("ScreenGui", {
		Name = "VWMenu_Client_v2", ResetOnSpawn = false, DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false,
	}, parent)
	self.Gui:SetAttribute("Owner", "VWMenu")
	self.Gui:SetAttribute("Version", 2)
	cleanup:Add(self.Gui)
	self._safe = make("Frame", { Name = "SafeArea", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, self.Gui)
	self.Window = make("CanvasGroup", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420), BackgroundColor3 = C.Background,
		BorderSizePixel = 0, GroupTransparency = 0, ClipsDescendants = true,
	}, self._safe)
	corner(self.Window, 9)
	make("UIStroke", { Color = C.Secondary, Thickness = 1, Transparency = 0.25 }, self.Window)
	self._scale = make("UIScale", { Scale = 1 }, self.Window)

	local header = make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 61) }, self.Window)
	local drag = make("TextButton", { Name = "DragHandle", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -106, 1, 0) }, header)
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
	self._minimize = self:_button(header, "Minimize", "−", UDim2.fromOffset(44, 44), UDim2.new(1, -98, 0, 8))
	self._minimize.TextSize = 20
	self._minimize.BackgroundTransparency = 1
	self:_connect(self._minimize.Activated, function() self:SetMinimized(not self._minimized) end)

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
		-- Native GuiButton activation handles Enter/Space; do not fire it twice.
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
	local width = math.min(560, (available.X - 24) / scale)
	local height = self._minimized and 61 or math.min(420, (available.Y - 24) / scale)
	local sidebar = width < 490 and 94 or 122
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
function UIController:SetMinimized(value)
	self._minimized = value == true
	self._sidebar.Visible = not self._minimized
	self._content.Visible = not self._minimized
	self._minimize.Text = self._minimized and "+" or "−"
	self._drag = nil; self._sliderDrag = nil
	self:_layout()
end
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
	local row = self:_row(tabId, config, 60, 78)
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
	local row = self:_row(tabId, config, 88, 24)
	row.Description.Size = UDim2.new(1, -24, 0, 21)
	local numberLabel = label(row, "Value", "", 11, C.Accent, UDim2.new(1, -70, 0, 10), UDim2.fromOffset(57, 18))
	numberLabel.TextXAlignment = Enum.TextXAlignment.Right
	row.Title.Size = UDim2.new(1, -90, 0, 20)
	local hit = self:_button(row, "Slider", "", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 49))
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

function UIController:AddColor(tabId, config)
	local row = self:_row(tabId, config, 66, 152)
	local swatch = make("Frame", {Name = "Swatch", BorderSizePixel = 0,
		Size = UDim2.fromOffset(18, 28), Position = UDim2.new(1, -141, 0, 19)}, row)
	corner(swatch, 4)
	local box = make("TextBox", {Name = "Hex", ClearTextOnFocus = false,
		BackgroundColor3 = C.Secondary, BorderSizePixel = 0, TextColor3 = C.Text,
		Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.fromOffset(108, 32),
		Position = UDim2.new(1, -117, 0, 17), PlaceholderText = "#RRGGBB"}, row)
	corner(box)
	local value = config.Value
	local handle = {Instance = row}
	function handle.Get() return value end
	function handle.Set(first, second, third)
		local nextValue, fireCallback = first, second
		if first == handle then nextValue, fireCallback = second, third end
		if type(nextValue) ~= "string" or not nextValue:match("^#%x%x%x%x%x%x$") then
			box.Text = value
			return
		end
		local previous = value
		value = string.upper(nextValue)
		box.Text, swatch.BackgroundColor3 = value, Color3.fromHex(value)
		if fireCallback and previous ~= value then self:_invoke(config.OnChanged, value) end
	end
	self:_connect(box.FocusLost, function() handle.Set(box.Text, true) end)
	handle.Set(value)
	self.Controls[config.Id] = handle
	return handle
end

function UIController:AddStatus(tabId, config)
	local row = self:_row(tabId, config, 148, 24)
	row.Description.Visible = false
	local status = label(row, "Status", "Iniciando...", 11, C.Text,
		UDim2.fromOffset(12, 35), UDim2.new(1, -24, 0, 105))
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.TextTruncate = Enum.TextTruncate.None
	return function(text) if status.Text ~= text then status.Text = text end end
end

return UIController
end)()

local __main = (function()
local Config = __config
local Cleanup = __cleanup
local PlayerTracker = __tracker
local AimController = __aim
local ESPController = __esp
local UI = __ui

local Main = {}

local function services()
    local result = {}
    for _, name in ipairs({"Players", "RunService", "UserInputService", "TweenService", "GuiService", "VRService", "HttpService", "Workspace"}) do
        result[name] = game:GetService(name)
    end
    return result
end

local function shutdownPrevious(playerGui)
    for _, previous in ipairs(playerGui:GetChildren()) do
        local owned = previous:GetAttribute("Owner") == "VWMenu"
        local known = previous.Name == "VWMenuRuntime_v2" or previous.Name == "VWMenu_Client_v1"
        if owned and known then
            local shutdown = previous:FindFirstChild("VWMenu_Shutdown")
            assert(shutdown and shutdown:IsA("BindableFunction"), "VW MENU anterior sem endpoint de limpeza; inicialização cancelada")
            local ok, problem = pcall(function() return shutdown:Invoke() end)
            assert(ok and previous.Parent == nil, "Não foi possível limpar a instância anterior: " .. tostring(problem))
        end
    end
end

local function controls(ui, config, app)
    ui:AddTab("AIM", "AIM", "Habilite e segure RMB. A mira usa o centro da tela.", "01")
    ui:AddTab("ESP", "ESP", "Overlays locais para o ambiente de teste autorizado.", "02")
    ui:AddTab("VISUAL", "VISUAL", "Cores em #RRGGBB; a amostra exibe a cor escolhida.", "03")
    ui:AddTab("SETTINGS", "SETTINGS", "Estado da sessão e descarregamento completo.", "04")
    local bindings = {}
    local function add(tab, kind, key, title, description, options)
        local definition = {Id = tab .. "_" .. key, Title = title, Description = description, Value = config:Get(key)}
        local range = Config.Ranges[key]
        if range then definition.Min, definition.Max, definition.Step = range[1], range[2], range[3] end
        definition.Options = options
        definition.OnChanged = function(value)
            local accepted, problem = config:Set(key, value)
            if not accepted then warn("[VW MENU] " .. tostring(problem)) end
        end
        local handle = ui["Add" .. kind](ui, tab, definition)
        table.insert(bindings, {Key = key, Handle = handle})
    end
    add("AIM", "Toggle", "AimEnabled", "Aim Assist", "Atua somente enquanto MouseButton2 estiver pressionado.")
    add("AIM", "Slider", "SmoothSpeed", "Smooth Speed", "1 a 30. Maior valor aproxima a câmera mais rápido.")
    add("AIM", "Slider", "FOVRadius", "FOV Radius", "Raio em pixels: 30 a 400.")
    add("AIM", "Toggle", "ShowFOV", "Show FOV", "Círculo visível mesmo com Aim Assist desativado.")
    add("AIM", "Toggle", "WallCheck", "Wall Check", "Exige linha de visão até a parte selecionada.")
    add("AIM", "Toggle", "TeamCheck", "Team Check", "Ignora aliados. Jogadores neutros não são aliados.")
    add("AIM", "Toggle", "TargetLock", "Target Lock", "Conserva o alvo enquanto vivo, visível e no FOV.")
    add("AIM", "Dropdown", "TargetPart", "Target Part", "A parte precisa existir; sem troca silenciosa.", {"Head", "HumanoidRootPart"})

    add("ESP", "Toggle", "ESPEnabled", "ESP", "Liga ou remove todos os overlays.")
    for _, item in ipairs({
        {"Highlight", "Highlight", "Contorno e preenchimento do personagem."},
        {"Boxes", "Boxes", "Caixa 3D acompanha os limites do modelo."},
        {"NameTags", "Name Tags", "Nome de exibição e usuário."},
        {"ShowHealth", "Show Health", "Vida atual / máxima, independente do nome."},
        {"ShowDistance", "Show Distance", "Distância em studs, independente do nome."},
        {"TeamColors", "Team Colors", "Usa TeamColor; desative para Friend/Enemy."},
        {"ShowTeammates", "Show Teammates", "Exibe também personagens da sua equipe."},
    }) do add("ESP", "Toggle", item[1], item[2], item[3]) end
    add("ESP", "Color", "FriendColor", "Friend Color", "Usada no modo Team / Relation sem Team Colors.")
    add("ESP", "Color", "EnemyColor", "Enemy Color", "Também se aplica a jogadores neutros.")
    add("ESP", "Slider", "HighlightTransparency", "Highlight Transparency", "0 = opaco; 1 = preenchimento invisível.")

    add("VISUAL", "Toggle", "ShowFOV", "Show FOV", "Sincronizado com o mesmo controle na aba AIM.")
    add("VISUAL", "Color", "FOVColor", "FOV Color", "Amostra e círculo atualizados ao confirmar a cor.")
    add("VISUAL", "Slider", "FOVThickness", "FOV Thickness", "Espessura em pixels.")
    add("VISUAL", "Slider", "FOVTransparency", "FOV Transparency", "0 = opaco; 1 = invisível, em ambos os renderizadores.")
    for _, component in ipairs({"Name", "Box", "Highlight"}) do
        add("VISUAL", "Dropdown", component .. "ColorMode", component .. " Color Mode", "Custom aplica a cor abaixo; Team / Relation usa a aba ESP.", {"Team / Relation", "Custom"})
        add("VISUAL", "Color", component .. "Color", component .. " Color", "Ative Custom para aplicar esta cor ao overlay.")
    end
    add("SETTINGS", "Toggle", "ReducedMotion", "Reduce Motion", "Aplica novas transições do menu sem animação.")
    ui:AddButton("SETTINGS", {Id = "Reset", Title = "Reset Defaults", ButtonText = "Restaurar", Description = "Desliga AIM/ESP e restaura todas as configurações.", OnActivated = function() config:Reset() end})
    ui:AddButton("SETTINGS", {Id = "Unload", Title = "Unload", ButtonText = "Descarregar VW MENU", Description = "Remove UI, FOV, overlays, eventos e render binding.", OnActivated = function() app:Destroy() end})
    local setStatus = ui:AddStatus("SETTINGS", {Id = "Status", Title = "Runtime Status"})
    local function synchronize()
        ui:SetReducedMotion(config:Get("ReducedMotion"))
        for _, binding in ipairs(bindings) do binding.Handle:Set(config:Get(binding.Key), false) end
    end
    app.Cleanup:Add(config:Subscribe(synchronize))
    synchronize()
    return setStatus
end

function Main.start()
    local s = services()
    assert(s.RunService:IsClient(), "Execute VW MENU em um LocalScript no cliente")
    local player = s.Players.LocalPlayer
    assert(player, "LocalPlayer não está disponível")
    local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    assert(playerGui, "PlayerGui não está disponível")
    shutdownPrevious(playerGui)

    local cleanup = Cleanup.new()
    local app = {Cleanup = cleanup, Unloaded = false}
    function app:Destroy()
        if self.Unloaded then return end
        self.Unloaded = true
        cleanup:Destroy()
    end
    local ok, result = pcall(function()
        -- Direct ScreenGui children survive PlayerGui respawn reset; a Folder does not.
        local root = Instance.new("ScreenGui")
        root.Name = "VWMenuRuntime_v2"
        root.ResetOnSpawn, root.IgnoreGuiInset = false, true
        root:SetAttribute("Owner", "VWMenu")
        root:SetAttribute("Version", 2)
        root.Parent = playerGui
        cleanup:Add(root)
        cleanup:Add(root.Destroying:Connect(function() app:Destroy() end))
        local shutdown = Instance.new("BindableFunction")
        shutdown.Name = "VWMenu_Shutdown"
        shutdown.OnInvoke = function() app:Destroy(); return true end
        shutdown.Parent = root
        if script and script:IsA("LocalScript") then cleanup:Add(script.Destroying:Connect(function() app:Destroy() end)) end

        local config = cleanup:Add(Config.new())
        local tracker = PlayerTracker.new(s, cleanup:Scope("tracker"))
        local id = s.HttpService:GenerateGUID(false)
        local function context(name)
            return {Services = s, Root = root, Config = config, Tracker = tracker, Id = id, Cleanup = cleanup:Scope(name)}
        end
        app.Config, app.Tracker = config, tracker
        app.Aim = AimController.new(context("aim"))
        app.ESP = ESPController.new(context("esp"))
        app.UI = UI.new(playerGui, cleanup:Scope("ui"))
        cleanup:Add(app.UI:GetGui().Destroying:Connect(function() app:Destroy() end))
        local setStatus = controls(app.UI, config, app)
        local elapsed = 0
        local function status()
            local aim, esp = app.Aim, app.ESP
            local aimState = "desligado"
            if config:Get("AimEnabled") then
                aimState = aim.Bound and (aim.Target and aim.Target.Player.Name or "sem alvo no FOV") or "aguarde RMB / câmera elegível"
            end
            local lastError = aim.LastError or esp.LastError or config.LastError or cleanup.LastError
            setStatus(string.format("AIM: %s\nESP: %s | overlays: %d\nFOV: %s | %s\nConexões gerenciadas: %d\nRender binding: %s\nErro interno: %s",
                aimState, config:Get("ESPEnabled") and "ligado" or "desligado", esp.Count,
                aim.FOVBackend, config:Get("ShowFOV") and "visível" or "oculto",
                cleanup:ConnectionCount(), aim.Bound and "ativo" or "inativo", lastError and string.sub(lastError, 1, 90) or "nenhum registrado"))
        end
        cleanup:Add(s.RunService.Heartbeat:Connect(function(deltaTime)
            elapsed += deltaTime
            if elapsed >= 0.5 then
                elapsed %= 0.5
                if app.UI:IsOpen() and app.UI._selectedTab == "SETTINGS" then status() end
            end
        end))
        status()
        root:SetAttribute("Ready", true)
        return app
    end)
    if not ok then app:Destroy(); error("[VW MENU] Falha na inicialização: " .. tostring(result), 0) end
    return result
end

return Main
end)()

return __main.start()
