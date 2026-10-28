local UIExtras = {}

-- Mugiwara UI tidak punya beberapa hal yang dipakai hub sejak masih WindUI: teks "Premium Only" di
-- elemen terkunci (LockedTitle), gambar kecil di samping Paragraph (Image + ImageSize), judul Tab dan
-- Section berwarna (rich text), ikon di header Section, SetValue/SetColor, dan event buka/tutup window. Library tidak
-- diubah; semuanya ditambahkan dari sisi hub lewat modul ini.
--
-- Install(Window) dipanggil SEKALI tepat setelah window dibuat, sebelum elemen apa pun dibuat.

local GOLD = Color3.fromRGB(255, 220, 130)

local function HasMarkup(text)
    return type(text) == "string" and string.find(text, "<", 1, true) ~= nil
end

local function CopyOptions(opts)
    local copy = {}
    for key, value in pairs(opts) do copy[key] = value end
    return copy
end

-- Gambar kecil di sisi kiri kartu Paragraph. `image` boleh "rbxassetid://", "rbxthumb://", angka
-- (asset id), atau URL http(s) (dibutuhkan helper gambar milik library).
local function AttachThumbnail(UI, element, image, size)
    local top = element.Top
    local info = top and top:FindFirstChild("Info")
    if not info then return end

    size = tonumber(size) or 64

    local thumb = Instance.new("ImageLabel")
    thumb.Name = "Thumbnail"
    thumb.BackgroundTransparency = 1
    thumb.BorderSizePixel = 0
    thumb.Size = UDim2.fromOffset(size, size)
    thumb.LayoutOrder = 0
    thumb.ScaleType = Enum.ScaleType.Crop

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = thumb
    thumb.Parent = top

    -- Kolom teks menyisakan tempat untuk gambar (selisih 10 = jarak antar kolom).
    info.Size = UDim2.new(1, -(size + 10), 0, 0)

    if type(image) == "number" then image = "rbxassetid://" .. image end
    if type(image) == "string" and string.sub(image, 1, 3) == "rbx" then
        thumb.Image = image
    elseif type(image) == "string" and UI.Compat and UI.Compat.ResolveImage then
        task.spawn(function()
            local ok, asset = pcall(UI.Compat.ResolveImage, image, "MugiwaraHub")
            if ok and asset and thumb.Parent then thumb.Image = asset end
        end)
    end
end

local function EnableRichText(label)
    if label then label.RichText = true end
end

local function FindByName(root, name)
    for _, child in ipairs(root:GetDescendants()) do
        if child.Name == name then return child end
    end
    return nil
end

-- Warna ikon: Color3 (tetap), nama token tema seperti "Success" (ikut tema), atau nil (aksen tema).
local function PaintIcon(UI, Window, image, color)
    if typeof(color) == "Color3" then
        UI.Icons.Tint(image, color)
    elseif type(color) == "string" and Window.Theme.Tokens[color] ~= nil then
        UI.Icons.BindImage(Window.Theme, image, color)
    else
        UI.Icons.BindImage(Window.Theme, image, "Accent")
    end
end

-- Section di library belum punya Icon. Ikon (opts.Icon, warna opts.IconColor) dipasang di header
-- sebelum judul; teks judul bergeser sebesar lebar ikon.
local function AttachSectionIcon(UI, Window, section, header, title, icon, color)
    local holder = Instance.new("Frame")
    holder.Name = "IconHolder"
    holder.AnchorPoint = Vector2.new(0, 0.5)
    holder.Position = UDim2.new(0, 14, 0.5, 0)
    holder.Size = UDim2.fromOffset(16, 16)
    holder.BackgroundTransparency = 1
    holder.Parent = header

    local image = UI.Icons.Create(icon, holder)
    if not image then
        holder:Destroy()
        return
    end
    PaintIcon(UI, Window, image, color)

    title.Position = UDim2.fromOffset(38, 0)
    title.Size = UDim2.new(1, -74, 1, 0)

    section.IconLabel = image
    function section:SetIconColor(newColor)
        PaintIcon(UI, Window, image, newColor)
    end
end

function UIExtras.Install(UI, Window)
    if Window._MugiwaraExtras then return end
    Window._MugiwaraExtras = true

    -- Tab dan elemen sementara hanya untuk mengambil class bersama milik library (Container dan
    -- Element); keduanya langsung dihapus lagi di frame yang sama.
    local probe = Window:Tab({ Title = "_probe" })
    local probeElement = probe:Toggle({ Title = "_probe" })
    local Container = getmetatable(probe)
    local Element = getmetatable(probeElement)
    probeElement:Destroy()
    probe:Destroy()

    if type(Container) ~= "table" or type(Element) ~= "table" then
        warn("[Mugiwara HUB] UIExtras: could not reach the library classes; premium labels and thumbnails are disabled.")
        return
    end

    -- SetValue / SetColor: ubah tampilan elemen TANPA memicu callback-nya (dipakai Lighting dan
    -- Camera untuk menyamakan UI dengan nilai yang diubah dari luar, jadi tidak boleh memicu loop).
    if Element.SetValue == nil then
        Element.SetValue = function(self, value) return self:Set(value, true) end
    end
    if Element.SetColor == nil then
        Element.SetColor = function(self, value) return self:Set(value, true) end
    end

    -- LockedTitle: teks di atas overlay elemen yang terkunci.
    local originalLock = Element.Lock
    Element.Lock = function(self, state)
        originalLock(self, state)
        local title = self.Options and self.Options.LockedTitle
        local overlay = self.LockOverlay
        if title and overlay then
            overlay.Text = (state ~= false) and tostring(title) or ""
            overlay.Font = Enum.Font.GothamBold
            overlay.TextSize = 13
            overlay.TextColor3 = GOLD
            overlay.TextXAlignment = Enum.TextXAlignment.Center
        end
    end

    -- Paragraph dengan Image + ImageSize: gambar kecil di samping teks, bukan latar kartu.
    local originalParagraph = Container.Paragraph
    Container.Paragraph = function(self, opts)
        if type(opts) == "table" and opts.Image ~= nil then
            local copy = CopyOptions(opts)
            copy.Image = nil
            copy.ImageSize = nil
            local element = originalParagraph(self, copy)
            AttachThumbnail(UI, element, opts.Image, opts.ImageSize)
            return element
        end
        return originalParagraph(self, opts)
    end

    -- Judul Section berwarna (`<font color="#ffff82">...</font>`) dan ikon di header Section.
    local originalSection = Container.Section
    Container.Section = function(self, opts)
        local section = originalSection(self, opts)
        if type(opts) == "table" and section and section.Frame then
            local header = FindByName(section.Frame, "Header")
            local title = header and header:FindFirstChildOfClass("TextLabel")
            if HasMarkup(opts.Title) then EnableRichText(title) end
            if title and opts.Icon ~= nil and opts.Icon ~= "" then
                local ok, err = pcall(AttachSectionIcon, UI, Window, section, header, title, opts.Icon, opts.IconColor)
                if not ok then warn("[Mugiwara HUB] Section icon error: " .. tostring(err)) end
            end
        end
        return section
    end

    -- Judul Tab berwarna: label tab tidak disimpan library, jadi dicari dari tombol di sidebar.
    local originalTab = Window.Tab
    Window.Tab = function(self, opts)
        local tab = originalTab(self, opts)
        if type(opts) == "table" and HasMarkup(opts.Title) and self.TabList then
            local button
            for _, child in ipairs(self.TabList:GetChildren()) do
                if child:IsA("TextButton") and child.Name == opts.Title then button = child end
            end
            EnableRichText(button and button:FindFirstChildOfClass("TextLabel"))
        end
        return tab
    end
end

-- Library hanya punya Window.Opened. Hook ini memanggil callback saat window benar-benar berubah
-- (bukan saat Open/Close dipanggil dua kali). Dipasang SETELAH pemanggilan Open/Close awal.
function UIExtras.HookVisibility(Window, onOpen, onClose)
    local originalOpen, originalClose = Window.Open, Window.Close

    Window.Open = function(self, ...)
        local was = self.Opened
        originalOpen(self, ...)
        if not was and self.Opened and onOpen then pcall(onOpen) end
    end

    Window.Close = function(self, ...)
        local was = self.Opened
        originalClose(self, ...)
        if was and not self.Opened and onClose then pcall(onClose) end
    end
end

return UIExtras
