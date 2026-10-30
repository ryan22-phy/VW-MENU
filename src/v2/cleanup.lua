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
