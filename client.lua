local identifiers = {
    discord = nil,
    steam = nil,
    license = nil
}
local isNotifyReady = false

Citizen.CreateThread(function()
    local resourceState = GetResourceState('okokNotify')
    isNotifyReady = (resourceState == "started" or resourceState == "starting")
    
    Citizen.Wait(1000)
    TriggerServerEvent('primerp_vehwl:reloadwl')
end)

function ShowNotification(message, notifType)
    notifType = notifType or 'error'
    
    if isNotifyReady then
        exports['okokNotify']:Alert("Vehicle Trust", message, 5000, notifType)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

function getIdentifiers()
    return identifiers
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        TriggerServerEvent('primerp_vehwl:Server:Check')
    end
end)

AddEventHandler("playerSpawned", function()
    TriggerServerEvent("primerp_vehwl:reloadwl")
end)

RegisterNetEvent("primerp_vehwl:loadIdentifiers")
AddEventHandler("primerp_vehwl:loadIdentifiers", function(ids)
    identifiers = ids
    print("Identifiers loaded: Discord: " .. (identifiers.discord or "none") .. 
          ", Steam: " .. (identifiers.steam or "none") .. 
          ", License: " .. (identifiers.license or "none"))
end)

RegisterNetEvent('primerp_vehwl:RunCode:Client')
AddEventHandler('primerp_vehwl:RunCode:Client', function(allowedVehicles)
    local ped = PlayerPedId()
    
    if not IsPedInAnyVehicle(ped, false) then
        return
    end
    
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return end
    
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= ped then return end
    
    local vehicleModel = GetEntityModel(veh)
    local modelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    
    local isWhitelisted = false
    local hasAccess = false
    
    for _, vehicle in pairs(allowedVehicles) do
        local spawncode = vehicle.spawncode
        if GetHashKey(spawncode) == vehicleModel or spawncode:lower() == modelName then
            isWhitelisted = true
            
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
    
    if isWhitelisted and not hasAccess then
        TaskLeaveVehicle(ped, veh, 16)
        Citizen.Wait(1500)
        ClearPedTasksImmediately(ped)
        ShowNotification('~r~ERROR: You do not have access to this personal vehicle', 'error')
    end
end)

RegisterCommand("reloadwl", function(source)
    TriggerServerEvent("primerp_vehwl:reloadwl")
    ShowNotification('~g~Vehicle trust system reloaded', 'info')
end, false)

RegisterCommand("vehaccess", function(source, args)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        ShowNotification('~r~You need to be in a vehicle to check access', 'error')
        return
    end
    
    local veh = GetVehiclePedIsIn(ped, false)
    local vehicleModel = GetEntityModel(veh)
    local modelName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
    
    TriggerServerEvent('primerp_vehwl:checkAccess', vehicleModel, modelName)
end, false)

RegisterNetEvent('primerp_vehwl:accessStatus')
AddEventHandler('primerp_vehwl:accessStatus', function(hasAccess, isWhitelisted, vehicleName)
    if isWhitelisted then
        if hasAccess then
            ShowNotification('~g~You have access to this ' .. vehicleName, 'success')
        else
            ShowNotification('~r~You do not have access to this ' .. vehicleName, 'error')
        end
    else
        ShowNotification('~b~This vehicle is not restricted', 'info')
    end
end)

RegisterCommand("myvehicles", function(source, args)
    TriggerServerEvent('primerp_vehwl:listMyVehicles')
end, false)

RegisterNetEvent('primerp_vehwl:displayVehicleList')
AddEventHandler('primerp_vehwl:displayVehicleList', function(vehicles)
    if #vehicles == 0 then
        ShowNotification('~y~You don\'t have access to any whitelisted vehicles', 'info')
        return
    end
    
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(41, 41, 41, 0.6); border-radius: 3px;"><b>Your Vehicle Access:</b></div>',
    })
    
    Citizen.Wait(50)
    
    for i, vehicle in ipairs(vehicles) do
        local ownerText = vehicle.owner == 1 and " (Owner)" or ""
        TriggerEvent('chat:addMessage', {
            template = '<div style="padding: 0.5vw; margin: 0.5vw; background-color: rgba(41, 41, 41, 0.6); border-radius: 3px;">{0}{1}</div>',
            args = {vehicle.spawncode, ownerText}
        })
        Citizen.Wait(10)
    end
end)
