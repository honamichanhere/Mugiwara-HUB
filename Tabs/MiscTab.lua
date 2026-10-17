local ServerModule = getgenv().MugiwaraImport("Manager/Server.lua")
local KeybindsModule = getgenv().MugiwaraImport("Manager/Keybinds.lua")
local MovementModule = getgenv().MugiwaraImport("Manager/Movement.lua")
local CameraModule = getgenv().MugiwaraImport("Manager/Camera.lua")

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
    -- KEYBOARD SHORTCUTS
    -- ==========================================
    if KeybindsModule then
        local ShortcutSection = TabMisc:Section({ Title = "Keyboard Shortcuts", Icon = "lucide:keyboard", Opened = true, Box = true })

        ShortcutSection:Paragraph({
            Title = "How to change a shortcut",
            Desc = "Click a key box, then press the new key. Shortcuts do nothing while you type in chat, and mouse buttons are not supported. Keyboard only (PC)."
        })

        -- Membalik toggle lewat elemen UI-nya (kalau sudah dibuat) supaya tombol di UI ikut
        -- bergerak; kalau elemennya belum ada, langsung ubah state modulnya.
        local function Flip(ui, label, fallback)
            local state
            if ui and ui.Set then
                ui:Set(not ui.Value)
                state = ui.Value
            else
                state = fallback()
            end
            Notify(label, state and "Turned ON" or "Turned OFF", 1.5)
        end

        local Shortcuts = {
            { Id = "ToggleUI", Title = "Show / Hide Hub", Desc = "Open or close this window.", Default = "RightShift" },
            {
                Id = "Fly", Title = "Fly", Desc = "Turn Fly on or off.", Default = "G",
                Run = function()
                    if not MovementModule then return end
                    Flip(MovementModule.UI and MovementModule.UI.Fly, "Fly", function()
                        local state = not MovementModule.FlyEnabled
                        MovementModule.ToggleFly(state)
                        return state
                    end)
                end
            },
            {
                Id = "Noclip", Title = "Noclip", Desc = "Walk through walls on or off.", Default = "N",
                Run = function()
                    if not MovementModule then return end
                    Flip(MovementModule.UI and MovementModule.UI.Noclip, "Noclip", function()
                        MovementModule.NoclipEnabled = not MovementModule.NoclipEnabled
                        return MovementModule.NoclipEnabled
                    end)
                end
            },
            {
                Id = "Speed", Title = "Speed Hack", Desc = "Turn Speed Hack on or off. Uses the speed you set in the Main tab.", Default = "Z",
                Run = function()
                    if not MovementModule then return end
                    Flip(MovementModule.UI and MovementModule.UI.Speed, "Speed Hack", function()
                        MovementModule.SpeedEnabled = not MovementModule.SpeedEnabled
                        if not MovementModule.SpeedEnabled then MovementModule.RestoreSpeed() end
                        return MovementModule.SpeedEnabled
                    end)
                end
            },
            {
                Id = "InfJump", Title = "Infinite Jump", Desc = "Turn Infinite Jump on or off.", Default = "J",
                Run = function()
                    if not MovementModule then return end
                    Flip(MovementModule.UI and MovementModule.UI.InfJump, "Infinite Jump", function()
                        MovementModule.InfJumpEnabled = not MovementModule.InfJumpEnabled
                        return MovementModule.InfJumpEnabled
                    end)
                end
            },
            {
                Id = "Freecam", Title = "Free Camera", Desc = "Turn Free Camera on or off.", Default = "P", Premium = true,
                Run = function()
                    if not CameraModule then return end
                    if not isPremiumUser then
                        Notify("Premium Only", "Free Camera is a premium feature.", 2)
                        return
                    end
                    Flip(CameraModule.UI and CameraModule.UI.Freecam, "Free Camera", function()
                        local state = not CameraModule.FreecamEnabled
                        CameraModule.ToggleFreecam(state)
                        return state
                    end)
                end
            },
            {
                Id = "Panic", Title = "Panic: Unload Hub", Desc = "Instantly remove the hub and undo everything. No confirmation.", Default = "End",
                Run = function()
                    if getgenv().MugiwaraUnload then getgenv().MugiwaraUnload() end
                end
            },
        }

        local function ApplyUIKey(keyName)
            local keyCode = KeybindsModule.GetKeyCode(keyName)
            if keyCode and Window.SetToggleKey then pcall(Window.SetToggleKey, Window, keyCode) end
        end

        local entries = {}
        for _, def in ipairs(Shortcuts) do
            local initial = KeybindsModule.Get(def.Id, def.Default)
            local element = ShortcutSection:Keybind({
                Title = def.Title,
                Desc = def.Desc,
                Value = initial,
                Locked = def.Premium and not isPremiumUser or false,
                LockedTitle = "Premium Only",
                Callback = function()
                    if def.Run then def.Run() end
                end
            })
            table.insert(entries, { Def = def, Element = element, Last = initial })
            if def.Id == "ToggleUI" then ApplyUIKey(initial) end
        end

        ShortcutSection:Button({
            Title = "Reset Shortcuts",
            Desc = "Put every shortcut back to its default key.",
            Icon = "lucide:rotate-ccw",
            Callback = function()
                for _, entry in ipairs(entries) do
                    if entry.Element and entry.Element.Set then entry.Element:Set(entry.Def.Default) end
                end
                Notify("Shortcuts Reset", "All shortcuts are back to their default keys.")
            end
        })

        -- WindUI tidak punya event "key berubah", jadi nilai tiap Keybind dicek berkala.
        -- Di sini perubahan divalidasi, dicek bentrok, disimpan, dan diterapkan.
        local watching = true
        getgenv().MugiwaraRegisterCleanup(function() watching = false end)

        task.spawn(function()
            while watching do
                task.wait(0.5)
                for _, entry in ipairs(entries) do
                    local value = entry.Element and entry.Element.Value
                    if value ~= entry.Last then
                        if not KeybindsModule.IsValidKey(value) then
                            -- Tombol mouse tidak dipicu oleh Keybind WindUI, jadi dikembalikan.
                            entry.Element:Set(entry.Last)
                            Notify("Unsupported Key", "Only keyboard keys can be used as shortcuts.", 3)
                        else
                            local conflict
                            for _, other in ipairs(entries) do
                                if other ~= entry and other.Last == value then conflict = other.Def.Title end
                            end

                            entry.Last = value
                            KeybindsModule.Set(entry.Def.Id, value)
                            if entry.Def.Id == "ToggleUI" then ApplyUIKey(value) end

                            if conflict then
                                Notify("Shortcut Saved", entry.Def.Title .. " = " .. value .. ". Note: " .. conflict .. " uses the same key.", 4)
                            else
                                Notify("Shortcut Saved", entry.Def.Title .. " = " .. value, 2)
                            end
                        end
                    end
                end
            end
        end)
    end

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
