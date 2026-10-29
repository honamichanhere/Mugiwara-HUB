local VisualAccModule = getgenv().MugiwaraImport("Manager/VisualAccessories.lua")
local VisualAvatarUI = getgenv().MugiwaraImport("Tabs/VisualAvatarUI.lua")

-- Dipakai untuk game yang tidak punya modul sendiri (Main.lua memilih salah satu: modul game ATAU Universal,
-- tidak pernah dua-duanya). Accessory dan Korless di sini mengubah karakter bawaan Roblox (R6 / R15);
-- Evade memakai modul yang sama tapi dengan rig Workspace.Rigs (lihat Games/Evade/VisualAccessories.lua).
return function(Window, isPremiumUser, MugiwaraUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    TabMain:Paragraph({
        Title = "Universal Mode Active",
        Icon = "lucide:info",
        Desc = "This game is not explicitly supported. Loading universal character movements as fallback."
    })

    if VisualAvatarUI and VisualAccModule then
        local PremiumSection = TabMain:Section({
            Title = '<font color="#ffff82">Premium Features</font>',
            Icon = "rbxassetid://74594159374416",
            IconColor = Color3.fromRGB(255, 255, 130),
            Opened = false,
            Box = true
        })

        local AccessorySection = PremiumSection:Section({ Title = "Accessory", Icon = "lucide:shirt", Opened = false })
        VisualAvatarUI.BuildAccessory(AccessorySection, VisualAccModule, isPremiumUser, MugiwaraUI)

        local KorlessSection = PremiumSection:Section({ Title = "Korless", Icon = "lucide:skull", Opened = false })
        VisualAvatarUI.BuildKorless(KorlessSection, VisualAccModule, isPremiumUser, MugiwaraUI)
    end

    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then injectMovement(TabMain, isPremiumUser, MugiwaraUI) end

    pcall(function() Window:SelectTab(2) end)
end
