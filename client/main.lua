local Config = require('config.shared')
local icon = Config.Icons
local props = {}
local blips = {}


function setupBlips()
    for i = 1, #blips do
        RemoveBlip(blips[i])
    end
    local washes = lib.callback.await('matkez_ownablecarwash:getAllWashes', false)
    for _, v in ipairs(washes) do
        local data = json.decode(v.data)
        local blip = AddBlipForCoord(data.washCoords.x, data.washCoords.y, data.washCoords.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipColour(blip, Config.Blip.color)
        SetBlipScale(blip, Config.Blip.size)
        SetBlipDisplay(blip, 4)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(v.label)
        EndTextCommandSetBlipName(blip)
        SetBlipAsShortRange(blip, true)
        table.insert(blips, blip)
    end
end

function setup()
    local washes = lib.callback.await('matkez_ownablecarwash:getAllWashes', false)
    for _, v in ipairs(washes) do
        local data = json.decode(v.data)
        RequestModel(Config.Creator.props.ped)
        while not HasModelLoaded(Config.Creator.props.ped) do
            Wait(0)
        end
        local ped = CreatePed(4, Config.Creator.props.ped, data.pedCoords.x, data.pedCoords.y, data.pedCoords.z - 1, data.pedHeading, false, false)
        PlaceObjectOnGroundProperly(ped)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        if Config.Target == 'ox_target' then
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'carwash_'..v.wash_id,
                    icon = icon.ox_target_open,
                    label = translate('ox_target_open'),
                    onSelect = function(target)
                        CarWash(v.wash_id)
                    end,
                    distance = 1.5,
                }
            })
        elseif Config.Target == 'qb-target' then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        icon = icon.ox_target_open,
                        label = translate('ox_target_open'),
                        action = function(entity)
                            CarWash(v.wash_id)
                        end,
                    }
                },
                distance = 1.5
            })
        end

        table.insert(props, ped)

        lib.zones.sphere({
            coords = vec3(data.washCoords.x, data.washCoords.y, data.washCoords.z),
            radius = Config.Washing.WashRadius,
            --debug = true,
            inside = function()
                if IsControlJustPressed(0, 38) then
                    Wash(v.wash_id)
                    return
                end
            end,
            onEnter = function()
                lib.showTextUI(translate('wash_vehicle'))
            end,
            onExit = function()
                lib.hideTextUI()
            end
        })

        lib.zones.sphere({
            coords = vec3(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z),
            radius = 5,
            --debug = true,
            inside = function()
                if IsControlJustPressed(0, 38) then
                    if not IsPedInAnyVehicle(cache.ped, false) then return end
                    local vehicle = GetVehiclePedIsIn(cache.ped, false)
                    local attached, trailer = GetVehicleTrailerVehicle(vehicle)
                    lib.callback.await('matkez_ownablecarwash:deliverWater', false, GetVehicleNumberPlateText(trailer), v.wash_id)
                    return
                end
            end,
            onEnter = function()
                local isEmployee = lib.callback.await('matkez_ownablecarwash:isEmployee', false, v.wash_id, false)
                if isEmployee then
                    lib.showTextUI(translate('deliver_textui'))
                end
            end,
            onExit = function()
                lib.hideTextUI()
            end
        })
    end
    setupBlips()
end

lib.callback.register('matkez_ownablecarwash:createWashCL', function(data, wash_id)
    RequestModel(Config.Creator.props.ped)
    while not HasModelLoaded(Config.Creator.props.ped) do
        Wait(0)
    end
    local ped = CreatePed(4, Config.Creator.props.ped, data.pedCoords.x, data.pedCoords.y, data.pedCoords.z - 1, data.pedHeading, false, false)
    PlaceObjectOnGroundProperly(ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'carwash_'..wash_id,
            icon = icon.ox_target_open,
            label = translate('ox_target_open'),
            onSelect = function(target)
                CarWash(wash_id)
            end,
            distance = 1.5,
        }
    })

    table.insert(props, ped)

    lib.zones.sphere({
        coords = vec3(data.washCoords.x, data.washCoords.y, data.washCoords.z),
        radius = Config.Washing.WashRadius,
        --debug = true,
        inside = function()
            if IsControlJustPressed(0, 38) then
                Wash(wash_id)
                return
            end
        end,
        onEnter = function()
            lib.showTextUI(translate('wash_vehicle'))
        end,
        onExit = function()
            lib.hideTextUI()
        end
    })

    lib.zones.sphere({
        coords = vec3(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z),
        radius = 5,
        --debug = true,
        inside = function()
            if IsControlJustPressed(0, 38) then
                if not IsPedInAnyVehicle(cache.ped, false) then return end
                local vehicle = GetVehiclePedIsIn(cache.ped, false)
                local attached, trailer = GetVehicleTrailerVehicle(vehicle)
                lib.callback.await('matkez_ownablecarwash:deliverWater', false, GetVehicleNumberPlateText(trailer), wash_id)
                return
            end
        end,
        onEnter = function()
            local isEmployee = lib.callback.await('matkez_ownablecarwash:isEmployee', false, wash_id, false)
            if isEmployee then
                lib.showTextUI(translate('deliver_textui'))
            end
        end,
        onExit = function()
            lib.hideTextUI()
        end
    })
    setupBlips()
end)

function Wash(wash_id)
    if not IsPedInAnyVehicle(cache.ped, false) then return end
    FreezeEntityPosition(GetVehiclePedIsIn(cache.ped, false), true)
    UseParticleFxAssetNextCall('core')
    local ptfx = StartParticleFxLoopedAtCoord('ent_amb_waterfall_splash_p', GetEntityCoords(cache.ped).xyz, 0.0, 0.0, GetEntityHeading(cache.ped), 1.0, 1, 1, 1, false)
    lib.callback.await('matkez_ownablecarwash:washVehicle', false, wash_id)
    StopParticleFxLooped(ptfx, true)
    FreezeEntityPosition(GetVehiclePedIsIn(cache.ped, false), false)
end

function CarWash(wash_id)
    local wash = lib.callback.await('matkez_ownablecarwash:getSpecificCarWash', false, wash_id)
    
    if wash.owner == '0' then
        local alert = lib.alertDialog({
            header = translate('buy_alert_header'),
            content = string.format(translate('buy_alert_content'), wash.price),
            centered = true,
            cancel = true,
            labels = {
                confirm = translate('buy_button_confirm'),
                cancel = translate('buy_button_cancel')
            }
        })
        if alert == 'confirm' then
            lib.callback.await('matkez_ownablecarwash:buyCarWash', false, wash_id)
        end
        return
    end
    
    local options = {}
    local workersCount = json.decode(wash.workers)
    local isEmployee = lib.callback.await('matkez_ownablecarwash:isEmployee', false, wash_id, false)

    if not isEmployee then Notify(nil, translate('not_employee'), 'error', 5000) return false end

    table.insert(options, {
        title = translate('stats'),
        description = string.format(translate('stats_description'), wash.water, #workersCount, wash.washPrice),
        icon = icon.stats,
        disabled = true
    })

    table.insert(options, {
        title = translate('open_register'),
        description = translate('open_register_description'),
        icon = icon.open_register,
        onSelect = function()
            lib.callback.await('matkez_ownablecarwash:openRegister', false, wash_id)
        end,
    })

    table.insert(options, {
        title = translate('order_list'),
        description = translate('order_list_description'),
        icon = icon.order_list,
        onSelect = function()
            local opt = {}
            local list = json.decode(wash.orders or '[]')

            table.insert(opt, {
                title = translate('go_back'),
                description = translate('go_back_description'),
                icon = icon.go_back,
                onSelect = function()
                    CarWash(wash_id)
                end,
            })

            for __, order in ipairs(list) do
                table.insert(opt, {
                    title = tostring(order.liters)..'L',
                    description = string.format(translate('busy'), order.busy),
                    icon = icon.water,
                    disabled = order.busy,
                    onSelect = function()
                        local alert = lib.alertDialog({
                            header = translate('delivery_question_header'),
                            content = translate('delivery_question_content'),
                            centered = true,
                            cancel = true
                        })
                        if alert == 'confirm' then
                            local cb, coords = lib.callback.await('matkez_ownablecarwash:startDelivery', false, wash_id, order.id)
                            if cb then
                                SetNewWaypoint(coords.x, coords.y)
                                Notify(nil, translate('notify_delivery'), 'success', 5000)
                            end
                        end
                    end,
                })
            end

            lib.registerContext({
                id = 'oreder_list',
                title = translate('start_question_header'),
                options = opt
            })
            lib.showContext('oreder_list')
        end,
    })

    if wash.owner == GetCharacterIdentifier() then
        table.insert(options, {
            title = translate('change_label'),
            description = translate('change_label_description'),
            icon = icon.carwash_label,
            onSelect = function()
                local input = lib.inputDialog('', {
                    {type = 'input', required = true, label = translate('carwash_label'), description = '', max = 30},
                })
                if not input then return end
                lib.callback.await('matkez_ownablecarwash:changeLabel', false, wash_id, input[1])
            end,
        })

        table.insert(options, {
            title = translate('change_price'),
            description = translate('change_price_description'),
            icon = icon.change_price,
            onSelect = function()
                local input = lib.inputDialog('', {
                    {type = 'number', required = true, label = translate('change_price'), description = '', min = Config.Washing.MinWashPrice, max = Config.Washing.MaxWashPrice},
                })
                if not input then return end
                lib.callback.await('matkez_ownablecarwash:changePrice', false, wash_id, input[1])
            end,
        })

        table.insert(options, {
            title = translate('order_water'),
            description = translate('order_water_description'),
            icon = icon.order_water,
            onSelect = function()
                local input = lib.inputDialog('', {
                    {type = 'slider', min = 1, max = Config.Ordering.MaxLiters, step = 1, required = true, label = 'ID', description = ''},
                })
                if not input then return end
                lib.callback.await('matkez_ownablecarwash:orderWater', false, wash_id, input[1])
            end,
        })

        table.insert(options, {
            title = translate('hire'),
            description = translate('hire_description'),
            icon = icon.hire,
            onSelect = function()
                local input = lib.inputDialog('', {
                    {type = 'number', required = true, label = 'ID', description = ''},
                })
                if not input then return end
                lib.callback.await('matkez_ownablecarwash:employeeManagement', false, wash_id, input[1], 'hire')
            end,
        })

        table.insert(options, {
            title = translate('fire'),
            description = translate('fire_description'),
            icon = icon.fire,
            onSelect = function()
                local opt = {}
                local workers = json.decode(wash.workers or '[]')
                table.insert(opt, {
                    title = translate('go_back'),
                    description = translate('go_back_description'),
                    icon = icon.go_back,
                    onSelect = function()
                        CarWash(wash_id)
                    end,
                })
                for __, worker in ipairs(workers) do
                    table.insert(opt, {
                        title = worker.name,
                        icon = icon.user,
                        onSelect = function()
                            local alert = lib.alertDialog({
                                header = translate('fire_header'),
                                content = string.format(translate('fire_content'), worker.name),
                                centered = true,
                                cancel = true
                            })
                            if alert == 'confirm' then
                                lib.callback.await('matkez_ownablecarwash:employeeManagement', false, wash_id, worker.identifier, 'fire')
                            end
                        end,
                    })
                end
                lib.registerContext({
                    id = 'fire_employee',
                    title = translate('fire_header'),
                    options = opt
                })
                lib.showContext('fire_employee')
            end,
        })

        table.insert(options, {
            title = translate('transfer_ownership'),
            description = translate('transfer_ownership_description'),
            icon = icon.transfer_ownership,
            onSelect = function()
                local input = lib.inputDialog('', {
                    {type = 'number', required = true, label = translate('transfer_ownership'), description = '',},
                })
                if not input then return end
                lib.callback.await('matkez_ownablecarwash:transferOwnership', false, wash_id, input[1])
            end,
        })
    end
    
    lib.registerContext({
        id = 'carwash_management_'..wash_id,
        title = wash.label,
        options = options
    })

    lib.showContext('carwash_management_'..wash_id)
end

lib.callback.register('matkez_ownablecarwash:hireQuestion', function(owner, label)
    local alert = lib.alertDialog({
        header = translate('hire_question_header'),
        content = string.format(translate('hire_question_content'), owner, label),
        centered = true,
        cancel = true
    })

    return alert
end)

lib.callback.register('matkez_ownablecarwash:progress', function()
    local progress = lib.progressBar({
        duration = Config.Washing.WashingDuration,
        label = translate('washing_vehicle'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            comat = true
        },
    })
    return progress
end)

lib.callback.register('matkez_ownablecarwash:washQuestion', function(price)
    local alert = lib.alertDialog({
        header = translate('wash_question_header'),
        content = string.format(translate('wash_question_content'), price),
        centered = true,
        cancel = true
    })
    return alert
end)

lib.callback.register('matkez_ownablecarwash:setupBlips', function()
    setupBlips()
end)

AddEventHandler('onResourceStart', function(r)
    if GetCurrentResourceName() ~= r then return end
    setup()
end)