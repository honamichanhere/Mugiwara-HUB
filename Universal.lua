return function(Window, isPremiumUser, WindUI)
    
    local loadHome = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/HomeTab.lua"))
    if loadHome then loadHome()(Window, isPremiumUser, WindUI) end

    local TabMain = Window:Tab({ Title = "Main", Icon = "lucide:ship" })
    
    TabMain:Paragraph({
        Title = "Universal Mode Active",
        Desc = "This game is not explicitly supported. Loading universal character movements as fallback."
    })

    local injectMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/refs/heads/main/Tabs/MovementInjector.lua"))
    if injectMovement then injectMovement()(TabMain, isPremiumUser, WindUI) end

    -- 4. PANGGIL TAB LIGHTING & CAMERA (Nanti kita bikin file-nya)
    -- local loadLighting = loadstring(game:HttpGet("URL_GITHUBLU_TABS_LIGHTINGTAB.LUA"))
    -- if loadLighting then loadLighting()(Window, isPremiumUser, WindUI) end

    -- local loadCamera = loadstring(game:HttpGet("URL_GITHUBLU_TABS_CAMERATAB.LUA"))
    -- if loadCamera then loadCamera()(Window, isPremiumUser, WindUI) end
    
    -- Aktifkan Tab Home saat pertama kali dieksekusi
    -- (WindUI biasanya otomatis select tab pertama, tapi buat jaga-jaga)
end
