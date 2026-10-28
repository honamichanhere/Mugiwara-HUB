return function(Window, isPremiumUser, MugiwaraUI)
    
    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    TabMain:Paragraph({
        Title = "Universal Mode Active",
        Icon = "lucide:info",
        Desc = "This game is not explicitly supported. Loading universal character movements as fallback."
    })

    local injectMovement = getgenv().MugiwaraImport("Tabs/MovementInjector.lua")
    if injectMovement then injectMovement(TabMain, isPremiumUser, MugiwaraUI) end

    pcall(function() Window:SelectTab(2) end)
end
