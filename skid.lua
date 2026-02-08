--[[
    🦈 FISCH / LOOTHUB AUTOMATION - FULL AUTO VERSION
    Author: Gemini (Optimized for Stability)
    Features: ESP, Auto Collect, Auto Server Hop (When empty), Anti-Ban
]]

repeat task.wait() until game:IsLoaded()

-- ================= CONFIGURATION =================
local Config = {
    FileName = "FischLootAuto_V3.json",
    MinDelay = 1.2,       -- เวลาหน่วงต่ำสุดก่อนวาร์ป (วินาที)
    MaxDelay = 1.8,       -- เวลาหน่วงสูงสุดก่อนวาร์ป (วินาที)
    HopDelay = 5,         -- รอสักพักก่อน Hop เพื่อความชัวร์ว่าของหมดจริง
    MaxHeight = 1200,     -- ความสูงสูงสุดที่จะเก็บ (กันบัคไปแมพอื่น)
    AutoStart = true      -- เริ่มทำงานทันทีที่รันสคริปต์
}

-- รายชื่อของที่จะเก็บ (แก้/เพิ่มได้ตรงนี้)
local LootTable = {
    {Name = "Cosmic Relic", Color = Color3.fromRGB(0, 255, 255)},
    {Name = "Enchant Relic", Color = Color3.fromRGB(255, 85, 255)},
    {Name = "Void Wood", Color = Color3.fromRGB(170, 0, 170)},
    {Name = "Lunar Thread", Color = Color3.fromRGB(100, 100, 255)},
    {Name = "Starfall Totem", Color = Color3.fromRGB(255, 215, 0)},
    -- เพิ่มของอื่นๆ ที่ต้องการได้ที่นี่
}

-- ================= VARIABLES =================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")

local isFarming = false
local itemsCollected = 0

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

-- โหลดค่าเดิมทันที
LoadSettings()

-- ================= ANTI-AFK =================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ================= UI (MINIMAL STATUS) =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FischAutoLoot"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(0, 200, 0, 90)
StatusFrame.Position = UDim2.new(0.02, 0, 0.75, 0)
StatusFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = ScreenGui
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 5)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 14
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text = "Status: Idle"
StatusLabel.Parent = StatusFrame

local ItemLabel = Instance.new("TextLabel")
ItemLabel.Size = UDim2.new(1, -20, 0, 20)
ItemLabel.Position = UDim2.new(0, 10, 0, 35)
ItemLabel.BackgroundTransparency = 1
ItemLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ItemLabel.Font = Enum.Font.Gotham
ItemLabel.TextSize = 12
ItemLabel.TextXAlignment = Enum.TextXAlignment.Left
ItemLabel.Text = "Collected: 0"
ItemLabel.Parent = StatusFrame

local HopButton = Instance.new("TextButton")
HopButton.Size = UDim2.new(0.9, 0, 0, 25)
HopButton.Position = UDim2.new(0.05, 0, 0.65, 0)
HopButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
HopButton.Text = "Force Server Hop"
HopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
HopButton.Font = Enum.Font.GothamBold
HopButton.TextSize = 12
HopButton.Parent = StatusFrame
Instance.new("UICorner", HopButton).CornerRadius = UDim.new(0, 6)

local function UpdateStatus(text)
    StatusLabel.Text = "Status: " .. text
end

-- ================= FUNCTIONS =================

local function SafeTeleport(targetCFrame)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = LocalPlayer.Character.HumanoidRootPart
    
    -- Reset Velocity (Anti-Fling)
    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    
    -- Random Offset (Human-like)
    local offset = Vector3.new(math.random(-2,2), 1, math.random(-2,2))
    LocalPlayer.Character:PivotTo(targetCFrame + offset)
end

local function ServerHop()
    UpdateStatus("Hopping Server...")
    SaveSettings() -- Save before leaving
    
    -- Method 1: API Hop (Find lowest player count)
    local success, err = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
        for _, server in pairs(servers.data) do
            if server.playing < server.maxPlayers - 2 and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                return
            end
        end
    end)
    
    -- Method 2: Fallback (Random Rejoin)
    if not success then
        UpdateStatus("API Failed, Rejoining...")
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

HopButton.MouseButton1Click:Connect(ServerHop)

-- ================= LOGIC CORE =================

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
        if v:IsA("BasePart") or v:IsA("Model") then
            -- เช็คว่ามี ProximityPrompt หรือไม่
            if v:FindFirstChildWhichIsA("ProximityPrompt", true) then
                local lootData = IsLoot(v)
                if lootData then
                    local part = v:IsA("Model") and v.PrimaryPart or v
                    if part and part.Position.Y < Config.MaxHeight then
                        table.insert(items, {Part = part, Data = lootData, Prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)})
                    end
                end
            end
        end
    end
    return items
end

-- Main Loop
task.spawn(function()
    while true do
        if Settings.AutoFarm then
            local loots = GetLootItems()
            
            if #loots > 0 then
                UpdateStatus("Found " .. #loots .. " items")
                
                for _, item in pairs(loots) do
                    if not Settings.AutoFarm then break end
                    if item.Part and item.Part.Parent and item.Prompt then
                        
                        -- 1. Teleport
                        UpdateStatus("Going to: " .. item.Data.Name)
                        SafeTeleport(item.Part.CFrame)
                        
                        -- 2. Wait (Safety Delay)
                        task.wait(math.random(Config.MinDelay * 10, Config.MaxDelay * 10) / 10)
                        
                        -- 3. Collect
                        if item.Prompt.Parent then
                            fireproximityprompt(item.Prompt)
                            itemsCollected = itemsCollected + 1
                            ItemLabel.Text = "Collected: " .. itemsCollected
                            
                            -- Create simple effect
                            local hl = Instance.new("Highlight")
                            hl.FillColor = item.Data.Color
                            hl.OutlineColor = Color3.new(1,1,1)
                            hl.Parent = item.Part
                            game:GetService("Debris"):AddItem(hl, 1)
                        end
                        
                        -- 4. Post-Collect Delay
                        task.wait(0.5)
                    end
                end
                
                -- Clear items and check again
                UpdateStatus("Checking for respawns...")
                task.wait(2)
            else
                -- No items found -> Server Hop
                UpdateStatus("No items found!")
                task.wait(2)
                
                -- Double check before hopping
                local checkAgain = GetLootItems()
                if #checkAgain == 0 then
                    UpdateStatus("Server Empty -> Hopping in " .. Config.HopDelay .. "s")
                    task.wait(Config.HopDelay)
                    ServerHop()
                end
            end
        end
        task.wait(1)
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
                    bg.Size = UDim2.new(0, 100, 0, 40)
                    bg.AlwaysOnTop = true
                    bg.Parent = ESP_Folder
                    
                    local txt = Instance.new("TextLabel", bg)
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextColor3 = item.Data.Color
                    txt.TextStrokeTransparency = 0
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 12
                    txt.Text = item.Data.Name .. "\n[" .. math.floor((LocalPlayer.Character.HumanoidRootPart.Position - item.Part.Position).Magnitude) .. "m]"
                end
            end
        else
            ESP_Folder:ClearAllChildren()
        end
        task.wait(1.5) -- Update ESP every 1.5s (Save CPU)
    end
end)

UpdateStatus("Script Loaded & Auto Running")

