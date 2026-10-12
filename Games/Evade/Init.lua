-- ==========================================
-- EVADE LOADER (GAMES/EVADE/INIT.LUA)
-- ==========================================
local VisualAccModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Games/Evade/VisualAccessories.lua"))()

return function(Window, isPremiumUser, WindUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    TabMain:Paragraph({
        Title = "Evade Mode Active",
        Desc = "Exclusive features for Evade loaded successfully."
    })

    -- ==========================================
    -- UI: PREMIUM ACCESSORIES SECTION
    -- ==========================================
    TabMain:Divider({ Title = "Evade Premium Features" })
    
    local AccSection = TabMain:Section({ Title = "Visual Accessories", Icon = "lucide:gem", Opened = true, Box = true })

    local templateNames = {}
    if VisualAccModule and VisualAccModule.Templates then
        for name, _ in pairs(VisualAccModule.Templates) do 
            table.insert(templateNames, name) 
        end
    end

    AccSection:Dropdown({
        Title = "Accessory Templates",
        Desc = "Choose from popular pre-defined accessories.",
        Locked = not isPremiumUser,
        Values = templateNames,
        Value = "",
        Callback = function(Option)
            if Option and VisualAccModule and VisualAccModule.Templates[Option] then
                task.spawn(function()
                    -- Panggil logic dari module, dan lempar WindUI biar bisa notif
                    VisualAccModule.Apply(VisualAccModule.Templates[Option], WindUI)
                end)
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

    -- ==========================================
    -- UI: UNIVERSAL MOVEMENT SECTION (BOTTOM)
    -- ==========================================
    TabMain:Divider({ Title = "Universal Modules" })
    
    local injectMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/Movement.lua"))
    if injectMovement then 
        injectMovement()(TabMain, isPremiumUser, WindUI) 
    end

    pcall(function() Window:SelectTab(2) end)
end
