local Config = require('config.shared')
if Config.Framework:lower() ~= 'qbox' then return end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    setup()
end)

function GetCharacterIdentifier()
    return QBX.PlayerData.citizenid
end