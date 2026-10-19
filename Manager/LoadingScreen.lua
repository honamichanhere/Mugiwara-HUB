--[[
    ███ Mugiwara Hub - Loading Screen ███
    Owner   : Honami

    -- Loader ini gak bakal selesai sampe lu manggil:
    --   Loader:Finish()               (cara paling gampang)
    --   Loader.FinishEvent:Fire()     (kalo mau lewat event)
    -- Contoh cara pakai lengkap ada di paling bawah file.
]]

-- ================= SERVICES =================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ================= CONFIG (ubah di sini aja) =================
local CONFIG = {
    Title = "Mugiwara Hub",
    Owner = "Honami",
    Version = "v" .. tostring((getgenv and getgenv().MugiwaraVersion) or "1.0.0"),

    -- Palet diambil dari tema "Luffy" milik hub (Main.lua): oranye #ff9132, krem #ffdcc8,
    -- #ffbe6e (tag versi), dan cokelat gelap #1F1108 (background dialog).
    Accent = Color3.fromRGB(255, 145, 50),     -- oranye outline tema Luffy
    Secondary = Color3.fromRGB(255, 220, 200), -- krem (judul topbar tema Luffy)
    Warning = Color3.fromRGB(255, 190, 110),   -- kuning-oranye buat log info/warn
    Error = Color3.fromRGB(255, 95, 86),       -- merah buat log error
    Background = Color3.fromRGB(31, 17, 8),    -- warna card
    Terminal = Color3.fromRGB(17, 9, 4),       -- warna kotak terminal
    TextMain = Color3.fromRGB(255, 240, 230),
    TextDim = Color3.fromRGB(176, 138, 112),

    DesignSize = Vector2.new(460, 312), -- ukuran dasar card (nanti di-scale otomatis)
    MinScale = 0.55,                    -- batas paling kecil (HP kecil)
    MaxScale = 1.3,                     -- batas paling gede (monitor gede)
    MaxLogLines = 6,                    -- jumlah baris log yg keliatan
}

-- Teks log palsu yg muter terus selama loading
local FAKE_LOGS = {
    "Establishing secure connection",
    "Verifying key session",
    "Fetching UI library",
    "Decrypting payload",
    "Scanning game environment",
    "Resolving game modules",
    "Mounting global tabs",
    "Syncing configuration",
    "Allocating memory blocks",
    "Compiling feature modules",
    "Checking for updates",
    "Optimizing render pipeline",
}

-- ================= HELPER =================
-- bikin instance + set property + masukin children sekaligus
local function create(className, props, children)
    local inst = Instance.new(className)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then
            inst[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

-- shortcut buat tween
local function tween(inst, time, props, style, direction)
    local t = TweenService:Create(
        inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

-- ubah Color3 jadi "#RRGGBB" buat RichText
local function hex(color)
    return "#" .. color:ToHex()
end

local HEX_CHARS = "0123456789ABCDEF"
local function randomHex(length)
    local out = table.create(length)
    for i = 1, length do
        local r = math.random(1, #HEX_CHARS)
        out[i] = HEX_CHARS:sub(r, r)
    end
    return table.concat(out)
end

-- cari tempat naro GUI: gethui (executor) -> CoreGui -> PlayerGui
local function getGuiParent()
    local okHui, hui = pcall(function()
        return gethui()
    end)
    if okHui and typeof(hui) == "Instance" then
        return hui
    end

    local okCore, core = pcall(function()
        local coreGui = game:GetService("CoreGui")
        local probe = Instance.new("Folder")
        probe.Parent = coreGui -- tes izin akses CoreGui
        probe:Destroy()
        return coreGui
    end)
    if okCore and core then
        return core
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ================= STATE =================
local state = {
    finishing = false,
    finished = false,
    titleBusy = false,
    status = "Initializing",
    startTime = os.clock(),
    lastHex = 0,

    -- Progress: kalau skrip pemanggil memakai Loader:SetProgress(target, cap), persen mengikuti
    -- tahap asli (naik cepat ke `target`, lalu merayap pelan ke `cap` selama tahap berjalan).
    -- Kalau SetProgress tidak pernah dipanggil, dipakai kurva waktu seperti semula.
    manualProgress = false,
    target = 0,
    cap = 0,
}
local connections = {}
local logOrder = 0

-- ================= BUILD UI =================
local guiParent = getGuiParent()

-- hapus loader lama kalo ada (biar gak dobel)
local oldGui = guiParent:FindFirstChild("MugiwaraLoader")
if oldGui then
    oldGui:Destroy()
end

local ScreenGui = create("ScreenGui", {
    Name = "MugiwaraLoader",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Parent = guiParent,
})

-- backdrop transparan seperti desain awal (0.35). Window hub di belakangnya (yang dibangun tab demi tab) terlihat samar di balik backdrop ini.
-- INSTANT_COVER: dipasang Main.lua kalau loading screen dibuat belakangan (perangkat baru, setelah
-- key valid), jadi layar langsung tertutup tanpa fade.
local COVER_TRANSPARENCY = 0.35
local INSTANT_COVER = (getgenv and getgenv().MugiwaraLoaderInstantCover) == true

-- background gelap full layar
local Backdrop = create("Frame", {
    Name = "Backdrop",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(10, 5, 2),
    BackgroundTransparency = INSTANT_COVER and COVER_TRANSPARENCY or 1,
    BorderSizePixel = 0,
    Parent = ScreenGui,
})

-- card utama di tengah
local Card = create("Frame", {
    Name = "Card",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(CONFIG.DesignSize.X, CONFIG.DesignSize.Y),
    BackgroundColor3 = CONFIG.Background,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = ScreenGui,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 14) }),
})

local CardScale = create("UIScale", { Scale = 1, Parent = Card })

-- border card yg warnanya muter (merah <-> hijau)
local CardStroke = create("UIStroke", {
    Thickness = 1.6,
    Color = Color3.new(1, 1, 1),
    Transparency = 1,
    Parent = Card,
})
local StrokeGradient = create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, CONFIG.Accent),
        ColorSequenceKeypoint.new(0.5, CONFIG.Secondary),
        ColorSequenceKeypoint.new(1, CONFIG.Accent),
    }),
    Parent = CardStroke,
})

-- isi card dibagi jadi beberapa blok (CanvasGroup) supaya masuk/keluarnya bisa berentetan
-- (stagger) per blok, bukan semuanya sekaligus. Posisi anak-anak tetap dalam koordinat card.
local Content = create("Frame", {
    Name = "Content",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Parent = Card,
})

local function createBlock(name)
    return create("CanvasGroup", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Position = UDim2.fromOffset(0, 14),
        Parent = Content,
    })
end

-- urutan = urutan masuk (dibalik saat keluar)
local HeaderBlock = createBlock("HeaderBlock")
local DividerBlock = createBlock("DividerBlock")
local TerminalBlock = createBlock("TerminalBlock")
local ProgressBlock = createBlock("ProgressBlock")
local FooterBlock = createBlock("FooterBlock")
local Blocks = { HeaderBlock, DividerBlock, TerminalBlock, ProgressBlock, FooterBlock }

-- ---------- Header ----------
local Title = create("TextLabel", {
    Name = "Title",
    Position = UDim2.fromOffset(20, 16),
    Size = UDim2.new(1, -60, 0, 32),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    Text = "",
    TextSize = 26,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = HeaderBlock,
}, {
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CONFIG.TextMain),
            ColorSequenceKeypoint.new(0.55, CONFIG.TextMain),
            ColorSequenceKeypoint.new(1, CONFIG.Accent),
        }),
    }),
})

-- titik status di pojok kanan atas (kedip-kedip)
local PulseDot = create("Frame", {
    Name = "PulseDot",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -22, 0, 32),
    Size = UDim2.fromOffset(9, 9),
    BackgroundColor3 = CONFIG.Secondary,
    BorderSizePixel = 0,
    Parent = HeaderBlock,
}, {
    create("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

create("TextLabel", {
    Name = "Subtitle",
    Position = UDim2.fromOffset(20, 50),
    Size = UDim2.new(1, -40, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    RichText = true,
    TextSize = 13,
    TextColor3 = CONFIG.TextDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = string.format(
        'Owner: <font color="%s">%s</font>   |   Version: <font color="%s">%s</font>',
        hex(CONFIG.Accent), CONFIG.Owner,
        hex(CONFIG.Secondary), CONFIG.Version
    ),
    Parent = HeaderBlock,
})

-- garis pemisah
local DIVIDER_SIZE = UDim2.new(1, -40, 0, 1)
local DividerLine = create("Frame", {
    Name = "Divider",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 76),
    Size = UDim2.new(0, 0, 0, 1), -- tumbuh dari tengah saat blok masuk
    BackgroundColor3 = CONFIG.TextDim,
    BorderSizePixel = 0,
    Parent = DividerBlock,
}, {
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }),
})

-- ---------- Terminal ----------
local TerminalBox = create("Frame", {
    Name = "Terminal",
    Position = UDim2.fromOffset(20, 86),
    Size = UDim2.new(1, -40, 0, 150),
    BackgroundColor3 = CONFIG.Terminal,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = TerminalBlock,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 8) }),
    create("UIStroke", { Color = CONFIG.TextDim, Transparency = 0.8, Thickness = 1 }),
})

-- 3 titik ala window terminal
local dotColors = { CONFIG.Error, CONFIG.Warning, CONFIG.Secondary }
for i, color in ipairs(dotColors) do
    create("Frame", {
        Position = UDim2.fromOffset(10 + (i - 1) * 14, 7),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = TerminalBox,
    }, {
        create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
end

create("TextLabel", {
    Name = "TerminalTitle",
    Position = UDim2.fromOffset(56, 3),
    Size = UDim2.new(1, -66, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 12,
    TextColor3 = CONFIG.TextDim,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "root@mugiwara: ~/loader",
    Parent = TerminalBox,
})

create("Frame", {
    Position = UDim2.fromOffset(0, 22),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = CONFIG.TextDim,
    BackgroundTransparency = 0.85,
    BorderSizePixel = 0,
    Parent = TerminalBox,
})

-- tempat baris-baris log
local LogFrame = create("Frame", {
    Name = "Logs",
    Position = UDim2.fromOffset(10, 28),
    Size = UDim2.new(1, -20, 1, -50),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = TerminalBox,
}, {
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 2),
    }),
})

-- baris prompt + cursor kedip
local PROMPT_TEXT = string.format(
    '<font color="%s">root@mugiwara</font><font color="%s">:~$</font> ',
    hex(CONFIG.Secondary), hex(CONFIG.TextDim)
)
local PromptLabel = create("TextLabel", {
    Name = "Prompt",
    Position = UDim2.new(0, 10, 1, -20),
    Size = UDim2.new(1, -20, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    RichText = true,
    TextSize = 12,
    TextColor3 = CONFIG.TextMain,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = PROMPT_TEXT,
    Parent = TerminalBox,
})

-- garis scanline yg turun terus (efek monitor jadul)
local Scanline = create("Frame", {
    Name = "Scanline",
    Position = UDim2.fromScale(0, -0.05),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = CONFIG.Secondary,
    BackgroundTransparency = 0.85,
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = TerminalBox,
})
TweenService:Create(
    Scanline,
    TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
    { Position = UDim2.fromScale(0, 1.05) }
):Play()

-- ---------- Status + Progress ----------
local StatusLabel = create("TextLabel", {
    Name = "Status",
    Position = UDim2.fromOffset(20, 246),
    Size = UDim2.new(1, -100, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 13,
    TextColor3 = CONFIG.TextMain,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "",
    Parent = ProgressBlock,
})

local PercentLabel = create("TextLabel", {
    Name = "Percent",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -20, 0, 246),
    Size = UDim2.fromOffset(70, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = CONFIG.Secondary,
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "0%",
    Parent = ProgressBlock,
})

local BAR_SIZE = UDim2.new(1, -40, 0, 6)
local BarTrack = create("Frame", {
    Name = "BarTrack",
    Position = UDim2.fromOffset(20, 268),
    Size = UDim2.new(0, 0, 0, 6), -- tumbuh dari kiri saat blok masuk
    BackgroundColor3 = Color3.fromRGB(52, 32, 18),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = ProgressBlock,
}, {
    create("UICorner", { CornerRadius = UDim.new(1, 0) }),
})

local Fill = create("Frame", {
    Name = "Fill",
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = BarTrack,
}, {
    create("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
local FillGradient = create("UIGradient", {
    Color = ColorSequence.new(CONFIG.Accent, CONFIG.Secondary),
    Parent = Fill,
})

-- kilatan putih yg lewat terus di progress bar
local Shimmer = create("Frame", {
    Name = "Shimmer",
    Position = UDim2.fromScale(-0.3, 0),
    Size = UDim2.fromScale(0.3, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = BarTrack,
}, {
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }),
})
TweenService:Create(
    Shimmer,
    TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
    { Position = UDim2.fromScale(1, 0) }
):Play()

-- teks hex random di bawah (dekorasi hacker)
local HexFooter = create("TextLabel", {
    Name = "HexFooter",
    Position = UDim2.fromOffset(20, 284),
    Size = UDim2.new(1, -40, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextColor3 = CONFIG.TextDim,
    TextTransparency = 0.45,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "",
    Parent = FooterBlock,
})

-- ================= ANIMASI TEKS =================
local SCRAMBLE_CHARS = "!@#$%&*<>?/\\|01ABCDEFXZ"

-- efek judul "acak" terus kebuka satu-satu huruf
local function scrambleText(label, finalText, duration)
    state.titleBusy = true
    local length = #finalText
    local stepTime = duration / math.max(length, 1)

    for revealed = 0, length do
        if not label.Parent then
            break
        end
        local out = finalText:sub(1, revealed)
        for j = revealed + 1, length do
            if finalText:sub(j, j) == " " then
                out ..= " "
            else
                local r = math.random(1, #SCRAMBLE_CHARS)
                out ..= SCRAMBLE_CHARS:sub(r, r)
            end
        end
        label.Text = out
        task.wait(stepTime)
    end

    label.Text = finalText
    state.titleBusy = false
end

-- nambah 1 baris log dengan efek ngetik
local LOG_TYPES = {
    info = { tag = "*", color = CONFIG.Warning },
    ok = { tag = "+", color = CONFIG.Secondary },
    warn = { tag = "!", color = CONFIG.Warning },
    error = { tag = "x", color = CONFIG.Error },
}

local function addLog(message, kind)
    if not LogFrame.Parent then
        return nil
    end

    local logType = LOG_TYPES[kind] or LOG_TYPES.info
    local timeStr = os.date("%H:%M:%S")
    logOrder += 1

    local richText = string.format(
        '<font color="%s">[%s]</font> <font color="%s">[%s]</font> %s',
        hex(CONFIG.TextDim), timeStr, hex(logType.color), logType.tag, message
    )
    -- panjang teks tanpa tag RichText (buat efek ngetik)
    local plainLength = #string.format("[%s] [%s] %s", timeStr, logType.tag, message)

    local line = create("TextLabel", {
        Name = "Log",
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        RichText = true,
        TextSize = 12,
        TextColor3 = CONFIG.TextMain,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = logOrder,
        MaxVisibleGraphemes = 0,
        Text = richText,
        Parent = LogFrame,
    })

    -- hapus log paling lama kalo kebanyakan
    local lines = {}
    for _, child in ipairs(LogFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            table.insert(lines, child)
        end
    end
    table.sort(lines, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    while #lines > CONFIG.MaxLogLines do
        table.remove(lines, 1):Destroy()
    end

    -- efek ngetik
    task.spawn(function()
        for i = 1, plainLength do
            if not line.Parent then
                return
            end
            line.MaxVisibleGraphemes = i
            task.wait(0.012)
        end
        if line.Parent then
            line.MaxVisibleGraphemes = -1
        end
    end)

    return { Label = line, Base = richText }
end

-- nambahin " OK" / " DONE" di ujung baris log
local function completeLog(entry, word, color)
    if not entry or not entry.Label.Parent then
        return
    end
    entry.Label.MaxVisibleGraphemes = -1
    entry.Label.Text = string.format('%s <font color="%s">%s</font>', entry.Base, hex(color), word)
end

-- ================= LOOP ANIMASI (tiap frame) =================
local animScale = Instance.new("NumberValue")
animScale.Value = 0.85
local percentValue = Instance.new("NumberValue")
percentValue.Value = 0

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    local now = os.clock()

    -- responsive: scale card sesuai ukuran layar (PC / HP)
    local camera = Workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        local scaleX = (viewport.X - 32) / CONFIG.DesignSize.X
        local scaleY = (viewport.Y - 32) / CONFIG.DesignSize.Y
        local baseScale = math.clamp(math.min(scaleX, scaleY), CONFIG.MinScale, CONFIG.MaxScale)
        CardScale.Scale = baseScale * animScale.Value
    end

    -- border muter
    StrokeGradient.Rotation = (now * 70) % 360

    -- titik status kedip
    PulseDot.BackgroundTransparency = 0.35 + 0.35 * math.sin(now * 5)

    -- cursor terminal kedip
    PromptLabel.Text = PROMPT_TEXT .. ((math.floor(now * 2.5) % 2 == 0) and "_" or "")

    -- persen: ikut tahap asli kalau ada SetProgress, kalau tidak pakai kurva waktu.
    -- Tidak pernah turun dan mentok di 99% sampe Finish dipanggil.
    if not state.finishing then
        local current = percentValue.Value
        if state.manualProgress then
            if current < state.target then
                current = current + (state.target - current) * (1 - math.exp(-dt * 7))
            elseif current < state.cap then
                current = current + (state.cap - current) * (1 - math.exp(-dt / 5))
            end
        else
            current = math.max(current, 99 * (1 - math.exp(-(now - state.startTime) / 12)))
        end
        percentValue.Value = math.min(current, 99)
    end
    local percent = percentValue.Value
    PercentLabel.Text = string.format("%d%%", math.floor(percent))
    Fill.Size = UDim2.fromScale(percent / 100, 1)

    -- status + titik-titik animasi
    if not state.finished then
        local dots = string.rep(".", math.floor(now * 3) % 4)
        StatusLabel.Text = state.status .. dots
    end

    -- hex random (dibatesin biar gak terlalu cepet)
    if now - state.lastHex > 0.07 then
        state.lastHex = now
        HexFooter.Text = string.format(
            "0x%s  %s %s  %s  MEM:0x%s",
            randomHex(8), randomHex(4), randomHex(4), randomHex(6), randomHex(4)
        )
    end
end))

-- ================= API =================
local Loader = {}
Loader.Gui = ScreenGui

-- Fire event ini buat nyelesain loading: Loader.FinishEvent:Fire()
Loader.FinishEvent = Instance.new("BindableEvent")

-- Event ini ke-fire pas UI loading udah bener-bener ilang
local closedEvent = Instance.new("BindableEvent")
Loader.Finished = closedEvent.Event

-- ganti teks status di atas progress bar
function Loader:SetStatus(text)
    if state.finishing then
        return
    end
    state.status = tostring(text)
end

-- persen mengikuti tahap asli: `target` = persen minimum sekarang (dikejar cepat),
-- `cap` = batas rayapan pelan selama tahap itu masih berjalan (tidak pernah turun).
function Loader:SetProgress(target, cap)
    if state.finishing then
        return
    end
    state.manualProgress = true
    state.target = math.max(state.target, tonumber(target) or 0)
    state.cap = math.max(state.target, tonumber(cap) or state.target)
end

-- nambah log manual. kind: "info" | "ok" | "warn" | "error"
function Loader:Log(text, kind)
    return addLog(tostring(text), kind)
end

-- hapus UI langsung tanpa animasi
function Loader:Destroy()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
    if ScreenGui then
        ScreenGui:Destroy()
    end
end

-- selesaiin loading + animasi keluar
function Loader:Finish(message)
    if state.finishing then
        return
    end
    state.finishing = true

    task.spawn(function()
        state.status = "Finalizing"
        addLog("All modules loaded successfully", "ok")

        -- progress full + warna hijau
        tween(percentValue, 0.6, { Value = 100 })
        task.wait(0.35)
        FillGradient.Color = ColorSequence.new(CONFIG.Secondary)
        addLog(message or ("Access granted. Welcome, " .. LocalPlayer.DisplayName), "ok")
        task.wait(0.35)

        state.finished = true
        StatusLabel.Text = "Ready"
        StatusLabel.TextColor3 = CONFIG.Secondary
        PulseDot.BackgroundColor3 = CONFIG.Secondary
        scrambleText(Title, CONFIG.Title, 0.35)
        task.wait(0.6)

        -- animasi keluar: kebalikan masuk. Blok paling bawah keluar duluan, berentetan ke atas,
        -- baru card dan backdrop menyusul.
        local EXIT_STAGGER = 0.06
        for index = #Blocks, 1, -1 do
            local block = Blocks[index]
            task.delay((#Blocks - index) * EXIT_STAGGER, function()
                tween(block, 0.28, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 12) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                if block == DividerBlock then
                    tween(DividerLine, 0.28, { Size = UDim2.new(0, 0, 0, 1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                elseif block == ProgressBlock then
                    tween(BarTrack, 0.28, { Size = UDim2.new(0, 0, 0, 6) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                end
            end)
        end
        task.wait(#Blocks * EXIT_STAGGER + 0.05)

        tween(animScale, 0.35, { Value = 0.85 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        tween(Card, 0.35, { BackgroundTransparency = 1 })
        tween(CardStroke, 0.35, { Transparency = 1 })
        tween(Backdrop, 0.4, { BackgroundTransparency = 1 })
        task.wait(0.45)

        Loader:Destroy()
        print("[Mugiwara Hub] Loading complete.")
        closedEvent:Fire()
    end)
end

-- kalo FinishEvent di-fire, otomatis Finish
Loader.FinishEvent.Event:Connect(function(message)
    Loader:Finish(message)
end)

-- biar bisa diakses dari script lain (executor)
pcall(function()
    getgenv().MugiwaraLoader = Loader
end)

-- ================= ANIMASI MASUK =================
tween(Backdrop, 0.5, { BackgroundTransparency = COVER_TRANSPARENCY })
tween(Card, 0.5, { BackgroundTransparency = 0.05 })
tween(CardStroke, 0.5, { Transparency = 0 })
tween(animScale, 0.7, { Value = 1 }, Enum.EasingStyle.Back)

-- blok isi masuk berentetan (slide naik + fade), tiap blok menyusul 0.1 detik setelah sebelumnya;
-- garis pemisah dan bar progress ikut "tumbuh" saat bloknya muncul.
local ENTER_STAGGER = 0.1
for index, block in ipairs(Blocks) do
    task.delay(0.2 + (index - 1) * ENTER_STAGGER, function()
        if not block.Parent then
            return
        end
        tween(block, 0.5, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
        if block == DividerBlock then
            tween(DividerLine, 0.6, { Size = DIVIDER_SIZE })
        elseif block == ProgressBlock then
            tween(BarTrack, 0.6, { Size = BAR_SIZE })
        end
    end)
end
task.delay(0.25, scrambleText, Title, CONFIG.Title, 0.9)

-- log awal
task.delay(0.3, function()
    addLog("Booting " .. CONFIG.Title .. " " .. CONFIG.Version, "ok")
end)

-- loop log palsu, jalan terus sampe Finish
task.spawn(function()
    task.wait(0.9)
    local index = 0
    while not state.finishing and ScreenGui.Parent do
        index = index % #FAKE_LOGS + 1
        local entry = addLog(FAKE_LOGS[index] .. "...", "info")
        task.wait(math.random(40, 95) / 100)
        if state.finishing then
            break
        end

        -- sesekali ada "warning" biar keliatan real
        if math.random() < 0.12 then
            completeLog(entry, "RETRY", CONFIG.Warning)
            task.wait(0.3)
            addLog("Packet timeout, retrying connection", "warn")
        else
            completeLog(entry, "OK", CONFIG.Secondary)
        end
        task.wait(math.random(15, 40) / 100)
    end
end)

-- efek glitch kecil di judul tiap beberapa detik
task.spawn(function()
    while ScreenGui.Parent and not state.finishing do
        task.wait(math.random(35, 65) / 10)
        if state.finishing or state.titleBusy or not Title.Parent then
            continue
        end
        local original = CONFIG.Title
        local pos = math.random(1, #original)
        local r = math.random(1, #SCRAMBLE_CHARS)
        Title.Text = original:sub(1, pos - 1) .. SCRAMBLE_CHARS:sub(r, r) .. original:sub(pos + 1)
        Title.Position = UDim2.fromOffset(22, 16)
        task.wait(0.06)
        Title.Position = UDim2.fromOffset(19, 16)
        task.wait(0.05)
        Title.Position = UDim2.fromOffset(20, 16)
        Title.Text = original
    end
end)

print("[Mugiwara Hub] Loader initialized.")

return Loader

--[[
    ================= CARA PAKAI =================

    -- 1) Panggil loader-nya (dari loadstring / require)
    local Loader = loadstring(game:HttpGet("LINK_RAW_LOADER_LU"))()

    -- 2) (opsional) ganti status / tambah log sesuai proses asli
    Loader:SetStatus("Loading WindUI")
    Loader:Log("Fetching WindUI library", "info")

    -- ... di sini proses load hub lu (WindUI, key system, modules, dll) ...

    -- 3) Kalo udah beres, selesain loading (pilih salah satu)
    Loader:Finish()
    -- atau: Loader.FinishEvent:Fire()
    -- atau dari script lain: getgenv().MugiwaraLoader:Finish()

    -- 4) (opsional) tunggu sampe UI loading bener-bener ilang
    Loader.Finished:Wait()

    -- Buat ngetes doang: otomatis selesai setelah 8 detik
    -- task.delay(8, function() Loader:Finish() end)
]]