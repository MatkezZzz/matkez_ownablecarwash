local Config = require('config.shared')
if Config.Framework:lower() ~= 'esx' then return end

local ESX = exports.es_extended:getSharedObject()

RegisterNetEvent('esx:playerLoaded', function (xPlayer, skin)
    Wait(5000)
    setup()
end)

function HasPermission()
    local identifier = ESX.GetPlayerData().identifier
    for _, id in ipairs(Config.Creator.allowed) do
        if id == identifier then 
            return true 
        end
    end
    return false
end

function GetCharacterIdentifier()
    return ESX.GetPlayerData().identifier
end