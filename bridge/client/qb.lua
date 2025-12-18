local Config = require('config.shared')
if Config.Framework:lower() ~= 'qb' then return end
local QB = exports['qb-core']:GetCoreObject()

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    setup()
end)

function GetCharacterIdentifier()
    return QB.Functions.GetPlayerData().citizenid
end