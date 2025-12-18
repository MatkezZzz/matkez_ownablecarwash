local Config = require('config.shared')
if Config.Framework:lower() ~= 'qb' then return end
local QB = exports['qb-core']:GetCoreObject()

function GetCharacterIdentifier(source)
    return QB.Functions.GetPlayer(source).PlayerData.citizenid
end

function GetCharacterName(source)
    local player = QB.Functions.GetPlayer(source)
    return player.PlayerData.charinfo.firstname..' '..player.PlayerData.charinfo.lastname
end

function GiveKeys(source, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
end

function Exploit(source)
    DropPlayer(source, 'exploit')
end