local Config = require('config.shared')
if Config.Framework:lower() ~= 'qbox' then return end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    setup()
end)

function HasPermission()
    local identifier = QBX.PlayerData.citizenid
    for _, id in ipairs(Config.Creator.allowed) do
        if id == identifier then 
            return true 
        end
    end
    return false
end

function GetCharacterIdentifier()
    return QBX.PlayerData.citizenid
end