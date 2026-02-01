-- LabOps - Vehicle Keys System
-- Created by Crow
-- Vehicle spawning, locking, and menu functionality
-- Based on Badger's Discord Vehicle Restrictions approach

local lockedVehicles = {} -- Track vehicles that need access checking
local myVehicles = nil -- Player's owned vehicles from server
local myTrustedVehicles = nil -- Player's trusted vehicles from server

-- Track previous permissions to detect removals
local previousOwnedVehicles = {}
local previousTrustedVehicles = {}

-- Get player's vehicles from server
RegisterNetEvent("vehicleKeys:CheckPermission:Return")
AddEventHandler("vehicleKeys:CheckPermission:Return", function(ownedVehicles, trustedVehicles)
    local newOwnedVehicles = ownedVehicles or {}
    local newTrustedVehicles = trustedVehicles or {}
    
    -- Check if permissions were removed (not just updated)
    local permissionsRemoved = false
    
    -- Compare with previous permissions
    if #previousTrustedVehicles > 0 or #previousOwnedVehicles > 0 then
        -- Check if any previously trusted vehicles are missing
        for _, oldTrusted in pairs(previousTrustedVehicles) do
            local stillHasAccess = false
            for _, newTrusted in pairs(newTrustedVehicles) do
                if string.lower(oldTrusted) == string.lower(newTrusted) then
                    stillHasAccess = true
                    break
                end
            end
            if not stillHasAccess then
                permissionsRemoved = true
                break
            end
        end
    end
    
    -- Update current permissions
    myVehicles = newOwnedVehicles
    myTrustedVehicles = newTrustedVehicles
    
    -- Force re-check of current vehicle with new permissions
    forceRecheck = true
    lastChecked = nil
    hasPerm = nil
    
    -- Only immediately check and remove vehicle if permissions were REMOVED
    if permissionsRemoved then
        Citizen.CreateThread(function()
            Citizen.Wait(100) -- Small delay to ensure permissions are set
            
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= nil and DoesEntityExist(veh) then
                    local model = GetEntityModel(veh)
                    local matchedSpawncode = nil
                    
                    -- Find matching spawncode
                    if allConfigSpawncodes then
                        for _, spawncode in pairs(allConfigSpawncodes) do
                            if GetHashKey(spawncode) == model then
                                matchedSpawncode = spawncode
                                break
                            end
                        end
                    end
                    
                    -- Check if player has access to this vehicle
                    if matchedSpawncode then
                        local hasAccess = false
                        
                        -- Check owned vehicles
                        if myVehicles then
                            for _, ownedSpawncode in pairs(myVehicles) do
                                if string.lower(ownedSpawncode) == string.lower(matchedSpawncode) then
                                    hasAccess = true
                                    break
                                end
                            end
                        end
                        
                        -- Check trusted vehicles
                        if not hasAccess and myTrustedVehicles then
                            for _, trustedSpawncode in pairs(myTrustedVehicles) do
                                if string.lower(trustedSpawncode) == string.lower(matchedSpawncode) then
                                    hasAccess = true
                                    break
                                end
                            end
                        end
                        
                        -- If no access, remove vehicle immediately
                        if not hasAccess then
                            lib.notify({
                                title = 'San Andreas Life Roleplay',
                                description = 'Your access to this vehicle has been removed. Vehicle will be deleted.',
                                type = 'error',
                                icon = 'triangle-exclamation',
                                duration = 3000
                            })
                            
                            -- Force player out and delete vehicle
                            TaskLeaveVehicle(ped, veh, 16)
                            Citizen.Wait(500)
                            DeleteEntity(veh)
                            ClearPedTasksImmediately(ped)
                            
                            -- Reset check state
                            lastChecked = nil
                            hasPerm = nil
                        end
                    end
                end
            end
        end)
    end
    
    -- Update previous permissions for next comparison
    previousOwnedVehicles = {}
    previousTrustedVehicles = {}
    for _, v in pairs(newOwnedVehicles) do
        table.insert(previousOwnedVehicles, v)
    end
    for _, v in pairs(newTrustedVehicles) do
        table.insert(previousTrustedVehicles, v)
    end
end)

-- Show keys menu using HTML/NUI
RegisterNetEvent('vehicleKeys:showKeysMenu', function(vehicles)
    if #vehicles == 0 then
        lib.notify({
            title = 'San Andreas Life Roleplay',
            description = 'You don\'t have access to any vehicles',
            type = 'info',
            icon = 'key'
        })
        return
    end
    
    -- Send vehicles to NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showMenu',
        vehicles = vehicles
    })
end)

-- Close menu from NUI
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Select vehicle from NUI
RegisterNUICallback('selectVehicle', function(data, cb)
    if data.spawncode then
        TriggerServerEvent('vehicleKeys:spawnVehicle', data.spawncode)
    end
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Show trusted players menu (HTML - uses same NUI page)
RegisterNetEvent('vehicleKeys:showTrustedMenu', function(vehiclesData)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showTrustedMenu',
        vehicles = vehiclesData
    })
end)

-- Show trust menu (HTML - uses same NUI page)
RegisterNetEvent('vehicleKeys:showTrustMenu', function(ownedVehicles)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showTrustMenu',
        vehicles = ownedVehicles
    })
end)

-- Close trusted menu from NUI
RegisterNUICallback('closeTrustedMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Remove trust from NUI
RegisterNUICallback('removeTrust', function(data, cb)
    if data.spawncode and data.discordId then
        TriggerServerEvent('vehicleKeys:removeTrustFromPlayer', data.spawncode, data.discordId)
    end
    cb('ok')
end)

-- Confirm trust from NUI
RegisterNUICallback('confirmTrust', function(data, cb)
    if data.targetPlayerId and data.selectedVehicles then
        TriggerServerEvent('vehicleKeys:confirmTrust', data.targetPlayerId, data.selectedVehicles)
    end
    -- Menu will be closed by the JavaScript closeMenu() function
    cb({success = true})
end)

-- Delete vehicle if player is in a vehicle when untrusted
RegisterNetEvent('vehicleKeys:deleteUntrustedVehicles', function(untrustedSpawncodes)
    Citizen.Wait(100) -- Small delay to ensure permissions are updated
    
    local ped = PlayerPedId()
    
    if not IsPedInAnyVehicle(ped, false) then
        return
    end
    
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == nil or not DoesEntityExist(veh) then
        return
    end
    
    -- Player is in a vehicle - delete it immediately
    lib.notify({
        title = 'San Andreas Life Roleplay',
        description = 'Your access to this vehicle has been removed. Vehicle will be deleted.',
        type = 'error',
        icon = 'triangle-exclamation',
        duration = 3000
    })
    
    -- Force player out and delete vehicle
    TaskLeaveVehicle(ped, veh, 16)
    Citizen.Wait(500)
    
    -- Delete the vehicle
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
    ClearPedTasksImmediately(ped)
    
    -- Reset check state
    lastChecked = nil
    hasPerm = nil
end)

-- Spawn vehicle
RegisterNetEvent('vehicleKeys:spawnVehicleClient', function(spawncode)
    local playerPed = PlayerPedId()
    
    -- Check if player is in a vehicle and delete it
    if IsPedInAnyVehicle(playerPed, false) then
        local currentVeh = GetVehiclePedIsIn(playerPed, false)
        if currentVeh ~= nil and DoesEntityExist(currentVeh) then
            -- Get player out of vehicle
            TaskLeaveVehicle(playerPed, currentVeh, 16)
            Citizen.Wait(500)
            
            -- Delete the old vehicle
            if DoesEntityExist(currentVeh) then
                DeleteEntity(currentVeh)
            end
            ClearPedTasksImmediately(playerPed)
        end
    end
    
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    -- Get spawn coordinates in front of player
    local forwardX = GetEntityForwardX(playerPed) * 3.0
    local forwardY = GetEntityForwardY(playerPed) * 3.0
    local spawnCoords = vector3(coords.x + forwardX, coords.y + forwardY, coords.z)
    
    -- Check if spawn location is clear
    local vehicle, foundZ = GetClosestVehicle(spawnCoords.x, spawnCoords.y, spawnCoords.z, 5.0, 0, 71)
    if DoesEntityExist(vehicle) then
        lib.notify({
            title = 'San Andreas Life Roleplay',
            description = 'Spawn location is blocked. Please move to a clear area.',
            type = 'error',
            icon = 'car'
        })
        return
    end
    
    -- Request model
    local model = GetHashKey(spawncode)
    RequestModel(model)
    
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 5000 do
        Citizen.Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(model) then
        lib.notify({
            title = 'San Andreas Life Roleplay',
            description = 'Failed to load vehicle model: ' .. spawncode,
            type = 'error',
            icon = 'triangle-exclamation'
        })
        return
    end
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetModelAsNoLongerNeeded(model)
    
    -- Set vehicle as locked to owner/trusted players only
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    lockedVehicles[netId] = {
        spawncode = string.lower(spawncode),
        owner = true
    }
    
    -- Mark vehicle so other scripts know it's locked
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Unlock doors for owner
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    
    -- Give keys to player
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    
    lib.notify({
        title = 'San Andreas Life Roleplay',
        description = 'Vehicle spawned: ' .. spawncode:upper(),
        type = 'success',
        icon = 'car'
    })
    
    -- Warp player into vehicle
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
end)

-- Vehicle access checking (Badger's approach)
local lastChecked = nil
local hasPerm = nil
local allConfigSpawncodes = nil
local forceRecheck = false -- Flag to force re-check when permissions change

-- Get all config spawncodes from server
RegisterNetEvent('vehicleKeys:ConfigSpawncodes:Return')
AddEventHandler('vehicleKeys:ConfigSpawncodes:Return', function(spawncodes)
    allConfigSpawncodes = spawncodes
end)

Citizen.CreateThread(function()
    -- Request permissions from server
    TriggerServerEvent("vehicleKeys:CheckPermission")
    
    -- Request all config spawncodes from server
    TriggerServerEvent("vehicleKeys:GetConfigSpawncodes")
    
    while true do
        Citizen.Wait(100) -- Reduced wait time for more responsive checking
        
        local ped = PlayerPedId()
        local veh = nil
        
        -- Check if player is in a vehicle or trying to enter one
        if IsPedInAnyVehicle(ped, false) then
            veh = GetVehiclePedIsIn(ped, false)
        else
            veh = GetVehiclePedIsTryingToEnter(ped)
        end
        
        if veh ~= nil and DoesEntityExist(veh) then
            local model = GetEntityModel(veh)
            local driver = GetPedInVehicleSeat(veh, -1)
            
            -- If we already checked this model and don't have permission, prevent access
            if (lastChecked ~= nil) and (lastChecked == model) and (hasPerm ~= nil) and (not hasPerm) and (not forceRecheck) then
                if driver == ped then
                    lib.notify({
                        title = 'San Andreas Life Roleplay',
                        description = 'You don\'t have access to this vehicle. Vehicle will be removed.',
                        type = 'error',
                        icon = 'triangle-exclamation',
                        duration = 2000
                    })
                    
                    -- Delete vehicle (always enabled)
                    DeleteEntity(veh)
                    ClearPedTasksImmediately(ped)
                end
                goto continue
            end
            
            -- Check if this is a new vehicle model to check OR if we need to force re-check
            if lastChecked ~= model or forceRecheck then
                local requiredPerm = nil
                hasPerm = nil
                
                -- Check if vehicle is in config by comparing model hash to all config spawncodes
                if allConfigSpawncodes then
                    local vehicleInConfig = false
                    local matchedSpawncode = nil
                    
                    -- Check if model matches any config spawncode
                    for _, spawncode in pairs(allConfigSpawncodes) do
                        if GetHashKey(spawncode) == model then
                            vehicleInConfig = true
                            matchedSpawncode = spawncode
                            break
                        end
                    end
                    
                    -- If vehicle is in config, check if player has access
                    if vehicleInConfig and matchedSpawncode then
                        requiredPerm = true
                        hasPerm = false -- Default to no permission
                        
                        -- Check if player owns this vehicle (if myVehicles is loaded)
                        if myVehicles then
                            for _, ownedSpawncode in pairs(myVehicles) do
                                if string.lower(ownedSpawncode) == string.lower(matchedSpawncode) then
                                    hasPerm = true
                                    break
                                end
                            end
                        end
                        
                        -- Check if player has trusted access (if myTrustedVehicles is loaded)
                        if not hasPerm and myTrustedVehicles then
                            for _, trustedSpawncode in pairs(myTrustedVehicles) do
                                if string.lower(trustedSpawncode) == string.lower(matchedSpawncode) then
                                    hasPerm = true
                                    break
                                end
                            end
                        end
                        
                        -- If permissions haven't loaded yet, don't delete the vehicle
                        if not myVehicles and not myTrustedVehicles then
                            hasPerm = nil
                        end
                    end
                end
                
                lastChecked = model
                forceRecheck = false -- Reset force recheck flag after checking
                
                -- If vehicle is restricted and player doesn't have permission, delete it
                if not hasPerm and requiredPerm ~= nil then
                    if driver == ped then
                        lib.notify({
                            title = 'San Andreas Life Roleplay',
                            description = 'You don\'t have access to this vehicle. Vehicle will be removed.',
                            type = 'error',
                            icon = 'triangle-exclamation',
                            duration = 2000
                        })
                        DeleteEntity(veh)
                        ClearPedTasksImmediately(ped)
                    end
                else
                    hasPerm = true
                end
            end
        end
        
        ::continue::
    end
end)

-- Clean up locked vehicles when they're deleted
AddEventHandler('entityRemoved', function(entity)
    if entity and GetEntityType(entity) == 2 then -- Vehicle
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId and lockedVehicles[netId] then
            lockedVehicles[netId] = nil
        end
    end
end)
