local LightingModule = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local HttpService = game:GetService("HttpService")

-- ==========================================
-- MESIN PEMBUAT FOLDER (EXECUTOR ONLY)
-- ==========================================
if makefolder and isfolder then
    if not isfolder("HonamiHub") then makefolder("HonamiHub") end
    if not isfolder("HonamiHub/Presets") then makefolder("HonamiHub/Presets") end
end

-- ==========================================
-- DATABASE PRESET BAWAAN (DEFAULT PRESETS)
-- ==========================================
LightingModule.BuiltInPresets = {
    ["Horor Vibe"] = {
        Desc = "Tema gelap, berkabut merah, dan mencekam.",
        Skybox = "5157589613",
        Values = {
            Lighting = { Brightness = 0.2, ClockTime = 0, Ambient = Color3.fromRGB(10, 0, 0) },
            Atmosphere = { Density = 0.8, Color = Color3.fromRGB(20, 5, 5), Haze = 5 },
            ColorCorrection = { Brightness = -0.1, Contrast = 0.5, Saturation = -0.5 }
        }
    },
    ["Cozy Sunset"] = {
        Desc = "Hangat, estetik, cocok buat hangout sore.",
        Skybox = "5186800496",
        Values = {
            Lighting = { Brightness = 2.5, ClockTime = 17.5, ExposureCompensation = 0.2 },
            SunRays = { Intensity = 0.2, Spread = 0.8 },
            Bloom = { Intensity = 0.5, Size = 20 }
        }
    }
}

-- ==========================================
-- MESIN PRESET (SAVE, LOAD, LIST)
-- ==========================================
function LightingModule.GetPresetsList()
    local list = {}

    table.insert(list, { Title = "Default", Desc = "Kembali ke cuaca map asli", Icon = "lucide:sun" })
    table.insert(list, { Type = "Divider" })

    for name, data in pairs(LightingModule.BuiltInPresets) do
        table.insert(list, { Title = name, Desc = data.Desc, Icon = "lucide:cloudy" })
    end

    if listfiles then
        local files = listfiles("HonamiHub/Presets")
        if #files > 0 then
            table.insert(list, { Type = "Divider" })
            for _, file in pairs(files) do
                local name = file:match("([^/\\]+)%.json$")
                if name then 
                    table.insert(list, { Title = name, Desc = "Custom Preset (Saved)", Icon = "lucide:save" }) 
                end
            end
        end
    end

    return list
end

function LightingModule.SavePreset(presetName)
    if presetName == "" then return end
    local data = HttpService:JSONEncode(LightingModule.TargetValues)
    if writefile then writefile("HonamiHub/Presets/" .. presetName .. ".json", data) end
end

function LightingModule.LoadPreset(presetName)
    if presetName == "Default" then
        LightingModule.LoadSkybox("Default")
        for cat, props in pairs(LightingModule.Defaults) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do
                    LightingModule.TargetValues[cat][k] = v
                    if obj then obj[k] = v end
                end
            end
        end
        return
    end

    if LightingModule.BuiltInPresets[presetName] then
        local presetData = LightingModule.BuiltInPresets[presetName]
        
        if presetData.Skybox and presetData.Skybox ~= "" then
            LightingModule.LoadSkybox(presetData.Skybox)
        end

        for cat, props in pairs(presetData.Values) do
            if LightingModule.TargetValues[cat] then
                local obj = LightingModule.Objects[cat]
                for k, v in pairs(props) do
                    LightingModule.TargetValues[cat][k] = v
                    if obj then obj[k] = v end
                end
            end
        end
        return
    end

    local path = "HonamiHub/Presets/" .. presetName .. ".json"
    if readfile and isfile and isfile(path) then
        local data = readfile(path)
        local success, decoded = pcall(function() return HttpService:JSONDecode(data) end)

        if success and decoded then
            for cat, props in pairs(decoded) do
                if LightingModule.TargetValues[cat] then
                    local obj = LightingModule.Objects[cat]
                    for k, v in pairs(props) do
                        LightingModule.TargetValues[cat][k] = v
                        if obj then obj[k] = v end
                    end
                end
            end
        end
    end
end

-- ==========================================
-- DATABASE SKYBOX (Pakai Asset ID Package/Model)
-- ==========================================
LightingModule.SkyboxDatabase = {
    ["Default Sky"] = "",
    ["Sunset"] = "5186800496",
    ["Vaporwave"] = "5157589613", 
    ["Starry Night"] = "143962526",
    ["Anime Sky"] = "14753835117"
}

LightingModule.SkyAnimEnabled = false
LightingModule.SkyAnimSpeed = 10
LightingModule.CopiedSky = nil

-- ==========================================
-- 1. DATABASE SYSTEM (Limit, Target, Default, & Object Cache)
-- ==========================================
LightingModule.LockEnabled = false

LightingModule.Objects = { Lighting = Lighting }
LightingModule.Defaults = {}
LightingModule.TargetValues = {}

LightingModule.Limits = {
    Lighting = {
        Brightness = {Min = 0, Max = 10},
        EnvironmentDiffuseScale = {Min = 0, Max = 1},
        EnvironmentSpecularScale = {Min = 0, Max = 1},
        ShadowSoftness = {Min = 0, Max = 1},
        ClockTime = {Min = 0, Max = 24},
        GeographicLatitude = {Min = -90, Max = 90},
        ExposureCompensation = {Min = -3, Max = 3}
    },
    Atmosphere = {
        Density = {Min = 0, Max = 1},
        Offset = {Min = 0, Max = 1},
        Glare = {Min = 0, Max = 10},
        Haze = {Min = 0, Max = 10}
    },
    Bloom = {
        Intensity = {Min = 0, Max = 10},
        Size = {Min = 0, Max = 56},
        Threshold = {Min = 0, Max = 10}
    },
    Blur = {
        Size = {Min = 0, Max = 56}
    },
    ColorCorrection = {
        Brightness = {Min = -1, Max = 1},
        Contrast = {Min = -1, Max = 1},
        Saturation = {Min = -1, Max = 1}
    },
    DepthOfField = {
        FarIntensity = {Min = 0, Max = 1},
        FocusDistance = {Min = 0, Max = 500},
        InFocusRadius = {Min = 0, Max = 50},
        NearIntensity = {Min = 0, Max = 1}
    },
    SunRays = {
        Intensity = {Min = 0, Max = 1},
        Spread = {Min = 0, Max = 1}
    }
}

-- ==========================================
-- 2. INIT: VALIDASI OBJECT & MIRRORING VALUE
-- ==========================================
function LightingModule.Init()
    local requiredEffects = {
        Atmosphere = "Atmosphere", 
        Bloom = "BloomEffect", 
        Blur = "BlurEffect",
        ColorCorrection = "ColorCorrectionEffect", 
        DepthOfField = "DepthOfFieldEffect", 
        SunRays = "SunRaysEffect"
    }

    for key, className in pairs(requiredEffects) do
        local effect = Lighting:FindFirstChildOfClass(className)
        if not effect then
            effect = Instance.new(className)
            effect.Name = "Honami_" .. className
            effect.Parent = Lighting
        end
        LightingModule.Objects[key] = effect
    end

    for category, properties in pairs(LightingModule.Limits) do
        LightingModule.Defaults[category] = {}
        LightingModule.TargetValues[category] = {}

        local obj = LightingModule.Objects[category]
        if obj then
            for propName, _ in pairs(properties) do
                local realValue = obj[propName]
                LightingModule.Defaults[category][propName] = realValue
                LightingModule.TargetValues[category][propName] = realValue
            end
        end
    end
end

LightingModule.Init()

-- ==========================================
-- 3. FUNGSI UPDATE DARI UI
-- ==========================================
function LightingModule.UpdateValue(category, property, value)
    if LightingModule.TargetValues[category] then
        LightingModule.TargetValues[category][property] = value

        if not LightingModule.LockEnabled then
            local obj = LightingModule.Objects[category]
            if obj then
                obj[property] = value
            end
        end
    end
end

-- ==========================================
-- MESIN LOAD SKYBOX (Dari ID Package/Model)
-- ==========================================
function LightingModule.LoadSkybox(id)
    if id == "" or id == "Default" then return end

    local success, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)

    if success and result and result[1] then
        local asset = result[1]
        local skyObject = asset:IsA("Sky") and asset or asset:FindFirstChildOfClass("Sky")

        if skyObject then
            local oldSky = Lighting:FindFirstChildOfClass("Sky")
            if oldSky then oldSky:Destroy() end

            skyObject.Parent = Lighting
            skyObject.Name = "Honami_Sky"
            print("Skybox berhasil dipasang!")
        else
            warn("Tidak ada objek Sky di dalam Asset ID tersebut!")
        end
    else
        warn("Gagal mendownload Asset ID (Mungkin ID salah atau di-private)")
    end
end

function LightingModule.ToggleEffect(category, isEnabled)
    local obj = LightingModule.Objects[category]
    if obj and obj:IsA("PostEffect") then
        obj.Enabled = isEnabled
    end
end

-- ==========================================
-- MESIN COPY-PASTE SKYBOX (LINTAS GAME TUNGGAL)
-- ==========================================
function LightingModule.CopySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then return false, "Tidak ada Skybox bawaan di map ini!" end
    
    local skyData = {
        SkyboxBk = sky.SkyboxBk,
        SkyboxDn = sky.SkyboxDn,
        SkyboxFt = sky.SkyboxFt,
        SkyboxLf = sky.SkyboxLf,
        SkyboxRt = sky.SkyboxRt,
        SkyboxUp = sky.SkyboxUp,
        SunTextureId = sky.SunTextureId,
        MoonTextureId = sky.MoonTextureId,
        StarCount = sky.StarCount
    }
    
    local json = HttpService:JSONEncode(skyData)
    if writefile then
        writefile("HonamiHub/CopiedSky.json", json)
        return true, "Skybox berhasil dicopy & tersimpan!"
    end
    return false, "Executor tidak support writefile!"
end

function LightingModule.PasteSkybox()
    local path = "HonamiHub/CopiedSky.json"
    if not (readfile and isfile and isfile(path)) then
        return false, "Belum ada Skybox yang pernah lu copy!"
    end
    
    local data = readfile(path)
    local success, decoded = pcall(function() return HttpService:JSONDecode(data) end)
    
    if success and decoded then
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "Honami_Sky"
            sky.Parent = Lighting
        end
        
        for key, value in pairs(decoded) do
            pcall(function() sky[key] = value end) 
        end
        
        return true, "Skybox berhasil dipaste!"
    end
    return false, "Data CopiedSky rusak/error!"
end

-- ==========================================
-- 4. KASTA TERTINGGI: MESIN FORCE LOCK & ANIMASI
-- ==========================================
RunService.RenderStepped:Connect(function(deltaTime)
    if LightingModule.LockEnabled then
        for category, properties in pairs(LightingModule.TargetValues) do
            local obj = LightingModule.Objects[category]
            if obj then
                for propName, targetVal in pairs(properties) do
                    if obj[propName] ~= targetVal then
                        obj[propName] = targetVal
                    end
                end
            end
        end
    end

    if LightingModule.SkyAnimEnabled then
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            local currentRot = sky.SkyboxOrientation
            local rotationStep = (LightingModule.SkyAnimSpeed * deltaTime)
            sky.SkyboxOrientation = currentRot + Vector3.new(0, rotationStep, 0)
        end
    end
end)

return LightingModule
