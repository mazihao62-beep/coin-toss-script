--[[
    扔硬币 v2.3 — 自动投币/购买/升级/出售
    全中文 WindUI 7Tab
--]]

print("[硬币] v2.3 加载中...")

local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local C = game:GetService("CoreGui")

local LP = P.LocalPlayer
if not LP then return end
print("[硬币] 玩家: " .. LP.Name)

for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") and (g.Name == "A" or g.Name:find("Coin") or g.Name == "WindUI") then
        pcall(function() g:Destroy() end)
    end
end

print("[硬币] 加载 WindUI...")
local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[硬币] WindUI 失败"); return end
print("[硬币] WindUI OK")

local Events = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Events")
if not Events then Events = RS:FindFirstChild("Events") end

local CoinLanded = Events and Events:FindFirstChild("CoinLanded")
local BuyCoin = Events and Events:FindFirstChild("BuyCoin")
local SellAll = Events and Events:FindFirstChild("SellAll")
local RequestUpgrade = Events and Events:FindFirstChild("RequestUpgrade")

print("[硬币] CoinLanded=" .. (CoinLanded and "OK" or "NIL"))
print("[硬币] BuyCoin=" .. (BuyCoin and "OK" or "NIL"))
print("[硬币] SellAll=" .. (SellAll and "OK" or "NIL"))
print("[硬币] Upgrade=" .. (RequestUpgrade and "OK" or "NIL"))

local S = {
    AutoThrow = false, AutoBuy = false,
    AutoUpgradeLuck = false, AutoUpgradeCash = false,
    AutoSell = false, TargetMulti = 3.0,
    Speed = false, SpeedValue = 50,
    Fly = false, FlySpeed = 50,
    Particles = true, Acrylic = true, Transparent = false,
    ParticleColor = Color3.fromRGB(80, 170, 255)
}
local KB = { Toggle = "F4" }
local WN, CT = nil, {}
local PR, PS, PC = false, {}, nil
local WN_visible = false
local toggleLock = false

local function getHRP()
    local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

local function getMultiplier()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local ui = pg:FindFirstChild("UiFolder")
    if not ui then return nil end
    local main = ui:FindFirstChild("Main")
    if not main then return nil end
    local hud = main:FindFirstChild("HUD")
    if not hud then return nil end
    local bar = hud:FindFirstChild("ThrowBar")
    if not bar then return nil end
    local cm = bar:FindFirstChild("CurrentMulti")
    if not cm then return nil end
    return cm.Size.Y.Scale * 3
end

local function getSelectedCoin()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return "Paradox Coin" end
    local ui = pg:FindFirstChild("UiFolder")
    if not ui then return "Paradox Coin" end
    local main = ui:FindFirstChild("Main")
    if not main then return "Paradox Coin" end
    local hud = main:FindFirstChild("HUD")
    if not hud then return "Paradox Coin" end
    local coin = hud:FindFirstChild("Coin")
    if not coin then return "Paradox Coin" end
    local mainCoin = coin:FindFirstChild("Main")
    if not mainCoin then return "Paradox Coin" end
    local cn = mainCoin:FindFirstChild("CoinName")
    if not cn then return "Paradox Coin" end
    return cn.Text or "Paradox Coin"
end

-- 自动投币 Cobalt确认: CoinLanded:FireServer(multi, pos, coinName, nil, nil)
local function doThrow()
    if not S.AutoThrow or not CoinLanded then return end
    local hrp = getHRP()
    if not hrp then return end
    local multi = getMultiplier()
    if not multi then return end
    if multi >= S.TargetMulti then
        local coin = getSelectedCoin()
        local pos = hrp.Position + hrp.CFrame.LookVector * 15
        local ok, err = pcall(function()
            CoinLanded:FireServer(S.TargetMulti, pos, coin, nil, nil)
        end)
        if ok then
            print("[投币] " .. coin .. " @" .. string.format("%.1f", S.TargetMulti) .. "x")
        else
            print("[投币] 失败: " .. tostring(err))
        end
        wait(0.5)
    end
end

-- 自动购买硬币
local function doBuyCoins()
    if not S.AutoBuy or not BuyCoin then return end
    local ls = LP:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    if not cash then return end
    local coinsFolder = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Assets") and RS.Assets.Assets:FindFirstChild("Coins")
    if not coinsFolder then return end
    local pkg
    pcall(function() pkg = require(RS.Assets.Modules.ProgressionModule) end)
    for _, coinObj in ipairs(coinsFolder:GetChildren()) do
        local name = coinObj.Name
        local cost = pkg and pkg.Coins and pkg.Coins[name] and pkg.Coins[name].Cost
        if (cost and cash.Value >= cost) or not cost then
            local ok, err = pcall(function() BuyCoin:FireServer(name) end)
            if ok then print("[购买] " .. name .. (cost and " $" .. cost or "")); wait(0.2) end
        end
    end
end

-- 自动升级(运气) Cobalt确认: "Luck Multiplier"
local function doUpgradeLuck()
    if not S.AutoUpgradeLuck or not RequestUpgrade then return end
    local keys = {"Luck Multiplier", "MoreLuck", "InsaneLuck"}
    for _, key in ipairs(keys) do
        local ok, err = pcall(function() RequestUpgrade:FireServer(key) end)
        if ok then print("[升级-运气] " .. key); break end
        wait(0.2)
    end
end

-- 自动升级(钱倍率) Cobalt确认: "Value Multiplier"
local function doUpgradeCash()
    if not S.AutoUpgradeCash or not RequestUpgrade then return end
    local keys = {"Value Multiplier", "DoubleCash", "DoubleThrow"}
    for _, key in ipairs(keys) do
        local ok, err = pcall(function() RequestUpgrade:FireServer(key) end)
        if ok then print("[升级-钱] " .. key); break end
        wait(0.2)
    end
end

-- 自动出售
local function doSell()
    if not S.AutoSell or not SellAll then return end
    local ok, err = pcall(function() SellAll:FireServer() end)
    if ok then print("[出售] 已出售所有物品") end
end

-- 加速
local spd = nil
local function updateSpeed()
    if S.Speed then
        spd = true
        spawn(function() while spd do
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = S.SpeedValue end
            wait(0.5)
        end end)
    else
        spd = false
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end

-- 飞行
local fly = nil
local function updateFly()
    if S.Fly then
        fly = true
        spawn(function()
            local bv = Instance.new("BodyVelocity")
            local bg = Instance.new("BodyGyro")
            bv.MaxForce = Vector3.new(1e5,1e5,1e5); bv.P = 1e4
            bg.MaxTorque = Vector3.new(1e5,1e5,1e5); bg.P = 1e4
            while fly do
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then wait(0.1); return end
                bv.Parent = hrp; bg.Parent = hrp
                bg.CFrame = CFrame.lookAt(Vector3.new(), workspace.CurrentCamera.CFrame.LookVector)
                local m = Vector3.new()
                if UIS:IsKeyDown(Enum.KeyCode.W) then m = m + workspace.CurrentCamera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then m = m - workspace.CurrentCamera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then m = m - workspace.CurrentCamera.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then m = m + workspace.CurrentCamera.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then m = m + Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then m = m + Vector3.new(0,-1,0) end
                bv.Velocity = m.Magnitude > 0 and m.Unit * S.FlySpeed or Vector3.new()
                wait(0.03)
            end
            pcall(function() bv:Destroy() end); pcall(function() bg:Destroy() end)
        end)
    else
        fly = false
    end
end

-- 粒子
local function sP() end
local function xP() end

local function tc(n)
    local t={Dark=Color3.fromRGB(80,170,255),Light=Color3.fromRGB(60,130,210),Rose=Color3.fromRGB(255,130,170),Plant=Color3.fromRGB(70,210,130),Ocean=Color3.fromRGB(60,190,240),Sunset=Color3.fromRGB(255,160,70),Midnight=Color3.fromRGB(130,100,240),Forest=Color3.fromRGB(60,180,90),Lavender=Color3.fromRGB(190,140,255),Coral=Color3.fromRGB(255,140,90),Mint=Color3.fromRGB(80,230,190),Sky=Color3.fromRGB(100,190,255),Blood=Color3.fromRGB(230,90,80),Lemon=Color3.fromRGB(230,210,70),Cyber=Color3.fromRGB(0,235,210)}
    return t[n] or Color3.fromRGB(80,170,255)
end

local function mW()
    WN = WI:CreateWindow({
        Title="扔硬币 v2.3", Author="b站英吉利超入_", Icon="solar:wallet-bold",
        Size=UDim2.fromOffset(750,560), ToggleKey=Enum.KeyCode.F4,
        Folder="coin-toss-script", Acrylic=true, Resizable=false,
        ScrollBarEnabled=true, HideSearchBar=true,
        OnClose=function() xP(); WN_visible=false
            S.AutoThrow=false; S.AutoBuy=false; S.AutoUpgradeLuck=false; S.AutoUpgradeCash=false; S.AutoSell=false; S.Speed=false; S.Fly=false
            for _,ct in pairs(CT) do if ct and type(ct.Set)=="function" then pcall(function() ct:Set(false) end) end end end,
        OnOpen=function() WN_visible=true; if S.Particles then sP() end end
    })
    spawn(function() wait(0.8) pcall(function() if WN and WN.Parent then WN.Parent.ClipsDescendants=true end end) end)
    spawn(function() wait(0.5) pcall(function() WN:SetToggleKey(Enum.KeyCode.F4) end) end)

    local t1 = WN:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
    CT.AutoThrow = t1:Toggle({Flag="AutoThrow", Title="自动投币(自选倍率)", Value=false, Callback=function(v) S.AutoThrow=v end})
    CT.MultiTarget = t1:Slider({Flag="MultiTarget", Title="投币倍率(0~3x)", Step=0.1, Value={Min=0,Max=3,Default=3.0}, Width=200, IsTextbox=true, Callback=function(v) S.TargetMulti=v end})
    t1:Divider()
    CT.AutoBuy = t1:Toggle({Flag="AutoBuy", Title="自动购买硬币", Value=false, Callback=function(v) S.AutoBuy=v end})
    CT.AutoUpgradeLuck = t1:Toggle({Flag="AutoUpgradeLuck", Title="自动升级(运气)", Value=false, Callback=function(v) S.AutoUpgradeLuck=v end})
    CT.AutoUpgradeCash = t1:Toggle({Flag="AutoUpgradeCash", Title="自动升级(钱倍率)", Value=false, Callback=function(v) S.AutoUpgradeCash=v end})
    CT.AutoSell = t1:Toggle({Flag="AutoSell", Title="自动出售物品", Value=false, Callback=function(v) S.AutoSell=v end})
    t1:Divider()
    CT.Speed = t1:Toggle({Flag="Speed", Title="加速", Value=false, Callback=function(v) S.Speed=v; updateSpeed() end})
    CT.SpeedV = t1:Slider({Flag="SpeedV", Title="速度", Step=5, Value={Min=16,Max=120,Default=50}, Width=200, IsTextbox=true, Callback=function(v) S.SpeedValue=v end})
    CT.Fly = t1:Toggle({Flag="Fly", Title="飞行", Value=false, Callback=function(v) S.Fly=v; updateFly() end})
    CT.FlyV = t1:Slider({Flag="FlyV", Title="飞行速度", Step=10, Value={Min=10,Max=150,Default=50}, Width=200, IsTextbox=true, Callback=function(v) S.FlySpeed=v end})

    local t2 = WN:Tab({Title="快捷键", Icon="solar:settings-bold"})
    t2:Keybind({Flag="ToggleKey", Title="窗口开关", Value="F4", Callback=function(v) KB.Toggle=v; pcall(function() WN:SetToggleKey(v) end) end})

    local t3 = WN:Tab({Title="UI设置", Icon="solar:monitor-bold"})
    CT.Particles = t3:Toggle({Flag="Particles", Title="粒子背景", Value=true, Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t3:Toggle({Flag="Acrylic", Title="毛玻璃", Value=true, Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t3:Toggle({Flag="Transparent", Title="透明", Value=false, Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Dark","Light","Rose","Plant","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t3:Dropdown({Flag="Theme", Title="主题", Values=tns, Value="Dark", Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t4 = WN:Tab({Title="信息统计", Icon="solar:chart-bold"})
    local sCash = t4:Paragraph({Title="现金: ?"})
    local sCoin = t4:Paragraph({Title="当前硬币: ?"})
    local sMulti = t4:Paragraph({Title="倍率: ?"})

    local t5 = WN:Tab({Title="配置管理", Icon="solar:diskette-bold"})
    pcall(function()
        local CM = WN.ConfigManager; if not CM then return end
        local cni = t5:Input({Flag="CN", Title="配置名称", Value="default", Icon="solar:file-text-bold", Callback=function(v) end})
        t5:Space(); local AC={}; pcall(function() AC=CM:AllConfigs() end)
        local DV=nil; for _,v in ipairs(AC) do if v=="default" then DV="default"; break end end
        local ACD=t5:Dropdown({Title="已有配置", Values=AC, Value=DV, Callback=function(v) if v then pcall(function() cni:Set(v) end) end end})
        t5:Space()
        t5:Button({Title="保存", Icon="solar:check-circle-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Save() then WI:Notify({Title="已保存", Content="OK", Duration=3}); pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        t5:Space()
        t5:Button({Title="加载", Icon="solar:refresh-circle-bold", Justify="Center", Color=Color3.fromHex("#10C550"), Callback=function()
            if not CM then return end; local c=CM:CreateConfig("default",false)
            if c and c:Load() then WI:Notify({Title="已加载", Content="OK", Duration=3}) end end})
        t5:Space()
        t5:Button({Title="删除", Icon="solar:trash-bin-trash-bold", Justify="Center", Color=Color3.fromHex("#ff3040"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Delete() then WI:Notify({Title="已删除", Content="OK", Duration=3}); pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        spawn(function() wait(1) pcall(function() CM:CreateConfig("default",true) end) end)
    end)

    local t6 = WN:Tab({Title="关于", Icon="solar:info-square-bold"})
    t6:Paragraph({Title="扔硬币 v2.3"}); t6:Divider()
    t6:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t6:Paragraph({Title="说明", Desc="自动投币/购买/升级(运气+钱倍率)/出售 + 飞行加速"})
    return sCash, sCoin, sMulti
end

pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")

UIS.InputBegan:Connect(function(input, gpe)
    if gpe or toggleLock then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local kn = input.KeyCode and input.KeyCode.Name or ""
        if kn == KB.Toggle and WN then
            toggleLock = true
            WN_visible = not WN_visible
            pcall(function() if WN_visible then WN:Open() else WN:Close() end end)
            wait(0.3)
            toggleLock = false
        end
    end
end)

local PP = false
WI:Popup({
    Title="扔硬币 v2.3",
    Content="自动投币/购买/升级/出售 + 飞行加速\n快捷键F4切换窗口",
    Buttons={{Title="加载", Callback=function() PP=true end, Variant="Primary"},{Title="取消", Callback=function() end}}
})
while not PP do wait(0.1) end

spawn(function()
    local sCash, sCoin, sMulti = mW()
    print("[硬币] v2.3 运行中")
    local last = 0
    while true do
        if S.AutoThrow then pcall(doThrow) end
        wait(0.1)
        if S.AutoBuy then pcall(doBuyCoins) wait(0.3) end
        if S.AutoUpgradeLuck then pcall(doUpgradeLuck) wait(0.3) end
        if S.AutoUpgradeCash then pcall(doUpgradeCash) wait(0.3) end
        if S.AutoSell then pcall(doSell) wait(0.3) end
        local now = tick()
        if now - last > 2 then
            last = now
            local ls = LP:FindFirstChild("leaderstats")
            local cash = ls and ls:FindFirstChild("Cash") and ls.Cash.Value or "?"
            local coin = getSelectedCoin()
            local multi = getMultiplier() and string.format("%.1fx", getMultiplier()) or "?"
            if sCash then pcall(function() sCash:SetTitle("现金: $" .. tostring(cash)) end) end
            if sCoin then pcall(function() sCoin:SetTitle("当前硬币: " .. tostring(coin)) end) end
            if sMulti then pcall(function() sMulti:SetTitle("倍率: " .. tostring(multi)) end) end
        end
        wait(0.5)
    end
end)