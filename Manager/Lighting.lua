local LightingModule = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ROOT = getgenv().MugiwaraFolder or "MugiwaraHub"
local PREFIX = "Mugiwara_" -- semua instance yang dibuat modul ini memakai prefix ini

if makefolder and isfolder then
    if not isfolder(ROOT) then makefolder(ROOT) end
    if not isfolder(ROOT .. "/Presets") then makefolder(ROOT .. "/Presets") end
end

LightingModule.BuiltInPresets = {
    ["Default Roblox"] = {
        Desc = "Roblox default Lighting.",
        Skybox = "18504982898",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(70, 70, 70),
                Brightness = 3,
                ColorShift_Top = Color3.fromRGB(0, 0, 0),
                ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
                EnvironmentDiffuseScale = 1,
                EnvironmentSpecularScale = 1,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(70, 70, 70),
                ClockTime = 14.5,
                ExposureCompensation = 0
            },
            Atmosphere = {
                Density = 0.3,
                Offset = 0.25,
                Color = Color3.fromRGB(199, 199, 199),
                Decay = Color3.fromRGB(106, 112, 125),
                Glare = 0,
                Haze = 0
            },
            Bloom = {
                Enabled = true,
                Intensity = 1,
                Size = 24,
                Threshold = 2
            },
            Blur = {
                Enabled = false,
                Size = 24
            },
            DepthOfField = {
                Enabled = false,
                FarIntensity = 0.1,
                FocusDistance = 0.05,
                InFocusRadius = 30,
                NearIntensity = 0.75
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.01,
                Spread = 0.1
            }
        }
    },
    ["Realistic Sunset"] = {
        Desc = "Golden hour hangat, fog tipis dari warna skybox.",
        Skybox = "2573514779",
        Values = {
            Lighting = {
                Ambient = Color3.fromRGB(105, 85, 92),
                Brightness = 2.4,
                ColorShift_Top = Color3.fromRGB(255, 170, 110),
                ColorShift_Bottom = Color3.fromRGB(70, 50, 80),
                EnvironmentDiffuseScale = 0.9,
                EnvironmentSpecularScale = 0.8,
                GlobalShadows = true,
                OutdoorAmbient = Color3.fromRGB(135, 108, 115),
                ShadowSoftness = 0.35,
                ClockTime = 17,
                GeographicLatitude = 15,
                ExposureCompensation = -0.1
            },
            Atmosphere = {
                Density = 0.36,
                Offset = 0.35,
                Color = Color3.fromRGB(225, 175, 150),
                Decay = Color3.fromRGB(150, 90, 80),
                Glare = 0.2,
                Haze = 0
            },
            Bloom = {
                Enabled = true,
                Intensity = 0.5,
                Size = 24,
                Threshold = 2.2
            },
            Blur = {
                Enabled = false,
                Size = 4
            },
            ColorCorrection = {
                Enabled = true,
                Brightness = 0,
                Contrast = 0.12,
                Saturation = -0.05,
                TintColor = Color3.fromRGB(255, 238, 225)
            },
            DepthOfField = {
                Enabled = true,
                FarIntensity = 0.08,
                FocusDistance = 120,
                InFocusRadius = 60,
                NearIntensity = 0.1
            },
            SunRays = {
                Enabled = true,
                Intensity = 0.08,
                Spread = 0.7
            }
        }
    }
}

LightingModule.LockEnabled = false
LightingModule.DefaultSkybox = nil 
LightingModule.ActiveSkybox = nil 
LightingModule.OnPresetLoaded = nil
LightingModule.OnPropertyChanged = nil
LightingModule.LastObserve = 0

LightingModule.Objects = { Lighting = Lighting }
LightingModule.Defaults = {} 
LightingModule.TargetValues = {} 

LightingModule.Limits = {
    Lighting = { Brightness = {Min = 0, Max = 10}, EnvironmentDiffuseScale = {Min = 0, Max = 1}, EnvironmentSpecularScale = {Min = 0, Max = 1}, ShadowSoftness = {Min = 0, Max = 1}, ClockTime = {Min = 0, Max = 24}, GeographicLatitude = {Min = -90, Max = 90}, ExposureCompensation = {Min = -3, Max = 3} },
    Atmosphere = { Density = {Min = 0, Max = 1}, Offset = {Min = 0, Max = 1}, Glare = {Min = 0, Max = 10}, Haze = {Min = 0, Max = 10} },
    Bloom = { Intensity = {Min = 0, Max = 10}, Size = {Min = 0, Max = 56}, Threshold = {Min = 0, Max = 10} },
    Blur = { Size = {Min = 0, Max = 56} },
    ColorCorrection = { Brightness = {Min = -1, Max = 1}, Contrast = {Min = -1, Max = 1}, Saturation = {Min = -1, Max = 1} },
    DepthOfField = { FarIntensity = {Min = 0, Max = 1}, FocusDistance = {Min = 0, Max = 500}, InFocusRadius = {Min = 0, Max = 50}, NearIntensity = {Min = 0, Max = 1} },
    SunRays = { Intensity = {Min = 0, Max = 1}, Spread = {Min = 0, Max = 1} }
}

LightingModule.TrackedProperties = {
    Lighting = {"Ambient", "Brightness", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "OutdoorAmbient", "ShadowSoftness", "ClockTime", "GeographicLatitude", "ExposureCompensation"},
    Atmosphere = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
    Bloom = {"Enabled", "Intensity", "Size", "Threshold"},
    Blur = {"Enabled", "Size"},
    ColorCorrection = {"Enabled", "Brightness", "Contrast", "Saturation", "TintColor"},
    DepthOfField = {"Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity"},
    SunRays = {"Enabled", "Intensity", "Spread"}
}

LightingModule.SkyboxDatabase = {
    ["Default Sky"] = "", ["Sunset"] = "5186800496", ["Vaporwave"] = "5157589613", 
    ["Starry Night"] = "143962526", ["Anime Sky"] = "14753835117"
}
LightingModule.SkyAnimEnabled = false
LightingModule.SkyAnimSpeed = 10

function LightingModule.Init()
    local requiredEffects = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }

    for key, className in pairs(requiredEffects) do
        local effect = Lighting:FindFirstChildOfClass(className)
        if not effect then
            effect = Instance.new(className)
            effect.Name = PREFIX .. className
            if effect:IsA("PostEffect") then 
                effect.Enabled = false 
            end
            effect.Parent = Lighting
        end
        LightingModule.Objects[key] = effect
    end

    for category, properties in pairs(LightingModule.TrackedProperties) do
        LightingModule.Defaults[category] = {}
        LightingModule.TargetValues[category] = {}

        local obj = LightingModule.Objects[category]
        if obj then
            for _, propName in ipairs(properties) do
                LightingModule.Defaults[category][propName] = obj[propName]
                LightingModule.TargetValues[category][propName] = obj[propName]
            end
        end
    end

    local originalSky = Lighting:FindFirstChildOfClass("Sky")
    if originalSky then
        LightingModule.DefaultSkybox = {
            SkyboxBk = originalSky.SkyboxBk, SkyboxDn = originalSky.SkyboxDn, SkyboxFt = originalSky.SkyboxFt,
            SkyboxLf = originalSky.SkyboxLf, SkyboxRt = originalSky.SkyboxRt, SkyboxUp = originalSky.SkyboxUp,
            SunTextureId = originalSky.SunTextureId, MoonTextureId = originalSky.MoonTextureId, StarCount = originalSky.StarCount
        }
        LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
    end
end
LightingModule.Init()

function LightingModule.UpdateValue(category, property, value)
    if LightingModule.TargetValues[category] then
        LightingModule.TargetValues[category][property] = value
        
        if not LightingModule.IsSyncing and not LightingModule.LockEnabled then
            local obj = LightingModule.Objects[category]
            if obj then pcall(function() obj[property] = value end) end
        end
    end
end

function LightingModule.ToggleEffect(category, isEnabled)
    LightingModule.UpdateValue(category, "Enabled", isEnabled)
end

function LightingModule.LoadSkybox(id)
    id = tostring(id or ""):match("^%s*(%d+)%s*$") -- hanya angka; buang input aneh
    if not id then return end
    local success, result = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
    if success and result and result[1] then
        local asset = result[1]
        local skyObject = asset:IsA("Sky") and asset or asset:FindFirstChildOfClass("Sky")
        
        if skyObject then
            LightingModule.ActiveSkybox = {
                SkyboxBk = skyObject.SkyboxBk, SkyboxDn = skyObject.SkyboxDn, SkyboxFt = skyObject.SkyboxFt,
                SkyboxLf = skyObject.SkyboxLf, SkyboxRt = skyObject.SkyboxRt, SkyboxUp = skyObject.SkyboxUp,
                SunTextureId = skyObject.SunTextureId, MoonTextureId = skyObject.MoonTextureId, StarCount = skyObject.StarCount
            }
            
            local currentSky = Lighting:FindFirstChildOfClass("Sky")
            if not currentSky then
                currentSky = Instance.new("Sky")
                currentSky.Name = PREFIX .. "Sky"
                currentSky.Parent = Lighting
            end
            
            for k, v in pairs(LightingModule.ActiveSkybox) do
                pcall(function() currentSky[k] = v end)
            end
            
            pcall(function() asset:Destroy() end) 
        end
    end
end

function LightingModule.GetPresetsList()
    local list = {}
    table.insert(list, { Title = "Default", Desc = "Restore the map's original lighting.", Icon = "lucide:sun" })
    table.insert(list, { Type = "Divider" })
    for name, data in pairs(LightingModule.BuiltInPresets) do
        table.insert(list, { Title = name, Desc = data.Desc, Icon = "lucide:cloudy" })
    end
    if listfiles then
        local files = listfiles(ROOT .. "/Presets")
        if #files > 0 then
            table.insert(list, { Type = "Divider" })
            for _, file in pairs(files) do
                local name = file:match("([^/\\]+)%.json$")
                if name then table.insert(list, { Title = name, Desc = "Custom Preset (Saved)", Icon = "lucide:save" }) end
            end
        end
    end
    return list
end

-- Nama preset dipakai sebagai nama file. Buang karakter path ("../", "\", dll) supaya
-- user nggak bisa nulis/baca file di luar folder MugiwaraHub/Presets.
local function SanitizePresetName(name)
    name = tostring(name or ""):gsub("[^%w _%-%.]", ""):gsub("%.%.+", "."):match("^%s*(.-)%s*$")
    return string.sub(name, 1, 40)
end

function LightingModule.SavePreset(presetName)
    presetName = SanitizePresetName(presetName)
    if presetName == "" then return false, "Invalid preset name." end
    local path = ROOT .. "/Presets/" .. presetName .. ".json"
    local isOverwrite = (isfile and isfile(path))
    
    local dataToSave = {}
    for cat, props in pairs(LightingModule.TargetValues) do 
        dataToSave[cat] = {}
        for k, v in pairs(props) do
            if typeof(v) == "Color3" then
                dataToSave[cat][k] = { isColor3 = true, R = v.R, G = v.G, B = v.B }
            else
                dataToSave[cat][k] = v
            end
        end
    end
    
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        dataToSave.CustomSkybox = {
            SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt,
            SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp,
            SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount
        }
    end

    local data = HttpService:JSONEncode(dataToSave)
    if writefile then 
        writefile(path, data) 
        return true, isOverwrite and "Overwrite" or "New"
    end
    return false, "Your executor does not support writefile."
end

function LightingModule.LoadPreset(presetName)
    if presetName == "Default" then
        local currentSky = Lighting:FindFirstChildOfClass("Sky")
        if LightingModule.DefaultSkybox then
            LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
            if not currentSky then
                currentSky = Instance.new("Sky", Lighting)
                currentSky.Name = PREFIX .. "Sky"
            end
            for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
        else
            LightingModule.ActiveSkybox = nil
            if currentSky then currentSky:Destroy() end
        end

        for cat, props in pairs(LightingModule.Defaults) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do 
                    LightingModule.TargetValues[cat][k] = v 
                    if obj then pcall(function() obj[k] = v end) end 
                end
            end
        end
        if LightingModule.OnPresetLoaded then pcall(LightingModule.OnPresetLoaded) end
        return
    end

    if LightingModule.BuiltInPresets[presetName] then
        local presetData = LightingModule.BuiltInPresets[presetName]
        if presetData.Skybox and presetData.Skybox ~= "" then 
            LightingModule.LoadSkybox(presetData.Skybox) 
        else
            local currentSky = Lighting:FindFirstChildOfClass("Sky")
            if LightingModule.DefaultSkybox then
                LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
                if not currentSky then
                    currentSky = Instance.new("Sky", Lighting)
                    currentSky.Name = PREFIX .. "Sky"
                end
                for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
            else
                LightingModule.ActiveSkybox = nil
                if currentSky then currentSky:Destroy() end
            end
        end
        
        for cat, props in pairs(presetData.Values) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do 
                    LightingModule.TargetValues[cat][k] = v 
                    if obj then pcall(function() obj[k] = v end) end 
                end
            end
        end
        if LightingModule.OnPresetLoaded then pcall(LightingModule.OnPresetLoaded) end 
        return
    end

    presetName = SanitizePresetName(presetName)
    if presetName == "" then return end
    local path = ROOT .. "/Presets/" .. presetName .. ".json"
    if readfile and isfile and isfile(path) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success and decoded then
            
            if decoded.CustomSkybox then
                LightingModule.ActiveSkybox = decoded.CustomSkybox
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if not sky then
                    sky = Instance.new("Sky", Lighting)
                    sky.Name = PREFIX .. "Sky"
                end
                for key, value in pairs(decoded.CustomSkybox) do pcall(function() sky[key] = value end) end
                decoded.CustomSkybox = nil 
            else
                local currentSky = Lighting:FindFirstChildOfClass("Sky")
                if LightingModule.DefaultSkybox then
                    LightingModule.ActiveSkybox = LightingModule.DefaultSkybox
                    if not currentSky then
                        currentSky = Instance.new("Sky", Lighting)
                        currentSky.Name = PREFIX .. "Sky"
                    end
                    for k, v in pairs(LightingModule.DefaultSkybox) do pcall(function() currentSky[k] = v end) end
                else
                    LightingModule.ActiveSkybox = nil
                    if currentSky then currentSky:Destroy() end
                end
            end

            for cat, props in pairs(decoded) do
                if LightingModule.TargetValues[cat] then
                    local obj = LightingModule.Objects[cat]
                    for k, v in pairs(props) do 
                        local finalValue = v
                        if type(v) == "table" and v.isColor3 then
                            finalValue = Color3.new(v.R, v.G, v.B)
                        end
                        
                        LightingModule.TargetValues[cat][k] = finalValue 
                        if obj then pcall(function() obj[k] = finalValue end) end 
                    end
                end
            end
            if LightingModule.OnPresetLoaded then pcall(LightingModule.OnPresetLoaded) end
        end
    end
end

function LightingModule.CopySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return false, "This map has no built-in skybox!" end
    local skyData = { SkyboxBk = sky.SkyboxBk, SkyboxDn = sky.SkyboxDn, SkyboxFt = sky.SkyboxFt, SkyboxLf = sky.SkyboxLf, SkyboxRt = sky.SkyboxRt, SkyboxUp = sky.SkyboxUp, SunTextureId = sky.SunTextureId, MoonTextureId = sky.MoonTextureId, StarCount = sky.StarCount }
    if writefile then
        writefile(ROOT .. "/CopiedSky.json", HttpService:JSONEncode(skyData))
        return true, "Skybox copied!"
    end
    return false, "Your executor does not support writefile!"
end

function LightingModule.PasteSkybox()
    local path = ROOT .. "/CopiedSky.json"
    if not (readfile and isfile and isfile(path)) then return false, "No skybox has been copied yet!" end
    local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if success and decoded then
        LightingModule.ActiveSkybox = decoded
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky", Lighting)
            sky.Name = PREFIX .. "Sky"
        end
        for key, value in pairs(decoded) do pcall(function() sky[key] = value end) end
        return true, "Skybox pasted!"
    end
    return false, "The copied skybox data is corrupted!"
end

local renderConnection
renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    local counts = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        local cls = child.ClassName
        if cls == "Sky" or cls == "Atmosphere" or cls == "BloomEffect" or cls == "BlurEffect" or cls == "ColorCorrectionEffect" or cls == "DepthOfFieldEffect" or cls == "SunRaysEffect" then
            -- Hanya objek buatan hub (prefix Mugiwara_) yang boleh dihapus saat duplikat.
            -- Efek milik game dibiarkan; kalau ada dua, versi game yang dipakai.
            local isOurs = string.sub(child.Name, 1, #PREFIX) == PREFIX
            local current = counts[cls]
            if not current then
                counts[cls] = child
            elseif isOurs then
                child:Destroy()
            elseif string.sub(current.Name, 1, #PREFIX) == PREFIX then
                current:Destroy()
                counts[cls] = child
            end
        end
    end

    local trackedClasses = { Atmosphere = "Atmosphere", Bloom = "BloomEffect", Blur = "BlurEffect", ColorCorrection = "ColorCorrectionEffect", DepthOfField = "DepthOfFieldEffect", SunRays = "SunRaysEffect" }
    for cat, clsName in pairs(trackedClasses) do
        if counts[clsName] then
            LightingModule.Objects[cat] = counts[clsName]
        else
            if LightingModule.LockEnabled then
                local newObj = Instance.new(clsName)
                newObj.Name = PREFIX .. clsName
                newObj.Parent = Lighting
                if newObj:IsA("PostEffect") then newObj.Enabled = false end
                LightingModule.Objects[cat] = newObj
                counts[clsName] = newObj
            end
        end
    end

    local currentSky = counts["Sky"]

    if LightingModule.LockEnabled then
        for category, properties in pairs(LightingModule.TargetValues) do
            local obj = LightingModule.Objects[category]
            if obj then
                for propName, targetVal in pairs(properties) do
                    pcall(function() if obj[propName] ~= targetVal then obj[propName] = targetVal end end)
                end
            end
        end
        
        if currentSky and LightingModule.ActiveSkybox then
            for k, v in pairs(LightingModule.ActiveSkybox) do
                pcall(function() if currentSky[k] ~= v then currentSky[k] = v end end)
            end
        end
    else
        LightingModule.LastObserve = (LightingModule.LastObserve or 0) + deltaTime
        if LightingModule.LastObserve >= 0.5 then
            LightingModule.LastObserve = 0
            LightingModule.IsSyncing = true

            for category, properties in pairs(LightingModule.TargetValues) do
                local obj = LightingModule.Objects[category]
                if obj then
                    for propName, targetVal in pairs(properties) do
                        local success, realVal = pcall(function() return obj[propName] end)
                        if success and realVal ~= nil then
                            local isDifferent = false
                            
                            if type(realVal) == "number" and type(targetVal) == "number" then
                                if math.abs(realVal - targetVal) > 0.01 then isDifferent = true end
                            elseif typeof(realVal) == "Color3" and typeof(targetVal) == "Color3" then
                                if math.abs(realVal.R - targetVal.R) > 0.01 or math.abs(realVal.G - targetVal.G) > 0.01 or math.abs(realVal.B - targetVal.B) > 0.01 then isDifferent = true end
                            elseif realVal ~= targetVal then
                                isDifferent = true
                            end

                            if isDifferent then
                                LightingModule.TargetValues[category][propName] = realVal
                                if LightingModule.OnPropertyChanged then
                                    pcall(LightingModule.OnPropertyChanged, category, propName, realVal)
                                end
                            end
                        end
                    end
                end
            end
            LightingModule.IsSyncing = false
        end
    end

    if LightingModule.SkyAnimEnabled and currentSky then
        local currentRot = currentSky.SkyboxOrientation
        currentSky.SkyboxOrientation = currentRot + Vector3.new(0, LightingModule.SkyAnimSpeed * deltaTime, 0)
    end
end)

-- Full teardown on re-execute: stop the loop, then put the map's original lighting back.
-- Restoring matters because the next session snapshots the current lighting as its default.
getgenv().MugiwaraRegisterCleanup(function()
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    LightingModule.LockEnabled = false
    LightingModule.SkyAnimEnabled = false
    LightingModule.OnPresetLoaded = nil
    LightingModule.OnPropertyChanged = nil
    pcall(LightingModule.LoadPreset, "Default")

    -- Hapus objek yang dibuat hub sendiri (prefix Mugiwara_); milik game tidak disentuh.
    for _, child in ipairs(Lighting:GetChildren()) do
        if string.sub(child.Name, 1, #PREFIX) == PREFIX then child:Destroy() end
    end
end)

return LightingModule
