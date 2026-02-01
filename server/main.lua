-- LabOps - Vehicle Keys System
-- Created by Crow
-- Discord ID based vehicle locking with trust system

local vehicleConfig = {}
local trustedPlayers = {} -- Structure: {discordId: {spawncode: {trustedDiscordIds: []}}}
local serverLockedVehicles = {} -- Track vehicles by netId: {spawncode = string, ownerDiscordId = string}
local trustedPlayersFile = "trusted.json"

-- Save trusted players to file
function SaveTrustedPlayers()
    local success = SaveResourceFile(GetCurrentResourceName(), trustedPlayersFile, json.encode(trustedPlayers, {indent = true}))
    -- Print statements removed to prevent chat spam
end

-- Load trusted players from file
function LoadTrustedPlayers()
    local file = LoadResourceFile(GetCurrentResourceName(), trustedPlayersFile)
    if file then
        local success, data = pcall(json.decode, file)
        if success and data then
            trustedPlayers = data
        else
            trustedPlayers = {}
        end
    else
        trustedPlayers = {}
    end
end

-- Load config.json
Citizen.CreateThread(function()
    Citizen.Wait(100) -- Wait for resource to fully start
    local file = LoadResourceFile(GetCurrentResourceName(), "config.json")
    if file then
        vehicleConfig = json.decode(file)
    else
        -- Create default config structure
        vehicleConfig = {
            vehicles = {},
            settings = {
                checkDiscordOnJoin = true,
                enableSpawnProtection = true
            }
        }
    end
    
    -- Load trusted players after config is loaded
    LoadTrustedPlayers()
end)

-- Get player Discord ID
function GetDiscordId(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in pairs(identifiers) do
        if string.find(identifier, "discord:") then
            return string.gsub(identifier, "discord:", "")
        end
    end
    return nil
end

-- Send webhook for trust/untrust actions
function SendTrustWebhook(action, ownerSource, targetDiscordId, vehicles)
    local webhookUrl = vehicleConfig.settings and vehicleConfig.settings.webhookUrl or nil
    
    if not webhookUrl or webhookUrl == "" then
        return -- No webhook URL configured
    end
    
    local ownerName = GetPlayerName(ownerSource)
    local ownerDiscordId = GetDiscordId(ownerSource)
    
    if not ownerName or not ownerDiscordId then
        return
    end
    
    -- Get target player name if online
    local targetName = nil
    for _, playerId in ipairs(GetPlayers()) do
        local playerIdNum = tonumber(playerId)
        if GetDiscordId(playerIdNum) == targetDiscordId then
            targetName = GetPlayerName(playerIdNum)
            break
        end
    end
    
    if not targetName then
        targetName = "Unknown Player"
    end
    
    local actionText = action == "trust" and "trusted" or "untrusted"
    local actionTitle = action == "trust" and "Vehicle Trusted" or "Vehicle Untrusted"
    
    -- Format vehicle list
    local vehicleList = ""
    if vehicles and #vehicles > 0 then
        for i, spawncode in ipairs(vehicles) do
            vehicleList = vehicleList .. "`" .. string.upper(spawncode) .. "`"
            if i < #vehicles then
                vehicleList = vehicleList .. ", "
            end
        end
    else
        vehicleList = "None"
    end
    
    local embed = {
        {
            ["title"] = actionTitle,
            ["description"] = string.format("<@%s> **%s** has %s vehicles to <@%s> **%s**", 
                ownerDiscordId, ownerName, actionText, targetDiscordId, targetName),
            ["color"] = 3447003, -- Blue color
            ["fields"] = {
                {
                    ["name"] = "Owner",
                    ["value"] = string.format("<@%s> (%s)", ownerDiscordId, ownerName),
                    ["inline"] = true
                },
                {
                    ["name"] = "Target Player",
                    ["value"] = string.format("<@%s> (%s)", targetDiscordId, targetName),
                    ["inline"] = true
                },
                {
                    ["name"] = "Vehicles",
                    ["value"] = vehicleList,
                    ["inline"] = false
                }
            },
            ["footer"] = {
                ["text"] = "San Andreas Life Roleplay - Vehicle Keys System"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({
        username = "Vehicle Keys System",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Check if player owns a vehicle
function PlayerOwnsVehicle(discordId, spawncode)
    if vehicleConfig.vehicles[discordId] then
        for _, vehicle in pairs(vehicleConfig.vehicles[discordId]) do
            if string.lower(vehicle) == string.lower(spawncode) then
                return true
            end
        end
    end
    return false
end

-- Get all vehicles player owns
function GetOwnedVehicles(discordId)
    if vehicleConfig.vehicles[discordId] then
        return vehicleConfig.vehicles[discordId]
    end
    return {}
end

-- Check if player has trusted access to a vehicle
function PlayerHasTrustedAccess(discordId, ownerDiscordId, spawncode)
    if not trustedPlayers[ownerDiscordId] then
        return false
    end
    
    if not trustedPlayers[ownerDiscordId][string.lower(spawncode)] then
        return false
    end
    
    for _, trustedId in pairs(trustedPlayers[ownerDiscordId][string.lower(spawncode)]) do
        if trustedId == discordId then
            return true
        end
    end
    
    return false
end

-- Get all vehicles player has access to (owned + trusted)
function GetAllAccessibleVehicles(discordId)
    local vehicles = {}
    local owned = GetOwnedVehicles(discordId)
    
    -- Add owned vehicles
    for _, spawncode in pairs(owned) do
        table.insert(vehicles, {
            spawncode = spawncode,
            owner = discordId,
            isOwner = true
        })
    end
    
    -- Add trusted vehicles (only if vehicle still exists in owner's config)
    for ownerId, ownerVehicles in pairs(trustedPlayers) do
        for spawncode, trustedList in pairs(ownerVehicles) do
            -- Check if owner still owns this vehicle in config
            if PlayerOwnsVehicle(ownerId, spawncode) then
                for _, trustedId in pairs(trustedList) do
                    if trustedId == discordId then
                        table.insert(vehicles, {
                            spawncode = spawncode,
                            owner = ownerId,
                            isOwner = false
                        })
                        break
                    end
                end
            end
        end
    end
    
    return vehicles
end

-- Trust a vehicle to a player
function TrustVehicle(ownerDiscordId, targetDiscordId, spawncode)
    if not PlayerOwnsVehicle(ownerDiscordId, spawncode) then
        return false, "You don't own this vehicle"
    end
    
    if ownerDiscordId == targetDiscordId then
        return false, "You can't trust yourself"
    end
    
    if not trustedPlayers[ownerDiscordId] then
        trustedPlayers[ownerDiscordId] = {}
    end
    
    spawncode = string.lower(spawncode)
    if not trustedPlayers[ownerDiscordId][spawncode] then
        trustedPlayers[ownerDiscordId][spawncode] = {}
    end
    
    -- Check if already trusted
    for _, trustedId in pairs(trustedPlayers[ownerDiscordId][spawncode]) do
        if trustedId == targetDiscordId then
            return false, "Player already has access to this vehicle"
        end
    end
    
    table.insert(trustedPlayers[ownerDiscordId][spawncode], targetDiscordId)
    SaveTrustedPlayers() -- Save after adding trust
    return true, "Success"
end

-- Untrust a vehicle from a player
function UntrustVehicle(ownerDiscordId, targetDiscordId, spawncode)
    if not PlayerOwnsVehicle(ownerDiscordId, spawncode) then
        return false, "You don't own this vehicle"
    end
    
    if not trustedPlayers[ownerDiscordId] then
        return false, "No trusted players found"
    end
    
    spawncode = string.lower(spawncode)
    if not trustedPlayers[ownerDiscordId][spawncode] then
        return false, "No trusted players found for this vehicle"
    end
    
    -- Remove target from trusted list
    for i, trustedId in pairs(trustedPlayers[ownerDiscordId][spawncode]) do
        if trustedId == targetDiscordId then
            table.remove(trustedPlayers[ownerDiscordId][spawncode], i)
            
            -- Clean up empty tables
            if #trustedPlayers[ownerDiscordId][spawncode] == 0 then
                trustedPlayers[ownerDiscordId][spawncode] = nil
            end
            if next(trustedPlayers[ownerDiscordId]) == nil then
                trustedPlayers[ownerDiscordId] = nil
            end
            
            SaveTrustedPlayers() -- Save after removing trust
            return true, "Success"
        end
    end
    
    return false, "Player doesn't have access to this vehicle"
end

-- Get all spawncodes from config (used for model hash matching)
function GetAllConfigSpawncodes()
    local spawncodes = {}
    if vehicleConfig.vehicles then
        for discordId, vehicles in pairs(vehicleConfig.vehicles) do
            for _, vehicle in pairs(vehicles) do
                local spawncode = string.lower(vehicle)
                if not spawncodes[spawncode] then
                    spawncodes[spawncode] = true
                end
            end
        end
    end
    
    -- Convert to array
    local result = {}
    for spawncode, _ in pairs(spawncodes) do
        table.insert(result, spawncode)
    end
    return result
end

-- Get trusted vehicles for a player
function GetTrustedVehicles(discordId)
    local trusted = {}
    for ownerId, ownerVehicles in pairs(trustedPlayers) do
        for spawncode, trustedList in pairs(ownerVehicles) do
            -- Check if owner still owns this vehicle in config
            if PlayerOwnsVehicle(ownerId, spawncode) then
                for _, trustedId in pairs(trustedList) do
                    if trustedId == discordId then
                        table.insert(trusted, spawncode)
                        break
                    end
                end
            end
        end
    end
    return trusted
end

-- Check permission system (like Badger's)
RegisterServerEvent("vehicleKeys:CheckPermission")
AddEventHandler("vehicleKeys:CheckPermission", function()
    local src = source
    local discordId = GetDiscordId(src)
    
    if not discordId then
        TriggerClientEvent("vehicleKeys:CheckPermission:Return", src, {}, {})
        return
    end
    
    -- Get player's owned vehicles
    local ownedVehicles = GetOwnedVehicles(discordId)
    
    -- Get player's trusted vehicles
    local trustedVehicles = GetTrustedVehicles(discordId)
    
    -- Send to client
    TriggerClientEvent("vehicleKeys:CheckPermission:Return", src, ownedVehicles, trustedVehicles)
end)

-- Send all config spawncodes to client (for client-side checking)
RegisterServerEvent("vehicleKeys:GetConfigSpawncodes")
AddEventHandler("vehicleKeys:GetConfigSpawncodes", function()
    local src = source
    local allSpawncodes = GetAllConfigSpawncodes()
    TriggerClientEvent("vehicleKeys:ConfigSpawncodes:Return", src, allSpawncodes)
end)


-- Check if vehicle model is in any player's config
function IsVehicleInConfig(spawncode)
    if not vehicleConfig.vehicles or not spawncode then
        return false
    end
    
    spawncode = string.lower(spawncode)
    
    for discordId, vehicles in pairs(vehicleConfig.vehicles) do
        for _, vehicle in pairs(vehicles) do
            if string.lower(vehicle) == spawncode then
                return true
            end
        end
    end
    return false
end

-- Register vehicle as locked (called when vehicle is spawned)
RegisterNetEvent('vehicleKeys:registerVehicle', function(netId, spawncode)
    local source = source
    local discordId = GetDiscordId(source)
    
    if netId and spawncode and discordId then
        serverLockedVehicles[netId] = {
            spawncode = string.lower(spawncode),
            ownerDiscordId = discordId
        }
    end
end)

-- Unregister vehicle when it's deleted
RegisterNetEvent('vehicleKeys:unregisterVehicle', function(netId)
    if netId and serverLockedVehicles[netId] then
        serverLockedVehicles[netId] = nil
    end
end)

-- Check vehicle access when player tries to drive
RegisterNetEvent('vehicleKeys:checkAccess', function(netId, spawncode, modelHash)
    local source = source
    local discordId = GetDiscordId(source)
    
    if not discordId then
        TriggerClientEvent('vehicleKeys:accessDenied', source, netId)
        return
    end
    
    -- Try to get spawncode from server's locked vehicles list first
    if serverLockedVehicles[netId] then
        spawncode = serverLockedVehicles[netId].spawncode
    end
    
    -- If spawncode not provided but modelHash is, try to match it against ALL config spawncodes
    if (not spawncode or spawncode == "") and modelHash and modelHash ~= 0 then
        -- Get ALL spawncodes from config and send to client for matching
        local allSpawncodes = GetAllConfigSpawncodes()
        if allSpawncodes and #allSpawncodes > 0 then
            TriggerClientEvent('vehicleKeys:matchModelHashAll', source, netId, modelHash, allSpawncodes)
            -- Don't allow access yet - wait for match result
            return
        end
    end
    
    -- If spawncode still not provided, allow access (vehicle not in our system)
    if not spawncode or spawncode == "" then
        TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
        return
    end
    
    spawncode = string.lower(spawncode)
    
    -- Check if this vehicle is even in the config
    if not IsVehicleInConfig(spawncode) then
        -- Vehicle not locked, allow access
        TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
        return
    end
    
    -- Vehicle IS in config, so it's locked - check if player has access
    -- Check if player owns the vehicle
    local ownsVehicle = PlayerOwnsVehicle(discordId, spawncode)
    
    if ownsVehicle then
        -- Player owns this vehicle - auto-register it if not already registered
        if not serverLockedVehicles[netId] then
            serverLockedVehicles[netId] = {
                spawncode = spawncode,
                ownerDiscordId = discordId
            }
            -- Notify client to register it locally too
            TriggerClientEvent('vehicleKeys:registerVehicleClient', source, netId, spawncode)
        end
        TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
        return
    end
    
    -- Check if player has trusted access
    for ownerId, _ in pairs(vehicleConfig.vehicles) do
        if PlayerHasTrustedAccess(discordId, ownerId, spawncode) then
            TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
            return
        end
    end
    
    -- Vehicle is in config but player has no access - DENY
    TriggerClientEvent('vehicleKeys:accessDenied', source, netId)
end)

-- Receive matched spawncode from client (when matching against owned vehicles)
RegisterNetEvent('vehicleKeys:modelMatched', function(netId, spawncode)
    local source = source
    local discordId = GetDiscordId(source)
    
    if not discordId or not netId or not spawncode then
        return
    end
    
    spawncode = string.lower(spawncode)
    
    -- Verify player owns this vehicle and vehicle is in config
    if PlayerOwnsVehicle(discordId, spawncode) and IsVehicleInConfig(spawncode) then
        -- Register the vehicle
        if not serverLockedVehicles[netId] then
            serverLockedVehicles[netId] = {
                spawncode = spawncode,
                ownerDiscordId = discordId
            }
            -- Notify client to register it locally too
            TriggerClientEvent('vehicleKeys:registerVehicleClient', source, netId, spawncode)
        end
    end
end)

-- Receive matched spawncode from client (when matching against ALL config spawncodes)
RegisterNetEvent('vehicleKeys:modelMatchedAll', function(netId, spawncode)
    local source = source
    local discordId = GetDiscordId(source)
    
    if not discordId or not netId then
        return
    end
    
    -- If no spawncode matched, vehicle is not in config - allow access
    if not spawncode or spawncode == "" then
        TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
        return
    end
    
    spawncode = string.lower(spawncode)
    
    -- Vehicle matched a spawncode in config - now check access
    -- Store spawncode for this vehicle
    if not serverLockedVehicles[netId] then
        -- Find the owner of this spawncode (first owner found)
        local ownerDiscordId = nil
        for discId, vehicles in pairs(vehicleConfig.vehicles) do
            for _, vehicle in pairs(vehicles) do
                if string.lower(vehicle) == spawncode then
                    ownerDiscordId = discId
                    break
                end
            end
            if ownerDiscordId then break end
        end
        
        serverLockedVehicles[netId] = {
            spawncode = spawncode,
            ownerDiscordId = ownerDiscordId
        }
        TriggerClientEvent('vehicleKeys:registerVehicleClient', source, netId, spawncode)
    end
    
    -- Now check access for this player
    -- Check if player owns the vehicle
    if PlayerOwnsVehicle(discordId, spawncode) then
        TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
        return
    end
    
    -- Check if player has trusted access
    for ownerId, _ in pairs(vehicleConfig.vehicles) do
        if PlayerHasTrustedAccess(discordId, ownerId, spawncode) then
            TriggerClientEvent('vehicleKeys:accessGranted', source, netId)
            return
        end
    end
    
    -- Vehicle is in config but player has no access - DENY
    TriggerClientEvent('vehicleKeys:accessDenied', source, netId)
end)

-- /keys command
RegisterCommand('keys', function(source, args, rawCommand)
    local discordId = GetDiscordId(source)
    
    if not discordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found. Please make sure you are logged into Discord.',
            type = 'error'
        })
        return
    end
    
    local vehicles = GetAllAccessibleVehicles(discordId)
    
    TriggerClientEvent('vehicleKeys:showKeysMenu', source, vehicles)
end, false)

-- /trusted command - Show who has trusted access to your vehicles
RegisterCommand('trusted', function(source, args, rawCommand)
    local discordId = GetDiscordId(source)
    
    if not discordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found. Please make sure you are logged into Discord.',
            type = 'error'
        })
        return
    end
    
    -- Get player's owned vehicles
    local ownedVehicles = GetOwnedVehicles(discordId)
    
    if #ownedVehicles == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'You don\'t own any vehicles',
            type = 'info'
        })
        return
    end
    
    -- Check if player has any trusted players
    if not trustedPlayers[discordId] or next(trustedPlayers[discordId]) == nil then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'user-group',
            description = 'You haven\'t trusted any vehicles to other players',
            type = 'info'
        })
        return
    end
    
    -- Build vehicles data for HTML menu
    local vehiclesData = {}
    
    for _, spawncode in pairs(ownedVehicles) do
        local lowerSpawncode = string.lower(spawncode)
        
        -- Check if this vehicle has trusted players
        if trustedPlayers[discordId] and trustedPlayers[discordId][lowerSpawncode] and #trustedPlayers[discordId][lowerSpawncode] > 0 then
            local trustedList = trustedPlayers[discordId][lowerSpawncode]
            local trustedPlayersData = {}
            
            -- Get player names for each trusted Discord ID
            for _, trustedDiscordId in pairs(trustedList) do
                local playerName = nil
                -- Try to find player by Discord ID
                for _, playerId in ipairs(GetPlayers()) do
                    local playerDiscordId = GetDiscordId(tonumber(playerId))
                    if playerDiscordId == trustedDiscordId then
                        playerName = GetPlayerName(tonumber(playerId))
                        break
                    end
                end
                
                -- If player not online, use Discord ID as name
                if not playerName then
                    playerName = "Offline Player"
                end
                
                table.insert(trustedPlayersData, {
                    name = playerName,
                    discordId = trustedDiscordId
                })
            end
            
            table.insert(vehiclesData, {
                spawncode = spawncode,
                trustedPlayers = trustedPlayersData
            })
        end
    end
    
    if #vehiclesData == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'user-group',
            description = 'None of your vehicles have trusted players',
            type = 'info'
        })
        return
    end
    
    -- Send data to client to show HTML menu
    TriggerClientEvent('vehicleKeys:showTrustedMenu', source, vehiclesData)
end, false)

-- /trust command - Show trust menu
RegisterCommand('trust', function(source, args, rawCommand)
    local ownerSource = source
    local ownerDiscordId = GetDiscordId(ownerSource)
    
    if not ownerDiscordId then
        TriggerClientEvent('ox_lib:notify', ownerSource, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found',
            type = 'error'
        })
        return
    end
    
    local ownedVehicles = GetOwnedVehicles(ownerDiscordId)
    
    if #ownedVehicles == 0 then
        TriggerClientEvent('ox_lib:notify', ownerSource, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'You don\'t own any vehicles',
            type = 'error'
        })
        return
    end
    
    -- Send owned vehicles to client to show trust menu
    TriggerClientEvent('vehicleKeys:showTrustMenu', ownerSource, ownedVehicles)
end, false)

-- Handle trust confirmation from menu
RegisterNetEvent('vehicleKeys:confirmTrust', function(targetPlayerId, selectedVehicles)
    local source = source
    local ownerDiscordId = GetDiscordId(source)
    
    if not ownerDiscordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found',
            type = 'error'
        })
        return
    end
    
    -- Validate player ID is provided
    if not targetPlayerId or targetPlayerId == '' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Please enter a Player ID',
            type = 'error'
        })
        return
    end
    
    local targetSource = tonumber(targetPlayerId)
    
    if not targetSource or not GetPlayerName(targetSource) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'user-xmark',
            description = 'Player not found',
            type = 'error'
        })
        return
    end
    
    local targetDiscordId = GetDiscordId(targetSource)
    if not targetDiscordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Target player Discord ID not found',
            type = 'error'
        })
        return
    end
    
    if not selectedVehicles or #selectedVehicles == 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Please select at least one vehicle',
            type = 'error'
        })
        return
    end
    
    local successCount = 0
    local trustedVehicles = {}
    for _, spawncode in pairs(selectedVehicles) do
        local success, msg = TrustVehicle(ownerDiscordId, targetDiscordId, spawncode)
        if success then
            successCount = successCount + 1
            table.insert(trustedVehicles, spawncode)
        end
    end
    
    -- Update target player's client with new trusted vehicles
    if successCount > 0 then
        local targetOwnedVehicles = GetOwnedVehicles(targetDiscordId)
        local targetTrustedVehicles = GetTrustedVehicles(targetDiscordId)
        TriggerClientEvent("vehicleKeys:CheckPermission:Return", targetSource, targetOwnedVehicles, targetTrustedVehicles)
        
        -- Send webhook
        SendTrustWebhook("trust", source, targetDiscordId, trustedVehicles)
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'San Andreas Life Roleplay',
        icon = 'check',
        description = 'Trusted ' .. successCount .. ' vehicle(s) to ' .. GetPlayerName(targetSource),
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetSource, {
        title = 'San Andreas Life Roleplay',
        icon = 'key',
        description = GetPlayerName(source) .. ' has trusted you with ' .. successCount .. ' vehicle(s)',
        type = 'info'
    })
end)

-- Remove trust from player (called from HTML menu)
RegisterNetEvent('vehicleKeys:removeTrustFromPlayer', function(spawncode, targetDiscordId)
    local source = source
    local ownerDiscordId = GetDiscordId(source)
    
    if not ownerDiscordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found',
            type = 'error'
        })
        return
    end
    
    local success, msg = UntrustVehicle(ownerDiscordId, targetDiscordId, spawncode)
    
    if success then
        -- Send webhook
        SendTrustWebhook("untrust", source, targetDiscordId, {spawncode})
        
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'check',
            description = 'Removed access to ' .. spawncode .. ' from player',
            type = 'success'
        })
        
        -- Find target player and update their client-side permissions
        local targetSource = nil
        for _, playerId in ipairs(GetPlayers()) do
            local playerDiscordId = GetDiscordId(tonumber(playerId))
            if playerDiscordId == targetDiscordId then
                targetSource = tonumber(playerId)
                break
            end
        end
        
        -- Update target player's client with updated trusted vehicles (removed)
        if targetSource then
            local targetOwnedVehicles = GetOwnedVehicles(targetDiscordId)
            local targetTrustedVehicles = GetTrustedVehicles(targetDiscordId)
            TriggerClientEvent("vehicleKeys:CheckPermission:Return", targetSource, targetOwnedVehicles, targetTrustedVehicles)
            
            -- Check if target player is in the untrusted vehicle and delete it
            local untrustedSpawncodes = {spawncode}
            TriggerClientEvent("vehicleKeys:deleteUntrustedVehicles", targetSource, untrustedSpawncodes)
        end
        
        -- Reload the trusted menu
        Citizen.Wait(100)
        
        local ownedVehicles = GetOwnedVehicles(ownerDiscordId)
        local vehiclesData = {}
        
        for _, vehSpawncode in pairs(ownedVehicles) do
            local lowerSpawncode = string.lower(vehSpawncode)
            
            if trustedPlayers[ownerDiscordId] and trustedPlayers[ownerDiscordId][lowerSpawncode] and #trustedPlayers[ownerDiscordId][lowerSpawncode] > 0 then
                local trustedList = trustedPlayers[ownerDiscordId][lowerSpawncode]
                local trustedPlayersData = {}
                
                for _, trustedDiscordId in pairs(trustedList) do
                    local playerName = nil
                    for _, playerId in ipairs(GetPlayers()) do
                        local playerDiscordId = GetDiscordId(tonumber(playerId))
                        if playerDiscordId == trustedDiscordId then
                            playerName = GetPlayerName(tonumber(playerId))
                            break
                        end
                    end
                    
                    if not playerName then
                        playerName = "Offline Player"
                    end
                    
                    table.insert(trustedPlayersData, {
                        name = playerName,
                        discordId = trustedDiscordId
                    })
                end
                
                table.insert(vehiclesData, {
                    spawncode = vehSpawncode,
                    trustedPlayers = trustedPlayersData
                })
            end
        end
        
        TriggerClientEvent('vehicleKeys:showTrustedMenu', source, vehiclesData)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = msg or 'Failed to remove access',
            type = 'error'
        })
    end
end)

-- Reload trusted menu (internal function)
function ReloadTrustedMenuForPlayer(source)
    local discordId = GetDiscordId(source)
    if not discordId then return end
    
    local ownedVehicles = GetOwnedVehicles(discordId)
    local vehiclesData = {}
    
    for _, spawncode in pairs(ownedVehicles) do
        local lowerSpawncode = string.lower(spawncode)
        
        if trustedPlayers[discordId] and trustedPlayers[discordId][lowerSpawncode] and #trustedPlayers[discordId][lowerSpawncode] > 0 then
            local trustedList = trustedPlayers[discordId][lowerSpawncode]
            local trustedPlayersData = {}
            
            for _, trustedDiscordId in pairs(trustedList) do
                local playerName = nil
                for _, playerId in ipairs(GetPlayers()) do
                    local playerDiscordId = GetDiscordId(tonumber(playerId))
                    if playerDiscordId == trustedDiscordId then
                        playerName = GetPlayerName(tonumber(playerId))
                        break
                    end
                end
                
                if not playerName then
                    playerName = "Offline Player"
                end
                
                table.insert(trustedPlayersData, {
                    name = playerName,
                    discordId = trustedDiscordId
                })
            end
            
            table.insert(vehiclesData, {
                spawncode = spawncode,
                trustedPlayers = trustedPlayersData
            })
        end
    end
    
    TriggerClientEvent('vehicleKeys:showTrustedMenu', source, vehiclesData)
end

-- Spawn vehicle command (called from menu)
RegisterNetEvent('vehicleKeys:spawnVehicle', function(spawncode)
    local source = source
    local discordId = GetDiscordId(source)
    
    if not discordId then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'Discord ID not found',
            type = 'error'
        })
        return
    end
    
    spawncode = string.lower(spawncode)
    
    -- Check if player owns the vehicle
    local ownsVehicle = PlayerOwnsVehicle(discordId, spawncode)
    
    -- Check if player has trusted access
    local hasTrustedAccess = false
    if not ownsVehicle then
        for ownerId, _ in pairs(vehicleConfig.vehicles) do
            if PlayerHasTrustedAccess(discordId, ownerId, spawncode) then
                hasTrustedAccess = true
                break
            end
        end
    end
    
    if ownsVehicle or hasTrustedAccess then
        TriggerClientEvent('vehicleKeys:spawnVehicleClient', source, spawncode)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Life Roleplay',
            icon = 'triangle-exclamation',
            description = 'You don\'t have access to spawn this vehicle',
            type = 'error'
        })
    end
end)

-- Player connecting - check Discord ID
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()
    
    Citizen.Wait(100)
    
    local discordId = GetDiscordId(source)
    
    if not discordId then
        deferrals.done("Discord ID not found. Please make sure you are logged into Discord.")
        return
    end
    
    deferrals.done()
end)
