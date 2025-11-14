local Config = require('config.shared')
if Config.Framework:lower() ~= 'qb' then return end
local QB = exports['qb-core']:GetCoreObject()

function HasPermission(source)
    local identifier = QB.Functions.GetPlayer(source).PlayerData.citizenid
    for _, id in ipairs(Config.Creator.allowed) do
        if id == identifier then 
            return true 
        end
    end
    return false
end

function GetCharacterIdentifier(source)
    return QB.Functions.GetPlayer(source).PlayerData.citizenid
end

function IsEmployee(source, wash_id, onlyBoss)
    local identifier = QB.Functions.GetPlayer(source).PlayerData.citizenid
    local row = MySQL.single.await('SELECT `owner`, `workers` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if row.owner == identifier then return true end
    if not onlyBoss then
        local workers = json.decode(row.workers)
        for _, v in ipairs(workers) do
            if v.identifier == identifier then
                return true
            end
        end
    end
    return false
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