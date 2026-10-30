local VisualAccModule = getgenv().MugiwaraImport("Games/Evade/VisualAccessories.lua")
local VisualAvatarUI = getgenv().MugiwaraImport("Tabs/VisualAvatarUI.lua")
local AvatarChangerModule = getgenv().MugiwaraImport("Games/Evade/AvatarChanger.lua")
local TicketFarmModule = getgenv().MugiwaraImport("Games/Evade/TicketFarm.lua")
local AfkFarmUI = getgenv().MugiwaraImport("Games/Evade/AfkFarmUI.lua")
local VisualEmotesUI = getgenv().MugiwaraImport("Games/Evade/VisualEmotesUI.lua")
local VisualCarryUI = getgenv().MugiwaraImport("Games/Evade/VisualCarryUI.lua")
local VisualUnusualUI = getgenv().MugiwaraImport("Games/Evade/VisualUnusualUI.lua")
local Risk = getgenv().MugiwaraImport("Manager/Risk.lua") or { Desc = function(_, text) return text end, Warn = function() end }

return function(Window, isPremiumUser, MugiwaraUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    local gameIcon = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=150&h=150"
    
    TabMain:Paragraph({
        Title = "Evade Mode Active",
        Desc = "Exclusive features for Evade loaded successfully.",
        Image = gameIcon,
        ImageSize = 75
    })

    local PremiumSection = TabMain:Section({ 
        Title = '<font color="#ffff82">Premium Features</font>', 
        Icon = "rbxassetid://74594159374416", 
        IconColor = Color3.fromRGB(255, 255, 130), 
        Opened = false, 
        Box = true 
    })

    -- Premium Features dibagi per kategori (section di dalam section): Auto Farm, Accessory, Korless,
    -- Avatar Changer, Visual Emotes, dan Visual Unusual.
    if AfkFarmUI then
        local AfkSection = PremiumSection:Section({ Title = "Auto Farm", Icon = "lucide:moon", Opened = false })
        local ok, err = pcall(AfkFarmUI.BuildFarm, AfkSection, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] AFK Farm UI error: " .. tostring(err)) end
    end

    -- Accessory dan Korless dibangun oleh Tabs/VisualAvatarUI.lua (dipakai juga oleh Universal).
    local AccessorySection = PremiumSection:Section({ Title = "Accessory", Icon = "lucide:shirt", Opened = false })
    if VisualAvatarUI then VisualAvatarUI.BuildAccessory(AccessorySection, VisualAccModule, isPremiumUser, MugiwaraUI) end

    local KorlessSection = PremiumSection:Section({ Title = "Korless", Icon = "lucide:skull", Opened = false })
    if VisualAvatarUI then VisualAvatarUI.BuildKorless(KorlessSection, VisualAccModule, isPremiumUser, MugiwaraUI) end

    local AvatarSection = PremiumSection:Section({ Title = "Avatar Changer", Icon = "lucide:user-round", Opened = false })

    local AvatarInput
    AvatarInput = AvatarSection:Input({
        Title = "Morph By Username",
        Icon = "lucide:user-round",
        Desc = "Copy any player's avatar exactly 1:1.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Placeholder = "Username...",
        Callback = function(Text)
            if not Text or Text == "" then return end 
            
            task.spawn(function()
                if AvatarChangerModule then AvatarChangerModule.Apply(Text, MugiwaraUI) end
            end)
            pcall(function() AvatarInput:Set("") end)
        end
    })

    AvatarSection:Button({
        Title = "Revert to Original",
        Icon = "lucide:undo-2",
        Desc = "Back to original avatar.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            if AvatarChangerModule then AvatarChangerModule.Clear(true, MugiwaraUI) end
        end
    })

    -- Visual Emotes (premium): tukar tampilan dua emote.
    if VisualEmotesUI then
        local EmotesSection = PremiumSection:Section({ Title = "Visual Emotes", Icon = "lucide:drama", Opened = false })
        -- Di thread sendiri: memuat daftar emote (Registry game) bisa lama, dan sisa tab Main tidak boleh menunggu.
        task.spawn(function()
            local ok, err = pcall(VisualEmotesUI.Build, EmotesSection, isPremiumUser, MugiwaraUI)
            if not ok then warn("[Mugiwara HUB] Visual Emotes UI error: " .. tostring(err)) end
        end)
    end

    -- Visual Unusual (premium): pasang efek Unusual milik game ke karakter, bisa ditumpuk.
    if VisualUnusualUI then
        local UnusualSection = PremiumSection:Section({ Title = "Visual Unusual", Icon = "lucide:sparkles", Opened = false })
        task.spawn(function()
            local ok, err = pcall(VisualUnusualUI.Build, UnusualSection, isPremiumUser, MugiwaraUI)
            if not ok then warn("[Mugiwara HUB] Visual Unusual UI error: " .. tostring(err)) end
        end)
    end

    -- ==========================================
    -- HALLOWEEN TICKET FARM (free)
    -- ==========================================
    if TicketFarmModule then
        local FarmSection = TabMain:Section({
            Title = "Halloween Ticket Farm",
            Icon = "lucide:ghost",
            Opened = false,
            Box = true
        })

        FarmSection:Toggle({
            Title = "Auto Farm Tickets",
            Icon = "lucide:ticket",
            Desc = Risk.Desc("TicketFarm", "Teleports to each Halloween ticket and waits until it is collected. When no tickets are left you stay put and can move freely."),
            Callback = function(Value)
                Risk.Warn(MugiwaraUI, "TicketFarm", Value)
                TicketFarmModule.SetFarm(Value)
            end
        })

        FarmSection:Toggle({
            Title = "Avoid NextBots",
            Icon = "lucide:shield-alert",
            Desc = Risk.Desc("AvoidNextBots", "Teleports you to a safe item spawn whenever a NextBot gets too close. Also skips tickets that are next to a NextBot."),
            Callback = function(Value)
                Risk.Warn(MugiwaraUI, "AvoidNextBots", Value)
                TicketFarmModule.SetAvoid(Value)
            end
        })

        FarmSection:Slider({
            Title = "NextBot Safe Distance",
            Icon = "lucide:ruler",
            Desc = "How close a NextBot can get before you are teleported away.",
            Step = 1,
            Value = { Min = 10, Max = 100, Default = TicketFarmModule.SafeDistance },
            Callback = function(Value)
                TicketFarmModule.SetSafeDistance(Value)
            end
        })

        FarmSection:Slider({
            Title = "Teleport Delay",
            Icon = "lucide:timer",
            Desc = "Wait this many seconds between teleports to tickets. 0 teleports right away. Escaping a NextBot is never delayed.",
            Step = 0.5,
            Suffix = " s",
            Value = { Min = 0, Max = 20, Default = TicketFarmModule.TeleportDelay or 0 },
            Callback = function(Value)
                TicketFarmModule.SetTeleportDelay(Value)
            end
        })
    end

    -- ==========================================
    -- AUTO COMMANDS (free)
    -- ==========================================
    if AfkFarmUI then
        local ok, err = pcall(AfkFarmUI.BuildCommands, TabMain, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] Auto Commands UI error: " .. tostring(err)) end
    end
    -- ==========================================
    -- VISUAL CARRY (free)
    -- ==========================================
    if VisualCarryUI then
        local CarrySection = TabMain:Section({ Title = "Visual Carry", Icon = "lucide:hand-helping", Opened = false, Box = true })
        -- Di thread sendiri: memuat daftar carry (Registry game) bisa lama, dan sisa tab Main tidak boleh menunggu.
        task.spawn(function()
            local ok, err = pcall(VisualCarryUI.Build, CarrySection, MugiwaraUI)
            if not ok then warn("[Mugiwara HUB] Visual Carry UI error: " .. tostring(err)) end
        end)
    end

    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then
        injectMovement(TabMain, isPremiumUser, MugiwaraUI)
    end

    pcall(function() Window:SelectTab(2) end)
end
