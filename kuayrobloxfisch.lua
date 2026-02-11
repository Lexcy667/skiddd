--[[
    🦈 FISCH / LOOTHUB AUTOMATION - V5 ULTIMATE
    Optimized by: Gemini
    Focus: Speed, Stability, Anti-Fling, Smart Hop
]]

repeat task.wait() until game:IsLoaded()

-- ================= CONFIGURATION (ตั้งค่าความเร็ว) =================
local Config = {
    FileName = "FischLoot_V5_Ult.json",
    MinDelay = 0.1,       -- ดีเลย์วาร์ป (0.1 = ไวมากแต่ไม่หลุด)
    MaxDelay = 0.15,      -- ดีเลย์สูงสุด
    HopDelay = 4,         -- รอ 4 วิ ถ้าไม่มีของค่อยย้าย (กันย้ายมั่ว)
    MaxHeight = 2000,     -- ความสูงสูงสุด (กันบัคไปแมพอื่น)
    DistanceCheck = 20,   -- ระยะห่างที่จะเริ่มเก็บ
    AutoStart = true      -- เริ่มทันที
}

-- รายชื่อของที่จะเก็บ
local LootTable = {
    {Name = "Cosmic Relic", Color = Color3.fromRGB(0, 255, 255)},
    {Name = "Enchant Relic", Color = Color3.fromRGB(255, 85, 255)},
    {Name = "Void Wood", Color = Color3.fromRGB(170, 0, 170)},
    {Name = "Lunar Thread", Color = Color3.fromRGB(100, 100, 255)},
    {Name = "Starfall Totem", Color = Color3.fromRGB(255, 215, 0)},
    {Name = "Crate", Color = Color3.fromRGB(255, 100, 100)},
    {Name = "Coral", Color = Color3.fromRGB(255, 150, 150)},
    -- เพิ่มของอื่นๆ ได้ที่นี่
}

-- ================= SERVICES & VARIABLES =================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local isFarming = false
local itemsCollected = 0
local JustHopped = false

-- ================= SETTINGS MANAGER =================
local Settings = {
    AutoFarm = true,
    ESP = true
}

local function SaveSettings()
    writefile(Config.FileName, HttpService:JSONEncode(Settings))
end

local function LoadSettings()
    if isfile(Config.FileName) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(Config.FileName))
        end)
        if success then Settings = result end
    else
        SaveSettings()
    end
end
LoadSettings()

-- ================= ANTI-AFK (Bypass) =================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

-- ================= UI SETUP =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FischAutoLoot_V5"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(0, 230, 0, 110)
StatusFrame.Position = UDim2.new(0.02, 0, 0.70, 0)
StatusFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = ScreenGui
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", StatusFrame).Color = Color3.fromRGB(50, 50, 100)
Instance.new("UIStroke", StatusFrame).Thickness = 2

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 25)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 16
TitleLabel.Text = "⚡ V5: ULTRA STABLE ⚡"
TitleLabel.Parent = StatusFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 30)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 13
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text = "Status: Idle"
StatusLabel.Parent = StatusFrame

local ItemLabel = Instance.new("TextLabel")
ItemLabel.Size = UDim2.new(1, -20, 0, 20)
ItemLabel.Position = UDim2.new(0, 10, 0, 55)
ItemLabel.BackgroundTransparency = 1
ItemLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ItemLabel.Font = Enum.Font.Gotham
ItemLabel.TextSize = 12
ItemLabel.TextXAlignment = Enum.TextXAlignment.Left
ItemLabel.Text = "Collected: 0"
ItemLabel.Parent = StatusFrame

local HopButton = Instance.new("TextButton")
HopButton.Size = UDim2.new(0.9, 0, 0, 25)
HopButton.Position = UDim2.new(0.05, 0, 0.75, 0)
HopButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
HopButton.Text = "FORCE SERVER HOP"
HopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
HopButton.Font = Enum.Font.GothamBold
HopButton.TextSize = 12
HopButton.Parent = StatusFrame
Instance.new("UICorner", HopButton).CornerRadius = UDim.new(0, 6)

local function UpdateStatus(text)
    StatusLabel.Text = "Status: " .. text
end

-- ================= CORE SYSTEMS =================

-- 1. Noclip Loop (เดินทะลุกำแพงตลอดเวลา)
task.spawn(function()
    while true do
        if Settings.AutoFarm and LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
        RunService.Stepped:Wait()
    end
end)

-- 2. Safe Teleport (วาร์ปเสถียร + หยุดตัว)
local function SafeTeleport(targetCFrame)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = LocalPlayer.Character.HumanoidRootPart
    
    -- หยุดแรงส่งก่อนวาร์ป (Anti-Fling)
    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    
    -- วาร์ปแบบ Pivot (เสถียรสุดใน Roblox ตอนนี้)
    -- ยกสูงนิดหน่อย (Vector3.new(0, 3, 0)) กันจมดิน
    LocalPlayer.Character:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
    
    -- หยุดแรงส่งอีกทีหลังวาร์ปถึง
    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
end

-- 3. Optimized Server Hop (API + Fallback)
local function ServerHop()
    if JustHopped then return end
    JustHopped = true
    
    UpdateStatus("Finding Server...")
    SaveSettings()
    
    -- Queue Script to run immediately on new server
    if syn and syn.queue_on_teleport then
        syn.queue_on_teleport('loadstring(game:HttpGet("YOUR_SCRIPT_URL_HERE"))()')
    end

    local PlaceID = game.PlaceId
    local AllIDs = {}
    local found = false
    
    local success, err = pcall(function()
        local Site;
        if found == false then
            Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
        end
        for i, v in pairs(Site.data) do
            -- หาเซิร์ฟที่คนไม่เต็ม และไม่ใช่เซิร์ฟเดิม
            if v.playing < v.maxPlayers and v.id ~= game.JobId then
                AllIDs[#AllIDs + 1] = v.id
            end
        end
    end)
    
    if not success then 
        UpdateStatus("API Error, Random Hop...")
        task.wait(1)
        TeleportService:Teleport(PlaceID, LocalPlayer)
        return 
    end
    
    if #AllIDs > 0 then
        UpdateStatus("Hopping...")
        TeleportService:TeleportToPlaceInstance(PlaceID, AllIDs[math.random(1, #AllIDs)], LocalPlayer)
    else
        UpdateStatus("No Servers Found, Rejoining...")
        TeleportService:Teleport(PlaceID, LocalPlayer)
    end
end

HopButton.MouseButton1Click:Connect(ServerHop)

-- 4. Loot Finder
local function IsLoot(model)
    if not model then return nil end
    local name = model.Name:lower()
    for _, loot in pairs(LootTable) do
        if string.find(name, loot.Name:lower()) then
            return loot
        end
    end
    return nil
end

local function GetLootItems()
    local items = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Model") or v:IsA("BasePart") then
            local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                local lootData = IsLoot(v)
                if lootData then
                    local part = v:IsA("Model") and v.PrimaryPart or v
                    if not part and v:IsA("Model") then
                        part = v:FindFirstChildWhichIsA("BasePart", true)
                    end
                    
                    if part and part.Position.Y < Config.MaxHeight then
                        table.insert(items, {Part = part, Data = lootData, Prompt = prompt})
                    end
                end
            end
        end
    end
    return items
end

-- ================= MAIN LOOP =================
task.spawn(function()
    while true do
        if Settings.AutoFarm then
            local loots = GetLootItems()
            
            if #loots > 0 then
                UpdateStatus("Farming: " .. #loots .. " items")
                
                for _, item in pairs(loots) do
                    if not Settings.AutoFarm then break end
                    
                    if item.Part and item.Part.Parent and item.Prompt and item.Prompt.Parent then
                        local p = item.Part
                        
                        -- A. วาร์ป
                        UpdateStatus("Go: " .. item.Data.Name)
                        SafeTeleport(p.CFrame)
                        
                        -- B. ดีเลย์สั้นๆ ให้เน็ตโหลด
                        local waitTime = math.random(Config.MinDelay * 100, Config.MaxDelay * 100) / 100
                        task.wait(waitTime)
                        
                        -- C. เช็คระยะและเก็บ
                        if LocalPlayer.Character and (LocalPlayer.Character.HumanoidRootPart.Position - p.Position).Magnitude < Config.DistanceCheck then
                            -- Bypass Prompt Duration (เก็บทันที ไม่ต้องกดค้าง)
                            item.Prompt.HoldDuration = 0 
                            item.Prompt.MaxActivationDistance = 50
                            
                            -- ยิง Prompt
                            fireproximityprompt(item.Prompt)
                            
                            -- Visual Effect
                            local hl = Instance.new("Highlight")
                            hl.FillColor = item.Data.Color
                            hl.OutlineTransparency = 1
                            hl.Parent = item.Part
                            Debris:AddItem(hl, 0.5)
                            
                            itemsCollected = itemsCollected + 1
                            ItemLabel.Text = "Collected: " .. itemsCollected
                        else
                            -- กันพลาดถ้าวาร์ปไม่ถึง ให้ลองอีกที
                            SafeTeleport(p.CFrame)
                            task.wait(0.1)
                            fireproximityprompt(item.Prompt)
                        end
                    end
                end
                
                UpdateStatus("Cooldown...")
                task.wait(0.3) -- พักแปปเดียวแล้วหาใหม่
            else
                -- ไม่มีของ -> เริ่มกระบวนการ Hop
                UpdateStatus("Searching...")
                task.wait(1.5)
                
                -- เช็คซ้ำอีกรอบ (Double Check) เพื่อความชัวร์
                local checkAgain = GetLootItems()
                if #checkAgain == 0 then
                    UpdateStatus("Server Empty -> HOPPING!")
                    task.wait(Config.HopDelay)
                    ServerHop()
                else
                    UpdateStatus("Found new items!")
                end
            end
        else
            UpdateStatus("Paused")
            task.wait(1)
        end
        task.wait()
    end
end)

-- ================= ESP =================
task.spawn(function()
    local ESP_Folder = Instance.new("Folder", ScreenGui)
    ESP_Folder.Name = "ESP_Items"

    while true do
        if Settings.ESP then
            ESP_Folder:ClearAllChildren()
            local items = GetLootItems()
            
            for _, item in pairs(items) do
                if item.Part then
                    local bg = Instance.new("BillboardGui")
                    bg.Adornee = item.Part
                    bg.Size = UDim2.new(0, 80, 0, 30)
                    bg.AlwaysOnTop = true
                    bg.Parent = ESP_Folder
                    
                    local txt = Instance.new("TextLabel", bg)
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextColor3 = item.Data.Color
                    txt.TextStrokeTransparency = 0
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 10
                    txt.Text = item.Data.Name
                end
            end
        else
            ESP_Folder:ClearAllChildren()
        end
        task.wait(2.5) -- ESP อัพเดทช้าหน่อยเพื่อไม่กิน FPS
    end
end)

-- แจ้งเตือนว่าสคริปต์ทำงาน
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Gemini Script V5",
    Text = "Auto Farm Loaded & Running!",
    Duration = 5
})

UpdateStatus("V5 READY")
