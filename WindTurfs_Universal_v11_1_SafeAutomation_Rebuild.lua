-- LANDSCAPE GAME-MODE / COMPACT MENU
-- SMALL MENU / MENU-ONLY WALLPAPER PATCH
--[[
    WINDTURF MM2 / UNIVERSAL SCRIPT - COMBINED BUILD
]]

--[[
    WINDTURF'S MM2 / UNIVERSAL SCRIPT
    Android Landscape UI • Galaxy Startup Loading Only
    v11.1 Feature Rebuild

    IMPORTANT:
    • This file is client-side and depends on the executor/runtime exposing
      normal Roblox Lua APIs.
    • The MM2 role/combat routines use Tool:Activate and camera aiming rather
      than assuming private RemoteEvent names, because those names can change.
    • Premium names are local UI gating, not secure server authorization.

    Main features:
      Combat       - Anti-Fling, normal movement helpers, role awareness
      Autofarm     - Coin scan, 40-coin round counter, pathfinding-based collection
      Hunter       - Suspicious movement, chat repeat detector, target tracking
      Visuals      - ESP, distance, FPS, ping
      Settings     - animations, safe mode, compactness, auto-stop
      Misc         - recenter, reset, emergency stop, unload
      Troll        - Prison Life safe movement / trolling tools
      Universal    - Local Ghost, environment tools, movement reset
      Update       - Version, patch notes, roadmap and future loader panel
]]

--//==============================================================
--// SERVICES
--//==============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
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

local existingGui = nil
pcall(function()
    local coreGui = game:GetService("CoreGui")
    existingGui = coreGui:FindFirstChild("WindTurfMM2_Rebuilt")
end)

-- Only block duplicate loads when a real GUI from the previous instance still exists.
-- This prevents a failed/partial startup from permanently locking the loader.
if ENV.WindTurfMM2_RebuiltLoaded and existingGui then
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
local SOURCE_REVISION = "Universal_RedGalaxy_v11_1_SafeAutomation_Rebuild"

local CONFIG = {
    ScriptName = "WindTurf's Universal Script",
    Version = "v11.1 Feature Rebuild",

    -- Paste the newest public loader here when a release is published.
    -- Kept empty until the update system is connected to the final release URL.
    UpdateLoadstring = "",
    PlannedKeySystemDate = "TBD",

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
        ["ellabellabean45"] = true,
        ["sleet_binary"] = true,
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
local applyGhostVisual
local showSpinWarning

local State = {
    MenuOpen = true,
    CurrentTab = "Combat",

    -- Prison Life safe movement / trolling
    PLWalkSpeed = false,
    PLWalkSpeedValue = 28,
    PLInfiniteJump = false,
    PLSpin = false,
    PLCrouchSpeed = false,
    PLFly = false,
    AutoArrest = false,
    PLWalkSpeedMax = 200,
    PLSpinSpeed = 90,
    Ghost = false,
    GhostTransparency = 1,
    NDSWalkSpeed = false,
    NDSWalkSpeedValue = 32,
    NDSInfiniteJump = false,
    NDSNoclip = false,
    NDSSpin = false,
    NDSSpinSpeed = 45,
    NDSLowGravity = false,

    -- Combat
    AntiFling = true,
    Fly = false,
    Noclip = false,

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

    -- Crosshair
    CrosshairEnabled = false,
    CrosshairSpin = true,
    CrosshairSize = 22,
    CrosshairColor = "Cyan",
    CrosshairDesign = 1,

    -- Live path-map diagram
    PathDiagram = true,
    PathDiagramCoins = true,
    PathDiagramDanger = true,
    PathDiagramObstacles = true,
    PathDiagramPlayers = true,

    -- Persistent local profile
    LifetimeCoins = 0,
    Sessions = 0,
    __Radar = false,
    __Threats = false,
    __Proximity = false,
    __Roles = false,
    __NDSGuidance = false,
    __Shelter = false,
    __Hazard = false,
    __Fall = false,
    __NDSPlayers = false,
    __Storm = false,
    __PLRole = false,
    __Wanted = false,
    __Taser = false,
    __Arrest = false,
    __Weapons = false,
    __PLMarkers = false,
    __Breadcrumb = false,
    __Smart = false,
    __Orbit = false,
    __FreeCam = false,
    __BreadcrumbU = false,
}

--//==============================================================
--// LOCAL PERSISTENCE
--//==============================================================
-- Executor file APIs are used when available. Roblox DataStoreService is
-- server-only, so a client/executor script cannot use Roblox DataStores
-- for its own persistent settings or badges.
local SAVE_FILE = "WindTurf_MM2_PathFarm_Settings.json"

local PERSIST_KEYS = {
    "AntiFling", "Fly", "Noclip",
    "AutoFarm", "AutoCollect", "AutoReturnAt40",
    "HunterEnabled", "HackerAlerts", "SuspiciousMovement", "ChatMonitor",
    "AutoLockSuspicious", "ESP", "Distance", "FPS", "Ping",
    "Animations", "SafeMode", "Compact", "RejoinAfterDeath",
    "CrosshairEnabled", "CrosshairSpin", "CrosshairSize",
    "CrosshairColor", "CrosshairDesign",
    "PathDiagram", "PathDiagramCoins", "PathDiagramDanger", "PathDiagramObstacles", "PathDiagramPlayers",
    "LifetimeCoins", "Sessions",
    "PLWalkSpeed", "PLWalkSpeedValue", "PLInfiniteJump", "PLSpin", "PLCrouchSpeed", "PLFly", "PLSpinSpeed",
    "Ghost", "GhostTransparency",
    "AutoArrest",
    "NDSWalkSpeed", "NDSWalkSpeedValue", "NDSInfiniteJump", "NDSNoclip", "NDSSpin", "NDSSpinSpeed", "NDSLowGravity",
    "__Radar", "__Threats", "__Proximity", "__Roles", "__NDSGuidance", "__Shelter", "__Hazard", "__Fall", "__NDSPlayers", "__Storm",
    "__PLRole", "__Wanted", "__Taser", "__Arrest", "__Weapons", "__PLMarkers", "__Breadcrumb", "__Smart", "__Orbit", "__FreeCam", "__BreadcrumbU",
}

local BadgesUnlocked = {}
local BadgeRows = {}
local savePersistentData
local unlockBadge
local refreshBadgeRows

local function loadPersistentData()
    local raw

    -- First try the executor's persistent file.
    local ok = pcall(function()
        if readfile and isfile and isfile(SAVE_FILE) then
            raw = readfile(SAVE_FILE)
        elseif readfile then
            -- Some runtimes return an error for a missing file.
            raw = readfile(SAVE_FILE)
        end
    end)

    if (not ok or type(raw) ~= "string" or raw == "") then
        local fallback = ENV.WindTurfMM2_PersistentProfile
        if type(fallback) == "table" then
            local savedState = fallback.State
            if type(savedState) == "table" then
                for _, key in ipairs(PERSIST_KEYS) do
                    if savedState[key] ~= nil then
                        State[key] = savedState[key]
                    end
                end
            end
            if type(fallback.Badges) == "table" then
                for badgeId, unlocked in pairs(fallback.Badges) do
                    BadgesUnlocked[tostring(badgeId)] = unlocked == true
                end
            end
        end
        return
    end

    local decoded
    local decodedOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)

    if not decodedOk or type(decoded) ~= "table" then
        return
    end

    local savedState = decoded.State
    if type(savedState) == "table" then
        for _, key in ipairs(PERSIST_KEYS) do
            if savedState[key] ~= nil and State[key] ~= nil then
                State[key] = savedState[key]
            end
        end
    end

    if type(decoded.Badges) == "table" then
        for badgeId, unlocked in pairs(decoded.Badges) do
            if unlocked == true then
                BadgesUnlocked[tostring(badgeId)] = true
            end
        end
    end
end

savePersistentData = function()
    local payload = {
        Version = 3,
        State = {},
        Badges = {},
    }

    for _, key in ipairs(PERSIST_KEYS) do
        payload.State[key] = State[key]
    end

    for badgeId, unlocked in pairs(BadgesUnlocked) do
        if unlocked then
            payload.Badges[tostring(badgeId)] = true
        end
    end

    local encoded
    local encodeOk = pcall(function()
        encoded = HttpService:JSONEncode(payload)
    end)

    if not encodeOk or type(encoded) ~= "string" then
        return false
    end

    local writeOk = pcall(function()
        if writefile then
            writefile(SAVE_FILE, encoded)
        else
            error("writefile unavailable")
        end
    end)

    -- Also keep a session fallback if the runtime has no file API.
    local envOk = pcall(function()
        local env = getGlobal()
        env.WindTurfMM2_PersistentProfile = payload
    end)

    return writeOk or envOk
end

loadPersistentData()

State.Sessions = (tonumber(State.Sessions) or 0) + 1

unlockBadge = function(badgeId)
    badgeId = tostring(badgeId)

    if BadgesUnlocked[badgeId] then
        return false
    end

    BadgesUnlocked[badgeId] = true

    if refreshBadgeRows then
        pcall(refreshBadgeRows)
    end

    pcall(savePersistentData)
    return true
end


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
local RoundCurrencyBaseline = nil
local RoundStarted = false
local LobbyTeleportStarted = false
local NoclipOriginalCollision = {}
local RoleLabel
local StatusLabel
local FarmDebugPanel
local FarmDebugStatus
local FarmDebugCoins
local FarmDebugTarget
local FarmDebugTargetDistance
local FarmDebugThreatDistance
local FarmDebugPhase

-- Live Path Map UI / data
local PathMapCanvas
local PathMapStatus
local PathMapTarget
local LivePathWaypoints = nil
local LivePathTarget = nil
local LivePathTimestamp = 0

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
    for object, original in pairs(NoclipOriginalCollision or {}) do
        if object and object.Parent then
            pcall(function() object.CanCollide = original end)
        end
    end
    table.clear(NoclipOriginalCollision or {})

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
    RoundCurrencyBaseline = nil
    RoundStarted = false
    LobbyTeleportStarted = false
    State.CoinCount = 0
    updateCoinLabel()

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

-- Persistent starter badges.
unlockBadge("1") -- Welcome to WindTurf
unlockBadge("13") -- First Load
unlockBadge("15") -- Galaxy Traveler

if PREMIUM then
    unlockBadge("20") -- Welcome to Premium
end

if (tonumber(State.Sessions) or 0) >= 5 then
    unlockBadge("18") -- Loyal Player
end

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

pcall(function()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local old = playerGui and playerGui:FindFirstChild("WindTurfMM2_Rebuilt")
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

local function attachGuiSafely(gui)
    local candidates = {}
    local ok, preferred = pcall(getGuiParent)
    if ok and preferred then
        table.insert(candidates, preferred)
    end

    pcall(function()
        local coreGui = game:GetService("CoreGui")
        if coreGui and coreGui ~= preferred then
            table.insert(candidates, coreGui)
        end
    end)

    pcall(function()
        local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if playerGui and playerGui ~= preferred then
            table.insert(candidates, playerGui)
        end
    end)

    for _, parent in ipairs(candidates) do
        local success = pcall(function()
            gui.Parent = parent
        end)
        if success and gui.Parent == parent then
            return true
        end
    end

    return false
end

if not attachGuiSafely(MainGui) then
    ENV.WindTurfMM2_RebuiltLoaded = nil
    error("WindTurf could not attach its ScreenGui to CoreGui or PlayerGui.")
end

--//==============================================================
--// MAIN WINDOW / WINDTURF RED-GALAXY UI
--//==============================================================
Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT)
Main.Position = UDim2.new(0.5, -MENU_WIDTH / 2, 0.5, -MENU_HEIGHT / 2)
Main.BackgroundColor3 = Color3.fromRGB(4, 5, 10)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Visible = false
Main.ZIndex = 100
Main.Parent = MainGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 15)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 28, 58)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.05
MainStroke.Parent = Main

-- Subtle red/black galaxy field inside the menu.
local GalaxyField = Instance.new("Frame")
GalaxyField.Name = "GalaxyField"
GalaxyField.Size = UDim2.fromScale(1, 1)
GalaxyField.BackgroundColor3 = Color3.fromRGB(4, 5, 11)
GalaxyField.BorderSizePixel = 0
GalaxyField.ZIndex = 100
GalaxyField.Parent = Main

local GalaxyGradient = Instance.new("UIGradient")
GalaxyGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 4, 13)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(5, 5, 12)),
    ColorSequenceKeypoint.new(0.72, Color3.fromRGB(14, 3, 9)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 4, 9)),
})
GalaxyGradient.Rotation = 12
GalaxyGradient.Parent = GalaxyField

for i = 1, 42 do
    local star = Instance.new("Frame")
    star.Name = "Star" .. i
    local size = (i % 7 == 0) and 2 or 1
    star.Size = UDim2.fromOffset(size, size)
    star.Position = UDim2.new((i * 37 % 97) / 100, 0, (i * 61 % 91) / 100, 0)
    star.BackgroundColor3 = (i % 5 == 0)
        and Color3.fromRGB(255, 90, 115)
        or Color3.fromRGB(150, 165, 205)
    star.BackgroundTransparency = (i % 4 == 0) and 0.2 or 0.55
    star.BorderSizePixel = 0
    star.ZIndex = 101
    star.Parent = GalaxyField
end

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = Color3.fromRGB(8, 5, 11)
Header.BackgroundTransparency = 0.03
Header.BorderSizePixel = 0
Header.ZIndex = 110
Header.Parent = Main

local HeaderGradient = Instance.new("UIGradient")
HeaderGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 3, 9)),
    ColorSequenceKeypoint.new(0.48, Color3.fromRGB(5, 4, 10)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(23, 3, 11)),
})
HeaderGradient.Rotation = 0
HeaderGradient.Parent = Header

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Color3.fromRGB(255, 24, 53)
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 111
HeaderLine.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.fromOffset(185, 27)
Title.Position = UDim2.fromOffset(13, 3)
Title.BackgroundTransparency = 1
Title.Text = "WINDTURF"
Title.TextColor3 = Color3.fromRGB(255, 35, 61)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = IsMobile and 22 or 26
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 112
Title.Parent = Header

local UniversalLabel = Instance.new("TextLabel")
UniversalLabel.Size = UDim2.fromOffset(150, 15)
UniversalLabel.Position = UDim2.fromOffset(38, 29)
UniversalLabel.BackgroundTransparency = 1
UniversalLabel.Text = "U N I V E R S A L"
UniversalLabel.TextColor3 = Color3.fromRGB(235, 235, 242)
UniversalLabel.Font = Enum.Font.GothamBold
UniversalLabel.TextSize = 8
UniversalLabel.TextXAlignment = Enum.TextXAlignment.Left
UniversalLabel.ZIndex = 112
UniversalLabel.Parent = Header

local CreatorLabel = Instance.new("TextLabel")
CreatorLabel.Size = UDim2.fromOffset(140, 20)
CreatorLabel.Position = UDim2.new(0.5, -70, 0, 16)
CreatorLabel.BackgroundTransparency = 1
CreatorLabel.Text = "Made by WindTurf"
CreatorLabel.TextColor3 = Color3.fromRGB(190, 195, 215)
CreatorLabel.Font = Enum.Font.GothamSemibold
CreatorLabel.TextSize = 9
CreatorLabel.TextXAlignment = Enum.TextXAlignment.Center
CreatorLabel.ZIndex = 112
CreatorLabel.Parent = Header

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "Minimize"
MinimizeButton.Size = UDim2.fromOffset(30, 30)
MinimizeButton.Position = UDim2.new(1, -72, 0, 12)
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Text = "—"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 38, 62)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 23
MinimizeButton.AutoButtonColor = false
MinimizeButton.ZIndex = 113
MinimizeButton.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "Close"
CloseButton.Size = UDim2.fromOffset(32, 32)
CloseButton.Position = UDim2.new(1, -38, 0, 11)
CloseButton.BackgroundColor3 = Color3.fromRGB(17, 5, 11)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(255, 40, 63)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 24
CloseButton.AutoButtonColor = false
CloseButton.ZIndex = 113
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton
local CloseStroke = Instance.new("UIStroke")
CloseStroke.Color = Color3.fromRGB(255, 25, 55)
CloseStroke.Transparency = 0.2
CloseStroke.Parent = CloseButton

local StatusStrip = Instance.new("Frame")
StatusStrip.Name = "StatusStrip"
StatusStrip.Size = UDim2.new(1, -108, 0, 22)
StatusStrip.Position = UDim2.fromOffset(99, 59)
StatusStrip.BackgroundColor3 = Color3.fromRGB(7, 8, 15)
StatusStrip.BorderSizePixel = 0
StatusStrip.ZIndex = 108
StatusStrip.Parent = Main
local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 7)
StatusCorner.Parent = StatusStrip
local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Color3.fromRGB(75, 22, 37)
StatusStroke.Transparency = 0.2
StatusStroke.Parent = StatusStrip

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -85, 1, 0)
StatusLabel.Position = UDim2.fromOffset(8, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "READY • scanning role..."
StatusLabel.TextColor3 = Color3.fromRGB(185, 192, 215)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 7
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 109
StatusLabel.Parent = StatusStrip

CoinLabel = Instance.new("TextLabel")
CoinLabel.Size = UDim2.fromOffset(72, 22)
CoinLabel.Position = UDim2.new(1, -78, 0, 0)
CoinLabel.BackgroundTransparency = 1
CoinLabel.Text = "COINS 0/40"
CoinLabel.TextColor3 = Color3.fromRGB(255, 48, 74)
CoinLabel.Font = Enum.Font.GothamBold
CoinLabel.TextSize = 7
CoinLabel.TextXAlignment = Enum.TextXAlignment.Right
CoinLabel.ZIndex = 109
CoinLabel.Parent = StatusStrip

-- Sidebar: same compact width/overall menu size, but styled like the reference.
Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 82, 1, -72)
Sidebar.Position = UDim2.fromOffset(9, 62)
Sidebar.BackgroundColor3 = Color3.fromRGB(5, 7, 13)
Sidebar.BackgroundTransparency = 0.08
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 2
Sidebar.ScrollBarImageColor3 = Color3.fromRGB(255, 35, 60)
Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new()
Sidebar.ZIndex = 107
Sidebar.Parent = Main
local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 11)
SidebarCorner.Parent = Sidebar
local SidebarStroke = Instance.new("UIStroke")
SidebarStroke.Color = Color3.fromRGB(58, 19, 31)
SidebarStroke.Transparency = 0.25
SidebarStroke.Parent = Sidebar
local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar
local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 5)
SidebarPadding.PaddingLeft = UDim.new(0, 4)
SidebarPadding.PaddingRight = UDim.new(0, 4)
SidebarPadding.PaddingBottom = UDim.new(0, 5)
SidebarPadding.Parent = Sidebar

local SidebarBrand = Instance.new("TextLabel")
SidebarBrand.Size = UDim2.new(1, -8, 0, 17)
SidebarBrand.BackgroundTransparency = 1
SidebarBrand.Text = "W  /  v11"
SidebarBrand.TextColor3 = Color3.fromRGB(255, 55, 78)
SidebarBrand.Font = Enum.Font.GothamBlack
SidebarBrand.TextSize = 8
SidebarBrand.LayoutOrder = -1
SidebarBrand.ZIndex = 108
SidebarBrand.Parent = Sidebar

Pages = {}
local TabButtons = {}

local TabInfo = {
    {"Combat", "⌂", "HOME"},
    {"Autofarm", "⚒", "AUTO FARM"},
    {"Hunter", "●", "PLAYER"},
    {"Visuals", "◉", "VISUALS"},
    {"Map", "⌖", "TELEPORT"},
    {"GameTools", "♣", "GAME TOOLS"},
    {"Troll", "☠", "TROLL"},
    {"Emotes", "☺", "EMOTES"},
    {"Crosshairs", "+", "CROSSHAIR"},
    {"Badges", "★", "BADGES"},
    {"Settings", "⚙", "SETTINGS"},
    {"Misc", "☷", "MISC"},
    {"Universal", "∞", "UNIVERSAL"},
    {"Update", "↻", "UPDATE"},
    {"Premium", "★", "PREMIUM"},
    {"NDS", "☁", "NDS"},
    {"Prison", "♜", "PRISON"},
    {"Radar", "◎", "RADAR"},
    {"Routes", "➤", "ROUTES"},
    {"Inspector", "ⓘ", "INSPECTOR"},
}

local PageArea = Instance.new("Frame")
PageArea.Name = "PageArea"
PageArea.Size = UDim2.new(1, -101, 1, -91)
PageArea.Position = UDim2.fromOffset(95, 86)
PageArea.BackgroundTransparency = 1
PageArea.ZIndex = 106
PageArea.Parent = Main

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
page.Active = true
page.ScrollingEnabled = true
    page.ScrollBarImageColor3 = Color3.fromRGB(255, 34, 60)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.ZIndex = 106
    page.Parent = PageArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 1)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = page

    Pages[name] = page
    return page
end

for _, info in ipairs(TabInfo) do
    createPage(info[1])
end

local function section(page, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -5, 0, 24)
    label.BackgroundColor3 = Color3.fromRGB(9, 8, 15)
    label.BackgroundTransparency = 0.12
    label.Text = "  " .. string.upper(text)
    label.TextColor3 = Color3.fromRGB(255, 60, 82)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BorderSizePixel = 0
    label.Parent = page
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = label
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(83, 21, 37)
    st.Transparency = 0.35
    st.Parent = label
    return label
end

local function toggle(page, name, description, stateKey, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 45)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BackgroundTransparency = 0.03
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder

    local accent = Instance.new("Frame")
    accent.Size = UDim2.fromOffset(3, 25)
    accent.Position = UDim2.fromOffset(6, 10)
    accent.BackgroundColor3 = Color3.fromRGB(255, 35, 60)
    accent.BorderSizePixel = 0
    accent.Parent = holder
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(1, 0)
    ac.Parent = accent

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -67, 0, 18)
    nameLabel.Position = UDim2.fromOffset(15, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(235, 238, 248)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 9
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -67, 0, 16)
    descLabel.Position = UDim2.fromOffset(15, 23)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(128, 137, 162)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 6.5
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = holder

    local switch = Instance.new("Frame")
    switch.Size = UDim2.fromOffset(34, 19)
    switch.Position = UDim2.new(1, -44, 0.5, -9)
    switch.BackgroundColor3 = Color3.fromRGB(24, 29, 43)
    switch.BorderSizePixel = 0
    switch.Parent = holder
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch
    local switchStroke = Instance.new("UIStroke")
    switchStroke.Color = Color3.fromRGB(67, 75, 96)
    switchStroke.Transparency = 0.25
    switchStroke.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(13, 13)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.fromRGB(155, 170, 198)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function refresh()
        local enabled = State[stateKey] == true
        if premiumOnly and not PREMIUM then
            switch.BackgroundColor3 = Color3.fromRGB(43, 19, 48)
            knob.BackgroundColor3 = Color3.fromRGB(175, 90, 190)
            knob.Position = UDim2.fromOffset(3, 3)
            descLabel.Text = "★ Premium feature"
            descLabel.TextColor3 = Color3.fromRGB(214, 120, 225)
            return
        end
        switch.BackgroundColor3 = enabled and Color3.fromRGB(215, 23, 48) or Color3.fromRGB(24, 29, 43)
        knob.BackgroundColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(155, 170, 198)
        tween(knob, 0.12, {Position = enabled and UDim2.fromOffset(18, 3) or UDim2.fromOffset(3, 3)})
    end

    connect("Toggle_" .. page.Name .. "_" .. stateKey .. "_" .. name, holder.MouseButton1Click, function()
        if premiumOnly and not PREMIUM then
            notify("Premium", "Premium access required.", 3)
            return
        end
        State[stateKey] = not State[stateKey]
        if callback then pcall(callback, State[stateKey]) end
        pcall(savePersistentData)
        refresh()
    end)
    refresh()
    return holder
end

local function slider(page, name, description, stateKey, minValue, maxValue, stepValue, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 57)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BorderSizePixel = 0
    holder.Parent = page
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 0, 17)
    title.Position = UDim2.fromOffset(12, 4)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(238, 240, 250)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 8.5
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = holder

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.fromOffset(55, 17)
    valueLabel.Position = UDim2.new(1, -65, 0, 4)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(255, 48, 72)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 8
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = holder

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 12)
    desc.Position = UDim2.fromOffset(12, 20)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(125, 135, 160)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 6
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = holder

    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.fromOffset(22, 12)
    minLabel.Position = UDim2.fromOffset(12, 42)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = tostring(minValue)
    minLabel.TextColor3 = Color3.fromRGB(180, 188, 208)
    minLabel.Font = Enum.Font.Gotham
    minLabel.TextSize = 6
    minLabel.TextXAlignment = Enum.TextXAlignment.Left
    minLabel.Parent = holder

    local maxLabel = minLabel:Clone()
    maxLabel.Position = UDim2.new(1, -34, 0, 42)
    maxLabel.Text = tostring(maxValue)
    maxLabel.TextXAlignment = Enum.TextXAlignment.Right
    maxLabel.Parent = holder

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -62, 0, 6)
    bar.Position = UDim2.fromOffset(34, 45)
    bar.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = holder
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(255, 30, 57)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(11, 11)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 48, 74)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local dragging = false
    local function setValue(value, fire)
        value = math.clamp(tonumber(value) or minValue, minValue, maxValue)
        local step = stepValue or 1
        value = math.floor((value - minValue) / step + 0.5) * step + minValue
        value = math.clamp(value, minValue, maxValue)
        State[stateKey] = value
        local ratio = (value - minValue) / math.max(maxValue - minValue, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueLabel.Text = tostring(math.floor(value))
        if fire and callback then pcall(callback, value) end
    end
    local function fromInput(input)
        local x = input.Position.X
        local left = bar.AbsolutePosition.X
        local width = math.max(bar.AbsoluteSize.X, 1)
        setValue(minValue + (maxValue - minValue) * math.clamp((x - left) / width, 0, 1), true)
        pcall(savePersistentData)
    end
    bar.MouseButton1Down:Connect(function() dragging = true end)
    connect("SliderInputEnded_" .. page.Name .. stateKey, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    connect("SliderInputChanged_" .. page.Name .. stateKey, UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
    end)
    connect("SliderTouch_" .. page.Name .. stateKey, bar.TouchTap, function(touchPositions)
        local pos = touchPositions and touchPositions[1]
        if pos then fromInput({Position = pos}) end
    end)
    setValue(State[stateKey], false)
    return holder
end

local function button(page, name, description, callback, premiumOnly)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, -5, 0, 40)
    holder.BackgroundColor3 = Color3.fromRGB(8, 10, 17)
    holder.BorderSizePixel = 0
    holder.Text = ""
    holder.AutoButtonColor = false
    holder.Parent = page
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = holder
    local stroke = Instance.new("UIStroke")
    stroke.Color = premiumOnly and Color3.fromRGB(130, 36, 135) or Color3.fromRGB(49, 22, 34)
    stroke.Transparency = 0.15
    stroke.Parent = holder
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 16)
    title.Position = UDim2.fromOffset(10, 3)
    title.BackgroundTransparency = 1
    title.Text = name
    title.TextColor3 = Color3.fromRGB(235, 238, 248)
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 8.5
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = holder
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 14)
    desc.Position = UDim2.fromOffset(10, 21)
    desc.BackgroundTransparency = 1
    desc.Text = description
    desc.TextColor3 = Color3.fromRGB(125, 135, 160)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 6
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = holder
    holder.MouseButton1Click:Connect(function()
        if premiumOnly and not PREMIUM then notify("Premium", "Premium access required.", 3); return end
        if callback then pcall(callback) end
    end)
    return holder
end

--//==============================================================
--// COMBAT PAGE
--//==============================================================
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
        "Broken Fly",
        "Legacy flight movement. It is intentionally left unchanged and may be unstable.",
        "Fly",
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

    FarmDebugPanel = Instance.new("Frame")
    FarmDebugPanel.Name = "FarmDebug"
    FarmDebugPanel.Size = UDim2.new(1, -5, 0, 82)
    FarmDebugPanel.BackgroundColor3 = Color3.fromRGB(8, 13, 27)
    FarmDebugPanel.BackgroundTransparency = 0.04
    FarmDebugPanel.BorderSizePixel = 0
    FarmDebugPanel.LayoutOrder = 0
    FarmDebugPanel.Parent = page

    local debugCorner = Instance.new("UICorner")
    debugCorner.CornerRadius = UDim.new(0, 11)
    debugCorner.Parent = FarmDebugPanel

    local debugStroke = Instance.new("UIStroke")
    debugStroke.Color = Color3.fromRGB(45, 75, 125)
    debugStroke.Transparency = 0.35
    debugStroke.Parent = FarmDebugPanel

    local debugTitle = Instance.new("TextLabel")
    debugTitle.Size = UDim2.new(1, -14, 0, 17)
    debugTitle.Position = UDim2.fromOffset(7, 3)
    debugTitle.BackgroundTransparency = 1
    debugTitle.Text = "AUTOFARM DEBUG"
    debugTitle.TextColor3 = CONFIG.AccentBright
    debugTitle.Font = Enum.Font.GothamBold
    debugTitle.TextSize = 8
    debugTitle.TextXAlignment = Enum.TextXAlignment.Left
    debugTitle.Parent = FarmDebugPanel

    local function debugLabel(y)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -14, 0, 14)
        label.Position = UDim2.fromOffset(7, y)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(165, 180, 210)
        label.Font = Enum.Font.Code
        label.TextSize = 8
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = FarmDebugPanel
        return label
    end

    FarmDebugStatus = debugLabel(19)
    FarmDebugCoins = debugLabel(33)
    FarmDebugTarget = debugLabel(47)
    FarmDebugTargetDistance = debugLabel(61)
    FarmDebugThreatDistance = debugLabel(75)
    FarmDebugPhase = debugLabel(89)
    FarmDebugPanel.Size = UDim2.new(1, -5, 0, 106)

    local function setFarmDebug(status, phase, target)
        if FarmDebugStatus then FarmDebugStatus.Text = "● " .. tostring(status or "IDLE") end
        if FarmDebugCoins then FarmDebugCoins.Text = "Coins: " .. tostring(State.CoinCount) .. "/" .. tostring(State.CoinGoal) end
        local distance = "-"
        if RootPart and target and target.Parent then
            distance = string.format("%.0f", (RootPart.Position - target.Position).Magnitude)
        end
        if FarmDebugTarget then FarmDebugTarget.Text = "Target: " .. (target and target.Name or "None") end
        if FarmDebugTargetDistance then FarmDebugTargetDistance.Text = "Target Distance: " .. distance end
        local threatDistance = "-"
        if RootPart and type(nearestDangerDistance) == "function" then
            local d = nearestDangerDistance()
            if d < math.huge then threatDistance = string.format("%.0f", d) end
        end
        if FarmDebugThreatDistance then FarmDebugThreatDistance.Text = "Threat Distance: " .. threatDistance end
        if FarmDebugPhase then FarmDebugPhase.Text = "Status: " .. tostring(phase or "WAITING") end
    end

    setFarmDebug("READY", "SCANNING", nil)

    toggle(
        page,
        "Auto Farm",
        "Find coins and walk to them using map-aware paths with threat checks.",
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

            local seen = {}
            for _, object in ipairs(workspace:GetDescendants()) do
                local part = getCoinPart(object)
                if part and not seen[part] and coinIsAvailable(part) then
                    seen[part] = true
                    count += 1
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
        "Auto Lock Suspicious",
        "Lock onto a hunter-detected suspicious player.",
        "AutoLockSuspicious",
        nil,
        true
    )
end

--//==============================================================
--//==============================================================
--// BADGES PAGE
--// Roblox-inspired visual badge cards. These are local WindTurf badges,
--// not official Roblox platform badges.
--//==============================================================
do
    local page = Pages.Badges

    section(page, "WINDTURF BADGE COLLECTION")

    local badgeNames = {
        "Welcome to WindTurf",
        "Coin Collector",
        "40 Coin Run",
        "Pathfinder",
        "Map Explorer",
        "Quick Reflexes",
        "Sheriff Ready",
        "Murder Mystery",
        "Hunter",
        "Chat Watcher",
        "Safe Route",
        "Round Survivor",
        "First Load",
        "UI Explorer",
        "Galaxy Traveler",
        "Night Watch",
        "Precision",
        "Loyal Player",
        "WindTurf Veteran",
        "Welcome to Premium",
    }

    local badgeIcons = {
        "W",
        "C",
        "40",
        "P",
        "M",
        "Q",
        "S",
        "MM",
        "H",
        "CH",
        "R",
        "★",
        "1",
        "UI",
        "✦",
        "N",
        "◎",
        "L",
        "V",
        "★",
    }

    local badgeDescription = Instance.new("TextLabel")
    badgeDescription.Size = UDim2.new(1, -5, 0, 32)
    badgeDescription.BackgroundTransparency = 1
    badgeDescription.Text =
        "Roblox-inspired circular badge cards • saved locally between sessions."
    badgeDescription.TextColor3 = Color3.fromRGB(145, 158, 188)
    badgeDescription.Font = Enum.Font.Gotham
    badgeDescription.TextSize = 8
    badgeDescription.TextWrapped = true
    badgeDescription.TextXAlignment = Enum.TextXAlignment.Left
    badgeDescription.Parent = page

    local BadgeGrid = Instance.new("Frame")
    BadgeGrid.Name = "BadgeGrid"
    BadgeGrid.Size = UDim2.new(1, -5, 0, math.ceil(#badgeNames / 2) * 94)
    BadgeGrid.BackgroundTransparency = 1
    BadgeGrid.Parent = page

    local Grid = Instance.new("UIGridLayout")
    Grid.CellSize = UDim2.new(0.5, -5, 0, 84)
    Grid.CellPadding = UDim2.fromOffset(8, 8)
    Grid.SortOrder = Enum.SortOrder.LayoutOrder
    Grid.Parent = BadgeGrid

    local function makeBadge(index, badgeName)
        local card = Instance.new("Frame")
        card.Name = "Badge_" .. tostring(index)
        card.BackgroundColor3 = Color3.fromRGB(11, 16, 32)
        card.BorderSizePixel = 0
        card.LayoutOrder = index
        card.Parent = BadgeGrid

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(55, 72, 112)
        cardStroke.Transparency = 0.45
        cardStroke.Parent = card

        -- Circular badge icon, matching the general Roblox badge presentation.
        local icon = Instance.new("Frame")
        icon.Size = UDim2.fromOffset(54, 54)
        icon.Position = UDim2.fromOffset(7, 15)
        icon.BackgroundColor3 = Color3.fromRGB(28, 42, 75)
        icon.BorderSizePixel = 0
        icon.Parent = card

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(1, 0)
        iconCorner.Parent = icon

        local iconStroke = Instance.new("UIStroke")
        iconStroke.Color = CONFIG.AccentBright
        iconStroke.Thickness = 1.5
        iconStroke.Parent = icon

        local iconText = Instance.new("TextLabel")
        iconText.Size = UDim2.fromScale(1, 1)
        iconText.BackgroundTransparency = 1
        iconText.Text = badgeIcons[index] or "★"
        iconText.TextColor3 = Color3.fromRGB(235, 242, 255)
        iconText.Font = Enum.Font.GothamBold
        iconText.TextSize = (#(badgeIcons[index] or "") > 1) and 11 or 18
        iconText.Parent = icon

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -72, 0, 31)
        name.Position = UDim2.fromOffset(68, 10)
        name.BackgroundTransparency = 1
        name.Text = badgeName
        name.TextColor3 = Color3.fromRGB(238, 243, 255)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 9
        name.TextWrapped = true
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.Parent = card

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -72, 0, 22)
        status.Position = UDim2.fromOffset(68, 45)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.GothamSemibold
        status.TextSize = 8
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Parent = card

        BadgeRows[tostring(index)] = {
            Card = card,
            Icon = icon,
            IconStroke = iconStroke,
            IconText = iconText,
            Name = name,
            Status = status,
            Premium = index == 20,
        }

        return card
    end

    for index, badgeName in ipairs(badgeNames) do
        makeBadge(index, badgeName)
    end

    refreshBadgeRows = function()
        for index, row in pairs(BadgeRows) do
            local unlocked = BadgesUnlocked[tostring(index)] == true
            local premiumBadge = row.Premium

            if unlocked then
                row.Card.BackgroundColor3 = Color3.fromRGB(13, 23, 43)
                row.Icon.BackgroundColor3 = premiumBadge
                    and Color3.fromRGB(86, 46, 112)
                    or Color3.fromRGB(28, 55, 92)
                row.IconStroke.Color = premiumBadge
                    and Color3.fromRGB(220, 135, 255)
                    or CONFIG.AccentBright
                row.IconText.TextColor3 = Color3.fromRGB(255, 255, 255)
                row.Status.Text = "✓ UNLOCKED"
                row.Status.TextColor3 = premiumBadge
                    and Color3.fromRGB(220, 145, 255)
                    or CONFIG.Green
            else
                row.Card.BackgroundColor3 = Color3.fromRGB(9, 12, 23)
                row.Icon.BackgroundColor3 = Color3.fromRGB(35, 37, 44)
                row.IconStroke.Color = Color3.fromRGB(85, 88, 98)
                row.IconText.TextColor3 = Color3.fromRGB(105, 108, 118)
                row.Status.Text = "🔒 LOCKED"
                row.Status.TextColor3 = Color3.fromRGB(120, 125, 140)
            end
        end
    end

    refreshBadgeRows()

    button(
        page,
        "Save Profile Now",
        "Immediately save badges and settings to the local profile file.",
        function()
            if savePersistentData() then
                notify("WindTurf", "Badges and settings saved.", 3)
            else
                notify("WindTurf", "File saving is unavailable in this executor.", 3)
            end
        end
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
--// CROSSHAIRS PAGE
--// Visual overlay only. It stays centered on the screen and does not
--// change the game's camera or targeting logic.
--//==============================================================
do
    local page = Pages.Crosshairs

    section(page, "CROSSHAIR")

    local CrosshairLayer = Instance.new("Frame")
    CrosshairLayer.Name = "CrosshairLayer"
    CrosshairLayer.Size = UDim2.fromScale(1, 1)
    CrosshairLayer.BackgroundTransparency = 1
    CrosshairLayer.Visible = false
    CrosshairLayer.ZIndex = 900
    CrosshairLayer.Parent = MainGui

    local CrosshairHolder = Instance.new("Frame")
    CrosshairHolder.Name = "Crosshair"
    CrosshairHolder.Size = UDim2.fromOffset(80, 80)
    CrosshairHolder.Position = UDim2.fromScale(0.5, 0.5)
    CrosshairHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    CrosshairHolder.BackgroundTransparency = 1
    CrosshairHolder.ZIndex = 901
    CrosshairHolder.Parent = CrosshairLayer

    local CrosshairDrawing = Instance.new("TextLabel")
    CrosshairDrawing.Size = UDim2.fromScale(1, 1)
    CrosshairDrawing.BackgroundTransparency = 1
    CrosshairDrawing.Text = "✚"
    CrosshairDrawing.TextScaled = false
    CrosshairDrawing.TextSize = 30
    CrosshairDrawing.Font = Enum.Font.GothamBold
    CrosshairDrawing.TextColor3 = Color3.fromRGB(0, 255, 255)
    CrosshairDrawing.TextStrokeTransparency = 0.25
    CrosshairDrawing.ZIndex = 902
    CrosshairDrawing.Parent = CrosshairHolder

    local crosshairColors = {
        Red = Color3.fromRGB(255, 70, 70),
        Blue = Color3.fromRGB(80, 150, 255),
        Yellow = Color3.fromRGB(255, 225, 70),
        Green = Color3.fromRGB(75, 230, 130),
        Magenta = Color3.fromRGB(255, 70, 220),
        Purple = Color3.fromRGB(175, 100, 255),
        Pink = Color3.fromRGB(255, 120, 190),
        Cyan = Color3.fromRGB(0, 255, 255),
        White = Color3.fromRGB(255, 255, 255),
    }

    local designs = {
        "✚",
        "✕",
        "⊙",
        "◇",
        "╋",
    }

    local function refreshCrosshair()
        CrosshairLayer.Visible = State.CrosshairEnabled
        CrosshairDrawing.Text = designs[math.clamp(State.CrosshairDesign, 1, #designs)]
        CrosshairDrawing.TextColor3 =
            crosshairColors[State.CrosshairColor] or crosshairColors.Cyan
        CrosshairDrawing.TextSize = math.clamp(State.CrosshairSize, 12, 60)
    end

    toggle(
        page,
        "Show Crosshair",
        "Display the crosshair in the exact center of the screen.",
        "CrosshairEnabled",
        refreshCrosshair
    )

    toggle(
        page,
        "Spin Crosshair",
        "Continuously rotate the crosshair while it is visible.",
        "CrosshairSpin",
        refreshCrosshair
    )

    button(page, "Change Color", "Cycle red, blue, yellow, green, magenta, purple, pink, cyan and white.",
        function()
            local order = {"Red","Blue","Yellow","Green","Magenta","Purple","Pink","Cyan","White"}
            local current = 1
            for i, name in ipairs(order) do
                if name == State.CrosshairColor then
                    current = i
                    break
                end
            end
            State.CrosshairColor = order[(current % #order) + 1]
            refreshCrosshair()
            notify("Crosshair", "Color: " .. State.CrosshairColor, 2)
        end
    )

    button(page, "Change Design", "Cycle 5 different crosshair designs.",
        function()
            State.CrosshairDesign = (State.CrosshairDesign % #designs) + 1
            refreshCrosshair()
            notify("Crosshair", "Design " .. tostring(State.CrosshairDesign), 2)
        end
    )

    button(page, "Change Size", "Cycle through compact, medium and large sizes.",
        function()
            local sizes = {16, 22, 30, 40, 50}
            local current = 1
            for i, size in ipairs(sizes) do
                if size == State.CrosshairSize then
                    current = i
                    break
                end
            end
            State.CrosshairSize = sizes[(current % #sizes) + 1]
            refreshCrosshair()
            notify("Crosshair", "Size: " .. tostring(State.CrosshairSize), 2)
        end
    )

    connect("CrosshairSpin", RunService.RenderStepped, function(dt)
        if State.CrosshairEnabled and State.CrosshairSpin and CrosshairHolder.Visible ~= false then
            CrosshairHolder.Rotation = (CrosshairHolder.Rotation + dt * 180) % 360
        end
    end)

    refreshCrosshair()
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
            State.CrosshairEnabled = false
            State.CrosshairSpin = true
            State.CrosshairSize = 22
            State.CrosshairColor = "Cyan"
            State.CrosshairDesign = 1
            State.PathDiagram = true
            State.PathDiagramCoins = true
            State.PathDiagramDanger = true
            State.PathDiagramObstacles = true
            State.PathDiagramPlayers = true
            LivePathWaypoints = nil
            LivePathTarget = nil
            pcall(savePersistentData)
            notify("Settings", "Defaults restored and saved.", 3)
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
        "Return the landscape menu to the center of the screen.",
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
        "WindTurf's MM2 / Universal Script • Android landscape build.",
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
            pcall(savePersistentData)
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
--// UNIVERSAL PAGE
--//==============================================================
do
    local page = Pages.Universal
    section(page, "UNIVERSAL TOOLS")

    toggle(
        page,
        "Ghost",
        "Local visual ghost mode. Hides your character only on your client; it is not true server-side invisibility.",
        "Ghost"
    )

    slider(
        page,
        "Ghost Transparency",
        "Adjust how transparent your own character appears locally.",
        "GhostTransparency",
        0,
        1,
        0.05
    )

    button(
        page,
        "Reset Ghost",
        "Restore your normal local character visibility.",
        function()
            State.Ghost = false
            State.GhostTransparency = 1
            applyGhostVisual(false)
            notify("Ghost", "Local visibility restored.", 2)
            pcall(savePersistentData)
        end
    )

    button(
        page,
        "Character Refresh",
        "Refresh character references after a respawn without reloading the entire script.",
        function()
            refreshCharacter()
            notify("Universal", "Character references refreshed.", 2)
        end
    )

    button(
        page,
        "Safe Movement Reset",
        "Disable local movement modifiers and restore ordinary Humanoid settings.",
        function()
            State.PLWalkSpeed = false
            State.PLInfiniteJump = false
            State.PLSpin = false
            State.PLCrouchSpeed = false
            State.PLFly = false
            State.NDSWalkSpeed = false
            State.NDSInfiniteJump = false
            State.NDSSpin = false
            State.NDSLowGravity = false
            State.Fly = false
            State.Ghost = false
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.AutoRotate = true
            end
            applyGhostVisual(false)
            notify("Universal", "Movement reset.", 2)
            pcall(savePersistentData)
        end
    )

    section(page, "UNIVERSAL IDEAS")
    button(page,"Environment Detector","Shows which supported game module was detected and whether the current place is unknown.",function()
        local info = nil; pcall(function() info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end); notify("Environment", "PlaceId " .. tostring(game.PlaceId) .. " • " .. tostring(info and info.Name or "Unknown"), 3)
    end)
    button(page,"Player Scanner","Refresh nearby player references for supported visual tools without targeting or moving them.",function()
        local count=0
        for _,plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer and getAliveRoot(plr) then count+=1 end end
        notify("Universal", tostring(count) .. " nearby players detected.", 3)
    end)
end

--//==============================================================
--// UPDATE / ROADMAP PAGE
--//==============================================================
do
    local page = Pages.Update
    section(page, "WINDTURF UPDATE CENTER")

    button(page,"Current Version","Show the currently installed WindTurf v11.1 release.",function()
        notify("WindTurf", CONFIG.Version, 3)
    end)

    button(page,"Latest Loadstring","Show the configured latest loader. The release URL is intentionally blank until you publish it.",function()
        local loader = tostring(CONFIG.UpdateLoadstring or "")
        if loader == "" then
            notify("Update", "No public update loadstring is configured yet.", 4)
            return
        end
        if setclipboard then pcall(function() setclipboard(loader) end) end
        notify("Update", "Latest loadstring copied when clipboard access is available.", 3)
    end)

    button(page,"Update Instructions","Display the exact text users should see when a new release is published.",function()
        local loader = tostring(CONFIG.UpdateLoadstring or "")
        local text = "PASTE THE FOLLOWING LOADSTRING INTO YOUR EXECUTOR AND REMOVE THE TEXT\n\n" .. (loader ~= "" and loader or "[LATEST LOADSTRING NOT CONFIGURED]")
        if setclipboard and loader ~= "" then pcall(function() setclipboard(text) end) end
        notify("Update", loader ~= "" and "Update text copied." or "Configure the latest loader first.", 4)
    end)

    section(page, "PATCH NOTES • v11.1 FEATURE REBUILD")
    button(page,"Universal Ghost","Added local visual Ghost mode with transparency controls; it does not claim server-side invisibility.",function() notify("Patch Notes","Ghost is client-visual only.",3) end)
    button(page,"Premium List","ellabellabean45 and sleet_binary are included in the local Premium list.",function() notify("Premium","Premium list updated.",3) end)
    button(page,"Spin Safety","Spin controls now expose a 1–1000 UI range with a safety warning above 600.",function() notify("Spin Safety","Values above 600 are safety-limited.",3) end)
    button(page,"Load Safety","Startup, respawn, and movement cleanup were retained from the load-safe rebuild.",function() notify("Load Safety","Load-safe cleanup retained.",3) end)

    section(page, "COMING SOON")
    button(page,"Key System","Planned non-premium key system. Premium users will bypass the key requirement. Planned date: " .. tostring(CONFIG.PlannedKeySystemDate),function() notify("Roadmap","Key system is planned, not active in v11.1.",3) end)
    button(page,"Game Modules","More environment-aware tools for Prison Life and Natural Disaster Survival.",function() notify("Roadmap","More game-specific tools are planned.",3) end)
    button(page,"Ghost Improvements","Future versions may improve the local visual Ghost presentation without pretending to bypass server visibility.",function() notify("Roadmap","Ghost improvements are planned.",3) end)
    button(page,"Feature Workaround Report","Safe alternatives are used where possible: pathfinding + normal Humanoid movement for automation, Tool:Activate for exposed tools, local markers/camera for visual features. True server-side invisibility, collision bypass, wall attacks, forced remote arrests, kill aura, and fling bypasses are not implemented because they require bypassing game/server rules rather than using normal mechanics.",function() notify("Report","See the script notes: unsupported bypass-style features are intentionally excluded.",5) end)
end

--//==============================================================
--// GAME TOOLS DROPDOWN / SAFE MOVEMENT PAGE
--//==============================================================
do
    local page = Pages.GameTools
    section(page, "GAME TOOLS")

    local selectedGame = "Prison Life"
    local selector = Instance.new("TextButton")
    selector.Size = UDim2.new(1, -5, 0, 44)
    selector.BackgroundColor3 = Color3.fromRGB(10, 14, 29)
    selector.BorderSizePixel = 0
    selector.Text = ""
    selector.AutoButtonColor = false
    selector.Parent = page
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 11); sc.Parent = selector
    local sl = Instance.new("TextLabel")
    sl.Size = UDim2.new(1, -42, 1, 0); sl.Position = UDim2.fromOffset(12,0); sl.BackgroundTransparency=1
    sl.TextColor3=Color3.fromRGB(235,240,255); sl.Font=Enum.Font.GothamSemibold; sl.TextSize=10; sl.TextXAlignment=Enum.TextXAlignment.Left; sl.Parent=selector
    local arrow=Instance.new("TextLabel"); arrow.Size=UDim2.fromOffset(30,44); arrow.Position=UDim2.new(1,-35,0,0); arrow.BackgroundTransparency=1; arrow.Text="▼"; arrow.TextColor3=CONFIG.AccentBright; arrow.Font=Enum.Font.GothamBold; arrow.TextSize=10; arrow.Parent=selector

    local options=Instance.new("Frame"); options.Size=UDim2.new(1,-5,0,126); options.BackgroundColor3=Color3.fromRGB(7,10,22); options.BorderSizePixel=0; options.Visible=false; options.ZIndex=50; options.Parent=page
    local oc=Instance.new("UICorner"); oc.CornerRadius=UDim.new(0,10); oc.Parent=options
    local ol=Instance.new("UIListLayout"); ol.SortOrder=Enum.SortOrder.LayoutOrder; ol.Parent=options

    local containers={}
    local function makeGameContainer(name)
        local f=Instance.new("Frame"); f.Name=name; f.Size=UDim2.new(1,-5,0,10); f.AutomaticSize=Enum.AutomaticSize.Y; f.BackgroundTransparency=1; f.Visible=false; f.Parent=page
        local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,7); lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=f
        local pad=Instance.new("UIPadding"); pad.PaddingBottom=UDim.new(0,8); pad.Parent=f
        containers[name]=f
        return f
    end

    local mm2=makeGameContainer("MM2")
    section(mm2,"MM2")
    button(mm2,"MM2 Existing Tools","MM2 features remain in Combat, Autofarm, Hunter, Map and Visuals.",function() notify("MM2","Use the existing MM2 tabs; nothing was removed.",2) end)

    local nds=makeGameContainer("NaturalDisasterSurvival")
    section(nds,"NATURAL DISASTER SURVIVAL")
    toggle(nds,"Infinite Jump","Repeat normal jump requests for traversal.","NDSInfiniteJump",function() setupNaturalDisasterInfiniteJump() end)
    toggle(nds,"Noclip","Local collision toggle for getting around map geometry.","NDSNoclip")
    toggle(nds,"WalkSpeed","Use the NDS movement speed slider below.","NDSWalkSpeed",function(enabled) if not enabled and Humanoid then Humanoid.WalkSpeed=16 end end)
    slider(nds,"NDS WalkSpeed","Adjust local movement speed from 1 to 200.","NDSWalkSpeedValue",1,200,1)
    toggle(nds,"Spin","Rotate your own character locally.","NDSSpin")
    slider(nds,"NDS Spin Speed","Control local spin speed from 1 to 1000. Values above 600 trigger a safety warning.","NDSSpinSpeed",1,1000,1,function(value) if value > 600 then showSpinWarning("NDS") end end)
    toggle(nds,"Low Gravity","Lower local workspace gravity while enabled; restores the original value when disabled.","NDSLowGravity")
    button(nds,"Reset NDS Movement","Restore normal movement settings.",function() State.NDSWalkSpeed=false; State.NDSInfiniteJump=false; State.NDSNoclip=false; State.NDSSpin=false; State.NDSLowGravity=false; if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; pcall(savePersistentData); notify("NDS","Movement reset.",2) end)

    local pl=makeGameContainer("PrisonLife")
    section(pl,"PRISON LIFE • SAFE MOVEMENT / TROLLING")
    toggle(pl,"WalkSpeed","Use the WalkSpeed slider below.","PLWalkSpeed",function(enabled) if not enabled and Humanoid then Humanoid.WalkSpeed=16 end end)
    slider(pl,"WalkSpeed","Adjust local Prison Life WalkSpeed from 1 to 200.","PLWalkSpeedValue",1,200,1)
    toggle(pl,"Infinite Jump","Repeats the normal Humanoid jump request while enabled.","PLInfiniteJump",function() setupPrisonLifeInfiniteJump() end)
    toggle(pl,"Noclip","Local character collision toggle. No anti-cheat bypass is included.","Noclip")
    toggle(pl,"Smooth Fly","Existing local traversal flight. This is not a server-side collision bypass.","PLFly")
    toggle(pl,"Spinbot","Rotate your own character locally.","PLSpin")
    slider(pl,"Spinbot Speed","Adjust local spin speed from 1 to 1000. Values above 600 trigger a safety warning.","PLSpinSpeed",1,1000,1,function(value) if value > 600 then showSpinWarning("Prison Life") end end)
    toggle(pl,"Crouch Speed","Apply the crouch movement speed when a detectable Prison Life crouch state is active.","PLCrouchSpeed")
    button(pl,"Reset Prison Life Movement","Restore normal movement settings.",function() State.PLWalkSpeed=false; State.PLInfiniteJump=false; State.Noclip=false; State.PLSpin=false; State.PLCrouchSpeed=false; if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; pcall(savePersistentData); notify("Prison Life","Movement reset.",2) end)
    section(pl,"SAFETY")
    button(pl,"Combat Automation Excluded","Auto-arrest uses normal Handcuffs + pathfinding. No player fling, wall attacks, or anti-cheat bypasses are added.",function() notify("WindTurf","Movement/trolling tools only.",3) end)

    local function showGame(name)
        selectedGame=name
        local internal = (name=="Natural Disaster Survival" and "NaturalDisasterSurvival") or (name=="Prison Life" and "PrisonLife") or name
        sl.Text="Game: "..name
        for n,f in pairs(containers) do f.Visible=(n==internal) end
        options.Visible=false
        arrow.Text="▼"
    end
    sl.Text="Game: Prison Life"
    showGame("Prison Life")
    selector.MouseButton1Click:Connect(function() options.Visible=not options.Visible; arrow.Text=options.Visible and "▲" or "▼" end)
    for i,name in ipairs({"MM2","Natural Disaster Survival","Prison Life"}) do
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,42); b.BackgroundTransparency=1; b.Text=name; b.TextColor3=Color3.fromRGB(225,232,248); b.Font=Enum.Font.GothamSemibold; b.TextSize=9; b.LayoutOrder=i; b.ZIndex=51; b.Parent=options
        b.MouseButton1Click:Connect(function() showGame(name) end)
    end
end

--//==============================================================
--// TROLL PAGE
--// Local-only fun movement tools. No combat automation, player fling,
--// wall attacks, or anti-cheat bypasses are included here.
--//==============================================================
do
    local page = Pages.Troll
    section(page, "TROLL / FUN MOVEMENT")

    toggle(
        page,
        "Infinite Jump",
        "Repeat ordinary jump requests for a bouncy movement effect.",
        "PLInfiniteJump",
        function()
            setupPrisonLifeInfiniteJump()
        end
    )

    toggle(
        page,
        "Local Spin",
        "Rotate your own character locally. High values can be unstable.",
        "PLSpin"
    )

    slider(
        page,
        "Spin Speed",
        "Control local rotation speed from 1 to 1000. Values above 600 trigger a safety warning.",
        "PLSpinSpeed",
        1,
        1000,
        1,
        function(value) if value > 600 then showSpinWarning("Universal") end end
    )

    toggle(
        page,
        "WalkSpeed",
        "Adjust your own normal Humanoid movement speed.",
        "PLWalkSpeed",
        function(enabled)
            if not enabled and Humanoid then
                Humanoid.WalkSpeed = 16
            end
        end
    )

    slider(
        page,
        "WalkSpeed Value",
        "Control your own WalkSpeed from 1 to 200.",
        "PLWalkSpeedValue",
        1,
        200,
        1
    )

    toggle(
        page,
        "Local Noclip",
        "Disable your character's local collisions. No anti-cheat bypass is used.",
        "Noclip"
    )

    toggle(
        page,
        "Crouch Speed",
        "Use the detected Prison Life crouch movement speed when crouching.",
        "PLCrouchSpeed"
    )

    button(
        page,
        "Sit / Stand",
        "Toggle your own Humanoid sitting state.",
        function()
            if Humanoid and Humanoid.Parent then
                Humanoid.Sit = not Humanoid.Sit
            end
        end
    )

    button(
        page,
        "Reset Fun Movement",
        "Turn off local troll movement and restore ordinary movement.",
        function()
            State.PLWalkSpeed = false
            State.PLInfiniteJump = false
            State.PLSpin = false
            State.PLCrouchSpeed = false
            State.Noclip = false
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.AutoRotate = true
                Humanoid.Sit = false
            end
            pcall(savePersistentData)
            notify("Troll", "Fun movement reset.", 2)
        end
    )

    section(page, "SAFETY")
    button(
        page,
        "Movement Only",
        "These tools affect your own character only; no kill aura, player fling, or combat automation.",
        function()
            notify("WindTurf", "Local movement tools only.", 3)
        end
    )
end

--//==============================================================
--// EMOTES PAGE
--// Uses Roblox Humanoid:PlayEmote where the current avatar/game exposes
--// the requested emote. Availability depends on the avatar and game.
--//==============================================================
do
    local page = Pages.Emotes
    section(page, "EMOTES / ROBLOX + CATALOG")

    local emoteContainer = Instance.new("Frame")
    emoteContainer.Name = "CatalogEmoteContainer"
    emoteContainer.Size = UDim2.new(1, -5, 0, 290)
emoteContainer.AutomaticSize = Enum.AutomaticSize.Y
    emoteContainer.BackgroundTransparency = 1
    emoteContainer.Parent = page

    local emoteGrid = Instance.new("UIGridLayout")
    emoteGrid.CellSize = UDim2.new(0.5, -5, 0, 48)
    emoteGrid.CellPadding = UDim2.fromOffset(7, 7)
    emoteGrid.SortOrder = Enum.SortOrder.LayoutOrder
    emoteGrid.Parent = emoteContainer
emoteGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    emoteContainer.Size = UDim2.new(1, -5, 0, math.max(290, emoteGrid.AbsoluteContentSize.Y))
end)

    local emoteButtons = {}
    local emoteOrder = {}

    local function playNamedEmote(name)
        if not Humanoid or not Humanoid.Parent then
            notify("Emotes", "Character is not ready.", 2)
            return
        end

        local ok, played = pcall(function()
            local asyncMethod = Humanoid.PlayEmoteAsync
            if type(asyncMethod) == "function" then
                return asyncMethod(Humanoid, name)
            end

            local legacyMethod = Humanoid.PlayEmote
            if type(legacyMethod) == "function" then
                return legacyMethod(Humanoid, name)
            end

            return false
        end)

        if not ok or played == false then
            notify("Emotes", name .. " is unavailable here.", 2)
        end
    end

    local function addEmoteButton(name, assetId)
        name = tostring(name)
        if emoteButtons[name] then
            return
        end

        local holder = Instance.new("TextButton")
        holder.Name = "Emote_" .. name:gsub("[^%w_]", "_")
        holder.Size = UDim2.new(0, 1, 0, 1)
        holder.BackgroundColor3 = Color3.fromRGB(13, 15, 24)
        holder.BorderSizePixel = 0
        holder.Text = ""
        holder.AutoButtonColor = false
        holder.LayoutOrder = #emoteOrder + 1
        holder.Parent = emoteContainer

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 9)
        c.Parent = holder

        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(74, 25, 42)
        s.Transparency = 0.15
        s.Parent = holder

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 20)
        title.Position = UDim2.fromOffset(7, 4)
        title.BackgroundTransparency = 1
        title.Text = name
        title.TextColor3 = Color3.fromRGB(245, 240, 246)
        title.Font = Enum.Font.GothamSemibold
        title.TextSize = 9
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.Parent = holder

        local idText = Instance.new("TextLabel")
        idText.Size = UDim2.new(1, -12, 0, 15)
        idText.Position = UDim2.fromOffset(7, 25)
        idText.BackgroundTransparency = 1
        idText.Text = assetId and ("CATALOG • " .. tostring(assetId)) or "ROBLOX / AVATAR"
        idText.TextColor3 = Color3.fromRGB(155, 135, 150)
        idText.Font = Enum.Font.Gotham
        idText.TextSize = 7
        idText.TextXAlignment = Enum.TextXAlignment.Left
        idText.TextTruncate = Enum.TextTruncate.AtEnd
        idText.Parent = holder

        holder.MouseButton1Click:Connect(function()
            playNamedEmote(name)
        end)

        emoteButtons[name] = holder
        table.insert(emoteOrder, name)
    end

    -- Roblox's built-in emotes are included as convenient shortcuts.
    local defaultEmotes = {
        {"Wave", "wave"}, {"Point", "point"}, {"Cheer", "cheer"},
        {"Laugh", "laugh"}, {"Dance", "dance"}, {"Dance 2", "dance2"},
        {"Dance 3", "dance3"}, {"Salute", "salute"},
    }

    for _, item in ipairs(defaultEmotes) do
        addEmoteButton(item[1], nil)
    end

    local function refreshCatalogEmotes()
        if not Humanoid or not Humanoid.Parent then
            notify("Emotes", "Character is not ready.", 2)
            return
        end

        local description
        local okDescription = pcall(function()
            description = Humanoid:FindFirstChildOfClass("HumanoidDescription")
                or Humanoid.HumanoidDescription
        end)

        if not okDescription or not description then
            notify("Emotes", "This avatar does not expose a HumanoidDescription.", 3)
            return
        end

        local emoteTable
        local ok = pcall(function()
            emoteTable = description:GetEmotes()
        end)

        if not ok or type(emoteTable) ~= "table" then
            notify("Emotes", "No catalog emotes are available to this avatar.", 3)
            return
        end

        local added = 0
        for name, ids in pairs(emoteTable) do
            local assetId
            if type(ids) == "table" then
                assetId = ids[1]
            else
                assetId = ids
            end

            if not emoteButtons[tostring(name)] then
                addEmoteButton(name, assetId)
                added += 1
            end
        end

        notify(
            "Emotes",
            added > 0
                and ("Loaded " .. tostring(added) .. " avatar/catalog emotes.")
                or "All currently available avatar/catalog emotes are already loaded.",
            3
        )
    end

    button(
        page,
        "Load My Catalog Emotes",
        "Reads the emotes currently exposed by your avatar, including user-created Marketplace emotes you have equipped.",
        refreshCatalogEmotes
    )

    button(
        page,
        "Refresh Catalog Emotes",
        "Refresh the list after changing equipped avatar emotes.",
        refreshCatalogEmotes
    )

    button(
        page,
        "Stop Emote",
        "Stop currently playing animation tracks on your character.",
        function()
            if Humanoid then
                pcall(function()
                    for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
                        track:Stop(0.15)
                    end
                end)
            end
        end
    )

    section(page, "CATALOG / AVATAR NOTE")
    button(
        page,
        "Why Not Every Marketplace Emote?",
        "Roblox only exposes emotes that the current avatar/game makes available. This loader does not pretend it can play arbitrary catalog animation IDs.",
        function()
            notify("Emotes", "Only emotes exposed to your avatar can be played.", 4)
        end
    )
end

--//==============================================================
--// SIDEBAR BUTTONS
--//==============================================================
for index, info in ipairs(TabInfo) do
    local tabName = info[1]
    local icon = info[2]
    local displayName = info[3] or tabName

    local buttonObject = Instance.new("TextButton")
    buttonObject.Name = tabName .. "Tab"
    buttonObject.Size = UDim2.new(1, 0, 0, 33)
    buttonObject.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
    buttonObject.BackgroundTransparency = 0.05
    buttonObject.BorderSizePixel = 0
    buttonObject.Text = ""
    buttonObject.AutoButtonColor = false
    buttonObject.LayoutOrder = index
    buttonObject.ZIndex = 109
    buttonObject.Parent = Sidebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = buttonObject
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(42, 24, 34)
    stroke.Transparency = 0.25
    stroke.Parent = buttonObject

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(22, 30)
    iconLabel.Position = UDim2.fromOffset(3, 1)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(190, 199, 220)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 13
    iconLabel.ZIndex = 110
    iconLabel.Parent = buttonObject

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -28, 1, 0)
    nameLabel.Position = UDim2.fromOffset(27, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = displayName
    nameLabel.TextColor3 = Color3.fromRGB(205, 212, 232)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 6.5
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 110
    nameLabel.Parent = buttonObject

    TabButtons[tabName] = buttonObject

    buttonObject.MouseButton1Click:Connect(function()
        for name, page in pairs(Pages) do
            page.Visible = name == tabName
        end
        for name, tabButton in pairs(TabButtons) do
            local active = name == tabName
            tabButton.BackgroundColor3 = active and Color3.fromRGB(198, 13, 39) or Color3.fromRGB(9, 11, 18)
            local label = tabButton:FindFirstChildOfClass("TextLabel")
            if label then label.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 212, 232) end
        end
        State.CurrentTab = tabName
    end)
end



Pages.Combat.Visible = true
TabButtons.Combat.BackgroundColor3 = Color3.fromRGB(198, 13, 39)

--//==============================================================
--// DRAG SYSTEM
--//==============================================================
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
ReopenButton.BackgroundColor3 = Color3.fromRGB(9, 10, 17)
ReopenButton.BackgroundTransparency = 0.04
ReopenButton.BorderSizePixel = 0
ReopenButton.Text = "W"
ReopenButton.TextColor3 = Color3.fromRGB(255, 55, 78)
ReopenButton.TextSize = 25
ReopenButton.Font = Enum.Font.GothamBlack
ReopenButton.AutoButtonColor = false
ReopenButton.Visible = false
ReopenButton.ZIndex = 900
ReopenButton.Parent = MainGui

local ReopenGradient = Instance.new("UIGradient")
ReopenGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 19)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(31, 8, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 10, 28)),
})
ReopenGradient.Rotation = 135
ReopenGradient.Parent = ReopenButton

local ReopenCorner = Instance.new("UICorner")
ReopenCorner.CornerRadius = UDim.new(1, 0)
ReopenCorner.Parent = ReopenButton

local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(255, 35, 68)
ReopenStroke.Thickness = 2
ReopenStroke.Transparency = 0.08
ReopenStroke.Parent = ReopenButton

local ReopenGlow = Instance.new("UIStroke")
ReopenGlow.Color = Color3.fromRGB(135, 15, 45)
ReopenGlow.Thickness = 5
ReopenGlow.Transparency = 0.75
ReopenGlow.Parent = ReopenButton

local ReopenHint = Instance.new("TextLabel")
ReopenHint.Size = UDim2.new(1, -8, 0, 12)
ReopenHint.Position = UDim2.new(0, 4, 1, -15)
ReopenHint.BackgroundTransparency = 1
ReopenHint.Text = "OPEN"
ReopenHint.TextColor3 = Color3.fromRGB(255, 150, 165)
ReopenHint.Font = Enum.Font.GothamBold
ReopenHint.TextSize = 6
ReopenHint.ZIndex = 901
ReopenHint.Parent = ReopenButton

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

local function setGuiFade(root, fadeOut, duration)
    local targets = {}
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("GuiObject") then
            table.insert(targets, obj)
        end
    end

    for _, obj in ipairs(targets) do
        if obj:GetAttribute("WindTurfFadeSaved") == nil then
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj:SetAttribute("WindTurfTextTransparency", obj.TextTransparency)
            end
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                obj:SetAttribute("WindTurfImageTransparency", obj.ImageTransparency)
            end
            obj:SetAttribute("WindTurfBackgroundTransparency", obj.BackgroundTransparency)
            obj:SetAttribute("WindTurfFadeSaved", true)
        end

        local props = {}
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            props.TextTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfTextTransparency") or 0)
        end
        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            props.ImageTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfImageTransparency") or 0)
        end
        props.BackgroundTransparency = fadeOut and 1 or (obj:GetAttribute("WindTurfBackgroundTransparency") or 0)

        tween(obj, duration, props, Enum.EasingStyle.Quad, fadeOut and Enum.EasingDirection.In or Enum.EasingDirection.Out)
    end
end

local function openMenu()
    State.MenuOpen = true
    ReopenButton.Visible = false
    ReopenButton.BackgroundTransparency = 1
    ReopenButton.TextTransparency = 1
    ReopenHint.TextTransparency = 1
    Main.Visible = true

    Main.Size = UDim2.fromOffset(MENU_WIDTH, 20)
    Main.BackgroundTransparency = 1
    setGuiFade(Main, true, 0)

    tween(
        Main,
        0.28,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, MENU_HEIGHT),
            BackgroundTransparency = 0.06
        },
        Enum.EasingStyle.Back,
        Enum.EasingDirection.Out
    )

    setGuiFade(Main, false, 0.28)
end

local function closeMenu()
    State.MenuOpen = false
    setGuiFade(Main, true, 0.20)

    tween(
        Main,
        0.20,
        {
            Size = UDim2.fromOffset(MENU_WIDTH, 20),
            BackgroundTransparency = 1
        },
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.In
    )

    task.delay(State.Animations and 0.20 or 0, function()
        if not State.MenuOpen and not Destroyed then
            Main.Visible = false

            ReopenButton.Visible = true
            ReopenButton.BackgroundTransparency = 1
            ReopenButton.TextTransparency = 1
            ReopenHint.TextTransparency = 1

            tween(ReopenButton, 0.24, {
                BackgroundTransparency = 0.04,
                TextTransparency = 0
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

            tween(ReopenHint, 0.24, {
                TextTransparency = 0
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
    local knife = findToolByNames({"knife", "murderer", "blade"}, player)
    if knife then return "Murderer" end

    local gun = findToolByNames({"gun", "sheriff", "revolver"}, player)
    if gun then
        if KnownSheriffUserId and player.UserId == KnownSheriffUserId then
            return "Sheriff"
        end
        -- A gun holder that is not the known sheriff is treated as Hero.
        -- The ID is updated from the first confirmed gun holder each ESP pass.
        return "Hero"
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
    -- Prefer a directly identified murderer first. This is more reliable
    -- than relying only on the visible Tool because the tool can briefly
    -- move between Character and Backpack.
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and getAliveRoot(player) then
            if getPlayerRole(player) == "Murderer" then
                return player
            end
        end
    end

    -- Fall back to an explicitly suspicious target only when no murderer
    -- can currently be identified.
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

-- Prison Life: normal-mechanics arrest helper. It only uses visible player state,
-- Humanoid movement/pathfinding, and a Handcuffs tool when the game exposes one.
local function isLikelyWantedPlayer(player)
    if not player or player == LocalPlayer then return false end
    local character = player.Character
    if not character then return false end

    local function truthyValue(container, names)
        if not container then return false end
        for _, name in ipairs(names) do
            local obj = container:FindFirstChild(name)
            if obj then
                if obj:IsA("BoolValue") and obj.Value then return true end
                if (obj:IsA("IntValue") or obj:IsA("NumberValue")) and obj.Value > 0 then return true end
                if obj:IsA("StringValue") and string.find(string.lower(obj.Value), "wanted", 1, true) then return true end
            end
        end
        return false
    end

    if truthyValue(player, {"Wanted","IsWanted","Bounty","WantedValue"}) then return true end
    if truthyValue(player:FindFirstChild("leaderstats"), {"Wanted","Bounty","Arrests","Criminal"}) then return true end

    local teamName = string.lower(tostring(player.Team and player.Team.Name or ""))
    if teamName:find("criminal",1,true) or teamName:find("inmate",1,true) or teamName:find("prisoner",1,true) then
        return true
    end
    return false
end

local function findWantedTarget()
    if not RootPart then return nil, math.huge end
    local best, bestDistance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if isLikelyWantedPlayer(player) then
            local root = getAliveRoot(player)
            if root then
                local d = (root.Position - RootPart.Position).Magnitude
                if d < bestDistance then best, bestDistance = player, d end
            end
        end
    end
    return best, bestDistance
end

local AutoArrestBusy = false
local LastArrestPath = 0

local function runAutoArrest()
    if not Feature.AutoArrest or AutoArrestBusy or not isPrisonPlace() or not isAlive() then return end
    local handcuffs = findToolByNames({"handcuff", "cuffs"})
    if not handcuffs then return end
    local target, distance = findWantedTarget()
    if not target then return end

    AutoArrestBusy = true
    task.spawn(function()
        local ok = false
        local targetRoot = getAliveRoot(target)
        if targetRoot and distance > 7 then
            local path = PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true, WaypointSpacing=3})
            local computed = pcall(function() path:ComputeAsync(RootPart.Position, targetRoot.Position) end)
            if computed and path.Status == Enum.PathStatus.Success then
                for _, wp in ipairs(path:GetWaypoints()) do
                    if not Feature.AutoArrest or not isAlive() or not target.Parent then break end
                    local currentRoot = getAliveRoot(target)
                    if not currentRoot then break end
                    if (currentRoot.Position - RootPart.Position).Magnitude <= 7 then break end
                    Humanoid:MoveTo(wp.Position)
                    local reached = false
                    local conn = Humanoid.MoveToFinished:Connect(function(r) reached = r end)
                    local deadline = os.clock() + 2.5
                    while not reached and os.clock() < deadline and Feature.AutoArrest do task.wait(0.05) end
                    conn:Disconnect()
                end
            end
        end
        targetRoot = getAliveRoot(target)
        if targetRoot and (targetRoot.Position - RootPart.Position).Magnitude <= 9 then
            if equipTool(handcuffs) then
                -- Normal Tool activation; no remote invocation or forced arrest.
                pcall(function() handcuffs:Activate() end)
                ok = true
            end
        end
        if ok then featureNotify("Prison Life", "Handcuffs activated on a nearby detected target.") end
        AutoArrestBusy = false
        LastArrestPath = os.clock()
    end)
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
--// COIN / THREAT-AWARE AUTOFARM
--// Rewritten around verification instead of assuming a teleport means
--// a collection. The script never counts a coin until the target changes,
--// disappears, or the player's observed currency increases.
--//==============================================================
local CoinObjects = {}
local CoinKnown = {}
local LastCoinScan = 0
local FarmBusy = false
local LastCollectedTarget = nil
local LastCollectedPosition = nil
local FARM_SCAN_INTERVAL = 0.45
local FARM_VERIFY_TIMEOUT = 1.00
local FARM_VERIFY_STEP = 0.08
local FARM_TARGET_RETRIES = 2
local FARM_FAIL_BLACKLIST_SECONDS = 1.75
local FARM_MAX_BLACKLIST_SECONDS = 5.0
local DANGER_RADIUS = 65
local SAFE_COIN_RADIUS = 72
local CoinBlacklist = {}
local CoinFailureCount = {}

-- Pathfinding is used for the farm instead of setting the character's CFrame
-- directly on top of coins. This follows actual walkable map geometry and
-- automatically adapts when the current MM2 map changes.
local FARM_AGENT_RADIUS = 2
local FARM_AGENT_HEIGHT = 5
local FARM_WAYPOINT_SPACING = 3.5
local FARM_WAYPOINT_TIMEOUT = 4.5
local FARM_REPATH_LIMIT = 3
local FARM_CANDIDATE_LIMIT = 8
local FARM_REPATH_DISTANCE = 5
local FARM_GROUND_RAY_HEIGHT = 8
local FARM_GROUND_RAY_DEPTH = 20

local function getCoinPart(object)
    if not object or not object.Parent then return nil end

    if object:IsA("BasePart") then
        local name = string.lower(object.Name)
        if name:find("coin", 1, true)
            or name:find("token", 1, true)
            or name:find("cash", 1, true)
            or name:find("collect", 1, true) then
            return object
        end
    end

    if object:IsA("Model") or object:IsA("Folder") then
        local directNames = {
            "Coin_Server", "Coin", "Token", "Cash", "Collect"
        }
        for _, name in ipairs(directNames) do
            local child = object:FindFirstChild(name)
            if child then
                if child:IsA("BasePart") then
                    return child
                end
                local handle = child:FindFirstChild("Handle", true)
                if handle and handle:IsA("BasePart") then
                    return handle
                end
            end
        end

        local handle = object:FindFirstChild("Handle", true)
        if handle and handle:IsA("BasePart") then
            local lower = string.lower(object.Name)
            if lower:find("coin", 1, true)
                or lower:find("token", 1, true)
                or lower:find("cash", 1, true)
                or lower:find("collect", 1, true) then
                return handle
            end
        end
    end

    return nil
end

local function coinIsAvailable(object)
    local part = getCoinPart(object)
    if not part or not part.Parent then return false end
    if part.Transparency >= 0.98 then return false end
    if part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then return false end
    return true
end

local function scanCoins()
    table.clear(CoinObjects)
    table.clear(CoinKnown)
    local seen = {}

    for _, object in ipairs(workspace:GetDescendants()) do
        local part = getCoinPart(object)
        if part and coinIsAvailable(part) and not seen[part] then
            seen[part] = true
            CoinKnown[part] = true
            table.insert(CoinObjects, part)
        end
    end

    LastCoinScan = os.clock()
end

connect("CoinDescendantAdded", workspace.DescendantAdded, function(object)
    local part = getCoinPart(object)
    if part and coinIsAvailable(part) and not CoinKnown[part] then
        CoinKnown[part] = true
        table.insert(CoinObjects, part)
    end
end)

connect("CoinDescendantRemoving", workspace.DescendantRemoving, function(object)
    CoinBlacklist[object] = nil
    CoinFailureCount[object] = nil
    CoinKnown[object] = nil
    for i = #CoinObjects, 1, -1 do
        if CoinObjects[i] == object then
            table.remove(CoinObjects, i)
            break
        end
    end
end)

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

local function nearestDangerDistance()
    local closest = math.huge
    for _, danger in ipairs(getDangerousPlayers()) do
        closest = math.min(closest, danger.Distance)
    end
    return closest
end

local function dangerousPlayerNearby(radius)
    if not RootPart then return false end
    radius = radius or DANGER_RADIUS
    return nearestDangerDistance() <= radius
end

local function coinThreatDistance(object, dangers)
    local closest = math.huge
    local position = getCoinPart(object) and getCoinPart(object).Position
    if not position then return closest end
    for _, danger in ipairs(dangers) do
        if danger.Root and danger.Root.Parent then
            closest = math.min(closest, (danger.Root.Position - position).Magnitude)
        end
    end
    return closest
end

local function coinIsBlacklisted(object)
    local untilTime = CoinBlacklist[object]
    if not untilTime then return false end
    if os.clock() >= untilTime then
        CoinBlacklist[object] = nil
        return false
    end
    return true
end

local function blacklistCoin(object)
    if not object then return end
    local failures = (CoinFailureCount[object] or 0) + 1
    CoinFailureCount[object] = failures
    local duration = math.min(FARM_FAIL_BLACKLIST_SECONDS * failures, FARM_MAX_BLACKLIST_SECONDS)
    CoinBlacklist[object] = os.clock() + duration
end

local function clearCoinFailure(object)
    if object then
        CoinBlacklist[object] = nil
        CoinFailureCount[object] = nil
    end
end

local function getFarmTargetPosition(object)
    if not object or not object.Parent then return nil end
    local position = object.Position

    -- Coins can be slightly above/below the walkable floor. Project the target
    -- down to nearby ground so PathfindingService plans to a walkable point.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = Character and {Character} or {}
    params.IgnoreWater = false

    local hit = workspace:Raycast(
        position + Vector3.new(0, 10, 0),
        Vector3.new(0, -30, 0),
        params
    )

    if hit then
        return hit.Position + Vector3.new(0, 1.8, 0)
    end

    return position
end

local function createFarmPath(startPosition, targetPosition)
    local path = PathfindingService:CreatePath({
        AgentRadius = FARM_AGENT_RADIUS,
        AgentHeight = FARM_AGENT_HEIGHT,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = FARM_WAYPOINT_SPACING,
    })

    local ok = pcall(function()
        path:ComputeAsync(startPosition, targetPosition)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return nil
    end

    if RootPart and not pathStillReasonable(waypoints, RootPart.Position) then
        return nil
    end

    return path, waypoints
end

local function pathIsSafe(waypoints, dangers)
    for _, waypoint in ipairs(waypoints) do
        for _, danger in ipairs(dangers) do
            if danger.Root and danger.Root.Parent then
                if (danger.Root.Position - waypoint.Position).Magnitude < SAFE_COIN_RADIUS then
                    return false
                end
            end
        end
    end
    return true
end

local function pathLength(waypoints, startPosition)
    local total = 0
    local previous = startPosition
    for _, waypoint in ipairs(waypoints) do
        total += (waypoint.Position - previous).Magnitude
        previous = waypoint.Position
    end
    return total
end


--//==============================================================
--// LIVE PATH MAP / TOP-DOWN DIAGRAM
--//==============================================================
-- This is a client-side visualization of the actual PathfindingService
-- waypoints selected by the farm. Green = current safe route, yellow =
-- coins, red = murderer danger area, blue = nearby map obstacles.
-- It does not move the character by itself.
local PATH_MAP_WORLD_RADIUS = 95
local PATH_MAP_UPDATE_INTERVAL = 0.18
local LastPathMapUpdate = 0

local function pathMapClear()
    if not PathMapCanvas then return end
    for _, child in ipairs(PathMapCanvas:GetChildren()) do
        if not child:GetAttribute("PathMapStatic") then
            pcall(function() child:Destroy() end)
        end
    end
end

local function pathMapLine(parent, a, b, color, thickness, zIndex)
    local delta = b - a
    local length = delta.Magnitude
    if length < 1 then return end

    local line = Instance.new("Frame")
    line.BorderSizePixel = 0
    line.BackgroundColor3 = color
    line.BackgroundTransparency = 0.08
    line.AnchorPoint = Vector2.new(0, 0.5)
    line.Position = UDim2.fromOffset(a.X, a.Y)
    line.Size = UDim2.fromOffset(length, thickness or 2)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.ZIndex = zIndex or 5
    line.Parent = parent
end

local function pathMapDot(parent, point, diameter, color, strokeColor, zIndex)
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromOffset(point.X, point.Y)
    dot.Size = UDim2.fromOffset(diameter, diameter)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.ZIndex = zIndex or 10
    dot.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    if strokeColor then
        local stroke = Instance.new("UIStroke")
        stroke.Color = strokeColor
        stroke.Thickness = 1
        stroke.Transparency = 0.15
        stroke.Parent = dot
    end

    return dot
end

local function pathMapWorldToScreen(position, center, width, height)
    local dx = position.X - center.X
    local dz = position.Z - center.Z

    local sx = width * 0.5 + (dx / PATH_MAP_WORLD_RADIUS) * (width * 0.5)
    local sy = height * 0.5 + (dz / PATH_MAP_WORLD_RADIUS) * (height * 0.5)

    return Vector2.new(sx, sy)
end

local function pathMapAddObstacle(parent, part, center, width, height)
    if not State.PathDiagramObstacles then return end
    if not part:IsA("BasePart") or not part.Parent then return end
    if not part.Anchored or not part.CanCollide then return end
    if Character and part:IsDescendantOf(Character) then return end
    if part.Transparency >= 0.92 then return end

    local size = part.Size
    local maxHorizontal = math.max(size.X, size.Z)
    local minHorizontal = math.min(size.X, size.Z)

    -- Skip floors, huge map shells and tiny decorative pieces.
    if size.Y > 18 then return end
    if maxHorizontal > 90 then return end
    if minHorizontal < 0.35 then return end

    local p = pathMapWorldToScreen(part.Position, center, width, height)
    local sx = math.max(2, (size.X / PATH_MAP_WORLD_RADIUS) * (width * 0.5))
    local sy = math.max(2, (size.Z / PATH_MAP_WORLD_RADIUS) * (height * 0.5))

    if p.X + sx * 0.5 < 0 or p.X - sx * 0.5 > width
        or p.Y + sy * 0.5 < 0 or p.Y - sy * 0.5 > height then
        return
    end

    local obstacle = Instance.new("Frame")
    obstacle.AnchorPoint = Vector2.new(0.5, 0.5)
    obstacle.Position = UDim2.fromOffset(p.X, p.Y)
    obstacle.Size = UDim2.fromOffset(math.min(sx, width), math.min(sy, height))
    obstacle.BackgroundColor3 = Color3.fromRGB(115, 125, 150)
    obstacle.BackgroundTransparency = 0.28
    obstacle.BorderSizePixel = 0
    obstacle.ZIndex = 2
    obstacle.Parent = parent
end

local function refreshPathMap(force)
    if not PathMapCanvas or not PathMapCanvas.Parent then return end
    if not State.PathDiagram then
        PathMapCanvas.Visible = false
        if PathMapStatus then
            PathMapStatus.Text = "MAP OFF"
        end
        return
    end

    PathMapCanvas.Visible = true

    if not force and os.clock() - LastPathMapUpdate < PATH_MAP_UPDATE_INTERVAL then
        return
    end
    LastPathMapUpdate = os.clock()

    pathMapClear()

    if not RootPart or not RootPart.Parent then
        if PathMapStatus then PathMapStatus.Text = "WAITING FOR CHARACTER" end
        return
    end

    local width = PathMapCanvas.AbsoluteSize.X
    local height = PathMapCanvas.AbsoluteSize.Y

    if width < 10 or height < 10 then
        return
    end

    local center = RootPart.Position

    -- Subtle grid for the diagram.
    for i = 1, 5 do
        local x = width * (i / 6)
        local y = height * (i / 6)

        local v = Instance.new("Frame")
        v.BorderSizePixel = 0
        v.BackgroundColor3 = Color3.fromRGB(45, 58, 95)
        v.BackgroundTransparency = 0.75
        v.Size = UDim2.fromOffset(1, height)
        v.Position = UDim2.fromOffset(x, 0)
        v.ZIndex = 1
        v.Parent = PathMapCanvas

        local h = Instance.new("Frame")
        h.BorderSizePixel = 0
        h.BackgroundColor3 = Color3.fromRGB(45, 58, 95)
        h.BackgroundTransparency = 0.75
        h.Size = UDim2.fromOffset(width, 1)
        h.Position = UDim2.fromOffset(0, y)
        h.ZIndex = 1
        h.Parent = PathMapCanvas
    end

    -- Nearby physical obstacles, top-down approximation.
    if State.PathDiagramObstacles then
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = Character and {Character} or {}

        local parts = {}
        local ok = pcall(function()
            parts = workspace:GetPartBoundsInBox(
                CFrame.new(center),
                Vector3.new(PATH_MAP_WORLD_RADIUS * 2, 60, PATH_MAP_WORLD_RADIUS * 2),
                overlap
            )
        end)

        if ok then
            local drawn = 0
            for _, part in ipairs(parts) do
                pathMapAddObstacle(
                    PathMapCanvas,
                    part,
                    center,
                    width,
                    height
                )
                drawn += 1
                if drawn >= 65 then
                    break
                end
            end
        end
    end

    -- Coin markers.
    if State.PathDiagramCoins then
        local coinDrawn = 0
        for _, coin in ipairs(CoinObjects) do
            if coinIsAvailable(coin) then
                local distance = (coin.Position - center).Magnitude
                if distance <= PATH_MAP_WORLD_RADIUS then
                    local p = pathMapWorldToScreen(
                        coin.Position,
                        center,
                        width,
                        height
                    )
                    pathMapDot(
                        PathMapCanvas,
                        p,
                        7,
                        Color3.fromRGB(255, 205, 55),
                        Color3.fromRGB(255, 240, 140),
                        7
                    )
                    coinDrawn += 1
                    if coinDrawn >= 30 then
                        break
                    end
                end
            end
        end
    end

    -- Murderer danger zones and line-of-sight direction.
    local murdererCount = 0
    if State.PathDiagramDanger then
        for _, danger in ipairs(getDangerousPlayers()) do
            if danger.Role == "Murderer"
                and danger.Root
                and danger.Root.Parent
                and (danger.Root.Position - center).Magnitude <= PATH_MAP_WORLD_RADIUS then

                local dangerPoint = pathMapWorldToScreen(
                    danger.Root.Position,
                    center,
                    width,
                    height
                )

                local dangerRadiusPx =
                    (DANGER_RADIUS / PATH_MAP_WORLD_RADIUS) * (width * 0.5)

                local ring = Instance.new("Frame")
                ring.AnchorPoint = Vector2.new(0.5, 0.5)
                ring.Position = UDim2.fromOffset(dangerPoint.X, dangerPoint.Y)
                ring.Size = UDim2.fromOffset(
                    dangerRadiusPx * 2,
                    dangerRadiusPx * 2
                )
                ring.BackgroundColor3 = Color3.fromRGB(255, 55, 70)
                ring.BackgroundTransparency = 0.88
                ring.BorderSizePixel = 0
                ring.ZIndex = 3
                ring.Parent = PathMapCanvas

                local ringCorner = Instance.new("UICorner")
                ringCorner.CornerRadius = UDim.new(1, 0)
                ringCorner.Parent = ring

                local ringStroke = Instance.new("UIStroke")
                ringStroke.Color = Color3.fromRGB(255, 65, 80)
                ringStroke.Thickness = 1
                ringStroke.Transparency = 0.25
                ringStroke.Parent = ring

                local playerPoint = pathMapWorldToScreen(
                    center,
                    center,
                    width,
                    height
                )

                pathMapLine(
                    PathMapCanvas,
                    playerPoint,
                    dangerPoint,
                    Color3.fromRGB(255, 75, 90),
                    2,
                    6
                )

                pathMapDot(
                    PathMapCanvas,
                    dangerPoint,
                    12,
                    Color3.fromRGB(255, 55, 70),
                    Color3.fromRGB(255, 210, 215),
                    11
                )

                local x = Instance.new("TextLabel")
                x.AnchorPoint = Vector2.new(0.5, 0.5)
                x.Position = UDim2.fromOffset(dangerPoint.X, dangerPoint.Y)
                x.Size = UDim2.fromOffset(22, 22)
                x.BackgroundTransparency = 1
                x.Text = "×"
                x.TextColor3 = Color3.fromRGB(255, 255, 255)
                x.Font = Enum.Font.GothamBold
                x.TextSize = 15
                x.ZIndex = 12
                x.Parent = PathMapCanvas

                murdererCount += 1
            end
        end
    end

    -- All nearby players. These are visualization-only live position markers;
    -- they do not target, move, or attack players.
    if State.PathDiagramPlayers then
        local playerDrawn = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local otherRoot = getAliveRoot(player)
                if otherRoot and otherRoot.Parent then
                    local distance = (otherRoot.Position - center).Magnitude
                    if distance <= PATH_MAP_WORLD_RADIUS then
                        local otherPoint = pathMapWorldToScreen(
                            otherRoot.Position, center, width, height
                        )
                        local role = getPlayerRole(player)
                        local markerColor = Color3.fromRGB(95, 175, 255)
                        if role == "Murderer" then
                            markerColor = Color3.fromRGB(255, 70, 80)
                        elseif role == "Sheriff" then
                            markerColor = Color3.fromRGB(75, 185, 255)
                        elseif role == "Hero" then
                            markerColor = Color3.fromRGB(245, 205, 70)
                        end

                        pathMapDot(
                            PathMapCanvas, otherPoint, 9, markerColor,
                            Color3.fromRGB(235, 245, 255), 13
                        )

                        local label = Instance.new("TextLabel")
                        label.AnchorPoint = Vector2.new(0.5, 0)
                        label.Position = UDim2.fromOffset(otherPoint.X, otherPoint.Y + 6)
                        label.Size = UDim2.fromOffset(90, 13)
                        label.BackgroundTransparency = 1
                        label.Text = string.sub(player.Name, 1, 12)
                        label.TextColor3 = Color3.fromRGB(225, 235, 250)
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 6
                        label.TextXAlignment = Enum.TextXAlignment.Center
                        label.ZIndex = 14
                        label.Parent = PathMapCanvas

                        playerDrawn += 1
                        if playerDrawn >= 30 then
                            break
                        end
                    end
                end
            end
        end
    end

    -- Current player/start marker.
    local playerPoint = pathMapWorldToScreen(
        center,
        center,
        width,
        height
    )
    pathMapDot(
        PathMapCanvas,
        playerPoint,
        13,
        Color3.fromRGB(70, 230, 125),
        Color3.fromRGB(220, 255, 230),
        15
    )

    -- Current actual PathfindingService route.
    local waypoints = LivePathWaypoints
    if waypoints and #waypoints >= 2 then
        local previous = nil

        for _, waypoint in ipairs(waypoints) do
            if waypoint and waypoint.Position then
                local p = pathMapWorldToScreen(
                    waypoint.Position,
                    center,
                    width,
                    height
                )

                if previous then
                    pathMapLine(
                        PathMapCanvas,
                        previous,
                        p,
                        Color3.fromRGB(60, 235, 120),
                        3,
                        9
                    )
                end

                pathMapDot(
                    PathMapCanvas,
                    p,
                    6,
                    Color3.fromRGB(70, 235, 140),
                    Color3.fromRGB(210, 255, 225),
                    10
                )

                previous = p
            end
        end
    end

    -- Current target coin.
    if LivePathTarget
        and LivePathTarget.Parent
        and coinIsAvailable(LivePathTarget) then

        local targetPoint = pathMapWorldToScreen(
            LivePathTarget.Position,
            center,
            width,
            height
        )

        pathMapDot(
            PathMapCanvas,
            targetPoint,
            11,
            Color3.fromRGB(255, 190, 45),
            Color3.fromRGB(255, 250, 175),
            14
        )

        local targetText = Instance.new("TextLabel")
        targetText.AnchorPoint = Vector2.new(0.5, 1)
        targetText.Position = UDim2.fromOffset(targetPoint.X, targetPoint.Y - 8)
        targetText.Size = UDim2.fromOffset(90, 16)
        targetText.BackgroundTransparency = 1
        targetText.Text = "TARGET"
        targetText.TextColor3 = Color3.fromRGB(255, 225, 100)
        targetText.Font = Enum.Font.GothamBold
        targetText.TextSize = 7
        targetText.ZIndex = 16
        targetText.Parent = PathMapCanvas
    end

    if PathMapStatus then
        local routeState = (waypoints and #waypoints >= 2)
            and "GREEN = CURRENT SAFE PATH"
            or "WAITING FOR SAFE PATH"

        if murdererCount > 0 then
            routeState = routeState .. " • RED = MURDERER"
        end

        PathMapStatus.Text = routeState
    end

    if PathMapTarget then
        if LivePathTarget and LivePathTarget.Parent then
            PathMapTarget.Text = "Target: " .. tostring(LivePathTarget.Name)
        else
            PathMapTarget.Text = "Target: none"
        end
    end
end


local function isGroundedNear(position)
    local origin = position + Vector3.new(0, FARM_GROUND_RAY_HEIGHT, 0)
    local direction = Vector3.new(0, -FARM_GROUND_RAY_DEPTH, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    params.IgnoreWater = false

    return workspace:Raycast(origin, direction, params) ~= nil
end

local function pathStillReasonable(waypoints, currentPosition)
    if not waypoints or #waypoints == 0 then
        return false
    end

    local first = waypoints[1]
    if first and (first.Position - currentPosition).Magnitude > 28 then
        return false
    end

    return true
end

local function findBestPathCoin()
    if not RootPart or LastRole ~= "Innocent" then return nil, nil end

    local dangers = getDangerousPlayers()
    local nearbyThreat = false
    for _, danger in ipairs(dangers) do
        if danger.Distance <= DANGER_RADIUS then
            nearbyThreat = true
            break
        end
    end

    local candidates = {}
    local currentPosition = RootPart.Position

    for _, object in ipairs(CoinObjects) do
        if coinIsAvailable(object) and object ~= LastCollectedTarget and not coinIsBlacklisted(object) then
            local distance = (currentPosition - object.Position).Magnitude
            if distance <= CONFIG.CoinSearchRadius then
                local threatDistance = coinThreatDistance(object, dangers)
                if threatDistance >= SAFE_COIN_RADIUS then
                    table.insert(candidates, {
                        Object = object,
                        Distance = distance,
                        ThreatDistance = threatDistance,
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if nearbyThreat then
            return a.ThreatDistance > b.ThreatDistance
        end
        return a.Distance < b.Distance
    end)

    local bestObject, bestPath, bestScore = nil, nil, math.huge
    local checked = math.min(#candidates, FARM_CANDIDATE_LIMIT)

    for index = 1, checked do
        local candidate = candidates[index]
        local targetPosition = getFarmTargetPosition(candidate.Object)
        local path, waypoints
        if targetPosition then
            path, waypoints = createFarmPath(currentPosition, targetPosition)
        end
        if path and waypoints and pathIsSafe(waypoints, dangers) then
            local length = pathLength(waypoints, currentPosition)
            local threatBonus = math.max(0, SAFE_COIN_RADIUS - candidate.ThreatDistance)
            local score = length + threatBonus * 3

            if score < bestScore then
                bestScore = score
                bestObject = candidate.Object
                bestPath = path
            end
        end
    end

    if bestObject and bestPath then
        LivePathTarget = bestObject
        LivePathWaypoints = bestPath:GetWaypoints()
        LivePathTimestamp = os.clock()
    elseif not bestObject and nearbyThreat then
        LivePathWaypoints = nil
        LivePathTarget = nil
        if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
        if FarmDebugPhase then FarmDebugPhase.Text = "Status: AVOIDING THREAT" end
    end

    return bestObject, bestPath
end

local function updateCoinLabel()
    if CoinLabel then
        CoinLabel.Text = "COINS " .. tostring(State.CoinCount) .. "/" .. tostring(State.CoinGoal)
    end
    if FarmDebugCoins then
        FarmDebugCoins.Text = "Coins: " .. tostring(State.CoinCount) .. "/" .. tostring(State.CoinGoal)
    end
end

local function readCurrencyValue()
    local values = {
        LocalPlayer:FindFirstChild("Coins"),
        LocalPlayer:FindFirstChild("CoinCount"),
        LocalPlayer:FindFirstChild("Currency"),
        LocalPlayer:FindFirstChild("Cash"),
    }

    for _, value in ipairs(values) do
        if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
            local number = tonumber(value.Value)
            if number and number >= 0 then
                return number
            end
        end
    end

    return nil
end

local function beginRoundCounter()
    RoundCurrencyBaseline = readCurrencyValue()
    RoundStarted = true
    LobbyTeleportStarted = false
    State.CoinCount = 0
    updateCoinLabel()
end

local function observedRoundCoinCount()
    local current = readCurrencyValue()
    if current == nil then
        return nil
    end

    if RoundCurrencyBaseline == nil then
        RoundCurrencyBaseline = current
        return 0
    end

    return math.max(0, math.floor(current - RoundCurrencyBaseline + 0.0001))
end

local function coinWasCollected(object, originalParent, originalTransparency)
    if not object then return true end
    if not object.Parent then return true end
    if object.Parent ~= originalParent then return true end
    if object.Transparency >= 0.98 then return true end
    if originalTransparency < 0.98 and object.Transparency - originalTransparency >= 0.45 then
        return true
    end
    return false
end

local function verifyCoinCollected(object, beforeObserved, originalParent, originalTransparency)
    if not object then return false end
    local deadline = os.clock() + FARM_VERIFY_TIMEOUT

    while os.clock() < deadline do
        local observed = observedRoundCoinCount()
        if observed ~= nil and beforeObserved ~= nil and observed > beforeObserved then
            return true
        end

        if coinWasCollected(object, originalParent, originalTransparency) then
            return true
        end

        task.wait(FARM_VERIFY_STEP)
    end

    return false
end

local function followFarmPath(path, target)
    if not path or not target or not Humanoid or not RootPart then return false end

    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then return false end

    local repaths = 0
    local index = 1
    local lastProgress = os.clock()
    local lastDistance = math.huge
    local lastMoveRefresh = 0

    while index <= #waypoints do
        if not isAlive() or LastRole ~= "Innocent" or not coinIsAvailable(target) then
            return false
        end

        local dangers = getDangerousPlayers()
        for _, danger in ipairs(dangers) do
            if danger.Root and danger.Root.Parent
                and (danger.Root.Position - RootPart.Position).Magnitude < DANGER_RADIUS then
                Humanoid:Move(Vector3.zero)
                return false
            end
        end

        if not isGroundedNear(RootPart.Position) then
            task.wait(0.08)
        end

        local waypoint = waypoints[index]
        if not waypoint or not waypoint.Position then
            repaths += 1
            if repaths > FARM_REPATH_LIMIT then return false end
            local targetPosition = getFarmTargetPosition(target) or target.Position
            local newPath, newWaypoints = createFarmPath(RootPart.Position, targetPosition)
            if not newPath or not newWaypoints or not pathIsSafe(newWaypoints, dangers) then
                return false
            end
            path, waypoints, index = newPath, newWaypoints, 1
            LivePathWaypoints, LivePathTarget, LivePathTimestamp = newWaypoints, target, os.clock()
            continue
        end

        local distanceToWaypoint = (RootPart.Position - waypoint.Position).Magnitude
        if distanceToWaypoint <= 3 then
            index += 1
            lastProgress = os.clock()
            lastDistance = math.huge
            continue
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            Humanoid.Jump = true
        end

        if FarmDebugPhase then
            FarmDebugPhase.Text = "Status: WALKING WAYPOINT " .. tostring(index) .. "/" .. tostring(#waypoints)
        end

        -- MoveTo is refreshed periodically instead of resetting the waypoint index.
        -- The previous v4 code replanned every 0.7s and reset index to 1, which could
        -- keep the character oscillating around the first waypoint forever.
        Humanoid:MoveTo(waypoint.Position)
        lastMoveRefresh = os.clock()

        local deadline = os.clock() + math.max(6.5, FARM_WAYPOINT_TIMEOUT)
        local finished = false
        local reached = false
        local connection
        connection = Humanoid.MoveToFinished:Connect(function(success)
            reached = success
            finished = true
        end)

        while not finished and os.clock() < deadline do
            if not isAlive() or LastRole ~= "Innocent" then
                break
            end

            for _, danger in ipairs(getDangerousPlayers()) do
                if danger.Root and danger.Root.Parent
                    and (danger.Root.Position - RootPart.Position).Magnitude < DANGER_RADIUS then
                    Humanoid:Move(Vector3.zero)
                    finished, reached = true, false
                    break
                end
            end
            if finished then break end

            local currentDistance = (RootPart.Position - waypoint.Position).Magnitude
            if currentDistance <= 3 then
                reached, finished = true, true
                break
            end

            if currentDistance + 0.25 < lastDistance then
                lastDistance = currentDistance
                lastProgress = os.clock()
            elseif os.clock() - lastProgress > 1.8 then
                -- Stalled: stop waiting and replan from the actual position.
                finished, reached = true, false
                break
            end

            -- Roblox documents that MoveTo times out after 8 seconds; refreshing
            -- before that keeps a legitimate walking request alive.
            if os.clock() - lastMoveRefresh >= 5.5 then
                Humanoid:MoveTo(waypoint.Position)
                lastMoveRefresh = os.clock()
            end

            task.wait(0.08)
        end

        if connection then connection:Disconnect() end

        if reached then
            index += 1
            continue
        end

        Humanoid:Move(Vector3.zero)
        repaths += 1
        if repaths > FARM_REPATH_LIMIT then
            return false
        end

        local targetPosition = getFarmTargetPosition(target) or target.Position
        local newPath, newWaypoints = createFarmPath(RootPart.Position, targetPosition)
        if not newPath or not newWaypoints then
            return false
        end
        if not pathIsSafe(newWaypoints, getDangerousPlayers()) then
            return false
        end

        path, waypoints, index = newPath, newWaypoints, 1
        LivePathWaypoints, LivePathTarget, LivePathTimestamp = newWaypoints, target, os.clock()
    end

    Humanoid:Move(Vector3.zero)
    unlockBadge("4")
    unlockBadge("5")
    unlockBadge("11")
    return true
end

local function farmOneCoin(target, precomputedPath)
    if not target or not coinIsAvailable(target) or LastRole ~= "Innocent" then return false end

    local beforeObserved = observedRoundCoinCount()
    local originalParent = target.Parent
    local originalTransparency = target.Transparency

    if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
    if FarmDebugPhase then FarmDebugPhase.Text = "Status: CALCULATING SAFE PATH" end

    for attempt = 1, FARM_TARGET_RETRIES do
        if LastRole ~= "Innocent" or not isAlive() then
            return false
        end

        if not coinIsAvailable(target) then
            clearCoinFailure(target)
            return true
        end

        if coinIsBlacklisted(target) then
            return false
        end

        local dangers = getDangerousPlayers()
        if coinThreatDistance(target, dangers) < SAFE_COIN_RADIUS then
            if FarmDebugPhase then FarmDebugPhase.Text = "Status: AVOIDING THREAT" end
            return false
        end

        local path = precomputedPath
        local waypoints
        if not path then
            local targetPosition = getFarmTargetPosition(target) or target.Position
            path, waypoints = createFarmPath(RootPart.Position, targetPosition)
        else
            waypoints = path:GetWaypoints()
        end

        if path and waypoints and pathIsSafe(waypoints, dangers) then
            if followFarmPath(path, target) then
                if FarmDebugPhase then FarmDebugPhase.Text = "Status: COLLECTING" end
                if verifyCoinCollected(target, beforeObserved, originalParent, originalTransparency) then
                    clearCoinFailure(target)
                    LivePathWaypoints = nil
                    LivePathTarget = nil
                    LivePathTimestamp = os.clock()
                    return true
                end
            end
        end

        precomputedPath = nil
        if attempt < FARM_TARGET_RETRIES then
            if FarmDebugPhase then FarmDebugPhase.Text = "Status: REPLANNING" end
            task.wait(0.12)
        end
    end

    blacklistCoin(target)
    LivePathWaypoints = nil
    LivePathTarget = nil
    LivePathTimestamp = os.clock()
    if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
    if FarmDebugPhase then FarmDebugPhase.Text = "Status: COIN FAILED" end
    return false
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
--// LIVE PATH MAP PAGE
--//==============================================================
do
    local page = Pages.Map

    section(page, "LIVE PATH MAP")

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -5, 0, 32)
    info.BackgroundTransparency = 1
    info.Text = "Live top-down map. Green = route • Red = murderer • Yellow = coins • Blue/Gold = players."
    info.TextColor3 = Color3.fromRGB(150, 165, 195)
    info.Font = Enum.Font.Gotham
    info.TextSize = 8
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = page

    PathMapCanvas = Instance.new("Frame")
    PathMapCanvas.Name = "LivePathMap"
    PathMapCanvas.Size = UDim2.new(1, -5, 0, 188)
    PathMapCanvas.BackgroundColor3 = Color3.fromRGB(5, 9, 22)
    PathMapCanvas.BorderSizePixel = 0
    PathMapCanvas.ClipsDescendants = true
    PathMapCanvas.Parent = page

    local mapCorner = Instance.new("UICorner")
    mapCorner.CornerRadius = UDim.new(0, 12)
    mapCorner:SetAttribute("PathMapStatic", true)
    mapCorner.Parent = PathMapCanvas

    local mapStroke = Instance.new("UIStroke")
    mapStroke.Color = Color3.fromRGB(50, 75, 125)
    mapStroke.Transparency = 0.25
    mapStroke:SetAttribute("PathMapStatic", true)
    mapStroke.Parent = PathMapCanvas

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 18)
    title.Position = UDim2.fromOffset(7, 5)
    title.BackgroundTransparency = 1
    title.Text = "PATHFINDING • LIVE"
    title.TextColor3 = Color3.fromRGB(120, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 8
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 20
    title:SetAttribute("PathMapStatic", true)
    title.Parent = PathMapCanvas

    PathMapStatus = Instance.new("TextLabel")
    PathMapStatus.Size = UDim2.new(1, -12, 0, 18)
    PathMapStatus.Position = UDim2.new(0, 7, 1, -22)
    PathMapStatus.BackgroundTransparency = 1
    PathMapStatus.Text = "WAITING FOR SAFE PATH"
    PathMapStatus.TextColor3 = Color3.fromRGB(130, 155, 195)
    PathMapStatus.Font = Enum.Font.GothamBold
    PathMapStatus.TextSize = 7
    PathMapStatus.TextXAlignment = Enum.TextXAlignment.Left
    PathMapStatus.ZIndex = 20
    PathMapStatus:SetAttribute("PathMapStatic", true)
    PathMapStatus.Parent = PathMapCanvas

    PathMapTarget = Instance.new("TextLabel")
    PathMapTarget.Size = UDim2.fromOffset(130, 18)
    PathMapTarget.Position = UDim2.new(1, -137, 1, -22)
    PathMapTarget.BackgroundTransparency = 1
    PathMapTarget.Text = "Target: none"
    PathMapTarget.TextColor3 = Color3.fromRGB(255, 220, 105)
    PathMapTarget.Font = Enum.Font.GothamBold
    PathMapTarget.TextSize = 7
    PathMapTarget.TextXAlignment = Enum.TextXAlignment.Right
    PathMapTarget.ZIndex = 20
    PathMapTarget:SetAttribute("PathMapStatic", true)
    PathMapTarget.Parent = PathMapCanvas

    toggle(
        page,
        "Show Live Path",
        "Draw the actual PathfindingService waypoints selected for the current coin.",
        "PathDiagram"
    )

    toggle(
        page,
        "Show Coins",
        "Show nearby detected coins as yellow markers.",
        "PathDiagramCoins"
    )

    toggle(
        page,
        "Show Murderer Zone",
        "Show the murderer position and the danger radius used by the farm.",
        "PathDiagramDanger"
    )

    toggle(
        page,
        "Show Obstacles",
        "Approximate nearby collidable map parts from a top-down view.",
        "PathDiagramObstacles"
    )

    toggle(
        page,
        "Show Players",
        "Show live nearby player positions on the top-down map.",
        "PathDiagramPlayers"
    )

    button(
        page,
        "Center Live Map",
        "Refresh the diagram around your current character position.",
        function()
            LivePathTimestamp = 0
            refreshPathMap(true)
        end
    )

    button(
        page,
        "Clear Route Preview",
        "Hide the currently remembered route until a new path is selected.",
        function()
            LivePathWaypoints = nil
            LivePathTarget = nil
            refreshPathMap(true)
        end
    )
end

--//==============================================================
--// UNIVERSAL VISUAL HELPERS
--//==============================================================
local GhostOriginalTransparency = {}
local SpinWarningGui

applyGhostVisual = function(enabled)
    if not Character then return end
    for _, object in ipairs(Character:GetDescendants()) do
        if object:IsA("BasePart") then
            if GhostOriginalTransparency[object] == nil then
                GhostOriginalTransparency[object] = object.LocalTransparencyModifier
            end
            object.LocalTransparencyModifier = enabled and math.clamp(tonumber(State.GhostTransparency) or 1, 0, 1) or GhostOriginalTransparency[object]
        elseif object:IsA("Decal") or object:IsA("Texture") then
            if GhostOriginalTransparency[object] == nil then
                GhostOriginalTransparency[object] = object.Transparency
            end
            object.Transparency = enabled and math.clamp(tonumber(State.GhostTransparency) or 1, 0, 1) or GhostOriginalTransparency[object]
        end
    end
    if not enabled then
        for object, original in pairs(GhostOriginalTransparency) do
            if object and object.Parent then
                pcall(function()
                    if object:IsA("BasePart") then object.LocalTransparencyModifier = original else object.Transparency = original end
                end)
            end
            GhostOriginalTransparency[object] = nil
        end
    end
end

showSpinWarning = function(gameName)
    if not MainGui then return end
    if SpinWarningGui and SpinWarningGui.Parent then SpinWarningGui:Destroy() end
    SpinWarningGui = Instance.new("Frame")
    SpinWarningGui.Name = "SpinWarning"
    SpinWarningGui.Size = UDim2.fromOffset(math.min(MENU_WIDTH - 30, 430), 190)
    SpinWarningGui.Position = UDim2.new(0.5, -math.min(MENU_WIDTH - 30, 430)/2, 0.5, -95)
    SpinWarningGui.BackgroundColor3 = Color3.fromRGB(22, 6, 10)
    SpinWarningGui.BorderSizePixel = 0
    SpinWarningGui.ZIndex = 1000
    SpinWarningGui.Parent = MainGui
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,14); c.Parent=SpinWarningGui
    local st=Instance.new("UIStroke"); st.Color=Color3.fromRGB(255,45,65); st.Thickness=2; st.Parent=SpinWarningGui
    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-24,0,32); title.Position=UDim2.fromOffset(12,10); title.BackgroundTransparency=1; title.Text="⚠ WARNING"; title.TextColor3=Color3.fromRGB(255,65,85); title.Font=Enum.Font.GothamBlack; title.TextSize=16; title.Parent=SpinWarningGui
    local body=Instance.new("TextLabel"); body.Size=UDim2.new(1,-28,0,82); body.Position=UDim2.fromOffset(14,48); body.BackgroundTransparency=1; body.Text="IF YOU DO THIS YOU MAY GO INTO NOCLIP AND WILL NOT BE ABLE TO COLLIDE WITH OTHER PLAYERS OR OBJECTS TO AVOID FLINGING OTHER PLAYERS.\n\nValues above 600 are safety-limited by WindTurf."; body.TextWrapped=true; body.TextColor3=Color3.fromRGB(235,220,225); body.Font=Enum.Font.GothamSemibold; body.TextSize=9; body.Parent=SpinWarningGui
    local close=Instance.new("TextButton"); close.Size=UDim2.new(1,-28,0,34); close.Position=UDim2.fromOffset(14,142); close.BackgroundColor3=Color3.fromRGB(175,22,42); close.BorderSizePixel=0; close.Text="I UNDERSTAND"; close.TextColor3=Color3.new(1,1,1); close.Font=Enum.Font.GothamBold; close.TextSize=9; close.Parent=SpinWarningGui
    local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,9); cc.Parent=close
    close.MouseButton1Click:Connect(function() if SpinWarningGui then SpinWarningGui:Destroy(); SpinWarningGui=nil end end)
end

--//==============================================================
--// NATURAL DISASTER SURVIVAL SAFE MOVEMENT HELPERS
--//==============================================================
local NaturalDisasterJumpConnection
local OriginalWorkspaceGravity = workspace.Gravity
local NaturalDisasterSpinAngle = 0

local function setupNaturalDisasterInfiniteJump()
    if NaturalDisasterJumpConnection then pcall(function() NaturalDisasterJumpConnection:Disconnect() end); NaturalDisasterJumpConnection=nil end
    if not State.NDSInfiniteJump then return end
    NaturalDisasterJumpConnection = UserInputService.JumpRequest:Connect(function()
        if State.NDSInfiniteJump and Humanoid and Humanoid.Parent and Humanoid.Health > 0 then
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

setupNaturalDisasterInfiniteJump()

--//==============================================================
--// PRISON LIFE SAFE MOVEMENT HELPERS
--//==============================================================
local PrisonLifeSpinAngle = 0
local PrisonLifeJumpConnection

local function isCrouchingForPrisonLife()
    if not Character then return false end

    local names = {"Crouching", "Crouch", "IsCrouching", "Crouched"}
    for _, name in ipairs(names) do
        local child = Character:FindFirstChild(name, true)
        if child and child:IsA("BoolValue") and child.Value == true then
            return true
        end
    end

    for _, name in ipairs(names) do
        local ok, value = pcall(function()
            return Character:GetAttribute(name)
        end)
        if ok and value == true then
            return true
        end
    end

    return false
end

local function setupPrisonLifeInfiniteJump()
    if PrisonLifeJumpConnection then
        pcall(function() PrisonLifeJumpConnection:Disconnect() end)
        PrisonLifeJumpConnection = nil
    end

    if not State.PLInfiniteJump then return end

    PrisonLifeJumpConnection = UserInputService.JumpRequest:Connect(function()
        if State.PLInfiniteJump and isAlive() then
            pcall(function()
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end)
end

setupPrisonLifeInfiniteJump()

--//==============================================================
--// MAIN RUNTIME LOOP
--//==============================================================
local LastRole = "Unknown"
local PreviousRole = "Unknown"
local LastRoleUpdate = 0

connect("MainRuntime", RunService.Heartbeat, function()
    if Destroyed then
        return
    end

    if os.clock() - LastRoleUpdate > 0.5 then
        PreviousRole = LastRole
        LastRole = getRole()

        if LastRole == "Innocent" and (PreviousRole ~= "Innocent" or not RoundStarted) then
            beginRoundCounter()
        end

        if LastRole == "Sheriff" then
            KnownSheriffUserId = LocalPlayer.UserId
        end
        LastRoleUpdate = os.clock()

        if RoleLabel then
            RoleLabel.Text = "ROLE • " .. LastRole
        end

        if StatusLabel and not LobbyTeleportStarted then
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


    if State.Ghost and Character then
        applyGhostVisual(true)
    elseif not State.Ghost and next(GhostOriginalTransparency) ~= nil then
        applyGhostVisual(false)
    end

    -- Prison Life safe movement tools. These only modify the local character's
    -- ordinary movement properties and do not touch combat remotes or bypasses.
    if isAlive() then
        if State.PLWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.PLWalkSpeedValue) or 28, 1, 200)
        elseif not State.PLCrouchSpeed then
            -- Only restore the default if our Prison Life movement toggles were
            -- previously responsible for the speed. The normal script remains
            -- free to change WalkSpeed when the feature is disabled.
            if Humanoid.WalkSpeed > 50 then
                Humanoid.WalkSpeed = 16
            end
        end

        if State.PLCrouchSpeed and isCrouchingForPrisonLife() then
            Humanoid.WalkSpeed = 24
        elseif State.PLWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.PLWalkSpeedValue) or 28, 1, 200)
        end

        if State.PLSpin and RootPart then
            PrisonLifeSpinAngle += math.rad(math.clamp(tonumber(State.PLSpinSpeed) or 90, 1, 600)) * (1/60)
            RootPart.CFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, PrisonLifeSpinAngle, 0)
        end

        if State.NDSSpin and RootPart then
            NaturalDisasterSpinAngle += math.rad(math.clamp(tonumber(State.NDSSpinSpeed) or 45, 1, 600)) * (1/60)
            RootPart.CFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, NaturalDisasterSpinAngle, 0)
        end

        if State.NDSWalkSpeed then
            Humanoid.WalkSpeed = math.clamp(tonumber(State.NDSWalkSpeedValue) or 32, 1, 200)
        end

        if State.NDSLowGravity then
            workspace.Gravity = math.clamp(OriginalWorkspaceGravity * 0.45, 20, OriginalWorkspaceGravity)
        elseif workspace.Gravity ~= OriginalWorkspaceGravity and not State.NDSLowGravity then
            workspace.Gravity = OriginalWorkspaceGravity
        end

    end





    if LastRole == "Innocent" and RoundStarted then
        refreshRoundCounter()

        -- Check the goal even if the user temporarily disabled the farm.
        -- The intended bag target is 40 for non-Elite users; Elite's 50 does
        -- not change this script's configured return threshold.
        if State.CoinCount >= State.CoinGoal then
            State.CoinCount = State.CoinGoal
            updateCoinLabel()
            teleportToLobbyAfter40()
        end
    end

    if PathMapCanvas and State.PathDiagram then
        refreshPathMap(false)
    end

    if false and (State.AutoFarm or State.AutoCollect) and isAlive() then
        -- Autofarm is intentionally Innocent-only. Never continue farming
        -- after a role change or after the round goal has been reached.
        if LastRole ~= "Innocent" then
            FarmBusy = false
            LastCollectedTarget = nil
        else
            if os.clock() - LastCoinScan >= FARM_SCAN_INTERVAL then
                scanCoins()
            end

            if not FarmBusy then
                if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
                if FarmDebugPhase then FarmDebugPhase.Text = "Status: SCANNING" end
                local target, targetPath = findBestPathCoin()
                if target then
                    FarmBusy = true
                    LastCollectedTarget = target
                    LastCollectedPosition = target.Position

                    task.spawn(function()
                        local collected = false
                        if FarmDebugTarget then FarmDebugTarget.Text = "Target: " .. target.Name end
                        if FarmDebugStatus then FarmDebugStatus.Text = "● ACTIVE" end
                        if isAlive() and LastRole == "Innocent" then
                            collected = farmOneCoin(target, targetPath)
                        end

                        if collected then
                            local observed = observedRoundCoinCount()
                            local previousRoundCount = State.CoinCount

                            if observed ~= nil then
                                State.CoinCount = math.clamp(math.max(State.CoinCount, observed), 0, State.CoinGoal)
                            else
                                State.CoinCount = math.min(State.CoinCount + 1, State.CoinGoal)
                            end

                            local gained = math.max(0, State.CoinCount - previousRoundCount)
                            if gained > 0 then
                                State.LifetimeCoins = (tonumber(State.LifetimeCoins) or 0) + gained
                                unlockBadge("2") -- Coin Collector
                                if State.CoinCount >= State.CoinGoal then
                                    unlockBadge("3") -- 40 Coin Run
                                end
                                if State.LifetimeCoins >= 100 then
                                    unlockBadge("19") -- WindTurf Veteran
                                end
                                pcall(savePersistentData)
                            end

                            updateCoinLabel()
                            if FarmDebugPhase then FarmDebugPhase.Text = "Status: SCANNING" end
                        else
                            if FarmDebugPhase then FarmDebugPhase.Text = "Status: SCANNING NEXT COIN" end
                        end

                        LastCollectedTarget = nil
                        LastCollectedPosition = nil
                        FarmBusy = false
                    end)
                end
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

    -- Reconcile the sheriff/hero identity before coloring anything. If the
    -- old sheriff no longer has the gun, the next current gun holder becomes
    -- the sheriff; this lets the Hero color update after the sheriff dies.
    local currentSheriffStillHasGun = false
    if KnownSheriffUserId then
        local known = Players:GetPlayerByUserId(KnownSheriffUserId)
        currentSheriffStillHasGun = known and findToolByNames({"gun", "sheriff", "revolver"}, known) ~= nil
    end

    if not currentSheriffStillHasGun then
        KnownSheriffUserId = nil
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character
                and findToolByNames({"gun", "sheriff", "revolver"}, player) then
                KnownSheriffUserId = player.UserId
                break
            end
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
--// v11 FEATURE MODULES
--// Safe rebuild: visualization, detection, pathfinding and normal movement.
--// Server-bypass combat, fling, collision bypass, and exploit teleport loops
--// are intentionally not active in this build.
--//==============================================================
local Feature = {
    Radar = false,
    Threats = true,
    Proximity = false,
    Breadcrumbs = false,
    SmartWaypoints = false,
    OrbitCamera = false,
    FreeCamera = false,
    ShelterFinder = false,
    DisasterGuidance = true,
    FallWarning = true,
    HazardDirection = true,
    PlayerShelterTracker = false,
    StormVisibility = false,
    PrisonMarkers = false,
    WantedTracker = false,
    TaserWarning = true,
    ArrestWarning = true,
    WeaponFinder = false,
    RoleTracker = true,
    AutoArrest = false,
    ArrestRadius = 12,
    ArrestRepathSeconds = 1.2,
}

local FeatureObjects = {}
local BreadcrumbPoints = {}
local CameraSavedCFrame = nil
local OrbitAngle = 0
local LastFeatureNotice = 0
local LastRadarRefresh = 0

local function featureNotify(title, msg)
    if os.clock() - LastFeatureNotice > 2 then
        LastFeatureNotice = os.clock()
        notify(title, msg, 3)
    end
end

local function getPlaceNameSafe()
    local name = "Unknown Place"
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then name = tostring(info.Name) end
    end)
    return name
end

local function isNDSPlace()
    return string.find(string.lower(getPlaceNameSafe()), "natural disaster survival", 1, true) ~= nil
end

local function isPrisonPlace()
    return string.find(string.lower(getPlaceNameSafe()), "prison life", 1, true) ~= nil
end

local function clearFeatureObjects()
    for _, obj in ipairs(FeatureObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(FeatureObjects)
end

local function marker(position, text, color)
    if typeof(position) ~= "Vector3" then return end
    local part = Instance.new("Part")
    part.Name = "WindTurfMarker"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Transparency = 1
    part.Size = Vector3.new(1,1,1)
    part.Position = position
    part.Parent = workspace
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(150, 32)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = part
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1,1)
    label.BackgroundColor3 = color or Color3.fromRGB(20,20,30)
    label.BackgroundTransparency = 0.15
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.Parent = bb
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = label
    table.insert(FeatureObjects, part)
end

local function refreshPlayerMarkers()
    clearFeatureObjects()
    if not Feature.Radar then return end
    if not RootPart then return end
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)
            if root then
                local d = (root.Position - RootPart.Position).Magnitude
                if d <= 300 then
                    local role = getPlayerRole(player)
                    local label = player.Name .. " • " .. math.floor(d) .. "m"
                    if Feature.RoleTracker and role ~= "Unknown" then label = label .. " • " .. role end
                    marker(root.Position, label, role == "Murderer" and Color3.fromRGB(120,20,30) or Color3.fromRGB(20,45,85))
                    count += 1
                    if count >= 30 then break end
                end
            end
        end
    end
end

local function refreshPrisonMarkers()
    clearFeatureObjects()
    if not RootPart then return end
    local names = {
        {"Prison", Vector3.new(0,0,0)},
        {"Yard", Vector3.new(0,0,0)},
    }
    -- Prefer actual named parts/models when available; no hard-coded teleport is performed.
    for _, pair in ipairs(names) do
        local obj = workspace:FindFirstChild(pair[1], true)
        if obj then
            local pos = obj:IsA("BasePart") and obj.Position or (obj:IsA("Model") and obj:GetPivot().Position)
            if pos then marker(pos, pair[1], Color3.fromRGB(70,30,90)) end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local root = getAliveRoot(player)
            if root and (root.Position - RootPart.Position).Magnitude < 180 then
                local role = getPlayerRole(player)
                if Feature.RoleTracker then marker(root.Position, player.Name .. " • " .. role, Color3.fromRGB(25,55,90)) end
            end
        end
    end
end

local function findShelterCandidates()
    local out = {}
    if not RootPart then return out end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.X >= 5 and obj.Size.Z >= 5 and obj.Size.Y >= 2 then
            local d = (obj.Position - RootPart.Position).Magnitude
            if d <= 350 and obj.Position.Y >= RootPart.Position.Y - 10 then
                table.insert(out, {part=obj, distance=d})
            end
        end
        if #out >= 40 then break end
    end
    table.sort(out, function(a,b) return a.distance < b.distance end)
    return out
end

local function refreshNDSMarkers()
    clearFeatureObjects()
    if not RootPart then return end
    local shelters = findShelterCandidates()
    for i = 1, math.min(6, #shelters) do
        local s = shelters[i]
        marker(s.part.Position, "SHELTER • " .. math.floor(s.distance) .. "m", Color3.fromRGB(20,80,55))
    end
    if Feature.PlayerShelterTracker then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = getAliveRoot(player)
                if root then marker(root.Position, player.Name, Color3.fromRGB(30,50,85)) end
            end
        end
    end
end

local function smartWaypoint(targetPosition)
    if not RootPart or typeof(targetPosition) ~= "Vector3" then return false end
    local path = PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true})
    local ok = pcall(function() path:ComputeAsync(RootPart.Position, targetPosition) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        featureNotify("Routes", "No safe path found.")
        return false
    end
    LivePathWaypoints = path:GetWaypoints()
    featureNotify("Routes", "Safe path calculated: " .. tostring(#LivePathWaypoints) .. " waypoints.")
    return true
end

local function addBreadcrumb()
    if not RootPart or not Feature.Breadcrumbs then return end
    table.insert(BreadcrumbPoints, RootPart.Position)
    if #BreadcrumbPoints > 80 then table.remove(BreadcrumbPoints, 1) end
end

local function restoreCamera()
    local camera = workspace.CurrentCamera
    if camera and CameraSavedCFrame then
        camera.CameraType = Enum.CameraType.Custom
        pcall(function() camera.CFrame = CameraSavedCFrame end)
    end
    CameraSavedCFrame = nil
end

local function applyFeatureGhost(enabled)
    applyGhostVisual = applyGhostVisual or function() end
    pcall(function() applyGhostVisual(enabled) end)
end

-- RADAR
 do
    local page = Pages.Radar
    section(page, "PLAYER RADAR / THREAT SCANNER")
    toggle(page,"Player Radar","Show nearby players with distance and detectable role labels.","__Radar",function(v) Feature.Radar=v; refreshPlayerMarkers() end)
    toggle(page,"Threat Scanner","Highlights nearby players whose detectable role or movement suggests caution.","__Threats",function(v) Feature.Threats=v end)
    toggle(page,"Proximity Alerts","Notify when another player gets very close.","__Proximity",function(v) Feature.Proximity=v end)
    toggle(page,"Role Tracker","Show detectable MM2 roles on radar markers.","__Roles",function(v) Feature.RoleTracker=v; refreshPlayerMarkers() end)
    button(page,"Refresh Radar","Rebuild the current player marker list.",function() refreshPlayerMarkers() end)
    button(page,"Clear Markers","Remove radar and game markers.",function() clearFeatureObjects() end)
 end

-- NDS
 do
    local page = Pages.NDS
    section(page,"NATURAL DISASTER SURVIVAL")
    toggle(page,"Disaster Guidance","Local guidance based on visible map/environment cues.","__NDSGuidance",function(v) Feature.DisasterGuidance=v end)
    toggle(page,"Shelter Finder","Mark nearby large elevated structures as possible shelter candidates.","__Shelter",function(v) Feature.ShelterFinder=v; if v then refreshNDSMarkers() end end)
    toggle(page,"Hazard Direction","Show a warning when nearby hazards or high-risk areas are detected.","__Hazard",function(v) Feature.HazardDirection=v end)
    toggle(page,"Fall Warning","Warn when your vertical drop becomes unusually large.","__Fall",function(v) Feature.FallWarning=v end)
    toggle(page,"Player Shelter Tracker","Mark nearby players so you can see where everyone is grouping.","__NDSPlayers",function(v) Feature.PlayerShelterTracker=v; refreshNDSMarkers() end)
    toggle(page,"Storm Visibility Mode","Reduce local visual clutter from heavy effects when possible.","__Storm",function(v) Feature.StormVisibility=v end)
    button(page,"Find Shelters Now","Scan the nearby map and mark likely shelter candidates.",function() Feature.ShelterFinder=true; refreshNDSMarkers() end)
    button(page,"NDS Quick Actions","Reset local movement and return the camera to normal.",function() restoreCamera(); if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; notify("NDS","Local controls reset.",2) end)
 end

-- PRISON LIFE
 do
    local page = Pages.Prison
    section(page,"PRISON LIFE • AWARENESS")
    toggle(page,"Role Detector","Detect visible team/role information where the game exposes it.","__PLRole",function(v) Feature.RoleTracker=v; refreshPrisonMarkers() end)
    toggle(page,"Wanted Tracker","Show a local warning when wanted/bounty-like values are visible on players.","__Wanted",function(v) Feature.WantedTracker=v end)
    toggle(page,"Taser Warning","Warn when a nearby player appears to have a taser tool equipped.","__Taser",function(v) Feature.TaserWarning=v end)
    toggle(page,"Arrest Warning","Warn when a nearby guard appears close enough to pose an arrest risk.","__Arrest",function(v) Feature.ArrestWarning=v end)
    toggle(page,"Auto Arrest","Use normal walking/pathfinding to approach a detected wanted/criminal player, then activate an exposed Handcuffs tool at close range.","AutoArrest",function(v) Feature.AutoArrest=v end)
    toggle(page,"Weapon Finder","Mark nearby visible tool/weapon objects without teleporting to them.","__Weapons",function(v) Feature.WeaponFinder=v end)
    toggle(page,"Prison Map Markers","Mark detectable prison locations and nearby player roles.","__PLMarkers",function(v) Feature.PrisonMarkers=v; refreshPrisonMarkers() end)
    button(page,"Refresh Prison Map","Re-scan the current place for detectable locations, tools and players.",function() refreshPrisonMarkers() end)
    button(page,"Safe Route Preview","Compute a normal PathfindingService route toward the nearest useful map object.",function()
        local nearest
        local best=math.huge
        if RootPart then
            for _,obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local d=(obj.Position-RootPart.Position).Magnitude
                    if d<best and d>12 and d<300 then nearest=obj; best=d end
                end
            end
        end
        if nearest then smartWaypoint(nearest.Position) else featureNotify("Routes","No nearby route target found.") end
    end)
    button(page,"Combat Safety","Auto-arrest uses normal Handcuffs activation and pathfinding; weapon teleport, player fling and combat bypass routines are excluded.",function() notify("WindTurf","Awareness only. No server-bypass combat automation.",3) end)
 end

-- ROUTES
 do
    local page = Pages.Routes
    section(page,"PATHS / WAYPOINTS")
    toggle(page,"Breadcrumb Trail","Record your recent local positions for a lightweight route history.","__Breadcrumb",function(v) Feature.Breadcrumbs=v end)
    toggle(page,"Smart Waypoints","Use Roblox PathfindingService to calculate normal walkable routes.","__Smart",function(v) Feature.SmartWaypoints=v end)
    button(page,"Route To Nearest Player","Calculate a path toward the nearest living player; does not move or target them.",function()
        local target
        local best=math.huge
        if RootPart then for _,pl in ipairs(Players:GetPlayers()) do if pl~=LocalPlayer then local r=getAliveRoot(pl); if r then local d=(r.Position-RootPart.Position).Magnitude; if d<best then best=d; target=r end end end end end
        if target then smartWaypoint(target.Position) else featureNotify("Routes","No living player found.") end
    end)
    button(page,"Clear Route","Clear the displayed path and breadcrumb history.",function() LivePathWaypoints=nil; table.clear(BreadcrumbPoints); notify("Routes","Route history cleared.",2) end)
    button(page,"Emergency Stop","Disable local movement helpers and restore normal camera/movement.",function() State.Fly=false; State.PLFly=false; State.Noclip=false; State.NDSNoclip=false; restoreCamera(); if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; notify("Routes","Emergency stop applied.",2) end)
 end

-- INSPECTOR
 do
    local page = Pages.Inspector
    section(page,"PLAYER / ENVIRONMENT INSPECTOR")
    button(page,"Environment Detector","Identify the current place and supported module family.",function()
        local info = "PlaceId " .. tostring(game.PlaceId) .. " • " .. tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown")
        notify("Environment", info, 5)
    end)
    button(page,"Inspect Nearest Player","Show name, distance, team and detectable role for the closest player.",function()
        local target; local best=math.huge
        if RootPart then for _,pl in ipairs(Players:GetPlayers()) do if pl~=LocalPlayer then local r=getAliveRoot(pl); if r then local d=(r.Position-RootPart.Position).Magnitude; if d<best then best=d; target=pl end end end end end
        if target then
            notify("Inspector",target.Name.." • "..math.floor(best).."m • team="..tostring(target.Team and target.Team.Name or "?").." • role="..tostring(getPlayerRole(target)),5)
        else notify("Inspector","No nearby player found.",3) end
    end)
    button(page,"Character Inspector","Show your current Humanoid/root state and health.",function()
        local hp=Humanoid and Humanoid.Health or 0
        notify("Character","Health "..math.floor(hp).." • WalkSpeed "..tostring(Humanoid and Humanoid.WalkSpeed or "?").." • Root "..tostring(RootPart~=nil),4)
    end)
    button(page,"Camera Reset","Restore normal Roblox camera control.",restoreCamera)
    button(page,"Spectator / Orbit Info","Local camera tools are kept separate from player targeting or movement automation.",function() notify("Inspector","Use the safe camera controls from Universal.",3) end)
 end

-- UNIVERSAL additions
 do
    local page=Pages.Universal
    section(page,"UNIVERSAL • EXTRA TOOLS")
    toggle(page,"Ghost / Invisible Visual","Local-only visual transparency; it does not make you server-invisible.","Ghost",function(v) Feature.Ghost=v; applyFeatureGhost(v) end)
    toggle(page,"Orbit Camera","Orbit the camera around your character without moving the character.","__Orbit",function(v) Feature.OrbitCamera=v; if not v then restoreCamera() end end)
    toggle(page,"Free Camera","Local camera mode; character stays where it is.","__FreeCam",function(v) Feature.FreeCamera=v; if v then CameraSavedCFrame=workspace.CurrentCamera and workspace.CurrentCamera.CFrame else restoreCamera() end end)
    toggle(page,"Breadcrumb Trail","Keep a local history of recent positions.","__BreadcrumbU",function(v) Feature.Breadcrumbs=v end)
    button(page,"Emergency Stop","Turn off movement helpers and restore normal camera/collision state.",function() State.Fly=false; State.PLFly=false; State.Noclip=false; State.NDSNoclip=false; Feature.OrbitCamera=false; Feature.FreeCamera=false; restoreCamera(); if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; notify("Universal","Emergency stop complete.",2) end)
    button(page,"Reset Character Movement","Restore normal WalkSpeed, AutoRotate and camera control.",function() restoreCamera(); if Humanoid then Humanoid.WalkSpeed=16; Humanoid.AutoRotate=true end; notify("Universal","Movement restored.",2) end)
    button(page,"Scan Environment","Run the universal environment detector.",function() notify("Environment","PlaceId="..tostring(game.PlaceId).." • NDS="..tostring(isNDSPlace()).." • Prison Life="..tostring(isPrisonPlace()),4) end)
 end

-- Feature heartbeat
connect("FeatureHeartbeat", RunService.Heartbeat, function(dt)
    if not RootPart then return end
    if Feature.Breadcrumbs then addBreadcrumb() end
    if Feature.Radar and os.clock() - LastRadarRefresh > 0.75 then LastRadarRefresh = os.clock(); refreshPlayerMarkers() end
    if Feature.Proximity or Feature.Threats then
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer then
                local r=getAliveRoot(pl)
                if r then
                    local d=(r.Position-RootPart.Position).Magnitude
                    if Feature.Proximity and d<12 then featureNotify("Proximity",""..pl.Name.." is very close.") end
                    if Feature.Threats and d<10 and getPlayerRole(pl)=="Murderer" then featureNotify("Threat","Detected murderer nearby.") end
                end
            end
        end
    end
    if Feature.AutoArrest and os.clock() - LastArrestPath > 1.2 then
        runAutoArrest()
    end
    if Feature.FallWarning and Humanoid and Humanoid.FloorMaterial==Enum.Material.Air and RootPart.AssemblyLinearVelocity.Y < -75 then
        featureNotify("Fall Warning","Large downward fall detected.")
    end
    if Feature.OrbitCamera and not Feature.FreeCamera then
        local cam=workspace.CurrentCamera
        if cam then
            CameraSavedCFrame = CameraSavedCFrame or cam.CFrame
            OrbitAngle += dt * 0.8
            local center=RootPart.Position + Vector3.new(0,3,0)
            local offset=Vector3.new(math.cos(OrbitAngle)*14,6,math.sin(OrbitAngle)*14)
            cam.CameraType=Enum.CameraType.Scriptable
            cam.CFrame=CFrame.lookAt(center+offset,center)
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


--//==============================================================
--// PERIODIC PROFILE SAVE
--//==============================================================
task.spawn(function()
    while not Destroyed do
        task.wait(30)
        if not Destroyed then
            pcall(savePersistentData)
        end
    end
end)
