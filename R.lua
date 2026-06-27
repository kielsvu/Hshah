-- Build A Boat AutoFarm – Tween Speed 10s, Game Respawn, Webhook Reports
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local webhookURL = "https://discord.com/api/webhooks/1434932220258291742/o6KZXO3PBAj9bJZHzs5RtpoVBSNZnBI2S1xpdgUHV2kiZ4zfylLBBeVSBaQdjZO1YBxq"

-- Positions
local Pos1 = Vector3.new(-55, -5, -225)
local Pos2 = Vector3.new(-20, 65, 8819)
local Pos3 = Vector3.new(-55, -358, 9492)

local tweenDuration = 10           -- FASTER (was 15)
local safeMinY = -40
local bufferY = 2
local farmRuns = 0
local lastWebhookTime = tick()
local WEBHOOK_INTERVAL = 300       -- 5 minutes

local lastInputTime = tick()
local isFarming = false
local isWaitingForRespawn = false
local respawnTimeout = 10          -- adjust if game takes longer to respawn

-- Find claim remote (prefer workspace)
local claimRemote = Workspace:FindFirstChild("ClaimRiverResultsGold")
    or ReplicatedStorage:FindFirstChild("ClaimRiverResultsGold")
    or (ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("ClaimRiverResultsGold"))

if claimRemote then
    print("✅ Claim remote found:", claimRemote:GetFullName())
else
    print("⚠️ Claim remote not found – will still farm but gold may not register.")
end

-- Gold reader
local function getGold()
    if _G.Data and _G.Data.gold then return _G.Data.gold end
    local dataFolder = player:FindFirstChild("Data")
    if dataFolder then
        local gold = dataFolder:FindFirstChild("Gold")
        if gold and gold:IsA("IntValue") then return gold.Value end
    end
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local gold = ls:FindFirstChild("Gold")
        if gold then return gold.Value end
    end
    return 0
end

-- Anti‑AFK
local function antiAFK()
    local now = tick()
    if now - lastInputTime >= 120 then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        lastInputTime = now
    end
end

-- Webhook sender
local function sendWebhook(runCount)
    local gold = getGold()
    local data = {
        ["embeds"] = {{
            ["title"] = "Build A Boat Gold Report",
            ["color"] = 7506394,
            ["fields"] = {
                {["name"] = "Total Gold", ["value"] = tostring(gold), ["inline"] = true},
                {["name"] = "Runs", ["value"] = tostring(runCount), ["inline"] = true},
                {["name"] = "Gold/Run", ["value"] = runCount > 0 and string.format("%.1f", gold / runCount) or "0", ["inline"] = true},
                {["name"] = "Time", ["value"] = os.date("%Y-%m-%d %H:%M:%S"), ["inline"] = false}
            },
            ["footer"] = {["text"] = "AutoFarm | Reports every 5 min"}
        }}
    }
    pcall(function()
        HttpService:PostAsync(webhookURL, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson, false, {
            ["Content-Type"] = "application/json"
        })
        print("📤 Webhook sent – Gold:", gold)
    end)
end

local function checkWebhookTimer()
    if tick() - lastWebhookTime >= WEBHOOK_INTERVAL then
        sendWebhook(farmRuns)
        lastWebhookTime = tick()
    end
end

-- Root part finder
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

-- NoClip
local function noClip(char, state)
    if not char then return end
    pcall(function()
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                v.CanCollide = not state
            end
        end
    end)
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.PlatformStand = state end
end

-- Tween movement
local function tweenTo(root, target, duration)
    if not root or not root.Parent then return end
    noClip(root.Parent, true)
    local startPos = root.Position
    local elapsed = 0
    local look = root.CFrame.LookVector

    while elapsed < duration and root and root.Parent do
        local dt = RunService.Heartbeat:Wait()
        elapsed = elapsed + dt
        local alpha = math.clamp(elapsed / duration, 0, 1)
        local newPos = startPos:Lerp(target, alpha)
        local y = math.max(newPos.Y, safeMinY)
        newPos = Vector3.new(newPos.X, y + bufferY, newPos.Z)
        root.CFrame = CFrame.new(newPos, newPos + look)
        root.Velocity = Vector3.zero
        root.RotVelocity = Vector3.zero
        antiAFK()
    end

    if root and root.Parent then
        root.CFrame = CFrame.new(target + Vector3.new(0, bufferY, 0))
        noClip(root.Parent, false)
    end
end

-- Perform one farm run
local function performRun()
    local char = player.Character
    if not char or not char.Parent then
        player.CharacterAdded:Wait()
        char = player.Character
    end

    local root = getRoot(char)
    if not root then
        print("No root part found.")
        return false
    end

    root.CFrame = CFrame.new(Pos1)
    task.wait(0.25)

    root = getRoot(player.Character)
    if root then
        tweenTo(root, Pos2, tweenDuration)
    end
    task.wait(0.25)

    root = getRoot(player.Character)
    if not root then
        return false
    end

    local currentGold = getGold()
    root.CFrame = CFrame.new(Pos3)

    local timeout = tick() + 5
    while getGold() == currentGold and tick() < timeout do
        task.wait(0.05)
        antiAFK()
        checkWebhookTimer()
    end

    if claimRemote then
        pcall(function() claimRemote:FireServer() end)
    end

    farmRuns = farmRuns + 1
    print("Run completed. Total runs:", farmRuns)
    checkWebhookTimer()
    return true
end

-- Wait for game's automatic respawn
local function waitForRespawn(timeout)
    local start = tick()
    isWaitingForRespawn = true
    while tick() - start < timeout do
        if player.Character and player.Character.Parent then
            isWaitingForRespawn = false
            return true
        end
        task.wait(0.1)
        checkWebhookTimer()
    end
    isWaitingForRespawn = false
    return false
end

-- Main farming loop
local function startAutoFarm()
    print("Auto-farm started. Tween speed set to 10 seconds.")
    while true do
        local char = player.Character
        if not char or not char.Parent then
            player.CharacterAdded:Wait()
            char = player.Character
        end

        isFarming = true
        local runSuccess = performRun()
        isFarming = false

        if not runSuccess then
            print("Run failed. Will retry after respawn.")
        end

        print("Waiting for game to respawn player... (timeout: " .. respawnTimeout .. "s)")
        local respawned = waitForRespawn(respawnTimeout)

        if not respawned then
            warn("Game did not respawn within timeout. Waiting for character to appear...")
            player.CharacterAdded:Wait()
            print("Character respawned. Resuming.")
        end
    end
end

-- Background anti‑AFK + webhook timer
task.spawn(function()
    while true do
        task.wait(60)
        antiAFK()
        checkWebhookTimer()
    end
end)

-- Send initial test webhook
task.wait(3)
sendWebhook(0)

-- Start the farm
startAutoFarm()
