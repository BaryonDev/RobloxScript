-- ============================================================
--   MEGA MERGED SCRIPT
--   AFK + Anti Reconnect | Compress Map | Egg Farm | Pet Finder
--   Rayfield UI Library | Tab-based | Auto-Exec Safe
-- ============================================================

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

local Players, RunService, TweenService, UserInputService, VIM, VirtualUser
repeat
    Players          = safeGetService("Players")
    RunService       = safeGetService("RunService")
    TweenService     = safeGetService("TweenService")
    UserInputService = safeGetService("UserInputService")
    VIM              = safeGetService("VirtualInputManager")
    VirtualUser      = safeGetService("VirtualUser")
    if not (Players and RunService and TweenService and UserInputService) then
        task.wait(0.3)
    end
until Players and RunService and TweenService and UserInputService

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

local deadline0 = tick() + 15
repeat task.wait(0.1) until player:FindFirstChild("PlayerGui") or tick() > deadline0

local playerGui = player:WaitForChild("PlayerGui", 30)

print("[MegaScript] ✅ Anti-fail guards OK. Memuat Rayfield...")

-- ============================================================
-- LOAD RAYFIELD UI LIBRARY
-- ============================================================
local Rayfield
local rayfieldOk, rayfieldErr = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not rayfieldOk or not Rayfield then
    warn("[MegaScript] ⚠️ Gagal load Rayfield: " .. tostring(rayfieldErr))
    warn("[MegaScript] Mencoba loadstring ulang setelah 3 detik...")
    task.wait(3)
    rayfieldOk, rayfieldErr = pcall(function()
        Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not rayfieldOk or not Rayfield then
        warn("[MegaScript] ❌ Rayfield GAGAL TOTAL. Abort.")
        return
    end
end

print("[MegaScript] ✅ Rayfield loaded!")

-- ============================================================
-- BUAT WINDOW UTAMA
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name             = "🎮  Mega Script Hub",
    LoadingTitle     = "Mega Script Hub",
    LoadingSubtitle  = "AFK · Compress · Egg Farm · Pet Finder",
    ConfigurationSaving = {
        Enabled  = false,
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- ============================================================
-- ============================================================
--   MODUL 1: AUTO RECONNECT (background, no guard needed in tab)
-- ============================================================
-- ============================================================
task.spawn(function()
    local coreGui
    do
        local e = 0
        repeat
            coreGui = game:FindService("CoreGui") or game.CoreGui
            task.wait(0.1); e += 0.1
        until coreGui or e >= 30
    end
    if not coreGui then
        warn("[AutoReconnect] CoreGui tidak ditemukan, modul dinonaktifkan.")
        return
    end

    local promptGui
    do
        local e = 0
        repeat
            promptGui = coreGui:FindFirstChild("RobloxPromptGui")
            if not promptGui then task.wait(0.2) end
            e += 0.2
        until promptGui or e >= 60
    end
    if not promptGui then
        warn("[AutoReconnect] RobloxPromptGui tidak ditemukan, modul dinonaktifkan.")
        return
    end

    local promptOverlay = promptGui:WaitForChild("promptOverlay", 30)
    if not promptOverlay then
        warn("[AutoReconnect] promptOverlay tidak ditemukan, modul dinonaktifkan.")
        return
    end

    local TeleportService = game:GetService("TeleportService")
    _G.__autoReconnect = true

    promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" and _G.__autoReconnect then
            while child and child.Parent and _G.__autoReconnect do
                pcall(function()
                    TeleportService:Teleport(game.PlaceId)
                end)
                task.wait(2)
            end
        end
    end)

    print("[AutoReconnect] Aktif & menunggu error prompt.")
end)

-- ============================================================
-- ============================================================
--   SHARED STATE: Teleport Priority System
--   PetFinder TP > Egg Farm TP (tidak boleh jalan bersamaan)
-- ============================================================
-- ============================================================
-- Ketika PetFinder autofarm / manual TP aktif → egg farm TP diblokir
_G.__petfinderTPActive = false  -- true = petfinder sedang TP
_G.__eggTPActive       = false  -- true = egg farm sedang TP

local function canEggTP()
    return not _G.__petfinderTPActive
end

-- ============================================================
-- ============================================================
--   TAB 1: AFK (Loop TP + Anti AFK + Auto Reconnect)
-- ============================================================
-- ============================================================
local TabAFK = Window:CreateTab("🛡️ AFK", 4483362458)

-- State
local loopTP_active      = false
local loopTP_running     = false
local antiAfk_active     = true
local antiAfkConn        = nil
local myPen              = nil
local claimButton        = nil
local claimButtonPos     = nil
local loopTPAvailable    = false
local penName            = "?"

-- [LOAD GUARD] Cari pen di background setelah tab dimuat
task.spawn(function()
    -- Tunggu game loaded
    local e0 = 0
    while not game:IsLoaded() and e0 < 60 do
        task.wait(0.2); e0 += 0.2
    end

    -- Tunggu character siap
    local function waitForCharacterReady()
        local char = player.Character
        if not char then char = player.CharacterAdded:Wait() end
        if not char:FindFirstChild("HumanoidRootPart") then
            char:WaitForChild("HumanoidRootPart", 15)
        end
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 15)
        if humanoid then
            local e2 = 0
            while humanoid.Health <= 0 and e2 < 5 do task.wait(0.1); e2 += 0.1 end
        end
        return char
    end
    waitForCharacterReady()

    -- Tunggu PlayerPens
    local playerPens = workspace:WaitForChild("PlayerPens", 60)
    if not playerPens then
        warn("[AFK] PlayerPens tidak ditemukan.")
        return
    end

    local function findMyPen()
        for _, pen in ipairs(playerPens:GetChildren()) do
            local owner = pen:GetAttribute("Owner")
            if owner and owner == player.Name then return pen end
        end
        return nil
    end

    myPen = findMyPen()
    if not myPen then
        local e3 = 0
        repeat
            task.wait(1); e3 += 1
            myPen = findMyPen()
        until myPen or e3 >= 60
    end

    if myPen then
        penName     = myPen.Name
        claimButton = myPen:FindFirstChild("ClaimAllButton")
        if claimButton then
            local anchorPart = claimButton:FindFirstChild("Part")
            if anchorPart and anchorPart:IsA("BasePart") then
                claimButtonPos = anchorPart.Position
            else
                local ok2, pivot = pcall(function() return claimButton:GetPivot().Position end)
                if ok2 then claimButtonPos = pivot end
            end
        end
    end

    loopTPAvailable = claimButtonPos ~= nil
    print("[AFK] Pen milikmu:", penName, "| LoopTP available:", loopTPAvailable)
end)

-- Loop TP helper
local function getTPTarget()
    if not claimButton then return claimButtonPos end
    local anchorPart = claimButton:FindFirstChild("Part")
    if anchorPart and anchorPart:IsA("BasePart") then
        return anchorPart.Position + Vector3.new(0, 30, 0)
    end
    local ok2, pivot = pcall(function() return claimButton:GetPivot().Position end)
    if ok2 and pivot then return pivot + Vector3.new(0, 30, 0) end
    return claimButtonPos and (claimButtonPos + Vector3.new(0, 30, 0)) or nil
end

local function startLoopTP()
    if loopTP_running or not loopTPAvailable then return end
    loopTP_running = true
    task.spawn(function()
        while loopTP_running and loopTP_active do
            local target = getTPTarget()
            if target then
                local char = player.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(target) end
            end
            local waited = 0
            while waited < 5 and loopTP_running and loopTP_active do
                task.wait(0.1); waited += 0.1
            end
        end
    end)
end

local function stopLoopTP()
    loopTP_running = false
end

-- Anti AFK helper
local function startAntiAfk()
    if antiAfkConn then return end
    antiAfkConn = Players.LocalPlayer.Idled:Connect(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

local function stopAntiAfk()
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
end

-- Respawn handler
player.CharacterRemoving:Connect(function()
    stopLoopTP()
end)
player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    local humanoid = char:WaitForChild("Humanoid", 10)
    if humanoid then
        local e4 = 0
        while humanoid.Health <= 0 and e4 < 5 do task.wait(0.1); e4 += 0.1 end
    end
    task.wait(0.3)
    if loopTP_active then startLoopTP() end
end)

-- Mulai anti afk secara default (ON)
startAntiAfk()

-- --- RAYFIELD UI: Tab AFK ---

TabAFK:CreateSection("Loop Teleport ke Pen")

TabAFK:CreateToggle({
    Name          = "📍 Loop TP → Pen (Auto)",
    CurrentValue  = false,     -- DEFAULT: OFF
    Flag          = "LoopTPToggle",
    Callback      = function(Value)
        loopTP_active = Value
        if Value then
            if not loopTPAvailable then
                Rayfield:Notify({
                    Title    = "Loop TP",
                    Content  = "⚠ Pen belum ditemukan! Tunggu sebentar lalu coba lagi.",
                    Duration = 4,
                    Image    = 4483362458,
                })
            else
                startLoopTP()
            end
        else
            stopLoopTP()
        end
    end,
})

TabAFK:CreateSection("Anti AFK & Reconnect")

TabAFK:CreateToggle({
    Name          = "💤 Anti AFK",
    CurrentValue  = true,      -- DEFAULT: ON
    Flag          = "AntiAFKToggle",
    Callback      = function(Value)
        antiAfk_active = Value
        if Value then startAntiAfk() else stopAntiAfk() end
    end,
})

TabAFK:CreateToggle({
    Name          = "🔄 Auto Reconnect",
    CurrentValue  = true,      -- DEFAULT: ON
    Flag          = "AutoReconnectToggle",
    Callback      = function(Value)
        _G.__autoReconnect = Value
    end,
})

TabAFK:CreateSection("Info")

TabAFK:CreateLabel("Pen: " .. (penName ~= "?" and penName or "Mendeteksi..."))
TabAFK:CreateLabel("Loop TP: teleport ke ClaimAllButton pen setiap 5 detik")
TabAFK:CreateLabel("Anti AFK: prevent kick karena idle")

-- ============================================================
-- ============================================================
--   TAB 2: COMPRESS MAP (Anti-Lag)
-- ============================================================
-- ============================================================
local TabCompress = Window:CreateTab("🗜️ Compress", 4483362458)

-- CONFIG compress
local COMPRESS_CONFIG = {
    RemoveTextures    = true,
    RemoveDecals      = true,
    RemoveParticles   = true,
    RemoveBeams       = true,
    RemoveTrails      = true,
    RemoveAtmosphere  = true,
    RemoveSky         = true,
    RemoveReflections = true,
    ResetColors       = true,
    ResetMaterial     = true,
    DefaultColor      = Color3.fromRGB(163, 162, 165),
    DefaultMaterial   = Enum.Material.SmoothPlastic,
    BatchSize         = 100,
    BatchDelay        = 0.05,
}

local compressRunning   = false
local compressAutoClean = nil

local function safeCall(fn, ...)
    pcall(fn, ...)
end

local function cleanInstance(obj)
    if not obj or not obj.Parent then return end
    local className = obj.ClassName

    if COMPRESS_CONFIG.RemoveTextures and (className == "Texture") then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveDecals and className == "Decal" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveParticles and className == "ParticleEmitter" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveBeams and className == "Beam" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveTrails and className == "Trail" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveAtmosphere and className == "Atmosphere" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveSky and className == "Sky" then
        safeCall(function() obj:Destroy() end); return
    end
    if COMPRESS_CONFIG.RemoveTextures and className == "SurfaceAppearance" then
        safeCall(function() obj:Destroy() end); return
    end
    if className == "SelectionBox" or className == "SelectionSphere" then
        safeCall(function() obj:Destroy() end); return
    end

    if obj:IsA("BasePart") then
        if COMPRESS_CONFIG.ResetColors then
            safeCall(function()
                obj.Color     = COMPRESS_CONFIG.DefaultColor
                obj.BrickColor = BrickColor.new("Medium stone grey")
            end)
        end
        if COMPRESS_CONFIG.ResetMaterial then
            safeCall(function() obj.Material = COMPRESS_CONFIG.DefaultMaterial end)
        end
        if COMPRESS_CONFIG.RemoveReflections then
            safeCall(function() obj.Reflectance = 0 end)
        end
        safeCall(function()
            obj.TopSurface    = Enum.SurfaceType.Smooth
            obj.BottomSurface = Enum.SurfaceType.Smooth
            obj.FrontSurface  = Enum.SurfaceType.Smooth
            obj.BackSurface   = Enum.SurfaceType.Smooth
            obj.LeftSurface   = Enum.SurfaceType.Smooth
            obj.RightSurface  = Enum.SurfaceType.Smooth
        end)
    end

    if className == "Shirt" or className == "Pants" or className == "ShirtGraphic" then
        safeCall(function() obj.ShirtTemplate = "" end)
        safeCall(function() obj.PantsTemplate = "" end)
        safeCall(function() obj.Graphic       = "" end)
        return
    end

    if className == "BodyColors" then
        safeCall(function()
            obj.HeadColor3      = COMPRESS_CONFIG.DefaultColor
            obj.TorsoColor3     = COMPRESS_CONFIG.DefaultColor
            obj.LeftArmColor3   = COMPRESS_CONFIG.DefaultColor
            obj.RightArmColor3  = COMPRESS_CONFIG.DefaultColor
            obj.LeftLegColor3   = COMPRESS_CONFIG.DefaultColor
            obj.RightLegColor3  = COMPRESS_CONFIG.DefaultColor
        end)
        return
    end

    if className == "Lighting" then
        safeCall(function()
            obj.GlobalShadows  = false
            obj.FogEnd         = 100000
            obj.Brightness     = 1
            obj.Ambient        = Color3.fromRGB(128, 128, 128)
            obj.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        end)
    end
end

local function processWorkspace()
    local allObjects = workspace:GetDescendants()
    local total = 0
    for i = 1, #allObjects, COMPRESS_CONFIG.BatchSize do
        for j = i, math.min(i + COMPRESS_CONFIG.BatchSize - 1, #allObjects) do
            local obj = allObjects[j]
            if obj and obj.Parent then
                safeCall(cleanInstance, obj)
                total += 1
            end
        end
        task.wait(COMPRESS_CONFIG.BatchDelay)
    end
    print("[AntiLag] Workspace selesai. Object diproses:", total)
end

local function processLighting()
    local lighting = game:GetService("Lighting")
    for _, obj in ipairs(lighting:GetDescendants()) do
        safeCall(cleanInstance, obj)
    end
    safeCall(cleanInstance, lighting)
end

local function setupAutoClean()
    if compressAutoClean then return end
    local conn1 = workspace.DescendantAdded:Connect(function(obj)
        task.wait(0.1)
        if obj and obj.Parent then
            safeCall(cleanInstance, obj)
            for _, child in ipairs(obj:GetDescendants()) do
                safeCall(cleanInstance, child)
            end
        end
    end)
    local conn2 = game:GetService("Lighting").DescendantAdded:Connect(function(obj)
        task.wait(0.1)
        if obj and obj.Parent then safeCall(cleanInstance, obj) end
    end)
    compressAutoClean = {conn1, conn2}
    print("[AntiLag] Auto-clean listener aktif.")
end

local function stopAutoClean()
    if compressAutoClean then
        for _, conn in ipairs(compressAutoClean) do
            pcall(function() conn:Disconnect() end)
        end
        compressAutoClean = nil
    end
end

local function runCompress()
    if compressRunning then return end
    compressRunning = true
    task.spawn(function()
        local ok1, e1 = pcall(processLighting)
        if not ok1 then warn("[AntiLag] Lighting error:", e1) end
        local ok2, e2 = pcall(processWorkspace)
        if not ok2 then warn("[AntiLag] Workspace error:", e2) end
        local ok3, e3 = pcall(setupAutoClean)
        if not ok3 then warn("[AntiLag] AutoClean error:", e3) end
        Rayfield:Notify({
            Title    = "Compress Map",
            Content  = "✅ Map berhasil di-compress! Performa meningkat.",
            Duration = 5,
            Image    = 4483362458,
        })
        print("[AntiLag] ✅ SELESAI! Game sudah dioptimasi.")
    end)
end

-- --- RAYFIELD UI: Tab Compress ---

TabCompress:CreateSection("Compress Map (Anti-Lag)")

TabCompress:CreateToggle({
    Name         = "🗜️ Compress Map",
    CurrentValue = false,      -- DEFAULT: OFF
    Flag         = "CompressToggle",
    Callback     = function(Value)
        if Value then
            Rayfield:Notify({
                Title    = "Compress Map",
                Content  = "Memulai compress... harap tunggu beberapa detik.",
                Duration = 3,
                Image    = 4483362458,
            })
            runCompress()
        else
            stopAutoClean()
            compressRunning = false
            Rayfield:Notify({
                Title    = "Compress Map",
                Content  = "Auto-clean dinonaktifkan. Object lama tetap tercompress.",
                Duration = 3,
                Image    = 4483362458,
            })
        end
    end,
})

TabCompress:CreateSection("Konfigurasi")

TabCompress:CreateToggle({
    Name         = "🎨 Reset Warna Part",
    CurrentValue = true,
    Flag         = "ResetColorsToggle",
    Callback     = function(Value)
        COMPRESS_CONFIG.ResetColors = Value
    end,
})

TabCompress:CreateToggle({
    Name         = "🧱 Reset Material Part",
    CurrentValue = true,
    Flag         = "ResetMaterialToggle",
    Callback     = function(Value)
        COMPRESS_CONFIG.ResetMaterial = Value
    end,
})

TabCompress:CreateToggle({
    Name         = "✨ Hapus Refleksi",
    CurrentValue = true,
    Flag         = "RemoveReflToggle",
    Callback     = function(Value)
        COMPRESS_CONFIG.RemoveReflections = Value
    end,
})

TabCompress:CreateSection("Info")
TabCompress:CreateLabel("Compress menghapus texture, decal, partikel, beam, trail,")
TabCompress:CreateLabel("atmosphere, sky, dan mereset material semua BasePart.")
TabCompress:CreateLabel("⚠ Sekali compress tidak bisa di-undo tanpa rejoin!")

-- ============================================================
-- ============================================================
--   TAB 3: EGG FARM (Chocolate Egg Farmer)
-- ============================================================
-- ============================================================
local TabEgg = Window:CreateTab("🥚 Egg Farm", 4483362458)

local eggTPEnabled      = false
local eggAutoClick      = false
local eggLoopRunning    = false
local eggCount          = 0

local function getEggs()
    local eggs = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "Chocolate Egg" then
            table.insert(eggs, obj)
        end
    end
    return eggs
end

local function setAllHoldZero()
    for _, egg in ipairs(getEggs()) do
        local root = egg:FindFirstChild("Root")
        if root then
            local pp = root:FindFirstChild("ProximityPrompt")
            if pp then pp.HoldDuration = 0 end
        end
    end
end

local function teleportToEgg(egg)
    -- Blokir jika petfinder sedang TP
    if not canEggTP() then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local root = egg:FindFirstChild("Root")
    if root and root:IsA("BasePart") then
        hrp.CFrame = root.CFrame * CFrame.new(0, 0, 3)
        _G.__eggTPActive = true
    end
end

local eggStatusLabel = nil  -- akan dikasih referensi dari rayfield paragraph

-- Mulai auto loop
local function startEggLoop()
    if eggLoopRunning then return end
    eggLoopRunning = true
    task.spawn(function()
        while eggLoopRunning and eggAutoClick do
            if not eggTPEnabled then
                task.wait(1)
            elseif _G.__petfinderTPActive then
                -- PetFinder sedang TP, yield dulu
                task.wait(0.5)
            else
                local eggs = getEggs()
                eggCount = #eggs

                for i, egg in ipairs(eggs) do
                    if not eggAutoClick or not eggLoopRunning then break end
                    if _G.__petfinderTPActive then break end  -- yield jika petfinder aktif

                    local root = egg:FindFirstChild("Root")
                    if root then
                        local pp = root:FindFirstChild("ProximityPrompt")
                        if pp then
                            pp.HoldDuration = 0
                            teleportToEgg(egg)
                            task.wait(0.15)
                            _G.__eggTPActive = false
                            fireproximityprompt(pp)
                            task.wait(0.2)
                        end
                    end
                end

                task.wait(0.3)
            end
            _G.__eggTPActive = false
        end
        _G.__eggTPActive = false
        eggLoopRunning   = false
    end)
end

local function stopEggLoop()
    eggLoopRunning   = false
    eggAutoClick     = false
    _G.__eggTPActive = false
end

-- --- RAYFIELD UI: Tab Egg Farm ---

TabEgg:CreateSection("Chocolate Egg Farm Otomatis")

TabEgg:CreateToggle({
    Name         = "🔴 Teleport to Egg",
    CurrentValue = true,       -- DEFAULT: ON
    Flag         = "EggTPToggle",
    Callback     = function(Value)
        eggTPEnabled = Value
        if Value then
            setAllHoldZero()
        else
            _G.__eggTPActive = false
        end
    end,
})

TabEgg:CreateToggle({
    Name         = "🟢 Auto Click Loop",
    CurrentValue = true,       -- DEFAULT: ON
    Flag         = "EggAutoClickToggle",
    Callback     = function(Value)
        eggAutoClick = Value
        if Value then
            startEggLoop()
        else
            stopEggLoop()
        end
    end,
})

-- Auto start loop karena default keduanya ON
eggTPEnabled = true
eggAutoClick = true
setAllHoldZero()
startEggLoop()

TabEgg:CreateSection("Info")
TabEgg:CreateLabel("Teleport to Egg: TP ke setiap egg & fire ProximityPrompt")
TabEgg:CreateLabel("Auto Click Loop: loop otomatis kumpulkan semua egg")
TabEgg:CreateLabel("⚠ Jika PetFinder TP sedang aktif, Egg TP akan yield")
TabEgg:CreateLabel("   (prioritas teleport: PetFinder > Egg Farm)")

-- ============================================================
-- ============================================================
--   TAB 4: PET FINDER
-- ============================================================
-- ============================================================
local TabPet = Window:CreateTab("🐾 Pet Finder", 4483362458)

-- ============================================================
-- Pet Finder State & Config
-- ============================================================
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

local TP_INTERVAL        = 0.1
local OFFSET             = Vector3.new(3, 0, 0)
local STRENGTH_THRESHOLD = 4800
local AUTOFARM_CPS       = 13
local WRONG_CATCH_TIMEOUT = 13

local RARITY_COLORS = {
    Common    = Color3.fromRGB(190, 190, 210),
    Rare      = Color3.fromRGB(90,  155, 255),
    Epic      = Color3.fromRGB(185, 100, 255),
    Legendary = Color3.fromRGB(255, 170, 40),
    Mythical  = Color3.fromRGB(255, 65,  90),
}
local RARITY_ORDER = {"Common", "Rare", "Epic", "Legendary", "Mythical"}

local function getAllPetsFolders()
    local folders = {}
    for _, area in ipairs(workspace:GetChildren()) do
        local petsFolder = area:FindFirstChild("Pets")
        if petsFolder then table.insert(folders, petsFolder) end
    end
    return folders
end

-- Pet Finder runtime state
local selectedPet_pf    = nil
local tpLooping_pf      = false
local tpConn_pf         = nil
local notifiedPets_pf   = {}
local autofarmQueue_pf  = {}
local autofarmRunning_pf = false
local currentFarmTarget = nil
local queuedPetKeys_pf  = {}
local autoClickActive_pf = false
local autoClickThread_pf = nil
local farmActive_pf      = false
local autofarmEnabled_pf = true
local notifEnabled_pf    = true

-- Selected rarity filter state (checkbox states mirrored through Rayfield toggles)
local checkboxStates_pf = {
    Common    = false,
    Rare      = false,
    Epic      = false,
    Legendary = false,
    Mythical  = true,   -- default ON
}

local filterMode_pf = "rarity"

-- Name filters untuk mode nama
local nameFilters_pf = {}

-- ============================================================
-- Pet Finder: Teleport helpers (with priority set)
-- ============================================================
local function stopTP_pf()
    tpLooping_pf = false
    if tpConn_pf then
        tpConn_pf:Disconnect()
        tpConn_pf = nil
    end
    _G.__petfinderTPActive = false
end

local function pfTPToPet(pet)
    if not pet or not pet.Parent then return end
    local char = player.Character
    if not char then return end
    local root    = char:FindFirstChild("HumanoidRootPart")
    local petRoot = pet:FindFirstChild("HumanoidRootPart")
        or pet:FindFirstChildWhichIsA("BasePart")
    if root and petRoot then
        _G.__petfinderTPActive = true
        root.CFrame = petRoot.CFrame + OFFSET
    end
end

-- ============================================================
-- Pet Finder: AutoClick helpers
-- ============================================================
local function startAutoClick_pf(cps)
    if not VIM then return end
    autoClickActive_pf = true
    local interval = 1 / cps
    autoClickThread_pf = task.spawn(function()
        while autoClickActive_pf do
            local vp     = workspace.CurrentCamera.ViewportSize
            local cx, cy = math.floor(vp.X / 2), math.floor(vp.Y / 2)
            pcall(function() VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 0) end)
            task.wait(0.01)
            pcall(function() VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
            task.wait(math.max(0.001, interval - 0.01))
        end
    end)
end

local function stopAutoClick_pf()
    autoClickActive_pf = false
    if autoClickThread_pf then
        task.cancel(autoClickThread_pf)
        autoClickThread_pf = nil
    end
end

-- ============================================================
-- Pet Finder: Lasso equip helpers
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
    if humanoid then pcall(function() humanoid:UnequipTools() end) end
end

local function pressKey1()
    if not VIM then return end
    pcall(function() VIM:SendKeyEvent(true,  Enum.KeyCode.One, false, game) end)
    task.wait(0.04)
    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.One, false, game) end)
end

local function reequipLasso()
    unequipAll()
    local t0 = tick()
    while isLassoEquipped() and (tick() - t0) < 1.5 do task.wait(0.05) end
    task.wait(0.12)
    local t1 = tick()
    while not isLassoEquipped() and (tick() - t1) < 3 do
        pressKey1(); task.wait(0.18)
    end
    return isLassoEquipped()
end

-- ============================================================
-- Pet Finder: Wrong-catch monitor
-- ============================================================
local function startWrongCatchMonitor_pf(getPet, getFarmActive, petNameStr)
    return task.spawn(function()
        local lassoUnequipStart = nil
        local recovering        = false

        while getFarmActive() do
            task.wait(0.1)
            if not autofarmEnabled_pf then
                lassoUnequipStart = nil; recovering = false; task.wait(0.3)
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
                    print("[PetFinder] ⚠️ Salah tangkap! Reequip...")
                    stopAutoClick_pf()
                    local ok = reequipLasso()
                    if ok and getFarmActive() and (pet and pet.Parent) then
                        startAutoClick_pf(AUTOFARM_CPS)
                        print("[PetFinder] ✅ Reequip berhasil.")
                    end
                    lassoUnequipStart = nil; recovering = false
                end
            end
        end
    end)
end

-- ============================================================
-- Pet Finder: Farm single target
-- ============================================================
local function farmTarget_pf(pet)
    if not pet or not pet.Parent then return end
    currentFarmTarget    = pet
    farmActive_pf        = true
    _G.__petfinderTPActive = true  -- Set priority flag

    local petName = pet:GetAttribute("Name") or pet.Name
    local str     = tonumber(pet:GetAttribute("Strength")) or 0
    print(string.format("[PetFinder] 🎯 Autofarm: %s | STR %d", petName, str))

    pfTPToPet(pet)
    task.wait(0.15)

    local equipped = reequipLasso()
    if not equipped then
        warn("[PetFinder] ⚠️ Lasso tidak bisa di-equip, skip.")
        currentFarmTarget      = nil
        farmActive_pf          = false
        _G.__petfinderTPActive = false
        return
    end

    startAutoClick_pf(AUTOFARM_CPS)

    local monitorThread = startWrongCatchMonitor_pf(
        function() return pet end,
        function() return farmActive_pf end,
        petName
    )

    local farmConn
    farmConn = RunService.Heartbeat:Connect(function()
        if not autofarmEnabled_pf then
            stopAutoClick_pf()
            farmConn:Disconnect()
            pcall(function() task.cancel(monitorThread) end)
            currentFarmTarget      = nil
            farmActive_pf          = false
            _G.__petfinderTPActive = false
            return
        end
        if not pet or not pet.Parent then
            stopAutoClick_pf()
            farmConn:Disconnect()
            pcall(function() task.cancel(monitorThread) end)
            currentFarmTarget      = nil
            farmActive_pf          = false
            _G.__petfinderTPActive = false
            return
        end
        pfTPToPet(pet)
    end)

    while (pet and pet.Parent) and autofarmEnabled_pf do
        task.wait(0.2)
    end

    stopAutoClick_pf()
    pcall(function() farmConn:Disconnect() end)
    pcall(function() task.cancel(monitorThread) end)
    currentFarmTarget      = nil
    farmActive_pf          = false
    _G.__petfinderTPActive = false

    task.wait(0.3)
    print("[PetFinder] 🔄 Target selesai, lanjut queue...")
end

-- ============================================================
-- Pet Finder: Queue processor
-- ============================================================
local function processQueue_pf()
    if autofarmRunning_pf then return end
    autofarmRunning_pf = true
    task.spawn(function()
        while true do
            if not autofarmEnabled_pf then
                task.wait(0.5)
            elseif #autofarmQueue_pf > 0 then
                local next = table.remove(autofarmQueue_pf, 1)
                if next and next.Parent then
                    local s = tonumber(next:GetAttribute("Strength")) or 0
                    if s >= STRENGTH_THRESHOLD then
                        queuedPetKeys_pf[tostring(next)] = nil
                        farmTarget_pf(next)
                        task.wait(0.3)
                    end
                else
                    queuedPetKeys_pf[tostring(next)] = nil
                end
            else
                task.wait(0.3)
            end
        end
    end)
end

local function queueAutofarm_pf(pet)
    if not autofarmEnabled_pf then return end
    local key = tostring(pet)
    if queuedPetKeys_pf[key] then return end
    if currentFarmTarget == pet then return end
    if not pet or not pet.Parent then return end
    queuedPetKeys_pf[key] = true
    table.insert(autofarmQueue_pf, pet)
    processQueue_pf()
end

processQueue_pf()

-- ============================================================
-- Pet Finder: Notif & trigger
-- ============================================================
local function triggerNotif_pf(pet)
    local key = tostring(pet)
    if notifiedPets_pf[key] then return end
    notifiedPets_pf[key] = true

    local petName  = pet:GetAttribute("Name") or pet.Name
    local strength = tonumber(pet:GetAttribute("Strength")) or 0
    local rarity   = pet:GetAttribute("Rarity") or "Common"

    if notifEnabled_pf then
        Rayfield:Notify({
            Title    = "⚡ " .. rarity:upper() .. " Ditemukan!",
            Content  = petName .. " — STR " .. tostring(strength),
            Duration = 6,
            Image    = 4483362458,
        })
    end

    queueAutofarm_pf(pet)
    print(string.format("[PetFinder] ⚡ Detected: %s | STR %d | %s", petName, strength, rarity))
end

-- ============================================================
-- Pet Finder: Search logic
-- ============================================================
local isSearchActive_pf    = false
local autoRefreshThread_pf = nil

local function matchesNameFilter_pf(pet)
    if #nameFilters_pf == 0 then return false end
    local petName = (pet:GetAttribute("Name") or pet.Name):lower()
    for _, entry in ipairs(nameFilters_pf) do
        if petName:find(entry:lower(), 1, true) then return true end
    end
    return false
end

local function doSearch_pf(isRefresh)
    if filterMode_pf == "rarity" then
        local anySelected = false
        for _, v in pairs(checkboxStates_pf) do if v then anySelected = true; break end end
        if not anySelected then
            if not isRefresh then
                Rayfield:Notify({
                    Title   = "Pet Finder",
                    Content = "⚠ Pilih minimal 1 rarity dulu!",
                    Duration = 3, Image = 4483362458,
                })
            end
            return
        end
    else
        if #nameFilters_pf == 0 then
            if not isRefresh then
                Rayfield:Notify({
                    Title   = "Pet Finder",
                    Content = "⚠ Tambah nama filter dulu!",
                    Duration = 3, Image = 4483362458,
                })
            end
            return
        end
    end

    local filtered = {}
    for _, petsFolder in ipairs(getAllPetsFolders()) do
        for _, pet in ipairs(petsFolder:GetChildren()) do
            local pass = false
            if filterMode_pf == "rarity" then
                local rarity = pet:GetAttribute("Rarity")
                pass = rarity and checkboxStates_pf[rarity] == true
            else
                pass = matchesNameFilter_pf(pet)
            end
            if pass then table.insert(filtered, pet) end
        end
    end

    table.sort(filtered, function(a, b)
        local sa = tonumber(a:GetAttribute("Strength")) or 0
        local sb = tonumber(b:GetAttribute("Strength")) or 0
        return sa > sb
    end)

    local count = 0
    for _, pet in ipairs(filtered) do
        count += 1
        local strength = tonumber(pet:GetAttribute("Strength")) or 0
        if strength >= STRENGTH_THRESHOLD then
            triggerNotif_pf(pet)
        end
    end

    if not isRefresh then
        Rayfield:Notify({
            Title   = "Pet Finder",
            Content = string.format("✔ %d hewan ditemukan (STR %d+ akan di-autofarm)", count, STRENGTH_THRESHOLD),
            Duration = 5, Image = 4483362458,
        })
    end

    if not isRefresh then
        if autoRefreshThread_pf then task.cancel(autoRefreshThread_pf) end
        isSearchActive_pf = true
        autoRefreshThread_pf = task.spawn(function()
            while isSearchActive_pf do
                task.wait(3)
                if isSearchActive_pf then doSearch_pf(true) end
            end
        end)
    end
end

-- ============================================================
-- Rayfield UI: Tab Pet Finder
-- ============================================================

TabPet:CreateSection("Filter Rarity")

for _, rarity in ipairs(RARITY_ORDER) do
    local defaultOn = (rarity == "Mythical")
    TabPet:CreateToggle({
        Name         = "🔸 " .. rarity,
        CurrentValue = defaultOn,
        Flag         = "PF_Rarity_" .. rarity,
        Callback     = function(Value)
            checkboxStates_pf[rarity] = Value
        end,
    })
end

TabPet:CreateSection("Autofarm & Notifikasi")

TabPet:CreateToggle({
    Name         = "⚔ Autofarm (STR " .. STRENGTH_THRESHOLD .. "+)",
    CurrentValue = true,       -- DEFAULT: ON
    Flag         = "PF_AutofarmToggle",
    Callback     = function(Value)
        autofarmEnabled_pf = Value
    end,
})

TabPet:CreateToggle({
    Name         = "🔔 Notifikasi Pet Kuat",
    CurrentValue = true,       -- DEFAULT: ON
    Flag         = "PF_NotifToggle",
    Callback     = function(Value)
        notifEnabled_pf = Value
    end,
})

TabPet:CreateSection("Kontrol Pencarian")

TabPet:CreateButton({
    Name     = "🔍 Cari Hewan (Jalankan/Refresh)",
    Callback = function()
        isSearchActive_pf = false
        if autoRefreshThread_pf then task.cancel(autoRefreshThread_pf) end
        notifiedPets_pf  = {}
        queuedPetKeys_pf = {}
        autofarmQueue_pf = {}
        doSearch_pf(false)
    end,
})

TabPet:CreateButton({
    Name     = "⏹ Stop Autofarm",
    Callback = function()
        autofarmEnabled_pf     = false
        isSearchActive_pf      = false
        _G.__petfinderTPActive = false
        if autoRefreshThread_pf then task.cancel(autoRefreshThread_pf) end
        stopAutoClick_pf()
        stopTP_pf()
        Rayfield:Notify({
            Title   = "Pet Finder",
            Content = "Autofarm dihentikan.",
            Duration = 3, Image = 4483362458,
        })
    end,
})

TabPet:CreateButton({
    Name     = "▶ Resume Autofarm",
    Callback = function()
        autofarmEnabled_pf = true
        Rayfield:Notify({
            Title   = "Pet Finder",
            Content = "Autofarm dilanjutkan.",
            Duration = 3, Image = 4483362458,
        })
    end,
})

TabPet:CreateSection("Filter Nama (Mode Alternatif)")

TabPet:CreateInput({
    Name          = "Tambah Filter Nama",
    PlaceholderText = "Ketik nama hewan...",
    RemoveTextAfterFocusLost = true,
    Flag          = "PF_NameInput",
    Callback      = function(Text)
        if not Text or Text:gsub("%s+", "") == "" then return end
        Text = Text:gsub("^%s+", ""):gsub("%s+$", "")
        if #nameFilters_pf >= 8 then
            Rayfield:Notify({Title="Pet Finder", Content="⚠ Maksimal 8 nama filter!", Duration=3, Image=4483362458})
            return
        end
        for _, e in ipairs(nameFilters_pf) do
            if e:lower() == Text:lower() then
                Rayfield:Notify({Title="Pet Finder", Content="⚠ Nama sudah ada!", Duration=2, Image=4483362458})
                return
            end
        end
        table.insert(nameFilters_pf, Text)
        filterMode_pf = "name"
        Rayfield:Notify({
            Title   = "Pet Finder",
            Content = "Filter nama ditambah: " .. Text .. " (total: " .. #nameFilters_pf .. ")",
            Duration = 3, Image = 4483362458,
        })
    end,
})

TabPet:CreateButton({
    Name     = "🗑 Hapus Semua Filter Nama (kembali ke Rarity)",
    Callback = function()
        nameFilters_pf = {}
        filterMode_pf  = "rarity"
        Rayfield:Notify({
            Title   = "Pet Finder",
            Content = "Filter nama dihapus. Mode kembali ke Rarity.",
            Duration = 3, Image = 4483362458,
        })
    end,
})

TabPet:CreateSection("Info")
TabPet:CreateLabel("TP Priority: PetFinder > Egg Farm (tidak tumpang tindih)")
TabPet:CreateLabel("Autofarm akan queue target STR " .. STRENGTH_THRESHOLD .. "+ secara otomatis")
TabPet:CreateLabel("Auto refresh pencarian setiap 3 detik saat aktif")

-- ============================================================
-- Auto Init PetFinder: aktifkan Mythical + langsung search
-- ============================================================
task.spawn(function()
    task.wait(1.5)
    checkboxStates_pf["Mythical"] = true
    task.wait(0.3)
    isSearchActive_pf = false
    notifiedPets_pf  = {}
    queuedPetKeys_pf = {}
    autofarmQueue_pf = {}
    doSearch_pf(false)
    print("[PetFinder] ✅ Auto-search Mythical dimulai!")
end)

-- ============================================================
-- ============================================================
--   PRINT SUMMARY
-- ============================================================
-- ============================================================
print("=========================================")
print("[MegaScript] ✅ SEMUA MODUL LOADED!")
print("[MegaScript] Tab 1: AFK (Loop TP: OFF | Anti AFK: ON | Reconnect: ON)")
print("[MegaScript] Tab 2: Compress Map (default: OFF)")
print("[MegaScript] Tab 3: Egg Farm (TP: ON | AutoClick: ON)")
print("[MegaScript] Tab 4: Pet Finder (Autofarm: ON | Notif: ON | Mythical auto-search)")
print("[MegaScript] TP Priority: PetFinder > Egg Farm")
print("=========================================")
