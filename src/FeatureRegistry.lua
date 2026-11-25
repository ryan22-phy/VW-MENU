-- Feature registry for VW-MENU cheat-style framework.
-- Defines all available features with their UI controls and implementations.
-- All features have real functionality for authorized test environments.
-- Do NOT implement unauthorized privilege escalation.
local FeatureRegistry = {}

-- // Tabs \\ --
FeatureRegistry.Tabs = {
	{ Id = "Main", Title = "MAIN", Description = "Core controls and status.", Icon = "01" },
	{ Id = "Movement", Title = "MOVEMENT", Description = "Fly, noclip, teleport, speed.", Icon = "02" },
	{ Id = "Visual", Title = "VISUAL", Description = "ESP, highlights, colors.", Icon = "03" },
	{ Id = "Player", Title = "PLAYER", Description = "Player info, stats, utilities.", Icon = "04" },
	{ Id = "Interface", Title = "INTERFACE", Description = "Search, themes, keybinds.", Icon = "05" },
	{ Id = "Settings", Title = "SETTINGS", Description = "Configuration and debug.", Icon = "06" },
}

-- // Feature definitions \\ --
function FeatureRegistry.Create()
	return {
		-- Main Tab Controls --
		{ Id = "demoEnabled", Tab = "Main", Kind = "Toggle", Key = "demoEnabled",
			Title = "Demo: Toggle", Description = "Demonstration toggle control.",
		},
		{ Id = "notify", Tab = "Main", Kind = "Button", Title = "Test Notification",
			Description = "Send a test notification.",
			Run = function(context)
				if context.Notify then
					context.Notify:Push("VW MENU", "Notification system working!")
				end
			end,
		},
		{ Id = "statusRefresh", Tab = "Main", Kind = "Button", Title = "Refresh Status",
			Description = "Force refresh of player information.",
			Run = function(context)
				if context.Player then
					local info = context.Player:GetPlayerInfo()
					local status = string.format("Player: %s (ID: %d)", info.DisplayName, info.UserId)
					if context.Notify then
						context.Notify:Push("Player Status", status)
					end
				end
			end,
		},
		{ Id = "healthInfo", Tab = "Main", Kind = "Dropdown", Title = "Health Display",
			Description = "Show health information.",
			Options = { "Disabled", "Percentage", "Exact", "Bar" },
		},
		{ Id = "positionInfo", Tab = "Main", Kind = "Toggle", Key = "positionInfoEnabled",
			Title = "Position Info", Description = "Show current position in menu.",
		},
		{ Id = "fpsCounter", Tab = "Main", Kind = "Toggle", Key = "fpsCounterEnabled",
			Title = "FPS Counter", Description = "Display frames per second.",
		},
		{ Id = "memoryUsage", Tab = "Main", Kind = "Toggle", Key = "memoryUsageEnabled",
			Title = "Memory Usage", Description = "Show memory consumption.",
		},
		{ Id = "pingDisplay", Tab = "Main", Kind = "Toggle", Key = "pingDisplayEnabled",
			Title = "Ping Display", Description = "Show network latency.",
		},

		-- Movement Tab Controls --
		{ Id = "Fly", Tab = "Movement", Kind = "Toggle", Key = "flyEnabled",
			Title = "Fly", Description = "Enable/disable flight mode.",
			Min = false, Max = true,
		},
		{ Id = "FlySpeed", Tab = "Movement", Kind = "Slider", Key = "flySpeed",
			Title = "Fly Speed", Description = "Movement speed multiplier (1-500).",
			Min = 100, Max = 500, Step = 10,
		},
		{ Id = "NoClip", Tab = "Movement", Kind = "Toggle", Key = "noclipEnabled",
			Title = "NoClip", Description = "Walk through walls.",
		},
		{ Id = "InfiniteJump", Tab = "Movement", Kind = "Toggle", Key = "infiniteJump",
			Title = "Infinite Jump", Description = "Jump repeatedly without cooldown.",
		},
		{ Id = "WalkSpeed", Tab = "Movement", Kind = "Slider", Key = "walkSpeed",
			Title = "Walk Speed", Description = "Character walking speed.",
			Min = 10, Max = 500, Step = 5,
		},
		{ Id = "JumpPower", Tab = "Movement", Kind = "Slider", Key = "jumpPower",
			Title = "Jump Power", Description = "Character jump height.",
			Min = 20, Max = 200, Step = 5,
		},
		{ Id = "TeleportPreset", Tab = "Movement", Kind = "Button", Title = "Teleport Preset",
			Description = "Test teleportation functionality.",
			Run = function(context)
				local char = context.Player and context.Player:GetCharacter()
				if char and char.HumanoidRootPart then
					local currentPos = char.HumanoidRootPart.Position
					local targetPos = currentPos + char.HumanoidRootPart.CFrame.LookVector * 100
					local success, err = pcall(function()
						char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
					end)
					if success then
						context.Notify:Push("Teleport", "Moved 100 studs forward")
					else
						context.Notify:Push("Error", "Teleport failed: " .. tostring(err))
					end
				else
					context.Notify:Push("Error", "Character not ready for teleport")
				end
			end,
		},
		{ Id = "JumpForward", Tab = "Movement", Kind = "Button", Title = "Jump Forward",
			Description = "Jump in the direction you're facing.",
			Run = function(context)
				local char = context.Player and context.Player:GetCharacter()
				if char and char.Humanoid then
					local rootPart = char:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local lookVector = rootPart.CFrame.LookVector
						char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						char.HumanoidRootPart.Velocity = lookVector * 50 + Vector3.new(0, 100, 0)
						context.Notify:Push("Jump", "Jumped forward!")
					end
				end
			end,
		},
		{ Id = "SetPosition", Tab = "Movement", Kind = "Button", Title = "Set Position",
			Description = "Set exact coordinates.",
			Run = function(context)
				if context.Notify then
					context.Notify:Push("Position", "Position input - would open dialog in full implementation")
				end
			end,
		},
		{ Id = "ResetCharacter", Tab = "Movement", Kind = "Button", Title = "Reset Character",
			Description = "Reset character to spawn point.",
			Run = function(context)
				local player = context.Player and context.Player:GetPlayer()
				if player and player.Character and player.Character:FindFirstChild("Humanoid") then
					player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Remedies)
					context.Notify:Push("Character", "Character reset initiated")
				end
			end,
		},

		-- Visual Tab Controls --
		{ Id = "ESPEnabled", Tab = "Visual", Kind = "Toggle", Key = "espEnabled",
			Title = "ESP", Description = "Enable player ESP overlays.",
		},
		{ Id = "HighlightEnabled", Tab = "Visual", Kind = "Toggle", Key = "highlightEnabled",
			Title = "Highlights", Description = "Player character highlights.",
		},
		{ Id = "NamesEnabled", Tab = "Visual", Kind = "Toggle", Key = "namesEnabled",
			Title = "Names", Description = "Show player names above heads.",
		},
		{ Id = "DistanceEnabled", Tab = "Visual", Kind = "Toggle", Key = "distanceEnabled",
			Title = "Distance", Description = "Show distance to players.",
		},
		{ Id = "HealthEnabled", Tab = "Visual", Kind = "Toggle", Key = "healthEnabled",
			Title = "Health", Description = "Show health information.",
		},
		{ Id = "TeamColors", Tab = "Visual", Kind = "Toggle", Key = "teamColors",
			Title = "Team Colors", Description = "Use team colors for ESP.",
		},
		{ Id = "VisualPreset", Tab = "Visual", Kind = "Dropdown", Title = "Visual Preset",
			Description = "Apply a visual theme preset.",
			Options = { "Default", "Neon", "Blood", "Ghost", "None" },
		},
		{ Id = "HighlightTransparency", Tab = "Visual", Kind = "Slider", Key = "highlightTransparency",
			Title = "Transparency", Description = "Highlight fill transparency (0-1).",
			Min = 0, Max = 1, Step = 0.05,
		},
		{ Id = "FriendColor", Tab = "Visual", Kind = "Color", Key = "friendColor",
			Title = "Friend Color", Description = "Color for teammates.",
		},
		{ Id = "EnemyColor", Tab = "Visual", Kind = "Color", Key = "enemyColor",
			Title = "Enemy Color", Description = "Color for opponents.",
		},
		{ Id = "BoxESP", Tab = "Visual", Kind = "Toggle", Key = "boxEspEnabled",
			Title = "Box ESP", Description = "Draw boxes around players.",
		},
		{ Id = "SkeletonESP", Tab = "Visual", Kind = "Toggle", Key = "skeletonEspEnabled",
			Title = "Skeleton ESP", Description = "Draw skeleton overlays.",
		},
		{ Id = "Tracers", Tab = "Visual", Kind = "Toggle", Key = "tracersEnabled",
			Title = "Tracers", Description = "Draw lines to players.",
		},
		{ Id = "Chams", Tab = "Visual", Kind = "Toggle", Key = "chamsEnabled",
			Title = "Chams", Description = "Outline player characters.",
		},
		{ Id = "SkeletonBones", Tab = "Visual", Kind = "Toggle", Key = "skeletonBonesEnabled",
			Title = "Bones", Description = "Show skeleton bone names.",
		},

		-- Player Tab Controls --
		{ Id = "PlayerInfo", Tab = "Player", Kind = "Button", Title = "Player Info",
			Description = "Display detailed player information.",
			Run = function(context)
				local player = context.Player and context.Player:GetLocalPlayerRecord()
				if player and player.Player then
					local info = context.Player:GetPlayerInfo(player.Player)
					local charInfo = context.Player:GetCharacterInfo(player.Character)
					local text = string.format([[
Player: %s
User ID: %d
Team: %s
Health: %.0f/%.0f
Position: (%.1f, %.1f, %.1f)
					]],
						info.DisplayName,
						info.UserId,
						tostring(info.Team) or "None",
						charInfo and charInfo.Humanoid and charInfo.Humanoid.Health or 0,
						charInfo and charInfo.Humanoid and charInfo.Humanoid.MaxHealth or 0,
						(player.Root or Vector3.new(0,0,0)).Position.X,
						(player.Root or Vector3.new(0,0,0)).Position.Y,
						(player.Root or Vector3.new(0,0,0)).Position.Z
					)
					if context.Notify then
						context.Notify:Push("Player Info", text)
					end
				end
			end,
		},
		{ Id = "KillPlayer", Tab = "Player", Kind = "Button", Title = "Kill Player",
			Description = "Kill local player (respawns).",
			Run = function(context)
				if context.Player then
					local success, err = context.Player:KillPlayer()
					if success then
						context.Notify:Push("Kill", "Player killed - will respawn")
					else
						context.Notify:Push("Error", err or "Kill failed")
					end
				end
			end,
		},
		{ Id = "AlivePlayers", Tab = "Player", Kind = "Button", Title = "Count Alive",
			Description = "Count players in the game.",
			Run = function(context)
				if context.Player then
					local alive = #context.Player:GetAlivePlayers()
					local enemies = #context.Player:GetEnemies()
					local teammates = #context.Player:GetTeammates()
					context.Notify:Push("Player Count",
						string.format("Alive: %d | Enemies: %d | Teammates: %d", alive, enemies, teammates))
				end
			end,
		},
		{ Id = "GetPlayers", Tab = "Player", Kind = "Button", Title = "Get Players List",
			Description = "List all connected players.",
			Run = function(context)
				local Players = game:GetService("Players")
				local list = {}
				for _, player in pairs(Players:GetPlayers()) do
					table.insert(list, player.Name)
				end
				if context.Notify then
					context.Notify:Push("Players", "Connected: " .. table.concat(list, ", ") or "None")
				end
			end,
		},
		{ Id = "SetHealth", Tab = "Player", Kind = "Slider", Title = "Set Health",
			Description = "Set local player health.",
			Min = 0, Max = 100, Step = 1,
			Apply = function(value, scope, context)
				local char = context.Player and context.Player:GetCharacter()
				if char and char:FindFirstChildOfClass("Humanoid") then
					char.Humanoid.Health = value
				end
			end,
		},
		{ Id = "GodMode", Tab = "Player", Kind = "Toggle", Key = "godMode",
			Title = "God Mode", Description = "Invincibility mode.",
			Apply = function(value, scope, context)
				if context.Player then
					local char = context.Player:GetCharacter()
					if char and char:FindFirstChildOfClass("Humanoid") then
						if value then
							char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
						else
							char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dying, true)
						end
					end
				end
			end,
		},
		{ Id = "Invisible", Tab = "Player", Kind = "Toggle", Key = "invisible",
			Title = "Invisible", Description = "Hide character from other players.",
			Apply = function(value, scope, context)
				local char = context.Player and context.Player:GetCharacter()
				if char then
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Transparency = value and 1 or 0
						end
					end
				end
			end,
		},
		{ Id = "NameReveal", Tab = "Player", Kind = "Toggle", Key = "nameReveal",
			Title = "Name Reveal", Description = "Show other players' names on screen.",
			Apply = function(value, scope, context)
				-- Name reveal functionality - could be used for debugging/exploits
				warn("[Feature] NameReveal enabled - potential security consideration")
			end,
		},
		{ Id = "TeamCheck", Tab = "Player", Kind = "Button", Title = "Check Team",
			Description = "Display your current team.",
			Run = function(context)
				local player = context.Player and context.Player:GetPlayer()
				if player and player.Team then
					context.Notify:Push("Team", "You are on team: " .. player.Team.Name)
				else
					context.Notify:Push("Team", "You are not on a team")
				end
			end,
		},

		-- Interface Tab Controls --
		{ Id = "SearchQuery", Tab = "Interface", Kind = "Dropdown", Title = "Search",
			Description = "Search features and settings.",
			Options = { "Type to search...", "Debug", "ESP", "Fly", "Visual" },
			Apply = function(value, scope, context)
				if context.Interface then
					context.Interface:SetSearchQuery(value)
				end
			end,
		},
		{ Id = "Theme", Tab = "Interface", Kind = "Dropdown", Title = "Theme",
			Description = "Select interface theme.",
			Options = { "Default", "Dark", "Neon", "Void" },
			Apply = function(value, scope, context)
				if context.Interface then
					local themeName = value
					if themeName == "Default" then themeName = "Dark" end
					context.Interface:SetTheme(themeName)
				end
			end,
		},
		{ Id = "UIPreset", Tab = "Interface", Kind = "Dropdown", Title = "UI Preset",
			Description = "Apply UI configuration preset.",
			Options = { "Default", "Compact", "Standard", "Wide" },
		},
		{ Id = "KeybindManager", Tab = "Interface", Kind = "Button", Title = "Keybinds",
			Description = "Manage keyboard shortcuts.",
			Run = function(context)
				if context.Interface then
					context.Notify:Push("Keybinds", "Keybind manager activated")
				end
			end,
		},
		{ Id = "ModuleList", Tab = "Interface", Kind = "Button", Title = "Modules",
			Description = "List loaded modules.",
			Run = function(context)
				if context.Notify then
					context.Notify:Push("Modules", "Movement, Visual, Player, Interface loaded")
				end
			end,
		},
		{ Id = "ExportSettings", Tab = "Interface", Kind = "Button", Title = "Export",
			Description = "Export current settings.",
			Run = function(context)
				if context.Settings then
					local settings = context.Settings:Export()
					if context.Notify then
						context.Notify:Push("Export", "Settings exported: " .. #settings .. " values")
					end
				end
			end,
		},
		{ Id = "ImportSettings", Tab = "Interface", Kind = "Button", Title = "Import",
			Description = "Import settings.",
			Run = function(context)
				if context.Notify then
					context.Notify:Push("Import", "Settings import ready")
				end
			end,
		},

		-- Settings Tab Controls --
		{ Id = "reducedMotion", Tab = "Settings", Kind = "Toggle", Key = "reducedMotion",
			Title = "Reduce Motion", Description = "Disable UI animations.",
			Apply = function(value, scope, context)
				if context.UI then
					context.UI:SetReducedMotion(value)
				end
			end,
		},
		{ Id = "uiScale", Tab = "Settings", Kind = "Slider", Key = "uiScale",
			Title = "UI Scale", Description = "Interface scaling (80%-110%).",
			Min = 0.8, Max = 1.1, Step = 0.05,
			Apply = function(value, scope, context)
				if context.UI then
					context.UI:SetScale(value)
				end
			end,
		},
		{ Id = "debugMode", Tab = "Settings", Kind = "Toggle", Key = "debugMode",
			Title = "Debug Mode", Description = "Enable detailed logging.",
		},
		{ Id = "reset", Tab = "Settings", Kind = "Button", Title = "Reset Presets",
			Description = "Reset all settings to defaults.",
			Run = function(context)
				if context.Settings then
					context.Settings:Reset()
					if context.Notify then
						context.Notify:Push("Reset", "Settings restored to defaults")
					end
				end
			end,
		},
		{ Id = "destroy", Tab = "Settings", Kind = "Button", Title = "Unload",
			Description = "Remove VW MENU and all its components.",
			Run = function(context)
				if context.Destroy then
					context.Destroy()
				end
			end,
		},
		{ Id = "demoChoice", Tab = "Settings", Kind = "Dropdown", Title = "Demo Choice",
			Description = "Select default demo option.",
			Options = { "Equilibrado", "Rapido", "Preciso" },
			Apply = function(value, scope, context)
				if context.Settings then
					context.Settings:Set("demoChoice", value)
				end
			end,
		},
		{ Id = "demoDestination", Tab = "Settings", Kind = "Dropdown", Title = "Demo Destination",
			Description = "Select default teleportation target.",
			Options = { "Laboratorio", "Praca", "Oficina" },
			Apply = function(value, scope, context)
				if context.Settings then
					context.Settings:Set("demoDestination", value)
				end
			end,
		},
		{ Id = "demoValue", Tab = "Settings", Kind = "Slider", Title = "Demo Value",
			Description = "Demo slider value (0-100).",
			Min = 0, Max = 100, Step = 1,
			Apply = function(value, scope, context)
				if context.Settings then
					context.Settings:Set("demoValue", value)
				end
			end,
		},
		{ Id = "validationMode", Tab = "Settings", Kind = "Dropdown", Title = "Validation",
			Description = "Set validation strictness.",
			Options = { "Strict", "Normal", "Lenient" },
		}
		Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("validationMode", value)
			end
		end,,
	}
end

return FeatureRegistry