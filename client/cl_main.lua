local QBCore = exports['qb-core']:GetCoreObject()
local HuntingPed = nil
local HuntingBlip = nil
local DeliveryBlip = nil
local ZoneBlip = nil
local isHunting = false
local isDelivering = false
local currentVehicle = nil
local skinnedAnimals = 0
local collectedSkins = 0
local spawnedAnimals = {}
local animalSpawnTimer = 0
local isInitialized = false


function InitializeHunting()
    if isInitialized then
        DebugLog("Init", "Already initialized, skipping...", "warning")
        return
    end
    
    CreateThread(function()
        Wait(2000)
        
        DebugLog("Init", "Initializing hunting system...", "info")
        
        if not CheckRequiredResources() then
            DebugLog("Init", "Required resources not available, retrying...", "warning")
            Wait(5000)
            if not CheckRequiredResources() then
                DebugLog("Init", "Failed to initialize - missing required resources", "error")
                return
            end
        end
        
        SendNUIMessage({ action = 'loadIcons', icons = Shared.Icons })
        
        SpawnHuntingPed()
        CreateHuntingBlips()
        SetupTargeting()
        StartBackgroundThreads()
        
        isInitialized = true
        DebugLog("Init", "Hunting system ready", "success")
    end)
end

function CheckRequiredResources()
    local targetResource = Shared.Target == 'interact' and 'interact' or 'qb-target'
    local qbCoreState = GetResourceState('qb-core')
    local targetState = GetResourceState(targetResource)
    
    local allGood = true
    
    DebugLog("Check", "Checking required resources...", "info")
    
    if qbCoreState == 'started' then
        DebugLog("Check", "qb-core detected and started", "success")
    else
        DebugLog("Check", "qb-core not found or not started", "error")
        allGood = false
    end
    
    if targetState == 'started' then
        DebugLog("Check", targetResource .. " detected and started", "success")
    else
        DebugLog("Check", targetResource .. " status: " .. targetState, "error")
        allGood = false
    end
    
    return allGood
end

function SpawnHuntingPed()
    if DoesEntityExist(HuntingPed) then
        DebugLog("Init", "Ped already exists, removing old one...", "warning")
        DeleteEntity(HuntingPed)
        HuntingPed = nil
        Wait(100)
    end
    
    RequestModel(GetHashKey(Shared.PedModel.model))
    while not HasModelLoaded(GetHashKey(Shared.PedModel.model)) do Wait(10) end
    
    local loc = Shared.PedLocation
    HuntingPed = CreatePed(4, GetHashKey(Shared.PedModel.model), loc.x, loc.y, loc.z - 1.0, loc.w, false, true)
    
    FreezeEntityPosition(HuntingPed, true)
    SetEntityInvincible(HuntingPed, true)
    SetBlockingOfNonTemporaryEvents(HuntingPed, true)
    TaskStartScenarioInPlace(HuntingPed, Shared.PedModel.scenario, 0, true)
    
    DebugLog("Init", "Ped spawned successfully", "success")
end

function CreateHuntingBlips()
    if HuntingBlip and DoesBlipExist(HuntingBlip) then
        DebugLog("Init", "Blip already exists, removing old one...", "warning")
        RemoveBlip(HuntingBlip)
        HuntingBlip = nil
        Wait(100)
    end
    
    local loc = Shared.PedLocation
    HuntingBlip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(HuntingBlip, Shared.Blip.sprite)
    SetBlipColour(HuntingBlip, Shared.Blip.color)
    SetBlipScale(HuntingBlip, Shared.Blip.scale)
    SetBlipAsShortRange(HuntingBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Shared.Blip.label)
    EndTextCommandSetBlipName(HuntingBlip)
    
    DebugLog("Init", "Blips created successfully", "success")
end

function SetupTargeting()
    Wait(500)
    
    if not DoesEntityExist(HuntingPed) then
        DebugLog("Target", "Ped does not exist, cannot setup targeting", "error")
        return
    end
    
    local config = Shared.TargetSettings.HunterPed
    
    if Shared.Target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(HuntingPed, {
            options = {{
                type = config.qbTarget.type,
                event = config.qbTarget.event,
                icon = config.qbTarget.icon,
                label = config.qbTarget.label
            }},
            distance = config.qbTarget.distance
        })
    elseif Shared.Target == 'interact' then
        exports.interact:AddLocalEntityInteraction({
            entity = HuntingPed,
            name = config.interact.name,
            id = config.interact.id,
            distance = config.interact.distance,
            interactDst = config.interact.interactDst,
            options = {
                {
                    label = config.interact.label,
                    action = function(entity, coords, args)
                        TriggerEvent(config.interact.event)
                    end,
                }
            }
        })
    end
    
    DebugLog("Target", "Targeting setup complete", "success")
end

function StartBackgroundThreads()
    AddTargetToDeadAnimals()
    CheckDeliveryDistance()
end

function OpenHuntingMenu()
    DebugLog("UI", "Opening menu...", "info")
    
    QBCore.Functions.TriggerCallback('Hunting:server:getStats', function(stats)
        QBCore.Functions.TriggerCallback('Hunting:server:getCollectedSkins', function(skins)
            collectedSkins = skins
            
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openUI',
                stats = stats,
                isHunting = isHunting,
                isDelivering = isDelivering,
                skinnedAnimals = skinnedAnimals,
                collectedSkins = collectedSkins
            })
        end)
    end)
end

function CloseUI()
    SetNuiFocus(false, false)
    DebugLog("UI", "Menu closed", "info")
end

function StartHunt()
    if isHunting then
        QBCore.Functions.Notify('Already hunting!', 'error')
        return
    end
    
    if isDelivering then
        QBCore.Functions.Notify('Finish delivery first!', 'error')
        return
    end
    
    DebugLog("Hunt", "Starting hunt...", "info")
    
    SpawnHuntingVehicle()
    CreateHuntingZone()
    StartAnimalSpawner()
    
    isHunting = true
    skinnedAnimals = 0
    
    QBCore.Functions.Notify('Hunt zone marked!', 'success')
end

function SpawnHuntingVehicle()
    RequestModel(GetHashKey(Shared.VehicleModel))
    while not HasModelLoaded(GetHashKey(Shared.VehicleModel)) do Wait(10) end
    
    local spawn = GetFreeVehicleSpawn()
    currentVehicle = CreateVehicle(GetHashKey(Shared.VehicleModel), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(currentVehicle, "HUNT"..math.random(1000, 9999))
    
    TaskWarpPedIntoVehicle(PlayerPedId(), currentVehicle, -1)
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(currentVehicle))
    
    DebugLog("Vehicle", "Vehicle spawned", "success")
end

function GetFreeVehicleSpawn()
    for _, spawn in ipairs(Shared.VehicleSpawns) do
        if not IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then
            return spawn
        end
    end
    return Shared.VehicleSpawns[1]
end

function CreateHuntingZone()
    if ZoneBlip and DoesBlipExist(ZoneBlip) then
        RemoveBlip(ZoneBlip)
    end
    
    local zone = Shared.HuntingZone
    ZoneBlip = AddBlipForRadius(zone.center.x, zone.center.y, zone.center.z, zone.radius)
    SetBlipColour(ZoneBlip, 1)
    SetBlipAlpha(ZoneBlip, 128)
    
    SetNewWaypoint(zone.center.x, zone.center.y)
end

function StartAnimalSpawner()
    CreateThread(function()
        while isHunting do
            if GetGameTimer() - animalSpawnTimer > Shared.AnimalSpawnInterval then
                CleanDeadAnimals()
                
                local alive = CountAliveAnimals()
                if alive < Shared.MaxAnimalsInZone then
                    for i = 1, math.min(3, Shared.MaxAnimalsInZone - alive) do
                        SpawnAnimal()
                    end
                end
                
                animalSpawnTimer = GetGameTimer()
            end
            Wait(5000)
        end
        
        CleanAllAnimals()
    end)
end

function SpawnAnimal()
    local model = Shared.AnimalModels[math.random(#Shared.AnimalModels)]
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do Wait(10) end
    
    local zone = Shared.HuntingZone
    local angle = math.random() * 2 * math.pi
    local dist = math.random(20, zone.radius - 10)
    local x = zone.center.x + math.cos(angle) * dist
    local y = zone.center.y + math.sin(angle) * dist
    
    local found, z = GetGroundZFor_3dCoord(x, y, zone.center.z + 100.0, false)
    z = found and z or zone.center.z
    
    local animal = CreatePed(28, GetHashKey(model), x, y, z, math.random(0, 360), true, false)
    
    if DoesEntityExist(animal) then
        SetEntityAsMissionEntity(animal, true, true)
        SetPedRelationshipGroupHash(animal, GetHashKey("WILD_ANIMAL"))
        TaskWanderInArea(animal, x, y, z, Shared.AnimalWanderRadius, 1.0, 1.0)
        
        table.insert(spawnedAnimals, animal)
        DebugLog("Spawn", "Spawned " .. model, "success")
    end
end

function CountAliveAnimals()
    local count = 0
    for _, animal in ipairs(spawnedAnimals) do
        if DoesEntityExist(animal) and not IsEntityDead(animal) then
            count = count + 1
        end
    end
    return count
end

function CleanDeadAnimals()
    for i = #spawnedAnimals, 1, -1 do
        if not DoesEntityExist(spawnedAnimals[i]) then
            table.remove(spawnedAnimals, i)
        end
    end
end

function CleanAllAnimals()
    for _, animal in ipairs(spawnedAnimals) do
        if DoesEntityExist(animal) then DeleteEntity(animal) end
    end
    spawnedAnimals = {}
end

function AddTargetToDeadAnimals()
    CreateThread(function()
        while true do
            if isHunting then
                for _, animal in ipairs(spawnedAnimals) do
                    if DoesEntityExist(animal) and IsEntityDead(animal) then
                        local config = Shared.TargetSettings.SkinAnimal
                        
                        exports['qb-target']:AddTargetEntity(animal, {
                            options = {{
                                type = config.qbTarget.type,
                                event = config.qbTarget.event,
                                icon = config.qbTarget.icon,
                                label = config.qbTarget.label,
                                entity = animal
                            }},
                            distance = config.qbTarget.distance
                        })
                    end
                end
                Wait(1000)
            else
                Wait(5000)
            end
        end
    end)
end

function SkinAnimal(data)
    local entity = data.entity
    
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasKnife)
        if not hasKnife then
            QBCore.Functions.Notify('Need a knife!', 'error')
            return
        end
        
        TaskTurnPedToFaceEntity(PlayerPedId(), entity, 2000)
        Wait(2000)
        
        local animalType = GetAnimalType(entity)
        QBCore.Functions.Progressbar("skin_animal", "Skinning animal...", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableCombat = true
        }, {
            animDict = "amb@medic@standing@kneel@base",
            anim = "base",
            flags = 1
        }, {}, {}, function()
            ClearPedTasks(PlayerPedId())
            RemoveAnimalFromList(entity)
            DeleteEntity(entity)
            
            skinnedAnimals = skinnedAnimals + 1
            TriggerServerEvent('Hunting:server:addSkin', animalType)
            
            QBCore.Functions.Notify('Skinned! Total: ' .. skinnedAnimals, 'success')
            DebugLog("Skin", "Skinned " .. animalType, "success")
        end, function()
            ClearPedTasks(PlayerPedId())
            QBCore.Functions.Notify('Cancelled', 'error')
        end)
    end, Shared.RequiredItem)
end

function GetAnimalType(entity)
    local model = GetEntityModel(entity)
    for _, animalModel in ipairs(Shared.AnimalModels) do
        if GetHashKey(animalModel) == model then
            return animalModel
        end
    end
    return 'unknown'
end

function RemoveAnimalFromList(entity)
    for i = #spawnedAnimals, 1, -1 do
        if spawnedAnimals[i] == entity then
            table.remove(spawnedAnimals, i)
            break
        end
    end
end

function EndHunt()
    DebugLog("Ending", "Ending hunt...", "info")
    
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteVehicle(currentVehicle)
        currentVehicle = nil
    end
    
    if skinnedAnimals > 0 then
        TriggerServerEvent('Hunting:server:storeSkins', skinnedAnimals)
    end
    
    if ZoneBlip and DoesBlipExist(ZoneBlip) then
        RemoveBlip(ZoneBlip)
        ZoneBlip = nil
    end
    
    CleanAllAnimals()
    
    isHunting = false
    skinnedAnimals = 0
    animalSpawnTimer = 0
    
    QBCore.Functions.Notify('Mission ended!', 'success')
end

function StartDelivery()
    QBCore.Functions.TriggerCallback('Hunting:server:getCollectedSkins', function(skins)
        collectedSkins = skins
        
        if collectedSkins <= 0 then
            QBCore.Functions.Notify('No skins!', 'error')
            return
        end
        
        if isHunting then
            QBCore.Functions.Notify('End hunt first!', 'error')
            return
        end
        
        DebugLog("Delivery", "Starting delivery...", "info")
        
        SpawnDeliveryVehicle()
        CreateDeliveryBlip()
        
        isDelivering = true
        SetNewWaypoint(Shared.DeliveryLocation.x, Shared.DeliveryLocation.y)
        QBCore.Functions.Notify('Deliver ' .. collectedSkins .. ' skins', 'success')
    end)
end

function CreateDeliveryBlip()
    if DeliveryBlip and DoesBlipExist(DeliveryBlip) then
        RemoveBlip(DeliveryBlip)
    end
    
    local dloc = Shared.DeliveryLocation
    DeliveryBlip = AddBlipForCoord(dloc.x, dloc.y, dloc.z)
    SetBlipSprite(DeliveryBlip, Shared.DeliveryBlip.sprite)
    SetBlipColour(DeliveryBlip, Shared.DeliveryBlip.color)
    SetBlipScale(DeliveryBlip, Shared.DeliveryBlip.scale)
    SetBlipAsShortRange(DeliveryBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Shared.DeliveryBlip.label)
    EndTextCommandSetBlipName(DeliveryBlip)
    
    DebugLog("Delivery", "Delivery blip created", "success")
end

function SpawnDeliveryVehicle()
    RequestModel(GetHashKey(Shared.VehicleModel))
    while not HasModelLoaded(GetHashKey(Shared.VehicleModel)) do Wait(10) end
    
    local spawn = GetFreeVehicleSpawn()
    currentVehicle = CreateVehicle(GetHashKey(Shared.VehicleModel), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(currentVehicle, "DLVR"..math.random(1000, 9999))
    
    TaskWarpPedIntoVehicle(PlayerPedId(), currentVehicle, -1)
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(currentVehicle))
end

function CheckDeliveryDistance()
    CreateThread(function()
        while true do
            if isDelivering then
                local coords = GetEntityCoords(PlayerPedId())
                local dist = #(coords - vector3(Shared.DeliveryLocation.x, Shared.DeliveryLocation.y, Shared.DeliveryLocation.z))
                
                if dist <= 3.0 then
                    DrawText3D(Shared.DeliveryLocation.x, Shared.DeliveryLocation.y, Shared.DeliveryLocation.z + 1.0, '[' .. Shared.DeliveryKey .. '] Deliver')
                    
                    if IsControlJustReleased(0, 182) then
                        CompleteDelivery()
                    end
                end
                Wait(0)
            else
                Wait(1000)
            end
        end
    end)
end

function CompleteDelivery()
    DebugLog("Delivery", "Completing delivery...", "info")
    
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        Wait(2000)
    end
    
    if currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteVehicle(currentVehicle)
        currentVehicle = nil
    end
    
    if DeliveryBlip and DoesBlipExist(DeliveryBlip) then
        RemoveBlip(DeliveryBlip)
        DeliveryBlip = nil
        DebugLog("Delivery", "Delivery blip removed", "success")
    end
    
    if collectedSkins > 0 then
        TriggerServerEvent('Hunting:server:deliverSkins', collectedSkins)
        Wait(1000)
    end
    
    collectedSkins = 0
    isDelivering = false
    
    DebugLog("Delivery", "Delivery complete", "success")
end

function GetHuntedAnimals(data, cb)
    QBCore.Functions.TriggerCallback('Hunting:server:getHuntedAnimals', function(animals)
        local animalData = {}
        for type, _ in pairs(animals) do
            animalData[type] = {
                name = Shared.AnimalNames[type] or type,
                icon = Shared.AnimalIcons[type] or 'https://via.placeholder.com/80'
            }
        end
        cb({ animals = animals, animalData = animalData })
    end)
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.4, 0.4)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 41, 128, 185, 200)
    ClearDrawOrigin()
end

function Cleanup()
    if HuntingPed and DoesEntityExist(HuntingPed) then DeleteEntity(HuntingPed) end
    if HuntingBlip and DoesBlipExist(HuntingBlip) then RemoveBlip(HuntingBlip) end
    if DeliveryBlip and DoesBlipExist(DeliveryBlip) then RemoveBlip(DeliveryBlip) end
    if ZoneBlip and DoesBlipExist(ZoneBlip) then RemoveBlip(ZoneBlip) end
    CleanAllAnimals()
    isInitialized = false
    DebugLog("Cleanup", "All cleaned", "info")
end

RegisterNetEvent('Hunting:client:openMenu', OpenHuntingMenu)
RegisterNetEvent('Hunting:client:skinAnimal', SkinAnimal)
RegisterNetEvent('Hunting:client:updateCollectedSkins', function(amount) collectedSkins = amount end)

RegisterNUICallback('closeUI', function(data, cb) CloseUI() cb('ok') end)
RegisterNUICallback('startHunt', function(data, cb) cb('ok') CloseUI() StartHunt() end)
RegisterNUICallback('endMission', function(data, cb) cb('ok') CloseUI() EndHunt() end)
RegisterNUICallback('collectSkins', function(data, cb) cb('ok') CloseUI() StartDelivery() end)
RegisterNUICallback('getHuntedAnimals', GetHuntedAnimals)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Cleanup()
    end
end)

CreateThread(function()
    InitializeHunting()
end)