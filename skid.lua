--[[
    🦈 FISCH AUTO - NO UI BUTTONS (PURE AUTO)
    Optimized for: Auto Collect "Stones/Relics", Bypass Logic
    Author: Gemini
]]

repeat task.wait() until game:IsLoaded()

-- ================= CONFIG (ตั้งค่าความปลอดภัย) =================
local Config = {
    MinDelay = 1.1,       -- รอ 1.1 วิ ก่อนเก็บ (กันเด้ง)
    MaxDelay = 1.6,       -- รอ 1.6 วิ (สุ่ม)
    ServerHopDelay = 5,   -- ถ้าไม่เจอของ รอ 5 วิ แล้วย้ายห้อง
    MaxHeight = 1500,     -- ความสูงสูงสุดที่จะสแกนหาของ
}

-- รายชื่อของที่จะเก็บ (หิน/กล่อง/Relic)
local LootNames = {
    "Cosmic Relic", 
    "Enchant Relic", 
    "Void Wood", 
    "Lunar Thread", 
    "Starfall Totem", 
    "Crate",       -- เผื่อเป็นกล่องทั่วไป
    "Carbon Crate" -- เผื่อเป็นกล่องคาร์บอน
}

-- ================= SERVICES =================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

-- ================= UI CREATION (NO BUTTONS) =================
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local OldGui = PlayerGui:FindFirstChild("FischAuto_NoBtn")
if OldGui then OldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FischAuto_NoBtn"
ScreenGui.Parent = PlayerGui

-- Main Background
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 110)
MainFrame.Position = UDim2.new(0.5, -125, 0.85, 0) -- อยู่ด้านล่างกลางจอ
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = MainFrame
UIStroke.Color = Color3.fromRGB(60, 60, 100)
UIStroke.Thickness = 2

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 25)
Title.BackgroundTransparency = 1
Title.Text = "🛡️ Mikir Auto - Fully Automated"
Title.TextColor3 = Color3.fromRGB(0, 255, 150)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.Parent = MainFrame

-- Subtitle (Experimental Text)
local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, 0, 0, 20)
SubTitle.Position = UDim2.new(0, 0, 0, 22)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "⚠️ เก็บหิน Bypass (ทดลอง)"
SubTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 12
SubTitle.Parent = MainFrame

-- Status: Current Target
local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(1, -20, 0, 25)
TargetLabel.Position = UDim2.new(0, 10, 0, 45)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Target: Scanning..."
TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.Font = Enum.Font.Gotham
TargetLabel.TextSize = 13
TargetLabel.Parent = MainFrame

-- Status: Action
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 70)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.Parent = MainFrame

-- Auto Run Indicator
local AutoRunText = Instance.new("TextLabel")
AutoRunText.Size = UDim2.new(0, 80, 0, 20)
AutoRunText.Position = UDim2.new(1, -85, 1, -25)
AutoRunText.BackgroundTransparency = 1
AutoRunText.Text = "✅ Auto Running"
AutoRunText.TextColor3 = Color3.fromRGB(100, 255, 100)
AutoRunText.Font = Enum.Font.GothamBold
AutoRunText.TextSize = 10
AutoRunText.Parent = MainFrame

-- ================= FUNCTIONS =================

local function SetStatus(target, action)
    TargetLabel.Text = "Target: " .. (target or "None")
    StatusLabel.Text = "Status: " .. (action or "Waiting...")
end

local function BypassTeleport(cframe)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        -- 1. Freeze Velocity (Anti-Fling Bypass)
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
        
        -- 2. Teleport
        LocalPlayer.Character:PivotTo(cframe)
        
        -- 3. Freeze again
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end
end

local function ServerHop()
    SetStatus("None", "Server Empty -> Hopping...")
    task.wait(2)
    
    local PlaceID = game.PlaceId
    local AllIDs = {}
    local found = false
    
    pcall(function()
        local Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
        for i, v in pairs(Site.data) do
            if v.playing ~= v.maxPlayers then
                table.insert(AllIDs, v.id)
            end
        end
    end)
    
    if #AllIDs > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceID, AllIDs[math.random(1, #AllIDs)], LocalPlayer)
    else
        SetStatus("None", "Hop Failed -> Rejoining...")
        TeleportService:Teleport(PlaceID, LocalPlayer)
    end
end

local function CheckLoot()
    local FoundItems = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Model") or v:IsA("BasePart") then
            for _, name in pairs(LootNames) do
                if string.find(v.Name, name) then
                    local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt then
                        table.insert(FoundItems, {Obj = v, Prompt = prompt})
                    end
                end
            end
        end
    end
    return FoundItems
end

-- ================= ANTI-AFK =================
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

-- ================= MAIN LOOP (AUTO RUN) =================

task.spawn(function()
    while task.wait(0.5) do
        local Items = CheckLoot()
        
        if #Items > 0 then
            for _, item in pairs(Items) do
                if item.Obj and item.Obj.Parent and item.Prompt.Parent then
                    local Part = (item.Obj:IsA("Model") and item.Obj.PrimaryPart) or item.Obj
                    
                    if Part and Part.Position.Y < Config.MaxHeight then
                        -- Update UI
                        SetStatus(item.Obj.Name, "Teleporting...")
                        
                        -- Teleport Step
                        BypassTeleport(Part.CFrame + Vector3.new(0, 3.5, 0))
                        
                        -- Wait Step (Randomized)
                        local delayTime = math.random(Config.MinDelay * 10, Config.MaxDelay * 10) / 10
                        SetStatus(item.Obj.Name, "Wait: " .. delayTime .. "s")
                        task.wait(delayTime)
                        
                        -- Collect Step
                        if item.Prompt.Parent then
                            SetStatus(item.Obj.Name, "Collecting...")
                            fireproximityprompt(item.Prompt)
                            task.wait(0.8) -- รอของเข้ากระเป๋า
                        end
                    end
                end
            end
        else
            -- No Items Found
            SetStatus("None", "Map Empty -> Waiting " .. Config.ServerHopDelay .. "s")
            task.wait(Config.ServerHopDelay)
            
            -- Check one last time before hop
            if #CheckLoot() == 0 then
                ServerHop()
            end
        end
    end
end)

