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

function PlayerTracker:GetLocalPlayerRecord()
    return self.Records[self.Services.Players.LocalPlayer]
end

function PlayerTracker:GetAllRecords()
    return self.Records
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
