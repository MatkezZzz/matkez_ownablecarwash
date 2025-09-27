local Config = require('config.shared')

function translate(message)
    local lng = Config.Languages[Config.Language]
    return lng[message]
end

function Notify(source, msg, type, duration)
    if IsDuplicityVersion() then 
        TriggerClientEvent('ox_lib:notify', source, {
            description = msg,
            type = type,
            duration = duration
        })
    else
        lib.notify({
            description = msg,
            type = type,
            duration = duration
        })
    end
end