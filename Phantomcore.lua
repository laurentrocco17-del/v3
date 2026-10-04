local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local CONFIG_DIR = "phantomcore_configs"
local AUTOLOAD_MARKER = "phantomcore_autoload.txt"
local DEFAULT_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local T = {
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(10, 10, 10),
    panel2 = Color3.fromRGB(20, 20, 20),
    border = Color3.fromRGB(60, 60, 60),
    text = Color3.fromRGB(255, 255, 255),
    dim = Color3.fromRGB(180, 180, 180),
    faint = Color3.fromRGB(120, 120, 120),
    accent = Color3.fromRGB(230, 230, 230),
    ok = Color3.fromRGB(80, 255, 130),
    warn = Color3.fromRGB(255, 180, 60),
    danger = Color3.fromRGB(255, 80, 80),
}

local cfg = {
    teleEnabled = false,
    teleDelay = 0.5,
    selected = nil,
    useAll = true,
    voidEnabled = false,
    voidForce = 500000,
    voidInterval = 0.1,
    holdTime = 0.3,
    espEnabled = false,
    espColor = 1,
    hitSound = false,
    soundId = "",
    fullbright = false,
    fpsOverlay = true,
    noclip = false,
    autoMelee = false,
    rapidFire = false,
    rapidAttack = false,
    auraEnabled = false,
    auraColor = 1,
    cameraFollow = false,
    autoLoad = false,
    activeConfig = "",
    killFeed = true,
    combatTimer = true,
    voidTrack = true,
    suspicious = true,
    notifications = true,
    holding = false,
    holdTarget = nil,
    teleKey = Enum.KeyCode.L,
    voidKey = Enum.KeyCode.V,
    bgEnabled = false,
    bgOffsetBack = 3,
    bgOffsetUp = 1.5,
    bgIgnoreTeam = false,
    bgLockCamera = false,
    flyEnabled = false,
    flySpeed = 60,
    flyKey = Enum.KeyCode.F,
    antiAim = false,
    antiAimDepth = 30,
}

local colors = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(255, 60, 60),
    Color3.fromRGB(60, 255, 120),
    Color3.fromRGB(80, 160, 255),
    Color3.fromRGB(255, 220, 60),
    Color3.fromRGB(255, 80, 220),
}
local colorNames = { "WHITE", "RED", "GREEN", "BLUE", "YELLOW", "PINK", "RAINBOW" }
local RAINBOW_IDX = 7
local rainbowHue = 0
local meleeKeywords = { "chainsaw", "sword", "knife", "axe", "bat", "hammer", "melee", "blade", "katana", "fist", "punch" }

local espGui = Instance.new("ScreenGui")
espGui.Name = "PC_ESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 999998
espGui.Parent = LP:WaitForChild("PlayerGui")

local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "PC_FPS"
fpsGui.ResetOnSpawn = false
fpsGui.IgnoreGuiInset = true
fpsGui.DisplayOrder = 999997
fpsGui.Parent = LP:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "PHANTOMCORE"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = LP:WaitForChild("PlayerGui")

local highlights = {}
local players = {}
local playerIndex = 1
local lastTele = tick()
local lastCycle = tick()
local rng = Random.new()
local savedLighting = nil
local awaitingBind = nil
local voidThread = nil
local comboThread = nil
local noclipConn = nil
local autoMeleeThread = nil
local rapidFireThread = nil
local rapidAttackConn = nil
local bgConn = nil
local bgLockedTarget = nil
local mouseDown = false
local auraHighlight = nil
local auraLight = nil
local camFollowTarget = nil
local lastSeen = {}
local lastVel = {}
local combatStart = tick()
local inCombat = false
local lastDamage = 0
local threatFlag = {}
local lastThreatToast = 0

local flyBV = nil
local flyBG = nil
local flyConn = nil
local antiAimConn = nil
local antiAimOrigin = nil

local function refreshPlayers()
    players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(players, p) end
    end
end

local function getRoot()
    local c = LP.Character
    if c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Humanoid") and c.Humanoid.Health > 0 then
        return c.HumanoidRootPart
    end
end

local function teleportTo(p)
    local r = getRoot()
    if not r then return false end
    local tc = p.Character
    if tc and tc:FindFirstChild("Head") then
        r.CFrame = CFrame.new(tc.Head.Position + Vector3.new(0, 1, 0))
        return true
    end
    return false
end

local function nearestPlayer()
    local r = getRoot()
    if not r then return nil end
    local myPos = r.Position
    local near, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local c = p.Character
            if c then
                local h = c:FindFirstChild("Head")
                if h then
                    local d = (h.Position - myPos).Magnitude
                    if d < dist then dist = d near = p end
                end
            end
        end
    end
    return near
end

local function curColor()
    if cfg.espColor == RAINBOW_IDX then
        return Color3.fromHSV(rainbowHue, 1, 1)
    end
    return colors[cfg.espColor]
end

local function curAuraColor()
    if cfg.auraColor == RAINBOW_IDX then
        return Color3.fromHSV((rainbowHue + 0.5) % 1, 1, 1)
    end
    return colors[cfg.auraColor]
end

local function mkBtn(parent, y, w, xOff, txt, accent)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.Size = UDim2.new(w, -4, 0, 26)
    b.Position = UDim2.new(xOff, 2, 0, y)
    b.BackgroundColor3 = accent and T.accent or T.panel2
    b.Text = txt
    b.TextColor3 = accent and T.bg or T.text
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 102
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
    local s = Instance.new("UIStroke", b)
    s.Color = T.border
    s.Thickness = 1
    return b
end

local function mkHeader(parent, y, txt)
    local h = Instance.new("Frame")
    h.Parent = parent
    h.Size = UDim2.new(1, -8, 0, 22)
    h.Position = UDim2.new(0, 4, 0, y)
    h.BackgroundColor3 = T.panel
    h.BorderSizePixel = 0
    h.ZIndex = 102
    Instance.new("UICorner", h).CornerRadius = UDim.new(0, 3)
    local hs = Instance.new("UIStroke", h)
    hs.Color = T.border
    hs.Thickness = 1
    local ht = Instance.new("TextLabel")
    ht.Parent = h
    ht.Size = UDim2.new(1, -16, 1, 0)
    ht.Position = UDim2.new(0, 8, 0, 0)
    ht.BackgroundTransparency = 1
    ht.Text = txt
    ht.TextColor3 = T.dim
    ht.TextSize = 10
    ht.Font = Enum.Font.GothamBold
    ht.TextXAlignment = Enum.TextXAlignment.Left
    ht.ZIndex = 103
end

local function mkSlider(parent, y, title, desc, defVal, dispFn, applyFn)
    local card = Instance.new("Frame")
    card.Parent = parent
    card.Size = UDim2.new(1, -8, 0, 70)
    card.Position = UDim2.new(0, 4, 0, y)
    card.BackgroundColor3 = T.panel
    card.BorderSizePixel = 0
    card.ZIndex = 102
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 3)
    local cs = Instance.new("UIStroke", card)
    cs.Color = T.border
    cs.Thickness = 1

    local lbl = Instance.new("TextLabel")
    lbl.Parent = card
    lbl.Size = UDim2.new(1, -16, 0, 14)
    lbl.Position = UDim2.new(0, 8, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = T.dim
    lbl.TextSize = 9
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 103

    local val = Instance.new("TextLabel")
    val.Parent = card
    val.Size = UDim2.new(1, -16, 0, 14)
    val.Position = UDim2.new(0, 8, 0, 8)
    val.BackgroundTransparency = 1
    val.Text = dispFn(defVal)
    val.TextColor3 = T.text
    val.TextSize = 9
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.ZIndex = 103

    local descL = Instance.new("TextLabel")
    descL.Parent = card
    descL.Size = UDim2.new(1, -16, 0, 12)
    descL.Position = UDim2.new(0, 8, 0, 22)
    descL.BackgroundTransparency = 1
    descL.Text = desc
    descL.TextColor3 = T.faint
    descL.TextSize = 9
    descL.Font = Enum.Font.Gotham
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.ZIndex = 103

    local track = Instance.new("Frame")
    track.Parent = card
    track.Size = UDim2.new(1, -32, 0, 6)
    track.Position = UDim2.new(0, 16, 0, 46)
    track.BackgroundColor3 = T.panel2
    track.BorderSizePixel = 0
    track.ZIndex = 103
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local trs = Instance.new("UIStroke", track)
    trs.Color = T.border
    trs.Thickness = 1

    local fill = Instance.new("Frame")
    fill.Parent = track
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = T.text
    fill.BorderSizePixel = 0
    fill.ZIndex = 104
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local drag = false

    local function update(input)
        local bp = track.AbsolutePosition.X
        local bs = track.AbsoluteSize.X
        local pos = math.clamp((input.Position.X - bp) / bs, 0, 1)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        applyFn(pos)
        val.Text = dispFn(pos)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            update(i)
        end
    end)
    track.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i)
        end
    end)
end

local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.new(0, 120, 0, 44)
fpsFrame.Position = UDim2.new(0, 8, 0, 8)
fpsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fpsFrame.BackgroundTransparency = 0.35
fpsFrame.BorderSizePixel = 0
fpsFrame.Parent = fpsGui
Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 6)

local fpsText = Instance.new("TextLabel")
fpsText.Size = UDim2.new(1, -12, 0, 18)
fpsText.Position = UDim2.new(0, 6, 0, 4)
fpsText.BackgroundTransparency = 1
fpsText.Text = "FPS: --"
fpsText.TextColor3 = Color3.fromRGB(255, 255, 255)
fpsText.TextSize = 11
fpsText.Font = Enum.Font.GothamBold
fpsText.TextXAlignment = Enum.TextXAlignment.Left
fpsText.Parent = fpsFrame

local pingText = Instance.new("TextLabel")
pingText.Size = UDim2.new(1, -12, 0, 18)
pingText.Position = UDim2.new(0, 6, 0, 22)
pingText.BackgroundTransparency = 1
pingText.Text = "PING: --"
pingText.TextColor3 = Color3.fromRGB(255, 255, 255)
pingText.TextSize = 11
pingText.Font = Enum.Font.GothamBold
pingText.TextXAlignment = Enum.TextXAlignment.Left
pingText.Parent = fpsFrame

local combatLabel = Instance.new("TextLabel")
combatLabel.Size = UDim2.new(0, 120, 0, 18)
combatLabel.Position = UDim2.new(0, 8, 0, 56)
combatLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
combatLabel.BackgroundTransparency = 0.35
combatLabel.BorderSizePixel = 0
combatLabel.Text = "FIGHT: --"
combatLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
combatLabel.TextSize = 11
combatLabel.Font = Enum.Font.GothamBold
combatLabel.TextXAlignment = Enum.TextXAlignment.Center
combatLabel.Parent = fpsGui
Instance.new("UICorner", combatLabel).CornerRadius = UDim.new(0, 6)

local killFeedFrame = Instance.new("Frame")
killFeedFrame.Size = UDim2.new(0, 240, 0, 130)
killFeedFrame.Position = UDim2.new(1, -248, 0, 8)
killFeedFrame.BackgroundTransparency = 1
killFeedFrame.Parent = fpsGui
local kfLayout = Instance.new("UIListLayout", killFeedFrame)
kfLayout.Padding = UDim.new(0, 3)
kfLayout.VerticalAlignment = Enum.VerticalAlignment.Top
kfLayout.SortOrder = Enum.SortOrder.LayoutOrder

local toastFrame = Instance.new("Frame")
toastFrame.Size = UDim2.new(0, 240, 0, 30)
toastFrame.Position = UDim2.new(0.5, -120, 1, -50)
toastFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toastFrame.BackgroundTransparency = 0.2
toastFrame.BorderSizePixel = 0
toastFrame.Visible = false
toastFrame.Parent = gui
Instance.new("UICorner", toastFrame).CornerRadius = UDim.new(0, 6)
local toastStroke = Instance.new("UIStroke", toastFrame)
toastStroke.Color = T.border
toastStroke.Thickness = 1

local toastText = Instance.new("TextLabel")
toastText.Parent = toastFrame
toastText.Size = UDim2.new(1, -12, 1, 0)
toastText.Position = UDim2.new(0, 6, 0, 0)
toastText.BackgroundTransparency = 1
toastText.Text = ""
toastText.TextColor3 = Color3.fromRGB(255, 255, 255)
toastText.TextSize = 12
toastText.Font = Enum.Font.GothamBold
toastText.TextXAlignment = Enum.TextXAlignment.Center

local toastThread = nil
local function toast(msg, color)
    if not cfg.notifications then return end
    toastText.Text = msg
    toastText.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    toastFrame.Visible = true
    toastFrame.BackgroundTransparency = 0.2
    toastStroke.Color = color or T.border
    if toastThread then task.cancel(toastThread) end
    toastThread = task.spawn(function()
        task.wait(1.5)
        toastFrame.Visible = false
    end)
end

local hitSound = Instance.new("Sound")
hitSound.SoundId = DEFAULT_SOUND
hitSound.Volume = 0.5
hitSound.Parent = game:GetService("SoundService")

local function isSuspicious(p)
    if not cfg.suspicious then return false end
    local c = p.Character
    if not c then return false end
    local root = c:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local last = lastVel[p]
    local now = root.Velocity.Magnitude
    lastVel[p] = now
    if last and last > 500 and now > 500 then
        local diff = math.abs(now - last)
        if diff > 200 then return true end
    end
    local lastPos = lastSeen[p]
    if lastPos then
        local d = (root.Position - lastPos).Magnitude
        if d > 200 then
            lastSeen[p] = root.Position
            return true
        end
    end
    lastSeen[p] = root.Position
    return false
end

local orb = Instance.new("TextButton")
orb.Parent = gui
orb.Size = UDim2.new(0, 36, 0, 36)
orb.Position = UDim2.new(0, 14, 0.5, -18)
orb.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
orb.Text = ""
orb.BorderSizePixel = 0
orb.Draggable = true
orb.AutoButtonColor = false
orb.ZIndex = 250
Instance.new("UICorner", orb).CornerRadius = UDim.new(0, 8)
local orbStroke = Instance.new("UIStroke", orb)
orbStroke.Color = T.border
orbStroke.Thickness = 1

local pcLabel = Instance.new("TextLabel")
pcLabel.Parent = orb
pcLabel.Size = UDim2.new(1, 0, 1, 0)
pcLabel.BackgroundTransparency = 1
pcLabel.Text = "PC"
pcLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
pcLabel.TextSize = 15
pcLabel.Font = Enum.Font.GothamBold
pcLabel.ZIndex = 251

local slash = Instance.new("Frame")
slash.Parent = orb
slash.Size = UDim2.new(1, 4, 0, 2)
slash.Position = UDim2.new(0, -2, 0.5, -1)
slash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
slash.BorderSizePixel = 0
slash.Rotation = 45
slash.ZIndex = 252

local win = Instance.new("Frame")
win.Parent = gui
win.Size = UDim2.new(0, 500, 0, 460)
win.Position = UDim2.new(0.5, -250, 0.5, -230)
win.BackgroundColor3 = T.bg
win.BorderSizePixel = 0
win.Draggable = true
win.ClipsDescendants = true
win.Visible = false
win.ZIndex = 100
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 4)
local winStroke = Instance.new("UIStroke", win)
winStroke.Color = T.border
winStroke.Thickness = 1

local tbar = Instance.new("Frame")
tbar.Parent = win
tbar.Size = UDim2.new(1, 0, 0, 26)
tbar.BackgroundColor3 = T.panel
tbar.BorderSizePixel = 0
tbar.ZIndex = 101
Instance.new("UICorner", tbar).CornerRadius = UDim.new(0, 4)

local ttl = Instance.new("TextLabel")
ttl.Parent = tbar
ttl.Size = UDim2.new(1, -60, 1, 0)
ttl.Position = UDim2.new(0, 10, 0, 0)
ttl.BackgroundTransparency = 1
ttl.Text = "PHANTOMCORE"
ttl.TextColor3 = T.text
ttl.TextSize = 12
ttl.Font = Enum.Font.GothamBold
ttl.TextXAlignment = Enum.TextXAlignment.Left
ttl.ZIndex = 102

local cls = Instance.new("TextButton")
cls.Parent = tbar
cls.Size = UDim2.new(0, 20, 0, 20)
cls.Position = UDim2.new(1, -24, 0, 3)
cls.BackgroundColor3 = T.panel2
cls.Text = "X"
cls.TextColor3 = T.text
cls.TextSize = 11
cls.Font = Enum.Font.GothamBold
cls.BorderSizePixel = 0
cls.AutoButtonColor = false
cls.ZIndex = 102
Instance.new("UICorner", cls).CornerRadius = UDim.new(0, 4)

local side = Instance.new("Frame")
side.Parent = win
side.Size = UDim2.new(0, 108, 1, -26)
side.Position = UDim2.new(0, 0, 0, 26)
side.BackgroundColor3 = T.panel
side.BorderSizePixel = 0
side.ZIndex = 101

local sl = Instance.new("Frame")
sl.Parent = side
sl.Size = UDim2.new(0, 1, 1, 0)
sl.Position = UDim2.new(1, -1, 0, 0)
sl.BackgroundColor3 = T.border
sl.BorderSizePixel = 0
sl.ZIndex = 102

local function tabBtn(y, txt)
    local b = Instance.new("TextButton")
    b.Parent = side
    b.Size = UDim2.new(1, -8, 0, 30)
    b.Position = UDim2.new(0, 4, 0, y)
    b.BackgroundColor3 = T.panel2
    b.Text = txt
    b.TextColor3 = T.dim
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 102
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
    local s = Instance.new("UIStroke", b)
    s.Color = T.border
    s.Thickness = 1
    return b
end

local tabRage = tabBtn(6, "RAGE")
local tabCombat = tabBtn(40, "COMBAT")
local tabVisual = tabBtn(74, "VISUAL")
local tabSettings = tabBtn(108, "SETTINGS")

local content = Instance.new("Frame")
content.Parent = win
content.Size = UDim2.new(1, -108, 1, -26)
content.Position = UDim2.new(0, 108, 0, 26)
content.BackgroundTransparency = 1
content.ZIndex = 101

local function newPage()
    local p = Instance.new("Frame")
    p.Parent = content
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.ZIndex = 101
    return p
end

local pgRage = newPage()
local pgCombat = newPage()
local pgVisual = newPage()
local pgSettings = newPage()

local tabList = {
    { btn = tabRage, pg = pgRage },
    { btn = tabCombat, pg = pgCombat },
    { btn = tabVisual, pg = pgVisual },
    { btn = tabSettings, pg = pgSettings },
}

local function setTab(target)
    for _, pair in ipairs(tabList) do
        if pair.btn == target then
            pair.btn.BackgroundColor3 = T.accent
            pair.btn.TextColor3 = T.bg
            pair.pg.Visible = true
        else
            pair.btn.BackgroundColor3 = T.panel2
            pair.btn.TextColor3 = T.dim
            pair.pg.Visible = false
        end
    end
end

tabRage.MouseButton1Click:Connect(function() setTab(tabRage) end)
tabCombat.MouseButton1Click:Connect(function() setTab(tabCombat) end)
tabVisual.MouseButton1Click:Connect(function() setTab(tabVisual) end)
tabSettings.MouseButton1Click:Connect(function() setTab(tabSettings) end)

local leftCol = Instance.new("Frame")
leftCol.Parent = pgRage
leftCol.Size = UDim2.new(0.5, -8, 1, -8)
leftCol.Position = UDim2.new(0, 4, 0, 4)
leftCol.BackgroundTransparency = 1
leftCol.ZIndex = 102

local rightCol = Instance.new("Frame")
rightCol.Parent = pgRage
rightCol.Size = UDim2.new(0.5, -8, 1, -8)
rightCol.Position = UDim2.new(0.5, 4, 0, 4)
rightCol.BackgroundTransparency = 1
rightCol.ZIndex = 102

mkHeader(leftCol, 0, "PRESETS")
local presetRow = Instance.new("Frame")
presetRow.Parent = leftCol
presetRow.Size = UDim2.new(1, -4, 0, 26)
presetRow.Position = UDim2.new(0, 2, 0, 24)
presetRow.BackgroundTransparency = 1
local presetLayout = Instance.new("UIListLayout", presetRow)
presetLayout.FillDirection = Enum.FillDirection.Horizontal
presetLayout.Padding = UDim.new(0, 3)
presetLayout.SortOrder = Enum.SortOrder.LayoutOrder

local btnAll = mkBtn(leftCol, 56, 0.5, 0, "ALL", true)
local btnSel = mkBtn(leftCol, 56, 0.5, 0.5, "SELECT", false)
local btnEnable = mkBtn(leftCol, 86, 1, 0, "ENABLE TELEPORT", false)
local btnCycle = mkBtn(leftCol, 116, 1, 0, "CYCLE NOW", false)

local statCard = Instance.new("Frame")
statCard.Parent = leftCol
statCard.Size = UDim2.new(1, -4, 0, 40)
statCard.Position = UDim2.new(0, 2, 0, 148)
statCard.BackgroundColor3 = T.panel
statCard.BorderSizePixel = 0
statCard.ZIndex = 101
Instance.new("UICorner", statCard).CornerRadius = UDim.new(0, 3)
local scs = Instance.new("UIStroke", statCard)
scs.Color = T.border
scs.Thickness = 1

local statDot = Instance.new("Frame")
statDot.Parent = statCard
statDot.Size = UDim2.new(0, 8, 0, 8)
statDot.Position = UDim2.new(0, 10, 0, 10)
statDot.BackgroundColor3 = T.text
statDot.BorderSizePixel = 0
statDot.ZIndex = 103
Instance.new("UICorner", statDot).CornerRadius = UDim.new(1, 0)

local statLbl = Instance.new("TextLabel")
statLbl.Parent = statCard
statLbl.Size = UDim2.new(1, -30, 0, 14)
statLbl.Position = UDim2.new(0, 24, 0, 6)
statLbl.BackgroundTransparency = 1
statLbl.Text = "DISABLED"
statLbl.TextColor3 = T.text
statLbl.TextSize = 10
statLbl.Font = Enum.Font.GothamBold
statLbl.TextXAlignment = Enum.TextXAlignment.Left
statLbl.ZIndex = 103

local statTgt = Instance.new("TextLabel")
statTgt.Parent = statCard
statTgt.Size = UDim2.new(1, -20, 0, 14)
statTgt.Position = UDim2.new(0, 10, 0, 22)
statTgt.BackgroundTransparency = 1
statTgt.Text = "no target"
statTgt.TextColor3 = T.faint
statTgt.TextSize = 9
statTgt.Font = Enum.Font.Gotham
statTgt.TextXAlignment = Enum.TextXAlignment.Left
statTgt.ZIndex = 103

local spdLbl = Instance.new("TextLabel")
spdLbl.Parent = leftCol
spdLbl.Size = UDim2.new(0.5, 0, 0, 14)
spdLbl.Position = UDim2.new(0, 4, 0, 196)
spdLbl.BackgroundTransparency = 1
spdLbl.Text = "SPEED"
spdLbl.TextColor3 = T.dim
spdLbl.TextSize = 9
spdLbl.Font = Enum.Font.GothamBold
spdLbl.TextXAlignment = Enum.TextXAlignment.Left
spdLbl.ZIndex = 102

local spdVal = Instance.new("TextLabel")
spdVal.Parent = leftCol
spdVal.Size = UDim2.new(0.5, -6, 0, 14)
spdVal.Position = UDim2.new(0.5, 2, 0, 196)
spdVal.BackgroundTransparency = 1
spdVal.Text = "0.5s"
spdVal.TextColor3 = T.text
spdVal.TextSize = 9
spdVal.Font = Enum.Font.GothamBold
spdVal.TextXAlignment = Enum.TextXAlignment.Right
spdVal.ZIndex = 102

local spdTrack = Instance.new("Frame")
spdTrack.Parent = leftCol
spdTrack.Size = UDim2.new(1, -4, 0, 6)
spdTrack.Position = UDim2.new(0, 2, 0, 214)
spdTrack.BackgroundColor3 = T.panel2
spdTrack.BorderSizePixel = 0
spdTrack.ZIndex = 102
Instance.new("UICorner", spdTrack).CornerRadius = UDim.new(1, 0)
local sps = Instance.new("UIStroke", spdTrack)
sps.Color = T.border
sps.Thickness = 1

local spdFill = Instance.new("Frame")
spdFill.Parent = spdTrack
spdFill.Size = UDim2.new(0.2, 0, 1, 0)
spdFill.BackgroundColor3 = T.text
spdFill.BorderSizePixel = 0
spdFill.ZIndex = 103
Instance.new("UICorner", spdFill).CornerRadius = UDim.new(1, 0)

local spdDrag = false
local function updSpeed(input)
    local bp = spdTrack.AbsolutePosition.X
    local bs = spdTrack.AbsoluteSize.X
    local pos = math.clamp((input.Position.X - bp) / bs, 0, 1)
    local v = math.round((0.1 + pos * 1.9) * 10) / 10
    cfg.teleDelay = v
    spdFill.Size = UDim2.new(pos, 0, 1, 0)
    spdVal.Text = string.format("%.1fs", v)
end
spdTrack.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        spdDrag = true; updSpeed(i)
    end
end)
spdTrack.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        spdDrag = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if spdDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        updSpeed(i)
    end
end)

local voidHead = Instance.new("Frame")
voidHead.Parent = leftCol
voidHead.Size = UDim2.new(1, -4, 0, 22)
voidHead.Position = UDim2.new(0, 2, 0, 236)
voidHead.BackgroundColor3 = T.panel
voidHead.BorderSizePixel = 0
voidHead.ZIndex = 101
Instance.new("UICorner", voidHead).CornerRadius = UDim.new(0, 3)
local vhs = Instance.new("UIStroke", voidHead)
vhs.Color = T.border
vhs.Thickness = 1

local vhTxt = Instance.new("TextLabel")
vhTxt.Parent = voidHead
vhTxt.Size = UDim2.new(0.6, 0, 1, 0)
vhTxt.Position = UDim2.new(0, 8, 0, 0)
vhTxt.BackgroundTransparency = 1
vhTxt.Text = "VOID SPAM"
vhTxt.TextColor3 = T.dim
vhTxt.TextSize = 10
vhTxt.Font = Enum.Font.GothamBold
vhTxt.TextXAlignment = Enum.TextXAlignment.Left
vhTxt.ZIndex = 102

local vStatus = Instance.new("TextLabel")
vStatus.Parent = voidHead
vStatus.Size = UDim2.new(0.4, -8, 1, 0)
vStatus.Position = UDim2.new(0.6, 0, 0, 0)
vStatus.BackgroundTransparency = 1
vStatus.Text = "IDLE"
vStatus.TextColor3 = T.faint
vStatus.TextSize = 10
vStatus.Font = Enum.Font.GothamBold
vStatus.TextXAlignment = Enum.TextXAlignment.Right
vStatus.ZIndex = 102

local btnVoid = mkBtn(leftCol, 262, 1, 0, "ENABLE VOID", false)

local cHead = Instance.new("Frame")
cHead.Parent = leftCol
cHead.Size = UDim2.new(1, -4, 0, 22)
cHead.Position = UDim2.new(0, 2, 0, 296)
cHead.BackgroundColor3 = T.panel
cHead.BorderSizePixel = 0
cHead.ZIndex = 101
Instance.new("UICorner", cHead).CornerRadius = UDim.new(0, 3)
local chs = Instance.new("UIStroke", cHead)
chs.Color = T.border
chs.Thickness = 1

local chTxt = Instance.new("TextLabel")
chTxt.Parent = cHead
chTxt.Size = UDim2.new(1, -16, 1, 0)
chTxt.Position = UDim2.new(0, 8, 0, 0)
chTxt.BackgroundTransparency = 1
chTxt.Text = "COMBO STATUS"
chTxt.TextColor3 = T.dim
chTxt.TextSize = 10
chTxt.Font = Enum.Font.GothamBold
chTxt.TextXAlignment = Enum.TextXAlignment.Left
chTxt.ZIndex = 102

local combStat = Instance.new("TextLabel")
combStat.Parent = leftCol
combStat.Size = UDim2.new(1, -4, 0, 26)
combStat.Position = UDim2.new(0, 2, 0, 320)
combStat.BackgroundColor3 = T.panel
combStat.BorderSizePixel = 0
combStat.Text = "both off"
combStat.TextColor3 = T.faint
combStat.TextSize = 10
combStat.Font = Enum.Font.Gotham
combStat.ZIndex = 102
Instance.new("UICorner", combStat).CornerRadius = UDim.new(0, 3)
local cms = Instance.new("UIStroke", combStat)
cms.Color = T.border
cms.Thickness = 1

local lHead = Instance.new("Frame")
lHead.Parent = rightCol
lHead.Size = UDim2.new(1, -4, 0, 22)
lHead.Position = UDim2.new(0, 2, 0, 0)
lHead.BackgroundColor3 = T.panel
lHead.BorderSizePixel = 0
lHead.ZIndex = 102
Instance.new("UICorner", lHead).CornerRadius = UDim.new(0, 3)
local lhs = Instance.new("UIStroke", lHead)
lhs.Color = T.border
lhs.Thickness = 1

local lTxt = Instance.new("TextLabel")
lTxt.Parent = lHead
lTxt.Size = UDim2.new(0.6, 0, 1, 0)
lTxt.Position = UDim2.new(0, 8, 0, 0)
lTxt.BackgroundTransparency = 1
lTxt.Text = "PLAYERS"
lTxt.TextColor3 = T.dim
lTxt.TextSize = 10
lTxt.Font = Enum.Font.GothamBold
lTxt.TextXAlignment = Enum.TextXAlignment.Left
lTxt.ZIndex = 103

local pCount = Instance.new("TextLabel")
pCount.Parent = lHead
pCount.Size = UDim2.new(0.4, -8, 1, 0)
pCount.Position = UDim2.new(0.6, 0, 0, 0)
pCount.BackgroundTransparency = 1
pCount.Text = "0"
pCount.TextColor3 = T.text
pCount.TextSize = 10
pCount.Font = Enum.Font.GothamBold
pCount.TextXAlignment = Enum.TextXAlignment.Right
pCount.ZIndex = 103

local listBox = Instance.new("ScrollingFrame")
listBox.Parent = rightCol
listBox.Size = UDim2.new(1, -4, 1, -26)
listBox.Position = UDim2.new(0, 2, 0, 26)
listBox.BackgroundColor3 = T.panel
listBox.BorderSizePixel = 0
listBox.ScrollBarThickness = 3
listBox.ScrollBarImageColor3 = T.border
listBox.CanvasSize = UDim2.new(0, 0, 0, 0)
listBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
listBox.ZIndex = 102
Instance.new("UICorner", listBox).CornerRadius = UDim.new(0, 3)
local lbs = Instance.new("UIStroke", listBox)
lbs.Color = T.border
lbs.Thickness = 1
local lbp = Instance.new("UIPadding", listBox)
lbp.PaddingTop = UDim.new(0, 3)
lbp.PaddingBottom = UDim.new(0, 3)
lbp.PaddingLeft = UDim.new(0, 3)
lbp.PaddingRight = UDim.new(0, 3)
local lbl2 = Instance.new("UIListLayout", listBox)
lbl2.Padding = UDim.new(0, 3)

local combatScroll = Instance.new("ScrollingFrame")
combatScroll.Parent = pgCombat
combatScroll.Size = UDim2.new(1, 0, 1, 0)
combatScroll.BackgroundTransparency = 1
combatScroll.BorderSizePixel = 0
combatScroll.ScrollBarThickness = 3
combatScroll.ScrollBarImageColor3 = T.border
combatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
combatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
combatScroll.ZIndex = 102

mkHeader(combatScroll, 4, "HIT SOUND")
local btnHitSound = mkBtn(combatScroll, 32, 1, 0, "HIT SOUND: OFF", false)

local soundInput = Instance.new("TextBox")
soundInput.Parent = combatScroll
soundInput.Size = UDim2.new(1, -8, 0, 26)
soundInput.Position = UDim2.new(0, 4, 0, 64)
soundInput.BackgroundColor3 = T.panel2
soundInput.BorderSizePixel = 0
soundInput.Text = ""
soundInput.PlaceholderText = "paste sound id here"
soundInput.PlaceholderColor3 = T.faint
soundInput.TextColor3 = T.text
soundInput.Font = Enum.Font.Gotham
soundInput.TextSize = 11
soundInput.ClearTextOnFocus = false
soundInput.ZIndex = 102
Instance.new("UICorner", soundInput).CornerRadius = UDim.new(0, 3)
local siStroke = Instance.new("UIStroke", soundInput)
siStroke.Color = T.border
siStroke.Thickness = 1

soundInput.FocusLost:Connect(function()
    local txt = soundInput.Text
    if txt == "" then
        hitSound.SoundId = DEFAULT_SOUND
        cfg.soundId = ""
        return
    end
    local id = txt:match("%d+")
    if id then
        hitSound.SoundId = "rbxassetid://" .. id
        cfg.soundId = id
    end
end)

mkHeader(combatScroll, 100, "AUTO MELEE")
local btnAutoMelee = mkBtn(combatScroll, 128, 1, 0, "AUTO MELEE: OFF", false)

mkHeader(combatScroll, 162, "MOVEMENT")
local btnNoclip = mkBtn(combatScroll, 190, 1, 0, "NOCLIP: OFF", false)
local btnFly = mkBtn(combatScroll, 220, 1, 0, "FLY: OFF", false)
local btnAntiAim = mkBtn(combatScroll, 250, 1, 0, "ANTI-AIM: OFF", false)

mkSlider(combatScroll, 284, "FLY SPEED", "studs per second", 0.3,
    function(pos)
        local v = math.floor(20 + pos * 280 + 0.5)
        cfg.flySpeed = v
        return tostring(v)
    end,
    function(pos) end
)

mkSlider(combatScroll, 362, "ANTI-AIM DEPTH", "how far under the map", 0.3,
    function(pos)
        local v = math.floor(10 + pos * 90 + 0.5)
        cfg.antiAimDepth = v
        return tostring(v)
    end,
    function(pos) end
)

mkHeader(combatScroll, 440, "VOIDSPAM SETTINGS")

mkSlider(combatScroll, 468, "VOIDSPAM TELEPORT", "pin time on target head (0.1-0.5s)", 0.5,
    function(pos)
        local v = math.round((0.1 + pos * 0.4) * 10) / 10
        v = math.clamp(v, 0.1, 0.5)
        cfg.holdTime = v
        return string.format("%.1fs", v)
    end,
    function(pos) end
)

mkSlider(combatScroll, 546, "VOIDSPAM DISTANCE", "how far the fling sends you", 0.5,
    function(pos)
        local v = math.floor(1000 + pos * 9999000 + 0.5)
        v = math.clamp(v, 1000, 10000000)
        cfg.voidForce = v
        return tostring(v)
    end,
    function(pos) end
)

mkHeader(combatScroll, 624, "ATTACK")
local btnRapidFire = mkBtn(combatScroll, 652, 1, 0, "RAPID FIRE: OFF", false)
local btnRapidAttack = mkBtn(combatScroll, 682, 1, 0, "RAPID ATTACK: OFF", false)

mkHeader(combatScroll, 718, "BACKGLUE")
local btnBg = mkBtn(combatScroll, 746, 1, 0, "BACKGLUE: OFF", false)

local bgStatus = Instance.new("TextLabel")
bgStatus.Parent = combatScroll
bgStatus.Size = UDim2.new(1, -8, 0, 22)
bgStatus.Position = UDim2.new(0, 4, 0, 778)
bgStatus.BackgroundColor3 = T.panel
bgStatus.BorderSizePixel = 0
bgStatus.Text = "idle"
bgStatus.TextColor3 = T.faint
bgStatus.TextSize = 10
bgStatus.Font = Enum.Font.Gotham
bgStatus.ZIndex = 103
Instance.new("UICorner", bgStatus).CornerRadius = UDim.new(0, 3)
local bgs = Instance.new("UIStroke", bgStatus)
bgs.Color = T.border
bgs.Thickness = 1

local btnBgCam = mkBtn(combatScroll, 808, 1, 0, "GLUE LOCK CAMERA: OFF", false)
local btnBgTeam = mkBtn(combatScroll, 838, 1, 0, "GLUE IGNORE TEAM: OFF", false)

local function bgPickTarget()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or workspace.CurrentCamera.CFrame.Position
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            if not (cfg.bgIgnoreTeam and p.Team == LP.Team) then
                local c = p.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local d = (hrp.Position - origin).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = hrp
                    end
                end
            end
        end
    end
    return best
end

local function bgStart()
    if bgConn then return end
    bgConn = RS.PreSimulation:Connect(function()
        if not cfg.bgEnabled then return end

        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not myRoot then
            bgStatus.Text = "no character"
            return
        end

        if not bgLockedTarget or not bgLockedTarget.Parent then
            bgLockedTarget = bgPickTarget()
        else
            local tHum = bgLockedTarget.Parent:FindFirstChildOfClass("Humanoid")
            if not tHum or tHum.Health <= 0 then
                bgLockedTarget = bgPickTarget()
            end
        end

        local targetRoot = bgLockedTarget
        if not targetRoot then
            bgStatus.Text = "no target"
            return
        end

        local look = targetRoot.CFrame.LookVector
        local pos = targetRoot.Position - (look * cfg.bgOffsetBack) + Vector3.new(0, cfg.bgOffsetUp, 0)
        myRoot.CFrame = CFrame.new(pos, targetRoot.Position)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.AssemblyAngularVelocity = Vector3.zero

        if cfg.bgLockCamera then
            workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, targetRoot.Position)
        end

        bgStatus.Text = "glued: " .. (targetRoot.Parent and targetRoot.Parent.Name or "?")
    end)
end

local function bgStop()
    if bgConn then bgConn:Disconnect() bgConn = nil end
    bgLockedTarget = nil
    bgStatus.Text = "idle"
end

btnBg.MouseButton1Click:Connect(function()
    cfg.bgEnabled = not cfg.bgEnabled
    if cfg.bgEnabled then
        btnBg.BackgroundColor3 = T.accent
        btnBg.TextColor3 = T.bg
        btnBg.Text = "BACKGLUE: ON"
        bgStart()
        toast("BackGlue ON", T.ok)
    else
        btnBg.BackgroundColor3 = T.panel2
        btnBg.TextColor3 = T.text
        btnBg.Text = "BACKGLUE: OFF"
        bgStop()
        toast("BackGlue OFF", T.warn)
    end
end)

btnBgCam.MouseButton1Click:Connect(function()
    cfg.bgLockCamera = not cfg.bgLockCamera
    if cfg.bgLockCamera then
        btnBgCam.BackgroundColor3 = T.accent
        btnBgCam.TextColor3 = T.bg
        btnBgCam.Text = "GLUE LOCK CAMERA: ON"
    else
        btnBgCam.BackgroundColor3 = T.panel2
        btnBgCam.TextColor3 = T.text
        btnBgCam.Text = "GLUE LOCK CAMERA: OFF"
    end
end)

btnBgTeam.MouseButton1Click:Connect(function()
    cfg.bgIgnoreTeam = not cfg.bgIgnoreTeam
    if cfg.bgIgnoreTeam then
        btnBgTeam.BackgroundColor3 = T.accent
        btnBgTeam.TextColor3 = T.bg
        btnBgTeam.Text = "GLUE IGNORE TEAM: ON"
    else
        btnBgTeam.BackgroundColor3 = T.panel2
        btnBgTeam.TextColor3 = T.text
        btnBgTeam.Text = "GLUE IGNORE TEAM: OFF"
    end
end)

mkHeader(pgVisual, 4, "ESP")
local btnEsp = mkBtn(pgVisual, 32, 1, 0, "HIGHLIGHT ESP: OFF", false)
local btnColor = mkBtn(pgVisual, 62, 1, 0, "COLOR: WHITE", false)
local btnAura = mkBtn(pgVisual, 92, 1, 0, "AURA: OFF", false)
local btnAuraColor = mkBtn(pgVisual, 122, 1, 0, "AURA COLOR: WHITE", false)

mkHeader(pgVisual, 158, "LIGHTING")
local btnFullbright = mkBtn(pgVisual, 186, 1, 0, "FULLBRIGHT: OFF", false)

mkHeader(pgVisual, 222, "CAMERA")
local btnCamFollow = mkBtn(pgVisual, 250, 1, 0, "CAMERA FOLLOW: OFF", false)

mkHeader(pgVisual, 286, "HUD")
local btnKillFeed = mkBtn(pgVisual, 314, 1, 0, "KILL FEED: ON", true)
local btnCombatTimer = mkBtn(pgVisual, 344, 1, 0, "COMBAT TIMER: ON", true)
local btnSuspicious = mkBtn(pgVisual, 374, 1, 0, "THREAT DETECTION: ON", true)
local btnVoidTrack = mkBtn(pgVisual, 404, 1, 0, "VOID TRACKER: ON", true)
local btnNotifications = mkBtn(pgVisual, 434, 1, 0, "NOTIFICATIONS: ON", true)

mkHeader(pgSettings, 4, "CONFIG")
local configInput = Instance.new("TextBox")
configInput.Parent = pgSettings
configInput.Size = UDim2.new(1, -8, 0, 26)
configInput.Position = UDim2.new(0, 4, 0, 30)
configInput.BackgroundColor3 = T.panel2
configInput.BorderSizePixel = 0
configInput.Text = ""
configInput.PlaceholderText = "config name"
configInput.PlaceholderColor3 = T.faint
configInput.TextColor3 = T.text
configInput.Font = Enum.Font.Gotham
configInput.TextSize = 11
configInput.ClearTextOnFocus = false
configInput.ZIndex = 102
Instance.new("UICorner", configInput).CornerRadius = UDim.new(0, 3)
local ciStroke = Instance.new("UIStroke", configInput)
ciStroke.Color = T.border
ciStroke.Thickness = 1

local btnCfgSave = mkBtn(pgSettings, 62, 0.5, 0, "SAVE", false)
local btnCfgRefresh = mkBtn(pgSettings, 62, 0.5, 0.5, "REFRESH", false)

local configList = Instance.new("ScrollingFrame")
configList.Parent = pgSettings
configList.Size = UDim2.new(1, -8, 0, 90)
configList.Position = UDim2.new(0, 4, 0, 96)
configList.BackgroundColor3 = T.panel2
configList.BorderSizePixel = 0
configList.ScrollBarThickness = 3
configList.ScrollBarImageColor3 = T.border
configList.CanvasSize = UDim2.new(0, 0, 0, 0)
configList.AutomaticCanvasSize = Enum.AutomaticSize.Y
configList.ZIndex = 102
Instance.new("UICorner", configList).CornerRadius = UDim.new(0, 3)
local clStroke = Instance.new("UIStroke", configList)
clStroke.Color = T.border
clStroke.Thickness = 1
local clPad = Instance.new("UIPadding", configList)
clPad.PaddingTop = UDim.new(0, 3)
clPad.PaddingBottom = UDim.new(0, 3)
clPad.PaddingLeft = UDim.new(0, 3)
clPad.PaddingRight = UDim.new(0, 3)
local clLayout = Instance.new("UIListLayout", configList)
clLayout.Padding = UDim.new(0, 3)

local btnCfgLoad = mkBtn(pgSettings, 194, 0.5, 0, "LOAD", false)
local btnCfgAuto = mkBtn(pgSettings, 194, 0.5, 0.5, "AUTO: OFF", false)

mkHeader(pgSettings, 232, "KEYBINDS")
local btnKeyTele = mkBtn(pgSettings, 260, 0.5, 0, "TELE: L", false)
local btnKeyVoid = mkBtn(pgSettings, 260, 0.5, 0.5, "VOID: V", false)
local btnKeyFly = mkBtn(pgSettings, 290, 0.5, 0, "FLY: F", false)

mkHeader(pgSettings, 326, "OVERLAY")
local btnFps = mkBtn(pgSettings, 354, 1, 0, "FPS OVERLAY: ON", true)

local function refreshConfigList()
    for _, c in ipairs(configList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    cfg.activeConfig = ""
    if not listfiles or not isfolder then return end
    if not isfolder(CONFIG_DIR) then
        pcall(function() makefolder(CONFIG_DIR) end)
    end
    local ok, files = pcall(function() return listfiles(CONFIG_DIR) end)
    if not ok or not files then return end
    for _, path in ipairs(files) do
        local name = path:match("([^/\\]+)%.txt$")
        if name then
            local b = Instance.new("TextButton")
            b.Parent = configList
            b.Size = UDim2.new(1, 0, 0, 22)
            b.BackgroundColor3 = T.panel2
            b.Text = name
            b.TextColor3 = T.text
            b.TextSize = 10
            b.Font = Enum.Font.Gotham
            b.BorderSizePixel = 0
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.AutoButtonColor = false
            b.ZIndex = 103
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
            local s = Instance.new("UIStroke", b)
            s.Color = T.border
            s.Thickness = 1
            local pad = Instance.new("UIPadding", b)
            pad.PaddingLeft = UDim.new(0, 6)
            b.MouseButton1Click:Connect(function()
                cfg.activeConfig = name
                for _, other in ipairs(configList:GetChildren()) do
                    if other:IsA("TextButton") then
                        other.BackgroundColor3 = T.panel2
                        other.TextColor3 = T.text
                    end
                end
                b.BackgroundColor3 = T.accent
                b.TextColor3 = T.bg
            end)
        end
    end
end

local function refreshList()
    for _, c in ipairs(listBox:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    refreshPlayers()
    pCount.Text = tostring(#players)
    for _, p in ipairs(players) do
        local b = Instance.new("TextButton")
        b.Parent = listBox
        b.Size = UDim2.new(1, 0, 0, 24)
        b.BackgroundColor3 = T.panel2
        b.Text = " " .. p.Name
        b.TextColor3 = T.text
        b.TextSize = 10
        b.Font = Enum.Font.Gotham
        b.BorderSizePixel = 0
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.AutoButtonColor = false
        b.ZIndex = 103
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        local s = Instance.new("UIStroke", b)
        s.Color = T.border
        s.Thickness = 1
        b.MouseButton1Click:Connect(function()
            cfg.selected = p
            cfg.useAll = false
            btnAll.BackgroundColor3 = T.panel2
            btnAll.TextColor3 = T.text
            btnSel.BackgroundColor3 = T.accent
            btnSel.TextColor3 = T.bg
            btnSel.Text = p.Name:sub(1, 10)
        end)
    end
end

local function updateCombo()
    if cfg.teleEnabled and cfg.voidEnabled then
        combStat.Text = string.format("pin %.1fs @ nearest head", cfg.holdTime)
        combStat.TextColor3 = T.text
    elseif cfg.teleEnabled then
        combStat.Text = "teleport only"
        combStat.TextColor3 = T.faint
    elseif cfg.voidEnabled then
        combStat.Text = "void only"
        combStat.TextColor3 = T.faint
    else
        combStat.Text = "both off"
        combStat.TextColor3 = T.faint
    end
end

local function clearHold()
    cfg.holding = false
    cfg.holdTarget = nil
end

local function startCombo()
    if comboThread then return end
    comboThread = task.spawn(function()
        while cfg.teleEnabled and cfg.voidEnabled do
            local near = nearestPlayer()
            if near then
                cfg.holding = true
                cfg.holdTarget = near
                if teleportTo(near) then
                    statTgt.Text = "-> " .. near.Name
                end
                task.wait(cfg.holdTime)
                clearHold()
            end
            task.wait(0.5)
        end
        clearHold()
        comboThread = nil
    end)
end

local function setTele(state)
    cfg.teleEnabled = state
    if state then
        cfg.useAll = true
        cfg.selected = nil
        refreshPlayers()
        playerIndex = 1
        lastTele = tick()
        lastCycle = tick()
        btnEnable.BackgroundColor3 = T.accent
        btnEnable.TextColor3 = T.bg
        btnEnable.Text = "DISABLE TELEPORT"
        statLbl.Text = "ENABLED"
        statDot.BackgroundColor3 = T.text
        btnAll.BackgroundColor3 = T.accent
        btnAll.TextColor3 = T.bg
        btnSel.BackgroundColor3 = T.panel2
        btnSel.TextColor3 = T.text
        btnSel.Text = "SELECT"
        refreshList()
        if cfg.voidEnabled then startCombo() end
    else
        clearHold()
        btnEnable.BackgroundColor3 = T.panel2
        btnEnable.TextColor3 = T.text
        btnEnable.Text = "ENABLE TELEPORT"
        statLbl.Text = "DISABLED"
        statDot.BackgroundColor3 = T.text
        statTgt.Text = "no target"
    end
    updateCombo()
end

local function applyVoid()
    local r = getRoot()
    if not r then return end
    if cfg.holding and cfg.holdTarget then
        local tc = cfg.holdTarget.Character
        local th = tc and tc:FindFirstChild("Head")
        if th then
            r.CFrame = CFrame.new(th.Position + Vector3.new(0, 1, 0))
            r.Velocity = Vector3.new(0, 0, 0)
            r.RotVelocity = Vector3.new(0, 0, 0)
            return
        else
            clearHold()
        end
    end
    local f = cfg.voidForce
    if f < 1 then f = 1 end
    local function rs()
        local m = rng:NextNumber(f * 0.7, f)
        if rng:NextInteger(0, 1) == 0 then return -m end
        return m
    end
    r.Velocity = Vector3.new(rs(), rng:NextNumber(f * 0.7, f), rs())
    r.RotVelocity = Vector3.new(
        rng:NextNumber(-10000, 10000),
        rng:NextNumber(-10000, 10000),
        rng:NextNumber(-10000, 10000)
    )
end

local function setVoid(state)
    cfg.voidEnabled = state
    if state then
        btnVoid.BackgroundColor3 = T.accent
        btnVoid.TextColor3 = T.bg
        btnVoid.Text = "DISABLE VOID"
        vStatus.Text = "ACTIVE"
        vStatus.TextColor3 = T.text
        voidThread = task.spawn(function()
            while cfg.voidEnabled do
                applyVoid()
                task.wait(cfg.voidInterval)
            end
        end)
        if cfg.teleEnabled then startCombo() end
    else
        clearHold()
        btnVoid.BackgroundColor3 = T.panel2
        btnVoid.TextColor3 = T.text
        btnVoid.Text = "ENABLE VOID"
        vStatus.Text = "IDLE"
        vStatus.TextColor3 = T.faint
        voidThread = nil
    end
    updateCombo()
end

local function isMelee(tool)
    local name = string.lower(tool.Name)
    for _, kw in ipairs(meleeKeywords) do
        if string.find(name, kw, 1, true) then return true end
    end
    return false
end

local function findMelee()
    local char = LP.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and isMelee(c) then return c, true end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") and isMelee(c) then return c, false end
        end
    end
    return nil
end

local function startAutoMelee()
    if autoMeleeThread then return end
    autoMeleeThread = task.spawn(function()
        while cfg.autoMelee do
            local tool, equipped = findMelee()
            if tool then
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum and not equipped then
                    pcall(function() hum:EquipTool(tool) end)
                end
            end
            task.wait(0.3)
        end
        autoMeleeThread = nil
    end)
end

local function stopAutoMelee()
    cfg.autoMelee = false
    autoMeleeThread = nil
end

local function startRapidFire()
    if rapidFireThread then return end
    rapidFireThread = task.spawn(function()
        while cfg.rapidFire do
            if mouseDown then
                local char = LP.Character
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool then
                        pcall(function() tool:Activate() end)
                    end
                end
            end
            task.wait(0.02)
        end
        rapidFireThread = nil
    end)
end

local function setRapidFire(state)
    cfg.rapidFire = state
    if state then
        btnRapidFire.BackgroundColor3 = T.accent
        btnRapidFire.TextColor3 = T.bg
        btnRapidFire.Text = "RAPID FIRE: ON"
        startRapidFire()
        toast("Rapid fire ON", T.ok)
    else
        btnRapidFire.BackgroundColor3 = T.panel2
        btnRapidFire.TextColor3 = T.text
        btnRapidFire.Text = "RAPID FIRE: OFF"
    end
end

local rapidAttackCooldownProps = {
    "AttackCooldown",
    "attackCooldown",
    "Cooldown",
    "cooldown",
    "FireRate",
    "fireRate",
    "ReloadTime",
    "reloadTime",
    "SwingCooldown",
    "swingCooldown",
    "HitCooldown",
    "hitCooldown",
    "Debounce",
    "debounce",
    "AttackDelay",
    "attackDelay",
    "UseDelay",
    "useDelay",
    "NextAttack",
    "nextAttack",
}

local function stripCooldown(inst)
    if not inst then return end
    if inst:IsA("ValueBase") then
        pcall(function()
            if typeof(inst.Value) == "number" and inst.Value > 0 then
                inst.Value = 0
            end
        end)
    end
    for _, prop in ipairs(rapidAttackCooldownProps) do
        pcall(function()
            local v = inst[prop]
            if typeof(v) == "number" and v > 0 then
                inst[prop] = 0
            end
        end)
    end
end

local function rapidAttackScan(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        stripCooldown(d)
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            stripCooldown(tool)
            for _, d in ipairs(tool:GetDescendants()) do
                stripCooldown(d)
            end
        end
    end
end

local function hookToolRapidAttack(tool)
    if not tool:IsA("Tool") then return end
    stripCooldown(tool)
    for _, d in ipairs(tool:GetDescendants()) do
        stripCooldown(d)
    end
    if tool:FindFirstChild("Cooldown") and not tool:FindFirstChild("Cooldown").__pcHooked then
        local cd = tool:FindFirstChild("Cooldown")
        if cd:IsA("NumberValue") or cd:IsA("IntValue") then
            cd.__pcHooked = true
            cd.Changed:Connect(function()
                if cfg.rapidAttack and cd.Value > 0 then
                    cd.Value = 0
                end
            end)
        end
    end
end

local function startRapidAttack()
    if rapidAttackConn then return end
    rapidAttackConn = RS.Heartbeat:Connect(function()
        if not cfg.rapidAttack then return end
        local char = LP.Character
        if not char then return end
        rapidAttackScan(char)
    end)
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then hookToolRapidAttack(t) end
        end
    end
end

local function setRapidAttack(state)
    cfg.rapidAttack = state
    if state then
        btnRapidAttack.BackgroundColor3 = T.accent
        btnRapidAttack.TextColor3 = T.bg
        btnRapidAttack.Text = "RAPID ATTACK: ON"
        startRapidAttack()
        toast("Rapid attack ON", T.ok)
    else
        btnRapidAttack.BackgroundColor3 = T.panel2
        btnRapidAttack.TextColor3 = T.text
        btnRapidAttack.Text = "RAPID ATTACK: OFF"
        if rapidAttackConn then
            rapidAttackConn:Disconnect()
            rapidAttackConn = nil
        end
    end
end

local function startFly()
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBG.P = 9e4
    flyBG.CFrame = root.CFrame
    flyBG.Parent = root
    if flyConn then flyConn:Disconnect() end
    flyConn = RS.RenderStepped:Connect(function()
        if not cfg.flyEnabled then return end
        local c = LP.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r or not flyBV or not flyBG then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then
            flyBV.Velocity = dir.Unit * cfg.flySpeed
        else
            flyBV.Velocity = Vector3.zero
        end
        flyBG.CFrame = cam.CFrame
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
end

local function setFly(state)
    cfg.flyEnabled = state
    if state then
        btnFly.BackgroundColor3 = T.accent
        btnFly.TextColor3 = T.bg
        btnFly.Text = "FLY: ON"
        startFly()
        toast("Fly ON", T.ok)
    else
        btnFly.BackgroundColor3 = T.panel2
        btnFly.TextColor3 = T.text
        btnFly.Text = "FLY: OFF"
        stopFly()
    end
end

local function startAntiAim()
    if antiAimConn then return end
    antiAimConn = RS.PreSimulation:Connect(function()
        if not cfg.antiAim then return end
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if not antiAimOrigin then
            antiAimOrigin = root.CFrame
        end
        root.CFrame = CFrame.new(antiAimOrigin.Position - Vector3.new(0, cfg.antiAimDepth, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        local cam = workspace.CurrentCamera
        cam.CFrame = CFrame.new(antiAimOrigin.Position + Vector3.new(0, 2, 8), antiAimOrigin.Position)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = false end
    end)
end

local function stopAntiAim()
    if antiAimConn then antiAimConn:Disconnect() antiAimConn = nil end
    antiAimOrigin = nil
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
        workspace.CurrentCamera.CameraSubject = hum
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end

local function setAntiAim(state)
    cfg.antiAim = state
    if state then
        btnAntiAim.BackgroundColor3 = T.accent
        btnAntiAim.TextColor3 = T.bg
        btnAntiAim.Text = "ANTI-AIM: ON"
        startAntiAim()
        toast("Anti-aim ON", T.ok)
    else
        btnAntiAim.BackgroundColor3 = T.panel2
        btnAntiAim.TextColor3 = T.text
        btnAntiAim.Text = "ANTI-AIM: OFF"
        stopAntiAim()
        toast("Anti-aim OFF", T.warn)
    end
end

btnFly.MouseButton1Click:Connect(function() setFly(not cfg.flyEnabled) end)
btnAntiAim.MouseButton1Click:Connect(function() setAntiAim(not cfg.antiAim) end)
btnRapidFire.MouseButton1Click:Connect(function() setRapidFire(not cfg.rapidFire) end)
btnRapidAttack.MouseButton1Click:Connect(function() setRapidAttack(not cfg.rapidAttack) end)

UIS.InputBegan:Connect(function(i, gp)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
end)

local function watchTool(tool)
    if not isMelee(tool) then return end
    hookToolRapidAttack(tool)
    tool.Activated:Connect(function()
        if not cfg.hitSound then return end
        local before = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local pc = p.Character
                if pc then
                    local h = pc:FindFirstChildOfClass("Humanoid")
                    if h then before[p] = h.Health end
                end
            end
        end
        task.wait(0.08)
        for p, hp in pairs(before) do
            local pc = p.Character
            if pc then
                local h = pc:FindFirstChildOfClass("Humanoid")
                if h and h.Health < hp then
                    hitSound:Play()
                    return
                end
            end
        end
    end)
end

local function setupChar(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then watchTool(child) end
    end
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then watchTool(child) end
    end)
end

if LP.Character then setupChar(LP.Character) end
LP.CharacterAdded:Connect(setupChar)
LP.CharacterAdded:Connect(function()
    task.wait(0.3)
    if cfg.auraEnabled then
        local c = LP.Character
        if c then
            local col = curAuraColor()
            if auraHighlight then auraHighlight:Destroy() end
            if auraLight then auraLight:Destroy() end
            local h = Instance.new("Highlight")
            h.FillColor = col
            h.OutlineColor = col
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = c
            h.Parent = c
            auraHighlight = h
            local root = c:FindFirstChild("HumanoidRootPart")
            if root then
                local l = Instance.new("PointLight")
                l.Color = col
                l.Range = 18
                l.Brightness = 3
                l.Shadows = false
                l.Parent = root
                auraLight = l
            end
        end
    end
    if cfg.flyEnabled then
        task.wait(0.2)
        startFly()
    end
end)

local function setFullbright(state)
    cfg.fullbright = state
    if state then
        if not savedLighting then
            savedLighting = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
            }
        end
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        btnFullbright.BackgroundColor3 = T.accent
        btnFullbright.TextColor3 = T.bg
        btnFullbright.Text = "FULLBRIGHT: ON"
    else
        if savedLighting then
            Lighting.Ambient = savedLighting.Ambient
            Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
            Lighting.Brightness = savedLighting.Brightness
            Lighting.GlobalShadows = savedLighting.GlobalShadows
            Lighting.FogEnd = savedLighting.FogEnd
            savedLighting = nil
        end
        btnFullbright.BackgroundColor3 = T.panel2
        btnFullbright.TextColor3 = T.text
        btnFullbright.Text = "FULLBRIGHT: OFF"
    end
end

local function setNoclip(state)
    cfg.noclip = state
    if state then
        btnNoclip.BackgroundColor3 = T.accent
        btnNoclip.TextColor3 = T.bg
        btnNoclip.Text = "NOCLIP: ON"
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RS.Stepped:Connect(function()
            local char = LP.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        btnNoclip.BackgroundColor3 = T.panel2
        btnNoclip.TextColor3 = T.text
        btnNoclip.Text = "NOCLIP: OFF"
    end
end

local function applyHighlight(p)
    local c = p.Character
    if not c then return end
    local ex = highlights[p]
    if ex and ex.Parent == c then return end
    if ex then ex:Destroy() end
    local h = Instance.new("Highlight")
    h.FillColor = curColor()
    h.OutlineColor = curColor()
    h.FillTransparency = 0.6
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = c
    h.Parent = c
    highlights[p] = h
end

local function clearHighlight(p)
    local h = highlights[p]
    if h then h:Destroy() highlights[p] = nil end
end

local function refreshColors()
    local col = curColor()
    for _, h in pairs(highlights) do
        if h and h.Parent then
            h.FillColor = col
            h.OutlineColor = col
        end
    end
end

local function setEsp(state)
    cfg.espEnabled = state
    if state then
        btnEsp.BackgroundColor3 = T.accent
        btnEsp.TextColor3 = T.bg
        btnEsp.Text = "HIGHLIGHT ESP: ON"
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then applyHighlight(p) end
        end
    else
        btnEsp.BackgroundColor3 = T.panel2
        btnEsp.TextColor3 = T.text
        btnEsp.Text = "HIGHLIGHT ESP: OFF"
        for p, _ in pairs(highlights) do clearHighlight(p) end
    end
end

local function applyAura()
    local c = LP.Character
    if not c then return end
    if auraHighlight then auraHighlight:Destroy() end
    if auraLight then auraLight:Destroy() end

    local col = curAuraColor()

    local h = Instance.new("Highlight")
    h.FillColor = col
    h.OutlineColor = col
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = c
    h.Parent = c
    auraHighlight = h

    local root = c:FindFirstChild("HumanoidRootPart")
    if root then
        local l = Instance.new("PointLight")
        l.Color = col
        l.Range = 18
        l.Brightness = 3
        l.Shadows = false
        l.Parent = root
        auraLight = l
    end
end

local function clearAura()
    if auraHighlight then auraHighlight:Destroy() auraHighlight = nil end
    if auraLight then auraLight:Destroy() auraLight = nil end
end

local function setAura(state)
    cfg.auraEnabled = state
    if state then
        btnAura.BackgroundColor3 = T.accent
        btnAura.TextColor3 = T.bg
        btnAura.Text = "AURA: ON"
        applyAura()
    else
        btnAura.BackgroundColor3 = T.panel2
        btnAura.TextColor3 = T.text
        btnAura.Text = "AURA: OFF"
        clearAura()
    end
end

local function getCamNearestPlayer()
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local nearest
    local nearestDistance = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local tc = player.Character
            local tr = tc and tc:FindFirstChild("HumanoidRootPart")
            local th = tc and tc:FindFirstChild("Head")
            if tr and th then
                local d = (root.Position - tr.Position).Magnitude
                if d < nearestDistance then
                    nearestDistance = d
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function setCamFollow(state)
    cfg.cameraFollow = state
    if state then
        btnCamFollow.BackgroundColor3 = T.accent
        btnCamFollow.TextColor3 = T.bg
        btnCamFollow.Text = "CAMERA FOLLOW: ON"
        camFollowTarget = getCamNearestPlayer()
        toast("Camera follow ON", T.ok)
    else
        btnCamFollow.BackgroundColor3 = T.panel2
        btnCamFollow.TextColor3 = T.text
        btnCamFollow.Text = "CAMERA FOLLOW: OFF"
        camFollowTarget = nil

        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom

        local character = LP.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            cam.CameraSubject = humanoid
            humanoid.AutoRotate = true
        end
    end
end

btnCamFollow.MouseButton1Click:Connect(function() setCamFollow(not cfg.cameraFollow) end)

local presets = {
    { name = "TROLL", holdTime = 0.3, voidForce = 500000, teleDelay = 0.5 },
    { name = "FIGHT", holdTime = 0.3, voidForce = 2000000, teleDelay = 0.5 },
    { name = "CHAOS", holdTime = 0.1, voidForce = 8000000, teleDelay = 0.2 },
}

for i, preset in ipairs(presets) do
    local b = Instance.new("TextButton")
    b.Parent = presetRow
    b.Size = UDim2.new(0.32, 0, 1, 0)
    b.BackgroundColor3 = T.panel2
    b.Text = preset.name
    b.TextColor3 = T.text
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 103
    b.LayoutOrder = i
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
    local s = Instance.new("UIStroke", b)
    s.Color = T.border
    s.Thickness = 1
    b.MouseButton1Click:Connect(function()
        cfg.holdTime = preset.holdTime
        cfg.voidForce = preset.voidForce
        cfg.teleDelay = preset.teleDelay
        if not cfg.voidEnabled then setVoid(true) end
        if not cfg.teleEnabled then setTele(true) end
        toast("Preset: " .. preset.name, T.accent)
    end)
end

btnEsp.MouseButton1Click:Connect(function() setEsp(not cfg.espEnabled) end)

btnColor.MouseButton1Click:Connect(function()
    cfg.espColor = (cfg.espColor % #colors) + 1
    btnColor.Text = "COLOR: " .. colorNames[cfg.espColor]
    refreshColors()
end)

btnAura.MouseButton1Click:Connect(function() setAura(not cfg.auraEnabled) end)

btnAuraColor.MouseButton1Click:Connect(function()
    cfg.auraColor = (cfg.auraColor % #colors) + 1
    btnAuraColor.Text = "AURA COLOR: " .. colorNames[cfg.auraColor]
    if cfg.auraEnabled then
        local col = curAuraColor()
        if auraHighlight then
            auraHighlight.FillColor = col
            auraHighlight.OutlineColor = col
        end
        if auraLight then auraLight.Color = col end
    end
end)

btnHitSound.MouseButton1Click:Connect(function()
    cfg.hitSound = not cfg.hitSound
    if cfg.hitSound then
        btnHitSound.BackgroundColor3 = T.accent
        btnHitSound.TextColor3 = T.bg
        btnHitSound.Text = "HIT SOUND: ON"
        toast("Hit sound ON", T.ok)
    else
        btnHitSound.BackgroundColor3 = T.panel2
        btnHitSound.TextColor3 = T.text
        btnHitSound.Text = "HIT SOUND: OFF"
    end
end)

btnAutoMelee.MouseButton1Click:Connect(function()
    cfg.autoMelee = not cfg.autoMelee
    if cfg.autoMelee then
        btnAutoMelee.BackgroundColor3 = T.accent
        btnAutoMelee.TextColor3 = T.bg
        btnAutoMelee.Text = "AUTO MELEE: ON"
        startAutoMelee()
        toast("Auto melee ON", T.ok)
    else
        btnAutoMelee.BackgroundColor3 = T.panel2
        btnAutoMelee.TextColor3 = T.text
        btnAutoMelee.Text = "AUTO MELEE: OFF"
        stopAutoMelee()
    end
end)

btnFullbright.MouseButton1Click:Connect(function() setFullbright(not cfg.fullbright) end)
btnNoclip.MouseButton1Click:Connect(function() setNoclip(not cfg.noclip) end)

btnKillFeed.MouseButton1Click:Connect(function()
    cfg.killFeed = not cfg.killFeed
    if cfg.killFeed then
        btnKillFeed.BackgroundColor3 = T.accent
        btnKillFeed.TextColor3 = T.bg
        btnKillFeed.Text = "KILL FEED: ON"
    else
        btnKillFeed.BackgroundColor3 = T.panel2
        btnKillFeed.TextColor3 = T.text
        btnKillFeed.Text = "KILL FEED: OFF"
    end
end)

btnCombatTimer.MouseButton1Click:Connect(function()
    cfg.combatTimer = not cfg.combatTimer
    combatLabel.Visible = cfg.combatTimer
    if cfg.combatTimer then
        btnCombatTimer.BackgroundColor3 = T.accent
        btnCombatTimer.TextColor3 = T.bg
        btnCombatTimer.Text = "COMBAT TIMER: ON"
    else
        btnCombatTimer.BackgroundColor3 = T.panel2
        btnCombatTimer.TextColor3 = T.text
        btnCombatTimer.Text = "COMBAT TIMER: OFF"
    end
end)

btnSuspicious.MouseButton1Click:Connect(function()
    cfg.suspicious = not cfg.suspicious
    if cfg.suspicious then
        btnSuspicious.BackgroundColor3 = T.accent
        btnSuspicious.TextColor3 = T.bg
        btnSuspicious.Text = "THREAT DETECTION: ON"
    else
        btnSuspicious.BackgroundColor3 = T.panel2
        btnSuspicious.TextColor3 = T.text
        btnSuspicious.Text = "THREAT DETECTION: OFF"
    end
end)

btnVoidTrack.MouseButton1Click:Connect(function()
    cfg.voidTrack = not cfg.voidTrack
    if cfg.voidTrack then
        btnVoidTrack.BackgroundColor3 = T.accent
        btnVoidTrack.TextColor3 = T.bg
        btnVoidTrack.Text = "VOID TRACKER: ON"
    else
        btnVoidTrack.BackgroundColor3 = T.panel2
        btnVoidTrack.TextColor3 = T.text
        btnVoidTrack.Text = "VOID TRACKER: OFF"
    end
end)

btnNotifications.MouseButton1Click:Connect(function()
    cfg.notifications = not cfg.notifications
    if cfg.notifications then
        btnNotifications.BackgroundColor3 = T.accent
        btnNotifications.TextColor3 = T.bg
        btnNotifications.Text = "NOTIFICATIONS: ON"
    else
        btnNotifications.BackgroundColor3 = T.panel2
        btnNotifications.TextColor3 = T.text
        btnNotifications.Text = "NOTIFICATIONS: OFF"
    end
end)

btnFps.MouseButton1Click:Connect(function()
    cfg.fpsOverlay = not cfg.fpsOverlay
    fpsFrame.Visible = cfg.fpsOverlay
    combatLabel.Visible = cfg.fpsOverlay and cfg.combatTimer
    if cfg.fpsOverlay then
        btnFps.BackgroundColor3 = T.accent
        btnFps.TextColor3 = T.bg
        btnFps.Text = "FPS OVERLAY: ON"
    else
        btnFps.BackgroundColor3 = T.panel2
        btnFps.TextColor3 = T.text
        btnFps.Text = "FPS OVERLAY: OFF"
    end
end)

local function serializeConfig()
    local lines = {}
    local data = {
        teleDelay = cfg.teleDelay,
        useAll = cfg.useAll,
        voidForce = cfg.voidForce,
        voidInterval = cfg.voidInterval,
        holdTime = cfg.holdTime,
        teleKey = cfg.teleKey.Name,
        voidKey = cfg.voidKey.Name,
        espColor = cfg.espColor,
        espEnabled = cfg.espEnabled,
        hitSound = cfg.hitSound,
        soundId = cfg.soundId,
        fullbright = cfg.fullbright,
        fpsOverlay = cfg.fpsOverlay,
        noclip = cfg.noclip,
        autoMelee = cfg.autoMelee,
        rapidFire = cfg.rapidFire,
        rapidAttack = cfg.rapidAttack,
        auraEnabled = cfg.auraEnabled,
        auraColor = cfg.auraColor,
        cameraFollow = cfg.cameraFollow,
        killFeed = cfg.killFeed,
        combatTimer = cfg.combatTimer,
        voidTrack = cfg.voidTrack,
        suspicious = cfg.suspicious,
        notifications = cfg.notifications,
        bgEnabled = cfg.bgEnabled,
        bgOffsetBack = cfg.bgOffsetBack,
        bgOffsetUp = cfg.bgOffsetUp,
        bgIgnoreTeam = cfg.bgIgnoreTeam,
        bgLockCamera = cfg.bgLockCamera,
        flyEnabled = cfg.flyEnabled,
        flySpeed = cfg.flySpeed,
        flyKey = cfg.flyKey.Name,
        antiAim = cfg.antiAim,
        antiAimDepth = cfg.antiAimDepth,
    }
    for k, v in pairs(data) do
        table.insert(lines, k .. "=" .. tostring(v))
    end
    return table.concat(lines, "\n")
end

local function applyConfigData(str)
    for line in str:gmatch("[^\n]+") do
        local k, v = line:match("^([^=]+)=(.+)$")
        if k and v then
            if k == "teleKey" then
                pcall(function() cfg.teleKey = Enum.KeyCode[v] end)
            elseif k == "voidKey" then
                pcall(function() cfg.voidKey = Enum.KeyCode[v] end)
            elseif k == "flyKey" then
                pcall(function() cfg.flyKey = Enum.KeyCode[v] end)
            else
                if v == "true" then v = true
                elseif v == "false" then v = false
                else
                    local n = tonumber(v)
                    if n then v = n end
                end
                if cfg[k] ~= nil then cfg[k] = v end
            end
        end
    end
    btnKeyTele.Text = "TELE: " .. cfg.teleKey.Name
    btnKeyVoid.Text = "VOID: " .. cfg.voidKey.Name
    btnKeyFly.Text = "FLY: " .. cfg.flyKey.Name
    spdFill.Size = UDim2.new((cfg.teleDelay - 0.1) / 1.9, 0, 1, 0)
    spdVal.Text = string.format("%.1fs", cfg.teleDelay)
    btnColor.Text = "COLOR: " .. colorNames[cfg.espColor]
    btnAuraColor.Text = "AURA COLOR: " .. colorNames[cfg.auraColor]
    refreshColors()
    setEsp(cfg.espEnabled)
    if cfg.hitSound then
        btnHitSound.BackgroundColor3 = T.accent
        btnHitSound.TextColor3 = T.bg
        btnHitSound.Text = "HIT SOUND: ON"
    else
        btnHitSound.BackgroundColor3 = T.panel2
        btnHitSound.TextColor3 = T.text
        btnHitSound.Text = "HIT SOUND: OFF"
    end
    if cfg.soundId and cfg.soundId ~= "" then
        hitSound.SoundId = "rbxassetid://" .. cfg.soundId
        soundInput.Text = cfg.soundId
    else
        hitSound.SoundId = DEFAULT_SOUND
        soundInput.Text = ""
    end
    if cfg.fullbright then setFullbright(true) else setFullbright(false) end
    if cfg.fpsOverlay then
        fpsFrame.Visible = true
        btnFps.BackgroundColor3 = T.accent
        btnFps.TextColor3 = T.bg
        btnFps.Text = "FPS OVERLAY: ON"
    else
        fpsFrame.Visible = false
        btnFps.BackgroundColor3 = T.panel2
        btnFps.TextColor3 = T.text
        btnFps.Text = "FPS OVERLAY: OFF"
    end
    combatLabel.Visible = cfg.fpsOverlay and cfg.combatTimer
    if cfg.noclip then setNoclip(true) else setNoclip(false) end
    if cfg.autoMelee then
        btnAutoMelee.BackgroundColor3 = T.accent
        btnAutoMelee.TextColor3 = T.bg
        btnAutoMelee.Text = "AUTO MELEE: ON"
        startAutoMelee()
    else
        btnAutoMelee.BackgroundColor3 = T.panel2
        btnAutoMelee.TextColor3 = T.text
        btnAutoMelee.Text = "AUTO MELEE: OFF"
        stopAutoMelee()
    end
    if cfg.rapidFire then
        btnRapidFire.BackgroundColor3 = T.accent
        btnRapidFire.TextColor3 = T.bg
        btnRapidFire.Text = "RAPID FIRE: ON"
        startRapidFire()
    else
        btnRapidFire.BackgroundColor3 = T.panel2
        btnRapidFire.TextColor3 = T.text
        btnRapidFire.Text = "RAPID FIRE: OFF"
    end
    if cfg.rapidAttack then
        btnRapidAttack.BackgroundColor3 = T.accent
        btnRapidAttack.TextColor3 = T.bg
        btnRapidAttack.Text = "RAPID ATTACK: ON"
        startRapidAttack()
    else
        btnRapidAttack.BackgroundColor3 = T.panel2
        btnRapidAttack.TextColor3 = T.text
        btnRapidAttack.Text = "RAPID ATTACK: OFF"
    end
    if cfg.auraEnabled then setAura(true) else setAura(false) end
    if cfg.cameraFollow then setCamFollow(true) else setCamFollow(false) end
    if cfg.flyEnabled then setFly(true) else setFly(false) end
    if cfg.antiAim then setAntiAim(true) else setAntiAim(false) end
    btnKillFeed.Text = cfg.killFeed and "KILL FEED: ON" or "KILL FEED: OFF"
    btnKillFeed.BackgroundColor3 = cfg.killFeed and T.accent or T.panel2
    btnKillFeed.TextColor3 = cfg.killFeed and T.bg or T.text
    btnCombatTimer.Text = cfg.combatTimer and "COMBAT TIMER: ON" or "COMBAT TIMER: OFF"
    btnCombatTimer.BackgroundColor3 = cfg.combatTimer and T.accent or T.panel2
    btnCombatTimer.TextColor3 = cfg.combatTimer and T.bg or T.text
    btnSuspicious.Text = cfg.suspicious and "THREAT DETECTION: ON" or "THREAT DETECTION: OFF"
    btnSuspicious.BackgroundColor3 = cfg.suspicious and T.accent or T.panel2
    btnSuspicious.TextColor3 = cfg.suspicious and T.bg or T.text
    btnVoidTrack.Text = cfg.voidTrack and "VOID TRACKER: ON" or "VOID TRACKER: OFF"
    btnVoidTrack.BackgroundColor3 = cfg.voidTrack and T.accent or T.panel2
    btnVoidTrack.TextColor3 = cfg.voidTrack and T.bg or T.text
    btnNotifications.Text = cfg.notifications and "NOTIFICATIONS: ON" or "NOTIFICATIONS: OFF"
    btnNotifications.BackgroundColor3 = cfg.notifications and T.accent or T.panel2
    btnNotifications.TextColor3 = cfg.notifications and T.bg or T.text
    btnBg.Text = cfg.bgEnabled and "BACKGLUE: ON" or "BACKGLUE: OFF"
    btnBg.BackgroundColor3 = cfg.bgEnabled and T.accent or T.panel2
    btnBg.TextColor3 = cfg.bgEnabled and T.bg or T.text
    btnBgCam.Text = cfg.bgLockCamera and "GLUE LOCK CAMERA: ON" or "GLUE LOCK CAMERA: OFF"
    btnBgCam.BackgroundColor3 = cfg.bgLockCamera and T.accent or T.panel2
    btnBgCam.TextColor3 = cfg.bgLockCamera and T.bg or T.text
    btnBgTeam.Text = cfg.bgIgnoreTeam and "GLUE IGNORE TEAM: ON" or "GLUE IGNORE TEAM: OFF"
    btnBgTeam.BackgroundColor3 = cfg.bgIgnoreTeam and T.accent or T.panel2
    btnBgTeam.TextColor3 = cfg.bgIgnoreTeam and T.bg or T.text
end

local function flashBtn(btn, temp)
    local original = btn.Text
    btn.Text = temp
    task.wait(1)
    btn.Text = original
end

btnCfgSave.MouseButton1Click:Connect(function()
    if not writefile or not isfolder or not makefolder then
        flashBtn(btnCfgSave, "NO API")
        return
    end
    local name = configInput.Text:gsub("[^%w_%-]", "")
    if name == "" then
        flashBtn(btnCfgSave, "NAME IT")
        return
    end
    if not isfolder(CONFIG_DIR) then
        pcall(function() makefolder(CONFIG_DIR) end)
    end
    local ok = pcall(function() writefile(CONFIG_DIR .. "/" .. name .. ".txt", serializeConfig()) end)
    if ok then
        flashBtn(btnCfgSave, "SAVED!")
        toast("Saved: " .. name, T.ok)
        refreshConfigList()
    else
        flashBtn(btnCfgSave, "FAILED")
    end
end)

btnCfgLoad.MouseButton1Click:Connect(function()
    if not readfile or not isfile then
        flashBtn(btnCfgLoad, "NO API")
        return
    end
    if cfg.activeConfig == "" then
        flashBtn(btnCfgLoad, "PICK ONE")
        return
    end
    local path = CONFIG_DIR .. "/" .. cfg.activeConfig .. ".txt"
    if not isfile(path) then
        flashBtn(btnCfgLoad, "NO FILE")
        return
    end
    local ok, data = pcall(function() return readfile(path) end)
    if ok and data then
        applyConfigData(data)
        flashBtn(btnCfgLoad, "LOADED!")
        toast("Loaded: " .. cfg.activeConfig, T.ok)
    else
        flashBtn(btnCfgLoad, "FAILED")
    end
end)

btnCfgRefresh.MouseButton1Click:Connect(function()
    refreshConfigList()
    flashBtn(btnCfgRefresh, "DONE")
end)

btnCfgAuto.MouseButton1Click:Connect(function()
    cfg.autoLoad = not cfg.autoLoad
    if cfg.autoLoad then
        btnCfgAuto.BackgroundColor3 = T.accent
        btnCfgAuto.TextColor3 = T.bg
        btnCfgAuto.Text = "AUTO: ON"
        if writefile then
            local target = cfg.activeConfig ~= "" and cfg.activeConfig or "none"
            pcall(function() writefile(AUTOLOAD_MARKER, target) end)
        end
        toast("Auto load ON", T.ok)
    else
        btnCfgAuto.BackgroundColor3 = T.panel2
        btnCfgAuto.TextColor3 = T.text
        btnCfgAuto.Text = "AUTO: OFF"
        if writefile then
            pcall(function() writefile(AUTOLOAD_MARKER, "none") end)
        end
    end
end)

local function tryAutoLoad()
    if not readfile or not isfile then return end
    if not isfile(AUTOLOAD_MARKER) then return end
    local ok, target = pcall(function() return readfile(AUTOLOAD_MARKER) end)
    if not ok or not target or target == "" or target == "none" then return end
    local path = CONFIG_DIR .. "/" .. target .. ".txt"
    if not isfile(path) then return end
    local ok2, data = pcall(function() return readfile(path) end)
    if ok2 and data then
        applyConfigData(data)
        cfg.autoLoad = true
        btnCfgAuto.BackgroundColor3 = T.accent
        btnCfgAuto.TextColor3 = T.bg
        btnCfgAuto.Text = "AUTO: ON"
        toast("Autoloaded: " .. target, T.ok)
    end
end

task.spawn(tryAutoLoad)
refreshConfigList()

btnEnable.MouseButton1Click:Connect(function() setTele(not cfg.teleEnabled) end)
btnVoid.MouseButton1Click:Connect(function() setVoid(not cfg.voidEnabled) end)

btnAll.MouseButton1Click:Connect(function()
    cfg.useAll = true
    cfg.selected = nil
    btnAll.BackgroundColor3 = T.accent
    btnAll.TextColor3 = T.bg
    btnSel.BackgroundColor3 = T.panel2
    btnSel.TextColor3 = T.text
    btnSel.Text = "SELECT"
    refreshList()
end)

btnSel.MouseButton1Click:Connect(function()
    cfg.useAll = false
    btnAll.BackgroundColor3 = T.panel2
    btnAll.TextColor3 = T.text
    btnSel.BackgroundColor3 = T.accent
    btnSel.TextColor3 = T.bg
    if cfg.selected then
        btnSel.Text = cfg.selected.Name:sub(1, 10)
    else
        btnSel.Text = "PICK"
    end
end)

btnCycle.MouseButton1Click:Connect(function()
    refreshPlayers()
    if #players == 0 then return end
    playerIndex = playerIndex % #players + 1
    local p = players[playerIndex]
    if p then
        teleportTo(p)
        statTgt.Text = "-> " .. p.Name
    end
end)

orb.MouseButton1Click:Connect(function()
    win.Visible = not win.Visible
end)

cls.MouseButton1Click:Connect(function()
    win.Visible = false
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if awaitingBind == "tele" then
        cfg.teleKey = input.KeyCode
        btnKeyTele.Text = "TELE: " .. input.KeyCode.Name
        awaitingBind = nil
        return
    end
    if awaitingBind == "void" then
        cfg.voidKey = input.KeyCode
        btnKeyVoid.Text = "VOID: " .. input.KeyCode.Name
        awaitingBind = nil
        return
    end
    if awaitingBind == "fly" then
        cfg.flyKey = input.KeyCode
        btnKeyFly.Text = "FLY: " .. input.KeyCode.Name
        awaitingBind = nil
        return
    end
    if input.KeyCode == cfg.teleKey then
        setTele(not cfg.teleEnabled)
    elseif input.KeyCode == cfg.voidKey then
        setVoid(not cfg.voidEnabled)
    elseif input.KeyCode == cfg.flyKey then
        setFly(not cfg.flyEnabled)
    end
end)

btnKeyTele.MouseButton1Click:Connect(function()
    awaitingBind = "tele"
    btnKeyTele.Text = "PRESS..."
end)

btnKeyVoid.MouseButton1Click:Connect(function()
    awaitingBind = "void"
    btnKeyVoid.Text = "PRESS..."
end)

btnKeyFly.MouseButton1Click:Connect(function()
    awaitingBind = "fly"
    btnKeyFly.Text = "PRESS..."
end)

Players.PlayerAdded:Connect(function(p)
    refreshList()
    if cfg.espEnabled and p ~= LP then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if cfg.espEnabled then applyHighlight(p) end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    clearHighlight(p)
    lastSeen[p] = nil
    lastVel[p] = nil
    refreshList()
end)

LP.CharacterAdded:Connect(function()
    bgLockedTarget = nil
    antiAimOrigin = nil
    task.wait(0.5)
    if cfg.noclip then setNoclip(true) end
    if cfg.rapidAttack then
        local c = LP.Character
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") then hookToolRapidAttack(t) end
            end
        end
    end
    if cfg.flyEnabled then
        task.wait(0.2)
        startFly()
    end
end)

spawn(function()
    while true do
        local dt = task.wait(0.5)
        if cfg.teleEnabled then
            if cfg.useAll then
                if tick() - lastCycle >= cfg.teleDelay then
                    lastCycle = tick()
                    refreshPlayers()
                    if #players > 0 then
                        playerIndex = playerIndex % #players + 1
                        local p = players[playerIndex]
                        if p then
                            teleportTo(p)
                            statTgt.Text = "-> " .. p.Name
                        end
                    end
                end
            elseif cfg.selected and cfg.selected.Parent then
                if tick() - lastTele >= cfg.teleDelay then
                    lastTele = tick()
                    if teleportTo(cfg.selected) then
                        statTgt.Text = "-> " .. cfg.selected.Name
                    end
                end
            end
        end
    end
end)

spawn(function()
    local fps = 0
    local frames = 0
    local last = tick()
    while true do
        local dt = task.wait(1)
        frames = frames + 1
        if tick() - last >= 1 then
            fps = frames
            frames = 0
            last = tick()
            fpsText.Text = "FPS: " .. fps
            local ok, ping = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            if ok and ping then
                pingText.Text = "PING: " .. math.floor(ping) .. "ms"
            end
        end
    end
end)

spawn(function()
    while true do
        task.wait(0.1)
        rainbowHue = (rainbowHue + 0.01) % 1
        if cfg.espEnabled and cfg.espColor == RAINBOW_IDX then
            refreshColors()
        end
        if cfg.auraEnabled and cfg.auraColor == RAINBOW_IDX then
            local col = curAuraColor()
            if auraHighlight then
                auraHighlight.FillColor = col
                auraHighlight.OutlineColor = col
            end
            if auraLight then auraLight.Color = col end
        end
    end
end)

spawn(function()
    while true do
        task.wait(0.25)
        if cfg.fpsOverlay and cfg.combatTimer then
            if inCombat then
                local t = tick() - combatStart
                combatLabel.Text = string.format("FIGHT: %.1fs", t)
                combatLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                if t > 8 then
                    inCombat = false
                end
            else
                combatLabel.Text = "FIGHT: --"
                combatLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end
end)

spawn(function()
    while true do
        task.wait(1)
        if cfg.voidTrack and cfg.suspicious then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and isSuspicious(p) then
                    if tick() - lastThreatToast > 3 then
                        lastThreatToast = tick()
                        toast("Threat: " .. p.Name, T.warn)
                    end
                end
            end
        end
    end
end)

spawn(function()
    while true do
        task.wait(0.5)
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then
                local hp = h.Health
                if hp < lastDamage then
                    inCombat = true
                    combatStart = tick()
                end
                lastDamage = hp
            end
        end
    end
end)

spawn(function()
    local lastPos = {}
    while true do
        task.wait(0.05)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local prev = lastPos[p]
                    if prev and (hrp.Position - prev).Magnitude > 150 then
                        if cfg.suspicious then
                            lastSeen[p] = hrp.Position
                        end
                    end
                    lastPos[p] = hrp.Position
                end
            end
        end
    end
end)

spawn(function()
    while true do
        task.wait(0.5)
        if cfg.cameraFollow then
            local target = camFollowTarget
            if not target or not target.Parent then
                camFollowTarget = getCamNearestPlayer()
                target = camFollowTarget
            end
            if target then
                local tc = target.Character
                local th = tc and tc:FindFirstChild("Head")
                if th then
                    local cam = workspace.CurrentCamera
                    cam.CameraType = Enum.CameraType.Scriptable
                    local look = CFrame.new(cam.CFrame.Position, th.Position)
                    cam.CFrame = cam.CFrame:Lerp(look, 0.15)
                    local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if myHum then
                        myHum.AutoRotate = false
                    end
                end
            end
        end
    end
end)

toast("PHANTOMCORE loaded", T.ok)
