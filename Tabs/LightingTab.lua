local LightingModule = getgenv().MugiwaraImport("Manager/Lighting.lua")

return function(Window, isPremiumUser, MugiwaraUI)
    
    local TabLighting = Window:Tab({ Title = "Lighting", Icon = "lucide:sun" })

    -- Semua data dihitung SEBELUM section dibuat, supaya section dan elemen pertamanya dibuat
    -- berurutan tanpa yield (download atau yield di antaranya bisa menunda tampilan section).
    local presetsList = LightingModule.GetPresetsList and LightingModule.GetPresetsList() or {}
    local skyboxNames2 = {}
    for name, id in pairs(LightingModule.SkyboxDatabase) do table.insert(skyboxNames2, name) end

    local PremiumSection = TabLighting:Section({
        Title = '<font color="#ffff82">Premium Features</font>',
        Icon = "rbxassetid://74594159374416",
        IconColor = Color3.fromRGB(255, 255, 130),
        Opened = false,
        Box = true
    })

    local VipLoadPreset = PremiumSection:Dropdown({
        Title = "Load Presets",
        Icon = "lucide:folder-open",
        Desc = "Select presets.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = presetsList,
        Value = "Default",
        Callback = function(Option)
            if type(Option) == "string" and Option ~= "" then
                LightingModule.LoadPreset(Option)
            end
        end
    })

    local VipSavePreset
    VipSavePreset = PremiumSection:Input({
        Title = "Save Preset",
        Icon = "lucide:save",
        Desc = "Save Lighting to a preset.",
        Placeholder = "Preset Name",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Text)
            if Text == "" then return end
            local success, status = LightingModule.SavePreset(Text) 
            if success then
                if status == "Overwrite" then
                    MugiwaraUI:Notify({ Title = "Preset Overwritten!", Content = "Preset '" .. Text .. "' successfully updated!", Duration = 3 })
                else
                    MugiwaraUI:Notify({ Title = "Preset Saved!", Content = "New preset '" .. Text .. "' successfully saved!", Duration = 3 })
                end           
                
                pcall(function() VipSavePreset:Set("") end)
                
                if VipLoadPreset and VipLoadPreset.Refresh then
                    VipLoadPreset:Refresh(LightingModule.GetPresetsList())
                end
            end
        end
    })

    local VipSkyBox = PremiumSection:Dropdown({
        Title = "Sky Box",
        Desc = "Change Sky Box.",
        Icon = "lucide:cloudy",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = skyboxNames2,
        Value = "Default Sky",
        Callback = function(Option)
            local assetId = LightingModule.SkyboxDatabase[Option]
            if assetId and assetId ~= "" then LightingModule.LoadSkybox(assetId) end
        end
    })

    local VipLoadSkyBox
    VipLoadSkyBox = PremiumSection:Input({
        Title = "Load Sky Box",
        Icon = "lucide:download",
        Desc = "Load Sky Box via Asset ID.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Placeholder = "Asset ID",
        Callback = function(Text)
            if Text == "" then return end
            LightingModule.LoadSkybox(Text) 
            pcall(function() VipLoadSkyBox:Set("") end)
        end
    })

    local VipSkyAnim = PremiumSection:Toggle({
        Title = "Sky Box Animation",
        Icon = "lucide:rotate-cw",
        Desc = "Animate the skybox by rotating it.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value) LightingModule.SkyAnimEnabled = Value end
    })

    local VipSkyRot = PremiumSection:Slider({
        Title = "Rotation Speed",
        Icon = "lucide:gauge",
        Desc = "Set the rotation speed of the skybox.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Step = 1,
        Value = { Min = 0, Max = 100, Default = 10 },
        Callback = function(Value) LightingModule.SkyAnimSpeed = Value end
    })

    local VipCopySky = PremiumSection:Button({
        Title = "Copy Sky Box",
        Icon = "lucide:copy",
        Desc = "Copy current Sky Box to Database.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local success, msg = LightingModule.CopySkybox()
            MugiwaraUI:Notify({ Title = success and "Success!" or "Failed!", Content = msg, Duration = 3 })
        end
    })

    local VipPasteSky = PremiumSection:Button({
        Title = "Paste Sky Box",
        Icon = "lucide:clipboard-paste",
        Desc = "Paste Sky Box from Database.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            local success, msg = LightingModule.PasteSkybox()
            MugiwaraUI:Notify({ Title = success and "Success!" or "Failed!", Content = msg, Duration = 3 })
        end
    })

    TabLighting:Divider({ Title = "System Control" })
    TabLighting:Toggle({ Title = "Lock Lighting", Icon = "lucide:lock", Desc = "Force Override! Lock all values in this script; prevent the game from altering the lighting.", Locked = false, Callback = function(Value) LightingModule.SetLock(Value) end })

    local UIElements = { Lighting = {}, Atmosphere = {}, Bloom = {}, Blur = {}, ColorCorrection = {}, DepthOfField = {}, SunRays = {}, Clouds = {} }

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
    UIElements.Lighting.Ambient = Lighting:Colorpicker({ Title = "Ambient", Icon = "lucide:lamp", Default = objL.Ambient, Callback = function(Value) LightingModule.UpdateValue("Lighting", "Ambient", Value) end })
    UIElements.Lighting.Brightness = Lighting:Slider({ Title = "Brightness", Icon = "lucide:sun-medium", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.Brightness.Min, Max = LightingModule.Limits.Lighting.Brightness.Max, Default = objL.Brightness }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "Brightness", Value) end })
    UIElements.Lighting.ColorShift_Top = Lighting:Colorpicker({ Title = "Color Shift Top", Icon = "lucide:arrow-up-to-line", Default = objL.ColorShift_Top, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ColorShift_Top", Value) end })
    UIElements.Lighting.ColorShift_Bottom = Lighting:Colorpicker({ Title = "Color Shift Bottom", Icon = "lucide:arrow-down-to-line", Default = objL.ColorShift_Bottom, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ColorShift_Bottom", Value) end })
    UIElements.Lighting.EnvironmentDiffuseScale = Lighting:Slider({ Title = "Environment Diffuse Scale", Icon = "lucide:scan", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.EnvironmentDiffuseScale.Min, Max = LightingModule.Limits.Lighting.EnvironmentDiffuseScale.Max, Default = objL.EnvironmentDiffuseScale }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "EnvironmentDiffuseScale", Value) end })
    UIElements.Lighting.EnvironmentSpecularScale = Lighting:Slider({ Title = "Environment Specular Scale", Icon = "lucide:sparkle", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.EnvironmentSpecularScale.Min, Max = LightingModule.Limits.Lighting.EnvironmentSpecularScale.Max, Default = objL.EnvironmentSpecularScale }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "EnvironmentSpecularScale", Value) end })
    UIElements.Lighting.GlobalShadows = Lighting:Toggle({ Title = "Global Shadows", Icon = "lucide:layers", Value = objL.GlobalShadows, Callback = function(Value) LightingModule.UpdateValue("Lighting", "GlobalShadows", Value) end })
    UIElements.Lighting.OutdoorAmbient = Lighting:Colorpicker({ Title = "Outdoor Ambient", Icon = "lucide:tree-pine", Default = objL.OutdoorAmbient, Callback = function(Value) LightingModule.UpdateValue("Lighting", "OutdoorAmbient", Value) end })
    UIElements.Lighting.ShadowSoftness = Lighting:Slider({ Title = "Shadow Softness", Icon = "lucide:blend", Step = 0.01, Value = { Min = LightingModule.Limits.Lighting.ShadowSoftness.Min, Max = LightingModule.Limits.Lighting.ShadowSoftness.Max, Default = objL.ShadowSoftness }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ShadowSoftness", Value) end })
    UIElements.Lighting.ClockTime = Lighting:Slider({ Title = "Clock Time", Icon = "lucide:clock", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ClockTime.Min, Max = LightingModule.Limits.Lighting.ClockTime.Max, Default = objL.ClockTime }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ClockTime", Value) end })
    UIElements.Lighting.GeographicLatitude = Lighting:Slider({ Title = "Geographic Latitude", Icon = "lucide:globe", Step = 1, Value = { Min = LightingModule.Limits.Lighting.GeographicLatitude.Min, Max = LightingModule.Limits.Lighting.GeographicLatitude.Max, Default = objL.GeographicLatitude }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "GeographicLatitude", Value) end })
    UIElements.Lighting.ExposureCompensation = Lighting:Slider({ Title = "Exposure Compensation", Icon = "lucide:aperture", Step = 0.1, Value = { Min = LightingModule.Limits.Lighting.ExposureCompensation.Min, Max = LightingModule.Limits.Lighting.ExposureCompensation.Max, Default = objL.ExposureCompensation }, Callback = function(Value) LightingModule.UpdateValue("Lighting", "ExposureCompensation", Value) end })
    Lighting:Toggle({ Title = "Hide Sun", Icon = "lucide:eye-off", Desc = "Hide the sun (and moon) in the sky. Sun Rays is a separate effect.", Value = LightingModule.SunHidden, Callback = function(Value) LightingModule.SetSunHidden(Value) end })

    local objAtm = LightingModule.Objects["Atmosphere"]
    local Atmosphere = TabLighting:Section({ Title = "Atmosphere", Icon = "lucide:sun-dim", Opened = false, Box = true })
    UIElements.Atmosphere.Density = Atmosphere:Slider({ Title = "Density", Icon = "lucide:cloud-fog", Step = 0.01, Value = { Min = LightingModule.Limits.Atmosphere.Density.Min, Max = LightingModule.Limits.Atmosphere.Density.Max, Default = objAtm.Density }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Density", Value) end })
    UIElements.Atmosphere.Offset = Atmosphere:Slider({ Title = "Offset", Icon = "lucide:move-vertical", Step = 0.01, Value = { Min = LightingModule.Limits.Atmosphere.Offset.Min, Max = LightingModule.Limits.Atmosphere.Offset.Max, Default = objAtm.Offset }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Offset", Value) end })
    UIElements.Atmosphere.Color = Atmosphere:Colorpicker({ Title = "Color", Icon = "lucide:palette", Default = objAtm.Color, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Color", Value) end })
    UIElements.Atmosphere.Decay = Atmosphere:Colorpicker({ Title = "Decay Color", Icon = "lucide:pipette", Default = objAtm.Decay, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Decay", Value) end })
    UIElements.Atmosphere.Glare = Atmosphere:Slider({ Title = "Glare", Icon = "lucide:sun", Step = 0.1, Value = { Min = LightingModule.Limits.Atmosphere.Glare.Min, Max = LightingModule.Limits.Atmosphere.Glare.Max, Default = objAtm.Glare }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Glare", Value) end })
    UIElements.Atmosphere.Haze = Atmosphere:Slider({ Title = "Haze", Icon = "lucide:wind", Step = 0.1, Value = { Min = LightingModule.Limits.Atmosphere.Haze.Min, Max = LightingModule.Limits.Atmosphere.Haze.Max, Default = objAtm.Haze }, Callback = function(Value) LightingModule.UpdateValue("Atmosphere", "Haze", Value) end })

    local objBloom = LightingModule.Objects["Bloom"]
    local Bloom = TabLighting:Section({ Title = "Bloom", Icon = "lucide:target", Opened = false, Box = true })
    UIElements.Bloom.Enabled = Bloom:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objBloom.Enabled, Callback = function(Value) LightingModule.ToggleEffect("Bloom", Value) end })
    UIElements.Bloom.Intensity = Bloom:Slider({ Title = "Intensity", Icon = "lucide:zap", Step = 0.1, Value = { Min = LightingModule.Limits.Bloom.Intensity.Min, Max = LightingModule.Limits.Bloom.Intensity.Max, Default = objBloom.Intensity }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Intensity", Value) end })
    UIElements.Bloom.Size = Bloom:Slider({ Title = "Size", Icon = "lucide:maximize", Step = 1, Value = { Min = LightingModule.Limits.Bloom.Size.Min, Max = LightingModule.Limits.Bloom.Size.Max, Default = objBloom.Size }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Size", Value) end })
    UIElements.Bloom.Threshold = Bloom:Slider({ Title = "Threshold", Icon = "lucide:sliders-horizontal", Step = 0.1, Value = { Min = LightingModule.Limits.Bloom.Threshold.Min, Max = LightingModule.Limits.Bloom.Threshold.Max, Default = objBloom.Threshold }, Callback = function(Value) LightingModule.UpdateValue("Bloom", "Threshold", Value) end })

    local objBlur = LightingModule.Objects["Blur"]
    local Blur = TabLighting:Section({ Title = "Blur", Icon = "lucide:droplet", Opened = false, Box = true })
    UIElements.Blur.Enabled = Blur:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objBlur.Enabled, Callback = function(Value) LightingModule.ToggleEffect("Blur", Value) end })
    UIElements.Blur.Size = Blur:Slider({ Title = "Size", Icon = "lucide:maximize", Step = 1, Value = { Min = LightingModule.Limits.Blur.Size.Min, Max = LightingModule.Limits.Blur.Size.Max, Default = objBlur.Size }, Callback = function(Value) LightingModule.UpdateValue("Blur", "Size", Value) end })

    local objCC = LightingModule.Objects["ColorCorrection"]
    local ColorCorrection = TabLighting:Section({ Title = "Color Correction", Icon = "lucide:palette", Opened = false, Box = true })
    UIElements.ColorCorrection.Enabled = ColorCorrection:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objCC.Enabled, Callback = function(Value) LightingModule.ToggleEffect("ColorCorrection", Value) end })
    UIElements.ColorCorrection.Brightness = ColorCorrection:Slider({ Title = "Brightness", Icon = "lucide:sun-medium", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Brightness.Min, Max = LightingModule.Limits.ColorCorrection.Brightness.Max, Default = objCC.Brightness }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Brightness", Value) end })
    UIElements.ColorCorrection.Contrast = ColorCorrection:Slider({ Title = "Contrast", Icon = "lucide:contrast", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Contrast.Min, Max = LightingModule.Limits.ColorCorrection.Contrast.Max, Default = objCC.Contrast }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Contrast", Value) end })
    UIElements.ColorCorrection.Saturation = ColorCorrection:Slider({ Title = "Saturation", Icon = "lucide:droplets", Step = 0.01, Value = { Min = LightingModule.Limits.ColorCorrection.Saturation.Min, Max = LightingModule.Limits.ColorCorrection.Saturation.Max, Default = objCC.Saturation }, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "Saturation", Value) end })
    UIElements.ColorCorrection.TintColor = ColorCorrection:Colorpicker({ Title = "Tint", Icon = "lucide:pipette", Default = objCC.TintColor, Callback = function(Value) LightingModule.UpdateValue("ColorCorrection", "TintColor", Value) end })

    local objDoF = LightingModule.Objects["DepthOfField"]
    local DepthOfField = TabLighting:Section({ Title = "Depth Of Field", Icon = "lucide:focus", Opened = false, Box = true })
    UIElements.DepthOfField.Enabled = DepthOfField:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objDoF.Enabled, Callback = function(Value) LightingModule.ToggleEffect("DepthOfField", Value) end })
    UIElements.DepthOfField.FarIntensity = DepthOfField:Slider({ Title = "Far Intensity", Icon = "lucide:mountain", Step = 0.01, Value = { Min = LightingModule.Limits.DepthOfField.FarIntensity.Min, Max = LightingModule.Limits.DepthOfField.FarIntensity.Max, Default = objDoF.FarIntensity }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "FarIntensity", Value) end })
    UIElements.DepthOfField.FocusDistance = DepthOfField:Slider({ Title = "Focus Distance", Icon = "lucide:focus", Step = 1, Value = { Min = LightingModule.Limits.DepthOfField.FocusDistance.Min, Max = LightingModule.Limits.DepthOfField.FocusDistance.Max, Default = objDoF.FocusDistance }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "FocusDistance", Value) end })
    UIElements.DepthOfField.InFocusRadius = DepthOfField:Slider({ Title = "In Focus Radius", Icon = "lucide:circle-dot", Step = 1, Value = { Min = LightingModule.Limits.DepthOfField.InFocusRadius.Min, Max = LightingModule.Limits.DepthOfField.InFocusRadius.Max, Default = objDoF.InFocusRadius }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "InFocusRadius", Value) end })
    UIElements.DepthOfField.NearIntensity = DepthOfField:Slider({ Title = "Near Intensity", Icon = "lucide:eye", Step = 0.01, Value = { Min = LightingModule.Limits.DepthOfField.NearIntensity.Min, Max = LightingModule.Limits.DepthOfField.NearIntensity.Max, Default = objDoF.NearIntensity }, Callback = function(Value) LightingModule.UpdateValue("DepthOfField", "NearIntensity", Value) end })

    local objSun = LightingModule.Objects["SunRays"]
    local SunRays = TabLighting:Section({ Title = "Sun Rays", Icon = "lucide:sun", Opened = false, Box = true })
    UIElements.SunRays.Enabled = SunRays:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objSun.Enabled, Callback = function(Value) LightingModule.ToggleEffect("SunRays", Value) end })
    UIElements.SunRays.Intensity = SunRays:Slider({ Title = "Intensity", Icon = "lucide:zap", Step = 0.01, Value = { Min = LightingModule.Limits.SunRays.Intensity.Min, Max = LightingModule.Limits.SunRays.Intensity.Max, Default = objSun.Intensity }, Callback = function(Value) LightingModule.UpdateValue("SunRays", "Intensity", Value) end })
    UIElements.SunRays.Spread = SunRays:Slider({ Title = "Spread", Icon = "lucide:expand", Step = 0.01, Value = { Min = LightingModule.Limits.SunRays.Spread.Min, Max = LightingModule.Limits.SunRays.Spread.Max, Default = objSun.Spread }, Callback = function(Value) LightingModule.UpdateValue("SunRays", "Spread", Value) end })

    -- Volumetric Clouds (objek Clouds di Terrain). Objek dicari SEBELUM section dibuat supaya elemen
    -- pertama langsung menyusul tanpa jeda (lihat catatan di bagian Premium Features).
    local objClouds = LightingModule.Objects["Clouds"]
    if objClouds then
        local Clouds = TabLighting:Section({ Title = "Volumetric Clouds", Icon = "lucide:cloud", Opened = false, Box = true })
        UIElements.Clouds.Enabled = Clouds:Toggle({ Title = "Enabled", Icon = "lucide:power", Value = objClouds.Enabled, Callback = function(Value) LightingModule.ToggleEffect("Clouds", Value) end })
        UIElements.Clouds.Cover = Clouds:Slider({ Title = "Cover", Icon = "lucide:cloud", Step = 0.01, Value = { Min = LightingModule.Limits.Clouds.Cover.Min, Max = LightingModule.Limits.Clouds.Cover.Max, Default = objClouds.Cover }, Callback = function(Value) LightingModule.UpdateValue("Clouds", "Cover", Value) end })
        UIElements.Clouds.Density = Clouds:Slider({ Title = "Density", Icon = "lucide:cloud-fog", Step = 0.01, Value = { Min = LightingModule.Limits.Clouds.Density.Min, Max = LightingModule.Limits.Clouds.Density.Max, Default = objClouds.Density }, Callback = function(Value) LightingModule.UpdateValue("Clouds", "Density", Value) end })
        UIElements.Clouds.Color = Clouds:Colorpicker({ Title = "Color", Icon = "lucide:palette", Default = objClouds.Color, Callback = function(Value) LightingModule.UpdateValue("Clouds", "Color", Value) end })
    end

end
