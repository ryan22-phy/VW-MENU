-- Place this LocalScript and its sibling ModuleScripts in StarterPlayerScripts/VWMenu.
local Main = require(script.Parent.Main)
local app = Main.Start()
-- Removing the bootstrap also closes its owned controller.
app.Cleanup:Add(script.Destroying:Connect(function() app.Destroy() end))
