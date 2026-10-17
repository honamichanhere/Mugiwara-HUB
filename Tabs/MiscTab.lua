local ServerModule = getgenv().MugiwaraImport("Manager/Server.lua")

return function(Window, isPremiumUser, WindUI)

    local TabMisc = Window:Tab({ Title = "Misc", Icon = "lucide:wrench" })

    local ServerSection = TabMisc:Section({ Title = "Server", Icon = "lucide:server", Opened = true, Box = true })

    ServerSection:Button({
        Title = "Rejoin",
        Desc = "Reconnect to this server. Falls back to a new server if it is full or closed.",
        Icon = "lucide:refresh-cw",
        Callback = function()
            if not ServerModule then
                WindUI:Notify({ Title = "Rejoin Failed", Content = "The server module failed to load.", Duration = 3 })
                return
            end

            WindUI:Notify({ Title = "Rejoining", Content = "Reconnecting to the server...", Duration = 3 })
            local ok, err = ServerModule.Rejoin()
            if not ok then
                WindUI:Notify({ Title = "Rejoin Failed", Content = tostring(err), Duration = 4 })
            end
        end
    })

end
