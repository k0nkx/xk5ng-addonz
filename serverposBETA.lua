local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Settings = {
    VisualizerColor = Color3.fromRGB(255, 255, 255),
    Transparency = 0.5,
    MaxPing = 300,
    HistoryDuration = 2,
    HighPingThreshold = 160,
    HighPingReduction = 0.9,
    Material = Enum.Material.ForceField,
    CanCollide = false,
    Anchored = true,
    Enabled = true,
    UpdateInterval = 0,
    VisualizeHead = false,
    VisualizeHRP = false,
    DecalHead = false,
    ToggleKey = Enum.KeyCode.End,
    UseServerIndicatorGUI = true,
    FollowVisualClone = true
}

if _G.ServerPosVisualizer then
    _G.ServerPosVisualizer:Disconnect()
    _G.ServerPosVisualizer = nil
end

if _G.VisualizerInputConnection then
    _G.VisualizerInputConnection:Disconnect()
    _G.VisualizerInputConnection = nil
end

if _G.VisualizerParts then
    for _, part in pairs(_G.VisualizerParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    _G.VisualizerParts = {}
end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

_G.VisualizerParts = _G.VisualizerParts or {}
local positionHistory = {}
local ServerIndicatorGUI = nil
local OriginalGUIParent = nil
local OriginalGUIText = nil

local function setupServerIndicatorGUI()
    if not Settings.UseServerIndicatorGUI then
        return
    end
    
    local CoreGui = game:GetService("CoreGui")
    
    if CoreGui:FindFirstChild("ServerIndicator") then
        local serverIndicator = CoreGui.ServerIndicator
        if serverIndicator:FindFirstChild("ServerIndicator") then
            ServerIndicatorGUI = serverIndicator.ServerIndicator
            
            if ServerIndicatorGUI:IsA("GuiBase2d") then
                OriginalGUIParent = ServerIndicatorGUI.Parent
            end
            
            if ServerIndicatorGUI:IsA("TextLabel") or ServerIndicatorGUI:IsA("TextButton") then
                OriginalGUIText = ServerIndicatorGUI.Text
            elseif ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel") then
                local textLabel = ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel")
                OriginalGUIText = textLabel.Text
            end
        end
    end
    
    if not ServerIndicatorGUI then
        task.wait(1)
        if CoreGui:FindFirstChild("ServerIndicator") then
            local serverIndicator = CoreGui.ServerIndicator
            if serverIndicator:FindFirstChild("ServerIndicator") then
                ServerIndicatorGUI = serverIndicator.ServerIndicator
                
                if ServerIndicatorGUI:IsA("GuiBase2d") then
                    OriginalGUIParent = ServerIndicatorGUI.Parent
                end
            end
        end
    end
    
    return ServerIndicatorGUI ~= nil
end

local function getVisualCloneToFollow()
    if Settings.VisualizeHRP and _G.VisualizerParts["HumanoidRootPart"] and _G.VisualizerParts["HumanoidRootPart"].Parent then
        return _G.VisualizerParts["HumanoidRootPart"]
    end
    
    if _G.VisualizerParts["UpperTorso"] and _G.VisualizerParts["UpperTorso"].Parent then
        return _G.VisualizerParts["UpperTorso"]
    end
    
    if _G.VisualizerParts["Torso"] and _G.VisualizerParts["Torso"].Parent then
        return _G.VisualizerParts["Torso"]
    end
    
    if _G.VisualizerParts["LowerTorso"] and _G.VisualizerParts["LowerTorso"].Parent then
        return _G.VisualizerParts["LowerTorso"]
    end
    
    if Settings.VisualizeHead and _G.VisualizerParts["Head"] and _G.VisualizerParts["Head"].Parent then
        return _G.VisualizerParts["Head"]
    end
    
    for partName, visualPart in pairs(_G.VisualizerParts) do
        if visualPart and visualPart.Parent then
            return visualPart
        end
    end
    
    return nil
end

local function updateServerIndicatorGUI()
    if not Settings.UseServerIndicatorGUI or not Settings.Enabled or not Settings.FollowVisualClone then
        return
    end
    
    if not ServerIndicatorGUI or not ServerIndicatorGUI:IsA("GuiBase2d") then
        return
    end
    
    local visualPartToFollow = getVisualCloneToFollow()
    if not visualPartToFollow then
        if ServerIndicatorGUI.Parent then
            ServerIndicatorGUI.Visible = false
        end
        return
    end
    
    local camera = workspace.CurrentCamera
    if camera then
        local screenPoint = camera:WorldToScreenPoint(visualPartToFollow.Position)
        local viewportSize = camera.ViewportSize
        
        if screenPoint.Z > 0 then
            ServerIndicatorGUI.Position = UDim2.new(
                screenPoint.X / viewportSize.X,
                0,
                screenPoint.Y / viewportSize.Y,
                0
            )
            ServerIndicatorGUI.Visible = true
            
            local ping = getPing()
            if ServerIndicatorGUI:IsA("TextLabel") or ServerIndicatorGUI:IsA("TextButton") then
                ServerIndicatorGUI.Text = string.format("Server Clone\nPing: %dms", math.floor(ping))
            elseif ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel") then
                local textLabel = ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel")
                textLabel.Text = string.format("Server Clone\nPing: %dms", math.floor(ping))
            end
        else
            ServerIndicatorGUI.Visible = false
        end
    end
end

local function restoreServerIndicatorGUI()
    if ServerIndicatorGUI and ServerIndicatorGUI:IsA("GuiBase2d") then
        if OriginalGUIParent and ServerIndicatorGUI.Parent ~= OriginalGUIParent then
            ServerIndicatorGUI.Parent = OriginalGUIParent
        end
        
        ServerIndicatorGUI.Visible = true
        
        if OriginalGUIText then
            if ServerIndicatorGUI:IsA("TextLabel") or ServerIndicatorGUI:IsA("TextButton") then
                ServerIndicatorGUI.Text = OriginalGUIText
            elseif ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel") then
                local textLabel = ServerIndicatorGUI:FindFirstChildWhichIsA("TextLabel")
                textLabel.Text = OriginalGUIText
            end
        end
    end
end

local function getPing()
    if not Settings.Enabled then return 0 end
    
    local networkPing = player:GetNetworkPing() * 1000
    
    local dataPing = 0
    local item = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
    if item then
        local ok, v = pcall(function()
            return item:GetValueString()
        end)
        if ok and v then
            dataPing = tonumber(v:match("%d+")) or 0
        end
    end
    
    local totalPing = networkPing + dataPing
    
    if totalPing > Settings.HighPingThreshold then
        networkPing = networkPing * Settings.HighPingReduction
        totalPing = networkPing + dataPing
    end
    
    return math.min(totalPing, Settings.MaxPing)
end

local function cloneBodyParts()
    if not Settings.Enabled then return end
    
    for partName, part in pairs(_G.VisualizerParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    _G.VisualizerParts = {}
    
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            if part.Name == "Head" and not Settings.VisualizeHead then
                continue
            end
            
            if part.Name == "HumanoidRootPart" and not Settings.VisualizeHRP then
                continue
            end
            
            local existingPart = workspace:FindFirstChild("Visualizer_" .. part.Name)
            if existingPart then
                existingPart:Destroy()
            end
            
            local clone = part:Clone()
            clone.Name = "Visualizer_" .. part.Name
            clone.Parent = workspace
            
            clone.Material = Settings.Material
            clone.BrickColor = BrickColor.new(Settings.VisualizerColor)
            clone.Transparency = Settings.Transparency
            clone.CanCollide = false
            clone.Anchored = true
            clone.CastShadow = false
            
            for _, child in pairs(clone:GetChildren()) do
                if child:IsA("Attachment") or child:IsA("Weld") or child:IsA("Motor6D") or child:IsA("BodyForce") or child:IsA("BodyVelocity") or child:IsA("BodyGyro") or child:IsA("BodyThrust") or child:IsA("RocketPropulsion") or child:IsA("VectorForce") then
                    child:Destroy()
                end
            end
            
            if part.Name == "Head" and not Settings.DecalHead then
                for _, child in pairs(clone:GetChildren()) do
                    if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SpecialMesh") then
                        child:Destroy()
                    end
                end
            end
            
            if clone:FindFirstChildOfClass("Script") then
                clone:FindFirstChildOfClass("Script"):Destroy()
            end
            
            if clone:FindFirstChildOfClass("LocalScript") then
                clone:FindFirstChildOfClass("LocalScript"):Destroy()
            end
            
            _G.VisualizerParts[part.Name] = clone
        end
    end
end

local function updateVisualizer()
    if not Settings.Enabled then return end
    
    local ping = getPing()
    
    local currentTime = tick()
    positionHistory[currentTime] = {}
    
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            if part.Name == "Head" and not Settings.VisualizeHead then
                continue
            end
            
            if part.Name == "HumanoidRootPart" and not Settings.VisualizeHRP then
                continue
            end
            
            positionHistory[currentTime][part.Name] = {
                Position = part.Position,
                Rotation = part.Rotation
            }
        end
    end
    
    for time in pairs(positionHistory) do
        if currentTime - time > Settings.HistoryDuration then
            positionHistory[time] = nil
        end
    end
    
    local backtrackTime = currentTime - (ping / 1000)
    
    local targetPositions = {}
    local closestTime = nil
    local smallestDiff = math.huge
    
    for time, positions in pairs(positionHistory) do
        local diff = math.abs(time - backtrackTime)
        if diff < smallestDiff then
            smallestDiff = diff
            closestTime = time
            targetPositions = positions
        end
    end
    
    for partName, visualPart in pairs(_G.VisualizerParts) do
        if visualPart and visualPart.Parent and targetPositions[partName] then
            local targetData = targetPositions[partName]
            visualPart.Position = targetData.Position
            visualPart.Rotation = targetData.Rotation
        end
    end
    
    if Settings.UseServerIndicatorGUI and Settings.FollowVisualClone then
        updateServerIndicatorGUI()
    end
end

local function destroyVisualizerParts()
    for partName, part in pairs(_G.VisualizerParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    _G.VisualizerParts = {}
    
    if Settings.UseServerIndicatorGUI then
        restoreServerIndicatorGUI()
    end
end

local function toggleVisualizer(state)
    Settings.Enabled = state
    if not state then
        destroyVisualizerParts()
        if Settings.UseServerIndicatorGUI then
            restoreServerIndicatorGUI()
        end
    else
        cloneBodyParts()
        if Settings.UseServerIndicatorGUI and not ServerIndicatorGUI then
            setupServerIndicatorGUI()
        end
    end
end

local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        toggleVisualizer(Settings.Enabled)
    end
end

cloneBodyParts()
setupServerIndicatorGUI()

local characterConnection
characterConnection = player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    task.wait(1)
    if Settings.Enabled then
        cloneBodyParts()
    end
    positionHistory = {}
    
    if Settings.UseServerIndicatorGUI then
        setupServerIndicatorGUI()
    end
end)

_G.ServerPosVisualizer = RunService.Heartbeat:Connect(updateVisualizer)

_G.VisualizerInputConnection = UserInputService.InputBegan:Connect(onInputBegan)

local characterRemovingConnection
characterRemovingConnection = player.CharacterRemoving:Connect(function()
    destroyVisualizerParts()
end)

_G.GUIFollowConnection = RunService.RenderStepped:Connect(function()
    if Settings.Enabled and Settings.UseServerIndicatorGUI and Settings.FollowVisualClone then
        updateServerIndicatorGUI()
    end
end)

return {
    Settings = Settings,
    toggleVisualizer = toggleVisualizer,
    destroyVisualizer = destroyVisualizerParts,
    refreshVisualizer = cloneBodyParts,
    setupServerIndicatorGUI = setupServerIndicatorGUI,
    ServerIndicatorGUI = ServerIndicatorGUI
}
