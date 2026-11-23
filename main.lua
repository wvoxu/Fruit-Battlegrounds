-- Fruit Battlegrounds (by wvoxu): auto spinner + skill spam in one window.
-- The UI library is loaded from LIB_URL (main.lua in the UI Library repo); its credits are in its header.

-- Link to this script (raw), so it restarts itself after moving to another world.
-- Leave it empty if the script is in your executor's autoexec folder instead.
local SCRIPT_URL = ""

local LIB_URL = "https://raw.githubusercontent.com/wvoxu/UI-Library/main/main.lua"

local sharedEnv = (getgenv and getgenv()) or _G
-- close older copies first (this one, and the two separate scripts)
for _, key in ipairs({ "__WvoxuFruitBattlegroundsCleanup", "__WvoxuFruitBattlegroundsPvPCleanup", "__WvoxuSkillSpamCleanup", "__WvoxuFruitSpinnerCleanup" }) do
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
            Body = HttpService:JSONEncode({ embeds = embed[1] ~= nil and embed or { embed } }), -- one embed, or a list of up to 10
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

-- Messages are sent in batches (Discord takes up to 10 embeds per request) and retried, so a rate limit
-- or a slow moment doesn't drop a spin, and the queue can keep up with fast spinning
local webhookQueue = {}
local webhookWorker = false
local function queueWebhook(embed)
    if webhookUrl == "" then return end
    table.insert(webhookQueue, embed)
    if webhookWorker then return end
    webhookWorker = true
    task.spawn(function()
        task.wait(0.3) -- let a few pile up
        while #webhookQueue > 0 do
            local batch = {}
            for _ = 1, math.min(10, #webhookQueue) do
                table.insert(batch, webhookQueue[1])
                table.remove(webhookQueue, 1)
            end
            local sent = false
            for attempt = 1, 6 do
                local ok, reason, wait = sendWebhook(batch)
                if ok then
                    sent = true
                    break
                end
                if reason == "no webhook set" then break end
                task.wait((wait or (attempt * 1.5)) + 0.2)
            end
            if not sent then warn("[Fruit Battlegrounds] " .. #batch .. " webhook message(s) couldn't be sent") end
            task.wait(0.25)
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
local SLOTS = { "1", "2", "3", "4", "5", "E", "G" } -- the hotbar buttons in the game's UI
local alive = true
local enabled = false
local gameSlot = { ["1"] = false, ["2"] = false, ["3"] = false, ["4"] = false, ["5"] = false, E = false, G = false } -- slots cast by pressing the key and clicking
local useSlot = { ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, E = true, G = false }
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
local SLOT_MODES = { "Off", "Fast", "Like the game" }
local gameInterval = 3 -- seconds between uses of a "Like the game" slot: a click while a skill is cooling down is just an M1
local lastGameCast = {}
slotGroup:Slider({
    Name = "Like the game: every",
    Flag = "gameInterval",
    Min = 0.5, Max = 20, Default = gameInterval, Step = 0.5, Suffix = " s",
    Callback = function(v) gameInterval = v end,
})
for _, slot in ipairs(SLOTS) do
    slotGroup:Dropdown({
        Name = "Slot " .. slot,
        Flag = "mode" .. slot,
        Options = SLOT_MODES,
        Default = useSlot[slot] and "Fast" or "Off",
        Callback = function(mode)
            useSlot[slot] = mode ~= "Off"
            gameSlot[slot] = mode == "Like the game"
        end,
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

-- skills that don't behave like the rest, from what the game sends when you cast them yourself:
--   plain = true: the cast carries no aim data
--   hold = seconds: the game keeps sending your position and aim for that long, then clears it
local SPECIAL = {
    ["OpeV2/Silence"] = { plain = true, hold = 1.25 },
}

local holding = 0 -- skills currently sending updates (clearing while another one is still going would cut it off)
local function useSkill(fruit, skill)
    local special = SPECIAL[fruit .. "/" .. skill]
    if special and special.plain then
        skillRemote:FireServer(fruit, skill, {})
    else
        skillRemote:FireServer(fruit, skill, { MouseRay = buildMouseRay(), RootCF = rootCFrame() })
    end
    if special and special.hold then
        holding = holding + 1
        local started = os.clock()
        while alive and enabled and os.clock() - started < special.hold do
            task.wait(0.11)
            skillRemote:FireServer("ClientData", "UpdateData", { RootCF = rootCFrame(), MouseRay = buildMouseRay() })
        end
        holding = holding - 1
        if holding <= 0 then
            holding = 0
            skillRemote:FireServer("ClientData", "ClearData", {})
        end
    end
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
        if useSlot[slot] and not gameSlot[slot] and skill and not busy[skill] then
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

-- "Cast like the game": press the skill's key and click, the way you would. The game's own code then
-- does everything (aim, holding, whatever the skill needs), so it works for every skill.
local VIM = game:GetService("VirtualInputManager")
local KEYS = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three, ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
}
local function keyOfSlot(slot)
    local bar = hotbar()
    local btn = bar and bar:FindFirstChild(slot)
    local label = btn and btn:FindFirstChild("Key")
    local text = label and label:IsA("TextLabel") and label.Text:upper() or slot:upper()
    return KEYS[text] or Enum.KeyCode[text]
end

local equippedSlot = nil -- the slot we last equipped; forgotten when the character respawns

-- is this slot's skill equipped right now? Skills are tools named like the skill bar: in your character when
-- equipped, in your backpack when not. If the game doesn't use tools for this skill, go by what we pressed last.
local function isEquipped(slot)
    local bar = hotbar()
    local btn = bar and bar:FindFirstChild(slot)
    local title = btn and btn:FindFirstChild("Title")
    local name = title and title:IsA("TextLabel") and title.Text or nil
    if name and name ~= "" then
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char and char:FindFirstChild(name) then return true end
        if backpack and backpack:FindFirstChild(name) then return false end
    end
    return equippedSlot == slot
end
LocalPlayer.CharacterAdded:Connect(function() equippedSlot = nil end)

task.spawn(function()
    while alive do
        task.wait(0.05)
        if enabled then
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                for _, slot in ipairs(SLOTS) do
                    if not (enabled and alive) then break end
                    if useSlot[slot] and gameSlot[slot] and skillOfSlot(slot) and os.clock() - (lastGameCast[slot] or 0) >= gameInterval then
                        lastGameCast[slot] = os.clock()
                        local key = keyOfSlot(slot)
                        if key == Enum.KeyCode.E then
                            -- the E skill is used by just pressing E: nothing to equip, no click
                            VIM:SendKeyEvent(true, key, false, game)
                            task.wait(0.03)
                            VIM:SendKeyEvent(false, key, false, game)
                            task.wait(0.05)
                        elseif key then
                            -- a skill stays equipped after you use it, and pressing its key again would put it away,
                            -- so the next click would be a plain M1. Only press the key when switching to another skill.
                            if not isEquipped(slot) then
                                VIM:SendKeyEvent(true, key, false, game)
                                task.wait(0.03)
                                VIM:SendKeyEvent(false, key, false, game)
                                task.wait(0.05)
                                equippedSlot = slot
                            end
                            -- click on the middle of the screen, away from the skill bar
                            local view = workspace.CurrentCamera.ViewportSize
                            local x, y = view.X * 0.5, view.Y * 0.4
                            VIM:SendMouseMoveEvent(x, y, game)
                            VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                            task.wait(0.015) -- as short as possible, so the game's Auto M1 doesn't see a held button
                            VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
                            task.wait(0.05)
                        end
                    end
                end
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
-- come back after being disconnected or kicked
local autoRejoin = true
survivalGroup:Toggle({
    Name = "Auto rejoin",
    Description = "Rejoins the same world if you get disconnected or kicked.",
    Flag = "autoRejoin",
    Default = autoRejoin,
    Callback = function(state) autoRejoin = state end,
})
do
    local GuiService = game:GetService("GuiService")
    local TeleportService = game:GetService("TeleportService")
    local rejoining = false
    local function rejoin(message)
        if rejoining or not autoRejoin or not alive then return end
        rejoining = true
        dbg("disconnected (" .. tostring(message) .. "), rejoining")
        task.spawn(function()
            task.wait(3)
            for _ = 1, 60 do
                if not (alive and autoRejoin) then break end
                pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
                task.wait(10)
            end
            rejoining = false
        end)
    end
    GuiService.ErrorMessageChanged:Connect(function(message)
        if message and message ~= "" then rejoin(message) end
    end)
    -- the disconnect window can also show up without that event firing
    pcall(function()
        local overlay = game:GetService("CoreGui").RobloxPromptGui.promptOverlay
        overlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then rejoin("error prompt") end
        end)
    end)
end

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
local hiddenForPlay = false
local function clickButton(btn, mode)
    local VIM = game:GetService("VirtualInputManager")
    -- the script's window can sit right on top of the Play button, so get it out of the way first
    if Window:IsVisible() then
        hiddenForPlay = true
        Window:Toggle(false)
        task.wait(0.4)
    end
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

local function goToWorld(target)
    Window:Notify({ Title = "Changing world", Text = "Going to world " .. target, Duration = 3 })
    -- write the settings out now, so the new world starts from exactly what's on screen
    pcall(function() Window:SaveConfig("Default") end)
    task.wait(0.5)
    if queue_on_teleport and SCRIPT_URL ~= "" then
        pcall(queue_on_teleport, string.format('loadstring(game:HttpGet("%s"))()', SCRIPT_URL))
    end
    pcall(function() game:GetService("TeleportService"):Teleport(WORLDS[target].placeId, LocalPlayer) end)
end

for i = 1, #WORLDS do
    worldGroup:Button({
        Name = "Go to world " .. i,
        Callback = function()
            if currentWorld == i then
                Window:Notify({ Title = "Already here", Text = "You're in world " .. i, Duration = 2 })
            else
                goToWorld(i)
            end
        end,
    })
end

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
                goToWorld(target)
            end
        end
    end
end)

-- bring the window back once you're in the game
task.spawn(function()
    while alive do
        task.wait(1)
        if hiddenForPlay and not menuReason() then
            hiddenForPlay = false
            if not Window:IsVisible() then Window:Toggle(true) end
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

----------------------------------------------------------------------
-- PVP
----------------------------------------------------------------------
local function runPvP()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local alive = true
local silentAim = false
local showCircle = false
local lockMode = "Camera"
local targetMode = "Closest to cursor"
local aimPartName = "HumanoidRootPart"
local fovRadius = 300
local maxDistance = 600
local lockSpeed = 5
local lockedPlayer = nil

local espOn = false
local espName, espHealth, espDistance = true, true, true
local espRange = 1500
local espOutline = true
local espFill = 1 -- 1 is see-through, so only the outline shows

local Tab = Window:Tab({ Name = "PvP", Icon = "Misc" })
local aimGroup = Tab:Group("Lock on")
local silentGroup = Tab:Group("Silent aim")
local pickGroup = Tab:Group("Target")
local espGroup = Tab:Group("ESP")

----------------------------------------------------------------------
-- TARGETS
----------------------------------------------------------------------
local function aimPartOf(char)
    return char and (char:FindFirstChild(aimPartName) or char:FindFirstChild("HumanoidRootPart"))
end

local function alivePlayerPart(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local part = aimPartOf(char)
    if hum and part and hum.Health > 0 then return part, hum end
    return nil
end

-- the best enemy for a new lock (or for silent aim): inside the circle, by the chosen rule
local function pickTarget()
    local cam = workspace.CurrentCamera
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not (cam and myRoot) then return nil end
    local cursor = UserInputService:GetMouseLocation()
    local best, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local part, hum = alivePlayerPart(plr)
            if part and not plr.Character:FindFirstChildOfClass("ForceField") then
                local distance = (part.Position - myRoot.Position).Magnitude
                if distance <= maxDistance then
                    local point, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local fromCursor = (Vector2.new(point.X, point.Y) - cursor).Magnitude
                        if fromCursor <= fovRadius then
                            local score = fromCursor
                            if targetMode == "Closest to me" then score = distance
                            elseif targetMode == "Lowest health" then score = hum.Health end
                            if not bestScore or score < bestScore then best, bestScore = plr, score end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- the part to aim at right now: the player you locked onto, otherwise whoever pickTarget finds
local function currentAimPart()
    if lockedPlayer then
        local part = alivePlayerPart(lockedPlayer)
        if part then return part end
    end
    local plr = pickTarget()
    return plr and alivePlayerPart(plr) or nil
end

local function releaseLock(reason)
    if not lockedPlayer then return end
    lockedPlayer = nil
    Window:Notify({ Title = "Lock released", Text = reason or "", Duration = 2 })
end

----------------------------------------------------------------------
-- SILENT AIM: your own casts keep the same shape, only the aim in them is swapped for the target
-- This has to watch the game's remote calls. It is only switched on while the toggle is on.
----------------------------------------------------------------------
local skillRemote = ReplicatedStorage:FindFirstChild("ReplicatorNoYield")
local hooked = false

local function targetRay(part)
    local cam = workspace.CurrentCamera
    local origin = cam.CFrame.Position
    local offset = part.Position - origin
    return {
        Origin = origin,
        Direction = offset.Unit * 300,
        Instance = part,
        Position = part.Position,
        Normal = -offset.Unit,
        Distance = offset.Magnitude,
        Material = part.Material,
    }
end

local function installHook()
    if hooked then return true end
    if not (hookfunction and newcclosure and skillRemote) then return false end
    local ok = pcall(function()
        local probe = Instance.new("RemoteEvent")
        local original
        original = hookfunction(probe.FireServer, newcclosure(function(self, ...)
            if silentAim and alive and self == skillRemote and not (checkcaller and checkcaller()) then
                local args = table.pack(...)
                local data = args[3]
                if type(data) == "table" and data.MouseRay ~= nil then
                    local target = currentAimPart()
                    if target then
                        local copy = {}
                        for k, v in pairs(data) do copy[k] = v end
                        copy.MouseRay = targetRay(target)
                        args[3] = copy
                        return original(self, table.unpack(args, 1, args.n))
                    end
                end
            end
            return original(self, ...)
        end))
        probe:Destroy()
    end)
    hooked = ok
    return ok
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
aimGroup:Keybind({
    Name = "Lock on / release",
    Description = "Locks onto the player nearest your cursor, and follows them until you press it again.",
    Flag = "lockKey",
    Default = Enum.KeyCode.T,
    Callback = function()
        if lockedPlayer then
            releaseLock("You let go")
            return
        end
        local plr = pickTarget()
        if plr then
            lockedPlayer = plr
            Window:Notify({ Title = "Locked on", Text = plr.DisplayName, Duration = 2 })
        else
            Window:Notify({ Title = "No target", Text = "Nobody is inside the circle", Duration = 2 })
        end
    end,
})
aimGroup:Dropdown({
    Name = "Lock mode",
    Description = "Camera turns your view. Cursor moves your mouse onto them.",
    Flag = "lockMode",
    Options = { "Camera", "Cursor" },
    Default = lockMode,
    Callback = function(v) lockMode = v end,
})
aimGroup:Slider({
    Name = "Follow speed",
    Description = "Lower is smoother and slower to catch up. Around 3 to 6 looks very smooth.",
    Flag = "lockSpeed",
    Min = 1, Max = 30, Default = lockSpeed, Step = 1,
    Callback = function(v) lockSpeed = v end,
})
silentGroup:Toggle({
    Name = "Silent aim",
    Description = "Your skills go at the target without moving your camera or cursor. The first time you turn it on it starts watching the game's calls, which the game may notice.",
    Flag = "silentAim",
    Default = false,
    Callback = function(state)
        if state and not installHook() then
            silentAim = false
            Window:Notify({ Title = "Silent aim", Text = "Your executor can't do this", Duration = 4 })
            return
        end
        silentAim = state
    end,
})
pickGroup:Dropdown({
    Name = "Pick target by",
    Flag = "targetMode",
    Options = { "Closest to cursor", "Closest to me", "Lowest health" },
    Default = targetMode,
    Callback = function(v) targetMode = v end,
})
pickGroup:Dropdown({
    Name = "Aim at",
    Flag = "aimPart",
    Options = { "HumanoidRootPart", "Head", "UpperTorso" },
    Default = aimPartName,
    Callback = function(v) aimPartName = v end,
})
pickGroup:Slider({
    Name = "Circle size",
    Description = "Only players inside this circle around your cursor can be locked onto.",
    Flag = "aimFov",
    Min = 50, Max = 1000, Default = fovRadius, Step = 10, Suffix = " px",
    Callback = function(v) fovRadius = v end,
})
pickGroup:Slider({
    Name = "Max distance",
    Flag = "aimDistance",
    Min = 50, Max = 2000, Default = maxDistance, Step = 10, Suffix = " studs",
    Callback = function(v) maxDistance = v end,
})
pickGroup:Toggle({
    Name = "Show circle",
    Flag = "aimCircle",
    Default = false,
    Callback = function(state) showCircle = state end,
})
espGroup:Toggle({ Name = "ESP", Flag = "espOn", Default = false, Callback = function(v) espOn = v end })
espGroup:Toggle({
    Name = "Outline",
    Description = "Draws the outline of their character, even through walls.",
    Flag = "espOutline",
    Default = true,
    Callback = function(v) espOutline = v end,
})
espGroup:Slider({
    Name = "Fill",
    Description = "0 fills the whole body with color, 100 shows only the outline.",
    Flag = "espFill",
    Min = 0, Max = 100, Default = 100, Step = 5, Suffix = "%",
    Callback = function(v) espFill = v / 100 end,
})
espGroup:Toggle({ Name = "Show name", Flag = "espName", Default = true, Callback = function(v) espName = v end })
espGroup:Toggle({ Name = "Show health", Flag = "espHealth", Default = true, Callback = function(v) espHealth = v end })
espGroup:Toggle({ Name = "Show distance", Flag = "espDistance", Default = true, Callback = function(v) espDistance = v end })
espGroup:Slider({
    Name = "ESP range",
    Flag = "espRange",
    Min = 100, Max = 5000, Default = espRange, Step = 50, Suffix = " studs",
    Callback = function(v) espRange = v end,
})

----------------------------------------------------------------------
-- THE CIRCLE (only if the executor has Drawing)
----------------------------------------------------------------------
local circle
pcall(function()
    if Drawing then
        circle = Drawing.new("Circle")
        circle.Thickness = 1
        circle.NumSides = 64
        circle.Filled = false
        circle.Color = Color3.fromRGB(255, 255, 255)
        circle.Visible = false
    end
end)

----------------------------------------------------------------------
-- FOLLOWING THE LOCKED PLAYER
----------------------------------------------------------------------
local renderName = "WvoxuAimLock"
pcall(function() RunService:UnbindFromRenderStep(renderName) end) -- in case an older copy is still bound
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not alive then
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        if circle then
            pcall(function() circle:Remove() end)
            circle = nil
        end
        return
    end
    local cam = workspace.CurrentCamera
    if circle then
        circle.Visible = showCircle
        if showCircle then
            circle.Position = UserInputService:GetMouseLocation()
            circle.Radius = fovRadius
        end
    end
    if not (lockedPlayer and cam) then return end
    local part = alivePlayerPart(lockedPlayer)
    if not part or not lockedPlayer.Parent then
        releaseLock("They are gone")
        return
    end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myRoot and (part.Position - myRoot.Position).Magnitude > maxDistance * 1.5 then
        releaseLock("Too far away")
        return
    end
    if lockMode == "Camera" then
        -- the same fraction of the remaining turn every second, whatever the frame rate, so it eases in smoothly
        local alpha = 1 - math.exp(-lockSpeed * dt)
        local goal = CFrame.lookAt(cam.CFrame.Position, part.Position)
        cam.CFrame = cam.CFrame:Lerp(goal, alpha)
    end
end)

-- cursor mode: ease the real cursor onto the locked player
task.spawn(function()
    local last = os.clock()
    while alive do
        task.wait(0.016)
        local now = os.clock()
        local dt = now - last
        last = now
        if lockedPlayer and lockMode == "Cursor" then
            local part = alivePlayerPart(lockedPlayer)
            local cam = workspace.CurrentCamera
            if part and cam then
                local point = cam:WorldToViewportPoint(part.Position)
                local cursor = UserInputService:GetMouseLocation()
                local alpha = 1 - math.exp(-lockSpeed * dt)
                pcall(function()
                    VIM:SendMouseMoveEvent(cursor.X + (point.X - cursor.X) * alpha, cursor.Y + (point.Y - cursor.Y) * alpha, game)
                end)
            end
        end
    end
end)

----------------------------------------------------------------------
-- ESP: name, health and distance above each player's head
----------------------------------------------------------------------
local espFolder = Instance.new("Folder")
espFolder.Name = "WvoxuESP"
do
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    espFolder.Parent = parent or game:GetService("CoreGui")
end
local espEntries = {}

local function removeEsp(plr)
    local e = espEntries[plr]
    if e then
        pcall(function() e.gui:Destroy() end)
        pcall(function() e.highlight:Destroy() end)
        espEntries[plr] = nil
    end
end

local function makeEsp(plr, head)
    local highlight = Instance.new("Highlight")
    highlight.Name = plr.Name
    highlight.Adornee = plr.Character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder
    local gui = Instance.new("BillboardGui")
    gui.Name = plr.Name
    gui.Adornee = head
    gui.AlwaysOnTop = true
    gui.Size = UDim2.fromOffset(220, 60)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.Parent = espFolder
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0.4
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Parent = gui
    espEntries[plr] = { gui = gui, label = label, head = head, highlight = highlight, char = plr.Character }
end

task.spawn(function()
    while alive do
        task.wait(0.1)
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local head = char and char:FindFirstChild("Head")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local distance = (head and myRoot) and (head.Position - myRoot.Position).Magnitude or math.huge
                if espOn and head and hum and hum.Health > 0 and distance <= espRange then
                    local e = espEntries[plr]
                    if e and (e.head ~= head or e.char ~= char) then
                        removeEsp(plr)
                        e = nil
                    end
                    if not e then
                        makeEsp(plr, head)
                        e = espEntries[plr]
                    end
                    local lines = {}
                    if espName then table.insert(lines, (lockedPlayer == plr and "[LOCKED] " or "") .. plr.DisplayName) end
                    local info = {}
                    if espHealth then table.insert(info, string.format("%d/%d HP", math.floor(hum.Health), math.floor(hum.MaxHealth))) end
                    if espDistance then table.insert(info, string.format("%dm", math.floor(distance))) end
                    if #info > 0 then table.insert(lines, table.concat(info, "  ")) end
                    e.label.Text = table.concat(lines, "\n")
                    local isLocked = lockedPlayer == plr
                    e.highlight.Enabled = espOutline
                    e.highlight.FillTransparency = espFill
                    e.highlight.OutlineColor = isLocked and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)
                    e.highlight.FillColor = isLocked and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)
                    local fraction = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    e.label.TextColor3 = lockedPlayer == plr and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(80, 255, 120), fraction)
                else
                    removeEsp(plr)
                end
            end
        end
        for plr in pairs(espEntries) do
            if not plr.Parent then removeEsp(plr) end
        end
    end
end)

sharedEnv.__WvoxuFruitBattlegroundsPvPCleanup = function()
    alive = false
    silentAim = false
    lockedPlayer = nil
    for plr in pairs(espEntries) do removeEsp(plr) end
    pcall(function() espFolder:Destroy() end)
end
end
local ok_runPvP, err_runPvP = pcall(runPvP)
if not ok_runPvP then warn("[Fruit Battlegrounds] PvP failed: " .. tostring(err_runPvP)) end

sharedEnv.__WvoxuFruitBattlegroundsCleanup = function()
    for _, key in ipairs({ "__WvoxuSkillSpamCleanup", "__WvoxuFruitSpinnerCleanup", "__WvoxuFruitBattlegroundsPvPCleanup" }) do
        if sharedEnv[key] then
            pcall(sharedEnv[key])
            sharedEnv[key] = nil
        end
    end
    pcall(function() Window:Unload(true) end)
end
