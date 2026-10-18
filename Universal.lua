return function(Window, isPremiumUser, WindUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    TabMain:Paragraph({
        Title = "Universal Mode Active",
        Desc = "This game is not explicitly supported. Loading universal character movements as fallback."
    })

    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then injectMovement(TabMain, isPremiumUser, WindUI) end

    pcall(function() Window:SelectTab(2) end)
end
