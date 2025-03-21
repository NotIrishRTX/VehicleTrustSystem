local whitelistCache = {}
local refreshInterval = 5 * 60 * 1000

function GetPlayerIdentifiers(source)
    local identifiers = {
        discord = nil,
        steam = nil,
        license = nil
    }
    
    for _, identifier in pairs(GetPlayerIdentifiers(source)) do
        if string.find(identifier, "discord:") then
            identifiers.discord = string.gsub(identifier, "discord:", "")
        elseif string.find(identifier, "steam:") then
            identifiers.steam = string.gsub(identifier, "steam:", "")
        elseif string.find(identifier, "license:") then
            identifiers.license = string.gsub(identifier, "license:", "")
        end
    end
    
    return identifiers
end

function LoadVehicleTrustData()
    exports.oxmysql:execute('SELECT * FROM vehicletrustsystem', {}, function(result)
        if result then
            whitelistCache = result
            print("[Vehicle Trust] Loaded " .. #result .. " vehicle trust entries from database.")
        else
            print("[Vehicle Trust] Failed to load vehicle trust data or no entries found.")
            whitelistCache = {}
        end
    end)
end

Citizen.CreateThread(function()
    LoadVehicleTrustData()
    
    while true do
        Citizen.Wait(refreshInterval)
        LoadVehicleTrustData()
    end
end)

RegisterNetEvent('primerp_vehwl:reloadwl')
AddEventHandler('primerp_vehwl:reloadwl', function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    
    TriggerClientEvent('primerp_vehwl:loadIdentifiers', src, identifiers)
    
    TriggerClientEvent('primerp_vehwl:RunCode:Client', src, whitelistCache)
end)

RegisterNetEvent('primerp_vehwl:Server:Check')
AddEventHandler('primerp_vehwl:Server:Check', function()
    local src = source
    TriggerClientEvent('primerp_vehwl:RunCode:Client', src, whitelistCache)
end)

RegisterNetEvent('primerp_vehwl:checkAccess')
AddEventHandler('primerp_vehwl:checkAccess', function(vehicleModel, modelName)
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local isWhitelisted = false
    local hasAccess = false
    local vehicleName = modelName
    
    for _, vehicle in pairs(whitelistCache) do
        local spawncode = vehicle.spawncode
        if GetHashKey(spawncode) == vehicleModel or string.lower(spawncode) == string.lower(modelName) then
            isWhitelisted = true
            vehicleName = spawncode
            
            if (identifiers.discord and identifiers.discord == vehicle.discord) or
               (identifiers.steam and identifiers.steam == vehicle.steam) or
               (identifiers.license and identifiers.license == vehicle.license) then
                if vehicle.allowed == 1 then
                    hasAccess = true
                    break
                end
            end
        end
    end
    
    TriggerClientEvent('primerp_vehwl:accessStatus', src, hasAccess, isWhitelisted, vehicleName)
end)

RegisterNetEvent('primerp_vehwl:listMyVehicles')
AddEventHandler('primerp_vehwl:listMyVehicles', function()
    local src = source
    local identifiers = GetPlayerIdentifiers(src)
    local playerVehicles = {}
    
    for _, vehicle in pairs(whitelistCache) do
        if ((identifiers.discord and identifiers.discord == vehicle.discord) or
            (identifiers.steam and identifiers.steam == vehicle.steam) or
            (identifiers.license and identifiers.license == vehicle.license)) and
           vehicle.allowed == 1 then
            table.insert(playerVehicles, {
                spawncode = vehicle.spawncode,
                owner = vehicle.owner
            })
        end
    end
    
    table.sort(playerVehicles, function(a, b)
        if a.owner == b.owner then
            return a.spawncode < b.spawncode
        end
        return a.owner > b.owner
    end)
    
    TriggerClientEvent('primerp_vehwl:displayVehicleList', src, playerVehicles)
end)

RegisterCommand("setowner", function(source, args, rawCommand)
    local src = source
    
    if not IsPlayerAceAllowed(src, "command.setowner") then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "You do not have permission to use this command!"}
        })
        return
    end
    
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            multiline = false,
            args = {"Vehicle Trust", "Usage: /setowner [playerID] [spawncode]"}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local spawncode = args[2]
    
    if not GetPlayerName(targetId) then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "Player ID " .. targetId .. " not found!"}
        })
        return
    end
    
    local targetIdentifiers = GetPlayerIdentifiers(targetId)
    
    exports.oxmysql:execute('INSERT INTO vehicletrustsystem (discord, steam, license, spawncode, owner, allowed) VALUES (?, ?, ?, ?, 1, 1) ON DUPLICATE KEY UPDATE owner = 1, allowed = 1', 
    {
        targetIdentifiers.discord,
        targetIdentifiers.steam, 
        targetIdentifiers.license,
        spawncode
    }, function(affectedRows)
        if affectedRows then
            TriggerClientEvent('chat:addMessage', src, {
                color = {0, 255, 0},
                multiline = false,
                args = {"Vehicle Trust", "Successfully set " .. GetPlayerName(targetId) .. " as owner of " .. spawncode}
            })
            
            TriggerClientEvent('chat:addMessage', targetId, {
                color = {0, 255, 0},
                multiline = false,
                args = {"Vehicle Trust", "You are now the owner of " .. spawncode}
            })
            
            LoadVehicleTrustData()
        else
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 0, 0},
                multiline = false,
                args = {"Vehicle Trust", "Failed to set ownership!"}
            })
        end
    end)
end, true)

RegisterCommand("trust", function(source, args, rawCommand)
    local src = source
    
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            multiline = false,
            args = {"Vehicle Trust", "Usage: /trust [playerID] [spawncode]"}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local spawncode = args[2]
    
    if not GetPlayerName(targetId) then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "Player ID " .. targetId .. " not found!"}
        })
        return
    end
    
    local identifiers = GetPlayerIdentifiers(src)
    local isOwner = false
    
    for _, vehicle in pairs(whitelistCache) do
        if vehicle.spawncode == spawncode and vehicle.owner == 1 and
           ((identifiers.discord and identifiers.discord == vehicle.discord) or
            (identifiers.steam and identifiers.steam == vehicle.steam) or
            (identifiers.license and identifiers.license == vehicle.license)) then
            isOwner = true
            break
        end
    end
    
    if not isOwner and not IsPlayerAceAllowed(src, "command.trust") then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "You don't own this vehicle or don't have permission!"}
        })
        return
    end
    
    local targetIdentifiers = GetPlayerIdentifiers(targetId)
    
    exports.oxmysql:execute('INSERT INTO vehicletrustsystem (discord, steam, license, spawncode, owner, allowed) VALUES (?, ?, ?, ?, 0, 1) ON DUPLICATE KEY UPDATE allowed = 1', 
    {
        targetIdentifiers.discord,
        targetIdentifiers.steam, 
        targetIdentifiers.license,
        spawncode
    }, function(affectedRows)
        if affectedRows then
            TriggerClientEvent('chat:addMessage', src, {
                color = {0, 255, 0},
                multiline = false,
                args = {"Vehicle Trust", "Successfully trusted " .. GetPlayerName(targetId) .. " with " .. spawncode}
            })
            
            TriggerClientEvent('chat:addMessage', targetId, {
                color = {0, 255, 0},
                multiline = false,
                args = {"Vehicle Trust", "You've been trusted with access to " .. spawncode}
            })
            
            LoadVehicleTrustData()
        else
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 0, 0},
                multiline = false,
                args = {"Vehicle Trust", "Failed to set trust!"}
            })
        end
    end)
end, false)

RegisterCommand("untrust", function(source, args, rawCommand)
    local src = source
    
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            multiline = false,
            args = {"Vehicle Trust", "Usage: /untrust [playerID] [spawncode]"}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local spawncode = args[2]
    
    if not GetPlayerName(targetId) then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "Player ID " .. targetId .. " not found!"}
        })
        return
    end
    
    local identifiers = GetPlayerIdentifiers(src)
    local isOwner = false
    
    for _, vehicle in pairs(whitelistCache) do
        if vehicle.spawncode == spawncode and vehicle.owner == 1 and
           ((identifiers.discord and identifiers.discord == vehicle.discord) or
            (identifiers.steam and identifiers.steam == vehicle.steam) or
            (identifiers.license and identifiers.license == vehicle.license)) then
            isOwner = true
            break
        end
    end
    
    if not isOwner and not IsPlayerAceAllowed(src, "command.untrust") then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "You don't own this vehicle or don't have permission!"}
        })
        return
    end
    
    local targetIdentifiers = GetPlayerIdentifiers(targetId)

    exports.oxmysql:execute('UPDATE vehicletrustsystem SET allowed = 0 WHERE spawncode = ? AND ((discord = ? AND discord IS NOT NULL) OR (steam = ? AND steam IS NOT NULL) OR (license = ? AND license IS NOT NULL))', 
    {
        spawncode,
        targetIdentifiers.discord,
        targetIdentifiers.steam,
        targetIdentifiers.license
    }, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = {0, 255, 0},
                multiline = false,
                args = {"Vehicle Trust", "Successfully revoked " .. GetPlayerName(targetId) .. "'s access to " .. spawncode}
            })
            
            TriggerClientEvent('chat:addMessage', targetId, {
                color = {255, 165, 0},
                multiline = false,
                args = {"Vehicle Trust", "Your access to " .. spawncode .. " has been revoked"}
            })
            
            LoadVehicleTrustData()
        else
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 0, 0},
                multiline = false,
                args = {"Vehicle Trust", "Failed to revoke trust or no matching record found!"}
            })
        end
    end)
end, false)

RegisterCommand("vehlist", function(source, args, rawCommand)
    local src = source
    
    local targetId = source
    if #args > 0 and IsPlayerAceAllowed(src, "command.vehlist") then
        targetId = tonumber(args[1])
        if not GetPlayerName(targetId) then
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 0, 0},
                multiline = false,
                args = {"Vehicle Trust", "Player ID " .. targetId .. " not found!"}
            })
            return
        end
    end
    
    if targetId ~= src and not IsPlayerAceAllowed(src, "command.vehlist") then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = false,
            args = {"Vehicle Trust", "You don't have permission to view others' vehicles!"}
        })
        return
    end
    
    local targetIdent = GetPlayerIdentifiers(targetId)
    local playerVehicles = {}
    
    for _, vehicle in pairs(whitelistCache) do
        if ((targetIdent.discord and targetIdent.discord == vehicle.discord) or
            (targetIdent.steam and targetIdent.steam == vehicle.steam) or
            (targetIdent.license and targetIdent.license == vehicle.license)) and
           vehicle.allowed == 1 then
            table.insert(playerVehicles, {
                spawncode = vehicle.spawncode,
                owner = vehicle.owner
            })
        end
    end
    
    table.sort(playerVehicles, function(a, b)
        if a.owner == b.owner then
            return a.spawncode < b.spawncode
        end
        return a.owner > b.owner
    end)
    
    if src == targetId then
        TriggerClientEvent('primerp_vehwl:displayVehicleList', src, playerVehicles)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            multiline = false,
            args = {"Vehicle Trust", "Vehicle list for " .. GetPlayerName(targetId) .. ":"}
        })
        
        Citizen.Wait(50)
        
        for _, vehicle in ipairs(playerVehicles) do
            local ownerText = vehicle.owner == 1 and " (Owner)" or ""
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", vehicle.spawncode .. ownerText}
            })
            Citizen.Wait(10)
        end
        
        if #playerVehicles == 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", "No vehicles found."}
            })
        end
    end
end, false)

print("^2Vehicle Trust System loaded successfully^7")
