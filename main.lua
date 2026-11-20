-- Fruit Battlegrounds (by wvoxu): auto spinner + skill spam in one window.
-- The UI library is loaded from LIB_URL (main.lua in the UI Library repo); its credits are in its header.

-- Link to this script (raw), so it restarts itself after moving to another world.
-- Leave it empty if the script is in your executor's autoexec folder instead.
local SCRIPT_URL = ""

local LIB_URL = "https://raw.githubusercontent.com/wvoxu/UI-Library/main/main.lua"

local sharedEnv = (getgenv and getgenv()) or _G
-- close older copies first (this one, and the two separate scripts)
for _, key in ipairs({ "__WvoxuFruitBattlegroundsCleanup", "__WvoxuSkillSpamCleanup", "__WvoxuFruitSpinnerCleanup" }) do
    if sharedEnv[key] then
        pcall(sharedEnv[key])
        sharedEnv[key] = nil
    end
end

local UILib
do
    local okGet, body = pcall(game.HttpGet, game, LIB_URL .. "?v=" .. os.time())
    if not okGet or type(body) ~= "string" or body == "" then
        warn("[Fruit Battlegrounds] couldn't download the UI library from " .. LIB_URL .. ": " .. tostring(body))
        return
    end
    local chunk, compileError = loadstring(body)
    if not chunk then
        warn("[Fruit Battlegrounds] the UI library didn't compile: " .. tostring(compileError))
        return
    end
    local okRun, library = pcall(chunk)
    if not okRun or type(library) ~= "table" or not library.Window then
        warn("[Fruit Battlegrounds] the UI library didn't give a window library: " .. tostring(library))
        return
    end
    UILib = library
end

local Window = UILib:Window({
    Title = "Fruit Battlegrounds",
    Subtitle = "by wvoxu",
    Key = Enum.KeyCode.RightShift, -- can be changed in Settings, it's remembered
    Folder = "wvoxu/FruitBattlegrounds",
    Size = Vector2.new(680, 470),
    MinSize = Vector2.new(520, 320),
    Splash = false,
    Logo = "W",
    KeepPrevious = true,
})

----------------------------------------------------------------------
-- SPINNER
----------------------------------------------------------------------
local function runSpinner()
local HttpService = game:GetService("HttpService")
local saved = HttpService:JSONDecode("{}") -- decoded so editors treat it as a flexible table
local saveSettings = function() end
local env = sharedEnv
local SPIN_COST = 50    -- gems per spin (re-measured after the first spin)
local SPIN_DELAY = 5.1  -- seconds between normal spins
local FAST_DELAY = 1.1  -- seconds between Fast spins (server accepts about one per second)

-- rarest first, so the good stuff is at the top of the list
local RARITIES = { "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

local FRUITS_BY_RARITY = {
    Mythic    = { "Lightning", "Nika", "DragonV2", "Soul", "DarkxQuake", "Okuchi", "DoughV2", "LeopardV2", "Impact", "OpeV2" },
    Legendary = { "Quake", "Gravity", "Phoenix", "TSRubber", "Dragon", "Dough", "Magnet", "Leopard", "Ope", "Venom", "MagmaV2", "IceV2", "LightV2", "FlameV2" },
    Epic      = { "Light", "Flame", "Magma", "Paw", "String", "Love", "Snow" },
    Rare      = { "Bomb", "Ice", "Darkness", "Ash" },
    Uncommon  = { "Smoke", "Rubber", "Falcon", "Gas" },
    Common    = { "Barrier", "Chop", "Sand" },
}

local RARITY_COLORS = {
    Mythic    = 0xffeb6a,
    Legendary = 0xff7e39,
    Epic      = 0xd465e5,
    Rare      = 0x478dff,
    Uncommon  = 0x7aff9d,
    Common    = 0x808080,
}

-- official names, where known (only used in the webhook text)
local OFFICIAL = {
    Barrier = "Bari Bari no Mi", Chop = "Bara Bara no Mi", Sand = "Suna Suna no Mi",
    Smoke = "Moku Moku no Mi", Rubber = "Gomu Gomu no Mi", Gas = "Gasu Gasu no Mi",
    Falcon = "Tori Tori no Mi, Model: Falcon", Bomb = "Bomu Bomu no Mi", Ice = "Hie Hie no Mi",
    Darkness = "Yami Yami no Mi", Light = "Pika Pika no Mi", Flame = "Mera Mera no Mi",
    Paw = "Nikyu Nikyu no Mi", Magma = "Magu Magu no Mi", String = "Ito Ito no Mi",
    Quake = "Gura Gura no Mi", Magnet = "Jiki Jiki no Mi", Gravity = "Zushi Zushi no Mi",
    Phoenix = "Tori Tori no Mi, Model: Phoenix", TSRubber = "Gomu Gomu no Mi-(Timeskip)",
    Leopard = "Neko Neko no Mi, Model: Leopard", Dough = "Mochi Mochi no Mi",
    Dragon = "Uo Uo no Mi, Model: Seiryu", Lightning = "Goro Goro no Mi", Ope = "Ope Ope no Mi",
    Venom = "Doku Doku no Mi", Nika = "Hito Hito no Mi, Model: Nika",
    Ash = "Hai Hai no Mi", Love = "Mero Mero no Mi", Snow = "Yuki Yuki no Mi", Soul = "Soru Soru no Mi",
    Okuchi = "Inu Inu no Mi, Model: Okuchi no Makami",
    DarkxQuake = "Yami Yami no Mi + Gura Gura no Mi",
    Impact = "Garp's fighting style",
    DragonV2 = "Uo Uo no Mi, Model: Seiryu (V2)", DoughV2 = "Mochi Mochi no Mi (V2)",
    LeopardV2 = "Neko Neko no Mi, Model: Leopard (V2)", OpeV2 = "Ope Ope no Mi (V2)",
    MagmaV2 = "Magu Magu no Mi (V2)", IceV2 = "Hie Hie no Mi (V2)",
    LightV2 = "Pika Pika no Mi (V2)", FlameV2 = "Mera Mera no Mi (V2)",
}

-- lowercase, no spaces/dashes: "Dragon V2" and "DragonV2" both match
local function norm(s)
    return (tostring(s):lower():gsub("[%s_%-]", ""))
end

local function normRarity(s)
    local n = norm(s)
    if n == "mythical" then n = "mythic" end
    return n
end

local FRUIT_NAMES = {}   -- for the dropdown, rarest first
local FRUIT_INFO = {}    -- norm(name) -> { name, rarity }
for _, rarity in ipairs(RARITIES) do
    for _, name in ipairs(FRUITS_BY_RARITY[rarity]) do
        table.insert(FRUIT_NAMES, name)
        FRUIT_INFO[norm(name)] = { name = name, rarity = rarity }
    end
end

----------------------------------------------------------------------
-- GAME HELPERS
----------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local data = player:WaitForChild("MAIN_DATA")

-- anti-AFK
for _, connection in pairs(getconnections(player.Idled)) do
    connection:Disable()
end

local httpRequest = (syn and syn.request) or http_request or request

local function invoke(action, args)
    return ReplicatedStorage.Replicator:InvokeServer("FruitsHandler", action, args)
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------

local running = false
local runId = 0
local slotNumber = tonumber(env.fruitslot) or tonumber(saved.slot) or 1
local wantedFruits = {}
local wantedRarities = {}
local stopOnUnknown = saved.stopOnUnknown ~= false
local fastSpin = saved.fastSpin == true
local webhookUrl = type(saved.webhook) == "string" and saved.webhook or ""
if type(env.webhookslink) == "string" and env.webhookslink ~= "link here" then
    webhookUrl = env.webhookslink
end

-- pre-fill: the old globals if they were set, otherwise whatever was saved last time
local presetFruits, presetRarities = {}, {}
local fruitSource = (type(env.fruits) == "table" and env.fruits) or (type(saved.fruits) == "table" and saved.fruits) or {}
local raritySource = (type(env.rarity) == "table" and env.rarity) or (type(saved.rarities) == "table" and saved.rarities) or {}
do
    for _, name in pairs(fruitSource) do
        local info = FRUIT_INFO[norm(name)]
        table.insert(presetFruits, info and info.name or tostring(name))
    end
end
do
    for _, r in pairs(raritySource) do
        for _, canonical in ipairs(RARITIES) do
            if normRarity(r) == norm(canonical) then
                table.insert(presetRarities, canonical)
            end
        end
    end
end
for _, v in ipairs(presetFruits) do table.insert(wantedFruits, v) end
for _, v in ipairs(presetRarities) do table.insert(wantedRarities, v) end


----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------

-- Saving is handled by the UI. The old json file is only read once to fill the first Default config.

sharedEnv.__WvoxuFruitSpinnerCleanup = function()
    running = false
    runId = runId + 1
end

local Tab = Window:Tab({ Name = "Spinner", Icon = "Misc" })

local statusGroup = Tab:Group("Status")
local statusRow = statusGroup:Label("Status: Idle")
local spinRow = statusGroup:Label("Spin: -")
local gotRow = statusGroup:Label("Got: -")
local gemsRow = statusGroup:Label("Gems left: -")

local autoToggle

-- setStatus("Spinning...", { "Spin: 3", "Got: Gas (Uncommon)", "Gems left: 1234 (24 spins)" })
-- A call without the second argument keeps the last spin's lines; {} clears them.
local function setStatus(text, info)
    statusRow:Set("Status: " .. text)
    if info ~= nil then
        spinRow:Set(info[1] or "Spin: -")
        gotRow:Set(info[2] or "Got: -")
        gemsRow:Set(info[3] or "Gems left: -")
    end
end

local function notify(title, text)
    Window:Notify({ Title = title, Text = text, Duration = 3 })
end

----------------------------------------------------------------------
-- WEBHOOK
----------------------------------------------------------------------
-- returns true on success, or false + a reason
local function sendWebhook(embed)
    if webhookUrl == "" then return false, "no webhook set" end
    if not httpRequest then return false, "executor has no request function" end
    local ok, response = pcall(function()
        return httpRequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["content-type"] = "application/json" },
            Body = HttpService:JSONEncode({ embeds = { embed } }),
        })
    end)
    if not ok then return false, tostring(response) end
    local code = type(response) == "table" and (response.StatusCode or response.status_code)
    if code and (code < 200 or code >= 300) then
        -- Discord says how long to wait when it's rate limiting
        local wait
        local body = type(response) == "table" and response.Body
        if code == 429 and type(body) == "string" then
            local decoded = select(2, pcall(function() return HttpService:JSONDecode(body) end))
            wait = type(decoded) == "table" and tonumber(decoded.retry_after) or nil
        end
        return false, "HTTP " .. tostring(code), wait
    end
    return true
end

-- Messages go out one at a time and get retried, so a rate limit or a bad moment doesn't drop a spin
local webhookQueue = {}
local webhookWorker = false
local function queueWebhook(embed)
    if webhookUrl == "" then return end
    table.insert(webhookQueue, embed)
    if webhookWorker then return end
    webhookWorker = true
    task.spawn(function()
        while #webhookQueue > 0 do
            local item = webhookQueue[1]
            local sent = false
            for attempt = 1, 6 do
                local ok, reason, wait = sendWebhook(item)
                if ok then sent = true break end
                if reason == "no webhook set" then break end
                task.wait((wait or (attempt * 1.5)) + 0.2)
            end
            if not sent then warn("[Fruit Battlegrounds] a webhook message couldn't be sent") end
            table.remove(webhookQueue, 1)
            task.wait(0.4)
        end
        webhookWorker = false
    end)
end

----------------------------------------------------------------------
-- SPIN LOOP
----------------------------------------------------------------------
local function toSet(list, normalizer)
    local set = {}
    for _, v in pairs(list) do
        set[normalizer(v)] = true
    end
    return set
end

local function spinLoop(myRun)
    local slot = slotNumber
    local gemsStart = data.Gems.Value
    local cost = SPIN_COST

    if gemsStart < cost then
        running = false
        setStatus("Not enough gems")
        notify("Fruit Spinner", "Not enough gems to spin")
        return
    end

    local spinsStart = math.floor(gemsStart / cost)
    invoke("SwitchSlot", { Slot = slot })

    -- safety net: if the fruit already in the slot is one you want, don't spin it away
    task.wait(0.5)
    do
        local current = tostring(data.Slots[tostring(slot)].Value)
        local currentInfo = FRUIT_INFO[norm(current)]
        local keep = nil
        if toSet(wantedFruits, norm)[norm(current)] then
            keep = current
        elseif currentInfo and toSet(wantedRarities, normRarity)[norm(currentInfo.rarity)] then
            keep = current .. " (" .. currentInfo.rarity .. ")"
        end
        if keep then
            running = false
            local reason = "Slot " .. slot .. " already has " .. keep
            setStatus("Stopped: " .. reason)
            notify("Fruit Spinner", reason)
            print("Script has stopped, " .. reason)
            return
        end
    end

    local spins = 0
    while running and runId == myRun do
        task.wait(fastSpin and FAST_DELAY or SPIN_DELAY)
        if not (running and runId == myRun) then return end -- stopped while waiting

        local gemsBefore = data.Gems.Value
        invoke("Spin", fastSpin and { Type = "Fast" } or {})
        spins = spins + 1

        local inGameName = tostring(data.Slots[tostring(slot)].Value)
        local gemsLeft = data.Gems.Value
        if spins == 1 and gemsBefore - gemsLeft > 0 then
            cost = gemsBefore - gemsLeft -- use what the game actually charged
        end

        local info = FRUIT_INFO[norm(inGameName)]
        local rarity = info and info.rarity or "Unknown"
        local official = OFFICIAL[inGameName]
        local spinsLeft = math.floor(gemsLeft / cost)
        local gemsSpent = gemsStart - gemsLeft
        local spinsSpent = math.floor(gemsSpent / cost)

        print("You got " .. inGameName .. " [Rarity:" .. rarity .. "]")
        setStatus("Spinning...", {
            "Spin: " .. spins,
            "Got: " .. inGameName .. " (" .. rarity .. ")",
            "Gems left: " .. gemsLeft .. " (" .. spinsLeft .. " spins)",
        })

        local description = "**Slot : " .. tostring(slot)
        if official then
            description = description .. "\nOfficial name: " .. official
        end
        description = description
            .. "\nIn-game name: " .. inGameName
            .. "\nRarity: " .. rarity
            .. "\nOriginal Gems: " .. gemsStart
            .. "\nOriginal Spins: " .. spinsStart
            .. "\nGems Left: " .. gemsLeft
            .. "\nSpin Left: " .. spinsLeft
            .. "\nGems Spent: " .. gemsSpent
            .. "\nSpin Spent: " .. spinsSpent .. "**"

        queueWebhook({
            title = "You Opened a New Fruit!!!",
            color = RARITY_COLORS[rarity] or 0xffffff,
            description = description,
        })

        -- check against whatever is selected right now
        local fruitSet = toSet(wantedFruits, norm)
        local raritySet = toSet(wantedRarities, normRarity)
        local reason = nil
        if fruitSet[norm(inGameName)] then
            reason = "Got " .. inGameName
        elseif info and raritySet[norm(info.rarity)] then
            reason = "Got " .. inGameName .. " (" .. rarity .. ")"
        elseif not info and stopOnUnknown then
            reason = "Got an unknown fruit: " .. inGameName
        elseif gemsLeft < cost then
            reason = "Out of gems"
        end

        if reason then
            running = false
            setStatus("Stopped: " .. reason)
            notify("Fruit Spinner stopped", reason)
            print("Script has stopped")
            queueWebhook({ title = "Script has stopped", description = reason, color = 0xffffff })
            return
        end
    end
end

local function startSpinning()
    if running then return end
    running = true
    runId = runId + 1
    local myRun = runId
    setStatus("Spinning...", {})

    task.spawn(function()
        local ok, err = pcall(spinLoop, myRun)
        if not ok then
            running = false
            setStatus("Error: " .. tostring(err))
            notify("Fruit Spinner error", tostring(err))
        end
        -- finished on its own (not turned off by hand): flip the switch back
        if runId == myRun and autoToggle then
            autoToggle:Set(false)
        end
    end)
end

local function stopSpinning()
    if not running then return end
    running = false
    runId = runId + 1 -- lets a loop that's mid-wait know it should quit
    setStatus("Stopped")
end


----------------------------------------------------------------------
-- CONTROLS
----------------------------------------------------------------------
local spinGroup = Tab:Group("Spin")

autoToggle = spinGroup:Toggle({
    Name = "Auto Spin",
    Description = "Keeps spinning until you land a fruit or rarity you picked.",
    Default = false,
    Callback = function(state)
        if state then
            startSpinning()
        else
            stopSpinning()
        end
    end,
})

spinGroup:Toggle({
    Name = "Fast Spin",
    Flag = "fastSpin",
    Description = "Faster spin, about 5x quicker.",
    Default = fastSpin,
    Callback = function(state)
        fastSpin = state
        saveSettings()
    end,
})

spinGroup:Input({
    Name = "Fruit Slot",
    Flag = "slot",
    Placeholder = "1",
    Default = tostring(slotNumber),
    Numeric = true,
    Callback = function(n)
        if n and n >= 1 then
            slotNumber = math.floor(n)
            saveSettings()
        else
            notify("Fruit Battlegrounds", "Slot has to be a number")
        end
    end,
})

local targetGroup = Tab:Group({ Name = "Stop when you get", Description = "Won't spin if your slot already has one of these." })

targetGroup:Dropdown({
    Name = "Wanted Fruits",
    Flag = "wantedFruits",
    Options = FRUIT_NAMES,
    Default = presetFruits,
    Multi = true,
    Callback = function(selected)
        wantedFruits = selected
        saveSettings()
    end,
})

targetGroup:Dropdown({
    Name = "Stop at Rarity",
    Flag = "wantedRarities",
    Options = RARITIES,
    Default = presetRarities,
    Multi = true,
    Callback = function(selected)
        wantedRarities = selected
        saveSettings()
    end,
})

targetGroup:Toggle({
    Name = "Stop on Unknown Fruit",
    Flag = "stopOnUnknown",
    Description = "Stops if you pull a fruit that's not in the list.",
    Default = stopOnUnknown,
    Callback = function(state)
        stopOnUnknown = state
        saveSettings()
    end,
})

local hookGroup = Tab:Group("Webhook")

hookGroup:Input({
    Name = "Webhook URL",
    Flag = "webhook",
    Placeholder = "https://discord.com/api/webhooks/...",
    Default = webhookUrl,
    Callback = function(text)
        webhookUrl = (text or ""):gsub("%s", "")
        saveSettings()
    end,
})

hookGroup:Button({
    Name = "Test Webhook",
    Callback = function()
        task.spawn(function()
            local ok, reason = sendWebhook({
                title = "Webhook test",
                description = "Fruit Battlegrounds can reach this webhook.",
                color = 0xffffff,
            })
            if ok then
                notify("Webhook", "Test message sent")
            else
                notify("Webhook failed", tostring(reason))
            end
        end)
    end,
})

Window:OnUnload(function()
    running = false
    runId = runId + 1
end)


end
local ok_runSpinner, err_runSpinner = pcall(runSpinner)
if not ok_runSpinner then warn("[Fruit Battlegrounds] SPINNER failed: " .. tostring(err_runSpinner)) end

----------------------------------------------------------------------
-- SKILL SPAM
----------------------------------------------------------------------
local function runSkillSpam()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local skillRemote = ReplicatedStorage:WaitForChild("ReplicatorNoYield", 10) -- skills and aiming data
if not skillRemote then
    warn("[Fruit Battlegrounds] couldn't find ReplicatorNoYield in ReplicatedStorage")
    return
end

local DEBUG = true
local function dbg(...)
    if DEBUG then print("[Fruit Battlegrounds]", ...) end
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local SLOTS = { "1", "2", "3", "4", "5", "G" } -- the hotbar buttons in the game's UI
local alive = true
local enabled = false
local useSlot = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, G = false }
local lastAttempt = {}

----------------------------------------------------------------------
-- READING THE GAME
----------------------------------------------------------------------
local function currentFruit()
    local char = LocalPlayer.Character
    local form = char and char:GetAttribute("Form")
    if type(form) == "string" and form ~= "" then return form end
    -- some forms don't set Form; look at the other attributes, then the last cast
    for _, holder in ipairs({ char, LocalPlayer }) do
        if holder then
            for name, v in pairs(holder:GetAttributes()) do
                local n = name:lower()
                if type(v) == "string" and v ~= "" and (n == "fruit" or n == "currentfruit" or n == "equippedfruit") then return v end
            end
        end
    end
    return nil
end

local function hotbar()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local ui = gui and gui:FindFirstChild("UI")
    return ui and ui:FindFirstChild("Hotbar")
end

-- "Finger Pistol Barrage" on the skill bar is sent to the server as FingerPistolBarrage
local function skillOfSlot(slot)
    local bar = hotbar()
    local btn = bar and bar:FindFirstChild(slot)
    if not btn then return nil end
    local title = btn:FindFirstChild("Title")
    local locked = btn:FindFirstChild("Locked")
    if locked and locked:IsA("GuiObject") and locked.Visible then return nil end
    if not (title and title:IsA("TextLabel")) or title.Text == "" then return nil end
    return (title.Text:gsub("[^%w]", "")), btn
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
sharedEnv.__WvoxuSkillSpamCleanup = function()
    alive = false
    enabled = false
end

local Tab = Window:Tab({ Name = "Autofarm", Icon = "Misc" })

local statusGroup = Tab:Group("Status")
local statusRow = statusGroup:Label("Status: Off")
local fruitRow = statusGroup:Label("Fruit: ...")

local mainGroup = Tab:Group("Auto Skills")
mainGroup:Toggle({
    Name = "Auto Skills",
    Flag = "autoSkills", -- remembered, so farming carries on after changing worlds
    Default = false,
    Keybind = Enum.KeyCode.X,
    Callback = function(state)
        enabled = state
        statusRow:Set("Status: " .. (state and "On" or "Off"))
        Window:Notify({ Title = "Autofarm " .. (state and "on" or "off"), Text = state and "Using skills" or "Stopped", Duration = 2 })
    end,
})
local slotGroup = Tab:Group("Skills")
for _, slot in ipairs(SLOTS) do
    slotGroup:Toggle({
        Name = "Use slot " .. slot,
        Flag = "use" .. slot,
        Default = useSlot[slot],
        Callback = function(state) useSlot[slot] = state end,
    })
end

----------------------------------------------------------------------
-- BUILDING WHAT THE GAME EXPECTS
----------------------------------------------------------------------
-- no aiming: the ray just points straight ahead of your character, in the same shape as the game's own mouse ray
local function buildMouseRay()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = root and root.Position or Vector3.zero
    local dir = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
    local position = origin + dir * 50
    return {
        Origin = origin,
        Direction = dir * 300,
        Instance = nil,
        Position = position,
        Normal = Vector3.new(0, 1, 0),
        Distance = 50,
        Material = Enum.Material.Air,
    }
end

local function rootCFrame()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root and root.CFrame
end

local function useSkill(fruit, skill)
    skillRemote:FireServer(fruit, skill, { MouseRay = buildMouseRay(), RootCF = rootCFrame() })
end

-- every frame: each ticked skill is cast again. Each skill runs on its own
local busy = {}
local CAST_GAP = 0.12 -- seconds between tries for each skill; no cooldown tracking, the server ignores early ones
local RunService = game:GetService("RunService")
local skillConn = RunService.Heartbeat:Connect(function()
    if not (enabled and alive) then return end
    local fruit = currentFruit()
    if not fruit then return end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not (humanoid and humanoid.Health > 0) then return end
    for _, slot in ipairs(SLOTS) do
        local skill = skillOfSlot(slot)
        if useSlot[slot] and skill and not busy[skill] then
            if os.clock() - (lastAttempt[skill] or 0) >= CAST_GAP then
                lastAttempt[skill] = os.clock()
                busy[skill] = true
                task.spawn(function()
                    pcall(useSkill, fruit, skill)
                    busy[skill] = nil
                end)
            end
        end
    end
end)

----------------------------------------------------------------------
-- STAMINA / PLAY / TELEPORT
----------------------------------------------------------------------
local resetOnLowStamina = true
local resetBelow = 20
local autoPlay = true
local teleportOn = true
-- the worlds: you can go to the next one at the level shown. Each has its own spot to teleport to.
local WORLDS = {
    { placeId = 9224601490,  level = 0,   spot = Vector3.new(-568, 640, -1338) },
    { placeId = 16190471004, level = 100, spot = Vector3.new(-224, -394, -2728) },
    { placeId = 12413901502, level = 200, spot = Vector3.new(-1924, 265, 850) },
}
local currentWorld = nil
for i, w in ipairs(WORLDS) do
    if game.PlaceId == w.placeId then currentWorld = i end
end
local worldSpots = {}
for i, w in ipairs(WORLDS) do worldSpots[i] = w.spot end
local teleportPos = worldSpots[currentWorld or 1]
local autoWorld = true
local keepPosition = false
local maxDrift = 15

local function parsePos(text)
    local nums = {}
    for n in tostring(text):gmatch("%-?%d+%.?%d*") do table.insert(nums, tonumber(n)) end
    if #nums >= 3 then return Vector3.new(nums[1], nums[2], nums[3]) end
    return nil
end

local survivalGroup = Tab:Group("Survival")
survivalGroup:Toggle({
    Name = "Reset on low stamina",
    Flag = "resetStamina",
    Default = resetOnLowStamina,
    Callback = function(state) resetOnLowStamina = state end,
})
survivalGroup:Slider({
    Name = "Reset below",
    Flag = "resetBelow",
    Min = 0, Max = 60, Default = resetBelow, Step = 1, Suffix = "%",
    Callback = function(v) resetBelow = v end,
})
survivalGroup:Toggle({
    Name = "Auto Play",
    Flag = "autoPlay",
    Default = autoPlay,
    Callback = function(state) autoPlay = state end,
})
survivalGroup:Toggle({
    Name = "Teleport after spawning",
    Flag = "teleportEnabled",
    Default = teleportOn,
    Callback = function(state) teleportOn = state end,
})
local posInputs = {}
local function spotText(v) return string.format("%.1f, %.1f, %.1f", v.X, v.Y, v.Z) end
for i, w in ipairs(WORLDS) do
    posInputs[i] = survivalGroup:Input({
        Name = "Teleport to (World " .. i .. ")",
        Flag = i == 1 and "teleportCoords" or ("teleportCoords" .. i),
        Default = spotText(w.spot),
        Placeholder = "-574, 746, -961",
        Callback = function(value)
            worldSpots[i] = parsePos(value) or w.spot
            if (currentWorld or 1) == i then teleportPos = worldSpots[i] end
        end,
    })
end
survivalGroup:Button({
    Name = "Use my position",
    Callback = function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local p = root.Position
        posInputs[currentWorld or 1]:Set(spotText(p))
    end,
})
survivalGroup:Toggle({
    Name = "Keep teleporting back",
    Flag = "keepPosition",
    Default = keepPosition,
    Callback = function(state) keepPosition = state end,
})
survivalGroup:Slider({
    Name = "Teleport back when further than",
    Flag = "maxDrift",
    Min = 3, Max = 100, Default = maxDrift, Step = 1, Suffix = " studs",
    Callback = function(v) maxDrift = v end,
})

-- stamina: the number lives on Character.Stats, the max is in the bar text on screen ("568/568")
local maxSeen = 0
local function readStamina()
    local char = LocalPlayer.Character
    local stats = char and char:FindFirstChild("Stats")
    local cur = stats and stats:GetAttribute("Stamina")
    local max
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local ui = gui and gui:FindFirstChild("UI")
    local hud = ui and ui:FindFirstChild("HUD")
    local bars = hud and hud:FindFirstChild("Bars")
    local label = bars and bars:FindFirstChild("ProgressStamina")
    if label and label:IsA("TextLabel") then
        local c, m = label.Text:match("(%d+%.?%d*)%s*/%s*(%d+%.?%d*)")
        if c and m then
            cur = cur or tonumber(c)
            max = tonumber(m)
        end
    end
    if type(cur) ~= "number" then return nil end
    if not max then
        maxSeen = math.max(maxSeen, cur) -- no max on screen: use the highest value seen
        max = maxSeen
    end
    if max <= 0 then return nil end
    return cur / max
end

-- a real mouse click on the button, so the game runs its whole Play sequence (the fade, hiding the menu, etc.)
local function clickButton(btn, mode)
    local VIM = game:GetService("VirtualInputManager")
    local sg = btn:FindFirstAncestorWhichIsA("ScreenGui")
    local inset = game:GetService("GuiService"):GetGuiInset()
    local guess = (sg and sg.IgnoreGuiInset) and Vector2.new(0, 0) or inset
    -- the click position is unclear on some UIs, so the retries try each way
    local offset = ({ guess, (guess.Y == 0) and inset or Vector2.new(0, 0), Vector2.new(0, 0), inset })[(mode - 1) % 4 + 1]
    local p = btn.AbsolutePosition + btn.AbsoluteSize / 2 + offset
    VIM:SendMouseMoveEvent(p.X, p.Y, game)
    task.wait(0.05)
    VIM:SendMouseMoveEvent(p.X + 1, p.Y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(p.X + 1, p.Y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(p.X + 1, p.Y, 0, false, game, 0)
end

local function findPlayButton()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local menu = gui and gui:FindFirstChild("UI") and gui.UI:FindFirstChild("MainMenu")
    if not menu then return nil end
    for _, d in ipairs(menu:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local text = d:IsA("TextButton") and d.Text or ""
            if d.Name:lower() == "play" or text:lower():gsub("%s", "") == "play" then return d end
            local label = d:FindFirstChildWhichIsA("TextLabel")
            if label and label.Text:lower():gsub("%s", "") == "play" then return d end
        end
    end
    return nil
end

-- on the menu when Spawned isn't set, or when the HUD or the skill bar is hidden (the game shows them when you spawn)
local function uiPart(name)
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local ui = gui and gui:FindFirstChild("UI")
    return ui and ui:FindFirstChild(name)
end
local function menuReason()
    local char = LocalPlayer.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return "no character" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return "dead" end
    if LocalPlayer:GetAttribute("Spawned") ~= true then return "Spawned is off" end
    local hud, bar = uiPart("HUD"), uiPart("Hotbar")
    if hud and hud:IsA("GuiObject") and not hud.Visible then return "HUD hidden" end
    if bar and bar:IsA("GuiObject") and not bar.Visible then return "skill bar hidden" end
    return nil
end
local function inMenu()
    return menuReason() ~= nil
end

local stateRow = statusGroup:Label("State: ...")
local lastFruitText, lastStateText
local lastPlay, lastReset, wasInMenu, menuSince, lastReason = 0, 0, inMenu(), nil, nil
local playAttempts = 0
task.spawn(function()
    while alive do
        task.wait(0.1)
        local fruitText = "Fruit: " .. (currentFruit() or "not found")
        if fruitText ~= lastFruitText then lastFruitText = fruitText; fruitRow:Set(fruitText) end
        local stamina = readStamina()
        local stateText = string.format("In game: %s  |  Stamina: %s", menuReason() and ("no (" .. menuReason() .. ")") or "yes", stamina and (math.floor(stamina * 100) .. "%") or "?")
        if stateText ~= lastStateText then lastStateText = stateText; stateRow:Set(stateText) end
        do
            local reason = menuReason()
            local menu = reason ~= nil
            if reason ~= lastReason then
                lastReason = reason
                dbg(reason and ("menu detected: " .. reason) or "in game")
            end
            if menu then menuSince = menuSince or os.clock() else menuSince = nil end
            if menu then
                wasInMenu = true
                -- wait a moment on the menu first, so a death animation isn't mistaken for it
                if autoPlay and os.clock() - menuSince >= 0.3 and os.clock() - lastPlay > 1.5 then
                    lastPlay = os.clock()
                    playAttempts = playAttempts + 1
                    local btn = findPlayButton()
                    if btn then
                        dbg("clicking Play")
                        local ok, err = pcall(clickButton, btn, playAttempts)
                        if not ok then dbg("Play click failed: " .. tostring(err)) end
                    else
                        dbg("Play button not found")
                    end
                end
            else
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if wasInMenu and root then
                    -- just spawned in
                    wasInMenu = false
                    playAttempts = 0
                elseif enabled and resetOnLowStamina and os.clock() - lastReset > 6 then
                    local frac = readStamina()
                    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                    if frac and humanoid and humanoid.Health > 0 and frac * 100 <= resetBelow then
                        lastReset = os.clock()
                        dbg(string.format("stamina at %d%%, resetting", frac * 100))
                        humanoid.Health = 0
                    end
                end
            end
        end
    end
end)

sharedEnv.__WvoxuSkillSpamCleanup = (function(prev)
    return function()
        skillConn:Disconnect()
        prev()
    end
end)(sharedEnv.__WvoxuSkillSpamCleanup)

----------------------------------------------------------------------
-- WORLDS
----------------------------------------------------------------------
local levelRow = statusGroup:Label("Level: ?  |  World: ?")

-- the level belongs to the fruit you have equipped: MAIN_DATA.Fruits.<fruit>.Level
local function readLevel()
    local data = LocalPlayer:FindFirstChild("MAIN_DATA")
    local fruits = data and data:FindFirstChild("Fruits")
    if not fruits then return nil end
    local name
    local slots = data:FindFirstChild("Slots")
    local slotNumber = data:FindFirstChild("Slot")
    local slotValue = slots and slotNumber and slots:FindFirstChild(tostring(slotNumber.Value))
    if slotValue and slotValue.Value ~= "" then name = tostring(slotValue.Value) end
    name = name or currentFruit()
    local fruit = name and fruits:FindFirstChild(name)
    local level = fruit and fruit:FindFirstChild("Level")
    if level and tonumber(level.Value) then return tonumber(level.Value), name end
    return nil
end

local worldGroup = Tab:Group("Worlds")
worldGroup:Toggle({
    Name = "Go to highest world",
    Flag = "autoWorld",
    Description = "World 2 at level 100, world 3 at level 200. Higher worlds give more XP.",
    Default = autoWorld,
    Callback = function(state) autoWorld = state end,
})

local lastWorldHop = 0
task.spawn(function()
    local lastText
    while alive do
        task.wait(2)
        local level, fruitName = readLevel()
        local text = string.format("Level: %s  |  World: %s", level and (level .. " (" .. tostring(fruitName) .. ")") or "?", currentWorld and tostring(currentWorld) or "?")
        if text ~= lastText then lastText = text; levelRow:Set(text) end
        if autoWorld and level and currentWorld and os.clock() - lastWorldHop > 20 then
            local target = currentWorld
            for i, w in ipairs(WORLDS) do
                if level >= w.level then target = math.max(target, i) end
            end
            if target > currentWorld then
                lastWorldHop = os.clock()
                dbg("level " .. level .. ", going to world " .. target)
                Window:Notify({ Title = "Changing world", Text = "Going to world " .. target, Duration = 3 })
                if queue_on_teleport and SCRIPT_URL ~= "" then
                    pcall(queue_on_teleport, string.format('loadstring(game:HttpGet("%s"))()', SCRIPT_URL))
                end
                pcall(function() game:GetService("TeleportService"):Teleport(WORLDS[target].placeId, LocalPlayer) end)
            end
        end
    end
end)

-- skills that push you around: if you end up too far from the spot, go back
task.spawn(function()
    while alive do
        task.wait(0.2)
        if keepPosition and teleportPos and not menuReason() then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - teleportPos).Magnitude > maxDrift then
                root.CFrame = CFrame.new(teleportPos)
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

-- teleport after every spawn, however it happened (your Play press, the script's, or a reset)
local function teleportAfterSpawn(char)
    local waited = 0
    while alive and LocalPlayer:GetAttribute("Spawned") ~= true and waited < 8 do
        task.wait(0.25)
        waited = waited + 0.25
    end
    task.wait(1)
    if not alive or LocalPlayer.Character ~= char or not (teleportOn and teleportPos) then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(teleportPos)
        dbg("teleported to " .. tostring(teleportPos))
    end
end
local spawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
    task.spawn(teleportAfterSpawn, char)
end)
sharedEnv.__WvoxuSkillSpamCleanup = (function(prev)
    return function()
        spawnConn:Disconnect()
        prev()
    end
end)(sharedEnv.__WvoxuSkillSpamCleanup)

end
local ok_runSkillSpam, err_runSkillSpam = pcall(runSkillSpam)
if not ok_runSkillSpam then warn("[Fruit Battlegrounds] Autofarm failed: " .. tostring(err_runSkillSpam)) end

sharedEnv.__WvoxuFruitBattlegroundsCleanup = function()
    for _, key in ipairs({ "__WvoxuSkillSpamCleanup", "__WvoxuFruitSpinnerCleanup" }) do
        if sharedEnv[key] then
            pcall(sharedEnv[key])
            sharedEnv[key] = nil
        end
    end
    pcall(function() Window:Unload(true) end)
end
