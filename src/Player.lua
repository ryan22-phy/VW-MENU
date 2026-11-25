-- Player utilities: info retrieval, character monitoring, position tracking.
-- For authorized test environments only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PlayerUtils = {}
PlayerUtils.__index = PlayerUtils

function PlayerUtils.new()
	local self = setmetatable({
		_Players = nil,
		_LocalPlayer = nil,
		_Character = nil,
		_Humanoid = nil,
		_RootPart = nil,
		_PositionThread = nil,
		_AlivePlayers = {},
		_EnemyPlayers = {},
		_TeammatePlayers = {},
	}, PlayerUtils)

	return self
end

function PlayerUtils:SetPlayers(playersService)
	self._Players = playersService or Players
end

function PlayerUtils:SetLocalPlayer(player)
	self._LocalPlayer = player or Players.LocalPlayer
end

-- // Player Information \\
function PlayerUtils:GetPlayerInfo(player)
	if not player or not player:IsA("Player") then
		return nil
	end

	return {
		Name = player.Name,
		DisplayName = player.DisplayName,
		UserId = player.UserId,
		Team = player.Team,
		Character = player.Character,
	}
end

function PlayerUtils:GetPlayerInfoFromUserId(userId)
	if not userId then return nil end
	return Players:GetPlayerByUserId(userId)
end

function PlayerUtils:GetLocalPlayer()
	return self._LocalPlayer or Players.LocalPlayer
end

function PlayerUtils:GetCharacter()
	if not self._Character and self._LocalPlayer then
		self._Character = self._LocalPlayer.Character or self._LocalPlayer.CharacterAdded:Wait()
	end
	return self._Character
end

function PlayerUtils:GetHumanoid()
	if not self._Humanoid then
		local char = self:GetCharacter()
		if char then
			self._Humanoid = char:FindFirstChildWhichIsA("Humanoid")
		end
	end
	return self._Humanoid
end

function PlayerUtils:GetRootPart()
	if not self._RootPart then
		local char = self:GetCharacter()
		if char then
			self._RootPart = char:FindFirstChild("HumanoidRootPart")
		end
	end
	return self._RootPart
end

function PlayerUtils:GetCharacterInfo(character)
	if not character then return nil end

	local info = {
		Humanoid = character:FindFirstChildWhichIsA("Humanoid"),
		RootPart = character:FindFirstChild("HumanoidRootPart"),
		Position = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position,
		Health = 0,
		MaxHealth = 0,
		Alive = false,
	}

	if info.Humanoid then
		info.Health = info.Humanoid.Health or 0
		info.MaxHealth = info.Humanoid.MaxHealth or 0
		info.Alive = info.Humanoid.Health > 0
	end

	return info
end

-- // Position Tracking \\
function PlayerUtils:GetLocalPlayerPosition()
	local root = self:GetRootPart()
	if root then
		return root.Position
	end
	return nil
end

function PlayerUtils:GetLocalPlayerCFrame()
	local root = self:GetRootPart()
	if root then
		return root.CFrame
	end
	return nil
end

function PlayerUtils:GetVelocity()
	local root = self:GetRootPart()
	if root and root assemblyLinearVelocity then
		return root assemblyLinearVelocity
	end
	return Vector3.new(0, 0, 0)
end

-- // Player Lists \\
function PlayerUtils:GetAllPlayers()
	if self._Players then
		return self._Players:GetPlayers()
	end
	return Players:GetPlayers()
end

function PlayerUtils:GetLivingPlayers()
	local living = {}
	for _, player in pairs(self:GetAllPlayers()) do
		local char = player.Character
		if char then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(living, player)
			end
		end
	end
	return living
end

function PlayerUtils:GetAlivePlayers(): { Player }
	return self:GetLivingPlayers()
end

function PlayerUtils:GetDeadPlayers(): { Player }
	local dead = {}
	for _, player in pairs(self:GetAllPlayers()) do
		local char = player.Character
		if not char then
			table.insert(dead, player)
		else
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if not hum or hum.Health <= 0 then
				table.insert(dead, player)
			end
		end
	end
	return dead
end

function PlayerUtils:GetEnemies(): { Player }
	local enemies = {}
	local localPlayer = self:GetLocalPlayer()
	if not localPlayer then return enemies end

	for _, player in pairs(self:GetAllPlayers()) do
		if player ~= localPlayer then
			-- Check team
			local sameTeam = (localPlayer.Team == player.Team)
			if not sameTeam then
				table.insert(enemies, player)
			end
		end
	end
	return enemies
end

function PlayerUtils:GetTeammates(): { Player }
	local teammates = {}
	local localPlayer = self:GetLocalPlayer()
	if not localPlayer then return teammates end

	for _, player in pairs(self:GetAllPlayers()) do
		if player ~= localPlayer then
			local sameTeam = (localPlayer.Team == player.Team)
			if sameTeam then
				table.insert(teammates, player)
			end
		end
	end
	return teammates
end

function PlayerUtils:GetFriends(): { Player }
	-- Friends are considered teammates in this context
	return self:GetTeammates()
end

-- // Player Records \\
function PlayerUtils:GetLocalPlayerRecord()
	local localPlayer = self:GetLocalPlayer()
	if not localPlayer then return nil end

	local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart")

	return {
		Player = localPlayer,
		Character = char,
		Root = root,
	}
end

-- // Player Management \\
function PlayerUtils:KillPlayer(player)
	if not player then
		player = self:GetLocalPlayer()
	end

	if not player then
		return false, "No player to kill"
	end

	if not player.Character or not player.Character:FindFirstChildWhichIsA("Humanoid") then
		return false, "Player character not available"
	end

	local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
	hum.Health = 0
	return true
end

function PlayerUtils:RespawnPlayer()
	local player = self:GetLocalPlayer()
	if not player then return false, "Player not found" end

	player:LoadCharacter()
	return true
end

function PlayerUtils:ResetCharacter()
	local player = self:GetLocalPlayer()
	if not player then return false, "Player not found" end

	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Remedies)
		return true
	end
	return false
end

function PlayerUtils:IsAlive(player)
	if not player then
		player = self:GetLocalPlayer()
	end
	if not player then return false end

	local char = player.Character
	if not char then return false end

	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return false end

	return hum.Health > 0
end

function PlayerUtils:GetHealth(player)
	if not player then
		player = self:GetLocalPlayer()
	end
	if not player then return 0 end

	local char = player.Character
	if not char then return 0 end

	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return 0 end

	return hum.Health
end

function PlayerUtils:GetMaxHealth(player)
	if not player then
		player = self:GetLocalPlayer()
	end
	if not player then return 0 end

	local char = player.Character
	if not char then return 0 end

	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return 0 end

	return hum.MaxHealth
end

function PlayerUtils:SetWalkSpeed(speed)
	local hum = self:GetHumanoid()
	if hum then
		hum.WalkSpeed = speed or 16
		return true
	end
	return false
end

function PlayerUtils:SetJumpPower(jumpPower)
	local hum = self:GetHumanoid()
	if hum then
		hum.JumpPower = jumpPower or 50
		return true
	end
	return false
end

-- // Utility Methods \\
function PlayerUtils:GetDistanceToPlayer(targetPlayer)
	local myRoot = self:GetRootPart()
	local targetRoot = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

	if myRoot and targetRoot then
		return (myRoot.Position - targetRoot.Position).Magnitude
	end

	return math.huge
end

function PlayerUtils:GetDistanceToPosition(position)
	local myRoot = self:GetRootPart()
	if myRoot then
		return (myRoot.Position - position).Magnitude
	end
	return 0
end

function PlayerUtils:GetFacingVector()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.LookVector
	end
	return Vector3.new(0, 0, -1)
end

function PlayerUtils:GetUpVector()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.UpVector
	end
	return Vector3.new(0, 1, 0)
end

-- // Profile Utilities \\
function PlayerUtils:GetPlayerId(player)
	if not player then return nil end
	if player:IsA("Player") then
		return player.UserId
	end
	return nil
end

function PlayerUtils:GetUniqueDisplayName(player)
	if not player then return "Unknown" end
	if player.DisplayName ~= player.Name then
		return player.DisplayName .. " (" .. player.Name .. ")"
	end
	return player.Name
end

function PlayerUtils:GenerateSessionId()
	return HttpService:GenerateGUID(false)
end

return PlayerUtils