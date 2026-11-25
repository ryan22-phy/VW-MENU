# Phase 2: Aprimoramento dos Módulos Existentes

## 2.1 Aprimoramento do Config (src/v2/config.lua)

### Novas Validações Implementadas
```lua
-- Adicionado: Validação de alcance para valores booleanos
function Config:Set(key, value)
    -- [Código existente]
    
    -- Nova validação: Range para bool
    local range = Config.Ranges[key]
    if range then
        -- [Código existente]
    end
    
    -- Nova validação: String min/max length
    if type(default) == "string" then
        if #value < 1 or #value > 100 then return false, "String length inválido (1-100)" end
        if not value:match("^#%x%x%x%x%x%x$") then return false, "Use #RRGGBB" end
        value = string.upper(value)
    end
    
    -- [Código existente]
end
```

### Melhoria de Observabilidade
```lua
-- Adicionado: History de mudanças (últimas 10)
function Config:GetHistory(count)
    count = math.clamp(count or 10, 0, 10)
    local result = {}
    for i = math.max(1, #self._history - count), #self._history do
        table.insert(result, self._history[i])
    end
    return result
end
```

### Novo Default: DebugMode
```lua
Config.Defaults = table.freeze({
    -- [Defaults existentes]
    DebugMode = false,  -- Modo debug para logs detalhados
})
```

## 2.2 Aprimoramento do Cleanup (src/v2/cleanup.lua)

### Nova Funcionalidade: Cleanup por Tempo
```lua
function Cleanup:AddTimed(resource, ttl)
    assert(ttl and ttl > 0, "TTL deve ser positivo")
    local id = self.NextId + 1
    self.NextId = id
    local entry = {
        Dispose = self:_makeDispose(resource),
        Connection = false,
        ExpiresAt = tick() + ttl
    }
    self.Items[id] = entry
    return resource
end
```

### Nova Funcionalidade: Cleanup com Callback de Erro
```lua
function Cleanup:AddWithHandler(resource, onDisposeError)
    local id = self.NextId + 1
    self.NextId = id
    local dispose = function()
        local ok, err = pcall(self:_makeDisposeFunc(resource))
        if not ok and onDisposeError then
            pcall(onDisposeError, err)
        end
    end
    self.Items[id] = {Dispose = dispose, Connection = false}
    return resource
end
```

### Métrica de Limpeza
```lua
function Cleanup:GetMetrics()
    local count = 0
    local connections = 0
    for _, entry in pairs(self.Items) do
        count += 1
        if entry.Connection then connections += 1 end
    end
    return {
        TotalItems = count,
        TotalConnections = connections,
        RootConnections = self.Root.Connections,
        IsDead = self.Dead
    }
end
```

## 2.3 Aprimoramento do Tracker (src/v2/tracker.lua)

### Nova Funcionalidade: Filtragem por Tag
```lua
-- Adicionado: Support for custom tags
function PlayerTracker:AddTag(player, tag)
    local record = self.Records[player]
    if not record then return false end
    record.Tags = record.Tags or {}
    record.Tags[tag] = true
    return true
end

function PlayerTracker:HasTag(player, tag)
    local record = self.Records[player]
    if not record or not record.Tags then return false end
    return record.Tags[tag] == true
end

function PlayerTracker:GetPlayersByTag(tag)
    local result = {}
    for player, record in pairs(self.Records) do
        if record.Tags and record.Tags[tag] then
            table.insert(result, player)
        end
    end
    return result
end
```

### Nova Funcionalidade: Proximity Detection
```lua
function PlayerTracker:GetNearestAlive(center, maxDistance)
    local nearest, distance = nil, math.huge
    for player, record in pairs(self.Records) do
        if self:IsAlive(record) and record.Root then
            local d = (record.Root.Position - center).Magnitude
            if d < distance and (not maxDistance or d <= maxDistance) then
                nearest, distance = record, d
            end
        end
    end
    return nearest
end
```

## 2.4 Aprimoramento do Aim (src/v2/aim.lua)

### Nova Funcionalidade: Modo "Toggle" para Aim Assist
```lua
-- Config adicionado: AimMode (Hold / Toggle / HoldUntilTarget)
function AimController:_getAimState()
    local mode = self.Context.Config:Get("AimMode") or "Hold"
    local config = self.Context.Config:Get("AimEnabled")
    
    if not config then return false end
    
    if mode == "Hold" then
        return self.Holding
    elseif mode == "Toggle" then
        return self.Holding
    elseif mode == "HoldUntilTarget" then
        return self.Holding or self.Target ~= nil
    end
    return false
end
```

### Nova Funcionalidade: Ajuste Dinâmico de FOV
```lua
-- FOV adaptativo baseado na velocidade do cursor
function AimController:_getDynamicFOVRadius()
    local baseRadius = self.Context.Config:Get("FOVRadius")
    local sensitivity = self.Context.Config:Get("MouseSensitivity") or 1
    return baseRadius * sensitivity
end
```

### Melhoria de Performance
```lua
-- Cache de candidatos válidos por frame
function AimController:_cacheCandidates(camera)
    if self._cachedCandidates and tick() - self._cacheTime < 0.016 then
        return self._cachedCandidates
    end
    
    local candidates = {}
    for _, record in pairs(self.Context.Tracker.Records) do
        local part, distance = self:_candidate(record, camera)
        if part then
            table.insert(candidates, {Record = record, Part = part, Distance = distance})
        end
    end
    
    -- Ordenar por distância
    table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    
    self._cachedCandidates = candidates
    self._cacheTime = tick()
    return candidates
end
```

## 2.5 Aprimoramento do ESP (src/v2/esp.lua)

### Nova Funcionalidade: ESP de Caixas 2D (Minimap-style)
```lua
function ESPController:AddMinimapBox(record, position, size)
    if not record then return end
    
    local overlay = self.Overlays[record]
    if not overlay then
        local scope = self.Context.Cleanup:Scope(record.Player)
        overlay = {Scope = scope, MinimapBoxes = {}}
        self.Overlays[record] = overlay
        self.Count += 1
    end
    
    local box = Instance.new("Frame")
    box.Name = "MinimapBox"
    box.Size = size or UDim2.fromOffset(20, 20)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.BackgroundTransparency = 0.3
    box.BackgroundColor3 = self:_color(record, "Box")
    box.Parent = overlay.Folder
    
    overlay.MinimapBoxes[position] = box
    overlay.Scope:Add(box)
end
```

### Nova Funcionalidade: ESP de Setas (Ocultação de Alvos)
```lua
function ESPController:AddDirectionArrow(record, direction)
    if not record or not self.Context.Config:Get("ESPEnabled") then return end
    
    local overlay = self.Overlays[record]
    if not overlay then return end
    
    local arrow = Instance.new("ImageLabel")
    arrow.Name = "DirectionArrow"
    arrow.Size = UDim2.fromOffset(24, 24)
    arrow.Image = "rbxasset://images/8488466570_714859881.png" -- Setas padrão
    arrow.ImageColor3 = Color3.new(1, 1, 1)
    arrow.Parent = overlay.Folder
    
    overlay.Arrow = arrow
    overlay.Scope:Add(arrow)
    
    self:_updateArrow(overlay, direction)
end

function ESPController:_updateArrow(overlay, direction)
    if not overlay.Arrow then return end
    
    local angle = math.atan2(direction.Y, direction.X)
    overlay.Arrow.Rotation = math.deg(angle)
end
```

### Nova Configuração: Transparência Condicional
```lua
-- Adicionado: HighlightTransparencyMode
function ESPController:_getHighlightTransparency(record)
    local mode = self.Context.Config:Get("HighlightTransparencyMode") or "Fixed"
    
    if mode == "Fixed" then
        return self.Context.Config:Get("HighlightTransparency")
    elseif mode == "Distance" then
        local origin = self:_origin()
        if record.Root then
            local dist = (record.Root.Position - origin).Magnitude
            return math.clamp(0.1 + (dist / 100) * 0.5, 0, 0.8)
        end
        return 0.65
    elseif mode == "Health" then
        if record.Humanoid then
            return 0.3 + (1 - record.Humanoid.Health / record.Humanoid.MaxHealth) * 0.4
        end
        return 0.65
    end
    
    return self.Context.Config:Get("HighlightTransparency")
end
```

## 2.6 Aprimoramento do UI Controller (src/v2/ui.lua)

### Novo Tipo de Controle: ColorSlider (para componentes Color)
```lua
function UIController:AddColorSlider(tabId, config)
    local minimum, maximum = 0, 255
    local step = 1
    
    local row = self:_row(tabId, config, 108, 152)
    
    local rgbLabel = label(row, "RGB", "rgb(0, 0, 0)", 11, C.Text, UDim2.new(1, -140, 0, 10), UDim2.fromOffset(130, 18))
    rgbLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    row.Title.Size = UDim2.new(1, -170, 0, 20)
    
    local colorSwatch = make("Frame", {
        Name = "Swatch",
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -120, 0, 19)
    }, row)
    corner(colorSwatch, 4)
    
    local value = config.Value or {R = 0, G = 0, B = 0}
    local handle = {Instance = row}
    
    function handle.Get() return value end
    function handle.Set(rgb, fireCallback)
        local previous = value
        value = {
            R = math.clamp(rgb.R or 0, 0, 255),
            G = math.clamp(rgb.G or 0, 0, 255),
            B = math.clamp(rgb.B or 0, 0, 255)
        }
        
        local prevColor = Color3.fromRGB(previous.R, previous.G, previous.B)
        self:_tween(colorSwatch, {BackgroundColor3 = Color3.fromRGB(value.R, value.G, value.B)})
        rgbLabel.Text = string.format("rgb(%d, %d, %d)", value.R, value.G, value.B)
        
        if fireCallback and (previous.R ~= value.R or previous.G ~= value.G or previous.B ~= value.B) then
            self:_invoke(config.OnChanged, value)
        end
    end
    
    handle.Set(value)
    self.Controls[config.Id] = handle
    return handle
end
```

### Novo Tipo de Controle: ButtonGroup
```lua
function UIController:AddButtonGroup(tabId, config)
    local row = self:_row(tabId, config, 60, 24)
    
    local hbox = make("Frame", {
        Name = "HBox",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 30),
        Size = UDim2.new(1, -24, 0, 26),
    }, row)
    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, hbox)
    
    local value = config.Value or 1
    local buttons = {}
    local handle = {Instance = row}
    
    function handle.Get()
        return value
    end
    
    function handle.Set(first, second, third)
        local selectKey, fireEvent = first, second
        if first == handle then selectKey, fireEvent = second, third end
        
        for key, _ in pairs(config.Options) do
            if selectKey == key then
                value = key
                for _, btn in pairs(buttons) do
                    btn.TextColor3 = C.Text
                    btn.BackgroundColor3 = C.Secondary
                end
                local btn = buttons[key]
                if btn then
                    btn.TextColor3 = C.Accent
                    btn.BackgroundColor3 = C.Background
                end
                if fireEvent then
                    self:_invoke(config.OnChanged, value)
                end
                break
            end
        end
    end
    
    buttons = {}
    for key, label in pairs(config.Options) do
        local btn = self:_button(hbox, "Btn_" .. key, label, UDim2.fromOffset(80, 24))
        btn.TextSize = 11
        buttons[key] = btn
        self:_connect(btn.Activated, function() handle.Set(key, true) end)
    end
    
    handle.Set(value)
    self.Controls[config.Id] = handle
    return handle
end
```

### Novo Tipo de Controle: ProgressBar
```lua
function UIController:AddProgressBar(tabId, config)
    local row = self:_row(tabId, config, 48, 24)
    
    local track = make("Frame", {
        Name = "Track",
        BackgroundColor3 = C.Secondary,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.fromOffset(12, 30)
    }, row)
    corner(track, 4)
    
    local fill = make("Frame", {
        Name = "Fill",
        BackgroundColor3 = C.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1)
    }, track)
    
    local value = config.Value or 0
    local handle = {Instance = row}
    
    function handle.Get()
        return value
    end
    
    function handle.Set(newValue)
        value = math.clamp(newValue or 0, 0, 100)
        fill.Size = UDim2.fromScale(value / 100, 1)
        if config.OnChanged then
            self:_invoke(config.OnChanged, value)
        end
    end
    
    handle.Set(value)
    self.Controls[config.Id] = handle
    return handle
end
```

### Melhoria de Acessibilidade
```lua
-- Adicionado: AriaLabels para leitores de tela
function UIController:_setAriaLabel(instance, label)
    if not instance then return end
    instance:SetAttribute("AriaLabel", label)
end

-- Adicionado: Modo alto contraste
function UIController:SetHighContrast(enabled)
    self._highContrast = enabled and true or false
    self:_refreshColors()
end

function UIController:_refreshColors()
    local bg = self._highContrast and Color3.new(1, 1, 1) or C.Background
    local text = self._highContrast and Color3.new(0, 0, 0) or C.Text
    self.Gui.BackgroundColor3 = bg
    -- Atualizar todos os textos...
end
```

## 2.7 Configurações Adicionais

### Novo Default: DebugMode
```lua
Config.Defaults = table.freeze({
    -- [Defaults existentes]
    DebugMode = false,              -- Logs debug detalhados
    MinimapEnabled = false,         -- ESP minimap-style
    DirectionArrows = false,        -- Setas direcionais ESP
    HighContrast = false,           -- Modo alto contraste
    MouseSensitivity = 1.0,         -- Sensibilidade do mouse
    AimMode = "Hold",               -- Hold / Toggle / HoldUntilTarget
    HighlightTransparencyMode = "Fixed", -- Fixed / Distance / Health
})
```

### Novo Range
```lua
Config.Ranges = table.freeze({
    -- [Ranges existentes]
    MouseSensitivity = {0.5, 2.0, 0.05},
    HighlightTransparency = {0, 1, 0.05},
    FOVTransparency = {0, 1, 0.05},
})
```

### Novas Choices
```lua
local choices = {
    -- [Choices existentes]
    AimMode = {Hold = true, Toggle = true, HoldUntilTarget = true},
    HighlightTransparencyMode = {Fixed = true, Distance = true, Health = true},
}
```

## 2.8 Próximos Passos para Phase 3

1. Implementar todos os novos tipos de controle no UI
2. Adicionar configurações ao painel de setting
3. Executar build e verificar integridade
4. Atualizar testes para cobrir novas funcionalidades