local QBCore = exports['qb-core']:GetCoreObject()

function DebugLog(event, message, type)
    if not Shared.Debug then return end
    local colors = { info = "^5", success = "^2", warning = "^3", error = "^1" }
    print((colors[type] or "^7") .. "[Hunting:" .. event .. "] ^7" .. message)
end

CreateThread(function()
    DebugLog("Database", "Creating Hunting database tables...", "info")
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS Hunting_stats (
            identifier VARCHAR(50) PRIMARY KEY,
            total_hunts INT DEFAULT 0,
            total_skins INT DEFAULT 0,
            total_earned INT DEFAULT 0,
            collected_skins INT DEFAULT 0,
            hunted_animals TEXT
        )
    ]], {}, function()
        DebugLog("Database", "Table created, checking columns...", "info")
        
        MySQL.Async.fetchAll([[
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE table_name = 'Hunting_stats' 
            AND column_name = 'collected_skins'
        ]], {}, function(result)
            if result and result[1] and result[1].count == 0 then
                DebugLog("Database", "Adding missing collected_skins column...", "warning")
                MySQL.Async.execute([[
                    ALTER TABLE Hunting_stats ADD COLUMN collected_skins INT DEFAULT 0
                ]], {}, function()
                    DebugLog("Database", "Column added successfully", "success")
                end)
            end
        end)
        
        MySQL.Async.fetchAll([[
            SELECT COUNT(*) as count 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE table_name = 'Hunting_stats' 
            AND column_name = 'hunted_animals'
        ]], {}, function(result)
            if result and result[1] and result[1].count == 0 then
                DebugLog("Database", "Adding missing hunted_animals column...", "warning")
                MySQL.Async.execute([[
                    ALTER TABLE Hunting_stats ADD COLUMN hunted_animals TEXT
                ]], {}, function()
                    DebugLog("Database", "hunted_animals column added successfully", "success")
                end)
            else
                DebugLog("Database", "All columns exist, database ready", "success")
            end
        end)
    end)
end)

QBCore.Functions.CreateCallback('Hunting:server:getStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        DebugLog("Callback", "Player not found for getStats", "error")
        return cb(nil) 
    end
    
    local identifier = Player.PlayerData.citizenid
    DebugLog("Callback", "Getting stats for player: " .. identifier, "info")
    
    MySQL.Async.fetchAll('SELECT * FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
        if result[1] then
            DebugLog("Callback", "Stats retrieved from database", "success")
            cb({
                totalHunts = result[1].total_hunts,
                totalSkins = result[1].total_skins,
                totalEarned = result[1].total_earned
            })
        else
            DebugLog("Callback", "Creating new stats entry for player", "info")
            MySQL.Async.execute('INSERT INTO Hunting_stats (identifier) VALUES (?)', {identifier})
            cb({
                totalHunts = 0,
                totalSkins = 0,
                totalEarned = 0
            })
        end
    end)
end)

QBCore.Functions.CreateCallback('Hunting:server:getCollectedSkins', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        DebugLog("Callback", "Player not found for getCollectedSkins", "error")
        return cb(0) 
    end
    
    local identifier = Player.PlayerData.citizenid
    DebugLog("Callback", "Getting collected skins for: " .. identifier, "info")
    
    MySQL.Async.fetchAll('SELECT collected_skins FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
        if result[1] then
            local skins = result[1].collected_skins or 0
            DebugLog("Callback", "Player has " .. skins .. " collected skins", "info")
            cb(skins)
        else
            MySQL.Async.execute('INSERT INTO Hunting_stats (identifier) VALUES (?)', {identifier})
            cb(0)
        end
    end)
end)

QBCore.Functions.CreateCallback('QBCore:HasItem', function(source, cb, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        DebugLog("Callback", "Player not found for HasItem check", "error")
        return cb(false) 
    end
    
    local hasItem = Player.Functions.GetItemByName(item)
    DebugLog("Callback", "Item check for " .. item .. ": " .. tostring(hasItem ~= nil), "info")
    cb(hasItem ~= nil)
end)

QBCore.Functions.CreateCallback('Hunting:server:getHuntedAnimals', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        DebugLog("Callback", "Player not found for getHuntedAnimals", "error")
        return cb({}) 
    end
    
    local identifier = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT hunted_animals FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
        if result[1] and result[1].hunted_animals then
            local huntedAnimals = json.decode(result[1].hunted_animals) or {}
            DebugLog("Callback", "Retrieved hunted animals for player", "success")
            cb(huntedAnimals)
        else
            cb({})
        end
    end)
end)

RegisterNetEvent('Hunting:server:addSkin', function(animalType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        DebugLog("Event", "Player not found for addSkin", "error")
        return 
    end
    
    local identifier = Player.PlayerData.citizenid
    
    MySQL.Async.fetchAll('SELECT hunted_animals FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
        local huntedAnimals = {}
        
        if result[1] and result[1].hunted_animals then
            huntedAnimals = json.decode(result[1].hunted_animals) or {}
        end
        
        huntedAnimals[animalType] = (huntedAnimals[animalType] or 0) + 1
        
        local jsonData = json.encode(huntedAnimals)
        
        MySQL.Async.execute([[
            UPDATE Hunting_stats 
            SET hunted_animals = ?
            WHERE identifier = ?
        ]], {jsonData, identifier}, function()
            DebugLog("Event", "Hunted animal saved: " .. animalType .. " (Total: " .. huntedAnimals[animalType] .. ")", "success")
            
            if Shared.LogsEnable then
                exports['Md-logs']:Log({ -- Download Script Md-logs
                    source = src,
                    category = 'hunting',
                    event = 'addSkin',
                    message = 'Player skinned an animal',
                    details = {
                        ['Citizen ID'] = identifier,
                        ['Player Name'] = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                        ['Animal Type'] = animalType,
                        ['Total of This Type'] = huntedAnimals[animalType]
                    },
                    webhook = 'https://ptb.discord.com/api/webhooks/1428996460837339166/zjElONxNr0YAL4Zr40EgGh9B6b5273AiGng59WOlYdujwfDG7zyNlQ3pKwxY2zpi0Lkh'
                })
                DebugLog("Event", "Log sent for skinned animal", "info")
            end
        end)
    end)
end)

RegisterNetEvent('Hunting:server:storeSkins', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        DebugLog("Event", "Player not found for storeSkins", "error")
        return 
    end
    
    local identifier = Player.PlayerData.citizenid
    
    DebugLog("Event", "Storing " .. amount .. " skins for " .. identifier, "info")
    
    MySQL.Async.fetchAll('SELECT collected_skins FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
        local currentSkins = 0
        if result[1] then
            currentSkins = result[1].collected_skins or 0
        end
        
        local newTotal = currentSkins + amount
        
        MySQL.Async.execute([[
            UPDATE Hunting_stats 
            SET collected_skins = ?
            WHERE identifier = ?
        ]], {newTotal, identifier}, function()
            DebugLog("Event", "Stored successfully. Total: " .. newTotal, "success")
            
            if Shared.LogsEnable then
                exports['Md-logs']:Log({
                    source = src,
                    category = 'hunting',
                    event = 'skins_stored',
                    message = 'Player stored skins after hunt',
                    details = {
                        ['Citizen ID'] = identifier,
                        ['Player Name'] = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                        ['Skins Stored'] = amount,
                        ['Previous Total'] = currentSkins,
                        ['New Total'] = newTotal
                    },
                    webhook = 'https://ptb.discord.com/api/webhooks/1428996460837339166/zjElONxNr0YAL4Zr40EgGh9B6b5273AiGng59WOlYdujwfDG7zyNlQ3pKwxY2zpi0Lkh'
                })
            end
        end)
    end)
end)

RegisterNetEvent('Hunting:server:deliverSkins', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        DebugLog("Event", "Player not found for delivery", "error")
        return 
    end
    
    if amount <= 0 then
        DebugLog("Event", "Invalid amount: " .. amount, "error")
        return
    end
    
    local identifier = Player.PlayerData.citizenid
    local reward = amount * Shared.DeliveryReward.perSkin
    
    DebugLog("Event", "Processing delivery for " .. identifier, "info")
    DebugLog("Event", "Amount: " .. amount .. " skins, Reward: $" .. reward, "info")
    
    local success = Player.Functions.AddMoney('cash', reward)
    
    if success then
        DebugLog("Event", "Money added successfully", "success")
    else
        DebugLog("Event", "Failed to add money", "error")
    end
    
    MySQL.Async.execute([[
        UPDATE Hunting_stats 
        SET total_hunts = total_hunts + 1,
            total_skins = total_skins + ?,
            total_earned = total_earned + ?,
            collected_skins = 0
        WHERE identifier = ?
    ]], {amount, reward, identifier}, function(affectedRows)
        DebugLog("Event", "Database updated, rows affected: " .. affectedRows, "success")
        TriggerClientEvent('QBCore:Notify', src, 'Delivered ' .. amount .. ' skins for $' .. reward, 'success')
        DebugLog("Event", "Payment completed successfully", "success")
        
        MySQL.Async.fetchAll('SELECT total_hunts, total_skins, total_earned FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
            if result[1] and Shared.LogsEnable then
                local totalHunts = result[1].total_hunts or 0
                local totalSkins = result[1].total_skins or 0
                local totalEarned = result[1].total_earned or 0
                
                exports['Md-logs']:Log({
                    source = src,
                    category = 'hunting',
                    event = 'delivery_completed',
                    message = 'Player completed hunting delivery',
                    details = {
                        ['Citizen ID'] = identifier,
                        ['Player Name'] = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                        ['Skins Delivered'] = amount,
                        ['Reward Amount'] = '$' .. reward,
                        ['Total Hunts'] = totalHunts,
                        ['Total Skins Ever'] = totalSkins,
                        ['Total Earned Ever'] = '$' .. totalEarned
                    },
                    webhook = 'https://ptb.discord.com/api/webhooks/1428996460837339166/zjElONxNr0YAL4Zr40EgGh9B6b5273AiGng59WOlYdujwfDG7zyNlQ3pKwxY2zpi0Lkh'
                })
            end
        end)
    end)
end)


-- For Developers Commands Add Animal Test 

-- RegisterCommand('add3animal', function(source, args, rawCommand)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)
--     if not Player then 
--         DebugLog("Command", "Player not found for add3animal", "error")
--         return 
--     end
    
--     local animalType = args[1]
--     if not animalType then
--         TriggerClientEvent('QBCore:Notify', src, 'Usage: /add3animal [animal_type]', 'error')
--         DebugLog("Command", "No animal type provided", "error")
--         return
--     end

--     local identifier = Player.PlayerData.citizenid
    
--     MySQL.Async.fetchAll('SELECT hunted_animals, collected_skins FROM Hunting_stats WHERE identifier = ?', {identifier}, function(result)
--         local huntedAnimals = {}
--         local collectedSkins = 0
        
--         if result[1] then
--             huntedAnimals = json.decode(result[1].hunted_animals) or {}
--             collectedSkins = result[1].collected_skins or 0
--         end
        
--         huntedAnimals[animalType] = (huntedAnimals[animalType] or 0) + 5000
--         collectedSkins = collectedSkins + 5000

--         local jsonData = json.encode(huntedAnimals)
        
--         MySQL.Async.execute('UPDATE Hunting_stats SET hunted_animals = ?, collected_skins = ? WHERE identifier = ?', 
--             {jsonData, collectedSkins, identifier}, function()
--                 DebugLog("Command", "Added 5000 " .. animalType .. " skins for player", "success")
--                 TriggerClientEvent('QBCore:Notify', src, 'Added 5000 ' .. animalType .. ' skins', 'success')

--                 if Shared.LogsEnable then
--                     exports['Md-logs']:Log({
--                         source = src,
--                         category = 'hunting',
--                         event = 'Add Skin Command (Admin)',
--                         message = 'Admin added skins via command',
--                         details = {
--                             ['Citizen ID'] = identifier,
--                             ['Player Name'] = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
--                             ['Animal Type'] = animalType,
--                             ['Amount Added'] = 5000,
--                             ['New Total Collected'] = collectedSkins
--                         },
--                         webhook = 'https://ptb.discord.com/api/webhooks/1428996460837339166/zjElONxNr0YAL4Zr40EgGh9B6b5273AiGng59WOlYdujwfDG7zyNlQ3pKwxY2zpi0Lkh'
--                     })
--                 end
--             end)
--     end)
-- end)