local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

return function(Window, isPremiumUser, WindUI)
    local TabHome = Window:Tab({ Title = "Home", Icon = "lucide:house" })
    
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
            local realPing, realFPS = 0, 0
            pcall(function() realPing = math.round(LocalPlayer:GetNetworkPing() * 1000) end)
            pcall(function() realFPS = math.round(1 / RunService.RenderStepped:Wait()) end)

            local newDesc = string.format("User ID: %d\nAccount Age: %d Days\nRoblox Premium: %s\nKey Status: %s\nLocation: %s\nPing: %s ms | FPS: %s",
                LocalPlayer.UserId, LocalPlayer.AccountAge, premiumStatus, (isPremiumUser and "Premium Key" or "Free Key"), clientLocation, tostring(realPing), tostring(realFPS))
            
            pcall(function() UserInfo:SetDesc(newDesc) end)
        end
    end)

    TabHome:Divider({ Title = "System Information" })
    TabHome:Paragraph({ 
        Title = "Game Data", 
        Desc = string.format("Place ID: %d\nJob ID: %s\nActive Players: %d / %d", game.PlaceId, game.JobId, #Players:GetPlayers(), Players.MaxPlayers) 
    })

    TabHome:Divider({ Title = "Developer & Administration" })
    TabHome:Paragraph({ Title = "Script Founder: Honami", Desc = "Honami (@honamichandesu) is the sole creator and lead developer of Mugiwara HUB." })
end
