local LightingModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/LightingManager.lua"))()

return function(Window, isPremiumUser, WindUI)
    
    local TabLighting = Window:Tab({ Title = "Lighting", Icon = "lucide:sun" })
    
    local UIElements = { Lighting = {}, Atmosphere = {}, Bloom = {}, Blur = {}, ColorCorrection = {}, DepthOfField = {}, SunRays = {} }

    -- 1. PRESET MANAGER (PREMIUM)
    local PresetSection = TabLighting:Section({ Title = "Preset Configuration", Icon = "lucide:save", Opened = true, Box = true })
    
    local VipSavePreset, VipLoadPreset, VipLoadSkyBox
    
    VipSavePreset = PresetSection:Input({
        Title = "Save Custom Preset",
        Desc = "Save your current lighting configuration to a local file. (Premium Only)",
        Placeholder = "Enter preset name...",
        Locked = not isPremiumUser,
        Callback = function(Text)
            if Text == "" then return end
            local success, msg = LightingModule.SavePreset(Text)
            if success then
                WindUI:Notify({ Title = "Preset Saved", Content = "Successfully saved lighting preset as: " .. Text, Duration = 3 })
                pcall(function() VipSavePreset:Set("") end)
            else
                WindUI:Notify({ Title = "Save Failed", Content = msg, Duration = 3 })
            end
        end
    })

    VipLoadPreset = PresetSection:Input({
        Title = "Load Custom Preset",
        Desc = "Load a previously saved custom lighting configuration. (Premium Only)",
        Placeholder = "Enter preset name...",
        Locked = not isPremiumUser,
        Callback = function(Text)
            if Text == "" then return end
            LightingModule.LoadPreset(Text)
            WindUI:Notify({ Title = "Preset Loaded", Content = "Successfully loaded preset: " .. Text, Duration = 3 })
            pcall(function() VipLoadPreset:Set("") end)
        end
    })

    PresetSection:Dropdown({
        Title = "Built-in Presets",
        Desc = "Select from pre-configured cinematic lighting setups.",
        Multi = false,
        Options = {"Default", "Cozy Sunset", "Horor Vibe", "Cyberpunk", "Realistic"},
        Callback = function(Value)
            LightingModule.LoadPreset(Value)
            WindUI:Notify({ Title = "Preset Applied", Content = "Successfully loaded built-in preset: " .. Value, Duration = 3 })
        end
    })

    VipLoadSkyBox = PresetSection:Input({
        Title = "Load Custom Skybox",
        Desc = "Enter a Roblox Image ID to apply a custom skybox texture.",
        Placeholder = "e.g., 1234567890",
        Callback = function(Text)
            if Text == "" then return end
            LightingModule.LoadSkybox(Text)
            WindUI:Notify({ Title = "Skybox Applied", Content = "Successfully loaded Custom Skybox ID: " .. Text, Duration = 3 })
            pcall(function() VipLoadSkyBox:Set("") end)
        end
    })

    -- 2. ENVIRONMENT & OBSERVER CONTROLS
    local ControlSection = TabLighting:Section({ Title = "Environment Controls", Icon = "lucide:settings-2", Opened = false, Box = true })
    
    ControlSection:Toggle({
        Title = "Force Lock Lighting",
        Desc = "Prevent the server/game from altering your lighting setup. If disabled, Observer Mode will auto-sync UI with the game.",
        Callback = function(Value) LightingModule.LockEnabled = Value end
    })
    
    ControlSection:Toggle({
        Title = "Enable Skybox Animation",
        Desc = "Automatically rotate the skybox to create a dynamic background effect.",
        Callback = function(Value) LightingModule.SkyAnimEnabled = Value end
    })

    ControlSection:Slider({
        Title = "Skybox Rotation Speed",
        Desc = "Adjust how fast the skybox rotates.",
        Step = 0.1,
        Value = { Min = 0.1, Max = 10, Default = 1 },
        Callback = function(Value) LightingModule.SkyAnimSpeed = Value end
    })

    -- FUNGSI PEMBANTU (UI GENERATOR)
    local function AddSlider(Section, Cat, Prop, Title, Min, Max, Def)
        local stepVal = (Max - Min <= 10) and 0.01 or 0.1
        UIElements[Cat][Prop] = Section:Slider({ Title = Title, Step = stepVal, Value = { Min = Min, Max = Max, Default = Def }, Callback = function(v) LightingModule.UpdateValue(Cat, Prop, v) end })
    end
    local function AddColor(Section, Cat, Prop, Title, Def)
        UIElements[Cat][Prop] = Section:Colorpicker({ Title = Title, Default = Def, Callback = function(v) LightingModule.UpdateValue(Cat, Prop, v) end })
    end
    local function AddToggle(Section, Cat, Prop, Title)
        UIElements[Cat][Prop] = Section:Toggle({ Title = Title, Callback = function(v) LightingModule.UpdateValue(Cat, Prop, v) end })
    end

    -- 3. GLOBAL LIGHTING
    local LgtSec = TabLighting:Section({ Title = "Global Lighting", Icon = "lucide:globe", Opened = false, Box = true })
    AddSlider(LgtSec, "Lighting", "Brightness", "Brightness Level", 0, 10, 2)
    AddSlider(LgtSec, "Lighting", "ClockTime", "Clock Time (Hours)", 0, 24, 12)
    AddSlider(LgtSec, "Lighting", "ExposureCompensation", "Exposure Compensation", -3, 3, 0)
    AddSlider(LgtSec, "Lighting", "EnvironmentDiffuseScale", "Diffuse Scale", 0, 1, 1)
    AddSlider(LgtSec, "Lighting", "EnvironmentSpecularScale", "Specular Scale", 0, 1, 1)
    AddSlider(LgtSec, "Lighting", "ShadowSoftness", "Shadow Softness", 0, 1, 0.2)
    AddToggle(LgtSec, "Lighting", "GlobalShadows", "Enable Global Shadows")
    AddColor(LgtSec, "Lighting", "Ambient", "Ambient Color", Color3.fromRGB(138, 138, 138))
    AddColor(LgtSec, "Lighting", "OutdoorAmbient", "Outdoor Ambient", Color3.fromRGB(128, 128, 128))
    AddColor(LgtSec, "Lighting", "ColorShift_Top", "Color Shift Top", Color3.fromRGB(0, 0, 0))
    AddColor(LgtSec, "Lighting", "ColorShift_Bottom", "Color Shift Bottom", Color3.fromRGB(0, 0, 0))

    -- 4. COLOR CORRECTION
    local CcSec = TabLighting:Section({ Title = "Color Correction", Icon = "lucide:palette", Opened = false, Box = true })
    AddSlider(CcSec, "ColorCorrection", "Brightness", "Brightness", -1, 1, 0)
    AddSlider(CcSec, "ColorCorrection", "Contrast", "Contrast", -1, 2, 0)
    AddSlider(CcSec, "ColorCorrection", "Saturation", "Saturation", -1, 5, 0)
    AddColor(CcSec, "ColorCorrection", "TintColor", "Tint Color", Color3.fromRGB(255, 255, 255))

    -- 5. ATMOSPHERE
    local AtmSec = TabLighting:Section({ Title = "Atmosphere", Icon = "lucide:cloud", Opened = false, Box = true })
    AddSlider(AtmSec, "Atmosphere", "Density", "Atmosphere Density", 0, 1, 0.3)
    AddSlider(AtmSec, "Atmosphere", "Offset", "Atmosphere Offset", 0, 1, 0)
    AddSlider(AtmSec, "Atmosphere", "Glare", "Atmosphere Glare", 0, 1, 0)
    AddSlider(AtmSec, "Atmosphere", "Haze", "Atmosphere Haze", 0, 5, 0)
    AddColor(AtmSec, "Atmosphere", "Color", "Atmosphere Color", Color3.fromRGB(199, 199, 199))
    AddColor(AtmSec, "Atmosphere", "Decay", "Decay Color", Color3.fromRGB(106, 112, 125))

    -- 6. BLOOM & BLUR
    local BbSec = TabLighting:Section({ Title = "Bloom & Blur", Icon = "lucide:droplet", Opened = false, Box = true })
    AddSlider(BbSec, "Bloom", "Intensity", "Bloom Intensity", 0, 5, 1)
    AddSlider(BbSec, "Bloom", "Size", "Bloom Size", 0, 56, 24)
    AddSlider(BbSec, "Bloom", "Threshold", "Bloom Threshold", 0, 4, 2)
    AddSlider(BbSec, "Blur", "Size", "Blur Size", 0, 56, 0)

    -- 7. DEPTH OF FIELD & SUNRAYS
    local DfSec = TabLighting:Section({ Title = "Depth of Field & SunRays", Icon = "lucide:focus", Opened = false, Box = true })
    AddSlider(DfSec, "DepthOfField", "FocusDistance", "Focus Distance", 0, 500, 0.05)
    AddSlider(DfSec, "DepthOfField", "InFocusRadius", "In-Focus Radius", 0, 50, 30)
    AddSlider(DfSec, "DepthOfField", "NearIntensity", "Near Intensity", 0, 1, 0.75)
    AddSlider(DfSec, "DepthOfField", "FarIntensity", "Far Intensity", 0, 1, 0.1)
    AddSlider(DfSec, "SunRays", "Intensity", "SunRays Intensity", 0, 1, 0.25)
    AddSlider(DfSec, "SunRays", "Spread", "SunRays Spread", 0, 1, 0.1)

    -- 8. SYNC ENGINE BRIDGE (OBSERVER MODE)
    LightingModule.OnPresetLoaded = function()
        for cat, props in pairs(UIElements) do
            for propName, element in pairs(props) do
                local targetValue = LightingModule.TargetValues[cat] and LightingModule.TargetValues[cat][propName]
                if targetValue ~= nil and type(element) == "table" then
                    pcall(function()
                        if element.SetValue then element:SetValue(targetValue)
                        elseif element.Set then element:Set(targetValue)
                        elseif element.SetColor then element:SetColor(targetValue)
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
                if element.SetValue then element:SetValue(newValue)
                elseif element.Set then element:Set(newValue)
                elseif element.SetColor then element:SetColor(newValue)
                end
            end)
        end
    end

end
