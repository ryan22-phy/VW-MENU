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
