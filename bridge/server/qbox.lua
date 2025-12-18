local Config = require('config.shared')
if Config.Framework:lower() ~= 'qbox' then return end
local QBX = exports.qbx_core

function GetCharacterIdentifier(source)
    return QBX:GetPlayer(source).PlayerData.citizenid
end

function GetCharacterName(source)
    local player = QBX:GetPlayer(source)
    return player.PlayerData.charinfo.firstname..' '..player.PlayerData.charinfo.lastname
end

function GiveKeys(source, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
end

function Exploit(source)
    QBX:ExploitBan(source, 'matkez_ownablecarwash')
end