-- Chat bersama semua pengguna hub (elemen Chat milik Mugiwara UI). Server chat-nya Cloudflare Worker;
-- alamatnya (ChatUrl) diisi di Main.lua. Tanpa alamat, tab menampilkan penjelasan saja.
return function(Window, isPremiumUser, MugiwaraUI, ChatUrl)
    local TabChat = Window:Tab({ Title = "Chat", Icon = "lucide:message-circle" })

    if type(ChatUrl) ~= "string" or ChatUrl == "" then
        TabChat:Paragraph({
            Title = "Chat Is Not Set Up Yet",
            Desc = "The chat server address has not been added to the hub yet. Check back after the next update.",
            Icon = "lucide:plug-zap"
        })
        return
    end

    local ok, err = pcall(function()
        local transport = MugiwaraUI.ChatTransports.Http({
            Url = ChatUrl,
            Channel = "global",
            Folder = getgenv().MugiwaraFolder or "MugiwaraHub",
        })

        TabChat:Chat({
            Title = "Mugiwara Chat",
            Transport = transport,
            Height = 300,
        })
    end)

    if not ok then
        warn("[Mugiwara HUB] Chat error: " .. tostring(err))
        TabChat:Paragraph({
            Title = "Chat Unavailable",
            Desc = "The chat could not start. Re-execute the hub to try again.",
            Icon = "lucide:circle-alert"
        })
    end
end
