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
