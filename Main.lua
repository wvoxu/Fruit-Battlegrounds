-- Fruit Spinner (by wvoxu)
-- Spins your fruit slot until you land a fruit / rarity you picked, or you run out of gems.
-- Pick everything in the window. Optional: set these globals before running to pre-fill it
-- (the old script used them): fruitslot, fruits, rarity, webhookslink

----------------------------------------------------------------------
-- LOADING THE UI LIBRARY
----------------------------------------------------------------------
local function safeloadstring(url)
    local source = game:HttpGet(url)
    -- RightShift hides/shows the window (library default is F3)
    source = source:gsub("Enum%.KeyCode%.F3", "Enum.KeyCode.RightShift", 1)
    -- skip the logo intro (and the wait that comes with it)
    source = source:gsub("self:Intro%(%)%s*task%.wait%(1%)", "", 1)
    -- remove the F2 "hide whole GUI" keybind so RightShift is the only UI toggle
    source = source:gsub('self:AddSettingKeybind%(%{%s*Text = "Toggle SBEUI GUI".-%}%)', "", 1)
    source = source:gsub("Toggle SBEUI Frame", "Toggle UI", 1)
    -- no search bar row: shrink the title bar to just the title
    source = source:gsub("self%.Config%.TitleHeight %+ 35", "self.Config.TitleHeight")

    -- Notifications: theme colours, no accent strip, no countdown bar.
    -- (The notification is a CanvasGroup, and a UIGradient on one tints everything inside it,
    -- so the gradient is made neutral and the real colour goes on the background.)
    local function replace(old, new)
        local a, b = source:find(old, 1, true)
        if a then
            source = source:sub(1, a - 1) .. new .. source:sub(b + 1)
        end
    end
    replace("config.AccentColor or Color3.fromRGB(0, 200, 255)", "config.AccentColor or self.Colors.AccentColor")
    replace("frame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)", "frame.BackgroundColor3 = self.Colors.MainFrameColor")
    replace("Color3.fromRGB(80, 80, 90)", "Color3.fromRGB(255, 255, 255)")
    replace("Color3.fromRGB(40, 40, 45)", "Color3.fromRGB(255, 255, 255)")
    replace("title.TextColor3 = Color3.fromRGB(255, 255, 255)", "title.TextColor3 = self.Colors.TitleColor")
    replace("msg.TextColor3 = Color3.fromRGB(245, 245, 245)", "msg.TextColor3 = self.Colors.LabelColor")
    replace("closeBtn.TextColor3 = Color3.fromRGB(255, 0, 0)", "closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)")
    replace("accent.Size = UDim2.new(0, 5, 1, 0)", "accent.Size = UDim2.new(0, 0, 1, 0)")
    replace("progressBarBackground.BackgroundTransparency = 0.7", "progressBarBackground.BackgroundTransparency = 1")
    replace("progressBar.BackgroundColor3 = Color3.fromRGB(255,255,255)", "progressBar.BackgroundTransparency = 1")

    local func, err = loadstring(source)
    if func then
        return func()
    end
    warn("LOADSTRING FAILED: " .. tostring(err))
    return nil
end

-- If this script was already run, shut the old copy down first (otherwise its window and spin
-- loop keep going in the background next to the new ones).
local sharedEnv = (getgenv and getgenv()) or _G
if sharedEnv.__WvoxuFruitSpinnerCleanup then
    pcall(sharedEnv.__WvoxuFruitSpinnerCleanup)
    sharedEnv.__WvoxuFruitSpinnerCleanup = nil
end

local UILibrary = safeloadstring("https://raw.githubusercontent.com/SugaBlaz/UI-Library/refs/heads/main/Orbital%20UI.lua")

----------------------------------------------------------------------
-- DATA
----------------------------------------------------------------------
local SPIN_COST = 50    -- gems per spin (re-measured after the first spin)
local SPIN_DELAY = 5.1  -- seconds between spins

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
local HttpService = game:GetService("HttpService")

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
local slotNumber = tonumber(env.fruitslot) or 1
local wantedFruits = {}
local wantedRarities = {}
local stopOnUnknown = true
local webhookUrl = ""
if type(env.webhookslink) == "string" and env.webhookslink ~= "link here" then
    webhookUrl = env.webhookslink
end

-- pre-fill from the old globals, if they were set
local presetFruits, presetRarities = {}, {}
if type(env.fruits) == "table" then
    for _, name in pairs(env.fruits) do
        local info = FRUIT_INFO[norm(name)]
        table.insert(presetFruits, info and info.name or tostring(name))
    end
end
if type(env.rarity) == "table" then
    for _, r in pairs(env.rarity) do
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
local ui = UILibrary.Main.new({
    TitleText = "Fruit Spinner (by wvoxu)",
    Size = UDim2.new(0, 300, 0, 380),
    Position = UDim2.new(0.5, -150, 0.5, -190),
    Theme = "Ghost",
    KeySystemEnabled = false,
    SaveOnExit = false,
    NotifcationSound = "", -- silent notifications
})
ui:CreateUI()

sharedEnv.__WvoxuFruitSpinnerCleanup = function()
    running = false
    runId = runId + 1 -- a loop that's mid-wait sees this and quits
    pcall(function() ui.ScreenGui:Destroy() end)
end

ui.Colors.ToggleColorOFF = Color3.fromRGB(255, 95, 95)
ui.Colors.ToggleColorON = Color3.fromRGB(95, 230, 130)
ui.Colors.ToggleColor = Color3.fromRGB(18, 18, 18)

-- remove the tab column + search bar and tidy the title bar
ui.TabScrollingFrame.Visible = false
ui.SearchFrame.Visible = false
ui.TitleText.Position = UDim2.new(0, 12, 0, 0)
ui.MinimizeButton.Parent.Position = UDim2.new(1, 0, 0, 0)
ui.SettingsBtn.Position = UDim2.new(1, -90, 0, 2.5)

-- full-width content, centred
local contentPadding = ui.ScrollingFrame:FindFirstChildOfClass("UIPadding")
if contentPadding then
    contentPadding.PaddingLeft = UDim.new(0, 0)
    contentPadding.PaddingRight = UDim.new(0, 0)
end
ui.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local statusLabel
local autoToggle

local function setStatus(text)
    if statusLabel then
        statusLabel.Text = "Status: " .. text
    end
end

local function notify(title, text)
    task.spawn(function()
        ui:Notify({
            Title = title,
            Text = text,
            Duration = 3,
            StartPosition = UDim2.new(1, 0, 0.776, 0),
            EndPosition = UDim2.new(0.724, 0, 0.776, 0),
            TweenTime = 0.5,
        })
    end)
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
        setStatus("not enough gems")
        notify("Fruit Spinner", "Not enough gems to spin")
        return
    end

    local spinsStart = math.floor(gemsStart / cost)
    invoke("SwitchSlot", { Slot = slot })

    local spins = 0
    while running and runId == myRun do
        task.wait(SPIN_DELAY)
        if not (running and runId == myRun) then return end -- stopped while waiting

        local gemsBefore = data.Gems.Value
        invoke("Spin", {})
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
        setStatus("spin " .. spins .. " - got " .. inGameName .. " (" .. rarity .. "), " .. gemsLeft .. " gems left")

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
            reason = "got " .. inGameName
        elseif info and raritySet[norm(info.rarity)] then
            reason = "got " .. inGameName .. " (" .. rarity .. ")"
        elseif not info and stopOnUnknown then
            reason = "got an unknown fruit: " .. inGameName
        elseif gemsLeft < cost then
            reason = "out of gems"
        end

        if reason then
            running = false
            setStatus("stopped, " .. reason)
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
    setStatus("spinning...")

    task.spawn(function()
        local ok, err = pcall(spinLoop, myRun)
        if not ok then
            running = false
            setStatus("error - " .. tostring(err))
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
    setStatus("stopped")
end

----------------------------------------------------------------------
-- CONTROLS
----------------------------------------------------------------------
statusLabel = ui:AddLabel("Status: idle")
statusLabel.TextXAlignment = Enum.TextXAlignment.Center

autoToggle = ui:AddToggle({
    Text = "Auto Spin",
    Default = false,
    SavingEnabled = false,
    Callback = function(state)
        if state then
            startSpinning()
        else
            stopSpinning()
        end
    end,
})

ui:AddTextBox({
    Text = "Fruit Slot",
    Default = tostring(slotNumber),
    Placeholder = "1",
    SavingEnabled = false,
    Callback = function(text)
        local n = tonumber(text)
        if n and n >= 1 then
            slotNumber = math.floor(n)
        else
            notify("Fruit Spinner", "Slot has to be a number")
        end
    end,
})

ui:AddMultiDropdown({
    Text = "Wanted Fruits",
    Options = FRUIT_NAMES,
    Default = presetFruits,
    SavingEnabled = false,
    Callback = function(selected)
        wantedFruits = selected
    end,
})

ui:AddMultiDropdown({
    Text = "Stop at Rarity",
    Options = RARITIES,
    Default = presetRarities,
    SavingEnabled = false,
    Callback = function(selected)
        wantedRarities = selected
    end,
})

ui:AddToggle({
    Text = "Stop on Unknown Fruit",
    Default = true,
    SavingEnabled = false,
    Callback = function(state)
        stopOnUnknown = state
    end,
})

ui:AddTextBox({
    Text = "Webhook URL",
    Default = webhookUrl,
    Placeholder = "https://discord.com/api/webhooks/...",
    SavingEnabled = false,
    Callback = function(text)
        webhookUrl = (text or ""):gsub("%s", "")
    end,
})

ui:AddButton({
    Text = "Test Webhook",
    Callback = function()
        task.spawn(function()
            local ok, reason = sendWebhook({
                title = "Webhook test",
                description = "Fruit Spinner can reach this webhook.",
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

-- bold ON/OFF text on every toggle
for _, child in ipairs(ui.ScrollingFrame:GetChildren()) do
    local btn = child:FindFirstChild("ToggleButton")
    if btn then
        btn.Font = Enum.Font.GothamBold
    end
end

-- key boxes (the Toggle UI key in Settings): hug the text, grow leftwards from the right edge
for _, box in ipairs(ui.SettingScrollingFrame:GetDescendants()) do
    if box.Name == "BindDisplay" and box:IsA("TextButton") then
        box.AutomaticSize = Enum.AutomaticSize.X
        box.Size = UDim2.new(0, 0, 0, 22)
        box.TextXAlignment = Enum.TextXAlignment.Right
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = box
    end
end

-- no outlines on text (the library's UIStroke traces the letters on text objects)
for _, d in ipairs(ui.ScreenGui:GetDescendants()) do
    if d:IsA("UIStroke") and (d.Parent:IsA("TextLabel") or d.Parent:IsA("TextButton") or d.Parent:IsA("TextBox")) then
        d:Destroy()
    end
end
