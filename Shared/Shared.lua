Shared = {}

Shared.Debug = true  -- Enable debug logs to console if not need set to false

Shared.LogsEnable = true -- Enable Discord Logging or not set to false to disable
-- Set Webhook in server/sv_main.lua lines 170 and 237 and 303 and 354

Shared.Target = 'qb-target' -- 'qb-target' or 'interact'

Shared.PedLocation = vector4(-766.6, 5580.36, 33.61, 89.67)

-- You can add more locations by adding more 'or' statements above.
Shared.DeliveryLocation = 
    math.random() < 0.5 and vector4(-685.5, 5833.76, 16.87, 134.08)
    or vector4(1219.75, 1835.69, 79.46, 351.28)
    or vector4(-248.36, 6204.66, 31.03, 45.76)
    -- use 'or ' vector4(coords)

Shared.VehicleSpawns = {
    vector4(-773.78, 5575.65, 33.49, 91.27),
    vector4(-773.75, 5578.16, 33.49, 86.25)
}

Shared.PedModel = math.random() < 0.5 and {model = 'cs_hunter', scenario = 'WORLD_HUMAN_STAND_IMPATIENT'}
    or {model = 'ig_hunter', scenario = 'WORLD_HUMAN_STAND_IMPATIENT'}

Shared.VehicleModel = 'bison'

Shared.RequiredItem = 'weapon_knife'

Shared.DeliveryKey = 'L'

Shared.HuntingZone = {
    center = vector3(-569.44, 5641.0, 38.52),
    radius = 100.0,
    heading = 332.91
}

Shared.AnimalModels = {
    'a_c_deer',
    'a_c_mtlion',
    'a_c_boar'
}

Shared.TargetSettings = {
    HunterPed = {
        qbTarget = {
            type = "client",
            event = "Hunting:client:openMenu",
            icon = "fas fa-paw",
            label = "Talk to Hunter",
            distance = 2.5
        },
        interact = {
            name = 'hunting_ped',
            id = 'hunting_ped_interaction',
            distance = 8.0,
            interactDst = 2.5,
            label = 'Talk to Hunter',
            event = 'Hunting:client:openMenu'
        }
    },
    SkinAnimal = {
        qbTarget = {
            type = "client",
            event = "Hunting:client:skinAnimal",
            icon = "fas fa-scissors",
            label = "Skin Animal",
            distance = 2.0
        },
    }
}

Shared.Icons = {
    mainLogo = 'https://i.ibb.co/mVFjQ9Q9/unnamed-2-removebg-preview.png',
    
    stats = {
        hunts = '🎯',
        animals = '🦌',
        money = '💰',
        stored = '📦',
        session = '🔫',
        viewList = '📋'
    },
    
    instructions = {
        step1 = '🚗',
        step2 = '🏹',
        step3 = '🛑',
        step4 = '📦'
    },
    
    rewards = {
        money = '💵',
        knife = '🔪'
    },
    
    buttons = {
        start = '🏹',
        stop = '🛑',
        collect = '📦'
    },
    
    header = '📖',
    footer = ''
}

Shared.AnimalIcons = { -- Icons for each animal type
    ['a_c_deer'] = 'https://i.ibb.co/mVFjQ9Q9/unnamed-2-removebg-preview.png',
    ['a_c_mtlion'] = 'https://i.ibb.co/bMQ9KZ2B/14-B95356-039-D-4-FA4-98-B3-41662-D7-F36-FE-removebg-preview.png',
    ['a_c_boar'] = 'https://i.ibb.co/wrd8n5Dp/unnamed-3-removebg-preview.png'
}

Shared.AnimalNames = {
    ['a_c_deer'] = 'Deer',
    ['a_c_mtlion'] = 'Mountain Lion',
    ['a_c_boar'] = 'Wild Boar'
}

Shared.MaxAnimalsInZone = 14

Shared.AnimalSpawnInterval = 30000

Shared.AnimalWanderRadius = 50.0

Shared.SkinReward = { -- Reward range for skinning an animal
    min = 50,
    max = 150
}

Shared.DeliveryReward = {
    perSkin = math.random(100,  250)
}

Shared.Blip = {
    sprite = 141,
    color = 2,
    scale = 0.8,
    label = 'Hunting Station'
}

Shared.DeliveryBlip = { -- Blip settings for delivery point
    sprite = 478,
    color = 5,
    scale = 0.7,
    label = 'Delivery Point'
}


function DebugLog(event, message, type)
    if not Shared.Debug then return end
    local colors = { info = "^5", success = "^2", warning = "^3", error = "^1" }
    print((colors[type] or "^7") .. "[Hunting:" .. event .. "] ^7" .. message)
end

if IsDuplicityVersion() then -- Dont Touch this
    exports('GetSharedObject', function()
        return Shared
    end)
end

-- Script by Moayed | Discord: 2.sk In 10/18/2025

-- Do not change the script name, if you change it  will cause the server to crash