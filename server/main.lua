local Config = require('config.shared')
local sConfig = require('config.server')
local deliveries = {}
local delivering = {}

function discordLog(description)
    if not sConfig.log then return end
    if sConfig.log.ox_lib then
        lib.logger(GetCharacterIdentifier(source), 'matkez_ownablecarwash', description)
    else
        local embed = {{
            title = GetCurrentResourceName(),
            description = description,
            footer = { text = os.date('%d.%m.%Y | %X') }
        }}
        PerformHttpRequest(sConfig.webhook, function() end, 'POST', json.encode({ embeds = embed }), {['Content-Type'] = 'application/json'})
    end
end

function SpawnVehicle(source, model, coords)
    local vehicle = CreateVehicle(model, coords.xyz, coords.w, true, false)
    while not DoesEntityExist(vehicle) do
        Wait(0)
    end
    return vehicle
end

function randomId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local id = ''
    for i = 1, 6 do
        local rand = math.random(1, #chars)
        id = id .. chars:sub(rand, rand)
    end
    return id
end

lib.callback.register('matkez_ownablecarwash:createCarwash', function(source, data)
    if not HasPermission(source) then Exploit(source) return false end
    local rID = randomId()
    local id = MySQL.insert.await('INSERT INTO `matkez_ownablecarwash` (wash_id, owner, data, price, label) VALUES (?, ?, ?, ?, ?)', {
        rID, false, json.encode(data), data.price, data.label
    })
    if id then 
        Notify(source, translate('created_success'), 'success', 5000)
        discordLog(string.format(translate('log_created'), GetCharacterIdentifier(source), data, data.price))
        exports.ox_inventory:RegisterStash('carwash_'..rID, data.label, Config.Register.slots, Config.Register.weight)
        for _, id in ipairs(GetPlayers()) do
            lib.callback.await('matkez_ownablecarwash:createWashCL', id, data, rID)
        end
    end
end)

lib.callback.register('matkez_ownablecarwash:getAllWashes', function(source)
    local response = MySQL.query.await('SELECT `wash_id`, `owner`, `washPrice`, `orders`, `data`, `price`, `label` FROM `matkez_ownablecarwash`')
    return response
end)

lib.callback.register('matkez_ownablecarwash:getSpecificCarWash', function(source, wash_id)
    local row = MySQL.single.await('SELECT `owner`, `price`, `washPrice`, `orders`, `data`, `workers`, `price`, `water`, `label` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    return row
end)

lib.callback.register('matkez_ownablecarwash:isEmployee', function(source, wash_id, onlyBoss)
    return IsEmployee(source, wash_id, onlyBoss)
end)

lib.callback.register('matkez_ownablecarwash:buyCarWash', function(source, wash_id)
    local row = MySQL.single.await('SELECT `owner`, `price` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    local price = tonumber(row.price)
    if row.owner ~= '0' then Exploit(source) return false end
    local money = exports.ox_inventory:Search(source, 'count', 'money')
    if money < price then Notify(source, translate('no_money'), 'error', 5000) return false end
    exports.ox_inventory:RemoveItem(source, 'money', price)
    local affectedRows = MySQL.update.await('UPDATE matkez_ownablecarwash SET owner = ? WHERE wash_id = ?', {
        GetCharacterIdentifier(source), wash_id
    })
    if affectedRows then
        Notify(source, translate('bought_success'), 'success', 5000)
        discordLog(string.format(translate('log_bought'), GetCharacterIdentifier(source), wash_id, price))
    end
end)

lib.callback.register('matkez_ownablecarwash:employeeManagement', function(source, wash_id, id, action)
    local row = MySQL.single.await('SELECT `owner`, `workers`, `label` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })

    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    local workers = json.decode(row.workers or '[]')

    if action == 'hire' then
        local cid = GetCharacterIdentifier(id)

        if not GetCharacterIdentifier(id) then Notify(source, translate('invalid_id'), 'error', 5000) return false end

        local dist = #(GetEntityCoords(GetPlayerPed(id)) - GetEntityCoords(GetPlayerPed(source)))

        if dist > 10.0 then
            Notify(source, translate('too_far'), 'error', 5000)
            return false
        end

        for _, v in ipairs(workers) do
            if v.identifier == cid then
                Notify(source, translate('already_employed'), 'error', 5000)
                return false
            end
        end

        local want = lib.callback.await('matkez_ownablecarwash:hireQuestion', id, GetCharacterName(source), row.label)

        if want == 'confirm' then 
            table.insert(workers, {identifier = cid, name = GetCharacterName(id)})
            Notify(source, translate('hire_success'), 'success', 5000)
            discordLog(string.format(translate('log_hire'), GetCharacterIdentifier(source), cid, wash_id))
        end
    elseif action == 'fire' then
        for _, v in ipairs(workers) do
            if v.identifier == id then
                table.remove(workers, _)
            end
        end
    end
    local affectedRows = MySQL.update.await('UPDATE matkez_ownablecarwash SET workers = ? WHERE wash_id = ?', {
        json.encode(workers), wash_id
    })
    discordLog(string.format(translate('log_fire'), GetCharacterIdentifier(source), id, wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:orderWater', function(source, wash_id, amount)
    local row = MySQL.single.await('SELECT `owner`, `workers`, `label`, `orders` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    if amount > Config.Ordering.MaxLiters then return false end
    local money = exports.ox_inventory:Search('carwash_'..wash_id, 'count', 'money')
    if money < amount * Config.Ordering.PricePerLiter then Notify(source, translate('no_money'), 'error', 5000) return false end
    exports.ox_inventory:RemoveItem('carwash_'..wash_id, 'money', amount * Config.Ordering.PricePerLiter)
    local orders = json.decode(row.orders or '[]')
    table.insert(orders, {id = randomId(), liters = amount, busy = false})
    local affectedRows = MySQL.update.await('UPDATE matkez_ownablecarwash SET orders = ? WHERE wash_id = ?', {
        json.encode(orders), wash_id
    })
    discordLog(string.format(translate('log_order'), GetCharacterIdentifier(source), amount, amount * Config.Ordering.PricePerLiter, wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:openRegister', function(source, wash_id)
    if not IsEmployee(source, wash_id, false) then Exploit(source) return false end
    exports.ox_inventory:forceOpenInventory(source, 'stash', 'carwash_'..wash_id)
    discordLog(string.format(translate('log_register'), GetCharacterIdentifier(source), wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:changeLabel', function(source, wash_id, label)
    local row = MySQL.single.await('SELECT `owner`, `label` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    local affectedRows = MySQL.update.await('UPDATE matkez_ownablecarwash SET label = ? WHERE wash_id = ?', {
        label, wash_id
    })
    discordLog(string.format(translate('log_label'), GetCharacterIdentifier(source), wash_id, row.label, label))
    
    for _, id in ipairs(GetPlayers()) do
        lib.callback.await('matkez_ownablecarwash:setupBlips', id)
    end

    return true
end)

lib.callback.register('matkez_ownablecarwash:changePrice', function(source, wash_id, price)
    local row = MySQL.single.await('SELECT `owner`, `label`, `washPrice` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    local affectedRows = MySQL.update.await('UPDATE matkez_ownablecarwash SET washPrice = ? WHERE wash_id = ?', {
        price, wash_id
    })
    discordLog(string.format(translate('log_price'), GetCharacterIdentifier(source), wash_id, row.washPrice, price))
    return true
end)

lib.callback.register('matkez_ownablecarwash:washVehicle', function(source, wash_id)
    local row = MySQL.single.await('SELECT `owner`, `label`, `washPrice`, `water` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if tonumber(row.water) < Config.Washing.WaterPerWash then Notify(source, translate('no_water'), 'error', 5000) return false end
    local money = exports.ox_inventory:Search(source, 'count', 'money')
    local price = tonumber(row.washPrice)
    local question = lib.callback.await('matkez_ownablecarwash:washQuestion', source, price)
    if question ~= 'confirm' then return false end
    if money < price then Notify(source, translate('no_money'), 'error', 5000) return false end
    MySQL.update.await('UPDATE matkez_ownablecarwash SET water = water - ? WHERE wash_id = ?', {
        Config.Washing.WaterPerWash, wash_id
    })
    local progress = lib.callback.await('matkez_ownablecarwash:progress', source)
    if progress then
        exports.ox_inventory:AddItem('carwash_'..wash_id, 'money', price)
        exports.ox_inventory:RemoveItem(source, 'money', price)
        SetVehicleDirtLevel(GetVehiclePedIsIn(GetPlayerPed(source), false), 0.0)
        return true
    else
        MySQL.update.await('UPDATE matkez_ownablecarwash SET water = water + ? WHERE wash_id = ?', {
            Config.Washing.WaterPerWash, wash_id
        })
        return false
    end
end)

lib.callback.register('matkez_ownablecarwash:startDelivery', function(source, wash_id, delivery_id)
    local row = MySQL.single.await('SELECT `owner`, `label`, `data`, `orders`, `water` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    if not IsEmployee(source, wash_id, false) then Exploit(source) return false end
    if delivering[source] == true then Notify(source, translate('already_delivering'), 'error', 5000) return false end
    local orders = json.decode(row.orders)
    local data = json.decode(row.data)
    local tankerCoords
    for _, v in ipairs(orders) do
        if v.id == delivery_id then
            if v.busy == true then return false end
            v.busy = true
            break
        end
    end

    for _, v in ipairs(Config.Delivery.TankerCoords) do
        local vehicle, vehicleCoords = lib.getClosestVehicle(vector3(v.x, v.y, v.z), 10.0, false)
        if not vehicleCoords then tankerCoords = v break end
    end

    if not tankerCoords then Notify(source, translate('no_place_for_tanker'), 'error', 5000) return false end

    MySQL.update.await('UPDATE matkez_ownablecarwash SET orders = ? WHERE wash_id = ?', {
        json.encode(orders), wash_id
    })

    local truck = SpawnVehicle(source, Config.Delivery.TruckModel, vec4(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z, data.truckHeading))
    local tanker = SpawnVehicle(source, Config.Delivery.TankerModel, tankerCoords)
    local plate = GetVehicleNumberPlateText(tanker)

    GiveKeys(source, GetVehicleNumberPlateText(truck))
    
    table.insert(deliveries, {
        truck = truck,
        tanker = tanker,
        wichWash = wash_id,
        tankerPlate = plate,
        delivery_id = delivery_id,
        playerId = source
    })

    delivering[source] = true
    discordLog(string.format(translate('log_delivery'), GetCharacterIdentifier(source), delivery_id, wash_id))

    return true, tankerCoords
end)

lib.callback.register('matkez_ownablecarwash:deliverWater', function(source, plate, wash_id)
    if not plate then return false end
    if not IsEmployee(source, wash_id, false) then return false end

    local row = MySQL.single.await('SELECT `data`, `orders`, `water` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })

    local data = json.decode(row.data)
    local orders = json.decode(row.orders)
    local distCheck = #(GetEntityCoords(GetPlayerPed(source)) - vec3(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z))

    if distCheck > 10.0 then Exploit(source) return false end

    local deliveryToRemove
    local orderToRemove
    local liters
    local delivery_id

    for del, v in ipairs(deliveries) do
        if v.tankerPlate == plate then
            if wash_id ~= v.wichWash then return false end
            if v.playerId ~= source then Notify(source, translate('not_yours'), 'error', 5000) return false end
            DeleteEntity(v.tanker)
            DeleteEntity(v.truck)
            deliveryToRemove = del
            delivery_id = v.delivery_id
            for ord, order in ipairs(orders) do
                if order.id == v.delivery_id then
                    liters = order.liters
                    orderToRemove = ord
                    break
                end
            end
            break
        end
    end

    if deliveryToRemove and orderToRemove then
        table.remove(deliveries, deliveryToRemove)
        table.remove(orders, orderToRemove)

        MySQL.update.await('UPDATE matkez_ownablecarwash SET water = water + ? WHERE wash_id = ?', {
            liters, wash_id
        })

        MySQL.update.await('UPDATE matkez_ownablecarwash SET orders = ? WHERE wash_id = ?', {
            json.encode(orders), wash_id
        })

        delivering[source] = false
        discordLog(string.format(translate('log_delivered'), GetCharacterIdentifier(source), delivery_id, liters, wash_id))
        return true
    end
    return false
end)

lib.callback.register('matkez_ownablecarwash:transferOwnership', function(source, wash_id, id)
    local row = MySQL.single.await('SELECT `owner` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
        wash_id
    })
    
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    if id == source then return false end
    local newOwner = GetCharacterIdentifier(id)
    if not newOwner then Notify(source, translate('invalid_id'), 'error', 5000) return false end
    
    MySQL.update.await('UPDATE matkez_ownablecarwash SET owner = ? WHERE wash_id = ?', {
        newOwner, wash_id
    })
    discordLog(string.format(translate('log_ownership'), GetCharacterIdentifier(source), wash_id, newOwner))
    return true
end)

function CancelDelivery(source)
    for _, v in ipairs(deliveries) do
        if v.playerId == source then
            local row = MySQL.single.await('SELECT `data`, `orders`, `water` FROM `matkez_ownablecarwash` WHERE `wash_id` = ? LIMIT 1', {
                v.wichWash
            })
            local orders = json.decode(row.orders)
            for __, order in ipairs(orders) do
                if order.id == v.delivery_id then
                    order.busy = false
                end
            end
            MySQL.update.await('UPDATE matkez_ownablecarwash SET orders = ? WHERE wash_id = ?', {
                json.encode(orders), v.wichWash
            })
            DeleteEntity(v.tanker)
            DeleteEntity(v.truck)
            table.remove(deliveries, _)
            break
        end
    end
end

AddEventHandler('playerDropped', function(r, cr, s)
    CancelDelivery(source)
end)

RegisterCommand(Config.Delivery.CancelCommand, function(source)
    CancelDelivery(source)
end)

Citizen.CreateThread(function()
    local response = MySQL.query.await('SELECT `wash_id`, `owner`, `washPrice`, `data`, `price`, `label` FROM `matkez_ownablecarwash`')
    for _, v in ipairs(response) do
        exports.ox_inventory:RegisterStash('carwash_'..v.wash_id, v.label, Config.Register.slots, Config.Register.weight)
    end
end)