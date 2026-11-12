-- ======================================================
-- SCRIPT: Respect Arena Aimbot + Auto Prompt Invisível
-- ======================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local RobloxMenuOpen = false
pcall(function()
    GuiService.MenuOpened:Connect(function() RobloxMenuOpen = true end)
    GuiService.MenuClosed:Connect(function()
        RobloxMenuOpen = false
        task.wait(0.15)
        if Config.CameraForce then
            pcall(function()
                local c = LocalPlayer.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then 
                        local yOffset = Config.RaiseCamera and Config.CameraRaiseOffset or 0
                        h.CameraOffset = Vector3.new(Config.CameraOffsetRight, yOffset, 0) 
                    end
                end
            end)
        end
    end)
end)

local Config = {
    Enabled=false, AimPart="Neck", FOV=25, FOV_Sticky=45, MaxDistance=100,
    Smoothness=0.15, Prediction=0.08, Locked=false, IgnoreTeam=true,
    IgnoreWalls=false, ShowHealth=false, CameraForce=false, CameraOffsetRight=2.5,
    LockScreenEnabled=false, LockScreenFixed=false, AutoPromptEnabled=false,
    AutoPromptFixed=false, LockBtnX=0.15, LockBtnY=0.4, PromptBtnX=0.7,
    PromptBtnY=0.6, HeadDelay=1.5, ESPAllPlayers=false, ShowFriendMarker=true,
    ShowKillCounter=true, HealthBarHeight=10.8, CameraDistance=80,
    CameraLocked=false, RaiseCamera=false, 
    CameraRaiseOffset=3.5, -- ✅ NOVO: Guarda a altura da câmera
}

local isAimingHead=false
local lastInputPosition=nil
local headshotTimer=0
local MyTeamIDs={}
local BlockedPlayers={}
local LastCacheUpdate=0

local FriendCache={}
local FriendCacheTime=0
local FRIEND_CACHE_TTL=30

local function IsRobloxFriend(tp)
    if tick()-FriendCacheTime>FRIEND_CACHE_TTL then
        FriendCache={}
        FriendCacheTime=tick()
    end
    if FriendCache[tp.UserId]~=nil then return FriendCache[tp.UserId] end
    local ok,f=pcall(function() return LocalPlayer:IsFriendsWith(tp.UserId) end)
    FriendCache[tp.UserId]=(ok and f) or false
    return FriendCache[tp.UserId]
end

local function SaveConfig()
    pcall(function() writefile("RespectAimbot_Config.json", HttpService:JSONEncode(Config)) end)
    pcall(function() for k,v in pairs(Config) do LocalPlayer:SetAttribute("Aimbot_"..k,v) end end)
end

local function LoadConfig()
    if isfile and isfile("RespectAimbot_Config.json") then
        local ok,data=pcall(function() return HttpService:JSONDecode(readfile("RespectAimbot_Config.json")) end)
        if ok and data then
            for k,v in pairs(data) do if Config[k]~=nil then Config[k]=v end end
            Config.HealthBarHeight = 10.8
            return
        end
    end
    for k,_ in pairs(Config) do
        local v=LocalPlayer:GetAttribute("Aimbot_"..k)
        if v~=nil then Config[k]=v end
    end
    Config.HealthBarHeight = 10.8
end
LoadConfig()

local function GetGuiParent()
    if gethui then
        local ok,hui=pcall(gethui)
        if ok and hui then return hui end
    end
    local ok,cg=pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="RespectArenaAimbot"
ScreenGui.ResetOnSpawn=false
ScreenGui.IgnoreGuiInset=true
ScreenGui.DisplayOrder=999
ScreenGui.Parent=GetGuiParent()

local FovCircle=Instance.new("Frame")
FovCircle.BackgroundTransparency=1
FovCircle.BorderSizePixel=0
FovCircle.Visible=Config.Enabled
FovCircle.ZIndex=999
FovCircle.Parent=ScreenGui
local FC=Instance.new("UICorner") FC.CornerRadius=UDim.new(1,0) FC.Parent=FovCircle
local FS=Instance.new("UIStroke") FS.Thickness=2 FS.Color=Color3.fromRGB(255,0,0) FS.Parent=FovCircle

local StickyCircle=Instance.new("Frame")
StickyCircle.BackgroundTransparency=1
StickyCircle.BorderSizePixel=0
StickyCircle.Visible=Config.Enabled
StickyCircle.ZIndex=998
StickyCircle.Parent=ScreenGui
local SC=Instance.new("UICorner") SC.CornerRadius=UDim.new(1,0) SC.Parent=StickyCircle
local SS=Instance.new("UIStroke") SS.Thickness=1.5 SS.Color=Color3.fromRGB(135,206,235) SS.Transparency=0.5 SS.Parent=StickyCircle

local function UpdateFovVisuals()
    FovCircle.Size=UDim2.new(0,Config.FOV*2,0,Config.FOV*2)
    FovCircle.Position=UDim2.new(0.5,-Config.FOV,0.5,-Config.FOV)
    StickyCircle.Size=UDim2.new(0,Config.FOV_Sticky*2,0,Config.FOV_Sticky*2)
    StickyCircle.Position=UDim2.new(0.5,-Config.FOV_Sticky,0.5,-Config.FOV_Sticky)
end
UpdateFovVisuals()

local MainFrame=Instance.new("Frame")
MainFrame.Size=UDim2.new(0,235,0,340)
MainFrame.Position=UDim2.new(0.5,-117,0.5,-170)
MainFrame.BackgroundColor3=Color3.fromRGB(25,25,25)
MainFrame.BorderSizePixel=0
MainFrame.Active=true
MainFrame.Parent=ScreenGui

local Title=Instance.new("TextLabel")
Title.Size=UDim2.new(1,0,0,30)
Title.BackgroundColor3=Color3.fromRGB(40,40,40)
Title.Text="  Respect Arena Aimbot"
Title.TextColor3=Color3.fromRGB(255,255,255)
Title.TextXAlignment=Enum.TextXAlignment.Left
Title.Font=Enum.Font.SourceSansBold
Title.TextSize=16
Title.Active=true
Title.Parent=MainFrame

local MinimizeBtn=Instance.new("TextButton")
MinimizeBtn.Size=UDim2.new(0,30,0,30)
MinimizeBtn.Position=UDim2.new(1,-30,0,0)
MinimizeBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
MinimizeBtn.Text="-"
MinimizeBtn.TextColor3=Color3.fromRGB(255,255,255)
MinimizeBtn.Font=Enum.Font.SourceSansBold
MinimizeBtn.TextSize=20
MinimizeBtn.Parent=Title

local ContentScroll=Instance.new("ScrollingFrame")
ContentScroll.Size=UDim2.new(1,0,1,-30)
ContentScroll.Position=UDim2.new(0,0,0,30)
ContentScroll.BackgroundTransparency=1
ContentScroll.BorderSizePixel=0
ContentScroll.ScrollBarThickness=6
ContentScroll.CanvasSize=UDim2.new(0,0,0,1000) -- Aumentado para caber o novo TextBox
ContentScroll.Parent=MainFrame

local AimToggle=Instance.new("TextButton")
AimToggle.Size=UDim2.new(0,200,0,35)
AimToggle.Position=UDim2.new(0.5,-100,0,10)
AimToggle.BackgroundColor3=Color3.fromRGB(200,50,50)
AimToggle.Text="AIM: OFF"
AimToggle.TextColor3=Color3.fromRGB(255,255,255)
AimToggle.Font=Enum.Font.SourceSansBold
AimToggle.Parent=ContentScroll

local function MakeLabel(text,y,w)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.new(0,w or 115,0,30)
    l.Position=UDim2.new(0,10,0,y)
    l.BackgroundTransparency=1
    l.Text=text
    l.TextColor3=Color3.fromRGB(200,200,200)
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Font=Enum.Font.SourceSans
    l.TextSize=12
    l.Parent=ContentScroll
    return l
end

local function MakeBox(y,val)
    local b=Instance.new("TextBox")
    b.Size=UDim2.new(0,75,0,30)
    b.Position=UDim2.new(1,-85,0,y)
    b.BackgroundColor3=Color3.fromRGB(50,50,50)
    b.Text=tostring(val)
    b.TextColor3=Color3.fromRGB(255,255,255)
    b.Font=Enum.Font.SourceSansBold
    b.TextSize=14
    b.Parent=ContentScroll
    return b
end

MakeLabel("FOV Trava:",55) local FovBox=MakeBox(55,Config.FOV)
MakeLabel("FOV Deslize:",95) local StickyBox=MakeBox(95,Config.FOV_Sticky)
MakeLabel("Dist. Metros:",135) local MaxDistBox=MakeBox(135,Config.MaxDistance)
MakeLabel("Suavidade:",175) local SmoothBox=MakeBox(175,Config.Smoothness)
MakeLabel("Delay Head:",215) local DelayBox=MakeBox(215,Config.HeadDelay)

local function MakeBtn(text,y,color)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,200,0,30)
    b.Position=UDim2.new(0.5,-100,0,y)
    b.BackgroundColor3=color or Color3.fromRGB(50,50,50)
    b.Text=text
    b.TextColor3=Color3.fromRGB(255,255,255)
    b.Font=Enum.Font.SourceSansBold
    b.TextSize=12
    b.Parent=ContentScroll
    return b
end

local PartBtn=MakeBtn("PARTE: "..Config.AimPart,255)
local TeamBtn=MakeBtn("IGNORAR AMIGOS/EQUIPE: "..(Config.IgnoreTeam and "ON" or "OFF"),295,Config.IgnoreTeam and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50))
local WallBtn=MakeBtn("NÃO ATRAVESSAR PAREDES: "..(Config.IgnoreWalls and "ON" or "OFF"),335,Config.IgnoreWalls and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50))
local HealthBtn=MakeBtn("MOSTRAR VIDA: "..(Config.ShowHealth and "ON" or "OFF"),375,Config.ShowHealth and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50))
local FriendListBtn=MakeBtn("LISTA DE AMIGOS/INIMIGOS",415,Color3.fromRGB(150,50,200))
local CameraBtn=MakeBtn("SAIR DA 1ª PESSOA: OFF",455)
local RaiseCamBtn=MakeBtn("LEVANTAR CÂMERA: OFF",495,Color3.fromRGB(200,50,50))

-- ✅ NOVO TEXTBOX PARA ALTURA DA CÂMERA
MakeLabel("Subir Câmera:",535) local RaiseAmountBox=MakeBox(535,Config.CameraRaiseOffset)

MakeLabel("Dist. Direita:",575) local OffsetBox=MakeBox(575,Config.CameraOffsetRight)
MakeLabel("Câmera ↑perto:", 615, 130) local CameraDistBox=MakeBox(615, Config.CameraDistance)
local CameraLockBtn=MakeBtn("TRAVAR CÂMERA: OFF", 655, Color3.fromRGB(200,50,50))
local ScreenLockMenuBtn=MakeBtn("CADEADO TELA: OFF",695)
local ScreenLockFixedBtn=MakeBtn("TRAVAR CADEADO TELA: OFF",735)
local AutoPromptMenuBtn=MakeBtn("AUTO PROMPT: OFF",775)
local AutoPromptFixedBtn=MakeBtn("TRAVAR AUTO PROMPT: OFF",815)
local ESPAllBtn=MakeBtn("ESP EM TODOS: OFF",855,Color3.fromRGB(200,50,50))
local FriendMarkerBtn=MakeBtn("LETRA A AMIGO: ON",895,Color3.fromRGB(50,200,50))
local KillCounterBtn=MakeBtn("CONTADOR MORTES: ON",935,Color3.fromRGB(50,200,50))

-- ======================================================
-- CADEADO FLUTUANTE
-- ======================================================
local ScreenLockBtn=Instance.new("TextButton")
ScreenLockBtn.Size=UDim2.new(0,45,0,45)
ScreenLockBtn.BackgroundColor3=Color3.fromRGB(40,40,40)
ScreenLockBtn.BackgroundTransparency=0.3
ScreenLockBtn.Text="🔓"
ScreenLockBtn.TextColor3=Color3.fromRGB(255,255,255)
ScreenLockBtn.TextSize=22
ScreenLockBtn.Font=Enum.Font.SourceSansBold
ScreenLockBtn.Visible=Config.LockScreenEnabled
ScreenLockBtn.Position=UDim2.new(Config.LockBtnX,0,Config.LockBtnY,0)
ScreenLockBtn.Parent=ScreenGui
local LC=Instance.new("UICorner") LC.CornerRadius=UDim.new(1,0) LC.Parent=ScreenLockBtn
local LS=Instance.new("UIStroke") LS.Thickness=2 LS.Color=Color3.fromRGB(0,162,255) LS.Parent=ScreenLockBtn

local isScreenLocked=false
ScreenLockBtn.MouseButton1Click:Connect(function()
    isScreenLocked=not isScreenLocked
    if isScreenLocked then
        ScreenLockBtn.Text="🔒"
        ScreenLockBtn.BackgroundColor3=Color3.fromRGB(0,150,50)
    else
        ScreenLockBtn.Text="🔓"
        ScreenLockBtn.BackgroundColor3=Color3.fromRGB(40,40,40)
    end
end)

local dL,diL,dsL,spL
ScreenLockBtn.InputBegan:Connect(function(i)
    if Config.LockScreenFixed then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dL=true dsL=i.Position spL=ScreenLockBtn.AbsolutePosition
        i.Changed:Connect(function()
            if i.UserInputState==Enum.UserInputState.End then
                dL=false
                local vp=Camera.ViewportSize
                Config.LockBtnX=math.clamp(ScreenLockBtn.AbsolutePosition.X/vp.X,0,1)
                Config.LockBtnY=math.clamp(ScreenLockBtn.AbsolutePosition.Y/vp.Y,0,1)
                SaveConfig()
            end
        end)
    end
end)
ScreenLockBtn.InputChanged:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then diL=i end
end)
UserInputService.InputChanged:Connect(function(i)
    if i==diL and dL and not Config.LockScreenFixed then
        local d=i.Position-dsL
        local vp=Camera.ViewportSize
        Config.LockBtnX=math.clamp((spL.X+d.X)/vp.X,0,1)
        Config.LockBtnY=math.clamp((spL.Y+d.Y)/vp.Y,0,1)
        ScreenLockBtn.Position=UDim2.new(Config.LockBtnX,0,Config.LockBtnY,0)
    end
end)

RunService.RenderStepped:Connect(function()
    if RobloxMenuOpen then return end
    if isScreenLocked and Config.LockScreenEnabled then
        pcall(function()
            local c=LocalPlayer.Character
            if c then
                local hrp=c:FindFirstChild("HumanoidRootPart")
                local h=c:FindFirstChildOfClass("Humanoid")
                if hrp and h and h.Health>0 and not h.SeatPart then
                    local look=Camera.CFrame.LookVector
                    local flat=Vector3.new(look.X,0,look.Z)
                    if flat.Magnitude>0 then
                        flat=flat.Unit
                        hrp.CFrame=CFrame.new(hrp.Position,hrp.Position+flat)
                    end
                end
            end
        end)
    end
end)

-- ======================================================
-- AUTO PROMPT FLUTUANTE
-- ======================================================
local AutoPromptBtn=Instance.new("TextButton")
AutoPromptBtn.Size=UDim2.new(0,45,0,45)
AutoPromptBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
AutoPromptBtn.BackgroundTransparency=0.3
AutoPromptBtn.Text="⚡ OFF"
AutoPromptBtn.TextColor3=Color3.fromRGB(255,255,255)
AutoPromptBtn.TextSize=11
AutoPromptBtn.Font=Enum.Font.SourceSansBold
AutoPromptBtn.Visible=Config.AutoPromptEnabled
AutoPromptBtn.Position=UDim2.new(Config.PromptBtnX,0,Config.PromptBtnY,0)
AutoPromptBtn.Parent=ScreenGui
local PC=Instance.new("UICorner") PC.CornerRadius=UDim.new(1,0) PC.Parent=AutoPromptBtn
local PS=Instance.new("UIStroke") PS.Thickness=2 PS.Color=Color3.fromRGB(255,255,255) PS.Parent=AutoPromptBtn

local isAutoPromptActive=false
AutoPromptBtn.MouseButton1Click:Connect(function()
    isAutoPromptActive=not isAutoPromptActive
    if isAutoPromptActive then
        AutoPromptBtn.Text="⚡ ON"
        AutoPromptBtn.BackgroundColor3=Color3.fromRGB(50,200,50)
    else
        AutoPromptBtn.Text="⚡ OFF"
        AutoPromptBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
    end
end)

local dP,diP,dsP,spP
AutoPromptBtn.InputBegan:Connect(function(i)
    if Config.AutoPromptFixed then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        dP=true dsP=i.Position spP=AutoPromptBtn.AbsolutePosition
        i.Changed:Connect(function()
            if i.UserInputState==Enum.UserInputState.End then
                dP=false
                local vp=Camera.ViewportSize
                Config.PromptBtnX=math.clamp(AutoPromptBtn.AbsolutePosition.X/vp.X,0,1)
                Config.PromptBtnY=math.clamp(AutoPromptBtn.AbsolutePosition.Y/vp.Y,0,1)
                SaveConfig()
            end
        end)
    end
end)
AutoPromptBtn.InputChanged:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then diP=i end
end)
UserInputService.InputChanged:Connect(function(i)
    if i==diP and dP and not Config.AutoPromptFixed then
        local d=i.Position-dsP
        local vp=Camera.ViewportSize
        Config.PromptBtnX=math.clamp((spP.X+d.X)/vp.X,0,1)
        Config.PromptBtnY=math.clamp((spP.Y+d.Y)/vp.Y,0,1)
        AutoPromptBtn.Position=UDim2.new(Config.PromptBtnX,0,Config.PromptBtnY,0)
    end
end)

task.spawn(function()
    while true do
        if Config.AutoPromptEnabled and isAutoPromptActive and not RobloxMenuOpen then
            pcall(function()
                local c=LocalPlayer.Character
                if c and c:FindFirstChild("HumanoidRootPart") then
                    local p=c.HumanoidRootPart.Position
                    for _,o in ipairs(workspace:GetDescendants()) do
                        if o:IsA("ProximityPrompt") then
                            local pp=o.Parent
                            if pp and pp:IsA("BasePart") then
                                local d=(pp.Position-p).Magnitude
                                local m=(o.MaxActivationDistance and o.MaxActivationDistance>0) and (o.MaxActivationDistance+12) or 25
                                if d<=m then o.Enabled=true fireproximityprompt(o) end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.15)
    end
end)

-- ======================================================
-- CÂMERA 3ª PESSOA
-- ======================================================
local cameraConns={}
local propConns={}
local lastWasInVehicle=false

local function IsInVehicle()
    local char=LocalPlayer.Character
    if not char then return false end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.SeatPart~=nil then return true end
    if Camera.CameraSubject and Camera.CameraSubject~=hum then
        local cs=Camera.CameraSubject
        if cs:IsA("VehicleSeat") or cs:IsA("Seat") then return true end
        if cs:IsA("Humanoid") and cs.Parent~=char then return true end
    end
    return false
end

local function GetEffectiveDistance()
    local t = math.clamp(Config.CameraDistance or 80, 1, 100)
    return math.max(1, 51 - t * 0.5)
end

local function forceThirdPerson()
    if RobloxMenuOpen then return end
    local char=LocalPlayer.Character
    if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health<=0 then return end
    if IsInVehicle() then
        if hum.CameraOffset~=Vector3.new(0,0,0) then
            pcall(function() hum.CameraOffset=Vector3.new(0,0,0) end)
        end
        lastWasInVehicle=true
        return
    end
    if lastWasInVehicle then
        lastWasInVehicle=false
        pcall(function() hum.CameraOffset=Vector3.new(0,0,0) end)
        task.wait(0.1)
    end
    pcall(function()
        if Config.CameraLocked then
            local dist = GetEffectiveDistance()
            if LocalPlayer.CameraMinZoomDistance ~= dist then
                LocalPlayer.CameraMinZoomDistance = dist
            end
            if LocalPlayer.CameraMaxZoomDistance ~= dist then
                LocalPlayer.CameraMaxZoomDistance = dist
            end
        else
            if LocalPlayer.CameraMinZoomDistance > 0.6 then
                LocalPlayer.CameraMinZoomDistance = 0.5
            end
            if LocalPlayer.CameraMaxZoomDistance < 128 then
                LocalPlayer.CameraMaxZoomDistance = 128
            end
        end
        if LocalPlayer.CameraMode~=Enum.CameraMode.Classic then LocalPlayer.CameraMode=Enum.CameraMode.Classic end
        if Camera.CameraType~=Enum.CameraType.Custom then Camera.CameraType=Enum.CameraType.Custom end
        if Camera.CameraSubject~=hum then Camera.CameraSubject=hum end
        
        -- ✅ USA O VALOR DO TEXTBOX AQUI
        local yOffset = Config.RaiseCamera and Config.CameraRaiseOffset or 0
        local off = Vector3.new(Config.CameraOffsetRight, yOffset, 0)
        if hum.CameraOffset~=off then hum.CameraOffset=off end
    end)
end

local function startCameraForce()
    forceThirdPerson()
    for _,c in ipairs(cameraConns) do c:Disconnect() end
    cameraConns={}
    table.insert(cameraConns,RunService.Stepped:Connect(forceThirdPerson))
    table.insert(cameraConns,RunService.Heartbeat:Connect(forceThirdPerson))
    for _,c in ipairs(propConns) do c:Disconnect() end
    propConns={}
    table.insert(propConns,LocalPlayer:GetPropertyChangedSignal("CameraMode"):Connect(forceThirdPerson))
    table.insert(propConns,LocalPlayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(forceThirdPerson))
    table.insert(propConns,LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(forceThirdPerson))
    table.insert(propConns,Camera:GetPropertyChangedSignal("CameraType"):Connect(forceThirdPerson))
    table.insert(propConns,Camera:GetPropertyChangedSignal("CameraSubject"):Connect(forceThirdPerson))
    table.insert(propConns,LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        forceThirdPerson()
    end))
end

local function stopCameraForce()
    for _,c in ipairs(cameraConns) do c:Disconnect() end
    for _,c in ipairs(propConns) do c:Disconnect() end
    cameraConns={} propConns={}
    lastWasInVehicle=false
    local c=LocalPlayer.Character
    if c then
        local h=c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.CameraOffset=Vector3.new(0,0,0) end) end
    end
end

CameraBtn.MouseButton1Click:Connect(function()
    Config.CameraForce=not Config.CameraForce
    if Config.CameraForce then startCameraForce() else stopCameraForce() end
    UpdateVisuals() SaveConfig()
end)

RaiseCamBtn.MouseButton1Click:Connect(function()
    Config.RaiseCamera = not Config.RaiseCamera
    if Config.CameraForce then
        forceThirdPerson()
    end
    UpdateVisuals()
    SaveConfig()
end)

CameraLockBtn.MouseButton1Click:Connect(function()
    Config.CameraLocked = not Config.CameraLocked
    if Config.CameraForce then
        forceThirdPerson()
    end
    UpdateVisuals()
    SaveConfig()
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.CameraForce then startCameraForce() end
end)

local TargetInfo=Instance.new("TextLabel")
TargetInfo.Size=UDim2.new(0,200,0,30)
TargetInfo.Position=UDim2.new(0.5,-100,0,10)
TargetInfo.BackgroundTransparency=0.5
TargetInfo.BackgroundColor3=Color3.fromRGB(0,0,0)
TargetInfo.TextColor3=Color3.fromRGB(0,255,0)
TargetInfo.Font=Enum.Font.SourceSansBold
TargetInfo.TextSize=14
TargetInfo.Text="Procurando Alvo..."
TargetInfo.ZIndex=10
TargetInfo.Parent=ScreenGui

-- ======================================================
-- BARRA DE VIDA
-- ======================================================
local HealthBars = {}
local HealthVisibilityCache = {}
local HEALTH_VIS_TTL = 0.1

local function IsHeadVisible(player)
    local char = player.Character
    if not char then return false end
    local head = char:FindFirstChild("Head")
    if not head then return false end
    local cache = HealthVisibilityCache[player]
    if cache and tick() - cache.time < HEALTH_VIS_TTL then
        return cache.visible
    end
    local camPos = Camera.CFrame.Position
    local dir = head.Position - camPos
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LocalPlayer.Character, char }
    rp.IgnoreWater = true
    local result = workspace:Raycast(camPos, dir, rp)
    local visible = (result == nil)
    HealthVisibilityCache[player] = { visible = visible, time = tick() }
    return visible
end

local function GetHealthBar(player)
    local data = HealthBars[player]
    if data and data.gui and data.gui.Parent then
        return data
    end
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "hp_" .. tostring(player.UserId)
    bgui.Size = UDim2.new(0, 32, 0, 4)
    bgui.StudsOffset = Vector3.new(0, Config.HealthBarHeight, 0)
    bgui.AlwaysOnTop = true
    bgui.MaxDistance = math.huge
    bgui.LightInfluence = 0
    bgui.ResetOnSpawn = false
    bgui.Enabled = false
    bgui.Parent = ScreenGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    bg.BorderSizePixel = 0
    bg.Parent = bgui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 2)
    corner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Parent = bg

    local hp = Instance.new("Frame")
    hp.Name = "HP"
    hp.Size = UDim2.new(1, 0, 1, 0)
    hp.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hp.BorderSizePixel = 0
    hp.Parent = bg

    local hpCorner = Instance.new("UICorner")
    hpCorner.CornerRadius = UDim.new(0, 2)
    hpCorner.Parent = hp

    HealthBars[player] = {gui = bgui, hp = hp}
    return HealthBars[player]
end

local function UpdateHealthBar(player)
    if player == LocalPlayer then return end
    local data = HealthBars[player]
    if not Config.ShowHealth then
        if data and data.gui then data.gui.Enabled = false end
        return
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")
    if not hum or not head or hum.Health <= 0 then
        if data and data.gui then data.gui.Enabled = false end
        return
    end
    if not IsHeadVisible(player) then
        if data and data.gui then data.gui.Enabled = false end
        return
    end
    data = data or GetHealthBar(player)
    if data.gui.Adornee ~= head then data.gui.Adornee = head end
    if data.gui.StudsOffset.Y ~= Config.HealthBarHeight then
        data.gui.StudsOffset = Vector3.new(0, Config.HealthBarHeight, 0)
    end
    data.gui.Enabled = true
    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    data.hp.Size = UDim2.new(pct, 0, 1, 0)
    if pct > 0.5 then
        data.hp.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    elseif pct > 0.25 then
        data.hp.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    else
        data.hp.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    end
end

-- ======================================================
-- CONTADOR DE MORTES
-- ======================================================
local KILL_COLORS = {
    Color3.fromRGB(0, 255, 100),
    Color3.fromRGB(80, 180, 255),
    Color3.fromRGB(255, 220, 50),
    Color3.fromRGB(255, 100, 220),
    Color3.fromRGB(255, 140, 50),
    Color3.fromRGB(100, 255, 255),
    Color3.fromRGB(200, 100, 255),
    Color3.fromRGB(255, 100, 100),
}

local function GetPlayerKillColor(player)
    return KILL_COLORS[(player.UserId % #KILL_COLORS) + 1]
end

local KillDiff = {}
local KillBGUIs = {}

local function UpdateKillDisplay(player)
    if player == LocalPlayer then return end
    local count = KillDiff[player] or 0
    local show = count > 0 and Config.ShowKillCounter
    if not show then
        if KillBGUIs[player] then KillBGUIs[player].Enabled = false end
        return
    end
    local char = player.Character
    local head = char and char:FindFirstChild("Head")
    if not head then
        if KillBGUIs[player] then KillBGUIs[player].Enabled = false end
        return
    end
    local bgui = KillBGUIs[player]
    if not bgui or not bgui.Parent then
        bgui = Instance.new("BillboardGui")
        bgui.Name = "kill_" .. tostring(player.UserId)
        bgui.AlwaysOnTop = true
        bgui.MaxDistance = math.huge
        bgui.LightInfluence = 0
        bgui.ResetOnSpawn = false
        bgui.ClipsDescendants = false
        bgui.StudsOffset = Vector3.new(0, Config.HealthBarHeight + 1.2, 0)
        bgui.Parent = ScreenGui

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Count"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextSize = 11
        lbl.Text = "x"
        lbl.Parent = bgui
        KillBGUIs[player] = bgui
    end
    local desiredY = Config.HealthBarHeight + 1.2
    if bgui.StudsOffset.Y ~= desiredY then
        bgui.StudsOffset = Vector3.new(0, desiredY, 0)
    end
    local txt = ""
    for i = 1, count do
        if i > 1 then txt = txt .. " " end
        txt = txt .. "x"
    end
    bgui.Count.Text = txt
    bgui.Count.TextColor3 = GetPlayerKillColor(player)
    local w = math.max(14, count * 10 + 4)
    bgui.Size = UDim2.new(0, w, 0, 12)
    bgui.Adornee = head
    bgui.Enabled = true
end

local function HookLocalDeath(char)
    task.spawn(function()
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
        if not hum then return end
        hum.Died:Connect(function()
            local creator = hum:FindFirstChild("creator")
            if creator and creator.Value and creator.Value:IsA("Player") then
                local killer = creator.Value
                if killer ~= LocalPlayer then
                    KillDiff[killer] = (KillDiff[killer] or 0) + 1
                    task.wait(0.3)
                    UpdateKillDisplay(killer)
                end
            end
        end)
    end)
end
if LocalPlayer.Character then HookLocalDeath(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(HookLocalDeath)

local function HookEnemyDeath(player)
    if player == LocalPlayer then return end
    local function attach(char)
        task.spawn(function()
            local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
            if not hum then return end
            hum.Died:Connect(function()
                local creator = hum:FindFirstChild("creator")
                if creator and creator.Value == LocalPlayer then
                    local cur = KillDiff[player] or 0
                    if cur > 0 then
                        KillDiff[player] = cur - 1
                        UpdateKillDisplay(player)
                    end
                end
            end)
        end)
    end
    if player.Character then attach(player.Character) end
    player.CharacterAdded:Connect(attach)
end

-- ======================================================
-- ESP HIGHLIGHT & CRUZ (NÃO-AMIGOS)
-- ======================================================
local ESPHighlights={}
local EnemyPlusFrames={}

local function RemoveESP(player)
    if ESPHighlights[player] then
        ESPHighlights[player]:Destroy()
        ESPHighlights[player]=nil
    end
    if EnemyPlusFrames[player] then
        EnemyPlusFrames[player]:Destroy()
        EnemyPlusFrames[player]=nil
    end
end

local function ApplyESP(player)
    if not player or player==LocalPlayer then return end
    if IsRobloxFriend(player) then 
        RemoveESP(player) 
        return 
    end
    local char=player.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then
        RemoveESP(player)
        return
    end

    if not ESPHighlights[player] or ESPHighlights[player].Adornee ~= char then
        RemoveESP(player)
        local hl=Instance.new("Highlight")
        hl.Name="hl"
        hl.FillColor=Color3.fromRGB(255,30,30)
        hl.OutlineColor=Color3.fromRGB(255,255,255)
        hl.FillTransparency=0.55
        hl.OutlineTransparency=0
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee=char
        hl.Parent=ScreenGui
        ESPHighlights[player]=hl
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    
    if torso and hum then
        if not EnemyPlusFrames[player] or EnemyPlusFrames[player].Adornee ~= torso then
            if EnemyPlusFrames[player] then EnemyPlusFrames[player]:Destroy() end
            
            local bgui = Instance.new("BillboardGui")
            bgui.Name = "plus_"..tostring(player.UserId)
            bgui.Size = UDim2.new(0, 15, 0, 15)
            bgui.StudsOffset = Vector3.new(0, -1, 0) 
            bgui.AlwaysOnTop = true
            bgui.MaxDistance = math.huge
            bgui.LightInfluence = 0
            bgui.ResetOnSpawn = false
            bgui.Parent = ScreenGui
            
            local lbl = Instance.new("TextLabel")
            lbl.Name = "PlusLabel"
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "+"
            lbl.Font = Enum.Font.SourceSansBold
            lbl.TextScaled = true
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.Parent = bgui
            
            bgui.Adornee = torso
            bgui.Enabled = true
            EnemyPlusFrames[player] = bgui
        end

        local lbl = EnemyPlusFrames[player]:FindFirstChild("PlusLabel")
        if lbl then
            if hum.Health > 0 then
                lbl.TextColor3 = Color3.fromRGB(255, 0, 0)
            else
                lbl.TextColor3 = Color3.fromRGB(255, 165, 0)
            end
        end
    end
end

local function ClearAllESP()
    for p,hl in pairs(ESPHighlights) do
        if hl then hl:Destroy() end
    end
    ESPHighlights={}
    
    for p,plus in pairs(EnemyPlusFrames) do
        if plus then plus:Destroy() end
    end
    EnemyPlusFrames={}
end

local function RefreshAllESP()
    if not Config.ESPAllPlayers then ClearAllESP() return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then ApplyESP(p) end
    end
end

-- ======================================================
-- "A" VERDE (AMIGOS)
-- ======================================================
local AFrames={}

local function CreateAFrame(player)
    local bgui=Instance.new("BillboardGui")
    bgui.Name="fm_"..tostring(player.UserId)
    bgui.Size=UDim2.new(0,22,0,22)
    bgui.StudsOffset=Vector3.new(0, Config.HealthBarHeight + 0.6, 0)
    bgui.AlwaysOnTop=true
    bgui.MaxDistance=math.huge
    bgui.LightInfluence=0
    bgui.ClipsDescendants=false
    bgui.ResetOnSpawn=false
    bgui.Parent=ScreenGui

    local frame=Instance.new("Frame")
    frame.Size=UDim2.new(1,0,1,0)
    frame.BackgroundColor3=Color3.fromRGB(0,220,0)
    frame.BorderSizePixel=0
    frame.Parent=bgui

    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,6)
    corner.Parent=frame

    local stroke=Instance.new("UIStroke")
    stroke.Thickness=2
    stroke.Color=Color3.fromRGB(0,90,0)
    stroke.Parent=frame

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1
    lbl.Text="A"
    lbl.TextColor3=Color3.fromRGB(0,0,0)
    lbl.Font=Enum.Font.SourceSansBold
    lbl.TextScaled=true
    lbl.Parent=frame

    AFrames[player]=bgui
    return bgui
end

local function UpdateFriendMarkers()
    for _,player in ipairs(Players:GetPlayers()) do
        if player~=LocalPlayer then
            local isFriend=IsRobloxFriend(player)
            local char=player.Character
            local head=char and char:FindFirstChild("Head")
            if isFriend and Config.ShowFriendMarker and head and char:FindFirstChildOfClass("Humanoid") then
                local bgui=AFrames[player] or CreateAFrame(player)
                if bgui.Adornee~=head then bgui.Adornee=head end
                local desiredY = Config.HealthBarHeight + 0.6
                if bgui.StudsOffset.Y ~= desiredY then
                    bgui.StudsOffset = Vector3.new(0, desiredY, 0)
                end
                bgui.Enabled=true
            elseif AFrames[player] then
                AFrames[player].Enabled=false
            end
        end
    end
    for p,bgui in pairs(AFrames) do
        if not p.Parent then
            bgui:Destroy()
            AFrames[p]=nil
        end
    end
end

-- ======================================================
-- HOOKS POR PLAYER
-- ======================================================
local function HookPlayer(player)
    if player==LocalPlayer then return end
    HookEnemyDeath(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.15)
        if Config.ESPAllPlayers then ApplyESP(player) end
        UpdateFriendMarkers()
        UpdateKillDisplay(player)
    end)
    if Config.ESPAllPlayers then ApplyESP(player) end
    UpdateFriendMarkers()
    UpdateKillDisplay(player)
end

for _,p in ipairs(Players:GetPlayers()) do HookPlayer(p) end

Players.PlayerAdded:Connect(function(player)
    HookPlayer(player)
    task.wait(0.5)
    if Config.ESPAllPlayers then ApplyESP(player) end
    UpdateFriendMarkers()
    UpdateKillDisplay(player)
end)

Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
    if AFrames[p] then AFrames[p]:Destroy() AFrames[p]=nil end
    if KillBGUIs[p] then KillBGUIs[p]:Destroy() KillBGUIs[p]=nil end
    if HealthBars[p] then
        if HealthBars[p].gui then HealthBars[p].gui:Destroy() end
        HealthBars[p]=nil
    end
    KillDiff[p]=nil
    HealthVisibilityCache[p]=nil
end)

-- ======================================================
-- LOOP DE ATUALIZAÇÃO DA BARRA DE VIDA
-- ======================================================
RunService.RenderStepped:Connect(function()
    if not Config.ShowHealth then return end
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            UpdateHealthBar(player)
        end
    end
end)

-- ======================================================
-- LOOP DE SEGURANÇA (GARANTE O ESP E A COR DO "+")
-- ======================================================
task.spawn(function()
    while true do
        task.wait(0.2) 
        if Config.ESPAllPlayers and not RobloxMenuOpen then
            for _,player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    local isFriend = IsRobloxFriend(player)
                    
                    if char and char:FindFirstChildOfClass("Humanoid") then
                        if isFriend then
                            if ESPHighlights[player] or EnemyPlusFrames[player] then
                                RemoveESP(player)
                            end
                        else
                            local hl = ESPHighlights[player]
                            if not hl or hl.Adornee ~= char then
                                ApplyESP(player)
                            else
                                local plus = EnemyPlusFrames[player]
                                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
                                if torso and (not plus or plus.Adornee ~= torso) then
                                    ApplyESP(player)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        for player, plusGui in pairs(EnemyPlusFrames) do
            if plusGui and plusGui.Parent then
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local lbl = plusGui:FindFirstChild("PlusLabel")
                
                if hum and lbl then
                    if hum.Health > 0 then
                        lbl.TextColor3 = Color3.fromRGB(255, 0, 0)
                    else
                        lbl.TextColor3 = Color3.fromRGB(255, 165, 0)
                    end
                end
            end
        end

        UpdateFriendMarkers()
        
        for player,bgui in pairs(KillBGUIs) do
            if not player.Parent then
                bgui:Destroy()
                KillBGUIs[player]=nil
            elseif (KillDiff[player] or 0) > 0 and Config.ShowKillCounter then
                local char=player.Character
                local head=char and char:FindFirstChild("Head")
                if head then
                    if bgui.Adornee~=head then bgui.Adornee=head end
                    bgui.Enabled=true
                else
                    bgui.Enabled=false
                end
            end
        end
    end
end)

ESPAllBtn.MouseButton1Click:Connect(function()
    Config.ESPAllPlayers=not Config.ESPAllPlayers
    RefreshAllESP()
    UpdateVisuals() SaveConfig()
end)

FriendMarkerBtn.MouseButton1Click:Connect(function()
    Config.ShowFriendMarker=not Config.ShowFriendMarker
    UpdateFriendMarkers()
    UpdateVisuals() SaveConfig()
end)

KillCounterBtn.MouseButton1Click:Connect(function()
    Config.ShowKillCounter=not Config.ShowKillCounter
    if not Config.ShowKillCounter then
        for _,bgui in pairs(KillBGUIs) do bgui.Enabled=false end
    else
        for p in pairs(KillDiff) do
            if p.Parent then UpdateKillDisplay(p) end
        end
    end
    UpdateVisuals() SaveConfig()
end)

HealthBtn.MouseButton1Click:Connect(function()
    Config.ShowHealth=not Config.ShowHealth
    if not Config.ShowHealth then
        for _,data in pairs(HealthBars) do
            if data.gui then data.gui.Enabled=false end
        end
    end
    UpdateVisuals() SaveConfig()
end)

-- ======================================================
-- LISTA AMIGOS/INIMIGOS
-- ======================================================
local ListFrame=Instance.new("Frame")
ListFrame.Size=UDim2.new(0,250,0,400)
ListFrame.Position=UDim2.new(0.5,130,0.5,-200)
ListFrame.BackgroundColor3=Color3.fromRGB(20,20,20)
ListFrame.BorderSizePixel=0
ListFrame.Active=true
ListFrame.Draggable=true
ListFrame.Visible=false
ListFrame.ZIndex=50
ListFrame.Parent=ScreenGui

local LT=Instance.new("TextLabel")
LT.Size=UDim2.new(1,0,0,30)
LT.BackgroundColor3=Color3.fromRGB(150,50,200)
LT.Text="Gerenciar Alvos"
LT.TextColor3=Color3.fromRGB(255,255,255)
LT.Font=Enum.Font.SourceSansBold
LT.TextSize=16
LT.ZIndex=51
LT.Parent=ListFrame

local LS2=Instance.new("ScrollingFrame")
LS2.Size=UDim2.new(1,-10,1,-40)
LS2.Position=UDim2.new(0,5,0,35)
LS2.BackgroundColor3=Color3.fromRGB(30,30,30)
LS2.BorderSizePixel=0
LS2.ScrollBarThickness=6
LS2.ZIndex=51
LS2.Parent=ListFrame

local LL=Instance.new("UIListLayout")
LL.SortOrder=Enum.SortOrder.Name
LL.Padding=UDim.new(0,4)
LL.Parent=LS2

FriendListBtn.MouseButton1Click:Connect(function()
    ListFrame.Visible=not ListFrame.Visible
    if ListFrame.Visible then
        local function UpdateList()
            for _,c in ipairs(LS2:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
            end
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer then
                    local isT=MyTeamIDs[tostring(p.UserId)] or IsRobloxFriend(p)
                    local row=Instance.new("TextButton")
                    row.Size=UDim2.new(1,0,0,30)
                    row.BackgroundColor3=isT and Color3.fromRGB(0,100,200) or Color3.fromRGB(200,50,50)
                    row.Text=""
                    row.ZIndex=52
                    row.Parent=LS2
                    local nl=Instance.new("TextLabel")
                    nl.Size=UDim2.new(1,-50,1,0)
                    nl.Position=UDim2.new(0,5,0,0)
                    nl.BackgroundTransparency=1
                    nl.Text=p.Name
                    nl.TextColor3=Color3.fromRGB(255,255,255)
                    nl.TextXAlignment=Enum.TextXAlignment.Left
                    nl.Font=Enum.Font.SourceSansBold
                    nl.TextSize=14
                    nl.ZIndex=53
                    nl.Parent=row
                    local tb=Instance.new("TextButton")
                    tb.Size=UDim2.new(0,40,0,20)
                    tb.Position=UDim2.new(1,-45,0.5,-10)
                    tb.BackgroundColor3=BlockedPlayers[p] and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
                    tb.Text=BlockedPlayers[p] and "ON" or "OFF"
                    tb.TextColor3=Color3.fromRGB(255,255,255)
                    tb.Font=Enum.Font.SourceSansBold
                    tb.TextSize=12
                    tb.ZIndex=54
                    tb.Parent=row
                    tb.MouseButton1Click:Connect(function()
                        BlockedPlayers[p]=not BlockedPlayers[p]
                        tb.Text=BlockedPlayers[p] and "ON" or "OFF"
                        tb.BackgroundColor3=BlockedPlayers[p] and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
                    end)
                end
            end
            LS2.CanvasSize=UDim2.new(0,0,0,LL.AbsoluteContentSize.Y+10)
        end
        UpdateList()
        task.spawn(function()
            while ListFrame.Visible do UpdateList() task.wait(2) end
        end)
    end
end)

local function UpdateTeamCache()
    MyTeamIDs={}
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local hud=pg:FindFirstChild("GTA_CleanStats_HUD")
    if not hud then return end
    local isBlue=false
    for _,o in pairs(hud:GetDescendants()) do
        if o:IsA("TextLabel") then
            local t=o.Text
            if t=="BLUE TEAM" or t=="Blue Team" then isBlue=true
            elseif t=="RED TEAM" or t=="Red Team" then isBlue=false
            elseif isBlue then
                if string.match(t,"^%d+$") and string.len(t)>3 then MyTeamIDs[t]=true end
            end
        end
    end
end

local function IsPlayerMyTeammate(tp)
    if tp==LocalPlayer then return true end
    if BlockedPlayers[tp] then return true end 
    if not Config.IgnoreTeam then return false end 
    if IsRobloxFriend(tp) then return true end
    if MyTeamIDs[tostring(tp.UserId)] then return true end
    return false
end

-- ======================================================
-- FLICK SUAVE
-- ======================================================
UserInputService.InputBegan:Connect(function(i,gp)
    if gp or RobloxMenuOpen then return end
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        lastInputPosition=i.Position
    end
end)
UserInputService.InputChanged:Connect(function(i,gp)
    if gp or RobloxMenuOpen then return end
    if (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) and lastInputPosition then
        if (lastInputPosition.Y-i.Position.Y)>15 then
            isAimingHead=true
            headshotTimer=tick()+Config.HeadDelay
        end
        lastInputPosition=i.Position
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        lastInputPosition=nil
        isAimingHead=false
    end
end)

local CurrentTarget=nil

-- ======================================================
-- HIGHLIGHT DO ALVO
-- ======================================================
local TargetHighlight=Instance.new("Highlight")
TargetHighlight.Name="hl_target"
TargetHighlight.FillColor=Color3.fromRGB(255,30,30)
TargetHighlight.FillTransparency=0.55
TargetHighlight.OutlineColor=Color3.fromRGB(255,255,255)
TargetHighlight.OutlineTransparency=0
TargetHighlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
TargetHighlight.Parent=ScreenGui

local function DestroyLockRing() TargetHighlight.Adornee=nil end
local function UpdateLockRing(tp)
    if not tp or not tp.Character then TargetHighlight.Adornee=nil return end
    TargetHighlight.Adornee=tp.Character
end

-- ======================================================
-- UTILITÁRIOS AIMBOT
-- ======================================================
local function IsVisible(part)
    if not part then return false end
    local origin=Camera.CFrame.Position
    local dir=(part.Position-origin)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LocalPlayer.Character,part.Parent}
    local r=workspace:Raycast(origin,dir,rp)
    return r==nil
end

local function GetPlayerDistance3D(p)
    local mc=LocalPlayer.Character
    local tc=p and p.Character
    if not mc or not tc then return math.huge end
    local mh=mc:FindFirstChild("HumanoidRootPart")
    local th=tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild(Config.AimPart)
    if not mh or not th then return math.huge end
    return (th.Position-mh.Position).Magnitude
end

local function IsTargetValid(p)
    if not p or not p.Character then return false end
    local h=p.Character:FindFirstChildOfClass("Humanoid")
    local part=p.Character:FindFirstChild(Config.AimPart) or p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
    if not h or h.Health<=0 or not part then return false end
    if GetPlayerDistance3D(p)>Config.MaxDistance then return false end
    if IsPlayerMyTeammate(p) then return false end
    if Config.IgnoreWalls and not IsVisible(part) then return false end
    return true
end

local function GetScreenDistanceToPlayer(p)
    if not p or not p.Character then return math.huge,false end
    local part=p.Character:FindFirstChild(Config.AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
    if not part then return math.huge,false end
    local sp,on=Camera:WorldToViewportPoint(part.Position)
    if not on then return math.huge,false end
    local c=Camera.ViewportSize/2
    return (Vector2.new(sp.X,sp.Y)-Vector2.new(c.X,c.Y)).Magnitude,true
end

local function GetTarget()
    if CurrentTarget and IsTargetValid(CurrentTarget) then
        local d,on=GetScreenDistanceToPlayer(CurrentTarget)
        if on and d<=Config.FOV_Sticky then return CurrentTarget end
    end
    local best,bestD=nil,Config.FOV
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer and IsTargetValid(p) then
            local d,on=GetScreenDistanceToPlayer(p)
            if on and d<bestD then bestD=d best=p end
        end
    end
    return best
end

-- ======================================================
-- LOOP PRINCIPAL DO AIMBOT
-- ======================================================
RunService.RenderStepped:Connect(function()
    if RobloxMenuOpen then return end
    if tick()-LastCacheUpdate>2 then
        LastCacheUpdate=tick()
        task.spawn(UpdateTeamCache)
    end
    if not Config.Enabled then
        FovCircle.Visible=false
        StickyCircle.Visible=false
        CurrentTarget=nil
        DestroyLockRing()
        TargetInfo.Text="Aimbot Desligado"
        TargetInfo.TextColor3=Color3.fromRGB(255,0,0)
        return
    end
    FovCircle.Visible=true
    StickyCircle.Visible=true
    local targetPlayer=GetTarget()
    if not targetPlayer then
        CurrentTarget=nil
        DestroyLockRing()
        FS.Color=Color3.fromRGB(255,0,0)
        TargetInfo.Text="Procurando Inimigo..."
        TargetInfo.TextColor3=Color3.fromRGB(255,255,0)
        return
    end
    CurrentTarget=targetPlayer
    UpdateLockRing(targetPlayer)
    local d=GetScreenDistanceToPlayer(targetPlayer)
    FS.Color=d<=Config.FOV and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,165,0)
    local d3=math.floor(GetPlayerDistance3D(targetPlayer))
    TargetInfo.Text="Travado: "..targetPlayer.Name.." ("..d3.."m)"
    TargetInfo.TextColor3=Color3.fromRGB(0,255,0)

    local targetPart
    local aimingNeck=(Config.AimPart=="Neck")
    local isHeadshot=isAimingHead and tick()<headshotTimer
    if aimingNeck then
        if isHeadshot then
            targetPart=targetPlayer.Character:FindFirstChild("Head")
        else
            targetPart=targetPlayer.Character:FindFirstChild("UpperTorso") or targetPlayer.Character:FindFirstChild("Torso")
            if targetPart then
                local ncf=targetPart.CFrame*CFrame.new(0,targetPart.Size.Y/2.5,0)
                targetPart={Position=ncf.Position, AssemblyLinearVelocity=targetPart.AssemblyLinearVelocity}
            end
        end
    else
        targetPart=targetPlayer.Character:FindFirstChild(Config.AimPart) or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    end
    if not targetPart then return end

    local vel=targetPart.AssemblyLinearVelocity
    local camPos=Camera.CFrame.Position
    local rDist=(targetPart.Position-camPos).Magnitude
    local pred=Config.Prediction
    if rDist<30 then pred=Config.Prediction*0.3
    elseif rDist<70 then pred=Config.Prediction*0.7 end
    local predictedPos=targetPart.Position+(vel*pred)

    if aimingNeck and isHeadshot then
        local h=targetPlayer.Character:FindFirstChild("Head")
        if h then
            local top=h.Position+Vector3.new(0,h.Size.Y/2,0)
            local cur=(predictedPos-camPos).Unit
            if (camPos+cur*rDist).Y>top.Y then predictedPos=top end
        end
    end
    local aimDir=(predictedPos-camPos).Unit
    local targetCF=CFrame.new(camPos,camPos+aimDir)
    Camera.CFrame=Camera.CFrame:Lerp(targetCF,Config.Smoothness)
end)

-- ======================================================
-- DRAG DO MENU
-- ======================================================
local function MakeDraggable(g,f)
    local dr,di,ds,sp
    g.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dr=true ds=i.Position sp=f.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dr=false end end)
        end
    end)
    g.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then di=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==di and dr then
            local d=i.Position-ds
            f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end
MakeDraggable(Title,MainFrame)

local minimized=false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    ContentScroll.Visible=not minimized
    MainFrame.Size=minimized and UDim2.new(0,235,0,30) or UDim2.new(0,235,0,340)
end)

-- ======================================================
-- UPDATE VISUALS
-- ======================================================
function UpdateVisuals()
    AimToggle.BackgroundColor3=Config.Enabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    AimToggle.Text=Config.Enabled and "AIM: ON" or "AIM: OFF"
    PartBtn.Text="PARTE: "..Config.AimPart
    TeamBtn.BackgroundColor3=Config.IgnoreTeam and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    TeamBtn.Text="IGNORAR AMIGOS/EQUIPE: "..(Config.IgnoreTeam and "ON" or "OFF")
    WallBtn.BackgroundColor3=Config.IgnoreWalls and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    WallBtn.Text="NÃO ATRAVESSAR PAREDES: "..(Config.IgnoreWalls and "ON" or "OFF")
    HealthBtn.BackgroundColor3=Config.ShowHealth and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    HealthBtn.Text="MOSTRAR VIDA: "..(Config.ShowHealth and "ON" or "OFF")
    CameraBtn.BackgroundColor3=Config.CameraForce and Color3.fromRGB(50,200,50) or Color3.fromRGB(50,50,50)
    CameraBtn.Text="SAIR DA 1ª PESSOA: "..(Config.CameraForce and "ON" or "OFF")
    
    RaiseCamBtn.BackgroundColor3 = Config.RaiseCamera and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    RaiseCamBtn.Text = "LEVANTAR CÂMERA: " .. (Config.RaiseCamera and "ON" or "OFF")
    
    CameraLockBtn.BackgroundColor3 = Config.CameraLocked and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    CameraLockBtn.Text = "TRAVAR CÂMERA: " .. (Config.CameraLocked and "ON" or "OFF")
    OffsetBox.Text=tostring(Config.CameraOffsetRight)
    CameraDistBox.Text=tostring(Config.CameraDistance)
    RaiseAmountBox.Text=tostring(Config.CameraRaiseOffset) -- ✅ Atualiza o textbox
    MaxDistBox.Text=tostring(Config.MaxDistance)
    ScreenLockMenuBtn.BackgroundColor3=Config.LockScreenEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(50,50,50)
    ScreenLockMenuBtn.Text="CADEADO TELA: "..(Config.LockScreenEnabled and "ON" or "OFF")
    ScreenLockFixedBtn.BackgroundColor3=Config.LockScreenFixed and Color3.fromRGB(50,200,50) or Color3.fromRGB(50,50,50)
    ScreenLockFixedBtn.Text="TRAVAR CADEADO TELA: "..(Config.LockScreenFixed and "ON" or "OFF")
    AutoPromptMenuBtn.BackgroundColor3=Config.AutoPromptEnabled and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    AutoPromptMenuBtn.Text="AUTO PROMPT: "..(Config.AutoPromptEnabled and "ON" or "OFF")
    AutoPromptFixedBtn.BackgroundColor3=Config.AutoPromptFixed and Color3.fromRGB(50,200,50) or Color3.fromRGB(50,50,50)
    AutoPromptFixedBtn.Text="TRAVAR AUTO PROMPT: "..(Config.AutoPromptFixed and "ON" or "OFF")
    ESPAllBtn.BackgroundColor3=Config.ESPAllPlayers and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    ESPAllBtn.Text="ESP EM TODOS: "..(Config.ESPAllPlayers and "ON" or "OFF")
    FriendMarkerBtn.BackgroundColor3=Config.ShowFriendMarker and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    FriendMarkerBtn.Text="LETRA A AMIGO: "..(Config.ShowFriendMarker and "ON" or "OFF")
    KillCounterBtn.BackgroundColor3=Config.ShowKillCounter and Color3.fromRGB(50,200,50) or Color3.fromRGB(200,50,50)
    KillCounterBtn.Text="CONTADOR MORTES: "..(Config.ShowKillCounter and "ON" or "OFF")
    ScreenLockBtn.Visible=Config.LockScreenEnabled
    ScreenLockBtn.Position=UDim2.new(Config.LockBtnX,0,Config.LockBtnY,0)
    AutoPromptBtn.Visible=Config.AutoPromptEnabled
    AutoPromptBtn.Position=UDim2.new(Config.PromptBtnX,0,Config.PromptBtnY,0)
end

-- ======================================================
-- HANDLERS
-- ======================================================
AimToggle.MouseButton1Click:Connect(function() Config.Enabled=not Config.Enabled UpdateVisuals() SaveConfig() end)
TeamBtn.MouseButton1Click:Connect(function() 
    Config.IgnoreTeam=not Config.IgnoreTeam 
    FriendCache = {}
    FriendCacheTime = 0
    UpdateVisuals() 
    SaveConfig() 
end)
WallBtn.MouseButton1Click:Connect(function() Config.IgnoreWalls=not Config.IgnoreWalls UpdateVisuals() SaveConfig() end)

ScreenLockMenuBtn.MouseButton1Click:Connect(function()
    Config.LockScreenEnabled=not Config.LockScreenEnabled
    ScreenLockBtn.Visible=Config.LockScreenEnabled
    if not Config.LockScreenEnabled then
        isScreenLocked=false
        ScreenLockBtn.Text="🔓"
        ScreenLockBtn.BackgroundColor3=Color3.fromRGB(40,40,40)
    end
    UpdateVisuals() SaveConfig()
end)

ScreenLockFixedBtn.MouseButton1Click:Connect(function()
    Config.LockScreenFixed=not Config.LockScreenFixed
    UpdateVisuals() SaveConfig()
end)

AutoPromptMenuBtn.MouseButton1Click:Connect(function()
    Config.AutoPromptEnabled=not Config.AutoPromptEnabled
    AutoPromptBtn.Visible=Config.AutoPromptEnabled
    if not Config.AutoPromptEnabled then
        isAutoPromptActive=false
        AutoPromptBtn.Text="⚡ OFF"
        AutoPromptBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
    end
    UpdateVisuals() SaveConfig()
end)

AutoPromptFixedBtn.MouseButton1Click:Connect(function()
    Config.AutoPromptFixed=not Config.AutoPromptFixed
    UpdateVisuals() SaveConfig()
end)

FovBox.FocusLost:Connect(function()
    local n=tonumber(FovBox.Text)
    if n and n>5 then Config.FOV=n UpdateFovVisuals() SaveConfig() else FovBox.Text=tostring(Config.FOV) end
end)
StickyBox.FocusLost:Connect(function()
    local n=tonumber(StickyBox.Text)
    if n and n>5 then Config.FOV_Sticky=n UpdateFovVisuals() SaveConfig() else StickyBox.Text=tostring(Config.FOV_Sticky) end
end)
MaxDistBox.FocusLost:Connect(function()
    local n=tonumber(MaxDistBox.Text)
    if n and n>0 then Config.MaxDistance=n SaveConfig() else MaxDistBox.Text=tostring(Config.MaxDistance) end
end)
SmoothBox.FocusLost:Connect(function()
    local n=tonumber(SmoothBox.Text)
    if n and n>0 and n<=1 then Config.Smoothness=n SaveConfig() else SmoothBox.Text=tostring(Config.Smoothness) end
end)
DelayBox.FocusLost:Connect(function()
    local n=tonumber(DelayBox.Text)
    if n and n>=0 then Config.HeadDelay=n SaveConfig() else DelayBox.Text=tostring(Config.HeadDelay) end
end)
OffsetBox.FocusLost:Connect(function()
    local n=tonumber(OffsetBox.Text)
    if n then Config.CameraOffsetRight=n SaveConfig() if Config.CameraForce then startCameraForce() end
    else OffsetBox.Text=tostring(Config.CameraOffsetRight) end
end)

-- ✅ NOVO HANDLER DO TEXTBOX DE ALTURA
RaiseAmountBox.FocusLost:Connect(function()
    local n=tonumber(RaiseAmountBox.Text)
    if n and n>=0 then 
        Config.CameraRaiseOffset=n 
        SaveConfig() 
        if Config.CameraForce then forceThirdPerson() end
    else 
        RaiseAmountBox.Text=tostring(Config.CameraRaiseOffset) 
    end
end)

CameraDistBox.FocusLost:Connect(function()
    local n=tonumber(CameraDistBox.Text)
    if n and n>=1 and n<=100 then
        Config.CameraDistance=n
        SaveConfig()
        if Config.CameraForce and Config.CameraLocked then
            forceThirdPerson()
        end
    else
        CameraDistBox.Text=tostring(Config.CameraDistance)
    end
end)

PartBtn.MouseButton1Click:Connect(function()
    if Config.AimPart=="Head" then Config.AimPart="Torso"
    elseif Config.AimPart=="Torso" then Config.AimPart="Neck"
    else Config.AimPart="Head" end
    UpdateVisuals() SaveConfig()
end)

if Config.CameraForce then startCameraForce() end
RefreshAllESP()
UpdateFriendMarkers()
UpdateVisuals()