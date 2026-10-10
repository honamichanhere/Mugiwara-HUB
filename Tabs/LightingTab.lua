local LightingModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/LightingManager.lua"))()
local ReflectionModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/ReflectionManager.lua"))()

return function(Window, isPremiumUser, WindUI)
    
    local TabLighting = Window:Tab({ Title = "Lighting", Icon = "lucide:sun" })

    local lockMsg = "Buy premium to unlock!"

    local skyboxNames = {}
    if LightingModule.SkyboxDatabase then
        for name, id in pairs(LightingModule.SkyboxDatabase) do table.insert(skyboxNames, name) end
    else
        table.insert(skyboxNames, "Default Sky")
    end

    local VipLoadPreset = TabLighting:Dropdown({
        Title = "Load Presets",
        Desc = "Select presets.",
        Locked = not isPremiumUser,
        Values = LightingModule.GetPresetsList and LightingModule.GetPresetsList() or {},
        Value = "Default",
        Callback = function(Option)
            if Option and Option.Title then
                LightingModule.LoadPreset(Option.Title) 
            end
        end
    })

    local VipSavePreset
    VipSavePreset = TabLighting:Input({
        Title = "Save Preset",
        Desc = "Save Lighting to a preset.",
        Placeholder = "Preset Name",
        Locked = not isPremiumUser,
        Callback = function(Text)
            if Text == "" then return end
            local success, status = LightingModule.SavePreset(Text) 
            if success then
                if status == "Overwrite" then
                    WindUI:Notify({ Title = "Preset Overwritten!", Content = "Preset '" .. Text .. "' successfully updated!", Duration = 3 })
                else
                    WindUI:Notify({ Title = "Preset Saved!", Content = "New preset '" .. Text .. "' successfully saved!", Duration = 3 })
                end           
                
                pcall(function() VipSavePreset:Set("") end)
                
                if VipLoadPreset and VipLoadPreset.Refresh then
                    VipLoadPreset:Refresh(LightingModule.GetPresetsList())
                end
            end
        end
    })

    local skyboxNames2 = {}
    for name, id in pairs(LightingModule.SkyboxDatabase) do table.insert(skyboxNames2, name) end

    local VipSkyBox = TabLighting:Dropdown({
        Title = "Sky Box",
        Desc = "Change Sky Box.",
        Icon = "lucide:cloudy",
        Locked = not isPremiumUser,
        Values = skyboxNames2,
        Value = "Default Sky",
        Callback = function(Option)
            local assetId = LightingModule.SkyboxDatabase[Option]
            if assetId and assetId ~= "" then LightingModule.LoadSkybox(assetId) end
        end
    })

    local VipLoadSkyBox
    VipLoadSkyBox = TabLighting:Input({
        Title = "Load Sky Box",
        Desc = "Load Sky Box via Asset ID.",
        Locked = not isPremiumUser,
        Placeholder = "Asset ID",
        Callback = function(Text)
            if Text == "" then return end
            LightingModule.LoadSkybox(Text) 
            pcall(function() VipLoadSkyBox:Set("") end)
        end
    })

    local VipSkyAnim = TabLighting:Toggle({
        Title = "Sky Box Animation",
        Desc = "Animate the skybox by rotating it.",
        Locked = not isPremiumUser,
        Callback = function(Value) LightingModule.SkyAnimEnabled = Value end
    })

    local VipSkyRot = TabLighting:Slider({
        Title = "Rotation Speed",
        Desc = "Set the rotation speed of the skybox.",
        Locked = not isPremiumUser,
        Step = 1,
        Value = { Min = 0, Max = 100, Default = 10 },
        Callback = function(Value) LightingModule.SkyAnimSpeed = Value end
    })

    local VipCopySky = TabLighting:Button({
        Title = "Copy Sky Box",
        Desc = "Copy current Sky Box to Database.",
        Locked = not isPremiumUser,
        Callback = function()
            local success, msg = LightingModule.CopySkybox()
            WindUI:Notify({ Title = success and "Success!" or "Failed!", Content = msg, Duration = 3 })
        end
    })

    local VipPasteSky = TabLighting:Button({
        Title = "Paste Sky Box",
        Desc = "Paste Sky Box from Database.",
        Locked = not isPremiumUser,
        Callback = function()
            local success, msg = LightingModule.PasteSkybox()
            WindUI:Notify({ Title = success and "Success!" or "Failed!", Content = msg, Duration = 3 })
        end
    })

    -- ==========================================
    -- GRAPHIC HACKS (PREMIUM)
    -- ==========================================
    TabLighting:Divider({ Title = "Graphic Hacks" })

    TabLighting:Toggle({
        Title = "Glass Reflection Effect",
        Desc = "Create deep reflections by exploiting glass material with out-of-bounds transparency.",
        Locked = not isPremiumUser,
        Callback = function(Value)
            if Value then
                WindUI:Notify({ Title = "Processing", Content = "Generating reflection layers. Please wait...", Duration = 3 })
            else
                WindUI:Notify({ Title = "Cleaning Up", Content = "Removing reflection layers...", Duration = 3 })
            end
            task.spawn(function()
                ReflectionModule.Toggle(Value)
            end)
        end
    })

    TabLighting:Slider({
        Title = "Reflection Depth (Transparency)",
        Desc = "Push transparency out of bounds for deeper reflections.",
        Locked = not isPremiumUser,
        Step = 0.5,
        Value = { Min = 1, Max = 10, Default = 1.5 },
        Callback = function(Value)
            task.spawn(function()
                ReflectionModule.UpdateSettings(Value, nil)
            end)
        end
    })

    TabLighting:Slider({
        Title = "Reflection Shell Offset",
        Desc = "Adjust the size offset of the reflection shell (studs).",
        Locked = not isPremiumUser,
        Step = 0.1,
        Value = { Min = 0, Max = 5, Default = 0.5 },
        Callback = function(Value)
            task.spawn(function()
                ReflectionModule.UpdateSettings(nil, Value)
            end)
        end
    })

    TabLighting:Divider({ Title = "System Control" })
    TabLighting:Toggle({ Title = "Lock Lighting", Desc = "Force Override! Lock all values in this script; prevent the game from altering the lighting.", Locked = false, Callback = function(Value) LightingModule.LockEnabled = Value end })

    -- ==========================================
    -- MESIN SINKRONISASI UI (JEMBATAN DARI MANAGER)
    -- ==========================================
    local UIElements = { Lighting = {}, Atmosphere = {}, Bloom = {}, Blur = {}, ColorCorrection = {}, DepthOfField = {}, SunRays = {} }

    LightingModule.OnPresetLoaded = function()
        for cat, props in pairs(UIElements) do
            for propName, element in pairs(props) do
                local targetValue = LightingModule.TargetValues[cat] and LightingModule.TargetValues[cat][propName]
                
                if targetValue ~= nil and type(element) == "table" then
                    pcall(function()
                        if element.SetValue then 
                            element:SetValue(targetValue) 
                        elseif element.Set then 
                            element:Set(targetValue) 
                        elseif element.SetColor then
                            element:SetColor(targetValue)
                        end
                    end)
                end
            end
        end
    end

    LightingModule.OnPropertyChanged = function(category, property, newValue)
        local element = UIElements[category] and UIElements[category][property]
        if element then
            pcall(function()
                if element.SetValue then 
                    element:SetValue(newValue) 
                elseif element.Set then 
                    element:Set(newValue) 
                elseif element.SetColor then
                    element:SetColor(newValue)
                end
            end)
        end
    end

    local objL = LightingModule.Objects["Lighting"]
    local Lighting = TabLighting:Section({ Title = "Lighting", Icon = "lucide:haze", Opened = false, Box = true })
    UIElements.Lighting.Ambient = Lighting:Colorpicker({ Title = "Ambient", Default = objL.Ambient, Callback = function(Value) LightingModule.UpdateValue("Lighting", "Ambient", Value) end })
    UIElements.Lighting.Brightness = Lighting:Slider({ Title = "Brightness", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.Brightness.Min, Max = LightingModule.Limits.Lighting.Brightness.Max, Default = objL.Brightness }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "Brightness", Value) end })
    UIElements.Lighting.ColorShift_Top = Lighting:Colorpicker({ Title = "Color Shift Top", Default = objL.ColorShift_Top, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ColorShift_Top", Value) end })
    UIElements.Lighting.ColorShift_Bottom = Lighting:Colorpicker({ Title = "Color Shift Bottom", Default = objL.ColorShift_Bottom, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ColorShift_Bottom", Value) end })
    UIElements.Lighting.EnvironmentDiffuseScale = Lighting:Slider({ Title = "Environment Diffuse Scale", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.EnvironmentDiffuseScale.Min, Max = LightingModule.Limits.Lighting.EnvironmentDiffuseScale.Max, Default = objL.EnvironmentDiffuseScale }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "EnvironmentDiffuseScale", Value) end })
    UIElements.Lighting.EnvironmentSpecularScale = Lighting:Slider({ Title = "Environment Specular Scale", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.EnvironmentSpecularScale.Min, Max = LightingModule.Limits.Lighting.EnvironmentSpecularScale.Max, Default = objL.EnvironmentSpecularScale }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "EnvironmentSpecularScale", Value) end })
    UIElements.Lighting.GlobalShadows = Lighting:Toggle({ Title = "Global Shadows", Value = objL.GlobalShadows, Callback = function(Value) LightingModule.UpdateValue("Lighting", "GlobalShadows", Value) end })
    UIElements.Lighting.OutdoorAmbient = Lighting:Colorpicker({ Title = "Outdoor Ambient", Default = objL.OutdoorAmbient, Callback = function(Value) LightingModule.UpdateValue("Lighting", "OutdoorAmbient", Value) end })
    UIElements.Lighting.ShadowSoftness = Lighting:Slider({ Title = "Shadow Softness", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.ShadowSoftness.Min, Max = LightingModule.Limits.Lighting.ShadowSoftness.Max, Default = objL.ShadowSoftness }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ShadowSoftness", Value) end })
    UIElements.Lighting.ClockTime = Lighting:Slider({ Title = "Clock Time", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ClockTime.Min, Max = LightingModule.Limits.Lighting.ClockTime.Max, Default = objL.ClockTime }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ClockTime", Value) end })
    UIElements.Lighting.GeographicLatitude = Lighting:Slider({ Title = "Geographic Latitude", Step = 1, Value = { Min = LightingModule.Limits.Lighting.GeographicLatitude.Min, Max = LightingModule.Limits.Lighting.GeographicLatitude.Max, Default = objL.GeographicLatitude }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "GeographicLatitude", Value) end })
    UIElements.Lighting.ExposureCompensation = Lighting:Slider({ Title = "Exposure Compensation", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ExposureCompensation.Min, Max = LightingModule.Limits.Lighting.ExposureCompensation.Max, Default = objL.ExposureCompensation }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ExposureCompensation", Value) end })

    local objAtm = LightingModule.Objects["Atmosphere"]
    local Atmosphere = TabLighting:Section({ Title = "Atmosphere", Icon = "lucide:sun-dim", Opened = false, Box = true })
    UIElements.Atmosphere.Density = Atmosphere:Slider({ Title = "Density", Step = 0.01, Value = { Min = LightingModule.Limits.Atmosphere.Density.Min, Max = LightingModule.Limits.Atmosphere.Density.Max, Default = objAtm.Density }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Density", Value) end })
    UIElements.Atmosphere.Offset = Atmosphere:Slider({ Title = "Offset", Step = 0.01, Value = { Min = LightingModule.Limits.Atmosphere.Offset.Min, Max = LightingModule.Limits.Atmosphere.Offset.Max, Default = objAtm.Offset }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Offset", Value) end })
    UIElements.Atmosphere.Color = Atmosphere:Colorpicker({ Title = "Color", Default = objAtm.Color, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Color", Value) end })
    UIElements.Atmosphere.Decay = Atmosphere:Colorpicker({ Title = "Decay Color", Default = objAtm.Decay, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Decay", Value) end })
    UIElements.Atmosphere.Glare = Atmosphere:Slider({ Title = "Glare", Step = 0.1, Value = { Min = LightingModule.Limits.Atmosphere.Glare.Min, Max = LightingModule.Limits.Atmosphere.Glare.Max, Default = objAtm.Glare }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Glare", Value) end })
    UIElements.Atmosphere.Haze = Atmosphere:Slider({ Title = "Haze", Step = 0.1, Value = { Min = LightingModule.Limits.Atmosphere.Haze.Min, Max = LightingModule.Limits.Atmosphere.Haze.Max, Default = objAtm.Haze }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Haze", Value) end })

    local objBloom = LightingModule.Objects["Bloom"]
    local Bloom = TabLighting:Section({ Title = "Bloom", Icon = "lucide:target", Opened = false, Box = true })
    UIElements.Bloom.Enabled = Bloom:Toggle({ Title = "Enabled", Value = objBloom.Enabled, Callback = function(Value) LightingModule.ToggleEffect("Bloom", Value) end })
    UIElements.Bloom.Intensity = Bloom:Slider({ Title = "Intensity", Step = 0.1, Value = { Min = LightingModule.Limits.Bloom.Intensity.Min, Max = LightingModule.Limits.Bloom.Intensity.Max, Default = objBloom.Intensity }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Intensity", Value) end })
    UIElements.Bloom.Size = Bloom:Slider({ Title = "Size", Step = 1, Value = { Min = LightingModule.Limits.Bloom.Size.Min, Max = LightingModule.Limits.Bloom.Size.Max, Default = objBloom.Size }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Size", Value) end })
    UIElements.Bloom.Threshold = Bloom:Slider({ Title = "Threshold", Step = 0.1, Value = { Min = LightingModule.Limits.Bloom.Threshold.Min, Max = LightingModule.Limits.Bloom.Threshold.Max, Default = objBloom.Threshold }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Threshold", Value) end })

    local objBlur = LightingModule.Objects["Blur"]
    local Blur = TabLighting:Section({ Title = "Blur", Icon = "lucide:droplet", Opened = false, Box = true })
    UIElements.Blur.Enabled = Blur:Toggle({ Title = "Enabled", Value = objBlur.Enabled, Callback = function(Value) LightingModule.ToggleEffect("Blur", Value) end })
    UIElements.Blur.Size = Blur:Slider({ Title = "Size", Step = 1, Value = { Min = LightingModule.Limits.Blur.Size.Min, Max = LightingModule.Limits.Blur.Size.Max, Default = objBlur.Size }, Callback = function(Value) LightingModule.UpdateValue("Blur", "Size", Value) end })

    local objCC = LightingModule.Objects["ColorCorrection"]
    local ColorCorrection = TabLighting:Section({ Title = "Color Correction", Icon = "lucide:palette", Opened = false, Box = true })
    UIElements.ColorCorrection.Enabled = ColorCorrection:Toggle({ Title = "Enabled", Value = objCC.Enabled, Callback = function(Value) LightingModule.ToggleEffect("ColorCorrection", Value) end })
    UIElements.ColorCorrection.Brightness = ColorCorrection:Slider({ Title = "Brightness", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Brightness.Min, Max = LightingModule.Limits.ColorCorrection.Brightness.Max, Default = objCC.Brightness }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Brightness", Value) end })
    UIElements.ColorCorrection.Contrast = ColorCorrection:Slider({ Title = "Contrast", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Contrast.Min, Max = LightingModule.Limits.ColorCorrection.Contrast.Max, Default = objCC.Contrast }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Contrast", Value) end })
    UIElements.ColorCorrection.Saturation = ColorCorrection:Slider({ Title = "Saturation", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Saturation.Min, Max = LightingModule.Limits.ColorCorrection.Saturation.Max, Default = objCC.Saturation }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Saturation", Value) end })
    UIElements.ColorCorrection.TintColor = ColorCorrection:Colorpicker({ Title = "Tint", Default = objCC.TintColor, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "TintColor", Value) end })

    local objDoF = LightingModule.Objects["DepthOfField"]
    local DepthOfField = TabLighting:Section({ Title = "Depth Of Field", Icon = "lucide:focus", Opened = false, Box = true })
    UIElements.DepthOfField.Enabled = DepthOfField:Toggle({ Title = "Enabled", Value = objDoF.Enabled, Callback = function(Value) LightingModule.ToggleEffect("DepthOfField", Value) end })
    UIElements.DepthOfField.FarIntensity = DepthOfField:Slider({ Title = "Far Intensity", Step = 0.01, Value = { Min = LightingModule.Limits.DepthOfField.FarIntensity.Min, Max = LightingModule.Limits.DepthOfField.FarIntensity.Max, Default = objDoF.FarIntensity }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "FarIntensity", Value) end })
    UIElements.DepthOfField.FocusDistance = DepthOfField:Slider({ Title = "Focus Distance", Step = 1, Value = { Min = LightingModule.Limits.DepthOfField.FocusDistance.Min, Max = LightingModule.Limits.DepthOfField.FocusDistance.Max, Default = objDoF.FocusDistance }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "FocusDistance", Value) end })
    UIElements.DepthOfField.InFocusRadius = DepthOfField:Slider({ Title = "In Focus Radius", Step = 1, Value = { Min = LightingModule.Limits.DepthOfField.InFocusRadius.Min, Max = LightingModule.Limits.DepthOfField.InFocusRadius.Max, Default = objDoF.InFocusRadius }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "InFocusRadius", Value) end })
    UIElements.DepthOfField.NearIntensity = DepthOfField:Slider({ Title = "Near Intensity", Step = 0.01, Value = { Min = LightingModule.Limits.DepthOfField.NearIntensity.Min, Max = LightingModule.Limits.DepthOfField.NearIntensity.Max, Default = objDoF.NearIntensity }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "NearIntensity", Value) end })

    local objSun = LightingModule.Objects["SunRays"]
    local SunRays = TabLighting:Section({ Title = "Sun Rays", Icon = "lucide:sun", Opened = false, Box = true })
    UIElements.SunRays.Enabled = SunRays:Toggle({ Title = "Enabled", Value = objSun.Enabled, Callback = function(Value) LightingModule.ToggleEffect("SunRays", Value) end })
    UIElements.SunRays.Intensity = SunRays:Slider({ Title = "Intensity", Step = 0.01, Value = { Min = LightingModule.Limits.SunRays.Intensity.Min, Max = LightingModule.Limits.SunRays.Intensity.Max, Default = objSun.Intensity }, Callback = function(Value) LightingModule.UpdateValue("SunRays", "Intensity", Value) end })
    UIElements.SunRays.Spread = SunRays:Slider({ Title = "Spread", Step = 0.01, Value = { Min = LightingModule.Limits.SunRays.Spread.Min, Max = LightingModule.Limits.SunRays.Spread.Max, Default = objSun.Spread }, Callback = function(Value) LightingModule.UpdateValue("SunRays", "Spread", Value) end })

end
