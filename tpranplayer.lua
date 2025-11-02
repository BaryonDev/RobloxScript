-- Random Player Teleport Script with GUI
-- Paste this into a LocalScript in StarterGui or StarterPlayerScripts
-- Atau execute dengan executor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Tunggu PlayerGui ready
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Hapus GUI lama jika ada
if PlayerGui:FindFirstChild("TeleportGui") then
    PlayerGui:FindFirstChild("TeleportGui"):Destroy()
end

wait(0.5)

-- Variables
local teleportEnabled = false
local teleportDelay = 1 -- detik

-- Create GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TeleportGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Frame
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 100)
Frame.Position = UDim2.new(0.5, -100, 0.1, 0)
Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Frame.BorderSizePixel = 2
Frame.BorderColor3 = Color3.fromRGB(0, 170, 255)
Frame.ZIndex = 10
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

-- UICorner untuk Frame
local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 10)
FrameCorner.Parent = Frame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "Random Teleport"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.ZIndex = 11
Title.Parent = Frame

-- Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 150, 0, 40)
ToggleButton.Position = UDim2.new(0.5, -75, 0.5, 5)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
ToggleButton.Text = "OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 18
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.ZIndex = 11
ToggleButton.Parent = Frame

-- UICorner untuk Button
local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 8)
ButtonCorner.Parent = ToggleButton

print("GUI Created Successfully!")

-- Fungsi untuk mendapatkan player random
local function getRandomPlayer()
    local allPlayers = Players:GetPlayers()
    local otherPlayers = {}
    
    for _, player in pairs(allPlayers) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(otherPlayers, player)
        end
    end
    
    if #otherPlayers > 0 then
        return otherPlayers[math.random(1, #otherPlayers)]
    end
    return nil
end

-- Fungsi teleport
local function teleportToRandomPlayer()
    if not teleportEnabled then return end
    
    local Character = LocalPlayer.Character
    if not Character then return end
    
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return end
    
    local targetPlayer = getRandomPlayer()
    if targetPlayer then
        local targetChar = targetPlayer.Character
        if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame * CFrame.new(0, 100, 0)
            print("Teleported to: " .. targetPlayer.Name)
        end
    end
end

-- Toggle function
ToggleButton.MouseButton1Click:Connect(function()
    teleportEnabled = not teleportEnabled
    
    if teleportEnabled then
        ToggleButton.Text = "ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        print("Teleport ENABLED")
    else
        ToggleButton.Text = "OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        print("Teleport DISABLED")
    end
end)

-- Loop teleport dengan coroutine
coroutine.wrap(function()
    while wait(teleportDelay) do
        if teleportEnabled then
            pcall(function()
                teleportToRandomPlayer()
            end)
        end
    end
end)()

print("Script loaded! GUI should be visible now.")
