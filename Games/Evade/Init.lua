local VisualAccModule = getgenv().MugiwaraImport("Games/Evade/VisualAccessories.lua")
local AvatarChangerModule = getgenv().MugiwaraImport("Games/Evade/AvatarChanger.lua")
local TicketFarmModule = getgenv().MugiwaraImport("Games/Evade/TicketFarm.lua")
local VIPCommandsModule = getgenv().MugiwaraImport("Games/Evade/VIPCommands.lua")

return function(Window, isPremiumUser, WindUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    local gameIcon = "rbxthumb://type=Asset&id=" .. game.PlaceId .. "&w=150&h=150"
    
    TabMain:Paragraph({
        Title = "Evade Mode Active",
        Desc = "Exclusive features for Evade loaded successfully.",
        Image = gameIcon,
        ImageSize = 75
    })

    TabMain:Divider({ Title = "Evade Premium Features" })
    
    local AccSection = TabMain:Section({ 
        Title = '<font color="#ffff82">Premium Features</font>', 
        Icon = "rbxassetid://74594159374416", 
        Opened = false, 
        Box = true 
    })

    local templateNames = {}
    if VisualAccModule and VisualAccModule.Templates then
        for i, item in ipairs(VisualAccModule.Templates) do 
            table.insert(templateNames, item.Name) 
        end
    end

    AccSection:Dropdown({
        Title = "Accessory Templates",
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
                        VisualAccModule.Apply(selectedId, WindUI)
                    end)
                end
            end
        end
    })

    local CustomAccInput
    CustomAccInput = AccSection:Input({
        Title = "Load Custom Asset ID",
        Desc = "Enter a valid Marketplace Accessory ID.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Placeholder = "e.g., 10159600649",
        Callback = function(Text)
            if not Text or Text == "" then return end 
            local assetId = tonumber(Text)
            if assetId then
                task.spawn(function()
                    if VisualAccModule then VisualAccModule.Apply(assetId, WindUI) end
                end)
                pcall(function() CustomAccInput:Set("") end)
            else
                WindUI:Notify({ Title = "Invalid Input", Content = "Please enter a valid numeric ID.", Duration = 3 })
            end
        end
    })

    AccSection:Button({
        Title = "Clear All Custom Accessories",
        Desc = "Remove all spawned accessories from your character.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            if VisualAccModule then VisualAccModule.Clear(WindUI) end
        end
    })

    AccSection:Toggle({
        Title = "Headless Head",
        Desc = "Visually removes your character's head.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleHeadless(Value) end
            end)
        end
    })

    AccSection:Toggle({
        Title = "Korblox Left Leg",
        Desc = "Applies Korblox visual mesh to the left leg.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleKorblox(Value, "Left") end
            end)
        end
    })

    AccSection:Toggle({
        Title = "Korblox Right Leg",
        Desc = "Applies Korblox visual mesh to the right leg.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function(Value)
            task.spawn(function()
                if VisualAccModule then VisualAccModule.ToggleKorblox(Value, "Right") end
            end)
        end
    })

    local AvatarInput
    AvatarInput = AccSection:Input({
        Title = "Morph By Username",
        Desc = "Copy any player's avatar exactly 1:1.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Placeholder = "Username...",
        Callback = function(Text)
            if not Text or Text == "" then return end 
            
            task.spawn(function()
                if AvatarChangerModule then AvatarChangerModule.Apply(Text, WindUI) end
            end)
            pcall(function() AvatarInput:Set("") end)
        end
    })

    AccSection:Button({
        Title = "Revert to Original",
        Desc = "Back to original avatar.",
        Locked = not isPremiumUser,
        LockedTitle = "Premium Only",
        Callback = function()
            if AvatarChangerModule then AvatarChangerModule.Clear(true, WindUI) end
        end
    })

    -- ==========================================
    -- HALLOWEEN TICKET FARM (free)
    -- ==========================================
    TabMain:Divider({ Title = "Halloween Event" })

    if TicketFarmModule then
        local FarmSection = TabMain:Section({
            Title = "Halloween Ticket Farm",
            Icon = "lucide:ticket",
            Opened = true,
            Box = true
        })

        FarmSection:Toggle({
            Title = "Auto Farm Tickets",
            Desc = "Teleports to each Halloween ticket and waits until it is collected. When no tickets are left you stay put and can move freely.",
            Callback = function(Value)
                TicketFarmModule.SetFarm(Value)
            end
        })

        FarmSection:Toggle({
            Title = "Avoid NextBots",
            Desc = "Teleports you to a safe item spawn whenever a NextBot gets too close. Also skips tickets that are next to a NextBot.",
            Callback = function(Value)
                TicketFarmModule.SetAvoid(Value)
            end
        })

        FarmSection:Slider({
            Title = "NextBot Safe Distance",
            Desc = "How close a NextBot can get before you are teleported away.",
            Step = 1,
            Value = { Min = 10, Max = 100, Default = TicketFarmModule.SafeDistance },
            Callback = function(Value)
                TicketFarmModule.SetSafeDistance(Value)
            end
        })
    end

    -- ==========================================
    -- AFK FARM (premium) - work in progress
    -- ==========================================
    TabMain:Divider({ Title = "AFK Farm" })

    if VIPCommandsModule then
        local AfkSection = TabMain:Section({
            Title = '<font color="#ffff82">AFK Farm</font>',
            Icon = "rbxassetid://74594159374416",
            Opened = false,
            Box = true
        })

        AfkSection:Paragraph({
            Title = "AFK Farm",
            Desc = "Farms tokens, points and XP while you are away by cycling rounds quickly with VIP commands (for example Timer to skip the intermission). Needs VIP command access, so it only works in a server you own (Community or Private). Commands that disable rewards are blocked automatically. Full automation is still in development; use the console below to test commands."
        })

        local commandText = ""

        AfkSection:Toggle({
            Title = "Allow Reward-Disabling Commands",
            Desc = "Off by default. Commands marked as disabling rewards (God, Speed, Tool, and others) drop this server's reward multiplier to 0.",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Value = false,
            Callback = function(Value)
                VIPCommandsModule.AllowRewardDisabling = Value
            end
        })

        AfkSection:Input({
            Title = "VIP Command Console",
            Desc = "Type a command the way you would in chat, for example !timer 1. Then press Send Command.",
            Placeholder = "!timer 1",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function(Text)
                commandText = tostring(Text or "")
            end
        })

        AfkSection:Button({
            Title = "Send Command",
            Desc = "Sends the command above to the server through the VIP menu channel.",
            Icon = "lucide:send",
            Locked = not isPremiumUser,
            LockedTitle = "Premium Only",
            Callback = function()
                local ok, result = VIPCommandsModule.RunText(commandText)
                WindUI:Notify({
                    Title = ok and "Command Sent" or "Command Not Sent",
                    Content = tostring(result),
                    Duration = ok and 2 or 4
                })
            end
        })
    end

    TabMain:Divider({ Title = "Universal Modules" })
    
    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then
        injectMovement(TabMain, isPremiumUser, WindUI)
    end

    pcall(function() Window:SelectTab(2) end)
end
