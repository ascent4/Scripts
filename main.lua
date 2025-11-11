-- Phantom Forces Wapus Features
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

-- Settings Table
local Settings = {
    SilentAim = {
        Enabled = true,
        FOV = 300,
        HitChance = 100,
        Hitbox = "Head", -- Head, Torso, Random
        VisibleCheck = false,
        ShowFOV = true,
        FOVColor = Color3.new(1, 1, 1),
        FOVThickness = 1,
        FOVFilled = false
    },
    GunMods = {
        NoRecoil = true,
        NoSway = true,
        NoSpread = true,
        SmallCrosshair = true,
        NoCameraBob = true
    },
    Movement = {
        NoFallDamage = true
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 1000,
        FontSize = 13,
        Drawing = {
            Names = {
                Enabled = true,
                Color = Color3.fromRGB(255, 255, 255),
            },
            Distance = {
                Enabled = true, 
                Color = Color3.fromRGB(255, 255, 255),
            },
            Weapons = {
                Enabled = true, 
                Color = Color3.fromRGB(255, 255, 255),
            },
            Healthbar = {
                Enabled = true,  
                Width = 3,
                Color = Color3.fromRGB(0, 255, 0),
            },
            Boxes = {
                Enabled = true,
                Color = Color3.fromRGB(255, 0, 0),
            }
        }
    }
}

-- Create FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Settings.SilentAim.FOVColor
FOVCircle.Radius = Settings.SilentAim.FOV
FOVCircle.NumSides = 48
FOVCircle.Visible = Settings.SilentAim.ShowFOV
FOVCircle.Thickness = Settings.SilentAim.FOVThickness
FOVCircle.Filled = Settings.SilentAim.FOVFilled
FOVCircle.Transparency = 1

-- Get modules
local function GetModules()
    for _, v in getgc(true) do
        if type(v) == "table" and rawget(v, "ScreenCull") and rawget(v, "NetworkClient") then
            local modules = {}
            for name, data in v do
                if data then modules[name] = data.module end
            end
            return modules
        end
    end
end

local Modules = GetModules()
local Network = Modules.NetworkClient
local ReplicationInterface = Modules.ReplicationInterface
local WeaponInterface = Modules.WeaponControllerInterface
local PublicSettings = Modules.PublicSettings
local BulletObject = Modules.BulletObject
local Recoil = Modules.RecoilSprings
local FirearmObject = Modules.FirearmObject
local CFrameLib = Modules.CFrameLib
local CameraObject = Modules.MainCameraObject
local ModifyData = Modules.ModifyData

-- Store originals
local Originals = {
    Send = Network.send,
    NewBullet = BulletObject.new,
    ApplyImpulse = Recoil.applyImpulse,
    ComputeGunSway = FirearmObject.computeGunSway,
    ComputeWalkSway = FirearmObject.computeWalkSway,
    FromAxisAngle = CFrameLib.fromAxisAngle,
    Step = CameraObject.step,
    GetModifiedData = ModifyData.getModifiedData
}

-- Simple ESP using Drawing API
local ESPDrawings = {}

local function CreateESP(Player)
    ESPDrawings[Player] = {
        Box = Drawing.new("Square"),
        BoxFill = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Weapon = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarBackground = Drawing.new("Square")
    }
    
    local drawings = ESPDrawings[Player]
    
    -- Box
    drawings.Box.Thickness = 2
    drawings.Box.Filled = false
    drawings.Box.Color = Settings.ESP.Drawing.Boxes.Color
    drawings.Box.Visible = false
    
    -- Box Fill
    drawings.BoxFill.Thickness = 1
    drawings.BoxFill.Filled = true
    drawings.BoxFill.Color = Color3.new(0, 0, 0)
    drawings.BoxFill.Transparency = 0.5
    drawings.BoxFill.Visible = false
    
    -- Name
    drawings.Name.Size = Settings.ESP.FontSize
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Color = Settings.ESP.Drawing.Names.Color
    drawings.Name.Visible = false
    
    -- Distance
    drawings.Distance.Size = Settings.ESP.FontSize
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.Color = Settings.ESP.Drawing.Distance.Color
    drawings.Distance.Visible = false
    
    -- Weapon
    drawings.Weapon.Size = Settings.ESP.FontSize
    drawings.Weapon.Center = true
    drawings.Weapon.Outline = true
    drawings.Weapon.Color = Settings.ESP.Drawing.Weapons.Color
    drawings.Weapon.Visible = false
    
    -- Health Bar
    drawings.HealthBar.Thickness = 1
    drawings.HealthBar.Filled = true
    drawings.HealthBar.Color = Settings.ESP.Drawing.Healthbar.Color
    drawings.HealthBar.Visible = false
    
    -- Health Bar Background
    drawings.HealthBarBackground.Thickness = 1
    drawings.HealthBarBackground.Filled = true
    drawings.HealthBarBackground.Color = Color3.new(0, 0, 0)
    drawings.HealthBarBackground.Visible = false
    
    return drawings
end

local function UpdateESP()
    if not Settings.ESP.Enabled then
        for _, drawings in pairs(ESPDrawings) do
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
        end
        return
    end
    
    for Player, drawings in pairs(ESPDrawings) do
        if not Player or Player == LocalPlayer then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local Character = Player.Character
        if not Character then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local Humanoid = Character:FindFirstChild("Humanoid")
        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        
        if not Humanoid or not HumanoidRootPart then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        -- Team check
        if Settings.ESP.TeamCheck and Player.Team == LocalPlayer.Team then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        local Position, OnScreen = Camera:WorldToViewportPoint(HumanoidRootPart.Position)
        local Distance = (Camera.CFrame.Position - HumanoidRootPart.Position).Magnitude
        
        if not OnScreen or Distance > Settings.ESP.MaxDistance then
            for _, drawing in pairs(drawings) do
                drawing.Visible = false
            end
            continue
        end
        
        -- Calculate box size based on distance
        local Scale = 1200 / Distance
        local Width = 4 * Scale
        local Height = 6 * Scale
        
        -- Box
        if Settings.ESP.Drawing.Boxes.Enabled then
            drawings.Box.Size = Vector2.new(Width, Height)
            drawings.Box.Position = Vector2.new(Position.X - Width/2, Position.Y - Height/2)
            drawings.Box.Visible = true
            
            drawings.BoxFill.Size = Vector2.new(Width, Height)
            drawings.BoxFill.Position = Vector2.new(Position.X - Width/2, Position.Y - Height/2)
            drawings.BoxFill.Visible = true
        else
            drawings.Box.Visible = false
            drawings.BoxFill.Visible = false
        end
        
        -- Health Bar
        if Settings.ESP.Drawing.Healthbar.Enabled then
            local HealthPercent = Humanoid.Health / Humanoid.MaxHealth
            local BarHeight = Height * HealthPercent
            
            drawings.HealthBarBackground.Size = Vector2.new(Settings.ESP.Drawing.Healthbar.Width + 2, Height + 2)
            drawings.HealthBarBackground.Position = Vector2.new(Position.X - Width/2 - Settings.ESP.Drawing.Healthbar.Width - 4, Position.Y - Height/2 - 1)
            drawings.HealthBarBackground.Visible = true
            
            drawings.HealthBar.Size = Vector2.new(Settings.ESP.Drawing.Healthbar.Width, BarHeight)
            drawings.HealthBar.Position = Vector2.new(Position.X - Width/2 - Settings.ESP.Drawing.Healthbar.Width - 3, Position.Y - Height/2 + (Height - BarHeight))
            drawings.HealthBar.Visible = true
        else
            drawings.HealthBar.Visible = false
            drawings.HealthBarBackground.Visible = false
        end
        
        -- Name
        if Settings.ESP.Drawing.Names.Enabled then
            drawings.Name.Text = Player.Name
            drawings.Name.Position = Vector2.new(Position.X, Position.Y - Height/2 - 20)
            drawings.Name.Visible = true
        else
            drawings.Name.Visible = false
        end
        
        -- Distance
        if Settings.ESP.Drawing.Distance.Enabled then
            drawings.Distance.Text = string.format("[%d]", math.floor(Distance))
            drawings.Distance.Position = Vector2.new(Position.X, Position.Y + Height/2 + 5)
            drawings.Distance.Visible = true
        else
            drawings.Distance.Visible = false
        end
        
        -- Weapon
        if Settings.ESP.Drawing.Weapons.Enabled then
            local Tool = Character:FindFirstChildOfClass("Tool")
            drawings.Weapon.Text = Tool and Tool.Name or "Fists"
            drawings.Weapon.Position = Vector2.new(Position.X, Position.Y + Height/2 + 20)
            drawings.Weapon.Visible = true
        else
            drawings.Weapon.Visible = false
        end
    end
end

-- Initialize ESP for all players
for _, Player in pairs(Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        ESPDrawings[Player] = CreateESP(Player)
    end
end

Players.PlayerAdded:Connect(function(Player)
    if Player ~= LocalPlayer then
        ESPDrawings[Player] = CreateESP(Player)
    end
end)

Players.PlayerRemoving:Connect(function(Player)
    if ESPDrawings[Player] then
        for _, drawing in pairs(ESPDrawings[Player]) do
            drawing:Remove()
        end
        ESPDrawings[Player] = nil
    end
end)

-- Update ESP every frame
RunService.RenderStepped:Connect(UpdateESP)

-- Silent Aim Functions
local function ComplexTrajectory(o, a, t, s, e)
    local ld = t - o
    a = -a
    e = e or Vector3.zero

    local function Solve(v44, v45, v46, v47, v48)
        if not v44 then return end
        if v44 > -1.0E-10 and v44 < 1.0E-10 then return Solve(v45, v46, v47, v48) end
        
        if v48 then
            local v49 = -v45 / (4 * v44)
            local v50 = (v46 + v49 * (3 * v45 + 6 * v44 * v49)) / v44
            local v51 = (v47 + v49 * (2 * v46 + v49 * (3 * v45 + 4 * v44 * v49))) / v44
            local v52 = (v48 + v49 * (v47 + v49 * (v46 + v49 * (v45 + v44 * v49)))) / v44
            
            if v51 > -1.0E-10 and v51 < 1.0E-10 then
                local v53, v54 = Solve(1, v50, v52)
                if not v54 or v54 < 0 then return end
                local v55, v56 = math.sqrt(v53), math.sqrt(v54)
                return v49 - v56, v49 - v55, v49 + v55, v49 + v56
            else
                local v57, _, v59 = Solve(1, 2 * v50, v50 * v50 - 4 * v52, -v51 * v51)
                local v60 = v59 or v57
                local v61 = math.sqrt(v60)
                local v62, v63 = Solve(1, v61, (v60 + v50 - v51 / v61) / 2)
                local v64, v65 = Solve(1, -v61, (v60 + v50 + v51 / v61) / 2)
                if v62 and v64 then return v49 + v62, v49 + v63, v49 + v64, v49 + v65
                elseif v62 then return v49 + v62, v49 + v63
                elseif v64 then return v49 + v64, v49 + v65 end
            end
        elseif v47 then
            local v66 = -v45 / (3 * v44)
            local v67 = -(v46 + v66 * (2 * v45 + 3 * v44 * v66)) / (3 * v44)
            local v68 = -(v47 + v66 * (v46 + v66 * (v45 + v44 * v66))) / (2 * v44)
            local v69 = v68 * v68 - v67 * v67 * v67
            local v70 = math.sqrt(math.abs(v69))
            
            if v69 > 0 then
                local v71 = v68 + v70
                local v72 = v68 - v70
                v71 = v71 < 0 and -(-v71)^0.3333333333333333 or v71^0.3333333333333333
                local v73 = v72 < 0 and -(-v72)^0.3333333333333333 or v72^0.3333333333333333
                return v66 + v71 + v73
            else
                local v74 = math.atan2(v70, v68) / 3
                local v75 = 2 * math.sqrt(v67)
                return v66 - v75 * math.sin(v74 + 0.5235987755982988), v66 + v75 * math.sin(v74 - 0.5235987755982988), v66 + v75 * math.cos(v74)
            end
        elseif v46 then
            local v76 = -v45 / (2 * v44)
            local v77 = v76 * v76 - v46 / v44
            if v77 < 0 then return end
            local v78 = math.sqrt(v77)
            return v76 - v78, v76 + v78
        elseif v45 then
            return -v45 / v44
        end
    end

    local r1, r2, r3, r4 = Solve(a:Dot(a) * 0.25, a:Dot(e), a:Dot(ld) + e:Dot(e) - s^2, ld:Dot(e) * 2, ld:Dot(ld))
    local x = (r1>0 and r1) or (r2>0 and r2) or (r3>0 and r3) or r4
    local v = (ld + e*x + 0.5*a*x^2) / x
    return v, x
end

local function GetHitboxPart()
    if Settings.SilentAim.Hitbox == "Head" then
        return "Head"
    elseif Settings.SilentAim.Hitbox == "Torso" then
        return "Torso"
    elseif Settings.SilentAim.Hitbox == "Random" then
        return math.random(1, 2) == 1 and "Head" or "Torso"
    end
    return "Head" -- Default fallback
end

local function GetClosestTarget(origin)
    local distance = Settings.SilentAim.FOV
    local position, closestPlayer, part

    ReplicationInterface.operateOnAllEntries(function(player, entry)
        local character = entry._thirdPersonObject and entry._thirdPersonObject._characterModelHash
        if character and player.Team ~= LocalPlayer.Team then
            local hitbox = GetHitboxPart()
            local targetPart = character[hitbox]
            
            if targetPart then
                local target = targetPart.Position
                local screenPosition = Camera:WorldToViewportPoint(target)
                local screenDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - origin).Magnitude

                if screenPosition.Z > 0 and screenDistance < distance then
                    part = targetPart
                    position = target
                    distance = screenDistance
                    closestPlayer = entry
                end
            end
        end
    end)

    return position, closestPlayer, part
end

-- Update FOV Circle
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Camera.ViewportSize * 0.5
    FOVCircle.Radius = Settings.SilentAim.FOV
    FOVCircle.Visible = Settings.SilentAim.ShowFOV
    FOVCircle.Color = Settings.SilentAim.FOVColor
    FOVCircle.Thickness = Settings.SilentAim.FOVThickness
    FOVCircle.Filled = Settings.SilentAim.FOVFilled
end)

-- Silent Aim Hooks
function Network.send(self, name, ...)
    if name == "falldamage" and Settings.Movement.NoFallDamage then
        return -- Block fall damage packets
    end
    
    if name == "newbullets" and Settings.SilentAim.Enabled then
        local uniqueId, bulletData, time = ...
        
        if Settings.SilentAim.HitChance >= math.random(1, 100) then
            local target = GetClosestTarget(Camera.ViewportSize * 0.5)

            if target then
                local weapon = WeaponInterface.getActiveWeaponController():getActiveWeapon()
                local velocity = ComplexTrajectory(bulletData.firepos, PublicSettings.bulletAcceleration, target, weapon._weaponData.bulletspeed, Vector3.zero).Unit
                
                for _, bullet in bulletData.bullets do
                    bullet[1] = velocity
                end
            end
        end
    end
    
    return Originals.Send(self, name, ...)
end

function BulletObject.new(bulletData)
    if bulletData.onplayerhit and Settings.SilentAim.Enabled then
        if Settings.SilentAim.HitChance >= math.random(1, 100) then
            local target = GetClosestTarget(Camera.ViewportSize * 0.5)

            if target then
                local velocity = ComplexTrajectory(bulletData.position, bulletData.acceleration, target, bulletData.velocity.Magnitude, Vector3.zero)
                bulletData.velocity = velocity
            end
        end
    end
    
    return Originals.NewBullet(bulletData)
end

-- Gun Mods Hooks
function Recoil.applyImpulse(...)
    if Settings.GunMods.NoRecoil then return end
    return Originals.ApplyImpulse(...)
end

function FirearmObject.computeGunSway(...)
    if Settings.GunMods.NoSway then return CFrame.identity end
    return Originals.ComputeGunSway(...)
end

function FirearmObject.computeWalkSway(self, dy, dx)
    if Settings.GunMods.NoSway then return Originals.ComputeWalkSway(self, 0, 0) end
    return Originals.ComputeWalkSway(self, dy, dx)
end

function CFrameLib.fromAxisAngle(x, y, z)
    if Settings.GunMods.NoSway then
        local controller = WeaponInterface.getActiveWeaponController()
        local weapon = controller and controller:getActiveWeapon()
        if weapon and not weapon._aiming then return CFrame.identity end
    end
    return Originals.FromAxisAngle(x, y, z)
end

function CameraObject.step(self, dt)
    if Settings.GunMods.NoCameraBob then
        Originals.Step(self, 0)
        self._lookDt = dt
        return
    end
    return Originals.Step(self, dt)
end

function ModifyData.getModifiedData(data, ...)
    setreadonly(data, false)
    
    if Settings.GunMods.NoSpread then
        data.hipfirespread = 0
        data.hipfirestability = 99999
        data.hipfirespreadrecover = 99999
        data.aimspread = 0
        data.aimstability = 99999
    end
    
    if Settings.GunMods.SmallCrosshair then
        data.crosssize = 10
        data.crossexpansion = 0
        data.crossspeed = 100
        data.crossdamper = 1
    end
    
    setreadonly(data, true)
    return Originals.GetModifiedData(data, ...)
end