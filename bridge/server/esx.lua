local Config = require('config.shared')
if Config.Framework:lower() ~= 'esx' then return end
local ESX = exports.es_extended:getSharedObject()

function GetCharacterIdentifier(source)
    return ESX.GetPlayerFromId(source).identifier
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