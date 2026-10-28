local Settings = getgenv().MugiwaraImport("Manager/UISettings.lua")

-- Semua pengaturan tampilan hub di satu tab (dibungkus tab section di paling bawah sidebar): tema,
-- wallpaper, skala, blur, dan pembuat tema. Tidak ada kaitannya dengan fitur game.
return function(Window, isPremiumUser, MugiwaraUI)
    if not Settings then return end

    local Group = Window:TabSection({ Title = "Appearance" })
    local Tab = Group:Tab({ Title = "UI Config", Icon = "lucide:monitor-cog" })

    local function Notify(title, content, duration)
        MugiwaraUI:Notify({ Title = title, Content = content, Duration = duration or 3 })
    end

    local function ValueOf(element, fallback)
        local value = element and element.Value
        if typeof(value) == "Color3" then return value end
        return fallback
    end

    local WALLPAPER_MODES = {
        { Title = "Theme Default", Desc = "Each theme brings its own picture.", Icon = "lucide:wand-sparkles", Mode = "theme" },
        { Title = "Custom", Desc = "Use the image ID typed below.", Icon = "lucide:image", Mode = "custom" },
        { Title = "None", Desc = "No wallpaper behind the window.", Icon = "lucide:image-off", Mode = "none" },
    }
    local function ModeTitle(mode)
        for _, item in ipairs(WALLPAPER_MODES) do
            if item.Mode == mode then return item.Title end
        end
        return WALLPAPER_MODES[1].Title
    end
    local function ModeFromTitle(title)
        for _, item in ipairs(WALLPAPER_MODES) do
            if item.Title == title then return item.Mode end
        end
        return "theme"
    end

    -- Item dropdown tema: nama, deskripsi tema, dan titik warna aksen tema itu sendiri.
    local function ThemeItems()
        local items = {}
        for _, name in ipairs(MugiwaraUI:GetThemes()) do
            local custom = Settings.IsCustomTheme(name)
            local okTokens, tokens = pcall(MugiwaraUI.Theme.Preview, name)
            tokens = okTokens and tokens or {}
            table.insert(items, {
                Title = name,
                Desc = tokens.Desc or (custom and "Custom theme" or nil),
                Icon = custom and "lucide:brush" or "lucide:palette",
                IconColor = tokens.Accent,
            })
        end
        return items
    end

    local function CustomItems()
        local items = {}
        for _, name in ipairs(Settings.CustomThemeNames()) do
            local okTokens, tokens = pcall(MugiwaraUI.Theme.Preview, name)
            table.insert(items, {
                Title = name,
                Desc = "Custom theme",
                Icon = "lucide:brush",
                IconColor = okTokens and tokens.Accent or nil,
            })
        end
        return items
    end

    -- ==========================================
    -- THEME
    -- ==========================================
    local ThemeSection = Tab:Section({ Title = "Theme", Icon = "lucide:palette", Opened = false, Box = true })

    local ThemeDropdown = ThemeSection:Dropdown({
        Title = "Theme",
        Desc = "Recolors the whole hub instantly. The choice is remembered.",
        Icon = "lucide:swatch-book",
        Values = ThemeItems(),
        Value = MugiwaraUI:GetTheme(),
        Callback = function(Option)
            if type(Option) == "string" and Option ~= MugiwaraUI:GetTheme() then
                MugiwaraUI:SetTheme(Option)
            end
        end
    })

    ThemeSection:Button({
        Title = "Open Theme Menu",
        Desc = "Preview every theme in the top-bar menu.",
        Icon = "lucide:panels-top-left",
        Callback = function()
            Window:OpenThemeMenu()
        end
    })

    -- Tema juga bisa diganti dari menu di top bar; dropdown ikut berubah dan pilihan disimpan.
    local stopThemeListener = MugiwaraUI.Theme:OnChange(function(_, name)
        Settings.Set("Theme", name)
        pcall(function() ThemeDropdown:Set(name, true) end)
        Settings.ApplyStrengthSoon(Window)
    end)
    getgenv().MugiwaraRegisterCleanup(stopThemeListener)

    -- ==========================================
    -- WALLPAPER
    -- ==========================================
    local WallpaperSection = Tab:Section({ Title = "Wallpaper", Icon = "lucide:image", Opened = false, Box = true })

    local WallpaperModeDropdown, WallpaperInput, StrengthSlider

    WallpaperModeDropdown = WallpaperSection:Dropdown({
        Title = "Wallpaper",
        Desc = "The picture behind the window.",
        Icon = "lucide:image",
        Values = WALLPAPER_MODES,
        Value = ModeTitle(Settings.Get("WallpaperMode")),
        Callback = function(Option)
            local mode = ModeFromTitle(Option)
            if mode == "custom" and Settings.Get("WallpaperId") == "" then
                Notify("Custom Wallpaper", "Type an image ID in the box below first.", 3)
                return
            end
            Settings.Set("WallpaperMode", mode)
            Settings.ApplyWallpaper(Window)
        end
    })

    WallpaperInput = WallpaperSection:Input({
        Title = "Custom Wallpaper",
        Desc = "Image asset ID or rbxassetid://... Press Enter to apply.",
        Icon = "lucide:hash",
        Placeholder = "rbxassetid://...",
        Value = Settings.Get("WallpaperId"),
        Callback = function(Text)
            Text = tostring(Text or ""):match("^%s*(.-)%s*$")
            if Text == Settings.Get("WallpaperId") then return end
            Settings.Set("WallpaperId", Text)
            if Text == "" then
                Settings.Set("WallpaperMode", "theme")
            else
                Settings.Set("WallpaperMode", "custom")
            end
            Settings.ApplyWallpaper(Window)
        end
    })

    StrengthSlider = WallpaperSection:Slider({
        Title = "Wallpaper Strength",
        Desc = "How visible the picture is.",
        Icon = "lucide:blend",
        Step = 1,
        Suffix = "%",
        Value = { Min = 0, Max = 100, Default = Settings.Get("WallpaperStrength") },
        Callback = function(Value)
            Settings.Set("WallpaperStrength", Value)
            Settings.ApplyStrength(Window)
        end
    })

    -- ==========================================
    -- WINDOW
    -- ==========================================
    local WindowSection = Tab:Section({ Title = "Window", Icon = "lucide:app-window", Opened = false, Box = true })

    local ScaleSlider = WindowSection:Slider({
        Title = "UI Scale",
        Desc = "Make the whole window bigger or smaller.",
        Icon = "lucide:scaling",
        Step = 0.05,
        Suffix = "x",
        Value = { Min = Settings.ScaleMin, Max = Settings.ScaleMax, Default = Settings.Get("Scale") },
        Callback = function(Value)
            Settings.Set("Scale", Value)
            Window:SetScale(Value)
        end
    })

    local BlurToggle = WindowSection:Toggle({
        Title = "Background Blur",
        Desc = "Blur the game behind the window while it is open.",
        Icon = "lucide:droplet",
        Value = Settings.Get("Blur"),
        Callback = function(Value)
            Settings.Set("Blur", Value)
            Window:SetBlur(Value)
        end
    })

    WindowSection:Button({
        Title = "Maximize / Restore",
        Desc = "Same as the square button in the top bar.",
        Icon = "lucide:maximize-2",
        Callback = function()
            Window:ToggleMaximized()
        end
    })

    WindowSection:Button({
        Title = "Reset UI Settings",
        Desc = "Back to the default theme, scale, blur and wallpaper. Your custom themes are kept.",
        Icon = "lucide:rotate-ccw",
        Callback = function()
            Window:Dialog({
                Title = "Reset UI settings?",
                Content = "Theme, scale, blur and wallpaper go back to their defaults.",
                Buttons = {
                    { Title = "Cancel" },
                    {
                        Title = "Reset",
                        Callback = function()
                            Settings.Reset()
                            MugiwaraUI:SetTheme(Settings.Get("Theme"))
                            Window:SetScale(Settings.Get("Scale"))
                            Window:SetBlur(Settings.Get("Blur"))
                            Settings.ApplyWallpaper(Window)
                            pcall(function() ScaleSlider:Set(Settings.Get("Scale"), true) end)
                            pcall(function() BlurToggle:Set(Settings.Get("Blur"), true) end)
                            pcall(function() WallpaperModeDropdown:Set(ModeTitle(Settings.Get("WallpaperMode")), true) end)
                            pcall(function() WallpaperInput:Set(Settings.Get("WallpaperId"), true) end)
                            pcall(function() StrengthSlider:Set(Settings.Get("WallpaperStrength"), true) end)
                            Notify("UI Settings", "Everything is back to the defaults.")
                        end
                    }
                }
            })
        end
    })

    -- ==========================================
    -- CREATE THEME
    -- ==========================================
    local CreateSection = Tab:Section({ Title = "Create Theme", Icon = "lucide:brush", Opened = false, Box = true })

    local themeName = ""
    local themeWallpaper = ""

    CreateSection:Input({
        Title = "Theme Name",
        Desc = "2 to 24 letters or numbers. Reusing a custom name replaces it.",
        Icon = "lucide:pencil-line",
        Placeholder = "My Theme",
        Callback = function(Text) themeName = tostring(Text or "") end
    })

    local AccentPicker = CreateSection:Colorpicker({ Title = "Accent", Desc = "Buttons, toggles and highlights.", Icon = "lucide:droplet", Default = Color3.fromRGB(255, 170, 60), Callback = function() end })
    local GradientAPicker = CreateSection:Colorpicker({ Title = "Gradient Start", Desc = "First color of the title gradients.", Icon = "lucide:arrow-up-to-line", Default = Color3.fromRGB(255, 246, 222), Callback = function() end })
    local GradientBPicker = CreateSection:Colorpicker({ Title = "Gradient End", Desc = "Last color of the title gradients.", Icon = "lucide:arrow-down-to-line", Default = Color3.fromRGB(255, 52, 82), Callback = function() end })
    local BackgroundPicker = CreateSection:Colorpicker({ Title = "Background", Desc = "The window background tint.", Icon = "lucide:square", Default = Color3.fromRGB(12, 13, 21), Callback = function() end })
    local TextPicker = CreateSection:Colorpicker({ Title = "Text", Desc = "Main text color.", Icon = "lucide:type", Default = Color3.fromRGB(252, 252, 255), Callback = function() end })

    CreateSection:Input({
        Title = "Theme Wallpaper",
        Desc = "Optional image ID shown with this theme.",
        Icon = "lucide:image",
        Placeholder = "rbxassetid://...",
        Callback = function(Text) themeWallpaper = tostring(Text or ""):match("^%s*(.-)%s*$") end
    })

    local SavedDropdown
    local selectedCustom = nil

    CreateSection:Button({
        Title = "Create & Apply",
        Desc = "Builds the theme from the colors above, saves it and switches to it.",
        Icon = "lucide:circle-plus",
        Callback = function()
            local ok, result = Settings.SaveTheme(MugiwaraUI, themeName, {
                Accent = Settings.ToHex(ValueOf(AccentPicker, Color3.fromRGB(255, 170, 60))),
                GradientA = Settings.ToHex(ValueOf(GradientAPicker, Color3.fromRGB(255, 246, 222))),
                GradientB = Settings.ToHex(ValueOf(GradientBPicker, Color3.fromRGB(255, 52, 82))),
                Background = Settings.ToHex(ValueOf(BackgroundPicker, Color3.fromRGB(12, 13, 21))),
                Text = Settings.ToHex(ValueOf(TextPicker, Color3.fromRGB(252, 252, 255))),
                Wallpaper = themeWallpaper,
            })
            if not ok then
                Notify("Could Not Create Theme", result, 4)
                return
            end

            pcall(function() ThemeDropdown:Refresh(ThemeItems(), false) end)
            pcall(function() SavedDropdown:Refresh(CustomItems(), false) end)
            MugiwaraUI:SetTheme(result)
            Notify("Theme Created", "'" .. result .. "' is saved and active.")
        end
    })

    -- ==========================================
    -- CUSTOM THEMES
    -- ==========================================
    local SavedSection = Tab:Section({ Title = "Custom Themes", Icon = "lucide:folder-open", Opened = false, Box = true })

    SavedDropdown = SavedSection:Dropdown({
        Title = "Saved Themes",
        Desc = "Themes you created.",
        Icon = "lucide:folder-open",
        Values = CustomItems(),
        AllowNone = true,
        Callback = function(Option)
            selectedCustom = (type(Option) == "string" and Option ~= "") and Option or nil
        end
    })

    SavedSection:Button({
        Title = "Apply Selected",
        Desc = "Switch to the selected custom theme.",
        Icon = "lucide:check",
        Callback = function()
            if not selectedCustom then
                Notify("Custom Themes", "Select a theme first.", 3)
                return
            end
            MugiwaraUI:SetTheme(selectedCustom)
        end
    })

    SavedSection:Button({
        Title = "Delete Selected",
        Desc = "Remove the selected custom theme for good.",
        Icon = "lucide:trash-2",
        Callback = function()
            if not selectedCustom then
                Notify("Custom Themes", "Select a theme first.", 3)
                return
            end
            local name = selectedCustom
            if Settings.DeleteTheme(MugiwaraUI, name) then
                selectedCustom = nil
                pcall(function() ThemeDropdown:Refresh(ThemeItems(), true) end)
                pcall(function() SavedDropdown:Refresh(CustomItems(), false) end)
                Notify("Theme Deleted", "'" .. name .. "' was removed.")
            end
        end
    })
end
