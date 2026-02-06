--[[
    LootHub Modified:
    - Position: Left Center
    - Theme: Red + RGB Stroke Cycle
    - Logic: Auto Collect toggles are mutually exclusive
]]

-- ================== Config ==================
local MAX_Y = 1183
local SETTINGS_FILE = "LootHubSettings_v2.json"

-- ================== Services ==================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ================== ServerHop ==================
local hopModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/LeoKholYt/roblox/main/lk_serverhop.lua"))()

-- ================== LOOTS ==================
local LOOTS = {
    {id = "Cosmic Relic", keywords = {"cosmic relic","cosmicrelic","cosmic"}, color = Color3.fromRGB(0,200,255)},
    {id = "Enchant Relic", keywords = {"enchant relic"}, color = Color3.fromRGB(255,100,255)},
    {id = "Void Wood", keywords = {"void wood"}, color = Color3.fromRGB(160,20,160)},
    {id = "Lunar Thread", keywords = {"lunar thread"}, color = Color3.fromRGB(120,140,255)},
    {id = "Starfall Totem", keywords = {"starfall totem"}, color = Color3.fromRGB(255,200,80)},
}

-- ================== Global State ==================
getgenv().ESPEnabled = true
getgenv().AutoCollectEnabled = false       -- Default OFF
getgenv().AutoCollectNoHopEnabled = false  -- Default OFF

-- ================== Save / Load ==================
local function saveSettings()
    local data = {
        ESP = getgenv().ESPEnabled,
        AutoCollect = getgenv().AutoCollectEnabled,
        AutoCollectNoHop = getgenv().AutoCollectNoHopEnabled
    }
    writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
end

local function loadSettings()
    if isfile(SETTINGS_FILE) then
        local raw = readfile(SETTINGS_FILE)
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            getgenv().ESPEnabled = data.ESP
            -- Load Auto states but prefer false if unsure to prevent instant hop loop
            getgenv().AutoCollectEnabled = data.AutoCollect or false
            getgenv().AutoCollectNoHopEnabled = data.AutoCollectNoHop or false
        end
    end
end
loadSettings()

-- ================== Helper Functions ==================
local function isItemHeldByPlayer(obj)
    local current = obj
    while current and current ~= Workspace do
        if current:IsA("Model") then
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character == current then return true end
            end
        end
        current = current.Parent
    end
    return false
end

local function getBasePart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _,d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    end
    return nil
end

local function lower(s) return tostring(s):lower() end
local function containsAny(s, keywords)
    if not s then return false end
    s = lower(s)
    for _,kw in ipairs(keywords) do
        if string.find(s, lower(kw), 1, true) then return true end
    end
    return false
end

local function findLootCategory(inst)
    for _,loot in ipairs(LOOTS) do
        if containsAny(inst.Name, loot.keywords) then return loot end
    end
    return nil
end

-- ================== ESP System ==================
local ESPs = {}
local ContainerName = "LootESP_Container"

local function getOrCreateContainer()
    local c = PlayerGui:FindFirstChild(ContainerName)
    if c then return c end
    c = Instance.new("Folder")
    c.Name = ContainerName
    c.Parent = PlayerGui
    return c
end

local function createBillboard(part, loot, obj)
    if not part or not part:IsDescendantOf(Workspace) then return end
    if part.Position.Y > MAX_Y then return end
    if ESPs[part] then return end
    if isItemHeldByPlayer(obj or part) then return end

    local container = getOrCreateContainer()
    local bg = Instance.new("BillboardGui")
    bg.Name = "ESP_" .. loot.id
    bg.Adornee = part
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 120, 0, 24)
    bg.StudsOffset = Vector3.new(0, 2.6, 0)
    bg.Parent = container

    local txt = Instance.new("TextLabel", bg)
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.TextScaled = true
    txt.Font = Enum.Font.SourceSansBold
    txt.Text = "★ " .. loot.id
    txt.TextColor3 = loot.color
    txt.TextStrokeTransparency = 0.3
    txt.TextStrokeColor3 = Color3.new(0,0,0)

    ESPs[part] = bg

    part.AncestryChanged:Connect(function(_, parent)
        if not part:IsDescendantOf(Workspace) or isItemHeldByPlayer(obj or part) then
            if ESPs[part] then
                ESPs[part]:Destroy()
                ESPs[part] = nil
            end
        end
    end)
end

local function enableESP()
    for _,desc in ipairs(Workspace:GetDescendants()) do
        local loot = findLootCategory(desc)
        if loot then
            local part = getBasePart(desc)
            if part and part.Position.Y <= MAX_Y and not isItemHeldByPlayer(desc) then
                createBillboard(part, loot, desc)
            end
        end
    end
end

local function disableESP()
    for _,bg in pairs(ESPs) do
        if bg and bg.Parent then bg:Destroy() end
    end
    ESPs = {}
end

Workspace.DescendantAdded:Connect(function(desc)
    if getgenv().ESPEnabled then
        local loot = findLootCategory(desc)
        if loot and not isItemHeldByPlayer(desc) then
            local part = getBasePart(desc)
            if part then createBillboard(part, loot, desc) end
        end
    end
end)

-- ================== Auto Collect Logic ==================
local function collectTargets()
    local found = false
    for _,obj in ipairs(Workspace:GetDescendants()) do
        local loot = findLootCategory(obj)
        if loot and obj:IsA("Model") and not isItemHeldByPlayer(obj) then
            local part = getBasePart(obj)
            if part then
                found = true
                if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
                    -- Teleport above
                    LocalPlayer.Character:PivotTo(part.CFrame + Vector3.new(0,5,0))
                    task.wait(0.5)
                    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then 
                        fireproximityprompt(prompt)
                        task.wait(0.5) -- Wait for collect
                    end
                end
            end
        end
    end
    return found
end

-- Loop: Auto Collect + Server Hop
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().AutoCollectEnabled then
            local relicFound = collectTargets()
            if not relicFound then
                -- No items found, wait a bit then check again or hop
                task.wait(3)
                if not collectTargets() then
                    -- Still nothing? HOP
                    hopModule:Teleport(game.PlaceId)
                end
            end
        end
    end
end)

-- Loop: Auto Collect Only (No Hop)
task.spawn(function()
    while task.wait(2) do
        if getgenv().AutoCollectNoHopEnabled then
            collectTargets()
        end
    end
end)

-- ================== GUI SYSTEM ==================
local function createGUI()
    local old = PlayerGui:FindFirstChild("LootHub_GUI_Red")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "LootHub_GUI_Red"
    screen.ResetOnSpawn = false
    screen.Parent = PlayerGui

    -- Main Frame (RED THEME)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 220)
    -- POSITION: Left Center
    frame.Position = UDim2.new(0, 20, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screen
    frame.ClipsDescendants = false

    local frameGradient = Instance.new("UIGradient")
    frameGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
    }
    frameGradient.Rotation = 45
    frameGradient.Parent = frame

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = frame

    -- RGB Stroke for Frame
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Thickness = 2
    frameStroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 35)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.FredokaOne
    title.Text = "LOOT HUB (แดง)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 22
    title.Parent = frame
    
    -- RGB Stroke for Title
    local titleStroke = Instance.new("UIStroke")
    titleStroke.Thickness = 1.5
    titleStroke.Parent = title

    -- RGB Cycle Logic
    task.spawn(function()
        local h = 0
        while screen.Parent do
            h = (h + 0.005) % 1
            local color = Color3.fromHSV(h, 1, 1)
            frameStroke.Color = color
            titleStroke.Color = color
            task.wait()
        end
    end)

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() screen:Destroy() end)

    -- Buttons Container
    local yOffset = 40
    local function makeButton(text, callback, defaultState)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 35)
        btn.Position = UDim2.new(0, 10, 0, yOffset)
        btn.Font = Enum.Font.GothamSemibold
        btn.Text = text
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(40, 40, 40)
        btn.Parent = frame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 50, 50)
        stroke.Thickness = 1
        stroke.Transparency = defaultState and 0 or 0.7
        stroke.Parent = btn

        -- Click Effect
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -24, 0, 31)}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -20, 0, 35)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -20, 0, 35)}):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            callback(btn, stroke)
        end)

        yOffset = yOffset + 40
        return btn, stroke
    end

    -- 1. ESP Toggle
    makeButton("👁️ ESP: " .. (getgenv().ESPEnabled and "ON" or "OFF"), function(btn, stroke)
        getgenv().ESPEnabled = not getgenv().ESPEnabled
        local isOn = getgenv().ESPEnabled
        
        btn.Text = "👁️ ESP: " .. (isOn and "ON" or "OFF")
        TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = isOn and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(40, 40, 40)}):Play()
        stroke.Transparency = isOn and 0 or 0.7
        
        if isOn then enableESP() else disableESP() end
        saveSettings()
    end, getgenv().ESPEnabled)

    -- 2. Auto Collect + HOP
    local btnHop, strokeHop -- Forward declaration
    local btnNoHop, strokeNoHop -- Forward declaration

    btnHop, strokeHop = makeButton("🚀 ออโต้+ย้ายเซิฟ: " .. (getgenv().AutoCollectEnabled and "ON" or "OFF"), function(btn, stroke)
        local newState = not getgenv().AutoCollectEnabled
        getgenv().AutoCollectEnabled = newState
        
        -- Disable NoHop if enabling Hop
        if newState then
            getgenv().AutoCollectNoHopEnabled = false
            btnNoHop.Text = "⚡ ออโต้ (ไม่ย้าย): OFF"
            TweenService:Create(btnNoHop, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
            strokeNoHop.Transparency = 0.7
        end

        btn.Text = "🚀 ออโต้+ย้ายเซิฟ: " .. (newState and "ON" or "OFF")
        TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = newState and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(40, 40, 40)}):Play()
        stroke.Transparency = newState and 0 or 0.7
        saveSettings()
    end, getgenv().AutoCollectEnabled)

    -- 3. Auto Collect (NO HOP)
    btnNoHop, strokeNoHop = makeButton("⚡ ออโต้ (ไม่ย้าย): " .. (getgenv().AutoCollectNoHopEnabled and "ON" or "OFF"), function(btn, stroke)
        local newState = not getgenv().AutoCollectNoHopEnabled
        getgenv().AutoCollectNoHopEnabled = newState

        -- Disable Hop if enabling NoHop
        if newState then
            getgenv().AutoCollectEnabled = false
            btnHop.Text = "🚀 ออโต้+ย้ายเซิฟ: OFF"
            TweenService:Create(btnHop, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
            strokeHop.Transparency = 0.7
        end

        btn.Text = "⚡ ออโต้ (ไม่ย้าย): " .. (newState and "ON" or "OFF")
        TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = newState and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(40, 40, 40)}):Play()
        stroke.Transparency = newState and 0 or 0.7
        saveSettings()
    end, getgenv().AutoCollectNoHopEnabled)

    -- 4. Manual Hop
    makeButton("🌐 ย้ายเซิฟเวอร์ (กดเลย)", function(btn, stroke)
        btn.Text = "⏳ กำลังย้าย..."
        hopModule:Teleport(game.PlaceId)
    end, false)

    -- Open Animation
    frame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 240, 0, 220)}):Play()
end

-- ================== Start ==================
if getgenv().ESPEnabled then enableESP() end
createGUI()
