if not game:IsLoaded() then game.Loaded:Wait() end

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local JobApplication = LocalGui:WaitForChild("JobApplication")
local JobApplicationFrame = JobApplication:WaitForChild("JobApplicationFrame")
local JobApplicationLabel = JobApplicationFrame:WaitForChild("JobApplicationLabel")
local ApplyJobButton = JobApplicationFrame:WaitForChild("ApplyJob")

local StockerPartPos = Vector3.new(165.861084, 253.884644, 203.044189)
local Map = Workspace:WaitForChild("Map")
local Tiles = Map:WaitForChild("Tiles")
local GasStationTile = Tiles:WaitForChild("GasStationTile")
local Quick11 = GasStationTile:WaitForChild("Quick11")
local ShelfStockingJob = Quick11:WaitForChild("Interior"):WaitForChild("ShelfStockingJob")
local NormalBox = ShelfStockingJob:WaitForChild("NormalBox")
local Shelves = ShelfStockingJob:WaitForChild("Shelves")
local PickBoxProximityPrompt = NormalBox:WaitForChild("ProximityPrompt")
local LastTargetShelf = nil
local IsMoving = false
local ProgressBarFrame = LocalGui:WaitForChild("ProgressBar")
    :WaitForChild("ProgressBarFrame")
    :WaitForChild("MainFrame")
    :WaitForChild("BarAmount")

local LastSize = nil
local SizeCheckTime = 0

local PathfindingParams = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = false,
    AgentCanClimb = false
}

local function DestroyDoor()
    for _, Obj in ipairs(Workspace:GetDescendants()) do
        if Obj.Name == "DoorSystem" then
            Obj:Destroy()
        end
    end
end

DestroyDoor()

local StockerConnection

local function MoveToPosition(RootPart, TargetPos)
    if IsMoving then return end
    IsMoving = true

    local Path = PathfindingService:CreatePath(PathfindingParams)
    local Success, ErrorMessage = pcall(function()
        Path:ComputeAsync(RootPart.Position, TargetPos)
    end)

    if not Success or Path.Status ~= Enum.PathStatus.Success then
        warn("Path calculation failed:", ErrorMessage or "Unknown error")
        IsMoving = false
        return false
    end

    local Waypoints = Path:GetWaypoints()
    for _, Waypoint in ipairs(Waypoints) do
        local Distance = (Waypoint.Position - RootPart.Position).Magnitude
        local TweenTime = math.min(Distance / 200, 1.5)

        local Tween = TweenService:Create(
            RootPart,
            TweenInfo.new(TweenTime, Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(Waypoint.Position + Vector3.new(0, 3, 0))}
        )

        local TweenComplete = false
        Tween:Play()

        local TweenConn = Tween.Completed:Connect(function()
            TweenComplete = true
        end)

        while not TweenComplete and _G.AutoStocker do
            task.wait()
        end

        TweenConn:Disconnect()

        if not _G.AutoStocker then
            Tween:Cancel()
            IsMoving = false
            return false
        end
    end

    IsMoving = false
    return true
end

local function GetTargetShelf()
    for _, Shelf in pairs(Shelves:GetChildren()) do
        if Shelf:FindFirstChild("Attachment") then
            return Shelf
        end
    end
    return nil
end

task.spawn(function()
    if StockerConnection then StockerConnection:Disconnect() end

    StockerConnection = RunService.Heartbeat:Connect(function()
        if not _G.AutoStocker then return end

        local Character = LocalPlayer.Character
        if not Character then return end

        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        if not RootPart then return end

        local Humanoid = Character:FindFirstChild("Humanoid")
        if not Humanoid then return end

        if LocalPlayer:GetAttribute("Job") == nil or LocalPlayer:GetAttribute("Job") ~= "shelf_stocker" then
            if JobApplicationFrame.Visible and string.find(JobApplicationLabel.Text, "Stocker") then
                firesignal(ApplyJobButton.MouseButton1Click)
            end
            
            if IsMoving then return end
            MoveToPosition(RootPart, StockerPartPos)
        else
            local BoxTool = Character:FindFirstChild("BoxTool")
            local BackpackTool = LocalPlayer.Backpack:FindFirstChild("BoxTool")
            
            if BoxTool then
                local TargetShelf = GetTargetShelf()
                if TargetShelf and TargetShelf:IsA("BasePart") then
                    LastTargetShelf = TargetShelf
                end
                if LastTargetShelf and not IsMoving then
                    MoveToPosition(RootPart, LastTargetShelf.Position)

                    local DistToShelf = (RootPart.Position - LastTargetShelf.Position).Magnitude
                    if DistToShelf < 5 then
                        if not LastSize then
                            LastSize = ProgressBarFrame.Size
                            SizeCheckTime = tick()
                        elseif tick() - SizeCheckTime > 1 then
                            if ProgressBarFrame.Size == LastSize then
                                Humanoid:UnequipTools()
                            end
                            LastSize = ProgressBarFrame.Size
                            SizeCheckTime = tick()
                        end
                    end

                    if LastTargetShelf:FindFirstChild("TouchInterest") then
                        firetouchinterest(LastTargetShelf, RootPart, 0)
                    end
                end
            elseif BackpackTool then
                Humanoid:EquipTool(BackpackTool)
            else
                if IsMoving then return end
                MoveToPosition(RootPart, NormalBox.Position)
                fireproximityprompt(PickBoxProximityPrompt)
            end
        end
    end)
end)
