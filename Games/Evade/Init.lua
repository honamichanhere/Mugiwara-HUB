local VisualAccModule = getgenv().MugiwaraImport("Games/Evade/VisualAccessories.lua")
local AvatarChangerModule = getgenv().MugiwaraImport("Games/Evade/AvatarChanger.lua")

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
        Callback = function()
            if VisualAccModule then VisualAccModule.Clear(WindUI) end
        end
    })

    AccSection:Toggle({
        Title = "Headless Head",
        Desc = "Visually removes your character's head.",
        Locked = not isPremiumUser,
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
        Locked = false,
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
        Locked = false,
        Callback = function()
            if AvatarChangerModule then AvatarChangerModule.Clear(true, WindUI) end
        end
    })

    TabMain:Divider({ Title = "Universal Modules" })
    
    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then
        injectMovement(TabMain, isPremiumUser, WindUI)
    end

    pcall(function() Window:SelectTab(2) end)
end
