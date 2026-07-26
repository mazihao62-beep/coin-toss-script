--[[
    扔硬币游戏 - 自动脚本 v2.5
    WindUI 模板 + 自动投币 + 自动升级 + 自动出售
    检测玩家当前硬币 / 倍率滑块控制投币时机
--]]

print("[扔硬币] v2.5 加载中...")

local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local C = game:GetService("CoreGui")
local LP = P.LocalPlayer
if not LP then return end
print("[扔硬币] 玩家: " .. LP.Name)

for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "A" or g.Name:find("Coin") or g.Name == "WindUI") then
        pcall(function() g:Destroy() end)
    end
end

local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[扔硬币] WindUI 失败"); return end
print("[扔硬币] WindUI OK")

local Events = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Events")
local CoinLanded = Events and Events:FindFirstChild("CoinLanded")
local RequestUpgrade = Events and Events:FindFirstChild("RequestUpgrade")
local BuyCoin = Events and Events:FindFirstChild("BuyCoin")
local SellAllItems = Events and Events:FindFirstChild("SellAllItems")
print("[扔硬币] CoinLanded=" .. tostring(CoinLanded and "OK" or "NIL"))
print("[扔硬币] RequestUpgrade=" .. tostring(RequestUpgrade and "OK" or "NIL"))
print("[扔硬币] BuyCoin=" .. tostring(BuyCoin and "OK" or "NIL"))
print("[扔硬币] SellAllItems=" .. tostring(SellAllItems and "OK" or "NIL"))

local S = {
    AutoThrow = false, AutoBuyCoin = false, AutoUpgradeLuck = false,
    AutoUpgradeValue = false, AutoSell = false, Speed = false, Fly = false,
    ThrowMultiplier = 3, SpeedVal = 50, FlySpeed = 50,
    Particles = true, Acrylic = true, Transparent = false,
    ParticleColor = Color3.fromRGB(80, 170, 255)
}
local KB = { Toggle = Enum.KeyCode.F4 }
local WN, CT = nil, {}
local PR, PS, PC = false, {}, nil
local WN_visible = false
local toggleLock = 0
local coinDebounce = 0
local coinList = {"Paradox Coin","Lucky Coin","Golden Coin","Obsidian Coin","Platinum Coin","Ruby Coin","Emerald Coin","Amethyst Coin","Topaz Coin","Diamond Coin","Staff Token","VIP Token","Developer Token","Diamond Token"}

local function getCoinName()
    local pg = LP:FindFirstChild("PlayerGui")
    local coinName = pg and pg:FindFirstChild("UiFolder") and pg.UiFolder:FindFirstChild("Main")
        and pg.UiFolder.Main:FindFirstChild("HUD") and pg.UiFolder.Main.HUD:FindFirstChild("Coin")
        and pg.UiFolder.Main.HUD.Coin:FindFirstChild("Main") and pg.UiFolder.Main.HUD.Coin.Main:FindFirstChild("CoinName")
    if coinName and coinName:IsA("TextLabel") and coinName.Text ~= "" then
        return coinName.Text
    end
    return nil
end

local function getMultiplier()
    local pg = LP:FindFirstChild("PlayerGui")
    local tb = pg and pg:FindFirstChild("UiFolder") and pg.UiFolder:FindFirstChild("Main")
        and pg.UiFolder.Main:FindFirstChild("HUD") and pg.UiFolder.Main.HUD:FindFirstChild("ThrowBar")
        and pg.UiFolder.Main.HUD.ThrowBar:FindFirstChild("CurrentMulti")
    if tb and tb:IsA("Frame") then
        return tb.Size.X.Scale * 3
    end
    return 0
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function formatNum(v)
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return string.format("%.1f", v)
end

-- 投币
local function doThrow()
    if not S.AutoThrow or not CoinLanded then return end
    local mult = getMultiplier()
    if mult < S.ThrowMultiplier then return end
    local coinName = getCoinName()
    if not coinName then return end
    local hrp = getHRP()
    if not hrp then return end
    local pos = hrp.Position + Vector3.new(0, -0.5, -2)
    local multInt = math.floor(S.ThrowMultiplier)
    if S.ThrowMultiplier == multInt then
        CoinLanded:FireServer(multInt, pos, coinName, nil, nil)
    else
        CoinLanded:FireServer(S.ThrowMultiplier, pos, coinName, nil, nil)
    end
    print("[投币] " .. coinName .. " @" .. formatNum(S.ThrowMultiplier) .. "x")
    wait(0.5)
end

-- 购买硬币（带防抖）
local function doBuyCoin()
    if not S.AutoBuyCoin or not BuyCoin then return end
    if tick() - coinDebounce < 3 then return end
    local cur = getCoinName()
    if cur then return end
    coinDebounce = tick()
    for _, name in ipairs(coinList) do
        local ok = pcall(function() BuyCoin:FireServer(name) end)
        if ok then print("[购买] " .. name) break end
        wait(0.1)
    end
end

-- 升级（带防抖）
local luckDebounce, valDebounce = 0, 0
local function doUpgradeLuck()
    if not S.AutoUpgradeLuck or not RequestUpgrade then return end
    if tick() - luckDebounce < 1 then return end
    luckDebounce = tick()
    local ok = pcall(function() RequestUpgrade:FireServer("Luck Multiplier") end)
    if ok then print("[升级] 运气") end
end

local function doUpgradeValue()
    if not S.AutoUpgradeValue or not RequestUpgrade then return end
    if tick() - valDebounce < 1 then return end
    valDebounce = tick()
    local ok = pcall(function() RequestUpgrade:FireServer("Value Multiplier") end)
    if ok then print("[升级] 钱倍率") end
end

-- 出售
local sellDebounce = 0
local function doSell()
    if not S.AutoSell or not SellAllItems then return end
    local now = tick()
    if now - sellDebounce < 2 then return end
    sellDebounce = now
    local ok, err = pcall(function() SellAllItems:FireServer() end)
    if ok then
        print("[出售] 已卖")
    else
        print("[出售] 失败: " .. tostring(err))
    end
end

-- 飞行
local BV, BG = nil, nil
local function clearFly()
    if BV then pcall(function() BV:Destroy() end) BV = nil end
    if BG then pcall(function() BG:Destroy() end) BG = nil end
end

local function toggleFly(on)
    clearFly()
    if not on then return end
    local h = getHRP()
    if not h then wait(0.5); h = getHRP(); if not h then return end end
    BV = Instance.new("BodyVelocity")
    BV.Velocity = Vector3.new(0,0,0)
    BV.MaxForce = Vector3.new(1,1,1) * 4000
    BV.P = 1250
    BV.Parent = h
    BG = Instance.new("BodyGyro")
    BG.MaxTorque = Vector3.new(1,1,1) * 4000
    BG.P = 1250
    BG.D = 500
    BG.Parent = h
end

local function flyStep()
    if not S.Fly or not BV then return end
    local h = getHRP()
    if not h then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local cam = workspace.CurrentCamera
    local speed = S.FlySpeed
    local md = hum.MoveDirection
    local dir = cam.CFrame:VectorToObjectSpace(md) * speed
    dir = Vector3.new(dir.X, 0, dir.Z)
    if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.ButtonR1) then
        dir = dir + Vector3.new(0, speed, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.ButtonL1) then
        dir = dir + Vector3.new(0, -speed, 0)
    end
    BV.Velocity = dir
    BG.CFrame = cam.CFrame
end

-- 粒子
local function sP()
    if PR then return end
    if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end
    PS={}; wait(0.3)
    local sg=Instance.new("ScreenGui"); sg.Name="CP"; sg.ResetOnSpawn=false; sg.DisplayOrder=999999; sg.IgnoreGuiInset=true; sg.Parent=C
    PC=Instance.new("Frame"); PC.Size=UDim2.new(1,0,1,0); PC.BackgroundTransparency=1; PC.BorderSizePixel=0; PC.Parent=sg
    for i=1,50 do
        local d=Instance.new("Frame"); local sz=math.random(5,10)
        d.Size=UDim2.new(0,sz,0,sz); d.Position=UDim2.new(0.2+math.random()*0.6,0,0.2+math.random()*0.6,0)
        d.BackgroundColor3=S.ParticleColor; d.BackgroundTransparency=0.3+math.random()*0.5; d.BorderSizePixel=0; d.Parent=PC
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,10)
        local a=math.random()*6.28; local sp=0.0008+math.random()*0.002
        table.insert(PS,{F=d,Sx=d.Position.X.Scale,Sy=d.Position.Y.Scale,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})
    end
    PR=true
    spawn(function() local t=0; while PR and PC do t=t+0.03
        pcall(function() local c=S.ParticleColor; for _,p in ipairs(PS) do if p.F and p.F.Parent then
            local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx)); local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy))
            if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end; if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end
            p.Sx=sx; p.Sy=sy; p.F.Position=UDim2.new(sx,0,sy,0); p.F.BackgroundColor3=c
            p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4
            p.F.Size=UDim2.new(0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5),0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5))
    end end end) wait(0.03) end end)
end
local function xP() PR=false; if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end; PS={} end

local tc_t = {Dark=Color3.fromRGB(80,170,255),Light=Color3.fromRGB(60,130,210),Rose=Color3.fromRGB(255,130,170),Plant=Color3.fromRGB(70,210,130),Ocean=Color3.fromRGB(60,190,240),Sunset=Color3.fromRGB(255,160,70),Midnight=Color3.fromRGB(130,100,240),Forest=Color3.fromRGB(60,180,90),Lavender=Color3.fromRGB(190,140,255),Coral=Color3.fromRGB(255,140,90),Mint=Color3.fromRGB(80,230,190),Sky=Color3.fromRGB(100,190,255),Blood=Color3.fromRGB(230,90,80),Lemon=Color3.fromRGB(230,210,70),Cyber=Color3.fromRGB(0,235,210)}
local function tc(n) return tc_t[n] or Color3.fromRGB(80,170,255) end

-- UI
local function mW()
    WN = WI:CreateWindow({
        Title="扔硬币", Author="b站英吉利超入_", Icon="solar:coin-bold",
        Size=UDim2.fromOffset(750,560), ToggleKey=KB.Toggle,
        Folder="coin-toss-script", Acrylic=true, Resizable=false,
        ScrollBarEnabled=true, HideSearchBar=true,
        OnClose=function()
            xP(); toggleFly(false); S.AutoThrow=false; S.AutoBuyCoin=false
            S.AutoUpgradeLuck=false; S.AutoUpgradeValue=false; S.AutoSell=false; S.Speed=false; S.Fly=false
            WN_visible=false
            for _, ct in pairs(CT) do if ct and type(ct.Set)=="function" then pcall(function() ct:Set(false) end) end end
        end,
        OnOpen=function() WN_visible=true; if S.Particles then sP() end end
    })
    WN_visible=true
    spawn(function() wait(0.8) pcall(function() if WN and WN.Parent then WN.Parent.ClipsDescendants=true end end) end)

    local t1=WN:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
    CT.AutoThrow=t1:Toggle({Flag="AutoThrow",Title="自动投币",Value=false,Callback=function(v) S.AutoThrow=v end})
    t1:Slider({Flag="ThrowMult",Title="投币倍率",Step=0.1,Value={Min=1,Max=3,Default=3},Width=200,IsTextbox=true,Callback=function(v) S.ThrowMultiplier=v end})
    t1:Divider()
    CT.AutoBuyCoin=t1:Toggle({Flag="AutoBuyCoin",Title="自动购买硬币",Value=false,Callback=function(v) S.AutoBuyCoin=v end})
    t1:Divider()
    CT.AutoUpgradeLuck=t1:Toggle({Flag="AutoUpgradeLuck",Title="升级(运气)",Value=false,Callback=function(v) S.AutoUpgradeLuck=v end})
    CT.AutoUpgradeValue=t1:Toggle({Flag="AutoUpgradeValue",Title="升级(钱倍率)",Value=false,Callback=function(v) S.AutoUpgradeValue=v end})
    t1:Divider()
    CT.AutoSell=t1:Toggle({Flag="AutoSell",Title="自动出售",Value=false,Callback=function(v) S.AutoSell=v end})
    t1:Divider()
    CT.Speed=t1:Toggle({Flag="Speed",Title="加速",Value=false,Callback=function(v) S.Speed=v end})
    t1:Slider({Flag="SpeedVal",Title="速度",Step=5,Value={Min=16,Max=120,Default=50},Width=200,IsTextbox=true,Callback=function(v) S.SpeedVal=v end})
    CT.Fly=t1:Toggle({Flag="Fly",Title="飞行(WASD+空格+Shift)",Value=false,Callback=function(v) S.Fly=v; toggleFly(v) end})
    t1:Slider({Flag="FlySpeed",Title="飞行速度",Step=5,Value={Min=10,Max=150,Default=50},Width=200,IsTextbox=true,Callback=function(v) S.FlySpeed=v end})

    local t2=WN:Tab({Title="快捷键", Icon="solar:settings-bold"})
    t2:Keybind({Flag="ToggleKey",Title="窗口开关",Value="F4",Callback=function(v)
        KB.Toggle=v
        pcall(function() if WN then WN:SetToggleKey(v) end end)
    end})

    local t3=WN:Tab({Title="UI设置", Icon="solar:monitor-bold"})
    CT.Particles=t3:Toggle({Flag="Particles",Title="粒子背景",Value=true,Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t3:Toggle({Flag="Acrylic",Title="毛玻璃",Value=true,Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t3:Toggle({Flag="Transparent",Title="透明",Value=false,Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Dark","Light","Rose","Plant","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t3:Dropdown({Flag="Theme",Title="主题",Values=tns,Value="Dark",Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t4=WN:Tab({Title="信息统计", Icon="solar:chart-bold"})
    local sCoin=t4:Paragraph({Title="硬币: ?"})
    local sMult=t4:Paragraph({Title="倍率: 0x"})

    local t5=WN:Tab({Title="配置管理", Icon="solar:diskette-bold"})
    pcall(function()
        local CM=WN.ConfigManager; if not CM then return end
        local cni=t5:Input({Flag="CN",Title="配置名称",Value="default",Icon="solar:file-text-bold",Callback=function(v) end})
        t5:Space(); local AC={}; pcall(function() AC=CM:AllConfigs() end)
        local DV=nil; for _,v in ipairs(AC) do if v=="default" then DV="default"; break end end
        local ACD=t5:Dropdown({Title="已有配置",Values=AC,Value=DV,Callback=function(v) if v then pcall(function() cni:Set(v) end) end end})
        t5:Space()
        t5:Button({Title="保存",Icon="solar:check-circle-bold",Justify="Center",Color=Color3.fromHex("#305dff"),Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Save() then WI:Notify({Title="已保存",Content="OK",Duration=3,Icon="solar:check-circle-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        t5:Space()
        t5:Button({Title="加载",Icon="solar:refresh-circle-bold",Justify="Center",Color=Color3.fromHex("#10C550"),Callback=function()
            if not CM then return end; local c=CM:CreateConfig("default",false)
            if c and c:Load() then WI:Notify({Title="已加载",Content="OK",Duration=3,Icon="solar:refresh-circle-bold"}) end end})
        t5:Space()
        t5:Button({Title="删除",Icon="solar:trash-bin-trash-bold",Justify="Center",Color=Color3.fromHex("#ff3040"),Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Delete() then WI:Notify({Title="已删除",Content="OK",Duration=3,Icon="solar:trash-bin-trash-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        spawn(function() wait(1) pcall(function() CM:CreateConfig("default",true) end) end)
    end)

    local t6=WN:Tab({Title="关于",Icon="solar:info-square-bold"})
    t6:Paragraph({Title="扔硬币 v2.5"}); t6:Divider()
    t6:Paragraph({Title="作者",Desc="b站英吉利超入_"})
    t6:Paragraph({Title="功能",Desc="自动投币/自动出售/自动升级/飞行/加速"})

    return sCoin, sMult
end

-- 启动
pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")

local PP = false
WI:Popup({
    Title="扔硬币 v2.5",
    Content="检测当前硬币 / 倍率控制投币 / 自动升级 / 自动出售",
    Buttons={{
        Title="加载",
        Callback=function() PP = true end,
        Variant="Primary"
    },{
        Title="取消",
        Callback=function() return end
    }}
})

while not PP do
    wait(0.1)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local now = tick()
    if now - toggleLock < 0.3 then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == KB.Toggle then
        toggleLock = now
        if WN then
            WN_visible = not WN_visible
            if WN_visible then
                pcall(function() WN:Open() end)
            else
                pcall(function() WN:Close() end)
            end
        end
    end
end)

LP.CharacterAdded:Connect(function()
    wait(1)
    if S.Fly then toggleFly(true) end
    if S.Speed then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = S.SpeedVal end
    end
end)

spawn(function()
    local sCoin, sMult = mW()
    print("[扔硬币] v2.5 运行中")
    local last = 0

    while true do
        if S.Speed then
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = S.SpeedVal end
        end
        if S.Fly then flyStep() end
        if S.AutoThrow then pcall(doThrow) end
        if S.AutoBuyCoin then pcall(doBuyCoin) end
        if S.AutoUpgradeLuck then pcall(doUpgradeLuck) end
        if S.AutoUpgradeValue then pcall(doUpgradeValue) end
        if S.AutoSell then pcall(doSell) end

        local now = tick()
        if now - last > 2 then
            last = now
            if sCoin then
                pcall(function() sCoin:SetTitle("硬币: " .. (getCoinName() or "无")) end)
            end
            if sMult then
                pcall(function() sMult:SetTitle("倍率: " .. formatNum(getMultiplier()) .. "x") end)
            end
        end
        wait(0.2)
    end
end)