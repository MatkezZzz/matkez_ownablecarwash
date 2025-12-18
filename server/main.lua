local Config = require('config.shared')
local sConfig = require('config.server')
local cachedWashes = {}
local deliveries = {}
local delivering = {}


CreateThread(function()
    local response = MySQL.query.await('SELECT * FROM `matkez_ownablecarwash`')
    for _, v in ipairs(response) do
        cachedWashes[v.wash_id] = {
            wash_id = v.wash_id,
            owner = v.owner,
            workers = json.decode(v.workers or '[]'),
            data = json.decode(v.data or '[]'),
            price = v.price,
            washPrice = v.washPrice,
            label = v.label,
            water = v.water,
            orders = json.decode(v.orders or '[]')
        }
    end
end)

function HasPermission(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in ipairs(identifiers) do
        if Config.Creator.allowed[identifier] then return true end
    end
    return false
end

function IsEmployee(source, wash_id, onlyBoss)
    local identifier = GetCharacterIdentifier(source)
    local wash = cachedWashes[wash_id]
    if wash.owner == identifier then return true end
    if not onlyBoss then
        for _, v in ipairs(wash.workers) do
            if v.identifier == identifier then
                return true
            end
        end
    end
    return false
end

function Log(description)
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
        cachedWashes[rID] = {
            wash_id = rID,
            owner = '0',
            workers = {},
            data = data,
            price = data.price,
            washPrice = 15,
            label = data.label,
            water = 100,
            orders = {}
        }
        Notify(source, translate('created_success'), 'success', 5000)
        Log(string.format(translate('log_created'), GetCharacterIdentifier(source), data, data.price))
        exports.ox_inventory:RegisterStash('carwash_'..rID, data.label, Config.Register.slots, Config.Register.weight)
        for _, id in ipairs(GetPlayers()) do
            lib.callback.await('matkez_ownablecarwash:createWashCL', id, data, rID)
        end
    end
end)

lib.callback.register('matkez_ownablecarwash:getAllWashes', function(source)
    return cachedWashes
end)

lib.callback.register('matkez_ownablecarwash:getSpecificCarWash', function(source, wash_id)
    return cachedWashes[wash_id]
end)

lib.callback.register('matkez_ownablecarwash:isEmployee', function(source, wash_id, onlyBoss)
    return IsEmployee(source, wash_id, onlyBoss)
end)

lib.callback.register('matkez_ownablecarwash:buyCarWash', function(source, wash_id)
    local row = cachedWashes[wash_id]
    local price = tonumber(row.price)
    if row.owner ~= '0' then Exploit(source) return false end
    local money = exports.ox_inventory:Search(source, 'count', 'money')
    if money < price then Notify(source, translate('no_money'), 'error', 5000) return false end
    exports.ox_inventory:RemoveItem(source, 'money', price)
    row.owner = GetCharacterIdentifier(source)
    Notify(source, translate('bought_success'), 'success', 5000)
    Log(string.format(translate('log_bought'), GetCharacterIdentifier(source), wash_id, price))
end)

lib.callback.register('matkez_ownablecarwash:employeeManagement', function(source, wash_id, id, action)
    local row = cachedWashes[wash_id]

    if not id then Notify(source, translate('invalid_id'), 'error', 5000) return false end
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    local workers = row.workers

    if action == 'hire' then
        local cid = GetCharacterIdentifier(id)

        if not GetCharacterIdentifier(id) then return false end

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
            Log(string.format(translate('log_hire'), GetCharacterIdentifier(source), cid, wash_id))
        end
    elseif action == 'fire' then
        for _, v in ipairs(workers) do
            if v.identifier == id then
                table.remove(workers, _)
            end
        end
    end
    Wait(100)
    row.workers = workers
    Log(string.format(translate('log_fire'), GetCharacterIdentifier(source), id, wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:orderWater', function(source, wash_id, amount)
    local row = cachedWashes[wash_id]
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    if amount > Config.Ordering.MaxLiters then return false end
    local money = exports.ox_inventory:Search('carwash_'..wash_id, 'count', 'money')
    if money < amount * Config.Ordering.PricePerLiter then Notify(source, translate('no_money'), 'error', 5000) return false end
    exports.ox_inventory:RemoveItem('carwash_'..wash_id, 'money', amount * Config.Ordering.PricePerLiter)
    local orders = row.orders
    table.insert(orders, {id = randomId(), liters = amount, busy = false})
    Wait(100)
    row.orders = orders
    Log(string.format(translate('log_order'), GetCharacterIdentifier(source), amount, amount * Config.Ordering.PricePerLiter, wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:openRegister', function(source, wash_id)
    if not IsEmployee(source, wash_id, false) then Exploit(source) return false end
    exports.ox_inventory:forceOpenInventory(source, 'stash', 'carwash_'..wash_id)
    Log(string.format(translate('log_register'), GetCharacterIdentifier(source), wash_id))
    return true
end)

lib.callback.register('matkez_ownablecarwash:changeLabel', function(source, wash_id, label)
    local row = cachedWashes[wash_id]
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    row.label = label
    Log(string.format(translate('log_label'), GetCharacterIdentifier(source), wash_id, row.label, label))
    
    for _, id in ipairs(GetPlayers()) do
        lib.callback.await('matkez_ownablecarwash:setupBlips', id)
    end

    return true
end)

lib.callback.register('matkez_ownablecarwash:changePrice', function(source, wash_id, price)
    local row = cachedWashes[wash_id]
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    row.washPrice = price
    Log(string.format(translate('log_price'), GetCharacterIdentifier(source), wash_id, row.washPrice, price))
    return true
end)

lib.callback.register('matkez_ownablecarwash:washVehicle', function(source, wash_id)
    local row = cachedWashes[wash_id]
    if tonumber(row.water) < Config.Washing.WaterPerWash then Notify(source, translate('no_water'), 'error', 5000) return false end
    local money = exports.ox_inventory:Search(source, 'count', 'money')
    local price = tonumber(row.washPrice)
    local question = lib.callback.await('matkez_ownablecarwash:washQuestion', source, price)
    if question ~= 'confirm' then return false end
    if money < price then Notify(source, translate('no_money'), 'error', 5000) return false end
    row.water -= Config.Washing.WaterPerWash
    local progress = lib.callback.await('matkez_ownablecarwash:progress', source)
    if progress then
        exports.ox_inventory:AddItem('carwash_'..wash_id, 'money', price)
        exports.ox_inventory:RemoveItem(source, 'money', price)
        SetVehicleDirtLevel(GetVehiclePedIsIn(GetPlayerPed(source), false), 0.0)
        return true
    else
        row.water += Config.Washing.WaterPerWash
        return false
    end
end)

lib.callback.register('matkez_ownablecarwash:startDelivery', function(source, wash_id, delivery_id)
    local row = cachedWashes[wash_id]
    if not IsEmployee(source, wash_id, false) then Exploit(source) return false end
    if delivering[source] == true then Notify(source, translate('already_delivering'), 'error', 5000) return false end
    local orders = row.orders
    local data = row.data
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

    row.orders = orders

    local truck = SpawnVehicle(source, Config.Delivery.TruckModel, vec4(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z, data.truckHeading))
    local tanker = SpawnVehicle(source, Config.Delivery.TankerModel, tankerCoords)
    local plate = GetVehicleNumberPlateText(tanker)

    GiveKeys(source, GetVehicleNumberPlateText(truck))
    
    table.insert(deliveries, {
        truck = truck,
        tanker = tanker,
        whichWash = wash_id,
        tankerPlate = plate,
        delivery_id = delivery_id,
        playerId = source
    })

    delivering[source] = true
    Log(string.format(translate('log_delivery'), GetCharacterIdentifier(source), delivery_id, wash_id))

    return true, tankerCoords
end)

lib.callback.register('matkez_ownablecarwash:deliverWater', function(source, plate, wash_id)
    if not plate then return false end
    if not IsEmployee(source, wash_id, false) then return false end

    local row = cachedWashes[wash_id]

    local data = row.data
    local orders = row.orders
    local distCheck = #(GetEntityCoords(GetPlayerPed(source)) - vec3(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z))

    if distCheck > 10.0 then Exploit(source) return false end

    local deliveryToRemove
    local orderToRemove
    local liters
    local delivery_id

    for del, v in ipairs(deliveries) do
        if v.tankerPlate == plate then
            if wash_id ~= v.whichWash then return false end
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

        row.water += liters

        row.orders = orders

        delivering[source] = false
        Log(string.format(translate('log_delivered'), GetCharacterIdentifier(source), delivery_id, liters, wash_id))
        return true
    end
    return false
end)

lib.callback.register('matkez_ownablecarwash:transferOwnership', function(source, wash_id, id)
    local row = cachedWashes[wash_id]
    
    if row.owner ~= GetCharacterIdentifier(source) then Exploit(source) return false end
    if id == source then return false end
    local newOwner = GetCharacterIdentifier(id)
    if not newOwner then Notify(source, translate('invalid_id'), 'error', 5000) return false end
    
    row.owner = newOwner
    Log(string.format(translate('log_ownership'), GetCharacterIdentifier(source), wash_id, newOwner))
    return true
end)

function CancelDelivery(source)
    if not delivering[source] then return false end
    for _, v in ipairs(deliveries) do
        if v.playerId == source then
            local row = cachedWashes[v.whichWash]
            local orders = row.orders
            for __, order in ipairs(orders) do
                if order.id == v.delivery_id then
                    order.busy = false
                end
            end
            row.orders = orders
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

lib.addCommand(Config.Creator.Command, {
    help = '',
}, function(source, args, raw)
    if not HasPermission(source) then return false end
    lib.callback.await('matkez_ownablecarwash:client:creatorContext', source)
end)

lib.addCommand(Config.Delivery.CancelCommand, {
    help = '',
}, function(source, args, raw)
    CancelDelivery(source)
end)

CreateThread(function()
    Wait(1000)
    for k, v in pairs(cachedWashes) do
        exports.ox_inventory:RegisterStash('carwash_'..k, v.label, Config.Register.slots, Config.Register.weight)
    end
end)

function saveAllWashes()
    for k, v in pairs(cachedWashes) do
        MySQL.update.await('UPDATE matkez_ownablecarwash SET owner = ?, workers = ?, data = ?, price = ?, washPrice = ?, label = ?, water = ?, orders = ? WHERE wash_id = ?', {
            v.owner, json.encode(v.workers), json.encode(v.data), v.price, v.washPrice, v.label, v.water, json.encode(v.orders), k
        })
    end
end

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    saveAllWashes()
end)