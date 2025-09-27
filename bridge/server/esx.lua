local Config = require('config.shared')
if Config.Framework:lower() ~= 'esx' then return end
local ESX = exports.es_extended:getSharedObject()

function HasPermission(source)
    local identifier = ESX.GetPlayerFromId(source).identifier
    for _, id in ipairs(Config.Creator.allowed) do
        if id == identifier then 
            return true 
        end
    end
    return false
end

function GetCharacterIdentifier(source)
    return ESX.GetPlayerFromId(source).identifier
end

function IsEmployee(source, wash_id, onlyBoss)
    local identifier = ESX.GetPlayerFromId(source).identifier
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
    local player = ESX.GetPlayerFromId(source)
    return player.getName()
end

function GiveKeys(source, plate)
    -- ?
end

function Exploit(source)
    print(string.format('^1 >>>> EXPLOIT ID: %s !!!! <<<<'), source)
    DropPlayer(source, 'Exploit')
end