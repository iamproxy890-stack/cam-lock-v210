--[[
    AIMBOT PRO SCRIPT - Prensado Camlock v6
    Interfaz basada en la imagen proporcionada.
    Teclas: CONFIG.KEY (toggle) | INSERT (panel) | DELETE (unload)
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local CoreGui          = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local CONFIG = {
    KEY         = Enum.KeyCode.F,
    UNLOAD_KEY  = Enum.KeyCode.Delete,
    PANEL_KEY   = Enum.KeyCode.Insert,

    AIM_PART    = "Head",
    MODE        = "Smooth",
    ACTIVATION  = "Always", -- "Always" | "Hold RMB"

    FOV         = 120,
    SMOOTHNESS  = 0.85,
    TRACK_SPEED = 0.70,
    PREDICTION  = 0.05,
    MAX_DISTANCE= 2000,

    TEAM_CHECK  = true,
    WALL_CHECK  = false,
    SHOW_FOV    = true,
    HIGHLIGHT   = true,

    ESP_ENABLED      = false,
    ESP_BOX          = true,
    ESP_LINE         = true,
    ESP_SHOW_DIST    = true,
    ESP_COLOR        = Color3.fromRGB(255, 0, 0),
    ESP_BOX_SIZE     = 1.0,
    ESP_TRANSP       = 0.8,
    ESP_MAX_DIST     = 1000,
    ESP_TEAM_CHECK   = true,

    NO_RECOIL        = false,
    NO_SPREAD        = false,
    AUTO_FIRE        = false,

    IGNORE_LIST      = {},
}
-- ==================================================

local enabled = false
local unloaded = false
local locked = nil
local needRelock = true
local Connections = {}
local ignored = {}

local function conn(c) table.insert(Connections, c); return c end

local function isAlive(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return (hum and hum.Health > 0) and true or false
end

local function isIgnored(plr)
    return ignored[plr.UserId] == true
end

local function getPart(char)
    if not char then return nil end
    local name = CONFIG.AIM_PART
    if name == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart")
end

local function predict(pos, vel)
    return pos + (vel * CONFIG.PREDICTION)
end

local function findTarget()
    local best, bestScore
    local center = Camera.ViewportSize / 2
    local camPos = Camera.CFrame.Position
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isIgnored(plr) then
            local char = plr.Character
            if char and isAlive(plr) then
                local ok = not (CONFIG.TEAM_CHECK and LP.Team and plr.Team == LP.Team)
                if ok then
                    local part = getPart(char)
                    if part then
                        local worldPos = predict(part.Position, part.AssemblyLinearVelocity)
                        local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
                        if onScreen and sp.Z > 0 then
                            local off = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if off <= CONFIG.FOV / 2 then
                                local dist = (part.Position - camPos).Magnitude
                                if dist <= CONFIG.MAX_DISTANCE then
                                    local score = off + dist * 0.05
                                    if not bestScore or score < bestScore then
                                        best, bestScore = plr, score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local circle
pcall(function()
    circle = Drawing.new("Circle")
    circle.Thickness = 1.5
    circle.NumSides = 64
    circle.Filled = false
    circle.Color = Color3.fromRGB(255, 0, 0)
    circle.Transparency = 0.65
end)

local function setHighlight(plr)
    if _G.CurrentHighlight then _G.CurrentHighlight:Destroy(); _G.CurrentHighlight = nil end
    if not CONFIG.HIGHLIGHT or not plr then return end
    local char = plr.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.FillTransparency = 0.6
    hl.OutlineColor = Color3.fromRGB(255, 0, 0)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = game:GetService("CoreGui")
    _G.CurrentHighlight = hl
end

local function release()
    locked = nil
    setHighlight(nil)
end

local function acquire()
    local t = findTarget()
    if not t then return end
    locked = t
    setHighlight(t)
    if CONFIG.SNAP_ON_LOCK ~= false then
        local part = getPart(t.Character)
        if part then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
        end
    end
end

-- ===================== ESP =====================
local espFolder = Instance.new("Folder", CoreGui)
espFolder.Name = "AimbotESP"

local function buildESP(plr)
    if not CONFIG.ESP_ENABLED or plr == LP then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_"..plr.Name
    bb.Size = UDim2.fromOffset(50, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder

    if CONFIG.ESP_BOX then
        local box = Instance.new("Frame")
        box.Size = UDim2.fromScale(1, 1.5) 
        box.Position = UDim2.fromScale(0, -0.25)
        box.BackgroundTransparency = 1
        box.BorderSizePixel = 0
        box.Parent = bb
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = CONFIG.ESP_COLOR
        stroke.Thickness = CONFIG.ESP_BOX_SIZE
        stroke.Transparency = CONFIG.ESP_TRANSP
        stroke.Parent = box
    end

    if CONFIG.ESP_SHOW_DIST then
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.fromOffset(100, 20)
        txt.Position = UDim2.fromOffset(-25, -20)
        txt.BackgroundTransparency = 1
        txt.TextColor3 = CONFIG.ESP_COLOR
        txt.TextStrokeTransparency = 0.5
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 12
        txt.Text = ""
        txt.Parent = bb
    end
end

local function refreshESP()
    for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
    if not CONFIG.ESP_ENABLED then return end
    for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
end

-- ===================== LÓGICA PRINCIPAL =====================
conn(RunService:BindToRenderStep("AimbotPro",
    Enum.RenderPriority.Camera.Value + 1, function(dt)
    if unloaded then return end
    Camera = Workspace.CurrentCamera
    
    if circle then
        circle.Position = Camera.ViewportSize / 2
        circle.Radius = CONFIG.FOV / 2
        circle.Visible = CONFIG.SHOW_FOV and enabled
    end

    if not enabled then return end
    
    local hold = CONFIG.ACTIVATION == "Hold RMB" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if CONFIG.ACTIVATION == "Hold RMB" and not hold then
        release()
        return
    end

    if locked and (not isAlive(locked) or not getPart(locked.Character)) then
        release()
        needRelock = true
    end

    if needRelock and not locked then
        acquire()
        if locked then needRelock = false end
    end

    if not locked then return end
    local part = getPart(locked.Character)
    if not part then return end

    local goal = predict(part.Position, part.AssemblyLinearVelocity)
    local goalCF = CFrame.lookAt(Camera.CFrame.Position, goal)

    if CONFIG.MODE == "Snap" then
        Camera.CFrame = goalCF
    else
        local alpha = 1 - (1 - CONFIG.SMOOTHNESS) ^ (math.min(dt, 0.05) * 60)
        Camera.CFrame = Camera.CFrame:Lerp(goalCF, math.clamp(alpha, 0, 1))
    end
end))

conn(RunService.Heartbeat:Connect(function()
    if not CONFIG.ESP_ENABLED then return end
    for _, bb in ipairs(espFolder:GetChildren()) do
        local plr = Players:FindFirstChild(bb.Name:gsub("ESP_", ""))
        if plr and plr.Character and plr.Character:FindFirstChild("Head") then
            local head = plr.Character.Head
            local dist = (head.Position - Camera.CFrame.Position).Magnitude
            
            local isTeam = CONFIG.ESP_TEAM_CHECK and LP.Team and plr.Team == LP.Team
            local show = not isTeam and dist <= CONFIG.ESP_MAX_DIST and isAlive(plr)
            
            bb.Enabled = show
            bb.Adornee = head
            
            local txt = bb:FindFirstChildOfClass("TextLabel")
            if txt then txt.Text = string.format("%dm", math.floor(dist)) end
        else
            bb.Enabled = false
        end
    end
end))

-- ===================== INTERFAZ GRÁFICA (AIMBOT PRO) =====================
local gui = Instance.new("ScreenGui")
gui.Name = "AimbotProUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

-- Colores
local COLOR_BG = Color3.fromRGB(10, 5, 10)
local COLOR_PANEL = Color3.fromRGB(15, 10, 15)
local COLOR_RED = Color3.fromRGB(255, 0, 50)
local COLOR_PURPLE = Color3.fromRGB(150, 50, 255)
local COLOR_TEXT = Color3.fromRGB(240, 240, 240)

local function mkBtn(parent, text, w, h, x, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, h)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    b.TextColor3 = COLOR_TEXT
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = parent
    
    local c = Instance.new("UICorner", b)
    c.CornerRadius = UDim.new(0, 6)
    
    local s = Instance.new("UIStroke", b)
    s.Color = COLOR_PURPLE
    s.Thickness = 1
    
    return b
end

local function mkTab(parent, text, y)
    local b = mkBtn(parent, text, 160, 35, 10, y)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "   " .. text
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(20, 20)
    icon.Position = UDim2.fromOffset(10, 7)
    icon.BackgroundTransparency = 1
    icon.Text = "O" -- Icono simple
    icon.TextColor3 = COLOR_RED
    icon.Parent = b
    
    return b
end

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(750, 500)
panel.Position = UDim2.new(0.5, -375, 0.5, -250)
panel.BackgroundColor3 = COLOR_BG
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui

local pc = Instance.new("UICorner", panel)
pc.CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke", panel)
ps.Color = COLOR_PURPLE
ps.Thickness = 1.5

-- Barra Superior
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Color3.fromRGB(20, 10, 20)
topBar.Parent = panel
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.fromOffset(200, 40)
title.Position = UDim2.fromOffset(20, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = COLOR_RED
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "AIMBOT <font color='#FFFFFF'>PRO</font>"
title.RichText = true
title.Parent = topBar

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(150, 40)
statusLabel.Position = UDim2.new(0.5, -75, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14
statusLabel.TextColor3 = COLOR_RED
statusLabel.Text = "ESTADO: DESACTIVADO"
statusLabel.Parent = topBar

local closeBtn = mkBtn(topBar, "X", 30, 30, 710, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 10)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Barra Lateral (Tabs)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.fromOffset(180, 420)
sidebar.Position = UDim2.fromOffset(10, 60)
sidebar.BackgroundTransparency = 1
sidebar.Parent = panel

local tabs = {"AIMBOT", "VISUALES", "MISC", "CONFIG"}
local pages = {}
local activeTab = nil

local function switchTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabs) do 
        if b == name then
            -- Resaltar
        end
    end
end

for i, tabName in ipairs(tabs) do
    local b = mkTab(sidebar, tabName, (i-1) * 45)
    b.MouseButton1Click:Connect(function()
        for _, p in pairs(pages) do p.Visible = false end
        pages[tabName].Visible = true
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(20, 15, 20) end
        end
        b.BackgroundColor3 = Color3.fromRGB(40, 10, 20)
    end)
end

-- Contenedor de Páginas
local pageContainer = Instance.new("Frame")
pageContainer.Size = UDim2.new(1, -200, 1, -110)
pageContainer.Position = UDim2.fromOffset(200, 60)
pageContainer.BackgroundTransparency = 1
pageContainer.Parent = panel

-- Pagina AIMBOT
local aimPage = Instance.new("ScrollingFrame")
aimPage.Size = UDim2.fromScale(1, 1)
aimPage.BackgroundTransparency = 1
aimPage.BorderSizePixel = 0
aimPage.ScrollBarThickness = 2
aimPage.ScrollBarImageColor3 = COLOR_PURPLE
aimPage.CanvasSize = UDim2.new(0, 0, 0, 500)
aimPage.Visible = true
aimPage.Parent = pageContainer
pages["AIMBOT"] = aimPage

local aimTitle = Instance.new("TextLabel")
aimTitle.Size = UDim2.new(1, 0, 0, 30)
aimTitle.BackgroundTransparency = 1
aimTitle.Font = Enum.Font.GothamBold
aimTitle.TextSize = 16
aimTitle.TextColor3 = COLOR_TEXT
aimTitle.TextXAlignment = Enum.TextXAlignment.Left
aimTitle.Text = "CONFIGURACIÓN DEL AIMBOT"
aimTitle.Parent = aimPage

local function mkRow(parent, text, y, isToggle, get, set, options)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -10, 0, 35)
    f.Position = UDim2.fromOffset(5, y)
    f.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(250, 35)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextColor3 = COLOR_TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    l.Parent = f
    
    if isToggle then
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(40, 20)
        btn.Position = UDim2.new(1, -50, 0.5, -10)
        btn.BackgroundColor3 = get() and COLOR_RED or Color3.fromRGB(50, 50, 50)
        btn.Text = ""
        btn.Parent = f
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        btn.MouseButton1Click:Connect(function()
            set(not get())
            btn.BackgroundColor3 = get() and COLOR_RED or Color3.fromRGB(50, 50, 50)
        end)
    elseif options then
        local btn = mkBtn(f, get(), 150, 25, 250, 5)
        btn.MouseButton1Click:Connect(function()
            -- Lógica simple de rotación
            local idx = 1
            for i, v in ipairs(options) do if v == get() then idx = i end end
            local nextIdx = (idx % #options) + 1
            set(options[nextIdx])
            btn.Text = options[nextIdx]
        end)
    else
        local s = Instance.new("TextSlider") -- Nota: Roblox no tiene TextSlider nativo, usamos un Frame simulado
    end
    return f
end

-- Slider Personalizado
local function mkSlider(parent, label, y, get, set, min, max)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -10, 0, 40)
    f.Position = UDim2.fromOffset(5, y)
    f.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(200, 40)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextColor3 = COLOR_TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label
    l.Parent = f
    
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.fromOffset(200, 6)
    barBg.Position = UDim2.new(0, 220, 0.5, -3)
    barBg.BackgroundColor3 = Color3.fromRGB(50, 20, 50)
    barBg.Parent = f
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
    
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new((get() - min) / (max - min), 0, 1, 0)
    barFill.BackgroundColor3 = COLOR_RED
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = UDim2.new(1, -6, 0.5, -6)
    knob.BackgroundColor3 = COLOR_PURPLE
    knob.Parent = barFill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    
    local val = Instance.new("TextLabel")
    val.Size = UDim2.fromOffset(40, 40)
    val.Position = UDim2.new(1, -40, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = tostring(get())
    val.TextColor3 = COLOR_TEXT
    val.Parent = f
    
    local dragging = false
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local v = min + (max - min) * relX
            set(v)
            barFill.Size = UDim2.new(relX, 0, 1, 0)
            val.Text = string.format("%.0f", v)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

mkRow(aimPage, "Activar Aimbot", 40, true, 
    function() return enabled end, 
    function(v) enabled = v; statusLabel.Text = v and "ESTADO: ACTIVADO" or "ESTADO: DESACTIVADO"; statusLabel.TextColor3 = v and Color3.fromRGB(0,255,0) or COLOR_RED end)

mkRow(aimPage, "Modo de Apuntado", 85, false,
    function() return CONFIG.AIM_PART end,
    function(v) CONFIG.AIM_PART = v end,
    {"Head", "Torso", "Closest"})

mkRow(aimPage, "Tecla de Activación", 130, false,
    function() return CONFIG.ACTIVATION end,
    function(v) CONFIG.ACTIVATION = v end,
    {"Always", "Hold RMB"})

mkSlider(aimPage, "Área de FOV", 175, 
    function() return CONFIG.FOV end, 
    function(v) CONFIG.FOV = v end, 20, 800)

mkSlider(aimPage, "Suavizado (Smooth)", 220, 
    function() return CONFIG.SMOOTHNESS * 100 end, 
    function(v) CONFIG.SMOOTHNESS = v / 100 end, 1, 100)

mkSlider(aimPage, "Velocidad de Seguimiento", 265, 
    function() return CONFIG.TRACK_SPEED * 100 end, 
    function(v) CONFIG.TRACK_SPEED = v / 100 end, 1, 100)

-- Pagina VISUALES
local visPage = Instance.new("ScrollingFrame")
visPage.Size = UDim2.fromScale(1, 1)
visPage.BackgroundTransparency = 1
visPage.BorderSizePixel = 0
visPage.ScrollBarThickness = 2
visPage.CanvasSize = UDim2.new(0, 0, 0, 400)
visPage.Visible = false
visPage.Parent = pageContainer
pages["VISUALES"] = visPage

local visTitle = Instance.new("TextLabel")
visTitle.Size = UDim2.new(1, 0, 0, 30)
visTitle.BackgroundTransparency = 1
visTitle.Font = Enum.Font.GothamBold
visTitle.TextSize = 16
visTitle.TextColor3 = COLOR_TEXT
visTitle.TextXAlignment = Enum.TextXAlignment.Left
visTitle.Text = "CONFIGURACIÓN VISUAL"
visTitle.Parent = visPage

mkRow(visPage, "ESP (Enemigos)", 40, true,
    function() return CONFIG.ESP_ENABLED end,
    function(v) CONFIG.ESP_ENABLED = v; refreshESP() end)

mkRow(visPage, "Caja Alrededor", 85, true,
    function() return CONFIG.ESP_BOX end,
    function(v) CONFIG.ESP_BOX = v; refreshESP() end)

mkRow(visPage, "Mostrar Distancia", 130, true,
    function() return CONFIG.ESP_SHOW_DIST end,
    function(v) CONFIG.ESP_SHOW_DIST = v; refreshESP() end)

mkSlider(visPage, "Tamaño de Caja", 175, 
    function() return CONFIG.ESP_BOX_SIZE end, 
    function(v) CONFIG.ESP_BOX_SIZE = v; refreshESP() end, 1, 5)

mkSlider(visPage, "Opacidad", 220, 
    function() return CONFIG.ESP_TRANSP * 100 end, 
    function(v) CONFIG.ESP_TRANSP = v / 100; refreshESP() end, 0, 100)

-- Pagina MISC
local miscPage = Instance.new("ScrollingFrame")
miscPage.Size = UDim2.fromScale(1, 1)
miscPage.BackgroundTransparency = 1
miscPage.BorderSizePixel = 0
miscPage.Visible = false
miscPage.Parent = pageContainer
pages["MISC"] = miscPage

mkRow(miscPage, "No Recoil (Visual)", 20, true,
    function() return CONFIG.NO_RECOIL end,
    function(v) CONFIG.NO_RECOIL = v end)

mkRow(miscPage, "No Spread (Visual)", 65, true,
    function() return CONFIG.NO_SPREAD end,
    function(v) CONFIG.NO_SPREAD = v end)

mkRow(miscPage, "Auto Disparo", 110, true,
    function() return CONFIG.AUTO_FIRE end,
    function(v) CONFIG.AUTO_FIRE = v end)

-- Pagina CONFIG
local cfgPage = Instance.new("Frame")
cfgPage.Size = UDim2.fromScale(1, 1)
cfgPage.BackgroundTransparency = 1
cfgPage.Visible = false
cfgPage.Parent = pageContainer
pages["CONFIG"] = cfgPage

local resetBtn = mkBtn(cfgPage, "RESTABLECER", 150, 40, 10, 20)
resetBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 50)
resetBtn.MouseButton1Click:Connect(function()
    CONFIG.FOV = 120
    CONFIG.SMOOTHNESS = 0.85
    CONFIG.TRACK_SPEED = 0.70
    print("Configuración restablecida")
end)

local applyBtn = mkBtn(cfgPage, "APLICAR", 150, 40, 170, 20)
applyBtn.BackgroundColor3 = COLOR_RED
applyBtn.MouseButton1Click:Connect(function()
    print("Configuración aplicada")
end)

-- Hacer el panel arrastrable
local dragging, dragStart, startPos
panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Teclas
conn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.KEY then
        enabled = not enabled
        statusLabel.Text = enabled and "ESTADO: ACTIVADO" or "ESTADO: DESACTIVADO"
        statusLabel.TextColor3 = enabled and Color3.fromRGB(0,255,0) or COLOR_RED
    elseif input.KeyCode == CONFIG.PANEL_KEY then
        gui.Enabled = not gui.Enabled
    elseif input.KeyCode == CONFIG.UNLOAD_KEY then
        unloaded = true
        gui:Destroy()
        if _G.CurrentHighlight then _G.CurrentHighlight:Destroy() end
        if circle then circle:Remove() end
        RunService:UnbindFromRenderStep("AimbotPro")
    end
end))

print("[Aimbot Pro] Cargado correctamente.")