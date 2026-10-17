local ServerModule = getgenv().MugiwaraImport("Manager/Server.lua")

return function(Window, isPremiumUser, WindUI)

    local TabMisc = Window:Tab({ Title = "Misc", Icon = "lucide:wrench" })

    if not ServerModule then
        TabMisc:Paragraph({
            Title = "Misc Unavailable",
            Desc = "The server module failed to load. Re-execute the hub to try again."
        })
        return
    end

    local function Notify(title, content, duration)
        WindUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    -- Teleport yang ditolak Roblox (server penuh, private, dll) dilaporkan lewat sini.
    ServerModule.OnTeleportFailed = function(message)
        Notify("Teleport Failed", (message and message ~= "") and message or "Roblox refused the teleport.", 5)
    end

    -- ==========================================
    -- PROTECTION
    -- ==========================================
    local ProtectionSection = TabMisc:Section({ Title = "Protection", Icon = "lucide:shield-check", Opened = true, Box = true })

    ProtectionSection:Toggle({
        Title = "Anti-AFK",
        Desc = "Prevents Roblox from kicking you after 20 minutes of inactivity.",
        Value = true,
        Callback = function(Value)
            ServerModule.SetAntiAfk(Value)
        end
    })

    ProtectionSection:Toggle({
        Title = "Auto Rejoin",
        Desc = "Joins a new server automatically if you are kicked or disconnected (max 3 attempts).",
        Value = false,
        Callback = function(Value)
            ServerModule.SetAutoRejoin(Value)
        end
    })

    -- ==========================================
    -- SERVER
    -- ==========================================
    local ServerSection = TabMisc:Section({ Title = "Server", Icon = "lucide:server", Opened = true, Box = true })

    ServerSection:Button({
        Title = "Rejoin",
        Desc = "Reconnect to this server. Falls back to a new server if it is full or closed.",
        Icon = "lucide:refresh-cw",
        Callback = function()
            Notify("Rejoining", "Reconnecting to the server...")
            local ok, err = ServerModule.Rejoin()
            if not ok then Notify("Rejoin Failed", tostring(err), 4) end
        end
    })

    local hopMode = "Random"

    ServerSection:Dropdown({
        Title = "Server Hop Mode",
        Desc = "Which kind of server Server Hop should pick.",
        Values = ServerModule.HopModes,
        Value = hopMode,
        Callback = function(Option)
            if type(Option) == "string" then hopMode = Option end
        end
    })

    ServerSection:Button({
        Title = "Server Hop",
        Desc = "Move to a different public server of this game.",
        Icon = "lucide:shuffle",
        Callback = function()
            Notify("Server Hop", "Searching for a server...", 2)
            -- HttpGet menunggu respons, jadi dijalankan di thread terpisah agar UI tidak macet.
            task.spawn(function()
                local ok, message = ServerModule.Hop(hopMode)
                Notify(ok and "Server Hop" or "Server Hop Failed", tostring(message), ok and 3 or 4)
            end)
        end
    })

    ServerSection:Divider({ Title = "Job ID" })

    ServerSection:Button({
        Title = "Copy Job ID",
        Desc = "Copy this server's Job ID so someone else can join it.",
        Icon = "lucide:copy",
        Callback = function()
            if setclipboard then
                setclipboard(ServerModule.GetJobId())
                Notify("Job ID Copied", "The Job ID is in your clipboard.")
            else
                Notify("Copy Failed", "Your executor does not support setclipboard.", 4)
            end
        end
    })

    local targetJobId = ""

    ServerSection:Input({
        Title = "Job ID",
        Desc = "Paste the Job ID of a public server of this game, then press Join Server.",
        Placeholder = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        Callback = function(Text)
            targetJobId = tostring(Text or "")
        end
    })

    ServerSection:Button({
        Title = "Join Server",
        Desc = "Join the server with the Job ID above. Private servers cannot be joined this way.",
        Icon = "lucide:log-in",
        Callback = function()
            local ok, err = ServerModule.JoinJobId(targetJobId)
            if ok then
                Notify("Joining", "Teleporting to the server...")
            else
                Notify("Join Failed", tostring(err), 4)
            end
        end
    })

    -- ==========================================
    -- HUB
    -- ==========================================
    local HubSection = TabMisc:Section({ Title = "Hub", Icon = "lucide:power", Opened = true, Box = true })

    HubSection:Button({
        Title = "Unload Hub",
        Desc = "Remove the hub and undo everything it changed. Re-execute the script to bring it back.",
        Icon = "lucide:x-circle",
        Callback = function()
            Window:Dialog({
                Title = "Unload Hub?",
                Content = "All features will be turned off and the UI will close.",
                Buttons = {
                    { Title = "Cancel" },
                    {
                        Title = "Unload",
                        Callback = function()
                            if getgenv().MugiwaraUnload then getgenv().MugiwaraUnload() end
                        end
                    }
                }
            })
        end
    })

end
