----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local config = {
    slot     = 1,                 -- which fruit slot to spin in
    fruits   = { "Barrier" },     -- stop when you get any of these (in-game names, see the list below)
    rarities = { },               -- stop on any of these: Common, Uncommon, Rare, Epic, Legendary, Mythic
    webhook  = "",                -- your Discord webhook URL (leave empty for none)
}

-- Optional: if you set these globals before running (the way the old script worked),
-- they override the values above.
local env = (getgenv and getgenv()) or _G
local slot     = env.fruitslot    or config.slot
local wantedFruits   = env.fruits        or config.fruits
local wantedRarities = env.rarity        or config.rarities
local webhookUrl     = env.webhookslink  or config.webhook

----------------------------------------------------------------------
-- DATA
----------------------------------------------------------------------
local SPIN_COST = 50      -- gems per spin
local SPIN_DELAY = 5.1    -- seconds between spins

local RARITY_COLORS = {
    Common    = 0x808080,
    Uncommon  = 0x7aff9d,
    Rare      = 0x478dff,
    Epic      = 0xd465e5,
    Legendary = 0xff7e39,
    Mythical  = 0xffeb6a,
}

-- in-game name -> info
local FRUITS = {
    { name = "Barrier", official = "Bari Bari no Mi", rarity = "Common",
      image = "https://trello.com/1/cards/640c774c8346bc615c9130d1/attachments/645aa80b9c56fc47f10c45d4/previews/645aa80b9c56fc47f10c4609/download/barrierbannerfbv2.png" },
    { name = "Chop", official = "Bara Bara no Mi", rarity = "Common",
      image = "https://trello.com/1/cards/640c777c5335d2a58fb085be/attachments/645aa81805f0b3aa8e7d6222/previews/645aa81805f0b3aa8e7d622e/download/chopbannerfbv2.png" },
    { name = "Sand", official = "Suna Suna no Mi", rarity = "Common",
      image = "https://trello.com/1/cards/640c77801627bd29930bf6a0/attachments/645aa827cd5493524d4e3c91/previews/645aa828cd5493524d4e3cbe/download/sandbannerfbv2.png" },
    { name = "Smoke", official = "Moku Moku no Mi", rarity = "Uncommon",
      image = "https://trello.com/1/cards/640c7783f8a59acdef0ae521/attachments/645aa832347e3db20572f8e7/previews/645aa832347e3db20572f8ef/download/smokebannerfbv2.png" },
    { name = "Rubber", official = "Gomu Gomu no Mi", rarity = "Uncommon",
      image = "https://trello.com/1/cards/640c7792a3708b8c25511bc2/attachments/645aa851c36c94c1867bb000/previews/645aa852c36c94c1867bb055/download/rubberbannerfbv2.png" },
    { name = "Gas", official = "Gasu Gasu no Mi", rarity = "Uncommon",
      image = "https://trello.com/1/cards/6455b685698bb2cc561bfb2d/attachments/645aa83bde09c2c77a3dceb4/previews/645aa83cde09c2c77a3dceca/download/gasbannerfbv2.png" },
    { name = "Falcon", official = "Tori Tori no Mi, Model: Falcon", rarity = "Uncommon",
      image = "https://trello.com/1/cards/6455b688e0d3dc321f250b3b/attachments/645aa85bc89ab8e61407286b/previews/645aa85bc89ab8e614072963/download/falconbannerv2.png" },
    { name = "Bomb", official = "Bomu Bomu no Mi", rarity = "Rare",
      image = "https://trello.com/1/cards/640c77a1595841caf51e003d/attachments/645aa86ecd7c7df4c805679b/previews/645aa86fcd7c7df4c80567ef/download/bombbannerfbv2.png" },
    { name = "Ice", official = "Hie Hie no Mi", rarity = "Rare",
      image = "https://trello.com/1/cards/640c77eb2331836d7158a1f1/attachments/645aa889d07981ba9748db66/previews/645aa88ad07981ba9748dbca/download/icebannerfbv2.png" },
    { name = "Darkness", official = "Yami Yami no Mi", rarity = "Rare",
      image = "https://trello.com/1/cards/640c77f8f91d029cf28fbcfa/attachments/645aa89a5451c1ab3208c49b/previews/645aa89b5451c1ab3208c677/download/darknessbannerfbv2.png" },
    { name = "Light", official = "Pika Pika no Mi", rarity = "Epic",
      image = "https://trello.com/1/cards/640c780e1e70d6393b45dc0b/attachments/645805de415b8c9b35df8bfd/previews/645805df415b8c9b35df8ca8/download/lightbannerfbv2.png" },
    { name = "Flame", official = "Mera Mera no Mi", rarity = "Epic",
      image = "https://trello.com/1/cards/640c781bc81456570a0756eb/attachments/6458056d426c4da42d7b9119/previews/6458056d426c4da42d7b929b/download/flamebannerfbv2.png" },
    { name = "Paw", official = "Nikyu Nikyu no Mi", rarity = "Epic",
      image = "https://trello.com/1/cards/640c783143a9de5c047225e0/attachments/645804e46c0aa9629353e704/previews/645804e56c0aa9629353e710/download/image_2023-05-05_201353704%283%29%282%29.png" },
    { name = "Magma", official = "Magu Magu no Mi", rarity = "Epic",
      image = "https://trello.com/1/cards/640c78276e1fd7cf5390b42a/attachments/645803d9226638fb91e5780b/previews/645803da226638fb91e57817/download/magmabannerfbv2.png" },
    { name = "String", official = "Ito Ito no Mi", rarity = "Epic",
      image = "https://trello.com/1/cards/648ee747d56a7f6124f3b1be/attachments/648ee7526004730e936e8d06/previews/648ee7536004730e936e8f0c/download/StringBannerFB.png" },
    { name = "Quake", official = "Gura Gura no Mi", rarity = "Legendary",
      image = "https://trello.com/1/cards/640c783fa2a582bc1044fada/attachments/6458014e2d5e8e0882e9eaf9/download/quakebannerfbv2.png" },
    { name = "Magnet", official = "Jiki Jiki no Mi", rarity = "Legendary",
      image = "https://trello.com/1/cards/64619b091821cac18d8fd604/attachments/6461ac0220e05f4a5818319b/download/image.png" },
    { name = "Gravity", official = "Zushi Zushi no Mi", rarity = "Legendary",
      image = "https://trello.com/1/cards/640c784fad1a4320837c7d5f/attachments/645800c1e42b7aacc516b23c/previews/645800c2e42b7aacc516b283/download/GRAVITYbannerfbv2.png" },
    { name = "Phoenix", official = "Tori Tori no Mi, Model: Phoenix", rarity = "Legendary",
      image = "https://trello.com/1/cards/640c7859aeaf58e1177dee7f/attachments/6458002d13c783bab0fba127/previews/6458002e13c783bab0fba133/download/phoenixbannerfbv2.png" },
    { name = "TSRubber", official = "Gomu Gomu no Mi-(Timeskip)", rarity = "Legendary",
      image = "https://trello.com/1/cards/640c78680618a3acb5c8a520/attachments/6457ff69a69a559a96e0bf02/previews/6457ff6aa69a559a96e0bfb3/download/TSRUBBERbannerfbv2.png" },
    { name = "Leopard", official = "Neko Neko no Mi, Model: Leopard", rarity = "Mythical",
      image = "https://trello.com/1/cards/64619b01f25809c82aaff841/attachments/6461ac55e7296d488c3ed3eb/previews/6461ac56e7296d488c3ed3fd/download/leopardbannerfbv2.png" },
    { name = "Dough", official = "Mochi Mochi no Mi", rarity = "Mythical",
      image = "https://trello.com/1/cards/640c78753a36660d4ec63b81/attachments/6457fe0e16e1bc3c76f40e9e/previews/6457fe0f16e1bc3c76f40eaa/download/doughbannerfbv2.png" },
    { name = "Dragon", official = "Uo Uo no Mi, Model: Seiryu", rarity = "Mythical",
      image = "https://trello.com/1/cards/640c787f137dee4ff4c31317/attachments/6457fcfae219beebabc93af4/previews/6457fcfbe219beebabc93b00/download/image_2023-05-05_201353704%283%29.png" },
    { name = "Lightning", official = "Goro Goro no Mi", rarity = "Mythical",
      image = "https://trello.com/1/cards/6455b68851830ae2486a4c18/attachments/6457fae033eb5b7d15413235/previews/6457fae133eb5b7d15413284/download/lightningbannerfbv2.png" },
    { name = "Ope", official = "Ope Ope no Mi", rarity = "Mythical",
      image = "https://trello.com/1/cards/648bfafa39104e81e63b5dc3/attachments/648ee725a755659873195cd2/previews/648ee726a755659873195d7d/download/image.png" },
    { name = "Venom", official = "Doku Doku no Mi", rarity = "Mythical",
      image = "https://trello.com/1/cards/64bec42c8048e8daa1e9d8e7/attachments/64bec42c8048e8daa1e9d970/previews/64bec42d8048e8daa1e9d98e/download/VenomBannerFB.png" },
    { name = "Nika", official = "Hito Hito no Mi, Model: Nika", rarity = "Mythical",
      image = "https://trello.com/1/cards/65005640d6e3a28a72d9bc4f/attachments/65005648db5624afe775992a/previews/65005648db5624afe7759ac7/download/NikaBannerv2.png" },
}

local fruitByName = {}
for _, f in ipairs(FRUITS) do
    fruitByName[f.name] = f
end

----------------------------------------------------------------------
-- SETUP
----------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local data = player.MAIN_DATA

-- anti-AFK
for _, connection in pairs(getconnections(player.Idled)) do
    connection:Disable()
end

local httpRequest = (syn and syn.request) or http_request or request

local function contains(list, value)
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end

-- "Mythic" and "Mythical" both work in the rarity list
local function wantsRarity(rarity)
    if contains(wantedRarities, rarity) then return true end
    return rarity == "Mythical" and contains(wantedRarities, "Mythic")
end

local function sendWebhook(embed)
    if not webhookUrl or webhookUrl == "" or not httpRequest then return end
    pcall(function()
        httpRequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["content-type"] = "application/json" },
            Body = HttpService:JSONEncode({ embeds = { embed } }),
        })
    end)
end

local function invoke(action, args)
    return ReplicatedStorage.Replicator:InvokeServer("FruitsHandler", action, args)
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
local gemsStart = data.Gems.Value
local spinsStart = math.floor(gemsStart / SPIN_COST)

invoke("SwitchSlot", { Slot = slot })

local found = false
repeat
    task.wait(SPIN_DELAY)
    invoke("Spin", {})

    local inGameName = data.Slots[tostring(slot)].Value
    local info = fruitByName[inGameName]
    local official = info and info.official or inGameName
    local rarity = info and info.rarity or "Unknown"

    local gemsLeft = data.Gems.Value
    local spinsLeft = math.floor(gemsLeft / SPIN_COST)
    local gemsSpent = gemsStart - gemsLeft
    local spinsSpent = spinsStart - spinsLeft

    print("You got " .. official .. " [In-game name:" .. inGameName .. ",Rarity:" .. rarity .. "]")

    sendWebhook({
        title = "You Opened a New Fruit!!!",
        color = RARITY_COLORS[rarity] or 0xffffff,
        image = info and { url = info.image } or nil,
        description = "**Slot : " .. tostring(slot)
            .. "\nOfficial name: " .. official
            .. "\nIn-game name: " .. inGameName
            .. "\nRarity: " .. rarity
            .. "\nOriginal Gems: " .. gemsStart
            .. "\nOriginal Spins: " .. spinsStart
            .. "\nGems Left: " .. gemsLeft
            .. "\nSpin Left: " .. spinsLeft
            .. "\nGems Spent: " .. gemsSpent
            .. "\nSpin Spent: " .. spinsSpent .. "**",
    })

    found = contains(wantedFruits, inGameName) or wantsRarity(rarity)
until found or gemsLeft < SPIN_COST

print("Script has stopped")
sendWebhook({ title = "Script has stopped", color = 0xffffff })
