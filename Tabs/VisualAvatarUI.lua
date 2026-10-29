-- Antarmuka Accessory dan Korless (Headless + Korblox), dipakai bersama oleh Universal dan Evade.
-- Logikanya ada di Manager/VisualAccessories.lua; modul itu dikirim lewat parameter `VisualAcc` supaya
-- Evade memakai versi yang sudah dipasangi rig-nya sendiri.
--
-- Penjaga anti-dobel: tiap bagian hanya boleh dibuat SEKALI per sesi hub. Kalau ada jalur lain yang mencoba
-- membuatnya lagi (misalnya modul Universal ikut termuat di game yang sudah punya modul sendiri), yang kedua
-- dilewati. Penjaga dibersihkan saat hub di-unload atau di-execute ulang.
local UI = {}

local function Claim(name)
    local env = getgenv()
    if not env.MugiwaraVisualAvatarUI then
        env.MugiwaraVisualAvatarUI = {}
        env.MugiwaraRegisterCleanup(function() env.MugiwaraVisualAvatarUI = nil end)
    end
    if env.MugiwaraVisualAvatarUI[name] then
        warn("[Mugiwara HUB] " .. name .. " UI is already built, skipping the second copy.")
        return false
    end
    env.MugiwaraVisualAvatarUI[name] = true
    return true
end

function UI.BuildAccessory(Section, VisualAcc, isPremiumUser, MugiwaraUI)
    if not Claim("Accessory") then return end

    local templateNames = {}
    if VisualAcc and VisualAcc.Templates then
        for _, item in ipairs(VisualAcc.Templates) do
            table.insert(templateNames, item.Name)
        end
    end

    Section:Dropdown({
        Title = "Accessory Templates",
        Icon = "lucide:shirt",
        Desc = "Choose from popular pre-defined accessories.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = templateNames,
        Value = "",
        Callback = function(Option)
            if Option and Option ~= "" and VisualAcc then
                local selectedId = nil
                for _, item in ipairs(VisualAcc.Templates) do
                    if item.Name == Option then
                        selectedId = item.ID
                        break
                    end
                end
                if selectedId then
                    task.spawn(function()
                        VisualAcc.Apply(selectedId, MugiwaraUI)
                    end)
                end
            end
        end
    })

    local CustomAccInput
    CustomAccInput = Section:Input({
        Title = "Load Custom Asset ID",
        Icon = "lucide:hash",
        Desc = "Enter a valid Marketplace Accessory ID.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Placeholder = "e.g., 10159600649",
        Callback = function(Text)
            if not Text or Text == "" then return end
            local assetId = tonumber(Text)
            if assetId then
                task.spawn(function()
                    if VisualAcc then VisualAcc.Apply(assetId, MugiwaraUI) end
                end)
                pcall(function() CustomAccInput:Set("") end)
            else
                MugiwaraUI:Notify({ Title = "Invalid Input", Content = "Please enter a valid numeric ID.", Duration = 3 })
            end
        end
    })

    Section:Button({
        Title = "Clear All Custom Accessories",
        Icon = "lucide:trash-2",
        Desc = "Remove all spawned accessories from your character.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            if VisualAcc then VisualAcc.Clear(MugiwaraUI) end
        end
    })
end

function UI.BuildKorless(Section, VisualAcc, isPremiumUser, MugiwaraUI)
    if not Claim("Korless") then return end

    Section:Toggle({
        Title = "Headless Head",
        Icon = "lucide:skull",
        Desc = "Visually removes your character's head.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAcc then VisualAcc.ToggleHeadless(Value) end
            end)
        end
    })

    local function KorbloxToggle(side)
        local lower = string.lower(side)
        Section:Toggle({
            Title = "Korblox " .. side .. " Leg",
            Icon = "lucide:footprints",
            Desc = "Applies Korblox visual mesh to the " .. lower .. " leg.",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Value)
                task.spawn(function()
                    if not VisualAcc then return end
                    if Value and VisualAcc.IsKorbloxReady and not VisualAcc.IsKorbloxReady() then
                        MugiwaraUI:Notify({ Title = "Korblox", Content = "Preparing your avatar data. Korblox is applied in a few seconds.", Duration = 4 })
                    end
                    local ok = VisualAcc.ToggleKorblox(Value, side)
                    if Value and not ok then
                        MugiwaraUI:Notify({ Title = "Korblox", Content = "Could not apply the " .. lower .. " Korblox leg. Check the console for details.", Duration = 4 })
                    end
                end)
            end
        })
    end

    KorbloxToggle("Left")
    KorbloxToggle("Right")
end

return UI
