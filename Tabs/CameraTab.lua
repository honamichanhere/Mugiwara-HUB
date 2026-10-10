-- ==========================================
-- CAMERA MANAGER LOADER
-- ==========================================
local CameraModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/CameraManager.lua"))()

return function(Window, isPremiumUser, WindUI)
    
    local TabCamera = Window:Tab({ Title = "Camera", Icon = "lucide:video" })

    -- ==========================================
    -- 1. PREMIUM CAMERA CONTROLS
    -- ==========================================
    local PremiumSection = TabCamera:Section({ Title = '<font color="#ffff82">Premium Camera Controls</font>', Icon = "lucide:crown", Opened = true, Box = true })
    
    PremiumSection:Toggle({
        Title = "Enable Free Camera",
        Desc = "Detach camera. Move with WASD/QE. Rotate by holding Right-Click or using Arrow Keys.",
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
            WindUI:Notify({ Title = success and "Observation Active" or "Observation Failed", Content = msg, Duration = 3 })
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

    PremiumSection:Divider({ Title = "Global Stabilizer Engine" })

    PremiumSection:Slider({
        Title = "Position Stabilizer",
        Desc = "Adds spring-like lag to character tracking. 0 = Instant, 1 = Max Smoothness.",
        Locked = not isPremiumUser,
        Step = 0.01,
        Value = { Min = 0, Max = 1, Default = 0 },
        Callback = function(Value)
            CameraModule.PositionStabilizer = Value
        end
    })

    PremiumSection:Slider({
        Title = "Rotation Stabilizer",
        Desc = "Smooths out camera aiming for a cinematic feel. 0 = Instant, 1 = Max Smoothness.",
        Locked = not isPremiumUser,
        Step = 0.01,
        Value = { Min = 0, Max = 1, Default = 0 },
        Callback = function(Value)
            CameraModule.RotationStabilizer = Value
        end
    })

    -- ==========================================
    -- 2. FIELD OF VIEW & ZOOM CONTROLS (FREE)
    -- ==========================================
    local FovSection = TabCamera:Section({ Title = "Field of View & Zoom Configuration", Icon = "lucide:eye", Opened = true, Box = true })

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
    
    FovSection:Divider({ Title = "Zoom Controls" })

    FovSection:Toggle({
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

    local initialZoom = workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position - workspace.CurrentCamera.Focus.Position).Magnitude or 12.5

    -- Menggunakan Input sebagai pengganti Slider untuk tes stabilitas UI
    local InputZoom
    InputZoom = FovSection:Input({
        Title = "Adjust Zoom Distance",
        Desc = "Enter distance (0 - 200). Auto-syncs when you scroll.",
        PlaceholderText = tostring(math.floor(initialZoom)),
        ClearTextOnFocus = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num then
                CameraModule.SetZoom(math.clamp(num, 0, 200))
            end
        end
    })

    -- ==========================================
    -- 3. UI SYNC ENGINE (OBSERVER)
    -- ==========================================
    CameraModule.OnFOVChanged = function(newValue)
        if SliderFOV then
            pcall(function() 
                if SliderFOV.SetValue then SliderFOV:SetValue(newValue)
                elseif SliderFOV.Set then SliderFOV:Set(newValue) end 
            end)
        end
    end

    CameraModule.OnZoomChanged = function(newValue)
        if InputZoom then
            pcall(function() 
                local textValue = tostring(math.floor(newValue * 10) / 10)
                if InputZoom.SetValue then InputZoom:SetValue(textValue)
                elseif InputZoom.Set then InputZoom:Set(textValue) end 
            end)
        end
    end

end
end
