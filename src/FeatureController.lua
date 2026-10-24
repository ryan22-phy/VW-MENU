-- Client feature scopes. A disabled toggle owns no continuing work.
local CleanupManager = require(script.Parent.CleanupManager)

local FeatureController = {}
FeatureController.__index = FeatureController

function FeatureController.new(settings, notifications, cleanup, context)
    local self = setmetatable({
        _settings = settings,
        _notifications = notifications,
        _context = context or {},
        _features = {},
        _destroyed = false,
    }, FeatureController)
    cleanup:Add(function() self:Destroy() end)
    return self
end

function FeatureController:Register(definition)
    assert(not self._destroyed, "FeatureController is destroyed")
    assert(type(definition.Id) == "string" and not self._features[definition.Id], "Duplicate/invalid feature Id")
    self._features[definition.Id] = {
        Definition = definition,
        Value = definition.Key and self._settings:Get(definition.Key),
        Scope = nil,
        Busy = false,
        Initialized = false,
        State = "idle",
    }
end

function FeatureController:Get(id)
    local record = self._features[id]
    return record and record.Value
end

function FeatureController:GetState(id)
    local record = self._features[id]
    return record and record.State
end

function FeatureController:_error(record, problem)
    record.State = "error"
    warn("[VW MENU] " .. record.Definition.Id .. ": " .. tostring(problem))
    self._notifications:Push("Falha no controle", "A acao nao foi concluida. Consulte o Output.", 5)
end

function FeatureController:Set(id, value)
    local record = self._features[id]
    if self._destroyed or not record then return false, "Recurso indisponivel" end
    if record.Busy then return false, "Recurso ocupado" end
    local definition = record.Definition
    if definition.Kind == "Button" then return false, "Use Activate para botoes" end
    if record.Initialized and record.Value == value then return true end
    local previous = record.Value
    if definition.Key then
        local accepted, problem = self._settings:Set(definition.Key, value)
        if not accepted then return false, problem end
    end
    record.Busy = true
    if record.Scope then record.Scope:Destroy() end
    local scope = CleanupManager.new()
    record.Scope = scope
    local token = { Cancelled = false }
    scope:Add(function() token.Cancelled = true end)
    -- Future asynchronous adapters must check token.Cancelled after each yield.
    local ok, result = pcall(function()
        if definition.Apply then return definition.Apply(value, scope, self._context, token) end
        return nil
    end)
    record.Busy = false
    record.Initialized = true
    if not ok then
        scope:Destroy()
        record.Scope = nil
        -- Failed toggles stay off; the old worker has already stopped.
        local fallback = if definition.Kind == "Toggle" then false else previous
        record.Value = fallback
        if definition.Key then self._settings:Set(definition.Key, fallback) end
        self:_error(record, result)
        return false, tostring(result)
    end
    if self._destroyed or record.Scope ~= scope then
        scope:Destroy()
        return false, "Recurso encerrado durante callback"
    end
    if result ~= nil then scope:Add(result) end
    record.Value = value
    record.State = if value == false then "disabled" else "ready"
    return true
end

function FeatureController:Activate(id)
    local record = self._features[id]
    if self._destroyed or not record or record.Busy then return false, "Recurso indisponivel" end
    local definition = record.Definition
    if definition.Kind ~= "Button" then return false, "Use Set para controles de valor" end
    record.Busy = true
    record.State = "running"
    local ok, result = pcall(function()
        if definition.Run then return definition.Run(self._context) end
        return nil
    end)
    record.Busy = false
    if not ok then
        self:_error(record, result)
        return false, tostring(result)
    end
    record.State = if self._destroyed then "destroyed" else "ready"
    return true
end

function FeatureController:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for _, record in pairs(self._features) do
        if record.Scope then record.Scope:Destroy(); record.Scope = nil end
        record.State = "destroyed"
    end
end

return FeatureController
