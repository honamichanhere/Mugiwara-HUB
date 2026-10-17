local CameraModule = getgenv().MugiwaraImport("Manager/Camera.lua")

return function(Window, isPremiumUser, WindUI)
    
    local TabCamera = Window:Tab({ Title = "Camera", Icon = "lucide:video" })

    local PremiumSection = TabCamera:Section({ Title = '<font color="#ffff82">Premium Features</font>', Icon = "rbxassetid://74594159374416", Opened = false, Box = true })
    
    local ToggleFreecam = PremiumSection:Toggle({
        Title = "Enable Free Camera",
        Desc = "Detach camera. Move with WASD/QE. Rotate by holding Right-Click or using Arrow Keys.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            CameraModule.ToggleFreecam(Value)
        end
    })

    -- Referensi toggle dipakai shortcut keyboard (tab Misc) supaya tombol UI ikut berubah.
    CameraModule.UI = { Freecam = ToggleFreecam }

    PremiumSection:Slider({
        Title = "Free Camera Speed",
        Desc = "Adjust the movement speed of the free camera.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
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
        LockedTitle = "Premium Only",
        Multi = false,
        Values = CameraModule.GetPlayerList(),
        Callback = function(Value)
            -- WindUI memanggil callback dropdown saat UI dibuat (nilai kosong); abaikan supaya
            -- tidak muncul notifikasi "Observation Active" tiap hub dijalankan.
            if type(Value) ~= "string" or Value == "" then return end

            local success, msg = CameraModule.SetSpectate(Value)
            WindUI:Notify({ Title = success and "Observation Active" or "Observation Failed", Content = msg, Duration = 3 })
        end
    })

    PremiumSection:Button({
        Title = "Refresh Player List",
        Desc = "Update the dropdown with the current active players in the server.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
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
        LockedTitle = "Premium Only",
        Icon = "lucide:user-x",
        Callback = function()
            local success, msg = CameraModule.SetSpectate(nil)
            WindUI:Notify({ Title = "Camera Reset", Content = msg, Duration = 3 })
        end
    })

    PremiumSection:Divider({ Title = "Global Stabilizer Engine" })

    PremiumSection:Slider({
        Title = "Position Stabilizer",
        Desc = "Adds spring-like lag to character tracking.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Step = 0.01,
        Value = { Min = 0, Max = 1, Default = 0 },
        Callback = function(Value)
            CameraModule.PositionStabilizer = Value
        end
    })

    PremiumSection:Slider({
        Title = "Rotation Stabilizer",
        Desc = "Smooths out camera aiming for a cinematic feel.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Step = 0.01,
        Value = { Min = 0, Max = 1, Default = 0 },
        Callback = function(Value)
            CameraModule.RotationStabilizer = Value
        end
    })

    local FovSection = TabCamera:Section({ Title = "Field of View", Icon = "lucide:eye", Opened = false, Box = true })

    local ToggleFOV
    ToggleFOV = FovSection:Toggle({
        Title = "Force Lock FOV",
        Desc = "Prevent the game from dynamically altering your field of view.",
        Callback = function(Value)
            CameraModule.FOVLocked = Value
            if not Value then CameraModule.RestoreFOV() end
        end
    })

    local safeFov = workspace.CurrentCamera and math.clamp(workspace.CurrentCamera.FieldOfView, 20, 120) or 70

    local SliderFOV
    SliderFOV = FovSection:Slider({
        Title = "Adjust FOV",
        Desc = "Set your preferred field of view. Syncs automatically if game alters it.",
        Step = 1,
        Value = { Min = 20, Max = 120, Default = safeFov },
        Callback = function(Value)
            CameraModule.SetFOV(Value)
        end
    })
    
    local ZoomSection = TabCamera:Section({ Title = "Zoom Configurations", Icon = "lucide:fullscreen", Opened = false, Box = true })

    ZoomSection:Toggle({
        Title = "Force Lock Zoom",
        Desc = "Lock camera distance. Prevents game or scrolling from altering zoom.",
        Callback = function(Value)
            CameraModule.ZoomLocked = Value
            if not Value and not CameraModule.FreecamEnabled then
                game:GetService("Players").LocalPlayer.CameraMinZoomDistance = 0.5
                game:GetService("Players").LocalPlayer.CameraMaxZoomDistance = 400
            end
        end
    })

    ZoomSection:Slider({
        Title = "Adjust Zoom Distance",
        Desc = "Set manual distance.",
        Step = 0.5,
        Value = { Min = 0, Max = 200, Default = 12.5 },
        Callback = function(Value)
            CameraModule.SetZoom(Value)
        end
    })

    CameraModule.OnFOVChanged = function(newValue)
        if SliderFOV then
            pcall(function() 
                if SliderFOV.SetValue then SliderFOV:SetValue(newValue)
                elseif SliderFOV.Set then SliderFOV:Set(newValue) end 
            end)
        end
    end

end
