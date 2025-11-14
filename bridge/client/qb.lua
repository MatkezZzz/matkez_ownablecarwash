local Config = require('config.shared')
if Config.Framework:lower() ~= 'qb' then return end
local QB = exports['qb-core']:GetCoreObject()

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    setup()
end)

function HasPermission()
    local identifier = QB.Functions.GetPlayerData().citizenid
    for _, id in ipairs(Config.Creator.allowed) do
        if id == identifier then 
            return true 
        end
    end
    return false
end

function GetCharacterIdentifier()
    return QB.Functions.GetPlayerData().citizenid
end