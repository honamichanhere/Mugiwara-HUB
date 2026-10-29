local VisualAccModule = getgenv().MugiwaraImport("Games/Evade/VisualAccessories.lua")
local AvatarChangerModule = getgenv().MugiwaraImport("Games/Evade/AvatarChanger.lua")
local TicketFarmModule = getgenv().MugiwaraImport("Games/Evade/TicketFarm.lua")
local AfkFarmUI = getgenv().MugiwaraImport("Games/Evade/AfkFarmUI.lua")
local VisualEmotesUI = getgenv().MugiwaraImport("Games/Evade/VisualEmotesUI.lua")
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
    -- Avatar Changer, dan Visual Emotes.
    if AfkFarmUI then
        local AfkSection = PremiumSection:Section({ Title = "Auto Farm", Icon = "lucide:moon", Opened = false })
        local ok, err = pcall(AfkFarmUI.BuildFarm, AfkSection, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] AFK Farm UI error: " .. tostring(err)) end
    end

    local AccessorySection = PremiumSection:Section({ Title = "Accessory", Icon = "lucide:shirt", Opened = false })

    local templateNames = {}
    if VisualAccModule and VisualAccModule.Templates then
        for i, item in ipairs(VisualAccModule.Templates) do 
            table.insert(templateNames, item.Name) 
        end
    end

    AccessorySection:Dropdown({
        Title = "Accessory Templates",
        Icon = "lucide:shirt",
        Desc = "Choose from popular pre-defined accessories.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Values = templateNames,
        Value = "",
        Callback = function(Option)
            if Option and Option ~= "" and VisualAccModule then
                local selectedId = nil
                for i, item in ipairs(VisualAccModule.Templates) do
                    if item.Name == Option then
                        selectedId = item.ID
                        break
                    end
                end
                if selectedId then
                    task.spawn(function()
                        VisualAccModule.Apply(selectedId, MugiwaraUI)
                    end)
                end
            end
        end
    })

    local CustomAccInput
    CustomAccInput = AccessorySection:Input({
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
                    if VisualAccModule then VisualAccModule.Apply(assetId, MugiwaraUI) end
                end)
                pcall(function() CustomAccInput:Set("") end)
            else
                MugiwaraUI:Notify({ Title = "Invalid Input", Content = "Please enter a valid numeric ID.", Duration = 3 })
            end
        end
    })

    AccessorySection:Button({
        Title = "Clear All Custom Accessories",
        Icon = "lucide:trash-2",
        Desc = "Remove all spawned accessories from your character.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            if VisualAccModule then VisualAccModule.Clear(MugiwaraUI) end
        end
    })

    local KorlessSection = PremiumSection:Section({ Title = "Korless", Icon = "lucide:skull", Opened = false })

    KorlessSection:Toggle({
        Title = "Headless Head",
        Icon = "lucide:skull",
        Desc = "Visually removes your character's head.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleHeadless(Value) end
            end)
        end
    })

    KorlessSection:Toggle({
        Title = "Korblox Left Leg",
        Icon = "lucide:footprints",
        Desc = "Applies Korblox visual mesh to the left leg.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleKorblox(Value, "Left") end
            end)
        end
    })

    KorlessSection:Toggle({
        Title = "Korblox Right Leg",
        Icon = "lucide:footprints",
        Desc = "Applies Korblox visual mesh to the right leg.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleKorblox(Value, "Right") end
            end)
        end
    })

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
        local ok, err = pcall(VisualEmotesUI.Build, EmotesSection, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] Visual Emotes UI error: " .. tostring(err)) end
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
    end

    -- ==========================================
    -- AUTO COMMANDS (free)
    -- ==========================================
    if AfkFarmUI then
        local ok, err = pcall(AfkFarmUI.BuildCommands, TabMain, isPremiumUser, MugiwaraUI)
        if not ok then warn("[Mugiwara HUB] Auto Commands UI error: " .. tostring(err)) end
    end
    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then
        injectMovement(TabMain, isPremiumUser, MugiwaraUI)
    end

    pcall(function() Window:SelectTab(2) end)
end
