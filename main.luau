task.wait(1)

-- // Services // --
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- // Blacklist System // --
local blacklist = {}
local localPlayer = Players.LocalPlayer
if blacklist[localPlayer.Name] then
    warn("Akses ditolak: Anda masuk dalam daftar blacklist.")
    return
end

-- // Status / State Fitur // --
local instantEnabled = false
local spamEnabled = false
local autoDropEnabled = false
local antiLagPlantsEnabled = false
local texturesCleared = false
local fruitPriceEnabled = false

-- // Tabel Penyimpanan Data Asli // --
local originalPlantData = {}
local originalTextures = {}
local originalLightingEffects = {}

-- // DATABASE TANAMAN (BASE SELL ONLY) // --
local CROP_DATA = {
    ["Rocket Pop"]      = 22500,
    ["Mushroom"]        = 13000,
    ["Hypno Bloom"]     = 9500,
    ["Moon Bloom"]      = 9000,
    ["Venom Spitter"]   = 3800,
    ["Dragon's Breath"] = 3400,
    ["Venus Fly Trap"]  = 3000,
    ["Ghost Pepper"]    = 2500,
    ["Sunflower"]       = 1750,
    ["Poison Ivy"]      = 1700,
    ["Pomegranate"]     = 900,
    ["Poison Apple"]    = 900,
    ["Fire Fern"]       = 900,
    ["Bamboo"]          = 800,
}

-- // 1. LOGIKA INSTANT INTERACT // --
local function makeInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        if instantEnabled then
            if not prompt:GetAttribute("OriginalDuration") then
                prompt:SetAttribute("OriginalDuration", prompt.HoldDuration)
            end
            prompt.HoldDuration = 0
        else
            local original = prompt:GetAttribute("OriginalDuration")
            if original then prompt.HoldDuration = original end
        end
    end
end

local function refreshPrompts()
    for _, descendant in ipairs(game:GetDescendants()) do
        makeInstant(descendant)
    end
end

game.DescendantAdded:Connect(function(descendant)
    if instantEnabled then
        task.wait(0.1)
        makeInstant(descendant)
    end
end)

-- // 2. LOGIKA AUTO SPAM E // --
task.spawn(function()
    while true do
        if spamEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(0.03)
        else
            task.wait(0.1)
        end
    end
end)

-- // 3. LOGIKA AUTO DROP (SPAM BACKSPACE) // --
task.spawn(function()
    while true do
        if autoDropEnabled then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
            task.wait(0.03)
        else
            task.wait(0.1)
        end
    end
end)

-- // 4. LOGIKA ANTI-LAG PLANTS // --
local function minimizePlantVisuals(plantModel)
    if not plantModel:IsA("Model") then return end
    
    for _, child in ipairs(plantModel:GetDescendants()) do
        if child:IsA("BasePart") or child:IsA("MeshPart") then
            if not originalPlantData[child] then
                originalPlantData[child] = {
                    Size = child.Size,
                    Transparency = child.Transparency,
                    CanCollide = child.CanCollide
                }
            end
            child.Size = Vector3.new(0, 0, 0)
            child.Transparency = 1
            child.CanCollide = false
        elseif child:IsA("Decal") or child:IsA("Texture") then
            if not originalPlantData[child] then
                originalPlantData[child] = { Transparency = child.Transparency }
            end
            child.Transparency = 1
        end
    end
end

local function restorePlantVisuals()
    for child, data in pairs(originalPlantData) do
        if child and child.Parent then
            if child:IsA("BasePart") or child:IsA("MeshPart") then
                child.Size = data.Size
                child.Transparency = data.Transparency
                child.CanCollide = data.CanCollide
            elseif child:IsA("Decal") or child:IsA("Texture") then
                child.Transparency = data.Transparency
            end
        end
    end
    table.clear(originalPlantData)
end

local function processAllPlants()
    local Gardens = game.Workspace:FindFirstChild("Gardens")
    if not Gardens then return end

    if antiLagPlantsEnabled then
        for _, plot in ipairs(Gardens:GetChildren()) do
            local PlantsFolder = plot:FindFirstChild("Plants")
            if PlantsFolder then
                for _, plant in ipairs(PlantsFolder:GetChildren()) do
                    minimizePlantVisuals(plant)
                end
            end
        end
    else
        restorePlantVisuals()
    end
end

local Gardens = game.Workspace:FindFirstChild("Gardens")
if Gardens then
    for _, plot in ipairs(Gardens:GetChildren()) do
        local PlantsFolder = plot:FindFirstChild("Plants")
        if PlantsFolder then
            PlantsFolder.ChildAdded:Connect(function(newPlant)
                task.wait(0.05)
                if antiLagPlantsEnabled then 
                    minimizePlantVisuals(newPlant) 
                end
            end)
        end
    end
end

-- // 5. LOGIKA CLEAR TEXTURES & LIGHTING EFFECTS // --
local function toggleTexturesAndLighting(state)
    if state then
        for _, v in ipairs(game.Workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("MeshPart") then
                originalTextures[v] = {Material = v.Material, Color = v.Color}
                v.Material = Enum.Material.SmoothPlastic
            elseif v:IsA("Texture") or v:IsA("Decal") then
                originalTextures[v] = {Parent = v.Parent}
                v.Parent = nil
            end
        end
        
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Sky") or string.find(effect.Name, "Effect") or string.find(effect.Name, "SunRays") or effect.Name == "Charles" then
                originalLightingEffects[effect] = {Parent = effect.Parent}
                effect.Parent = nil
            end
        end
    else
        for obj, data in pairs(originalTextures) do
            if obj and typeof(obj) == "Instance" then
                if obj:IsA("BasePart") then
                    obj.Material = data.Material
                else
                    obj.Parent = data.Parent
                end
            end
        end
        table.clear(originalTextures)
        
        for effect, data in pairs(originalLightingEffects) do
            if effect and typeof(effect) == "Instance" then
                effect.Parent = data.Parent
            end
        end
        table.clear(originalLightingEffects)
    end
end

-- // 6. LOGIKA FRUIT PRICE OVERLAY + TOTAL VALUE HEADER // --
local function formatPrice(amount)
    if amount >= 1000000 then
        return string.format("%.2fM¢", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("%.2fK¢", amount / 1000)
    else
        return string.format("%.0f¢", amount)
    end
end

local function getCropNameForSlot(weightLabel)
    local checkFrames = { weightLabel.Parent, weightLabel.Parent and weightLabel.Parent.Parent }
    
    for _, frame in ipairs(checkFrames) do
        if frame and frame:IsA("GuiObject") then
            for _, child in ipairs(frame:GetDescendants()) do
                if child:IsA("TextLabel") and child ~= weightLabel and child.Name ~= "PriceTagOverlay" then
                    local textClean = string.match(child.Text, "^%s*(.-)%s*$") or child.Text
                    local textLower = string.lower(textClean)
                    
                    -- ABAIKAN KATA SEED / BENIH
                    if string.find(textLower, "seed") or string.find(textLower, "benih") then
                        return nil
                    end
                    
                    for knownCrop, _ in pairs(CROP_DATA) do
                        if textLower == string.lower(knownCrop) then
                            return knownCrop
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function getInventoryContainer()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    for _, guiObj in ipairs(playerGui:GetDescendants()) do
        if guiObj:IsA("TextLabel") and (guiObj.Text == "Inventory" or string.find(guiObj.Text, "Fruits")) then
            local container = guiObj.Parent
            if container and container.Name ~= "PlayerGui" then
                return container.Parent or container
            end
        end
    end
    
    return playerGui:FindFirstChild("Inventory", true)
end

local function processInventorySlots()
    if not fruitPriceEnabled then return end

    local inventoryContainer = getInventoryContainer()
    if not inventoryContainer then return end

    if inventoryContainer:IsA("GuiObject") and not inventoryContainer.Visible then
        return
    end

    local grandTotalValue = 0

    -- SCAN SLOT DI DALAM INVENTORY & HOTBAR
    for _, guiObj in ipairs(inventoryContainer:GetDescendants()) do
        if guiObj:IsA("TextLabel") and guiObj.Name ~= "PriceTagOverlay" and guiObj.Name ~= "TotalValueBanner" then
            local textLower = string.lower(guiObj.Text)
            
            if string.find(textLower, "kg") and string.match(textLower, "[%d%.]+") then
                local weightLabel = guiObj
                local weightText = weightLabel.Text
                
                local cropName = getCropNameForSlot(weightLabel)
                
                if cropName then
                    local baseSell = CROP_DATA[cropName]
                    local weight = tonumber(string.match(weightText, "[%d%.]+"))
                    
                    if baseSell and weight then
                        local totalPrice = weight * baseSell
                        grandTotalValue = grandTotalValue + totalPrice -- Tambahkan ke Total
                        
                        local priceString = formatPrice(totalPrice)
                        
                        local priceTag = weightLabel:FindFirstChild("PriceTagOverlay")
                        if not priceTag then
                            priceTag = Instance.new("TextLabel")
                            priceTag.Name = "PriceTagOverlay"
                            priceTag.Size = UDim2.new(1, 20, 0, 14)
                            priceTag.Position = UDim2.new(0.5, 0, 0, -14)
                            priceTag.AnchorPoint = Vector2.new(0.5, 0)
                            priceTag.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            priceTag.BackgroundTransparency = 0.2
                            priceTag.TextColor3 = Color3.fromRGB(255, 215, 0)
                            priceTag.Font = Enum.Font.SourceSansBold
                            priceTag.TextSize = 11
                            priceTag.ZIndex = weightLabel.ZIndex + 50
                            priceTag.Parent = weightLabel
                            
                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(0, 3)
                            corner.Parent = priceTag
                        end
                        priceTag.Text = "≈ " .. priceString
                        priceTag.Visible = true
                    end
                end
            end
        end
    end

    -- // BANNER TOTAL HARGA BUAH (DITAMPIKAN DI DALAM FRAME TOP HEADER Y = 6px) // --
    local totalBanner = inventoryContainer:FindFirstChild("TotalValueBanner")
    if not totalBanner then
        totalBanner = Instance.new("TextLabel")
        totalBanner.Name = "TotalValueBanner"
        totalBanner.Size = UDim2.new(0, 210, 0, 22)
        totalBanner.Position = UDim2.new(0.5, 0, 0, 6) -- Di tengah atas di dalam frame Inventory
        totalBanner.AnchorPoint = Vector2.new(0.5, 0)
        totalBanner.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        totalBanner.BackgroundTransparency = 0.2
        totalBanner.TextColor3 = Color3.fromRGB(255, 215, 0) -- Warna Emas
        totalBanner.Font = Enum.Font.SourceSansBold
        totalBanner.TextSize = 12
        totalBanner.ZIndex = 1000 -- Memastikan selalu di paling depan
        totalBanner.Parent = inventoryContainer
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = totalBanner

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 215, 0)
        stroke.Thickness = 1
        stroke.Parent = totalBanner
    end
    
    totalBanner.Text = "TOTAL CROPS: ≈ " .. formatPrice(grandTotalValue)
    totalBanner.Visible = true
end

local function hideAllPriceOverlays()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    for _, tag in ipairs(playerGui:GetDescendants()) do
        if tag.Name == "PriceTagOverlay" or tag.Name == "TotalValueBanner" then
            tag.Visible = false
        end
    end
end

task.spawn(function()
    while true do
        if fruitPriceEnabled then
            processInventorySlots()
            task.wait(1)
        else
            task.wait(0.5)
        end
    end
end)


-- // 7. PEMBUATAN PREMIUM GUI // --
local oldGui = CoreGui:FindFirstChild("PremiumControlGUI")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PremiumControlGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 180, 0, 325)
MainFrame.Position = UDim2.new(0, 20, 0.5, -162)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "CONTROL PANEL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Name = "FpsLabel"
FpsLabel.Size = UDim2.new(0.4, 0, 1, 0)
FpsLabel.Position = UDim2.new(0.4, 0, 0, 0)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "FPS: --"
FpsLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
FpsLabel.Font = Enum.Font.SourceSansBold
FpsLabel.TextSize = 12
FpsLabel.TextXAlignment = Enum.TextXAlignment.Right
FpsLabel.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(1, -28, 0, 2)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 16
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinimizeBtn

local Container = Instance.new("Frame")
Container.Name = "Container"
Container.Size = UDim2.new(1, 0, 1, -30)
Container.Position = UDim2.new(0, 0, 0, 30)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = Container

local PaddingOffset = Instance.new("Frame")
PaddingOffset.Size = UDim2.new(1, 0, 0, 2)
PaddingOffset.BackgroundTransparency = 1
PaddingOffset.LayoutOrder = 0
PaddingOffset.Parent = Container

local function createToggleButton(name, text, layoutOrder, onClick)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Size = UDim2.new(0, 160, 0, 34)
    Button.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
    Button.Text = text .. " [OFF]"
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.SourceSansBold
    Button.TextSize = 13
    Button.BorderSizePixel = 0
    Button.LayoutOrder = layoutOrder
    Button.Parent = Container

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 5)
    ButtonCorner.Parent = Button

    local state = false
    Button.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 140, 70)}):Play()
            Button.Text = text .. " [ON]"
        else
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(150, 45, 45)}):Play()
            Button.Text = text .. " [OFF]"
        end
        onClick(state)
    end)
end

-- // INISIALISASI TOMBOL // --
createToggleButton("InstantBtn", "Instant Interact", 1, function(status)
    instantEnabled = status
    refreshPrompts()
end)

createToggleButton("SpamBtn", "Auto Spam E", 2, function(status)
    spamEnabled = status
end)

createToggleButton("AutoDropBtn", "Auto Drop", 3, function(status)
    autoDropEnabled = status
end)

createToggleButton("AntiLagPlantsBtn", "Anti-Lag (Plants)", 4, function(status)
    antiLagPlantsEnabled = status
    processAllPlants()
end)

createToggleButton("ClearTexturesBtn", "Clear Map Textures", 5, function(status)
    texturesCleared = status
    toggleTexturesAndLighting(status)
end)

createToggleButton("FruitPriceBtn", "Fruit Price Overlay", 6, function(status)
    fruitPriceEnabled = status
    if status then
        processInventorySlots()
    else
        hideAllPriceOverlays()
    end
end)

-- // RUNNING CONTROLLER // --
local lastIteration = os.clock()
local frameHistory = {}
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local delta = now - lastIteration
    lastIteration = now
    table.insert(frameHistory, delta)
    while #frameHistory > 60 do table.remove(frameHistory, 1) end
    local totalDelta = 0
    for _, fDelta in ipairs(frameHistory) do totalDelta = totalDelta + fDelta end
    local fps = math.floor(#frameHistory / totalDelta)
    FpsLabel.Text = "FPS: " .. tostring(fps)
end)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        Container.Visible = false
        MainFrame:TweenSize(UDim2.new(0, 180, 0, 30), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        MinimizeBtn.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 180, 0, 325), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true, function()
            Container.Visible = true
        end)
        MinimizeBtn.Text = "-"
    end
end)

print("Premium Suite Final V13 (Internal Header Banner): Loaded Successfully.")
