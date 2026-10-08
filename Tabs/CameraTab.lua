-- ==========================================
-- CAMERA MANAGER LOADER
-- ==========================================
-- PENTING: Ganti URL ini pake raw link file CameraManager.lua dari GitHub lu!
local CameraModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/CameraManager.lua"))()

return function(Window, isPremiumUser, WindUI)
    
    local TabCamera = Window:Tab({ Title = "Camera", Icon = "lucide:video" })

    -- ==========================================
    -- 1. PREMIUM CAMERA CONTROLS
    -- ==========================================
    local PremiumSection = TabCamera:Section({ Title = '<font color="#ffff82">Premium Camera Controls</font>', Icon = "lucide:crown", Opened = true, Box = true })
    
    PremiumSection:Toggle({
        Title = "Enable Free Camera",
        Desc = "Detach and control the camera freely using WASD, Q/E, and Arrow Keys.",
        Locked = not isPremiumUser,
        Callback = function(Value)
            CameraModule.ToggleFreecam(Value)
        end
    })

    PremiumSection:Slider({
        Title = "Free Camera Speed",
        Desc = "Adjust the movement speed of the free camera.",
        Locked = not isPremiumUser,
        Step = 1,
        Value = { Min = 0, Max = 500, Default = 16 },
        Callback = function(Value)
            CameraModule.FreecamSpeed = Value
        end
    })

    PremiumSection:Divider({ Title = "Observation Mode" })

    local DropdownSpectate
    DropdownSpectate = PremiumSection:Dropdown({
        Title = "Spectate Player",
        Desc = "Select a player from the server to observe their perspective.",
        Locked = not isPremiumUser,
        Multi = false,
        Values = CameraModule.GetPlayerList(),
        Callback = function(Value)
            local success, msg = CameraModule.SetSpectate(Value)
            if success then
                WindUI:Notify({ Title = "Observation Active", Content = msg, Duration = 3 })
            else
                WindUI:Notify({ Title = "Observation Failed", Content = msg, Duration = 3 })
            end
        end
    })

    PremiumSection:Button({
        Title = "Refresh Player List",
        Desc = "Update the dropdown with the current active players in the server.",
        Locked = not isPremiumUser,
        Icon = "lucide:refresh-cw",
        Callback = function()
            if DropdownSpectate and DropdownSpectate.Refresh then
                DropdownSpectate:Refresh(CameraModule.GetPlayerList())
                WindUI:Notify({ Title = "List Updated", Content = "The player list has been successfully refreshed.", Duration = 2 })
            end
        end
    })

    PremiumSection:Button({
        Title = "Stop Spectating",
        Desc = "Return the camera to your own local character.",
        Locked = not isPremiumUser,
        Icon = "lucide:user-x",
        Callback = function()
            local success, msg = CameraModule.SetSpectate(nil)
            WindUI:Notify({ Title = "Camera Reset", Content = msg, Duration = 3 })
        end
    })

    -- ==========================================
    -- 2. FIELD OF VIEW CONTROLS (FREE)
    -- ==========================================
    local FovSection = TabCamera:Section({ Title = "Field of View Configuration", Icon = "lucide:eye", Opened = true, Box = true })

    FovSection:Toggle({
        Title = "Force Lock FOV",
        Desc = "Prevent the game from dynamically altering your field of view (e.g., during sprinting or taking damage).",
        Callback = function(Value)
            CameraModule.FOVLocked = Value
        end
    })

    FovSection:Slider({
        Title = "Adjust FOV",
        Desc = "Set your preferred field of view.",
        Step = 1,
        Value = { Min = 20, Max = 120, Default = 70 },
        Callback = function(Value)
            CameraModule.FOVValue = Value
        end
    })

end
