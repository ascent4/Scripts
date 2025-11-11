-- Wapus ESP Standalone - Clean Settings Table
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

-- Recreate Wapus drawing library
local drawing = {}
drawing.Fonts = {UI = 0, System = 1, Plex = 2, Monospace = 3}

local cache = {updates = {}, instances = {}, shapes = {}}
local folder = Instance.new("ScreenGui")
folder.Name = "WapusESP"
folder.IgnoreGuiInset = true
folder.Parent = game:GetService("CoreGui")

local universal = {Visible = false, Transparency = 1, Color = Color3.new(0, 0, 0), ZIndex = 1}

local function destroyEntity(entity)
    if entity._data.drawings then
        for _, object in pairs(entity._data.drawings) do
            if object.Destroy then
                object:Destroy()
            end
        end
    end
end

local newMetatable = {
    __index = function(self, index)
        if index == "Remove" or index == "Destroy" then
            return destroyEntity
        end
        return self._data[index]
    end,
    __newindex = function(self, index, value)
        if self._data[index] ~= nil and self._data[index] ~= value then
            self._data[index] = value
            if not cache.updates[self._data.index] then 
                cache.updates[self._data.index] = {} 
            end
            cache.updates[self._data.index][index] = value
        end
    end
}

function drawing.new(shape)
    local entity = {}
    for ind, val in universal do entity[ind] = val end
    
    if shape == "Square" then
        entity.Position = Vector2.zero
        entity.Size = Vector2.zero
        entity.Thickness = 1
        entity.Filled = false
    elseif shape == "Text" then
        entity.Text = ""
        entity.Size = 14
        entity.Center = false
        entity.Outline = false
        entity.OutlineColor = Color3.new(0, 0, 0)
        entity.Position = Vector2.zero
        entity.Font = 0
    elseif shape == "Line" then
        entity.From = Vector2.zero
        entity.To = Vector2.zero
        entity.Thickness = 1
    end
    
    local data = {_data = entity}
    entity.drawings = {}
    entity.index = #cache.shapes + 1
    entity.shape = shape
    
    if shape == "Square" then
        local frames = {}
        for i = 1, 5 do
            local frame = Instance.new("Frame", folder)
            frame.Visible = false
            frame.BorderSizePixel = 0
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frames[i] = frame
        end
        entity.drawings = {box = frames[1], line1 = frames[2], line2 = frames[3], line3 = frames[4], line4 = frames[5]}
    elseif shape == "Text" then
        local label = Instance.new("TextLabel", folder)
        label.Text = ""
        label.TextColor3 = Color3.new(0, 0, 0)
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(0, 0, 0, 0)
        label.Font = Enum.Font.Ubuntu
        label.Visible = false
        entity.drawings = {label = label}
    elseif shape == "Line" then
        local line = Instance.new("Frame", folder)
        line.Visible = false
        line.BorderSizePixel = 0
        line.BackgroundColor3 = Color3.new(0, 0, 0)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        entity.drawings = {line = line}
    end
    
    cache.shapes[entity.index] = data
    table.insert(cache.instances, entity.drawings)
    return setmetatable(data, newMetatable)
end

-- Settings Table
local Settings = {
    ESP = {
        Enabled = true,
        Box = true,
        Name = true,
        Distance = true,
        Health = true,
        Weapon = false,
        Tracer = true,
        TeamCheck = true,
        ShowDead = false,
        MaxDistance = 1000,
        
        -- Colors
        BoxColor = Color3.new(1, 0, 0),
        NameColor = Color3.new(1, 1, 1),
        DistanceColor = Color3.new(1, 1, 1),
        TracerColor = Color3.new(1, 1, 1),
        FriendlyColor = Color3.new(0, 1, 0),
        
        -- Visual
        BoxThickness = 2,
        TracerThickness = 1,
        TextSize = 14,
        TextOutline = true,
        HealthColorBased = true
    },
    
    Aimbot = {
        Enabled = false,
        FOV = 300,
        Smoothness = 1,
        Hitbox = "Head", -- Head, Torso, Random
        VisibleCheck = false,
        TeamCheck = true,
        ShowFOV = true,
        FOVColor = Color3.new(1, 1, 1),
        FOVThickness = 1,
        FOVFilled = false
    },
    
    GunMods = {
        NoRecoil = false,
        NoSway = false,
        NoSpread = false,
        SmallCrosshair = false,
        NoCameraBob = false
    },
    
    Movement = {
        NoFallDamage = false
    },
    
    Visuals = {
        ThirdPerson = false,
        NoFlash = false,
        NoSmoke = false
    }
}

-- Player ESP storage
local playerESP = {}
local lastUpdate = 0

-- Get team color
local function getTeamColor(player)
    if Settings.ESP.TeamCheck and player.Team == localPlayer.Team then
        return Settings.ESP.FriendlyColor
    end
    return Settings.ESP.BoxColor
end

-- Get health color
local function getHealthColor(health)
    if not Settings.ESP.HealthColorBased then
        return Settings.ESP.NameColor
    end
    
    if health > 70 then
        return Color3.new(0, 1, 0)
    elseif health > 30 then
        return Color3.new(1, 1, 0)
    else
        return Color3.new(1, 0, 0)
    end
end

-- Create ESP for a player
local function createESP(player)
    if playerESP[player] then return end
    
    playerESP[player] = {
        Box = drawing.new("Square"),
        Name = drawing.new("Text"),
        Distance = drawing.new("Text"),
        Health = drawing.new("Text"),
        WeaponText = drawing.new("Text"),
        Tracer = drawing.new("Line")
    }
    
    -- Setup text properties
    for _, text in pairs({playerESP[player].Name, playerESP[player].Distance, playerESP[player].Health, playerESP[player].WeaponText}) do
        text.Outline = Settings.ESP.TextOutline
        text.OutlineColor = Color3.new(0, 0, 0)
        text.Size = Settings.ESP.TextSize
    end
    
    playerESP[player].Box.Filled = false
    playerESP[player].Box.Thickness = Settings.ESP.BoxThickness
    playerESP[player].Tracer.Thickness = Settings.ESP.TracerThickness
end

-- Remove ESP for a player
local function removeESP(player)
    if playerESP[player] then
        for _, drawingObj in pairs(playerESP[player]) do
            drawingObj:Remove()
        end
        playerESP[player] = nil
    end
end

-- Update all ESP elements
local function updateESP()
    if not Settings.ESP.Enabled then 
        for player, drawings in pairs(playerESP) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
        return 
    end
    
    local currentTime = tick()
    if currentTime - lastUpdate < 1/30 then return end
    lastUpdate = currentTime
    
    for player, drawings in pairs(playerESP) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local head = character and character:FindFirstChild("Head")
        
        local isTeammate = Settings.ESP.TeamCheck and player.Team == localPlayer.Team
        local isDead = not humanoid or humanoid.Health <= 0
        local shouldShow = character and head and (not isDead or Settings.ESP.ShowDead)
        
        if shouldShow then
            local headPos, onScreen = camera:WorldToViewportPoint(head.Position)
            local distance = (localPlayer.Character and localPlayer.Character:FindFirstChild("Head") and 
                            (head.Position - localPlayer.Character.Head.Position).Magnitude or 0)
            
            if onScreen and distance <= Settings.ESP.MaxDistance then
                -- Calculate box from character bounds
                local cf = character:GetBoundingBox()
                local size = cf.Size
                local pos = cf.Position
                
                local topLeft = camera:WorldToViewportPoint(pos + Vector3.new(-size.X/2, size.Y/2, 0))
                local bottomRight = camera:WorldToViewportPoint(pos + Vector3.new(size.X/2, -size.Y/2, 0))
                
                local boxSize = Vector2.new(bottomRight.X - topLeft.X, topLeft.Y - bottomRight.Y)
                local boxPos = Vector2.new(topLeft.X, bottomRight.Y)
                
                -- Team-based color
                local teamColor = getTeamColor(player)
                
                -- Box
                if Settings.ESP.Box then
                    drawings.Box.Position = boxPos
                    drawings.Box.Size = boxSize
                    drawings.Box.Color = teamColor
                    drawings.Box.Visible = true
                else
                    drawings.Box.Visible = false
                end
                
                -- Name
                if Settings.ESP.Name then
                    drawings.Name.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y - 15)
                    drawings.Name.Text = player.Name
                    drawings.Name.Color = Settings.ESP.NameColor
                    drawings.Name.Center = true
                    drawings.Name.Visible = true
                else
                    drawings.Name.Visible = false
                end
                
                -- Distance
                if Settings.ESP.Distance then
                    drawings.Distance.Position = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 2)
                    drawings.Distance.Text = string.format("[%dm]", math.floor(distance))
                    drawings.Distance.Color = Settings.ESP.DistanceColor
                    drawings.Distance.Center = true
                    drawings.Distance.Visible = true
                else
                    drawings.Distance.Visible = false
                end
                
                -- Health
                if Settings.ESP.Health and not isDead then
                    drawings.Health.Position = Vector2.new(boxPos.X - 25, boxPos.Y)
                    drawings.Health.Text = string.format("%dHP", humanoid.Health)
                    drawings.Health.Color = getHealthColor(humanoid.Health)
                    drawings.Health.Visible = true
                else
                    drawings.Health.Visible = false
                end
                
                -- Tracer
                if Settings.ESP.Tracer then
                    local tracerStart = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    drawings.Tracer.From = tracerStart
                    drawings.Tracer.To = Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y)
                    drawings.Tracer.Color = Settings.ESP.TracerColor
                    drawings.Tracer.Visible = true
                else
                    drawings.Tracer.Visible = false
                end
            else
                -- Out of range or off-screen
                for _, drawing in pairs(drawings) do
                    drawing.Visible = false
                end
            end
        else
            -- Dead or invalid character
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
    end
end

-- Initialize ESP for all players
for _, player in pairs(players:GetPlayers()) do
    if player ~= localPlayer then
        createESP(player)
    end
end

-- Player management
players.PlayerAdded:Connect(function(player)
    createESP(player)
end)

players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- Character management
local function onCharacterAdded(player, character)
    if character then
        character:WaitForChild("Humanoid")
        createESP(player)
    end
end

for _, player in pairs(players:GetPlayers()) do
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
end

-- Main update loop
runService.RenderStepped:Connect(updateESP)

-- Export settings table globally
getgenv().Settings = Settings

print("Wapus ESP loaded successfully!")
print("Control everything via the Settings table:")
print("")
print("-- ESP Settings:")
print("Settings.ESP.Enabled = true/false")
print("Settings.ESP.Box = true/false")
print("Settings.ESP.Name = true/false")
print("Settings.ESP.Distance = true/false")
print("Settings.ESP.Health = true/false")
print("Settings.ESP.Tracer = true/false")
print("Settings.ESP.TeamCheck = true/false")
print("")
print("-- Colors:")
print("Settings.ESP.BoxColor = Color3.new(1, 0, 0)")
print("Settings.ESP.NameColor = Color3.new(1, 1, 1)")
print("Settings.ESP.FriendlyColor = Color3.new(0, 1, 0)")
print("")
print("-- Aimbot:")
print("Settings.Aimbot.Enabled = true/false")
print("Settings.Aimbot.FOV = 300")
print("Settings.Aimbot.ShowFOV = true/false")
print("")
print("-- Gun Mods:")
print("Settings.GunMods.NoRecoil = true/false")
print("Settings.GunMods.NoSpread = true/false")
print("Settings.GunMods.SmallCrosshair = true/false")
