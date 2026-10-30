-- Minimal event boundary for CLI tests. This does not emulate rendering or Roblox scheduling.
return function()
    local signal = {Listeners = {}}
    function signal:Connect(callback)
        local connection = {Connected = true}
        function connection:Disconnect()
            self.Connected = false
            signal.Listeners[self] = nil
        end
        self.Listeners[connection] = callback
        return connection
    end
    function signal:Fire(...)
        for connection, callback in pairs(table.clone(self.Listeners)) do
            if connection.Connected then callback(...) end
        end
    end
    return signal
end
