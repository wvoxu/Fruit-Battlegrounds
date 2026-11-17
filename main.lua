-- Fruit Battlegrounds auto spinner (by wvoxu), UI Library
-- Spins your fruit slot until you land a fruit / rarity you picked, or you run out of gems.
-- Pick everything in the window. Optional: set these globals before running to pre-fill it
-- (the old script used them): fruitslot, fruits, rarity, webhookslink

-- UI LIBRARY: loaded from this link (the "main.lua" of your UI Library repo). Change it if the repo is named differently.
local LIB_URL = "https://raw.githubusercontent.com/wvoxu/UI-Library/main/main.lua"

----------------------------------------------------------------------
-- SAVED SETTINGS
----------------------------------------------------------------------
-- Settings are kept in a small file in your executor's workspace folder and loaded on start.
-- (Whether Auto Spin is on is never saved. The theme and menu key are saved by the UI itself.)
local HttpService = game:GetService("HttpService")
local SAVE_FILE = "WvoxuFruitSpinner.json"
local saved = HttpService:JSONDecode("{}") -- (decoded this way so editors treat it as a flexible table)
local canSave = (writefile and readfile and isfile) ~= nil
if canSave and isfile(SAVE_FILE) then
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
    if ok and type(decoded) == "table" then
        saved = decoded
    end
end
local saveSettings = function() end -- replaced once the UI exists

-- If this script was already run, shut the old copy down first (otherwise its window and spin
-- loop keep going in the background next to the new ones).
local sharedEnv = (getgenv and getgenv()) or _G
if sharedEnv.__WvoxuFruitSpinnerCleanup then
    pcall(sharedEnv.__WvoxuFruitSpinnerCleanup)
    sharedEnv.__WvoxuFruitSpinnerCleanup = nil
end

-- The UI library (FeatherInk, a restyled copy of S2kh's FeatherLite) is built into this file for now.
local FeatherLite
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
    FeatherLite = library
end

----------------------------------------------------------------------
-- DATA
----------------------------------------------------------------------
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
local env = sharedEnv

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
local Window = FeatherLite:Window({
    Title = "Fruit Battlegrounds",
    Subtitle = "by wvoxu",
    Key = Enum.KeyCode.RightShift, -- players can change it in Settings, it's remembered
    Folder = "WvoxuFruitBattlegrounds",
    Size = Vector2.new(720, 470),
    Splash = false,
    Logo = "W", -- a cursive W instead of the feather picture
    KeepPrevious = true, -- don't close other FeatherLite scripts' windows
})

local ready = false -- settings are only written once the UI has finished loading

local function copyList(t)
    local c = {}
    for _, v in ipairs(t) do table.insert(c, v) end
    return c
end

-- Settings are saved by the UI itself now (Settings > Configs: Autosave / Autoload).
-- The old settings file is only read once, to fill in the first "Default" config.
saveSettings = function() end

sharedEnv.__WvoxuFruitSpinnerCleanup = function()
    running = false
    runId = runId + 1 -- a loop that's mid-wait sees this and quits
    pcall(function() Window:Unload(true) end)
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
        return false, "HTTP " .. tostring(code)
    end
    return true
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

        task.spawn(sendWebhook, {
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
            task.spawn(sendWebhook, { title = "Script has stopped", description = reason, color = 0xffffff })
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
    Description = "Spins until you get a fruit or rarity you picked.",
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
    Description = "Uses the fast spin, about 5x quicker.",
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

local targetGroup = Tab:Group({ Name = "Stop when you get", Description = "It also won't spin if the slot already has one of these." })

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
    Description = "Stops if you pull a fruit that isn't in the list.",
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

-- everything is built: from now on, changes get saved
ready = true
