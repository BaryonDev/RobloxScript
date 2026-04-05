-- ================================================
-- PET FINDER + AUTOFARM v3
-- + Filter by Name Panel (switch mode)
-- ================================================

-- ============================================================
-- TAHAP 0: ANTI-FAIL AUTOEXECUTE — tunggu semua load dulu
-- ============================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(1.5)

local function safeGetService(name)
    local ok, svc = pcall(function() return game:GetService(name) end)
    return ok and svc or nil
end

local Players, RunService, TweenService, UserInputService, VIM
repeat
    Players          = safeGetService("Players")
    RunService       = safeGetService("RunService")
    TweenService     = safeGetService("TweenService")
    UserInputService = safeGetService("UserInputService")
    VIM              = safeGetService("VirtualInputManager")
    if not (Players and RunService and TweenService and UserInputService and VIM) then
        task.wait(0.3)
    end
until Players and RunService and TweenService and UserInputService and VIM

local player
repeat
    player = Players.LocalPlayer
    if not player then task.wait(0.2) end
until player

local function waitForChar()
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    local deadline = tick() + 15
    while not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) do
        if tick() > deadline then break end
        task.wait(0.1)
    end
end
waitForChar()

local deadline = tick() + 15
repeat
    task.wait(0.1)
until player:FindFirstChild("PlayerGui") or tick() > deadline

local function hasPetsFolder()
    for _, area in ipairs(workspace:GetChildren()) do
        if area:FindFirstChild("Pets") then return true end
    end
    return false
end
local petsDeadline = tick() + 45
while not hasPetsFolder() and tick() < petsDeadline do
    task.wait(0.5)
end
if not hasPetsFolder() then
    warn("[PetFinder] ⚠️ Folder Pets tidak ditemukan setelah 45 detik.")
end

local mouse
local mouseDeadline = tick() + 10
repeat
    pcall(function() mouse = player:GetMouse() end)
    if not mouse then task.wait(0.1) end
until mouse or tick() > mouseDeadline

local existingGui = player.PlayerGui:FindFirstChild("PetFinderUI")
if existingGui then existingGui:Destroy() end

task.wait(0.2)
print("[PetFinder] ✅ Semua services & data siap. Memuat UI...")

-- ============================================================
-- KONFIGURASI
-- ============================================================
local function getAllPetsFolders()
    local folders = {}
    for _, area in ipairs(workspace:GetChildren()) do
        local petsFolder = area:FindFirstChild("Pets")
        if petsFolder then
            table.insert(folders, petsFolder)
        end
    end
    return folders
end

local TP_INTERVAL          = 0.1
local OFFSET               = Vector3.new(3, 0, 0)
local HEIGHT_MINIMIZED     = 40
local HEIGHT_COLLAPSED     = 408   -- +38 untuk tab bar
local HEIGHT_EXPANDED      = 708   -- +38 untuk tab bar
local NOTIF_SOUND_ID       = "rbxassetid://145099824"
local STRENGTH_THRESHOLD   = 4800
local AUTOFARM_CPS         = 13
local WRONG_CATCH_TIMEOUT  = 13

-- ============================================================
-- PALET WARNA
-- ============================================================
local C = {
    BASE        = Color3.fromRGB(10, 10, 16),
    SURFACE     = Color3.fromRGB(17, 17, 27),
    ELEVATED    = Color3.fromRGB(24, 24, 38),
    ROW         = Color3.fromRGB(22, 22, 34),
    ROW_ACTIVE  = Color3.fromRGB(55, 50, 110),
    ACCENT      = Color3.fromRGB(105, 95, 225),
    ACCENT_GLOW = Color3.fromRGB(135, 125, 255),
    CYAN_LINE   = Color3.fromRGB(80, 220, 255),
    BORDER      = Color3.fromRGB(38, 38, 60),
    BORDER_MID  = Color3.fromRGB(55, 55, 85),
    BORDER_SEL  = Color3.fromRGB(100, 90, 220),
    TEXT_1      = Color3.fromRGB(238, 238, 255),
    TEXT_2      = Color3.fromRGB(135, 135, 168),
    TEXT_3      = Color3.fromRGB(80, 80, 110),
    DIVIDER     = Color3.fromRGB(38, 38, 60),
    NOTIF_BG    = Color3.fromRGB(18, 18, 30),
    NOTIF_GOLD  = Color3.fromRGB(255, 200, 60),
    NOTIF_CYAN  = Color3.fromRGB(55, 200, 255),
    GREEN       = Color3.fromRGB(60, 200, 100),
    GREEN_GLOW  = Color3.fromRGB(80, 255, 140),
    TAB_ACTIVE  = Color3.fromRGB(105, 95, 225),
    TAB_IDLE    = Color3.fromRGB(24, 24, 38),
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(190, 190, 210),
    Rare      = Color3.fromRGB(90,  155, 255),
    Epic      = Color3.fromRGB(185, 100, 255),
    Legendary = Color3.fromRGB(255, 170, 40),
    Mythical  = Color3.fromRGB(255, 65,  90),
}
local RARITY_ORDER = {"Common", "Rare", "Epic", "Legendary", "Mythical"}

local function getStrengthColor(str)
    if     str >= 5000 then return Color3.fromRGB(55,  200, 255)
    elseif str >= 3400 then return Color3.fromRGB(255, 70,  70)
    elseif str >= 2500 then return Color3.fromRGB(255, 145, 45)
    elseif str >= 1600 then return Color3.fromRGB(240, 215, 55)
    elseif str >= 1000 then return Color3.fromRGB(80,  210, 105)
    else                    return C.TEXT_2
    end
end

-- ============================================================
-- HELPER
-- ============================================================
local function addStroke(parent, color, thickness, transp)
    local s = Instance.new("UIStroke", parent)
    s.Color        = color     or C.BORDER
    s.Thickness    = thickness or 1
    s.Transparency = transp   or 0
    return s
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 8)
    return c
end

-- ============================================================
-- SCREENGUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "PetFinderUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = player.PlayerGui

local NotifSound = Instance.new("Sound")
NotifSound.SoundId            = NOTIF_SOUND_ID
NotifSound.Volume             = 0.6
NotifSound.RollOffMaxDistance = 0
NotifSound.Parent             = ScreenGui

-- ============================================================
-- MAIN FRAME
-- ============================================================
local MainFrame = Instance.new("Frame")
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, 300, 0, HEIGHT_COLLAPSED)
MainFrame.Position         = UDim2.new(0, 16, 0, 20)
MainFrame.BackgroundColor3 = C.SURFACE
MainFrame.BorderSizePixel  = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent           = ScreenGui
addCorner(MainFrame, 12)
addStroke(MainFrame, C.BORDER, 1)

local TopLine = Instance.new("Frame")
TopLine.Size             = UDim2.new(0.6, 0, 0, 2)
TopLine.Position         = UDim2.new(0.2, 0, 0, 0)
TopLine.BackgroundColor3 = C.CYAN_LINE
TopLine.BorderSizePixel  = 0
TopLine.ZIndex           = 5
TopLine.Parent           = MainFrame
addCorner(TopLine, 2)

local TopGlow = Instance.new("Frame")
TopGlow.Size                   = UDim2.new(1, 0, 0, 28)
TopGlow.BackgroundColor3       = Color3.fromRGB(80, 220, 255)
TopGlow.BackgroundTransparency = 0.92
TopGlow.BorderSizePixel        = 0
TopGlow.ZIndex                 = 2
TopGlow.Parent                 = MainFrame

-- ============================================================
-- TITLE BAR
-- ============================================================
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = C.BASE
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 3
TitleBar.Parent           = MainFrame
addCorner(TitleBar, 12)

local TitleFix = Instance.new("Frame")
TitleFix.Size             = UDim2.new(1, 0, 0, 12)
TitleFix.Position         = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = C.BASE
TitleFix.BorderSizePixel  = 0
TitleFix.ZIndex           = 3
TitleFix.Parent           = TitleBar

local TitleDivider = Instance.new("Frame")
TitleDivider.Size             = UDim2.new(1, -24, 0, 1)
TitleDivider.Position         = UDim2.new(0, 12, 1, -1)
TitleDivider.BackgroundColor3 = C.BORDER
TitleDivider.BorderSizePixel  = 0
TitleDivider.ZIndex           = 4
TitleDivider.Parent           = TitleBar

local TitleDot = Instance.new("Frame")
TitleDot.Size             = UDim2.new(0, 7, 0, 7)
TitleDot.Position         = UDim2.new(0, 14, 0.5, -3)
TitleDot.BackgroundColor3 = C.CYAN_LINE
TitleDot.BorderSizePixel  = 0
TitleDot.ZIndex           = 4
TitleDot.Parent           = TitleBar
addCorner(TitleDot, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size                = UDim2.new(1, -100, 1, 0)
TitleLabel.Position            = UDim2.new(0, 28, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3          = C.TEXT_1
TitleLabel.Font                = Enum.Font.GothamBold
TitleLabel.TextSize            = 13
TitleLabel.Text                = "PET FINDER"
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left
TitleLabel.ZIndex              = 4
TitleLabel.Parent              = TitleBar

local TitleStatus = Instance.new("TextLabel")
TitleStatus.Size                = UDim2.new(0, 80, 1, 0)
TitleStatus.Position            = UDim2.new(1, -120, 0, 0)
TitleStatus.BackgroundTransparency = 1
TitleStatus.TextColor3          = C.GREEN
TitleStatus.Font                = Enum.Font.GothamBold
TitleStatus.TextSize            = 9
TitleStatus.Text                = ""
TitleStatus.TextXAlignment      = Enum.TextXAlignment.Right
TitleStatus.ZIndex              = 4
TitleStatus.Parent              = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 26, 0, 26)
MinBtn.Position         = UDim2.new(1, -38, 0.5, -13)
MinBtn.BackgroundColor3 = C.ELEVATED
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "−"
MinBtn.TextColor3       = C.TEXT_2
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 14
MinBtn.ZIndex           = 5
MinBtn.Parent           = TitleBar
addCorner(MinBtn, 6)
addStroke(MinBtn, C.BORDER_MID, 1)

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragStart, frameStart
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging   = true
        dragStart  = input.Position
        frameStart = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + delta.X,
            frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ============================================================
-- CONTENT AREA
-- ============================================================
local Content = Instance.new("Frame")
Content.Name                = "Content"
Content.Size                = UDim2.new(1, 0, 1, -44)
Content.Position            = UDim2.new(0, 0, 0, 44)
Content.BackgroundTransparency = 1
Content.Parent              = MainFrame

-- ============================================================
-- TAB BAR (Mode Switch: Rarity | Nama)  Y=4
-- ============================================================
local filterMode = "rarity"  -- "rarity" | "name"

local TabBar = Instance.new("Frame")
TabBar.Size             = UDim2.new(1, -20, 0, 30)
TabBar.Position         = UDim2.new(0, 10, 0, 4)
TabBar.BackgroundColor3 = C.ELEVATED
TabBar.BorderSizePixel  = 0
TabBar.Parent           = Content
addCorner(TabBar, 8)
addStroke(TabBar, C.BORDER, 1)

-- Tab Rarity (kiri)
local TabRarity = Instance.new("TextButton")
TabRarity.Size             = UDim2.new(0.5, -2, 1, -4)
TabRarity.Position         = UDim2.new(0, 2, 0, 2)
TabRarity.BackgroundColor3 = C.ELEVATED
TabRarity.BorderSizePixel  = 0
TabRarity.Text             = "🎲  Rarity"
TabRarity.TextColor3       = C.TEXT_2
TabRarity.Font             = Enum.Font.GothamBold
TabRarity.TextSize         = 11
TabRarity.ZIndex           = 3
TabRarity.Parent           = TabBar
addCorner(TabRarity, 7)

-- Tab Nama (kanan)
local TabName = Instance.new("TextButton")
TabName.Size             = UDim2.new(0.5, -2, 1, -4)
TabName.Position         = UDim2.new(0.5, 0, 0, 2)
TabName.BackgroundColor3 = C.ELEVATED
TabName.BorderSizePixel  = 0
TabName.Text             = "🔍  Nama"
TabName.TextColor3       = C.TEXT_3
TabName.Font             = Enum.Font.GothamBold
TabName.TextSize         = 11
TabName.ZIndex           = 3
TabName.Parent           = TabBar
addCorner(TabName, 7)

-- Active indicator underline (BUKAN child of TabBar agar tidak kena layout)
local TabIndicator = Instance.new("Frame")
TabIndicator.Size             = UDim2.new(0.5, -8, 0, 2)
TabIndicator.Position         = UDim2.new(0, 4, 1, -3)
TabIndicator.BackgroundColor3 = C.ACCENT_GLOW
TabIndicator.BorderSizePixel  = 0
TabIndicator.ZIndex           = 5
TabIndicator.Parent           = TabBar
addCorner(TabIndicator, 2)

local function updateTabs()
    if filterMode == "rarity" then
        TabRarity.TextColor3     = C.TEXT_1
        TabRarity.BackgroundColor3 = Color3.fromRGB(30, 28, 52)
        TabName.TextColor3       = C.TEXT_3
        TabName.BackgroundColor3 = C.ELEVATED
        TweenService:Create(TabIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quint),
            {Position = UDim2.new(0, 2, 1, -3)}):Play()
    else
        TabName.TextColor3       = C.TEXT_1
        TabName.BackgroundColor3 = Color3.fromRGB(30, 28, 52)
        TabRarity.TextColor3     = C.TEXT_3
        TabRarity.BackgroundColor3 = C.ELEVATED
        TweenService:Create(TabIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quint),
            {Position = UDim2.new(0.5, 2, 1, -3)}):Play()
    end
end
updateTabs()

-- ============================================================
-- RARITY PANEL  Y=40, H=180
-- ============================================================
local CheckSection = Instance.new("Frame")
CheckSection.Size                = UDim2.new(1, -20, 0, 180)
CheckSection.Position            = UDim2.new(0, 10, 0, 40)   -- +38 dari sebelumnya (12→40)
CheckSection.BackgroundTransparency = 1
CheckSection.Parent              = Content
CheckSection.Visible             = true

local CheckLayout = Instance.new("UIListLayout", CheckSection)
CheckLayout.Padding   = UDim.new(0, 5)
CheckLayout.SortOrder = Enum.SortOrder.LayoutOrder

local checkboxStates  = {}
local checkboxToggles = {}

local function createCheckbox(rarity)
    local color = RARITY_COLORS[rarity]

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = C.ROW
    row.BorderSizePixel  = 0
    row.LayoutOrder      = table.find(RARITY_ORDER, rarity)
    row.Parent           = CheckSection
    addCorner(row, 7)
    addStroke(row, C.BORDER, 1)

    local leftBar = Instance.new("Frame")
    leftBar.Size                   = UDim2.new(0, 3, 0.6, 0)
    leftBar.Position               = UDim2.new(0, 0, 0.2, 0)
    leftBar.BackgroundColor3       = color
    leftBar.BorderSizePixel        = 0
    leftBar.BackgroundTransparency = 1
    leftBar.Parent                 = row
    addCorner(leftBar, 3)

    local box = Instance.new("TextButton")
    box.Size             = UDim2.new(0, 16, 0, 16)
    box.Position         = UDim2.new(0, 12, 0.5, -8)
    box.BackgroundColor3 = C.ELEVATED
    box.BorderSizePixel  = 0
    box.Text             = ""
    box.Parent           = row
    addCorner(box, 4)
    local boxStroke = addStroke(box, C.BORDER_MID, 1)

    local tick_ = Instance.new("TextLabel")
    tick_.Size                  = UDim2.new(1, 0, 1, 0)
    tick_.BackgroundTransparency = 1
    tick_.TextColor3            = color
    tick_.Font                  = Enum.Font.GothamBold
    tick_.TextSize              = 11
    tick_.Text                  = ""
    tick_.Parent                = box

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -50, 1, 0)
    lbl.Position            = UDim2.new(0, 36, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3          = C.TEXT_2
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 12
    lbl.Text                = rarity
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Parent              = row

    local rarDot = Instance.new("Frame")
    rarDot.Size                   = UDim2.new(0, 6, 0, 6)
    rarDot.Position               = UDim2.new(1, -14, 0.5, -3)
    rarDot.BackgroundColor3       = color
    rarDot.BackgroundTransparency = 0.5
    rarDot.BorderSizePixel        = 0
    rarDot.Parent                 = row
    addCorner(rarDot, 10)

    checkboxStates[rarity] = false

    local function toggle()
        checkboxStates[rarity] = not checkboxStates[rarity]
        if checkboxStates[rarity] then
            tick_.Text                  = "✔"
            box.BackgroundColor3        = Color3.fromRGB(40, 38, 68)
            boxStroke.Color             = color
            leftBar.BackgroundTransparency = 0
            lbl.TextColor3              = C.TEXT_1
            rarDot.BackgroundTransparency = 0
        else
            tick_.Text                  = ""
            box.BackgroundColor3        = C.ELEVATED
            boxStroke.Color             = C.BORDER_MID
            leftBar.BackgroundTransparency = 1
            lbl.TextColor3              = C.TEXT_2
            rarDot.BackgroundTransparency = 0.5
        end
    end

    checkboxToggles[rarity] = toggle
    box.MouseButton1Click:Connect(toggle)
    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then toggle() end
    end)
end

for _, r in ipairs(RARITY_ORDER) do
    createCheckbox(r)
end

-- ============================================================
-- NAME FILTER PANEL  Y=40, H=180  (hidden by default)
-- ============================================================
local nameFilters = {}   -- list of { name = string, frame = Instance }

local NameSection = Instance.new("Frame")
NameSection.Size                = UDim2.new(1, -20, 0, 180)
NameSection.Position            = UDim2.new(0, 10, 0, 40)
NameSection.BackgroundTransparency = 1
NameSection.Visible             = false
NameSection.Parent              = Content

-- Input row (input box + tombol tambah)
local InputRow = Instance.new("Frame")
InputRow.Size             = UDim2.new(1, 0, 0, 34)
InputRow.BackgroundTransparency = 1
InputRow.Parent           = NameSection

local NameInput = Instance.new("TextBox")
NameInput.Size             = UDim2.new(1, -44, 1, -6)
NameInput.Position         = UDim2.new(0, 0, 0, 3)
NameInput.BackgroundColor3 = C.ELEVATED
NameInput.BorderSizePixel  = 0
NameInput.PlaceholderText  = "Ketik nama hewan..."
NameInput.PlaceholderColor3 = C.TEXT_3
NameInput.TextColor3       = C.TEXT_1
NameInput.Font             = Enum.Font.Gotham
NameInput.TextSize         = 11
NameInput.ClearTextOnFocus = false
NameInput.Text             = ""
NameInput.Parent           = InputRow
addCorner(NameInput, 7)
addStroke(NameInput, C.BORDER_MID, 1)

local InputPad = Instance.new("UIPadding", NameInput)
InputPad.PaddingLeft  = UDim.new(0, 8)
InputPad.PaddingRight = UDim.new(0, 8)

local AddBtn = Instance.new("TextButton")
AddBtn.Size             = UDim2.new(0, 36, 1, -6)
AddBtn.Position         = UDim2.new(1, -36, 0, 3)
AddBtn.BackgroundColor3 = C.ACCENT
AddBtn.BorderSizePixel  = 0
AddBtn.Text             = "+"
AddBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
AddBtn.Font             = Enum.Font.GothamBold
AddBtn.TextSize         = 18
AddBtn.Parent           = InputRow
addCorner(AddBtn, 7)

-- Hint text
local HintLabel = Instance.new("TextLabel")
HintLabel.Size                = UDim2.new(1, 0, 0, 16)
HintLabel.Position            = UDim2.new(0, 0, 0, 36)
HintLabel.BackgroundTransparency = 1
HintLabel.TextColor3          = C.TEXT_3
HintLabel.Font                = Enum.Font.Gotham
HintLabel.TextSize            = 9
HintLabel.Text                = "Partial match · case insensitive · maks 8 nama"
HintLabel.TextXAlignment      = Enum.TextXAlignment.Left
HintLabel.Parent              = NameSection

-- Scrollable list nama (Y=56)
local NameListFrame = Instance.new("ScrollingFrame")
NameListFrame.Size                = UDim2.new(1, 0, 1, -58)
NameListFrame.Position            = UDim2.new(0, 0, 0, 58)
NameListFrame.BackgroundColor3    = C.BASE
NameListFrame.BorderSizePixel     = 0
NameListFrame.ScrollBarThickness  = 3
NameListFrame.ScrollBarImageColor3 = C.ACCENT
NameListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
NameListFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
NameListFrame.Parent              = NameSection
addCorner(NameListFrame, 7)
addStroke(NameListFrame, C.BORDER, 1)

local NameListLayout = Instance.new("UIListLayout", NameListFrame)
NameListLayout.Padding   = UDim.new(0, 3)
NameListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local NameListPad = Instance.new("UIPadding", NameListFrame)
NameListPad.PaddingTop    = UDim.new(0, 5)
NameListPad.PaddingBottom = UDim.new(0, 5)
NameListPad.PaddingLeft   = UDim.new(0, 5)
NameListPad.PaddingRight  = UDim.new(0, 8)

local NameEmptyLabel = Instance.new("TextLabel")
NameEmptyLabel.Size                = UDim2.new(1, 0, 0, 36)
NameEmptyLabel.BackgroundTransparency = 1
NameEmptyLabel.TextColor3          = C.TEXT_3
NameEmptyLabel.Font                = Enum.Font.Gotham
NameEmptyLabel.TextSize            = 11
NameEmptyLabel.Text                = "Belum ada nama ditambahkan."
NameEmptyLabel.Visible             = true
NameEmptyLabel.Parent              = NameListFrame

-- Fungsi rebuild list nama
local function rebuildNameList()
    for _, c in ipairs(NameListFrame:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    NameEmptyLabel.Visible = (#nameFilters == 0)

    for i, entry in ipairs(nameFilters) do
        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, 0, 0, 26)
        row.BackgroundColor3 = C.ROW
        row.BorderSizePixel  = 0
        row.LayoutOrder      = i
        row.Parent           = NameListFrame
        addCorner(row, 6)
        addStroke(row, C.BORDER, 1)

        -- Dot accent
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 5, 0, 5)
        dot.Position         = UDim2.new(0, 8, 0.5, -2)
        dot.BackgroundColor3 = C.ACCENT_GLOW
        dot.BorderSizePixel  = 0
        dot.Parent           = row
        addCorner(dot, 10)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size                = UDim2.new(1, -50, 1, 0)
        nameLbl.Position            = UDim2.new(0, 20, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3          = C.TEXT_1
        nameLbl.Font                = Enum.Font.GothamBold
        nameLbl.TextSize            = 11
        nameLbl.Text                = entry.name
        nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
        nameLbl.TextTruncate        = Enum.TextTruncate.AtEnd
        nameLbl.Parent              = row

        -- Tombol hapus (×)
        local delBtn = Instance.new("TextButton")
        delBtn.Size             = UDim2.new(0, 22, 0, 22)
        delBtn.Position         = UDim2.new(1, -26, 0.5, -11)
        delBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
        delBtn.BorderSizePixel  = 0
        delBtn.Text             = "×"
        delBtn.TextColor3       = Color3.fromRGB(255, 80, 80)
        delBtn.Font             = Enum.Font.GothamBold
        delBtn.TextSize         = 14
        delBtn.Parent           = row
        addCorner(delBtn, 5)

        local capturedIdx = i
        delBtn.MouseButton1Click:Connect(function()
            table.remove(nameFilters, capturedIdx)
            rebuildNameList()
        end)
    end
end

rebuildNameList()

-- Fungsi tambah nama
local function addNameFilter()
    local raw = NameInput.Text
    if not raw or raw:gsub("%s+", "") == "" then return end
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if #nameFilters >= 8 then
        HintLabel.Text      = "⚠ Maks 8 nama!"
        HintLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        task.delay(2, function()
            HintLabel.Text       = "Partial match · case insensitive · maks 8 nama"
            HintLabel.TextColor3 = C.TEXT_3
        end)
        return
    end
    -- cek duplikat (case insensitive)
    for _, e in ipairs(nameFilters) do
        if e.name:lower() == raw:lower() then
            HintLabel.Text       = "⚠ Sudah ada!"
            HintLabel.TextColor3 = C.NOTIF_GOLD
            task.delay(2, function()
                HintLabel.Text       = "Partial match · case insensitive · maks 8 nama"
                HintLabel.TextColor3 = C.TEXT_3
            end)
            return
        end
    end
    table.insert(nameFilters, { name = raw })
    NameInput.Text = ""
    rebuildNameList()
end

AddBtn.MouseButton1Click:Connect(addNameFilter)
NameInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then addNameFilter() end
end)

-- ============================================================
-- TAB SWITCH LOGIC
-- ============================================================
local function switchToRarity()
    filterMode           = "rarity"
    CheckSection.Visible = true
    NameSection.Visible  = false
    updateTabs()
end

local function switchToName()
    filterMode           = "name"
    CheckSection.Visible = false
    NameSection.Visible  = true
    updateTabs()
end

TabRarity.MouseButton1Click:Connect(switchToRarity)
TabName.MouseButton1Click:Connect(switchToName)

-- ============================================================
-- NOTIFICATION TOGGLE ROW  Y=228 (sebelumnya 198, +30 tab)
-- ============================================================
local notifEnabled = true

local NotifRow = Instance.new("Frame")
NotifRow.Size             = UDim2.new(1, -20, 0, 32)
NotifRow.Position         = UDim2.new(0, 10, 0, 228)
NotifRow.BackgroundColor3 = C.ROW
NotifRow.BorderSizePixel  = 0
NotifRow.Parent           = Content
addCorner(NotifRow, 7)
addStroke(NotifRow, C.BORDER, 1)

local NotifIcon = Instance.new("TextLabel")
NotifIcon.Size                 = UDim2.new(0, 20, 1, 0)
NotifIcon.Position             = UDim2.new(0, 10, 0, 0)
NotifIcon.BackgroundTransparency = 1
NotifIcon.TextColor3           = C.NOTIF_GOLD
NotifIcon.Font                 = Enum.Font.GothamBold
NotifIcon.TextSize             = 14
NotifIcon.Text                 = "🔔"
NotifIcon.Parent               = NotifRow

local NotifLabel = Instance.new("TextLabel")
NotifLabel.Size                = UDim2.new(1, -90, 1, 0)
NotifLabel.Position            = UDim2.new(0, 34, 0, 0)
NotifLabel.BackgroundTransparency = 1
NotifLabel.TextColor3          = C.TEXT_1
NotifLabel.Font                = Enum.Font.GothamBold
NotifLabel.TextSize            = 11
NotifLabel.Text                = "Notifikasi  STR " .. STRENGTH_THRESHOLD .. "+"
NotifLabel.TextXAlignment      = Enum.TextXAlignment.Left
NotifLabel.Parent              = NotifRow

local NotifToggleWrap = Instance.new("Frame")
NotifToggleWrap.Size             = UDim2.new(0, 40, 0, 20)
NotifToggleWrap.Position         = UDim2.new(1, -50, 0.5, -10)
NotifToggleWrap.BackgroundColor3 = C.ACCENT
NotifToggleWrap.BorderSizePixel  = 0
NotifToggleWrap.Parent           = NotifRow
addCorner(NotifToggleWrap, 10)

local NotifToggleKnob = Instance.new("Frame")
NotifToggleKnob.Size             = UDim2.new(0, 14, 0, 14)
NotifToggleKnob.Position         = UDim2.new(1, -17, 0.5, -7)
NotifToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
NotifToggleKnob.BorderSizePixel  = 0
NotifToggleKnob.Parent           = NotifToggleWrap
addCorner(NotifToggleKnob, 10)

local NotifToggleBtn = Instance.new("TextButton")
NotifToggleBtn.Size                 = UDim2.new(1, 0, 1, 0)
NotifToggleBtn.BackgroundTransparency = 1
NotifToggleBtn.Text                 = ""
NotifToggleBtn.Parent               = NotifToggleWrap

local function updateNotifToggle()
    if notifEnabled then
        TweenService:Create(NotifToggleWrap, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = C.ACCENT}):Play()
        TweenService:Create(NotifToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(1, -17, 0.5, -7)}):Play()
        NotifIcon.TextColor3  = C.NOTIF_GOLD
        NotifLabel.TextColor3 = C.TEXT_1
    else
        TweenService:Create(NotifToggleWrap, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = C.ELEVATED}):Play()
        TweenService:Create(NotifToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 3, 0.5, -7)}):Play()
        NotifIcon.TextColor3  = C.TEXT_3
        NotifLabel.TextColor3 = C.TEXT_3
    end
end

NotifToggleBtn.MouseButton1Click:Connect(function()
    notifEnabled = not notifEnabled
    updateNotifToggle()
end)
NotifRow.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        notifEnabled = not notifEnabled
        updateNotifToggle()
    end
end)

-- ============================================================
-- AUTOFARM TOGGLE ROW  Y=268
-- ============================================================
local autofarmEnabled = true

local AFRow = Instance.new("Frame")
AFRow.Size             = UDim2.new(1, -20, 0, 32)
AFRow.Position         = UDim2.new(0, 10, 0, 268)
AFRow.BackgroundColor3 = C.ROW
AFRow.BorderSizePixel  = 0
AFRow.Parent           = Content
addCorner(AFRow, 7)
addStroke(AFRow, C.BORDER, 1)

local AFIcon = Instance.new("TextLabel")
AFIcon.Size                 = UDim2.new(0, 20, 1, 0)
AFIcon.Position             = UDim2.new(0, 10, 0, 0)
AFIcon.BackgroundTransparency = 1
AFIcon.TextColor3           = C.GREEN_GLOW
AFIcon.Font                 = Enum.Font.GothamBold
AFIcon.TextSize             = 14
AFIcon.Text                 = "⚔"
AFIcon.Parent               = AFRow

local AFLabel = Instance.new("TextLabel")
AFLabel.Size                = UDim2.new(1, -90, 1, 0)
AFLabel.Position            = UDim2.new(0, 34, 0, 0)
AFLabel.BackgroundTransparency = 1
AFLabel.TextColor3          = C.TEXT_1
AFLabel.Font                = Enum.Font.GothamBold
AFLabel.TextSize            = 11
AFLabel.Text                = "Autofarm  STR " .. STRENGTH_THRESHOLD .. "+"
AFLabel.TextXAlignment      = Enum.TextXAlignment.Left
AFLabel.Parent              = AFRow

local AFToggleWrap = Instance.new("Frame")
AFToggleWrap.Size             = UDim2.new(0, 40, 0, 20)
AFToggleWrap.Position         = UDim2.new(1, -50, 0.5, -10)
AFToggleWrap.BackgroundColor3 = C.GREEN
AFToggleWrap.BorderSizePixel  = 0
AFToggleWrap.Parent           = AFRow
addCorner(AFToggleWrap, 10)

local AFToggleKnob = Instance.new("Frame")
AFToggleKnob.Size             = UDim2.new(0, 14, 0, 14)
AFToggleKnob.Position         = UDim2.new(1, -17, 0.5, -7)
AFToggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AFToggleKnob.BorderSizePixel  = 0
AFToggleKnob.Parent           = AFToggleWrap
addCorner(AFToggleKnob, 10)

local AFToggleBtn = Instance.new("TextButton")
AFToggleBtn.Size                 = UDim2.new(1, 0, 1, 0)
AFToggleBtn.BackgroundTransparency = 1
AFToggleBtn.Text                 = ""
AFToggleBtn.Parent               = AFToggleWrap

local function updateAFToggle()
    if autofarmEnabled then
        TweenService:Create(AFToggleWrap, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = C.GREEN}):Play()
        TweenService:Create(AFToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(1, -17, 0.5, -7)}):Play()
        AFIcon.TextColor3  = C.GREEN_GLOW
        AFLabel.TextColor3 = C.TEXT_1
    else
        TweenService:Create(AFToggleWrap, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = C.ELEVATED}):Play()
        TweenService:Create(AFToggleKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 3, 0.5, -7)}):Play()
        AFIcon.TextColor3  = C.TEXT_3
        AFLabel.TextColor3 = C.TEXT_3
    end
end

AFToggleBtn.MouseButton1Click:Connect(function()
    autofarmEnabled = not autofarmEnabled
    updateAFToggle()
end)
AFRow.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        autofarmEnabled = not autofarmEnabled
        updateAFToggle()
    end
end)

-- ============================================================
-- SEARCH BUTTON  Y=312 (sebelumnya 282, +30)
-- ============================================================
local SearchBtnWrap = Instance.new("Frame")
SearchBtnWrap.Size             = UDim2.new(1, -20, 0, 36)
SearchBtnWrap.Position         = UDim2.new(0, 10, 0, 312)
SearchBtnWrap.BackgroundColor3 = C.ACCENT
SearchBtnWrap.BorderSizePixel  = 0
SearchBtnWrap.Parent           = Content
addCorner(SearchBtnWrap, 8)

local BtnShimmer = Instance.new("Frame")
BtnShimmer.Size                   = UDim2.new(1, 0, 0.5, 0)
BtnShimmer.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
BtnShimmer.BackgroundTransparency = 0.92
BtnShimmer.BorderSizePixel        = 0
BtnShimmer.Parent                 = SearchBtnWrap
addCorner(BtnShimmer, 8)

local SearchBtn = Instance.new("TextButton")
SearchBtn.Size                 = UDim2.new(1, 0, 1, 0)
SearchBtn.BackgroundTransparency = 1
SearchBtn.Text                 = "Cari Hewan"
SearchBtn.TextColor3           = Color3.fromRGB(255, 255, 255)
SearchBtn.Font                 = Enum.Font.GothamBold
SearchBtn.TextSize             = 13
SearchBtn.Parent               = SearchBtnWrap

-- ============================================================
-- DIVIDER & RESULTS  Y=357 / Y=363
-- ============================================================
local Divider = Instance.new("Frame")
Divider.Size             = UDim2.new(1, -20, 0, 1)
Divider.Position         = UDim2.new(0, 10, 0, 357)
Divider.BackgroundColor3 = C.DIVIDER
Divider.BorderSizePixel  = 0
Divider.Visible          = false
Divider.Parent           = Content

local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name                 = "ResultsFrame"
ResultsFrame.Size                 = UDim2.new(1, -20, 1, -370)
ResultsFrame.Position             = UDim2.new(0, 10, 0, 363)
ResultsFrame.BackgroundColor3     = C.BASE
ResultsFrame.BorderSizePixel      = 0
ResultsFrame.ScrollBarThickness   = 3
ResultsFrame.ScrollBarImageColor3 = C.ACCENT
ResultsFrame.AutomaticCanvasSize  = Enum.AutomaticSize.Y
ResultsFrame.CanvasSize           = UDim2.new(0, 0, 0, 0)
ResultsFrame.Visible              = false
ResultsFrame.Parent               = Content
addCorner(ResultsFrame, 8)
addStroke(ResultsFrame, C.BORDER, 1)

local ResultsLayout = Instance.new("UIListLayout", ResultsFrame)
ResultsLayout.Padding   = UDim.new(0, 4)
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local ResultsPad = Instance.new("UIPadding", ResultsFrame)
ResultsPad.PaddingTop    = UDim.new(0, 6)
ResultsPad.PaddingBottom = UDim.new(0, 6)
ResultsPad.PaddingLeft   = UDim.new(0, 5)
ResultsPad.PaddingRight  = UDim.new(0, 9)

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Size                = UDim2.new(1, 0, 0, 40)
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.TextColor3          = C.TEXT_3
EmptyLabel.Font                = Enum.Font.Gotham
EmptyLabel.TextSize            = 12
EmptyLabel.Text                = "Tidak ada hewan ditemukan."
EmptyLabel.Visible             = false
EmptyLabel.Parent              = ResultsFrame

-- ============================================================
-- STATE
-- ============================================================
local selectedPet   = nil
local selectedBtn   = nil
local tpLooping     = false
local tpConn        = nil
local isMinimized   = false
local isResultsOpen = false
local notifiedPets  = {}

local autofarmQueue    = {}
local autofarmRunning  = false
local currentFarmTarget = nil
local queuedPetKeys    = {}
local autoClickActive  = false
local autoClickThread  = nil

-- ============================================================
-- NOTIFIKASI POPUP
-- ============================================================
local notifQueue     = {}
local NOTIF_WIDTH    = 280
local NOTIF_HEIGHT   = 64
local NOTIF_GAP      = 8
local NOTIF_MARGIN_R = 16
local NOTIF_MARGIN_B = 16
local MAX_NOTIF      = 4

local function getNotifYOffset(index)
    return -(NOTIF_MARGIN_B + (index - 1) * (NOTIF_HEIGHT + NOTIF_GAP))
end

local function repositionNotifs()
    for i, entry in ipairs(notifQueue) do
        local targetY = getNotifYOffset(i)
        TweenService:Create(entry.frame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_MARGIN_R), 1, targetY - NOTIF_HEIGHT)}
        ):Play()
    end
end

local function dismissNotif(entry)
    local idx = table.find(notifQueue, entry)
    if idx then table.remove(notifQueue, idx) end
    TweenService:Create(entry.frame,
        TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {Position = UDim2.new(1, 20, 1, entry.frame.Position.Y.Offset)}
    ):Play()
    task.delay(0.3, function()
        entry.frame:Destroy()
        repositionNotifs()
    end)
end

local function showNotifPopup(petName, strength, rarity)
    if #notifQueue >= MAX_NOTIF then
        dismissNotif(notifQueue[1])
        task.wait(0.05)
    end

    local rarColor = RARITY_COLORS[rarity] or C.NOTIF_CYAN
    local strColor = C.NOTIF_CYAN

    local notifFrame = Instance.new("Frame")
    notifFrame.Size             = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
    notifFrame.Position         = UDim2.new(1, 20, 1, -(NOTIF_MARGIN_B + NOTIF_HEIGHT))
    notifFrame.BackgroundColor3 = C.NOTIF_BG
    notifFrame.BorderSizePixel  = 0
    notifFrame.ZIndex           = 20
    notifFrame.Parent           = ScreenGui
    addCorner(notifFrame, 10)
    addStroke(notifFrame, C.NOTIF_CYAN, 1, 0.3)

    local topAccent = Instance.new("Frame")
    topAccent.Size             = UDim2.new(0.5, 0, 0, 2)
    topAccent.Position         = UDim2.new(0.25, 0, 0, 0)
    topAccent.BackgroundColor3 = strColor
    topAccent.BorderSizePixel  = 0
    topAccent.ZIndex           = 21
    topAccent.Parent           = notifFrame
    addCorner(topAccent, 2)

    local leftAccent = Instance.new("Frame")
    leftAccent.Size             = UDim2.new(0, 3, 0.7, 0)
    leftAccent.Position         = UDim2.new(0, 0, 0.15, 0)
    leftAccent.BackgroundColor3 = strColor
    leftAccent.BorderSizePixel  = 0
    leftAccent.ZIndex           = 21
    leftAccent.Parent           = notifFrame
    addCorner(leftAccent, 3)

    local notifIconLbl = Instance.new("TextLabel")
    notifIconLbl.Size                 = UDim2.new(0, 30, 1, 0)
    notifIconLbl.Position             = UDim2.new(0, 10, 0, 0)
    notifIconLbl.BackgroundTransparency = 1
    notifIconLbl.TextColor3           = strColor
    notifIconLbl.Font                 = Enum.Font.GothamBold
    notifIconLbl.TextSize             = 20
    notifIconLbl.Text                 = "⚡"
    notifIconLbl.ZIndex               = 21
    notifIconLbl.Parent               = notifFrame

    local headerLbl = Instance.new("TextLabel")
    headerLbl.Size                = UDim2.new(1, -55, 0, 18)
    headerLbl.Position            = UDim2.new(0, 44, 0, 8)
    headerLbl.BackgroundTransparency = 1
    headerLbl.TextColor3          = strColor
    headerLbl.Font                = Enum.Font.GothamBold
    headerLbl.TextSize            = 10
    headerLbl.Text                = "HEWAN KUAT DITEMUKAN!"
    headerLbl.TextXAlignment      = Enum.TextXAlignment.Left
    headerLbl.ZIndex              = 21
    headerLbl.Parent              = notifFrame

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                = UDim2.new(1, -55, 0, 16)
    nameLbl.Position            = UDim2.new(0, 44, 0, 24)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3          = C.TEXT_1
    nameLbl.Font                = Enum.Font.GothamBold
    nameLbl.TextSize            = 13
    nameLbl.Text                = petName
    nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
    nameLbl.TextTruncate        = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex              = 21
    nameLbl.Parent              = notifFrame

    local strLbl = Instance.new("TextLabel")
    strLbl.Size                = UDim2.new(1, -55, 0, 14)
    strLbl.Position            = UDim2.new(0, 44, 0, 40)
    strLbl.BackgroundTransparency = 1
    strLbl.TextColor3          = rarColor
    strLbl.Font                = Enum.Font.GothamBold
    strLbl.TextSize            = 10
    strLbl.Text                = rarity:upper() .. "  •  STR " .. tostring(strength)
    strLbl.TextXAlignment      = Enum.TextXAlignment.Left
    strLbl.ZIndex              = 21
    strLbl.Parent              = notifFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size                 = UDim2.new(0, 18, 0, 18)
    closeBtn.Position             = UDim2.new(1, -24, 0, 6)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text                 = "×"
    closeBtn.TextColor3           = C.TEXT_3
    closeBtn.Font                 = Enum.Font.GothamBold
    closeBtn.TextSize             = 14
    closeBtn.ZIndex               = 22
    closeBtn.Parent               = notifFrame

    local progressBg = Instance.new("Frame")
    progressBg.Size             = UDim2.new(1, 0, 0, 2)
    progressBg.Position         = UDim2.new(0, 0, 1, -2)
    progressBg.BackgroundColor3 = C.BORDER
    progressBg.BorderSizePixel  = 0
    progressBg.ZIndex           = 21
    progressBg.Parent           = notifFrame
    addCorner(progressBg, 2)

    local progressBar = Instance.new("Frame")
    progressBar.Size             = UDim2.new(1, 0, 1, 0)
    progressBar.BackgroundColor3 = strColor
    progressBar.BorderSizePixel  = 0
    progressBar.ZIndex           = 22
    progressBar.Parent           = progressBg
    addCorner(progressBar, 2)

    local entry = {frame = notifFrame}
    table.insert(notifQueue, entry)
    repositionNotifs()

    local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_MARGIN_R), 1, getNotifYOffset(#notifQueue) - NOTIF_HEIGHT)
    TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = targetPos}):Play()
    TweenService:Create(progressBar, TweenInfo.new(5, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()

    closeBtn.MouseButton1Click:Connect(function() dismissNotif(entry) end)
    task.delay(5, function()
        if notifFrame and notifFrame.Parent then dismissNotif(entry) end
    end)
end

-- ============================================================
-- AUTOFARM — EQUIP & CLICK HELPERS
-- ============================================================
local function isLassoEquipped()
    local char = player.Character
    if not char then return false end
    return char:FindFirstChildOfClass("Tool") ~= nil
end

local function unequipAll()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid:UnequipTools() end)
    end
end

local function pressKey1()
    pcall(function()
        VIM:SendKeyEvent(true,  Enum.KeyCode.One, false, game)
    end)
    task.wait(0.04)
    pcall(function()
        VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    end)
end

local function reequipLasso()
    unequipAll()
    local t0 = tick()
    while isLassoEquipped() and (tick() - t0) < 1.5 do
        task.wait(0.05)
    end
    task.wait(0.12)
    local t1 = tick()
    while not isLassoEquipped() and (tick() - t1) < 3 do
        pressKey1()
        task.wait(0.18)
    end
    return isLassoEquipped()
end

local function startAutoClick(cps)
    autoClickActive = true
    local interval  = 1 / cps
    autoClickThread = task.spawn(function()
        while autoClickActive do
            local vp     = workspace.CurrentCamera.ViewportSize
            local cx, cy = math.floor(vp.X / 2), math.floor(vp.Y / 2)
            pcall(function()
                VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 0)
            end)
            task.wait(0.01)
            pcall(function()
                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
            task.wait(math.max(0.001, interval - 0.01))
        end
    end)
end

local function stopAutoClick()
    autoClickActive = false
    if autoClickThread then
        task.cancel(autoClickThread)
        autoClickThread = nil
    end
end

-- ============================================================
-- STATUS LABEL
-- ============================================================
local function setStatusLabel(text, color)
    TitleStatus.Text       = text
    TitleStatus.TextColor3 = color or C.GREEN
end

-- ============================================================
-- AUTOFARM — WRONG-CATCH MONITOR
-- ============================================================
local function startWrongCatchMonitor(getPet, getFarmActive, petNameStr)
    return task.spawn(function()
        local lassoUnequipStart = nil
        local recovering        = false

        while getFarmActive() do
            task.wait(0.1)

            if not autofarmEnabled then
                lassoUnequipStart = nil
                recovering        = false
                task.wait(0.3)
            end

            local pet = getPet()
            if not pet or not pet.Parent then break end
            if recovering then continue end

            local equipped = isLassoEquipped()

            if equipped then
                lassoUnequipStart = nil
            else
                if not lassoUnequipStart then
                    lassoUnequipStart = tick()
                elseif tick() - lassoUnequipStart >= WRONG_CATCH_TIMEOUT then
                    recovering = true
                    print(string.format(
                        "[PetFinder] ⚠️ Salah tangkap! Lasso unequip %.1f detik, target masih ada. Reequip...",
                        tick() - lassoUnequipStart
                    ))
                    setStatusLabel("🔄 Salah tangkap!", C.NOTIF_GOLD)
                    stopAutoClick()

                    local ok = reequipLasso()
                    if ok and getFarmActive() and (pet and pet.Parent) then
                        setStatusLabel("⚔ " .. petNameStr, C.GREEN_GLOW)
                        startAutoClick(AUTOFARM_CPS)
                        print("[PetFinder] ✅ Reequip berhasil, autoclick dilanjutkan.")
                    elseif not ok then
                        warn("[PetFinder] ⚠️ Reequip gagal setelah salah tangkap!")
                        setStatusLabel("⚠ Reequip gagal", Color3.fromRGB(255, 80, 80))
                        task.wait(0.5)
                        local ok2 = reequipLasso()
                        if ok2 and getFarmActive() and (pet and pet.Parent) then
                            setStatusLabel("⚔ " .. petNameStr, C.GREEN_GLOW)
                            startAutoClick(AUTOFARM_CPS)
                            print("[PetFinder] ✅ Reequip retry berhasil.")
                        end
                    end

                    lassoUnequipStart = nil
                    recovering        = false
                end
            end
        end
    end)
end

-- ============================================================
-- AUTOFARM — FARM SATU TARGET
-- ============================================================
local farmActive = false

local function farmTarget(pet)
    if not pet or not pet.Parent then return end
    currentFarmTarget = pet
    farmActive        = true

    local petName = pet:GetAttribute("Name") or pet.Name
    local str     = tonumber(pet:GetAttribute("Strength")) or 0
    print(string.format("[PetFinder] 🎯 Autofarm: %s | STR %d", petName, str))
    setStatusLabel("⚔ " .. petName, C.GREEN_GLOW)

    local function tpToPet()
        if not pet or not pet.Parent then return end
        local char = player.Character
        if not char then return end
        local root    = char:FindFirstChild("HumanoidRootPart")
        local petRoot = pet:FindFirstChild("HumanoidRootPart")
            or pet:FindFirstChildWhichIsA("BasePart")
        if root and petRoot then
            root.CFrame = petRoot.CFrame + OFFSET
        end
    end

    tpToPet()
    task.wait(0.15)

    setStatusLabel("🔄 Reequip...", C.NOTIF_GOLD)
    local equipped = reequipLasso()

    if not equipped then
        warn("[PetFinder] ⚠️ Lasso tidak bisa di-equip, skip target ini.")
        currentFarmTarget = nil
        farmActive        = false
        setStatusLabel("", C.TEXT_3)
        return
    end

    setStatusLabel("⚔ " .. petName, C.GREEN_GLOW)
    startAutoClick(AUTOFARM_CPS)

    local monitorThread = startWrongCatchMonitor(
        function() return pet end,
        function() return farmActive end,
        petName
    )

    local farmConn
    farmConn = RunService.Heartbeat:Connect(function()
        if not autofarmEnabled then
            stopAutoClick()
            farmConn:Disconnect()
            pcall(function() task.cancel(monitorThread) end)
            currentFarmTarget = nil
            farmActive        = false
            setStatusLabel("⏸ Dijeda", C.TEXT_2)
            return
        end

        if not pet or not pet.Parent then
            stopAutoClick()
            farmConn:Disconnect()
            pcall(function() task.cancel(monitorThread) end)
            currentFarmTarget = nil
            farmActive        = false
            setStatusLabel("✔ Selesai", C.NOTIF_CYAN)
            task.delay(2, function() setStatusLabel("", C.TEXT_3) end)
            return
        end

        tpToPet()
    end)

    while (pet and pet.Parent) and autofarmEnabled do
        task.wait(0.2)
    end

    stopAutoClick()
    pcall(function() farmConn:Disconnect() end)
    pcall(function() task.cancel(monitorThread) end)
    currentFarmTarget = nil
    farmActive        = false

    task.wait(0.3)
    print("[PetFinder] 🔄 Target selesai, lanjut queue berikutnya...")
end

-- ============================================================
-- AUTOFARM — QUEUE PROCESSOR
-- ============================================================
local function processQueue()
    if autofarmRunning then return end
    autofarmRunning = true
    task.spawn(function()
        while true do
            if not autofarmEnabled then
                task.wait(0.5)
            elseif #autofarmQueue > 0 then
                local next = table.remove(autofarmQueue, 1)
                if next and next.Parent then
                    local s = tonumber(next:GetAttribute("Strength")) or 0
                    if s >= STRENGTH_THRESHOLD then
                        queuedPetKeys[tostring(next)] = nil
                        farmTarget(next)
                        task.wait(0.3)
                    end
                else
                    queuedPetKeys[tostring(next)] = nil
                end
            else
                task.wait(0.3)
            end
        end
    end)
end

local function queueAutofarm(pet)
    if not autofarmEnabled then return end
    local key = tostring(pet)
    if queuedPetKeys[key] then return end
    if currentFarmTarget == pet then return end
    if not pet or not pet.Parent then return end
    queuedPetKeys[key] = true
    table.insert(autofarmQueue, pet)
    print(string.format("[PetFinder] 📋 Queue: %s | STR %d | Queue size: %d",
        pet:GetAttribute("Name") or pet.Name,
        tonumber(pet:GetAttribute("Strength")) or 0,
        #autofarmQueue
    ))
    processQueue()
end

processQueue()

-- ============================================================
-- TRIGGER NOTIFIKASI + AUTOFARM
-- ============================================================
local function triggerNotif(pet)
    local key = tostring(pet)
    if notifiedPets[key] then return end
    notifiedPets[key] = true

    local petName  = pet:GetAttribute("Name") or pet.Name
    local strength = tonumber(pet:GetAttribute("Strength")) or 0
    local rarity   = pet:GetAttribute("Rarity") or "Common"

    if notifEnabled then
        pcall(function() NotifSound:Play() end)
        showNotifPopup(petName, strength, rarity)
    end

    queueAutofarm(pet)
    print(string.format("[PetFinder] ⚡ Detected: %s | STR %d | %s", petName, strength, rarity))
end

-- ============================================================
-- HELPER FRAME HEIGHT
-- ============================================================
local function tweenFrameHeight(target)
    TweenService:Create(
        MainFrame,
        TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 300, 0, target)}
    ):Play()
end

local function clearResults()
    for _, c in ipairs(ResultsFrame:GetChildren()) do
        if c.Name == "PetRow" then c:Destroy() end
    end
    EmptyLabel.Visible = false
end

local function stopTP()
    tpLooping = false
    if tpConn then
        tpConn:Disconnect()
        tpConn = nil
    end
end

-- ============================================================
-- SELECT PET (manual dari list)
-- ============================================================
local function selectPet(pet, btn)
    if selectedPet == pet and tpLooping then
        stopTP()
        btn.BackgroundColor3 = C.ROW
        selectedPet = nil
        selectedBtn = nil
        return
    end

    if selectedBtn then selectedBtn.BackgroundColor3 = C.ROW end
    stopTP()

    selectedPet = pet
    selectedBtn = btn
    btn.BackgroundColor3 = C.ROW_ACTIVE

    if not pet.Parent then return end
    tpLooping = true

    tpConn = RunService.Heartbeat:Connect(function()
        if not tpLooping then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if not selectedPet or not selectedPet.Parent then
            stopTP()
            if selectedBtn then selectedBtn.BackgroundColor3 = C.ROW end
            selectedPet = nil
            selectedBtn = nil
            return
        end
        local petRoot = selectedPet:FindFirstChild("HumanoidRootPart")
            or selectedPet:FindFirstChildWhichIsA("BasePart")
        if petRoot then
            root.CFrame = petRoot.CFrame + OFFSET
        end
    end)
end

-- ============================================================
-- BUILD ROW
-- ============================================================
local function buildRow(pet, count)
    local rarity   = pet:GetAttribute("Rarity")
    local petName  = pet:GetAttribute("Name") or ("Pet #" .. count)
    local rarColor = RARITY_COLORS[rarity] or C.TEXT_2
    local strength = tonumber(pet:GetAttribute("Strength")) or 0
    local strColor = getStrengthColor(strength)

    local row = Instance.new("TextButton")
    row.Name             = "PetRow"
    row.Size             = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = (selectedPet == pet) and C.ROW_ACTIVE or C.ROW
    row.BorderSizePixel  = 0
    row.Text             = ""
    row.LayoutOrder      = count
    row.Parent           = ResultsFrame
    addCorner(row, 6)

    if queuedPetKeys[tostring(pet)] or currentFarmTarget == pet then
        addStroke(row, C.GREEN, 1, 0)
    else
        addStroke(row, C.BORDER, 1)
    end

    local rarBar = Instance.new("Frame")
    rarBar.Size             = UDim2.new(0, 3, 0.65, 0)
    rarBar.Position         = UDim2.new(0, 0, 0.175, 0)
    rarBar.BackgroundColor3 = rarColor
    rarBar.BorderSizePixel  = 0
    rarBar.Parent           = row
    addCorner(rarBar, 3)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                = UDim2.new(1, -80, 0, 18)
    nameLbl.Position            = UDim2.new(0, 14, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3          = C.TEXT_1
    nameLbl.Font                = Enum.Font.GothamBold
    nameLbl.TextSize            = 12
    nameLbl.Text                = petName
    nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
    nameLbl.TextTruncate        = Enum.TextTruncate.AtEnd
    nameLbl.Parent              = row

    local strRow = Instance.new("Frame")
    strRow.Size                 = UDim2.new(1, -80, 0, 16)
    strRow.Position             = UDim2.new(0, 14, 0, 25)
    strRow.BackgroundTransparency = 1
    strRow.Parent               = row

    local strDot = Instance.new("Frame")
    strDot.Size             = UDim2.new(0, 5, 0, 5)
    strDot.Position         = UDim2.new(0, 0, 0.5, -2)
    strDot.BackgroundColor3 = strColor
    strDot.BorderSizePixel  = 0
    strDot.Parent           = strRow
    addCorner(strDot, 10)

    local strLabel = Instance.new("TextLabel")
    strLabel.Size                = UDim2.new(1, -10, 1, 0)
    strLabel.Position            = UDim2.new(0, 9, 0, 0)
    strLabel.BackgroundTransparency = 1
    strLabel.TextColor3          = strColor
    strLabel.Font                = Enum.Font.GothamBold
    strLabel.TextSize            = 10
    strLabel.Text                = "STR  " .. tostring(strength)
    strLabel.TextXAlignment      = Enum.TextXAlignment.Left
    strLabel.Parent              = strRow

    local badge = Instance.new("TextLabel")
    badge.Size             = UDim2.new(0, 60, 0, 20)
    badge.Position         = UDim2.new(1, -64, 0.5, -10)
    badge.BackgroundColor3 = C.BASE
    badge.BorderSizePixel  = 0
    badge.TextColor3       = rarColor
    badge.Font             = Enum.Font.GothamBold
    badge.TextSize         = 9
    badge.Text             = rarity and rarity:upper() or "?"
    badge.Parent           = row
    addCorner(badge, 5)
    addStroke(badge, rarColor, 1, 0.5)

    if strength >= STRENGTH_THRESHOLD then
        local glowDot = Instance.new("Frame")
        glowDot.Size             = UDim2.new(0, 6, 0, 6)
        glowDot.Position         = UDim2.new(1, -72, 0.5, -3)
        glowDot.BackgroundColor3 = C.NOTIF_CYAN
        glowDot.BorderSizePixel  = 0
        glowDot.Parent           = row
        addCorner(glowDot, 10)
    end

    if currentFarmTarget == pet then
        local farmingLbl = Instance.new("TextLabel")
        farmingLbl.Size                = UDim2.new(0, 50, 0, 14)
        farmingLbl.Position            = UDim2.new(0, 14, 0, 6)
        farmingLbl.BackgroundTransparency = 1
        farmingLbl.TextColor3          = C.GREEN_GLOW
        farmingLbl.Font                = Enum.Font.GothamBold
        farmingLbl.TextSize            = 8
        farmingLbl.Text                = "▶ FARMING"
        farmingLbl.TextXAlignment      = Enum.TextXAlignment.Left
        farmingLbl.ZIndex              = 3
        farmingLbl.Parent              = row
    end

    if selectedPet == pet then selectedBtn = row end

    row.MouseButton1Click:Connect(function()
        selectPet(pet, row)
    end)
end

-- ============================================================
-- NAME MATCH HELPER
-- ============================================================
local function matchesNameFilter(pet)
    if #nameFilters == 0 then return false end
    local petName = (pet:GetAttribute("Name") or pet.Name):lower()
    for _, entry in ipairs(nameFilters) do
        if petName:find(entry.name:lower(), 1, true) then
            return true
        end
    end
    return false
end

-- ============================================================
-- SEARCH LOGIC
-- ============================================================
local isSearchActive    = false
local autoRefreshThread = nil

local function doSearch(isRefresh)
    -- ---- Mode Rarity ----
    if filterMode == "rarity" then
        local anySelected = false
        for _, v in pairs(checkboxStates) do
            if v then anySelected = true; break end
        end

        if not anySelected then
            if not isRefresh then
                SearchBtn.Text                    = "Pilih Rarity Dulu!"
                SearchBtnWrap.BackgroundColor3    = Color3.fromRGB(160, 60, 60)
                task.delay(1.5, function()
                    SearchBtn.Text                = "Cari Hewan"
                    SearchBtnWrap.BackgroundColor3 = C.ACCENT
                end)
            end
            return
        end

    -- ---- Mode Nama ----
    else
        if #nameFilters == 0 then
            if not isRefresh then
                SearchBtn.Text                    = "Tambah Nama Dulu!"
                SearchBtnWrap.BackgroundColor3    = Color3.fromRGB(160, 60, 60)
                task.delay(1.5, function()
                    SearchBtn.Text                = "Cari Hewan"
                    SearchBtnWrap.BackgroundColor3 = C.ACCENT
                end)
            end
            return
        end
    end

    if selectedPet and not selectedPet.Parent then
        selectedPet = nil
        selectedBtn = nil
        stopTP()
    end

    clearResults()

    local filtered = {}
    for _, petsFolder in ipairs(getAllPetsFolders()) do
        for _, pet in ipairs(petsFolder:GetChildren()) do
            local pass = false
            if filterMode == "rarity" then
                local rarity = pet:GetAttribute("Rarity")
                pass = rarity and checkboxStates[rarity] == true
            else
                pass = matchesNameFilter(pet)
            end

            if pass then
                table.insert(filtered, pet)
            end
        end
    end

    table.sort(filtered, function(a, b)
        local sa = tonumber(a:GetAttribute("Strength")) or 0
        local sb = tonumber(b:GetAttribute("Strength")) or 0
        return sa > sb
    end)

    local count = 0
    for _, pet in ipairs(filtered) do
        count = count + 1
        buildRow(pet, count)
        local strength = tonumber(pet:GetAttribute("Strength")) or 0
        if strength >= STRENGTH_THRESHOLD then
            triggerNotif(pet)
        end
    end

    EmptyLabel.Visible = (count == 0)

    if not isRefresh then
        ResultsFrame.Visible = true
        Divider.Visible      = true
        isResultsOpen        = true
        tweenFrameHeight(HEIGHT_EXPANDED)

        if autoRefreshThread then task.cancel(autoRefreshThread) end
        isSearchActive = true
        autoRefreshThread = task.spawn(function()
            while isSearchActive do
                task.wait(3)
                if isSearchActive then doSearch(true) end
            end
        end)

        SearchBtn.Text = string.format("✔  %d hewan ditemukan", count)
        task.delay(2, function() SearchBtn.Text = "Cari Hewan" end)
    end
end

SearchBtn.MouseButton1Click:Connect(function()
    isSearchActive = false
    if autoRefreshThread then task.cancel(autoRefreshThread) end
    selectedPet    = nil
    selectedBtn    = nil
    stopTP()
    notifiedPets   = {}
    queuedPetKeys  = {}
    autofarmQueue  = {}
    doSearch(false)
end)

-- ============================================================
-- MINIMIZE TOGGLE
-- ============================================================
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        Content.Visible = false
        tweenFrameHeight(HEIGHT_MINIMIZED)
        MinBtn.Text = "+"
    else
        Content.Visible = true
        tweenFrameHeight(isResultsOpen and HEIGHT_EXPANDED or HEIGHT_COLLAPSED)
        MinBtn.Text = "−"
    end
end)

-- ============================================================
-- AUTO INIT: aktifkan Mythical + langsung search
-- ============================================================
task.spawn(function()
    task.wait(0.6)

    if not checkboxStates["Mythical"] then
        local toggleFn = checkboxToggles["Mythical"]
        if toggleFn then toggleFn() end
    end

    task.wait(0.2)

    isSearchActive = false
    if autoRefreshThread then task.cancel(autoRefreshThread) end
    selectedPet   = nil
    selectedBtn   = nil
    stopTP()
    notifiedPets  = {}
    queuedPetKeys = {}
    autofarmQueue = {}
    doSearch(false)
end)

print("[PetFinder] ✅ Script v3 berhasil dimuat!")
print(string.format(
    "[PetFinder] ⚙️  Autofarm: ON | CPS: %d | Threshold: STR %d+ | Wrong-catch timeout: %.1fs",
    AUTOFARM_CPS, STRENGTH_THRESHOLD, WRONG_CATCH_TIMEOUT
))
print("[PetFinder] 🔍 Filter by Name: tersedia (tab 'Nama')")
