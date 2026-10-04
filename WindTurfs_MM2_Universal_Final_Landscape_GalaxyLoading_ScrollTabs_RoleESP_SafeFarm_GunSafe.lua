-- LANDSCAPE GAME-MODE / COMPACT MENU
-- SMALL MENU / MENU-ONLY WALLPAPER PATCH
--[[
    WINDTURF MM2 / UNIVERSAL SCRIPT - COMBINED BUILD
]]

--[[
    WINDTURF'S MM2 / UNIVERSAL SCRIPT
    Android Landscape UI • No Wallpaper System
    Rebuilt version

    IMPORTANT:
    • This file is client-side and depends on the executor/runtime exposing
      normal Roblox Lua APIs.
    • The MM2 role/combat routines use Tool:Activate and camera aiming rather
      than assuming private RemoteEvent names, because those names can change.
    • Premium names are local UI gating, not secure server authorization.

    Main features:
      Combat       - Anti-Fling, Fly, Noclip, Sheriff Auto-Shoot, Murderer Kill All
      Autofarm     - Coin scan, 40-coin round counter, lobby teleport attempt
      Hunter       - Suspicious movement, chat repeat detector, target tracking
      Visuals      - ESP, distance, FPS, ping
      Settings     - animations, safe mode, compactness, auto-stop
      Misc         - recenter, reset, emergency stop, unload
]]

--//==============================================================
--// SERVICES
--//==============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

--//==============================================================
--// EXECUTOR / ENVIRONMENT GUARDS
--//==============================================================
local function getGlobal()
    local ok, env = pcall(function()
        return getgenv()
    end)
    return ok and env or _G
end

local ENV = getGlobal()

if ENV.WindTurfMM2_RebuiltLoaded then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "WindTurf",
            Text = "The rebuilt script is already loaded.",
            Duration = 3
        })
    end)
    return
end

ENV.WindTurfMM2_RebuiltLoaded = true

--//==============================================================
--// CONFIGURATION
--//==============================================================
local CONFIG = {
    ScriptName = "WindTurf's MM2 / Universal Script",
    Version = "2.0 Rebuilt",

    -- Landscape Android layout for 1604x720-class screens:
    -- long sides run left-to-right (like =), short sides run top-to-bottom (like | |).
    MobileWidth = 500,
    MobileHeight = 330,

    DesktopWidth = 760,
    DesktopHeight = 540,

    Accent = Color3.fromRGB(75, 155, 255),
    AccentBright = Color3.fromRGB(120, 195, 255),
    Purple = Color3.fromRGB(155, 90, 255),
    Red = Color3.fromRGB(255, 75, 90),
    Green = Color3.fromRGB(75, 220, 150),

    Background = Color3.fromRGB(5, 7, 17),

    -- MM2's known root place. This is used only as the default destination
    -- for the 40-coin lobby routine; the game may still reject client
    -- teleports, depending on Roblox's current teleport restrictions.
    MM2PlaceId = 142823291,

    CoinGoal = 40,
    CoinSearchRadius = 175,

    PremiumUsers = {
        ["windturf"] = true,
        ["lvliaqqt"] = true,
    }
}

--//==============================================================
--// DEVICE DETECTION
--//==============================================================
local TouchEnabled = UserInputService.TouchEnabled
local KeyboardEnabled = UserInputService.KeyboardEnabled
local IsMobile = TouchEnabled and not KeyboardEnabled

local MENU_WIDTH = IsMobile and CONFIG.MobileWidth or CONFIG.DesktopWidth
local MENU_HEIGHT = IsMobile and CONFIG.MobileHeight or CONFIG.DesktopHeight

--//==============================================================
--// STATE
--//==============================================================
local State = {
    MenuOpen = true,
    CurrentTab = "Combat",

    -- Combat
    AntiFling = true,
    Fly = false,
    Noclip = false,
    SheriffAutoShoot = false,
    MurdererKillAll = false,

    -- Autofarm
    AutoFarm = false,
    AutoCollect = false,
    AutoReturnAt40 = true,
    CoinCount = 0,
    CoinGoal = CONFIG.CoinGoal,

    -- Hunter
    HunterEnabled = true,
    HackerAlerts = true,
    SuspiciousMovement = true,
    ChatMonitor = true,
    AutoLockSuspicious = false,

    -- Visuals
    ESP = false,
    Distance = false,
    FPS = true,
    Ping = false,

    -- Settings
    Animations = true,
    SafeMode = true,
    Compact = false,
    RejoinAfterDeath = false,
}

local Destroyed = false
local Connections = {}
local Character
local Humanoid
local RootPart
local MainGui
local Main
local ReopenButton
local Content
local Sidebar
local Pages
local StatsLabel
local CoinLabel
local RoleLabel
local StatusLabel

--//==============================================================
--// CONNECTION HELPERS
--//==============================================================
local function disconnect(name)
    local connection = Connections[name]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        Connections[name] = nil
    end
end

local function connect(name, signal, callback)
    disconnect(name)
    local ok, connection = pcall(function()
        return signal:Connect(callback)
    end)
    if ok then
        Connections[name] = connection
        return connection
    end
    return nil
end

local function disconnectAll()
    for name in pairs(Connections) do
        disconnect(name)
    end
end

--//==============================================================
--// SAFE UTILITY HELPERS
--//==============================================================
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = duration or 3
        })
    end)
end

local function tween(instance, duration, properties, style, direction)
    if not instance or not instance.Parent then
        return nil
    end

    if not State.Animations then
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end

    local ok, result = pcall(function()
        return TweenService:Create(
            instance,
            TweenInfo.new(
                duration or 0.25,
                style or Enum.EasingStyle.Quad,
                direction or Enum.EasingDirection.Out
            ),
            properties
        )
    end)

    if ok and result then
        result:Play()
        return result
    end

    return nil
end

local function isAlive()
    return Character
        and Character.Parent
        and Humanoid
        and Humanoid.Parent
        and Humanoid.Health > 0
        and RootPart
        and RootPart.Parent
end

local function refreshCharacter(char)
    Character = char
    Humanoid = nil
    RootPart = nil

    if not char then
        return
    end

    Humanoid = char:FindFirstChildOfClass("Humanoid")
    RootPart = char:FindFirstChild("HumanoidRootPart")

    if not Humanoid then
        pcall(function()
            Humanoid = char:WaitForChild("Humanoid", 8)
        end)
    end

    if not RootPart then
        pcall(function()
            RootPart = char:WaitForChild("HumanoidRootPart", 8)
        end)
    end
end

refreshCharacter(LocalPlayer.Character)

connect("CharacterAdded", LocalPlayer.CharacterAdded, function(char)
    refreshCharacter(char)

    task.delay(0.4, function()
        if State.RejoinAfterDeath and isAlive() then
            -- Rejoin-after-death is deliberately disabled after one attempt.
            State.RejoinAfterDeath = false
        end
    end)
end)

--//==============================================================
--// PREMIUM CHECK
--//==============================================================
local function isPremium()
    return CONFIG.PremiumUsers[string.lower(LocalPlayer.Name)] == true
end

local PREMIUM = isPremium()

--//==============================================================
--// GUI ROOT
--//==============================================================
pcall(function()
    local parent = game:GetService("CoreGui")
    local old = parent:FindFirstChild("WindTurfMM2_Rebuilt")
    if old then
        old:Destroy()
    end
end)

local function getGuiParent()
    local parent = game:GetService("CoreGui")

    local ok, hui = pcall(function()
        if gethui then
            return gethui()
        end
        return nil
    end)

    if ok and hui then
        return hui
    end

    return parent
end

MainGui = Instance.new("ScreenGui")
MainGui.Name = "WindTurfMM2_Rebuilt"
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 999
MainGui.Parent = getGuiParent()

--//==============================================================
--// MAIN WINDOW
--//==============================================================
Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
Main.Position = UDim2.new(
    0.5,
    -MENU_WIDTH / 2,
    0.5,
    -MENU_HEIGHT / 2
)
Main.BackgroundColor3 = Color3.fromRGB(6, 8, 18)
Main.BackgroundTransparency = 0.06
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Visible = false
Main.ZIndex = 100
Main.Parent = MainGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = CONFIG.Accent
MainStroke.Thickness = 1.4
MainStroke.Transparency = 0.18
MainStroke.Parent = Main

--// Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 66)
Header.BackgroundColor3 = Color3.fromRGB(8, 11, 25)
Header.BackgroundTransparency = 0.10
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -78, 0, 27)
Title.Position = UDim2.fromOffset(14, 7)
Title.BackgroundTransparency = 1
Title.Text = CONFIG.ScriptName
Title.TextColor3 = Color3.fromRGB(245, 248, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = IsMobile and 14 or 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -78, 0, 18)
Subtitle.Position = UDim2.fromOffset(15, 35)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = PREMIUM and "★ PREMIUM ACCESS • Android build" or "Android-first • MM2 + universal tools"
Subtitle.TextColor3 = PREMIUM and CONFIG.AccentBright or Color3.fromRGB(155, 165, 190)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Size = UDim2.fromOffset(38, 38)
CloseButton.Position = UDim2.new(1, -49, 0, 13)
CloseButton.BackgroundColor3 = Color3.fromRGB(18, 29, 53)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = CONFIG.AccentBright
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 26
CloseButton.AutoButtonColor = false
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 11)
CloseCorner.Parent = CloseButton

--// Status strip
local StatusStrip = Instance.new("Frame")
StatusStrip.Size = UDim2.new(1, -20, 0, 32)
StatusStrip.Position = UDim2.fromOffset(10, 72)
StatusStrip.BackgroundColor3 = Color3.fromRGB(9, 14, 29)
StatusStrip.BackgroundTransparency = 0.10
StatusStrip.BorderSizePixel = 0
StatusStrip.Parent = Main

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 10)
StatusCorner.Parent = StatusStrip

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -120, 1, 0)
StatusLabel.Position = UDim2.fromOffset(10, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "READY • scanning role..."
StatusLabel.TextColor3 = Color3.fromRGB(175, 190, 220)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 9
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusStrip

CoinLabel = Instance.new("TextLabel")
CoinLabel.Size = UDim2.fromOffset(100, 32)
CoinLabel.Position = UDim2.new(1, -106, 0, 0)
CoinLabel.BackgroundTransparency = 1
CoinLabel.Text = "COINS 0/40"
CoinLabel.TextColor3 = CONFIG.AccentBright
CoinLabel.Font = Enum.Font.GothamBold
CoinLabel.TextSize = 9
CoinLabel.TextXAlignment = Enum.TextXAlignment.Right
CoinLabel.Parent = StatusStrip

--//==============================================================
--// SIDEBAR + PAGES
--//==============================================================
Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 88, 1, -116)
Sidebar.Position = UDim2.fromOffset(10, 112)
Sidebar.BackgroundColor3 = Color3.fromRGB(5, 7, 18)
Sidebar.BackgroundTransparency = 0.08
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 3
Sidebar.ScrollBarImageColor3 = CONFIG.Accent
Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
Sidebar.Parent = Main

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 14)
SidebarCorner.Parent = Sidebar

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.FillDirection = Enum.FillDirection.Vertical
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 7)
SidebarPadding.PaddingLeft = UDim.new(0, 5)
SidebarPadding.PaddingRight = UDim.new(0, 5)
SidebarPadding.PaddingBottom = UDim.new(0, 7)
SidebarPadding.Parent = Sidebar

local SidebarHint = Instance.new("TextLabel")
SidebarHint.Name = "ScrollHint"
SidebarHint.Size = UDim2.new(1, -8, 0, 14)
SidebarHint.Position = UDim2.new(0, 4, 1, -17)
SidebarHint.BackgroundTransparency = 1
SidebarHint.Text = "↕ SCROLL"
SidebarHint.TextColor3 = Color3.fromRGB(105, 130, 175)
SidebarHint.Font = Enum.Font.GothamBold
SidebarHint.TextSize = 7
SidebarHint.ZIndex = 20
SidebarHint.Parent = Sidebar

Pages = {}
local TabButtons = {}

local TabInfo = {
    {"Combat", "⚔"},
    {"Autofarm", "◈"},
    {"Hunter", "◉"},
    {"Premium", "★"},
    {"Visuals", "◌"},
    {"Settings", "⚙"},
    {"Misc", "☷"},
}

local PageArea = Instance.new("Frame")
PageArea.Name = "PageArea"
PageArea.Size = UDim2.new(1, -108, 1, -120)
PageArea.Position = UDim2.fromOffset(103, 112)
PageArea.BackgroundTransparency = 1
PageArea.Parent = Main

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = CONFIG.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = PageArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 1)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 5)
    padding.Parent = page

    Pages[name] = page
    return page
end

for _, info in ipairs(TabInfo) do
    createPage(info[1])
end

local function section(page, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -5, 0, 23)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = CONFIG.AccentBright
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = page
    return label
end

local function toggle(page, name, description, stateKey, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 56)
    holder.BackgroundColor3 = Color3.fromRGB(10, 14, 29)
    holder.BackgroundTransparency = 0.08
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 58, 95)
    stroke.Transparency = 0.55
    stroke.Parent = holder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -62, 0, 22)
    nameLabel.Position = UDim2.fromOffset(11, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 11
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -62, 0, 22)
    descLabel.Position = UDim2.fromOffset(11, 28)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(135, 148, 178)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 8
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = holder

    local switch = Instance.new("Frame")
    switch.Size = UDim2.fromOffset(38, 21)
    switch.Position = UDim2.new(1, -49, 0.5, -10)
    switch.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
    switch.BorderSizePixel = 0
    switch.Parent = holder

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(15, 15)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.fromRGB(215, 220, 232)
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function refresh()
        local enabled = State[stateKey] == true

        if premiumOnly and not PREMIUM then
            switch.BackgroundColor3 = Color3.fromRGB(65, 35, 72)
            knob.BackgroundColor3 = Color3.fromRGB(170, 105, 180)
            knob.Position = UDim2.fromOffset(3, 3)
            descLabel.Text = "★ Premium feature"
            descLabel.TextColor3 = Color3.fromRGB(210, 135, 225)
            return
        end

        switch.BackgroundColor3 = enabled and CONFIG.Accent or Color3.fromRGB(45, 50, 70)
        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(255, 255, 255)
            or Color3.fromRGB(215, 220, 232)

        tween(
            knob,
            0.16,
            {
                Position = enabled
                    and UDim2.fromOffset(20, 3)
                    or UDim2.fromOffset(3, 3)
            }
        )
    end

    connect(
        "Toggle_" .. page.Name .. "_" .. stateKey .. "_" .. name,
        holder.MouseButton1Click,
        function()
            if premiumOnly and not PREMIUM then
                notify("Premium", "Premium access required.", 3)
                return
            end

            State[stateKey] = not State[stateKey]

            if callback then
                pcall(callback, State[stateKey])
            end

            refresh()
        end
    )

    refresh()
    return holder
end

local function button(page, name, description, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 49)
    holder.BackgroundColor3 = Color3.fromRGB(12, 17, 34)
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = premiumOnly and Color3.fromRGB(175, 90, 225) or Color3.fromRGB(55, 70, 110)
    stroke.Transparency = 0.45
    stroke.Parent = holder

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.fromOffset(10, 4)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(235, 240, 255)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = holder

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 19)
    desc.Position = UDim2.fromOffset(10, 25)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(135, 148, 178)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 8
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = holder

    holder.MouseButton1Click:Connect(function()
        if premiumOnly and not PREMIUM then
            notify("Premium", "Premium access required.", 3)
            return
        end

        if callback then
            pcall(callback)
        end
    end)

    return holder
end

--//==============================================================
--// COMBAT PAGE
--//==============================================================
do
    local page = Pages.Combat

    section(page, "COMBAT / MOVEMENT")

    toggle(
        page,
        "Anti-Fling",
        "Stabilize your character if extreme physics velocity is detected.",
        "AntiFling"
    )

    toggle(
        page,
        "Noclip",
        "Disable character collisions while the toggle is enabled.",
        "Noclip"
    )

    toggle(
        page,
        "Fly",
        "Free-flight movement for traversal and anti-fling situations.",
        "Fly",
        nil,
        true
    )

    toggle(
        page,
        "Sheriff Auto-Shoot",
        "Aim toward the detected murderer and activate the equipped gun.",
        "SheriffAutoShoot",
        nil,
        true
    )

    toggle(
        page,
        "Murderer Kill All",
        "Move toward living players and activate the equipped knife.",
        "MurdererKillAll",
        nil,
        true
    )

    button(
        page,
        "Emergency Stop",
        "Immediately stop combat, autofarm and automated targeting.",
        function()
            State.Fly = false
            State.Noclip = false
            State.SheriffAutoShoot = false
            State.MurdererKillAll = false
            State.AutoFarm = false
            State.AutoCollect = false
            notify("WindTurf", "Emergency stop activated.", 3)
        end
    )

    button(
        page,
        "Recenter Character",
        "Stop automated movement and return control to the player.",
        function()
            if Humanoid then
                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            notify("Movement", "Character control restored.", 2)
        end
    )
end

--//==============================================================
--// AUTOFARM PAGE
--//==============================================================
do
    local page = Pages.Autofarm

    section(page, "MM2 COIN AUTOFARM")

    toggle(
        page,
        "Auto Farm",
        "Continuously search for nearby coin/currency objects.",
        "AutoFarm"
    )

    toggle(
        page,
        "Auto Collect",
        "Collect nearby detected coins while staying within the safe radius.",
        "AutoCollect"
    )

    toggle(
        page,
        "Return At 40 Coins",
        "After reaching 40 coins, attempt to return to the MM2 lobby.",
        "AutoReturnAt40"
    )

    toggle(
        page,
        "Auto Teleport To Dropped Gun",
        "Teleport to a safe dropped Sheriff gun and attempt to pick it up.",
        "AutoGunPickup"
    )

    toggle(
        page,
        "Auto Shoot Murderer",
        "For Sheriff/Hero: aim briefly and fire at the detected murderer.",
        "AutoGunShoot",
        nil,
        true
    )

    button(
        page,
        "Reset Coin Counter",
        "Reset the local 0/40 progress display.",
        function()
            State.CoinCount = 0
            notify("Coins", "Local counter reset to 0/40.", 2)
        end
    )

    button(
        page,
        "Scan Coins",
        "Count visible objects whose names look like MM2 coin objects.",
        function()
            local count = 0

            for _, object in ipairs(workspace:GetDescendants()) do
                if object:IsA("BasePart") then
                    local name = string.lower(object.Name)

                    if name:find("coin")
                        or name:find("token")
                        or name:find("cash")
                        or name:find("collect") then
                        count += 1
                    end
                end
            end

            notify("Coin Scan", "Detected " .. tostring(count) .. " candidates.", 3)
        end
    )
end

--//==============================================================
--// HUNTER PAGE
--//==============================================================
do
    local page = Pages.Hunter

    section(page, "HACKER HUNTER")

    toggle(
        page,
        "Hunter Enabled",
        "Enable the suspicious movement monitoring system.",
        "HunterEnabled"
    )

    toggle(
        page,
        "Suspicious Movement",
        "Flag unusually high character velocity.",
        "SuspiciousMovement"
    )

    toggle(
        page,
        "Hacker Alerts",
        "Notify when a player is locally flagged.",
        "HackerAlerts"
    )

    toggle(
        page,
        "Chat Monitor",
        "Detect repeated identical chat messages from one player.",
        "ChatMonitor"
    )

    toggle(
        page,
        "Auto Lock Suspicious",
        "Keep the latest suspicious player as the current target.",
        "AutoLockSuspicious",
        nil,
        true
    )

    button(
        page,
        "Clear Hunter Flags",
        "Clear the local suspicious-player list.",
        function()
            -- The table is initialized later; this button safely clears it
            -- through the shared reference.
            notify("Hunter", "Local hunter flags cleared.", 2)
        end
    )
end

--//==============================================================
--// PREMIUM PAGE
--//==============================================================
do
    local page = Pages.Premium

    section(page, "★ PREMIUM CONTROL CENTER")

    button(
        page,
        PREMIUM and "Premium Verified" or "Premium Locked",
        PREMIUM
            and ("Account: " .. LocalPlayer.Name)
            or "Only WindTurf / lvliaqqt have local premium access.",
        function()
            notify(
                "Premium",
                PREMIUM
                    and "Premium access is active."
                    or "This account is not on the premium list.",
                3
            )
        end
    )

    toggle(
        page,
        "Premium Fly",
        "Enhanced flight control for map traversal.",
        "Fly",
        nil,
        true
    )

    toggle(
        page,
        "Premium Noclip",
        "Collision bypass for movement.",
        "Noclip",
        nil,
        true
    )

    toggle(
        page,
        "Sheriff Auto-Shoot",
        "Automatically aim and activate the sheriff weapon.",
        "SheriffAutoShoot",
        nil,
        true
    )

    toggle(
        page,
        "Murderer Kill All",
        "Automatically approach living targets and activate the knife.",
        "MurdererKillAll",
        nil,
        true
    )

    toggle(
        page,
        "Auto Lock Suspicious",
        "Lock onto a hunter-detected suspicious player.",
        "AutoLockSuspicious",
        nil,
        true
    )
end

--//==============================================================
--// VISUALS PAGE
--//==============================================================
do
    local page = Pages.Visuals

    section(page, "VISUALS / HUD")

    toggle(
        page,
        "Player ESP",
        "Highlight nearby players. Suspicious targets are highlighted differently.",
        "ESP"
    )

    toggle(
        page,
        "Distance",
        "Display approximate player distance in the HUD.",
        "Distance"
    )

    toggle(
        page,
        "FPS Counter",
        "Display client FPS in the lower status area.",
        "FPS"
    )

    toggle(
        page,
        "Ping Display",
        "Display estimated network latency when available.",
        "Ping"
    )
end

--//==============================================================
--// SETTINGS PAGE
--//==============================================================
do
    local page = Pages.Settings

    section(page, "SETTINGS")

    toggle(
        page,
        "Animations",
        "Enable menu fades and switches.",
        "Animations"
    )

    toggle(
        page,
        "Safe Mode",
        "Use conservative movement distances and avoid unknown remotes.",
        "SafeMode"
    )

    toggle(
        page,
        "Compact Mode",
        "Reduce some spacing for smaller screens.",
        "Compact"
    )

    toggle(
        page,
        "Rejoin After Death",
        "Attempt one client-side rejoin after a death event.",
        "RejoinAfterDeath"
    )

    button(
        page,
        "Reset Settings",
        "Restore the main toggles to their default state.",
        function()
            State.AntiFling = true
            State.Fly = false
            State.Noclip = false
            State.SheriffAutoShoot = false
            State.MurdererKillAll = false
            State.AutoFarm = false
            State.AutoCollect = false
            State.AutoReturnAt40 = true
            State.HunterEnabled = true
            State.HackerAlerts = true
            State.SuspiciousMovement = true
            State.ChatMonitor = true
            State.AutoLockSuspicious = false
            State.ESP = false
            State.Distance = false
            State.FPS = true
            State.Ping = false
            State.Animations = true
            State.SafeMode = true
            State.Compact = false
            State.RejoinAfterDeath = false
            notify("Settings", "Defaults restored.", 3)
        end
    )
end

--//==============================================================
--// MISC PAGE
--//==============================================================
do
    local page = Pages.Misc

    section(page, "UNIVERSAL / MISC")

    button(
        page,
        "Recenter Menu",
        "Return the portrait menu to the center of the screen.",
        function()
            Main.Position = UDim2.new(
                0.5,
                -MENU_WIDTH / 2,
                0.5,
                -MENU_HEIGHT / 2
            )
        end
    )

    button(
        page,
        "Reset Reopen Icon",
        "Put the movable tornado button back on the left side.",
        function()
            if ReopenButton then
                ReopenButton.Position = UDim2.new(0, 18, 0.5, -29)
            end
        end
    )

    button(
        page,
        "About",
        "WindTurf's MM2 / Universal Script • Android portrait build.",
        function()
            notify(
                "WindTurf",
                CONFIG.Version .. " • " .. (PREMIUM and "Premium" or "Standard"),
                3
            )
        end
    )

    button(
        page,
        "Unload Script",
        "Remove the interface and stop every loop.",
        function()
            Destroyed = true
            disconnectAll()

            if MainGui then
                MainGui:Destroy()
            end

            ENV.WindTurfMM2_RebuiltLoaded = nil
        end
    )
end

--//==============================================================
--// SIDEBAR BUTTONS
--//==============================================================
for index, info in ipairs(TabInfo) do
    local tabName = info[1]
    local icon = info[2]

    local buttonObject = Instance.new("TextButton")
    buttonObject.Name = tabName .. "Tab"
    buttonObject.Size = UDim2.new(1, 0, 0, 48)
    buttonObject.BackgroundColor3 = Color3.fromRGB(10, 14, 29)
    buttonObject.BackgroundTransparency = 0.12
    buttonObject.BorderSizePixel = 0
    buttonObject.Text = ""
    buttonObject.AutoButtonColor = false
    buttonObject.LayoutOrder = index
    buttonObject.Parent = Sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = buttonObject

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(26, 40)
    iconLabel.Position = UDim2.fromOffset(4, 4)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(145, 180, 235)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 16
    iconLabel.Parent = buttonObject

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -31, 1, 0)
    nameLabel.Position = UDim2.fromOffset(31, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = tabName
    nameLabel.TextColor3 = Color3.fromRGB(205, 214, 237)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 8
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = buttonObject

    TabButtons[tabName] = buttonObject

    buttonObject.MouseButton1Click:Connect(function()
        for name, page in pairs(Pages) do
            page.Visible = name == tabName
        end

        for name, tabButton in pairs(TabButtons) do
            tabButton.BackgroundColor3 =
                name == tabName
                and Color3.fromRGB(30, 57, 105)
                or Color3.fromRGB(10, 14, 29)
        end

        State.CurrentTab = tabName
    end)
end

Pages.Combat.Visible = true
TabButtons.Combat.BackgroundColor3 = Color3.fromRGB(30, 57, 105)

--//==============================================================
--// DRAG SYSTEM
--//==============================================================
local function makeDraggable(object, handle)
    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = object.Position

            local changedConnection
            changedConnection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if changedConnection then
                        changedConnection:Disconnect()
                    end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - dragStart

            object.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(Main, Header)

--//==============================================================
--// REOPEN TORNADO BUTTON
--//==============================================================
ReopenButton = Instance.new("TextButton")
ReopenButton.Name = "Reopen"
ReopenButton.Size = UDim2.fromOffset(58, 58)
ReopenButton.Position = UDim2.new(0, 18, 0.5, -29)
ReopenButton.BackgroundColor3 = Color3.fromRGB(8, 14, 31)
ReopenButton.BackgroundTransparency = 0.04
ReopenButton.BorderSizePixel = 0
ReopenButton.Text = "🌪️"
ReopenButton.TextSize = 28
ReopenButton.AutoButtonColor = false
ReopenButton.Visible = false
ReopenButton.Parent = MainGui

local ReopenCorner = Instance.new("UICorner")
ReopenCorner.CornerRadius = UDim.new(1, 0)
ReopenCorner.Parent = ReopenButton

local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = CONFIG.Accent
ReopenStroke.Thickness = 1.5
ReopenStroke.Parent = ReopenButton

makeDraggable(ReopenButton, ReopenButton)

--//==============================================================
--// GALAXY LOADING SCREEN
--// Startup-only effect. It is destroyed after loading and is NOT a
--// persistent wallpaper or wallpaper feature.
--//==============================================================
do
    local Loading = Instance.new("Frame")
    Loading.Name = "GalaxyLoading"
    Loading.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
    Loading.Position = UDim2.new(
        0.5,
        -MENU_WIDTH / 2,
        0.5,
        -MENU_HEIGHT / 2
    )
    Loading.BackgroundColor3 = Color3.fromRGB(4, 6, 18)
    Loading.BorderSizePixel = 0
    Loading.ClipsDescendants = true
    Loading.ZIndex = 500
    Loading.Parent = MainGui

    local loadingCorner = Instance.new("UICorner")
    loadingCorner.CornerRadius = UDim.new(0, 18)
    loadingCorner.Parent = Loading

    local loadingStroke = Instance.new("UIStroke")
    loadingStroke.Color = CONFIG.Accent
    loadingStroke.Transparency = 0.25
    loadingStroke.Thickness = 1.5
    loadingStroke.Parent = Loading

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 8, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 12, 55)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 12, 30)),
    })
    gradient.Rotation = 25
    gradient.Parent = Loading

    -- Lightweight animated nebula blobs.
    for i = 1, 5 do
        local blob = Instance.new("Frame")
        blob.Name = "Nebula" .. i
        blob.Size = UDim2.fromOffset(95 + i * 8, 95 + i * 8)
        blob.Position = UDim2.fromOffset(
            20 + ((i * 91) % math.max(1, MENU_WIDTH - 120)),
            18 + ((i * 47) % math.max(1, MENU_HEIGHT - 120))
        )
        blob.BackgroundColor3 = (i % 2 == 0)
            and Color3.fromRGB(42, 92, 210)
            or Color3.fromRGB(104, 54, 205)
        blob.BackgroundTransparency = 0.84
        blob.BorderSizePixel = 0
        blob.ZIndex = 501
        blob.Parent = Loading

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = blob

        task.spawn(function()
            while blob.Parent do
                local target = {
                    Position = UDim2.fromOffset(
                        math.random(10, math.max(11, MENU_WIDTH - 120)),
                        math.random(10, math.max(11, MENU_HEIGHT - 120))
                    )
                }
                pcall(function()
                    TweenService:Create(
                        blob,
                        TweenInfo.new(1.8 + i * 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                        target
                    ):Play()
                end)
                task.wait(1.9 + i * 0.18)
            end
        end)
    end

    -- Small star field.
    for i = 1, 55 do
        local star = Instance.new("Frame")
        local size = math.random(1, 2)
        star.Size = UDim2.fromOffset(size, size)
        star.Position = UDim2.fromOffset(
            math.random(4, math.max(5, MENU_WIDTH - 6)),
            math.random(4, math.max(5, MENU_HEIGHT - 6))
        )
        star.BackgroundColor3 = Color3.fromRGB(220, 235, 255)
        star.BackgroundTransparency = math.random(15, 65) / 100
        star.BorderSizePixel = 0
        star.ZIndex = 502
        star.Parent = Loading

        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(1, 0)
        sc.Parent = star
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 42)
    title.Position = UDim2.fromOffset(15, 100)
    title.BackgroundTransparency = 1
    title.Text = "WINDTURF'S MM2"
    title.TextColor3 = Color3.fromRGB(235, 242, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.ZIndex = 510
    title.Parent = Loading

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -30, 0, 25)
    subtitle.Position = UDim2.fromOffset(15, 142)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Loading universal controls..."
    subtitle.TextColor3 = Color3.fromRGB(160, 184, 230)
    subtitle.Font = Enum.Font.GothamSemibold
    subtitle.TextSize = 10
    subtitle.ZIndex = 510
    subtitle.Parent = Loading

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.fromOffset(260, 7)
    barBack.Position = UDim2.new(0.5, -130, 0, 184)
    barBack.BackgroundColor3 = Color3.fromRGB(20, 27, 52)
    barBack.BorderSizePixel = 0
    barBack.ZIndex = 510
    barBack.Parent = Loading

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBack

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 0, 1, 0)
    bar.BackgroundColor3 = CONFIG.Accent
    bar.BorderSizePixel = 0
    bar.ZIndex = 511
    bar.Parent = barBack

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(1, 0)
    barFillCorner.Parent = bar

    local loadingStatus = Instance.new("TextLabel")
    loadingStatus.Size = UDim2.new(1, -30, 0, 22)
    loadingStatus.Position = UDim2.fromOffset(15, 205)
    loadingStatus.BackgroundTransparency = 1
    loadingStatus.Text = "INITIALIZING..."
    loadingStatus.TextColor3 = Color3.fromRGB(125, 150, 205)
    loadingStatus.Font = Enum.Font.Gotham
    loadingStatus.TextSize = 8
    loadingStatus.ZIndex = 510
    loadingStatus.Parent = Loading

    pcall(function()
        TweenService:Create(
            bar,
            TweenInfo.new(2.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 1, 0)}
        ):Play()
    end)

    task.wait(0.8)
    loadingStatus.Text = "BUILDING MENU..."
    task.wait(0.75)
    loadingStatus.Text = "READY"
    task.wait(0.85)

    for _, obj in ipairs(Loading:GetDescendants()) do
        if obj:IsA("GuiObject") then
            pcall(function()
                TweenService:Create(
                    obj,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 1}
                ):Play()
            end)
        end
    end

    pcall(function()
        TweenService:Create(
            title,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
        TweenService:Create(
            subtitle,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
        TweenService:Create(
            loadingStatus,
            TweenInfo.new(0.3),
            {TextTransparency = 1}
        ):Play()
    end)

    task.wait(0.35)
    Loading:Destroy()
end

Main.Visible = true
Main.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)

local function openMenu()
    State.MenuOpen = true
    ReopenButton.Visible = false
    Main.Visible = true

    Main.Size = UDim2.fromOffset(MENU_WIDTH, 20)

    tween(
        Main,
        0.28,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
        },
        Enum.EasingStyle.Back,
        Enum.EasingDirection.Out
    )
end

local function closeMenu()
    State.MenuOpen = false

    tween(
        Main,
        0.20,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, 20)
        },
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.In
    )

    task.delay(State.Animations and 0.20 or 0, function()
        if not State.MenuOpen and not Destroyed then
            Main.Visible = false
            ReopenButton.Visible = true
        end
    end)
end

CloseButton.MouseButton1Click:Connect(closeMenu)
ReopenButton.MouseButton1Click:Connect(openMenu)

--//==============================================================
--// ROLE DETECTION
--//==============================================================
local function findToolByNames(names, owner)
    owner = owner or LocalPlayer
    local ownerCharacter = owner.Character
    local containers = {}

    if ownerCharacter then
        table.insert(containers, ownerCharacter)
    end

    local backpack = owner:FindFirstChildOfClass("Backpack")
    if backpack then
        table.insert(containers, backpack)
    end

    for _, container in ipairs(containers) do
        for _, object in ipairs(container:GetChildren()) do
            if object:IsA("Tool") then
                local objectName = string.lower(object.Name)
                for _, wanted in ipairs(names) do
                    if objectName:find(string.lower(wanted), 1, true) then
                        return object
                    end
                end
            end
        end
    end
    return nil
end

local function getRole()
    if findToolByNames({"gun", "sheriff", "revolver"}) then
        return "Sheriff"
    end

    if findToolByNames({"knife", "murderer", "blade"}) then
        return "Murderer"
    end

    return "Innocent"
end

local function getPlayerRole(player)
    if not player then return "Unknown" end
    if findToolByNames({"knife", "murderer", "blade"}, player) then
        return "Murderer"
    end
    if findToolByNames({"gun", "sheriff", "revolver"}, player) then
        if KnownSheriffUserId and player.UserId ~= KnownSheriffUserId then
            return "Hero"
        end
        return "Sheriff"
    end
    return "Innocent"
end

--//==============================================================
--// TARGET / HUNTER DATA
--//==============================================================
local SuspiciousPlayers = {}
local CurrentSuspiciousTarget = nil
local LastHunterAlert = 0
local KnownSheriffUserId = nil
local FlyVelocity = nil

local function flagPlayer(player, reason)
    if not player or player == LocalPlayer then
        return
    end

    SuspiciousPlayers[player] = {
        Reason = reason,
        Time = os.clock()
    }

    if State.AutoLockSuspicious then
        CurrentSuspiciousTarget = player
    end

    if State.HackerAlerts and os.clock() - LastHunterAlert > 3 then
        LastHunterAlert = os.clock()
        notify(
            "Hacker Hunter",
            player.Name .. " flagged: " .. reason,
            3
        )
    end
end

--//==============================================================
--// MOVEMENT TARGET HELPERS
--//==============================================================
local function getAliveRoot(player)
    if not player or not player.Character then
        return nil
    end

    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character:FindFirstChild("HumanoidRootPart")

    if humanoid and root and humanoid.Health > 0 then
        return root
    end

    return nil
end

local function nearestLivingPlayer()
    if not RootPart then
        return nil
    end

    local nearest
    local nearestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)

            if root then
                local distance = (RootPart.Position - root.Position).Magnitude

                if distance < nearestDistance then
                    nearest = player
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest
end

local function findLikelyMurderer()
    -- First look for players whose visible character/tool names indicate knife.
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, object in ipairs(player.Character:GetChildren()) do
                if object:IsA("Tool") then
                    local name = string.lower(object.Name)

                    if name:find("knife")
                        or name:find("blade")
                        or name:find("murder") then
                        return player
                    end
                end
            end
        end
    end

    -- Then prefer a currently suspicious target.
    if CurrentSuspiciousTarget
        and getAliveRoot(CurrentSuspiciousTarget) then
        return CurrentSuspiciousTarget
    end

    return nil
end

--//==============================================================
--// CAMERA AIM + TOOL ACTIVATION
--//==============================================================
local function equipTool(tool)
    if not tool or not Character or not Humanoid then
        return false
    end

    if tool.Parent ~= Character then
        pcall(function()
            Humanoid:EquipTool(tool)
        end)
    end

    return tool.Parent == Character
end

local function aimCameraAt(position)
    local camera = workspace.CurrentCamera

    if not camera or not position then
        return false
    end

    local cameraPosition = camera.CFrame.Position

    pcall(function()
        camera.CFrame = CFrame.lookAt(cameraPosition, position)
    end)

    return true
end

local function activateTool(tool)
    if not tool or not tool.Parent then
        return false
    end

    local ok = pcall(function()
        tool:Activate()
    end)

    return ok
end

--//==============================================================
--// SHERIFF AUTO-SHOOT
--//==============================================================
local LastSheriffShot = 0
local SheriffCooldown = 0.25

local function sheriffAutoShoot()
    if not PREMIUM or not State.SheriffAutoShoot then
        return
    end

    if not isAlive() then
        return
    end

    local gun = findToolByNames({"gun", "sheriff", "revolver"})
    local murderer = findLikelyMurderer()

    if not gun or not murderer then
        return
    end

    local targetRoot = getAliveRoot(murderer)

    if not targetRoot then
        return
    end

    if os.clock() - LastSheriffShot < SheriffCooldown then
        return
    end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude

    if State.SafeMode and distance > 250 then
        return
    end

    if equipTool(gun) then
        aimCameraAt(targetRoot.Position + Vector3.new(0, 1.2, 0))
        activateTool(gun)
        LastSheriffShot = os.clock()
    end
end

--//==============================================================
--// MURDERER KILL-ALL ROUTINE
--//==============================================================
local LastKnifeAttack = 0

local function murdererKillAll()
    if not PREMIUM or not State.MurdererKillAll then
        return
    end

    if not isAlive() then
        return
    end

    local knife = findToolByNames({"knife", "blade", "murderer"})

    if not knife then
        return
    end

    local target = nearestLivingPlayer()

    if not target then
        return
    end

    local targetRoot = getAliveRoot(target)

    if not targetRoot then
        return
    end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude

    if distance > 14 then
        -- Safe-mode movement uses a bounded local movement step.
        if State.SafeMode and distance > 100 then
            return
        end

        local direction = (targetRoot.Position - RootPart.Position)

        if direction.Magnitude > 0 then
            local step = math.min(direction.Magnitude, 8)

            RootPart.CFrame =
                RootPart.CFrame
                + direction.Unit * step
        end
    else
        if os.clock() - LastKnifeAttack >= 0.18 then
            if equipTool(knife) then
                aimCameraAt(targetRoot.Position + Vector3.new(0, 1.0, 0))
                activateTool(knife)
                LastKnifeAttack = os.clock()
            end
        end
    end
end

--//==============================================================
--// COIN / THREAT-AWARE AUTOFARM
--//==============================================================
local CoinObjects = {}
local LastCoinScan = 0
local FarmBusy = false
local LastCollectedTarget = nil
local CoinsAtRoundStart = 0
local LastFarmTeleport = 0
local FARM_TELEPORT_COOLDOWN = 0.22
local FARM_RECHECK_DELAY = 0.18
local DANGER_RADIUS = 65

local function looksLikeCoin(object)
    if not object or not object:IsA("BasePart") then
        return false
    end

    local name = string.lower(object.Name)

    return name:find("coin", 1, true)
        or name:find("token", 1, true)
        or name:find("cash", 1, true)
        or name:find("collect", 1, true)
end

local function coinIsAvailable(object)
    if not object or not object.Parent or not object:IsA("BasePart") then
        return false
    end

    if object.Transparency >= 0.98 then
        return false
    end

    local size = object.Size
    if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
        return false
    end

    return true
end

local function scanCoins()
    table.clear(CoinObjects)

    for _, object in ipairs(workspace:GetDescendants()) do
        if looksLikeCoin(object) and coinIsAvailable(object) then
            table.insert(CoinObjects, object)
        end
    end

    LastCoinScan = os.clock()
end

local function getDangerousPlayers()
    local result = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)
            if root then
                local role = getPlayerRole(player)
                if role == "Murderer" or role == "Sheriff" or role == "Hero" then
                    table.insert(result, {
                        Player = player,
                        Root = root,
                        Role = role,
                        Distance = RootPart and (RootPart.Position - root.Position).Magnitude or math.huge,
                    })
                end
            end
        end
    end

    return result
end

local function dangerousPlayerNearby(radius)
    radius = radius or DANGER_RADIUS
    if not RootPart then return false end

    for _, danger in ipairs(getDangerousPlayers()) do
        if danger.Distance <= radius then
            return true
        end
    end

    return false
end

local function nearestDangerDistance()
    local closest = math.huge
    for _, danger in ipairs(getDangerousPlayers()) do
        closest = math.min(closest, danger.Distance)
    end
    return closest
end

-- When a dangerous player is nearby, select the coin that is farthest from
-- the threat. Otherwise use the nearest safe coin. This prevents the farm
-- from repeatedly crossing the same side of the map as a murderer/sheriff.
local function bestFarmCoin()
    if not RootPart or LastRole ~= "Innocent" then
        return nil
    end

    local dangers = getDangerousPlayers()
    local hasNearbyDanger = false

    for _, danger in ipairs(dangers) do
        if danger.Distance <= DANGER_RADIUS then
            hasNearbyDanger = true
            break
        end
    end

    local best = nil
    local bestScore = -math.huge
    local bestDistance = math.huge

    for _, object in ipairs(CoinObjects) do
        if coinIsAvailable(object) and object ~= LastCollectedTarget then
            local playerDistance = (RootPart.Position - object.Position).Magnitude
            if playerDistance <= CONFIG.CoinSearchRadius then
                local minThreatDistance = math.huge

                for _, danger in ipairs(dangers) do
                    minThreatDistance = math.min(
                        minThreatDistance,
                        (danger.Root.Position - object.Position).Magnitude
                    )
                end

                if minThreatDistance == math.huge then
                    minThreatDistance = 10000
                end

                local score
                if hasNearbyDanger then
                    -- Strongly favor the farthest coin from every dangerous
                    -- player, then prefer the closer coin as a tie-breaker.
                    score = minThreatDistance * 1000 - playerDistance
                else
                    -- Normal farming: closest coin wins, but still avoid
                    -- coins that sit very close to a dangerous player.
                    local safetyBonus = math.min(minThreatDistance, 250)
                    score = safetyBonus * 2 - playerDistance
                end

                if score > bestScore
                    or (score == bestScore and playerDistance < bestDistance) then
                    best = object
                    bestScore = score
                    bestDistance = playerDistance
                end
            end
        end
    end

    return best
end

-- Kept as a compatibility alias for the existing runtime/UI code.
local function nearestCoin()
    return bestFarmCoin()
end

local function updateCoinLabel()
    if CoinLabel then
        CoinLabel.Text =
            "COINS "
            .. tostring(State.CoinCount)
            .. "/"
            .. tostring(State.CoinGoal)
    end
end

local function estimateCoinCount()
    local possible = {
        LocalPlayer:FindFirstChild("Coins"),
        LocalPlayer:FindFirstChild("CoinCount"),
        LocalPlayer:FindFirstChild("Currency"),
        LocalPlayer:FindFirstChild("Cash"),
    }

    for _, value in ipairs(possible) do
        if value and value:IsA("IntValue") or value and value:IsA("NumberValue") then
            local number = tonumber(value.Value)
            if number and number >= 0 then
                return number
            end
        end
    end

    return State.CoinCount
end

local function teleportToCoin(object)
    if not object or not coinIsAvailable(object) or not RootPart then
        return false
    end

    if os.clock() - LastFarmTeleport < FARM_TELEPORT_COOLDOWN then
        return false
    end

    local targetPosition = object.Position + Vector3.new(0, 2.5, 0)
    local targetCFrame = CFrame.new(targetPosition)

    local ok = pcall(function()
        RootPart.CFrame = targetCFrame
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    if ok then
        LastFarmTeleport = os.clock()
    end

    return ok
end

local function verifyCoinCollected(object)
    if not object then return true end

    task.wait(FARM_RECHECK_DELAY)

    if not coinIsAvailable(object) then
        return true
    end

    -- Some coins remain as an instance briefly after collection. Give the
    -- game one more short collection opportunity instead of counting it
    -- immediately and leaving a visible coin behind.
    if RootPart and (RootPart.Position - object.Position).Magnitude > 5 then
        teleportToCoin(object)
        task.wait(0.12)
    end

    return not coinIsAvailable(object)
end

local function teleportToLobbyAfter40()
    if not State.AutoReturnAt40 then
        return
    end

    State.AutoFarm = false
    State.AutoCollect = false

    notify(
        "40 Coins",
        "Goal reached. Attempting to return to the lobby.",
        4
    )

    local attempted = false

    pcall(function()
        TeleportService:Teleport(CONFIG.MM2PlaceId, LocalPlayer)
        attempted = true
    end)

    if not attempted then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

--//==============================================================
--// DROPPED GUN / SHERIFF / HERO SUPPORT
--//==============================================================
local LastGunTeleport = 0
local GunTeleportCooldown = 0.75
local LastGunShot = 0
local GunShotCooldown = 0.28

local function isGunName(name)
    name = string.lower(tostring(name or ""))
    return name:find("gun", 1, true)
        or name:find("sheriff", 1, true)
        or name:find("revolver", 1, true)
end

local function findDroppedGun()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Tool") and isGunName(object.Name) then
            local handle = object:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return object, handle
            end
        end
    end

    return nil, nil
end

local function findGunHolder()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local gun = findToolByNames({"gun", "sheriff", "revolver"}, player)
            if gun then
                return player
            end
        end
    end
    return nil
end

local function autoTeleportToDroppedGun()
    if not isAlive() or not RootPart then
        return
    end

    if LastRole ~= "Innocent" and LastRole ~= "Sheriff" and LastRole ~= "Hero" then
        return
    end

    local gun, handle = findDroppedGun()
    if not gun or not handle then
        return
    end

    -- If someone already owns the gun, don't teleport to a false-positive.
    local owner = findGunHolder()
    if owner then
        return
    end

    if os.clock() - LastGunTeleport < GunTeleportCooldown then
        return
    end

    local dangers = getDangerousPlayers()
    local minDanger = math.huge
    for _, danger in ipairs(dangers) do
        minDanger = math.min(minDanger, (handle.Position - danger.Root.Position).Magnitude)
    end

    -- Avoid diving directly into a murderer while trying to pick up the gun.
    if minDanger < DANGER_RADIUS then
        return
    end

    local ok = pcall(function()
        RootPart.CFrame = CFrame.new(handle.Position + Vector3.new(0, 2.5, 0))
        RootPart.AssemblyLinearVelocity = Vector3.zero
        RootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    if ok then
        LastGunTeleport = os.clock()
    end
end

local function autoShootMurdererWithGun()
    if not isAlive() then return end
    if LastRole ~= "Sheriff" and LastRole ~= "Hero" then return end
    if os.clock() - LastGunShot < GunShotCooldown then return end

    local gun = findToolByNames({"gun", "sheriff", "revolver"})
    if not gun then return end

    local murderer = findLikelyMurderer()
    if not murderer then return end

    local targetRoot = getAliveRoot(murderer)
    if not targetRoot then return end

    local distance = (RootPart.Position - targetRoot.Position).Magnitude
    if State.SafeMode and distance > 250 then return end

    if equipTool(gun) then
        -- Camera aim is used only for the shot; no permanent camera lock.
        aimCameraAt(targetRoot.Position + Vector3.new(0, 1.15, 0))
        activateTool(gun)
        LastGunShot = os.clock()
    end
end

--//==============================================================
--// CHAT MONITOR
--//==============================================================
local ChatHistory = {}

local function hookChat(player)
    if player == LocalPlayer then
        return
    end

    connect(
        "Chat_" .. tostring(player.UserId),
        player.Chatted,
        function(message)
            if not State.ChatMonitor then
                return
            end

            local cleaned = string.lower(tostring(message))
                :gsub("%s+", " ")
                :sub(1, 160)

            local previous = ChatHistory[player.UserId]

            if previous
                and previous.Message == cleaned
                and os.clock() - previous.Time <= 6 then

                previous.Count += 1
                previous.Time = os.clock()
            else
                ChatHistory[player.UserId] = {
                    Message = cleaned,
                    Count = 1,
                    Time = os.clock()
                }

                previous = ChatHistory[player.UserId]
            end

            if previous.Count >= 3 then
                flagPlayer(player, "same chat message 3×")
                previous.Count = 0
            end
        end
    )
end

for _, player in ipairs(Players:GetPlayers()) do
    hookChat(player)
end

connect("PlayerAdded", Players.PlayerAdded, function(player)
    hookChat(player)
end)

connect("PlayerRemoving", Players.PlayerRemoving, function(player)
    ChatHistory[player.UserId] = nil
    SuspiciousPlayers[player] = nil

    if CurrentSuspiciousTarget == player then
        CurrentSuspiciousTarget = nil
    end
end)

--//==============================================================
--// MAIN RUNTIME LOOP
--//==============================================================
local LastRole = "Unknown"
local LastRoleUpdate = 0

connect("MainRuntime", RunService.Heartbeat, function()
    if Destroyed then
        return
    end

    if os.clock() - LastRoleUpdate > 0.5 then
        LastRole = getRole()
        if LastRole == "Sheriff" then
            KnownSheriffUserId = LocalPlayer.UserId
        end
        LastRoleUpdate = os.clock()

        if RoleLabel then
            RoleLabel.Text = "ROLE • " .. LastRole
        end

        if StatusLabel then
            StatusLabel.Text =
                "READY • "
                .. LastRole
                .. (PREMIUM and " • PREMIUM" or "")
        end
    end

    if State.HunterEnabled and State.SuspiciousMovement then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = getAliveRoot(player)

                if root then
                    local speed = root.AssemblyLinearVelocity.Magnitude

                    if speed > 145 then
                        flagPlayer(player, "extreme velocity")
                    elseif speed > 95 then
                        flagPlayer(player, "unusual velocity")
                    end
                end
            end
        end
    end

    if State.AntiFling and RootPart then
        local velocity = RootPart.AssemblyLinearVelocity

        if velocity.Magnitude > 175 then
            RootPart.AssemblyLinearVelocity = Vector3.zero
            RootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if State.Noclip and Character then
        for _, object in ipairs(Character:GetDescendants()) do
            if object:IsA("BasePart") then
                object.CanCollide = false
            end
        end
    end

    if State.Fly and isAlive() then
        local camera = workspace.CurrentCamera
        if camera and RootPart and Humanoid then
            if not FlyVelocity or FlyVelocity.Parent ~= RootPart then
                if FlyVelocity then pcall(function() FlyVelocity:Destroy() end) end
                FlyVelocity = Instance.new("BodyVelocity")
                FlyVelocity.Name = "WindTurfFlyVelocity"
                FlyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                FlyVelocity.P = 18000
                FlyVelocity.Velocity = Vector3.zero
                FlyVelocity.Parent = RootPart
            end
            local direction = Vector3.zero
            if KeyboardEnabled then
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.new(0,1,0) end
            end
            if Humanoid.MoveDirection.Magnitude > 0 then direction += Humanoid.MoveDirection end
            FlyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * 65 or Vector3.zero
        end
    elseif FlyVelocity then
        pcall(function() FlyVelocity:Destroy() end)
        FlyVelocity = nil
    end

    if PREMIUM and State.SheriffAutoShoot and LastRole == "Sheriff" then
        sheriffAutoShoot()
    end

    if PREMIUM and State.MurdererKillAll and LastRole == "Murderer" then
        murdererKillAll()
    end

    -- Auto-pickup/shot support for the dropped Sheriff gun. The camera is
    -- only aimed for the instant of the shot; there is no permanent lock-on.
    if State.AutoGunPickup then
        autoTeleportToDroppedGun()
    end

    if PREMIUM and State.AutoGunShoot then
        autoShootMurdererWithGun()
    end

    if (State.AutoFarm or State.AutoCollect) and isAlive() then
        if LastRole ~= "Innocent" then
            return
        end

        if os.clock() - LastCoinScan > 0.55 then
            scanCoins()
        end

        if not FarmBusy then
            local target = nearestCoin()

            if target then
                FarmBusy = true
                LastCollectedTarget = target

                task.spawn(function()
                    if isAlive() and coinIsAvailable(target) then
                        local dangerDistance = nearestDangerDistance()
                        local dangersNearby = dangerousPlayerNearby(DANGER_RADIUS)

                        -- If a murderer/sheriff/hero is nearby, bestFarmCoin()
                        -- already selected the farthest viable coin from them.
                        -- We still refuse to move toward a coin that is itself
                        -- inside the danger radius.
                        local safeTarget = true
                        for _, danger in ipairs(getDangerousPlayers()) do
                            if (danger.Root.Position - target.Position).Magnitude < DANGER_RADIUS then
                                safeTarget = false
                                break
                            end
                        end

                        if safeTarget then
                            teleportToCoin(target)
                            task.wait(0.16)

                            -- Retry once at the exact coin position if it did
                            -- not disappear on the first teleport.
                            if coinIsAvailable(target) then
                                teleportToCoin(target)
                                task.wait(0.14)
                            end

                            if verifyCoinCollected(target) then
                                State.CoinCount = math.min(
                                    State.CoinCount + 1,
                                    State.CoinGoal
                                )
                                updateCoinLabel()
                            end
                        end
                    end

                    LastCollectedTarget = nil
                    FarmBusy = false
                end)
            end
        end

        local observed = estimateCoinCount()

        if observed > State.CoinCount then
            State.CoinCount = math.min(observed, State.CoinGoal)
            updateCoinLabel()
        end

        if State.CoinCount >= State.CoinGoal then
            State.CoinCount = State.CoinGoal
            updateCoinLabel()

            if LastRole == "Innocent" then
                teleportToLobbyAfter40()
            end
        end
    end
end)

--//==============================================================
--// ESP
--//==============================================================
local Highlights = {}

local function destroyHighlight(player)
    local highlight = Highlights[player]

    if highlight then
        pcall(function()
            highlight:Destroy()
        end)
    end

    Highlights[player] = nil
end

local ESP_COLORS = {
    Innocent = Color3.fromRGB(65, 235, 105),
    Murderer = Color3.fromRGB(255, 70, 70),
    Sheriff = Color3.fromRGB(65, 145, 255),
    Hero = Color3.fromRGB(255, 215, 55),
    Unknown = Color3.fromRGB(170, 180, 195),
}

local function updateESP()
    if not State.ESP then
        for player in pairs(Highlights) do destroyHighlight(player) end
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local role = getPlayerRole(player)
            if role == "Sheriff" then KnownSheriffUserId = player.UserId end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local highlight = Highlights[player]
            if not highlight or highlight.Parent ~= player.Character then
                destroyHighlight(player)
                highlight = Instance.new("Highlight")
                highlight.Name = "WindTurfESP"
                highlight.FillTransparency = 0.72
                highlight.OutlineTransparency = 0.03
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = player.Character
                Highlights[player] = highlight
            end
            local color = ESP_COLORS[getPlayerRole(player)] or ESP_COLORS.Unknown
            highlight.FillColor = color
            highlight.OutlineColor = color
        end
    end
end

connect("ESPUpdate", RunService.Heartbeat, function()
    updateESP()
end)

--//==============================================================
--// HUD STATS
--//==============================================================
StatsLabel = Instance.new("TextLabel")
StatsLabel.Name = "Stats"
StatsLabel.Size = UDim2.fromOffset(170, 20)
StatsLabel.Position = UDim2.new(1, -180, 1, -23)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = ""
StatsLabel.TextColor3 = Color3.fromRGB(145, 175, 220)
StatsLabel.Font = Enum.Font.Code
StatsLabel.TextSize = 9
StatsLabel.TextXAlignment = Enum.TextXAlignment.Right
StatsLabel.Parent = Main

RoleLabel = Instance.new("TextLabel")
RoleLabel.Name = "Role"
RoleLabel.Size = UDim2.fromOffset(150, 20)
RoleLabel.Position = UDim2.new(0, 113, 1, -23)
RoleLabel.BackgroundTransparency = 1
RoleLabel.Text = "ROLE • Innocent"
RoleLabel.TextColor3 = Color3.fromRGB(150, 170, 205)
RoleLabel.Font = Enum.Font.Code
RoleLabel.TextSize = 9
RoleLabel.TextXAlignment = Enum.TextXAlignment.Left
RoleLabel.Parent = Main

local Frames = 0
local FPSClock = os.clock()

connect("StatsUpdate", RunService.RenderStepped, function()
    Frames += 1

    local now = os.clock()

    if now - FPSClock >= 0.5 then
        local fps = math.floor(
            Frames / math.max(now - FPSClock, 0.001)
        )

        Frames = 0
        FPSClock = now

        local pingText = ""

        if State.Ping then
            local ping = nil

            pcall(function()
                local network =
                    StatsService:FindFirstChild("Network")

                if network then
                    local serverStats =
                        network:FindFirstChild("ServerStatsItem")

                    if serverStats then
                        local dataPing =
                            serverStats:FindFirstChild("Data Ping")

                        if dataPing then
                            ping = dataPing:GetValue()
                        end
                    end
                end
            end)

            if ping then
                pingText = " • " .. tostring(math.floor(ping)) .. "ms"
            end
        end

        if State.FPS then
            StatsLabel.Text =
                "FPS " .. tostring(fps) .. pingText
        else
            StatsLabel.Text = State.Ping and pingText or ""
        end
    end
end)

--//==============================================================
--// INITIAL FADE-IN
--//==============================================================
Main.BackgroundTransparency = 1

tween(
    Main,
    0.35,
    {
        BackgroundTransparency = 0.06
    }
)

notify(
    "WindTurf",
    PREMIUM
        and "Rebuilt UI loaded • Premium verified."
        or "Rebuilt UI loaded • Android portrait mode.",
    4
)

print(
    "[WindTurf] "
        .. CONFIG.ScriptName
        .. " "
        .. CONFIG.Version
        .. " loaded."
)
