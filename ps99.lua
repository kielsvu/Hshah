local function enableInfPetSpeed()
    local playerPets = require(game.ReplicatedStorage.Library.Client.PlayerPet)
    if playerPets then
        playerPets.CalculateSpeedMultiplier = function()
            return math.huge
        end
    end
end
enableInfPetSpeed()

local function getTimeTrialInstance()
    local container = workspace.__THINGS and workspace.__THINGS.__INSTANCE_CONTAINER
    if not container then return nil end
    local active = container:FindFirstChild("Active")
    if not active then return nil end
    return active:FindFirstChild("TimeTrial")
end

local function teleportTo(cframe)
    local char = game.Players.LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = cframe
    end
end

local function teleportToZone(index)
    local timeTrial = getTimeTrialInstance()
    if not timeTrial then return end
    local breakZones = timeTrial:FindFirstChild("BREAK_ZONES")
    if not breakZones then return end
    local zones = breakZones:GetChildren()
    if #zones < index then return end
    local zone = zones[index]
    local spawnPart = zone:FindFirstChild("Spawn")
    local targetCF = spawnPart and spawnPart.CFrame or zone:GetPivot()
    if targetCF then
        teleportTo(targetCF)
    end
end

local Network = require(game:GetService("ReplicatedStorage").Library.Client.Network)

local function collectOrbs()
    local orbsFolder = workspace.__THINGS and workspace.__THINGS.Orbs
    if not orbsFolder then return end
    local orbs = orbsFolder:GetChildren()
    if #orbs == 0 then return end
    for _, orb in ipairs(orbs) do
        local orbId = tonumber(orb.Name)
        if orbId and orbId > 0 then
            Network.Fire("Orbs: Collect", { orbId })
            orb:Destroy()
        end
    end
end

local cachedBreakableNames = {}
local lastRefreshTime = 0
local REFRESH_INTERVAL = 2
local currentZone = nil

local function getBreakablesInZoneCached()
    local now = tick()
    if (now - lastRefreshTime) > REFRESH_INTERVAL then
        local timeTrial = getTimeTrialInstance()
        if not timeTrial then
            cachedBreakableNames = {}
        else
            local breakZones = timeTrial:FindFirstChild("BREAK_ZONES")
            if breakZones then
                local zones = breakZones:GetChildren()
                if #zones > 0 then
                    currentZone = zones[1]
                end
            end
            if not currentZone then
                cachedBreakableNames = {}
            else
                local center = currentZone:GetPivot() or (currentZone:FindFirstChild("Spawn") and currentZone.Spawn.CFrame)
                if not center then
                    cachedBreakableNames = {}
                else
                    local breakables = workspace.__THINGS and workspace.__THINGS.Breakables
                    if not breakables then
                        cachedBreakableNames = {}
                    else
                        local radius = 230
                        local result = {}
                        for _, child in ipairs(breakables:GetChildren()) do
                            if child:IsA("Model") then
                                if child:GetAttribute("ParentID") == "TimeTrial" then
                                    local dist = (child:GetPivot().Position - center.Position).Magnitude
                                    if dist <= radius then
                                        table.insert(result, child.Name)
                                    end
                                end
                            end
                        end
                        cachedBreakableNames = result
                    end
                end
            end
        end
        lastRefreshTime = now
    end
    return cachedBreakableNames
end

task.spawn(function()
    while true do
        collectOrbs()
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        local breakableNames = getBreakablesInZoneCached()
        if #breakableNames > 0 then
            local randomBreakable = breakableNames[math.random(1, #breakableNames)]
            Network.UnreliableFire("Breakables_PlayerDealDamage", randomBreakable)
        end
        task.wait(1)
    end
end)

local function createTeleportUI()
    local player = game.Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name = "TimeTrialTeleport"
    gui.Parent = player:WaitForChild("PlayerGui")
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 240)
    frame.Position = UDim2.new(0, 10, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Time Trial Teleport"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, 0, 1, -30)
    buttonContainer.Position = UDim2.new(0, 0, 0, 30)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = frame

    for i = 1, 6 do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 28)
        btn.Position = UDim2.new(0, 5, 0, (i - 1) * 32 + 5)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.Gotham
        btn.Text = "Zone " .. i
        btn.Parent = buttonContainer
        btn.MouseButton1Click:Connect(function()
            teleportToZone(i)
        end)
    end
end

task.wait(0.5)
createTeleportUI()
