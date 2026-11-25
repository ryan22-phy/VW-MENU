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
            local aimMode = context.Config:Get("AimMode") or "Hold"
            if aimMode == "Hold" then
                self.Holding = true
                self:_syncBinding()
            elseif aimMode == "Toggle" then
                self.Holding = not self.Holding
                self:_syncBinding()
            elseif aimMode == "HoldUntilTarget" then
                self.Holding = true
                self:_syncBinding()
            end
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
    local aimEnabled = context.Config:Get("AimEnabled")
    if not aimEnabled then return false end

    local aimMode = context.Config:Get("AimMode") or "Hold"

    local canAim = false
    if aimMode == "Hold" then
        canAim = self.Holding
    elseif aimMode == "Toggle" then
        -- In Toggle mode, Holding represents the toggled state
        canAim = self.Holding
    elseif aimMode == "HoldUntilTarget" then
        canAim = self.Holding or (self.Target and self:_candidate(self.Target, camera) ~= nil)
    else
        canAim = self.Holding
    end

    if not canAim then
        self.Target = nil
        return false
    end

    return camera ~= nil and camera.CameraType ~= Enum.CameraType.Scriptable
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
