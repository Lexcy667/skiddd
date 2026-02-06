-- LootHub ESP + ServerHop Only
-- Modified: Left Side Position + Removed Auto Collect
-- ================== Config ==================
local MAX_Y = 1183
local SETTINGS_FILE = "LootHubSettings_Lite.json" -- เปลี่ยนชื่อไฟล์เซฟแยกจากตัวเก่า

-- ================== Services ==================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

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

-- ================== Save / Load ==================
local function defaultSettings()
    return { ESP = true }
end

local function saveSettings()
    local data = {
        ESP = getgenv().ESPEnabled
    }
    writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
end

local function loadSettings()
    if isfile(SETTINGS_FILE) then
        local raw = readfile(SETTINGS_FILE)
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            getgenv().ESPEnabled = data.ESP
            return
        end
    end
    -- Default
    local def = defaultSettings()
    getgenv().ESPEnabled = def.ESP
end
loadSettings()

local function setESP(val)
    getgenv().ESPEnabled = val
    saveSettings()
end

-- ================== ESP ==================
local ESPs = {}
local ContainerName = "LootESP_Container"

local function lower(s) return tostring(s):lower() end

local function containsAny(s, keywords)
    if not s then return false end
    s = lower(s)
    for _,kw in ipairs(keywords) do
        if string.find(s, lower(kw), 1, true) then return true end
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

local function findLootCategory(inst)
    for _,loot in ipairs(LOOTS) do
        if containsAny(inst.Name, loot.keywords) then return loot end
    end
    return nil
end

local function getOrCreateContainer()
    local c = PlayerGui:FindFirstChild(ContainerName)
    if c then return c end
    c = Instance.new("Folder")
    c.Name = ContainerName
    c.Parent = PlayerGui
    return c
end

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
    txt.TextStrokeTransparency = 0.6

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
    local c = PlayerGui:FindFirstChild(ContainerName)
    if c then c:Destroy() end
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

-- ================== GUI ==================
local function createGUI()
    local old = PlayerGui:FindFirstChild("LootHub_GUI")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "LootHub_GUI"
    screen.ResetOnSpawn = false
    screen.Parent = PlayerGui

    -- Config Frame Size
    local frameWidth = 220
    local frameHeight = 130 -- ลดความสูงลงเพราะปุ่มน้อยลง

    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    
    -- *** Position: Left Middle ***
    -- AnchorPoint (0, 0.5) หมายถึงจุดอ้างอิงอยู่ซ้ายกึ่งกลางของเฟรม
    frame.AnchorPoint = Vector2.new(0, 0.5)
    -- Position (0, 20, 0.5, 0) หมายถึง ชิดซ้ายห่างออกมา 20px, กึ่งกลางจอเเนวตั้ง
    frame.Position = UDim2.new(0, 20, 0.5, 0)

    frame.BackgroundColor3 = Color3.fromRGB(20, 5, 5)
    frame.BorderSizePixel = 0
    frame.Active, frame.Draggable = true, true
    frame.Parent = screen

    -- RED Gradient
    local frameGradient = Instance.new("UIGradient")
    frameGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 30, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 0))
    }
    frameGradient.Rotation = 45
    frameGradient.Parent = frame

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(255, 50, 50)
    frameStroke.Thickness = 2
    frameStroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 30)
    title.Position = UDim2.new(0, 8, 0, 5)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "✨ เอาหินหนูไหม"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.fromRGB(150, 0, 0)
    title.Parent = frame

    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
    }
    titleGradient.Parent = title

    -- Animations
    local function openAnim()
        frame.Size = UDim2.new(0, 0, 0, 0)
        -- อนิเมชั่นเด้งออกจากซ้าย
        TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, frameWidth, 0, frameHeight)}):Play()
    end

    local function closeAnim()
        local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function() screen:Destroy() end)
    end

    local function btnClickAnim(btn)
        btn.MouseButton1Down:Connect(function()
             TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -20, 0, 28)}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
             TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -16, 0, 32)}):Play()
        end)
        btn.MouseLeave:Connect(function()
             TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(1, -16, 0, 32)}):Play()
        end)
    end

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -28, 0, 8)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    closeBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    closeBtn.Parent = frame
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0) end)
    closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0) end)
    closeBtn.MouseButton1Click:Connect(function() closeAnim() end)

    -- Button Creator Helper
    local function createButton(text, position, color, enabled)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 32)
        -- Adjust position logic for left aligned anchor
        btn.Position = position
        btn.AnchorPoint = Vector2.new(0.5, 0)
        btn.Position = UDim2.new(0.5, 0, position.Y.Scale, position.Y.Offset)

        btn.Text = text
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        btn.BackgroundColor3 = enabled and color or Color3.fromRGB(50, 10, 10)
        btn.Parent = frame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = enabled and color or Color3.fromRGB(80, 20, 20)
        btnStroke.Thickness = 1
        btnStroke.Parent = btn

        btnClickAnim(btn)

        btn.MouseEnter:Connect(function()
            local targetColor = enabled and Color3.fromRGB(math.min(255, color.R*255*1.2), math.min(255, color.G*255*1.2), math.min(255, color.B*255*1.2)) or Color3.fromRGB(70, 20, 20)
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        end)
        btn.MouseLeave:Connect(function()
            local targetColor = enabled and color or Color3.fromRGB(50, 10, 10)
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        end)

        return btn
    end

    local activeColor = Color3.fromRGB(200, 40, 40)
    local inactiveColor = Color3.fromRGB(50, 10, 10)

    -- ESP Button
    local espBtn = createButton(
        "🎯 ESP: " .. (getgenv().ESPEnabled and "เปิด" or "ปิด"),
        UDim2.new(0, 0, 0, 45),
        activeColor,
        getgenv().ESPEnabled
    )
    espBtn.MouseButton1Click:Connect(function()
        setESP(not getgenv().ESPEnabled)
        local isOn = getgenv().ESPEnabled
        if isOn then enableESP() else disableESP() end
        espBtn.Text = "🎯 ESP: " .. (isOn and "เปิด" or "ปิด")
        espBtn.BackgroundColor3 = isOn and activeColor or inactiveColor
        espBtn.UIStroke.Color = isOn and activeColor or Color3.fromRGB(80, 20, 20)
    end)

    -- Server Hop Button (ขยับขึ้นมาแทนที่ Auto เดิม)
    local hopBtn = Instance.new("TextButton")
    hopBtn.Size = UDim2.new(1, -16, 0, 32)
    hopBtn.AnchorPoint = Vector2.new(0.5, 0)
    hopBtn.Position = UDim2.new(0.5, 0, 0, 85) -- Position Y 85
    
    hopBtn.Text = "🌐 ย้ายเซิฟเวอร์"
    hopBtn.Font = Enum.Font.GothamBold
    hopBtn.TextSize = 12
    hopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hopBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    hopBtn.Parent = frame

    local hopBtnCorner = Instance.new("UICorner")
    hopBtnCorner.CornerRadius = UDim.new(0, 8)
    hopBtnCorner.Parent = hopBtn

    local hopBtnStroke = Instance.new("UIStroke")
    hopBtnStroke.Color = Color3.fromRGB(255, 50, 50)
    hopBtnStroke.Thickness = 2
    hopBtnStroke.Parent = hopBtn

    local hopBtnGradient = Instance.new("UIGradient")
    hopBtnGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 0))
    }
    hopBtnGradient.Rotation = 90
    hopBtnGradient.Parent = hopBtn
    
    btnClickAnim(hopBtn)

    hopBtn.MouseEnter:Connect(function()
        TweenService:Create(hopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 20, 20)}):Play()
    end)
    hopBtn.MouseLeave:Connect(function()
        TweenService:Create(hopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}):Play()
    end)
    hopBtn.MouseButton1Click:Connect(function()
        hopBtn.Text = "⏳ กำลังย้าย..."
        hopModule:Teleport(game.PlaceId)
    end)

    -- Shadow
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.BorderSizePixel = 0
    shadow.ZIndex = frame.ZIndex - 1
    shadow.Parent = screen
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Start Animation
    openAnim()
end

-- ================== Init ==================
if getgenv().ESPEnabled then
    enableESP()
end
createGUI()
