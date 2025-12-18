local Config = require('config.shared')
if Config.Framework:lower() ~= 'esx' then return end

local ESX = exports.es_extended:getSharedObject()

RegisterNetEvent('esx:playerLoaded', function (xPlayer, skin)
    Wait(5000)
    setup()
end)

function GetCharacterIdentifier()
    return ESX.GetPlayerData().identifier
end