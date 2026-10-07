local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

return function(Window, isPremiumUser, WindUI)
    local TabHome = Window:Tab({ Title = "Home", Icon = "lucide:house" })
    
    local success, gameInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
    local gameName = (success and gameInfo and gameInfo.Name) or "Unknown Game"

    local clientLocation = "Fetching data..."
    task.spawn(function()
        pcall(function()
            local response = game:HttpGet("http://ip-api.com/json/")
            local data = HttpService:JSONDecode(response)
            if data and data.country and data.city then
                clientLocation = data.city .. ", " .. data.country
            else
                clientLocation = "Undisclosed Region"
            end
        end)
    end)

    local premiumStatus = (LocalPlayer.MembershipType == Enum.MembershipType.Premium) and "Premium" or "Free"
    
    local UserInfo = TabHome:Paragraph({
        Title = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
        Desc = "Loading real-time data...",
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
        ImageSize = 100,
    })

    task.spawn(function()
        while task.wait(1) do
            local realPing = 0
            pcall(function() realPing = math.round(LocalPlayer:GetNetworkPing() * 1000) end)
            
            local fps = 0
            pcall(function() fps = math.round(1 / RunService.RenderStepped:Wait()) end)

            local newDesc = string.format("User ID: %d\nAccount Age: %d Days\nRoblox Premium: %s\nKey Status: %s\nLocation: %s\nPing: %s ms | FPS: %s",
                LocalPlayer.UserId, LocalPlayer.AccountAge, premiumStatus, (isPremiumUser and "Premium Access" or "Free Access"), clientLocation, tostring(realPing), tostring(fps))
            
            pcall(function() UserInfo:SetDesc(newDesc) end)
        end
    end)

    TabHome:Divider({ Title = "System Information" })
    
    TabHome:Paragraph({ 
        Title = gameName, 
        Desc = string.format("Place ID: %d\nJob ID: %s\nActive Players: %d / %d\nExecution Mode: Client-Side\nClient Region: %s", game.PlaceId, game.JobId, #Players:GetPlayers(), Players.MaxPlayers, clientLocation) 
    })

    TabHome:Divider({ Title = "Developer & Administration" })
    
    TabHome:Paragraph({ 
        Title = "Script Founder: Honami", 
        Desc = "Honami (@honamichandesu) is the sole creator and lead developer of Mugiwara HUB, dedicated to delivering a seamless, high-performance scripting experience." 
    })

    TabHome:Button({ 
        Title = "Official TikTok", 
        Desc = "Follow @honamichanhere for the latest updates and showcases.",
        Icon = "lucide:external-link", 
        Callback = function() 
            if setclipboard then setclipboard("https://tiktok.com/@honamichanhere") end
            WindUI:Notify({ Title = "Action Successful", Content = "The official TikTok profile link has been copied to your clipboard.", Duration = 3 }) 
        end 
    })

    TabHome:Button({ 
        Title = "Official Discord Community", 
        Desc = "Join our community server for technical support and premium access.",
        Icon = "lucide:message-square", 
        Callback = function() 
            if setclipboard then setclipboard("https://discord.gg/djmrevtSV7") end
            WindUI:Notify({ Title = "Action Successful", Content = "The Discord community invite link has been copied to your clipboard.", Duration = 3 }) 
        end 
    })

    TabHome:Divider({ Title = "Acknowledgments & Credits" })
    
    TabHome:Button({ 
        Title = "UI Framework: WindUI", 
        Desc = "Open-source interface library utilized for Mugiwara HUB.",
        Icon = "lucide:code", 
        Callback = function() 
            if setclipboard then setclipboard("https://github.com/Footagesus/WindUI") end
            WindUI:Notify({ Title = "Action Successful", Content = "The repository link for WindUI has been copied to your clipboard.", Duration = 3 }) 
        end 
    })

    TabHome:Button({ 
        Title = "Authentication: Panda Auth", 
        Desc = "Powered by PUSL-v4 architecture for secure key validation.",
        Icon = "lucide:shield-check", 
        Callback = function() 
            if setclipboard then setclipboard("https://discord.gg/panda-auth") end
            WindUI:Notify({ Title = "Action Successful", Content = "The Panda Auth reference link has been copied to your clipboard.", Duration = 3 }) 
        end 
    })
end
