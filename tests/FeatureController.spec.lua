-- Teste de comportamento. No cliente Studio: require(spec)(folderDeModulos).
return function(modules)
    local CleanupManager = require(modules.CleanupManager)
    local SettingsManager = require(modules.SettingsManager)
    local FeatureController = require(modules.FeatureController)
    local player = Instance.new("Player")
    local root = CleanupManager.new()
    local messages = {}
    local settings = SettingsManager.new(player)
    local notices = { Push = function(_, title, body) table.insert(messages, { title, body }) end }
    local controller = FeatureController.new(settings, notices, root, {})
    local stops = 0
    controller:Register({ Id = "worker", Kind = "Toggle", Key = "demoEnabled",
        Apply = function(value, scope)
            if value then scope:Add(function() stops += 1 end) end
        end,
    })
    assert(controller:Set("worker", true))
    assert(controller:Set("worker", true))
    assert(stops == 0, "same value must not duplicate work")
    assert(controller:Set("worker", false))
    assert(stops == 1, "toggle off must stop old work")
    assert(not controller:Set("worker", "yes"), "invalid boolean must be rejected")
    assert(controller:Get("worker") == false)
    controller:Register({ Id = "broken", Kind = "Button", Run = function() error("expected test error") end })
    assert(not controller:Activate("broken"), "callback errors must be contained")
    assert(#messages == 1)
    assert(controller:Set("worker", true))
    root:Destroy()
    root:Destroy()
    assert(stops == 2, "owner destroy must stop worker once")
    assert(not controller:Set("worker", true), "destroyed controller cannot start work")
    player:Destroy()
    return "FeatureController: PASS"
end
