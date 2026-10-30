local ServerModule = getgenv().MugiwaraImport("Manager/Server.lua")
local ShortcutsUI = getgenv().MugiwaraImport("Tabs/ShortcutsUI.lua")
local CursorModule = getgenv().MugiwaraImport("Manager/Cursor.lua")
local HideGuiModule = getgenv().MugiwaraImport("Manager/HideGui.lua")

return function(Window, isPremiumUser, MugiwaraUI)

    local TabMisc = Window:Tab({ Title = "Misc", Icon = "lucide:wrench" })

    if not ServerModule then
        TabMisc:Paragraph({
            Title = "Misc Unavailable",
            Icon = "lucide:triangle-alert",
            Desc = "The server module failed to load. Re-execute the hub to try again."
        })
        return
    end

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    -- Teleport yang ditolak Roblox (server penuh, private, dll) dilaporkan lewat sini.
    ServerModule.OnTeleportFailed = function(message)
        Notify("Teleport Failed", (message and message ~= "") and message or "Roblox refused the teleport.", 5)
    end

    -- ==========================================
    -- PROTECTION
    -- ==========================================
    local ProtectionSection = TabMisc:Section({ Title = "Protection", Icon = "lucide:shield-check", Opened = false, Box = true })

    ProtectionSection:Toggle({
        Title = "Anti-AFK",
        Icon = "lucide:coffee",
        Desc = "Prevents Roblox from kicking you after 20 minutes of inactivity.",
        Value = true,
        Callback = function(Value)
            ServerModule.SetAntiAfk(Value)
        end
    })

    ProtectionSection:Toggle({
        Title = "Auto Rejoin",
        Icon = "lucide:repeat",
        Desc = "Joins a new server automatically if you are kicked or disconnected (max 3 attempts).",
        Value = false,
        Callback = function(Value)
            ServerModule.SetAutoRejoin(Value)
        end
    })

    -- ==========================================
    -- SERVER
    -- ==========================================
    local ServerSection = TabMisc:Section({ Title = "Server", Icon = "lucide:server", Opened = false, Box = true })

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
        Icon = "lucide:server-cog",
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
        Icon = "lucide:hash",
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
    -- KEYBOARD SHORTCUTS
    -- ==========================================
    if ShortcutsUI then
        local ok, err = pcall(ShortcutsUI.Build, TabMisc, Window, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] Shortcuts UI error: " .. tostring(err)) end
    end

    -- ==========================================
    -- INTERFACE
    -- ==========================================
    if HideGuiModule then
        local InterfaceSection = TabMisc:Section({ Title = "Interface", Icon = "lucide:eye-off", Opened = false, Box = true })

        InterfaceSection:Toggle({
            Title = "Hide GUI",
            Icon = "lucide:eye-off",
            Desc = "Hides every other GUI: the game's menus, Roblox's own UI (chat, player list, top bar, touch controls), and other scripts' windows. Only this hub stays visible. Turn it off to bring everything back.",
            Value = false,
            Callback = function(Value)
                HideGuiModule.SetHidden(Value)
            end
        })
    end

    -- ==========================================
    -- HUB
    -- ==========================================
    local HubSection = TabMisc:Section({ Title = "Hub", Icon = "lucide:power", Opened = false, Box = true })

    if CursorModule then
        HubSection:Toggle({
            Title = "Free Cursor When Open",
            Icon = "lucide:mouse-pointer-2",
            Desc = "Unlock the mouse while this window is open, even with shift lock on.",
            Value = CursorModule.Enabled,
            Callback = function(Value)
                CursorModule.SetEnabled(Value)
            end
        })

        HubSection:Button({
            Title = "Lock Cursor",
            Desc = "Lock the mouse to the screen centre right now. Close and reopen the window to free it again.",
            Icon = "lucide:lock",
            Callback = function()
                CursorModule.Lock()
            end
        })
    end

    HubSection:Button({
        Title = "Unload Hub",
        Desc = "Remove the hub and undo everything it changed. Re-execute the script to bring it back.",
        Icon = "lucide:circle-x",
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
