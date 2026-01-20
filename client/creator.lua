local Config = require('config.shared')
local icon = Config.Icons
local creatorData = {price = nil, label = nil, pedCoords = nil, pedHeading = nil, washingCoords = {}, truckCoords = nil, truckHeading = nil}
local raycastObject
local creating = false

function resetCreatorData()
    creatorData = {price = nil, label = nil, pedCoords = nil, pedHeading = nil, washingCoords = {}, truckCoords = nil, truckHeading = nil}
end

function raycast(type)
    local cType = Config.Creator.props[type]
    RequestModel(cType)
    while not HasModelLoaded(cType) do
        Wait(20)
    end
    creating = true

    lib.showTextUI(translate('creator_textui'))

    if type == 'ped' then 
        raycastObject = CreatePed(4, cType, GetEntityCoords(cache.ped).xyz, false, false, false)
    else
        raycastObject = CreateObject(cType, GetEntityCoords(cache.ped).xyz, false, false, false)
    end
    SetEntityCollision(raycastObject, false, false)
    SetEntityAlpha(raycastObject, 150, false)
    while creating do
        Wait(0)
        local h, eh, ec, sn, mh = lib.raycast.fromCamera(511, 4, Config.Creator.raycastDistance)
        SetEntityCoords(raycastObject, ec, false, false, false, false)
        PlaceObjectOnGroundProperly(raycastObject)
        if IsControlPressed(0, 73) then
            creating = false
            lib.hideTextUI()
            DeleteEntity(raycastObject)
            creatorContext()
            return false
        elseif IsControlPressed(0, 19) then
            SetEntityHeading(raycastObject, GetEntityHeading(raycastObject) + 1.5)
        elseif IsControlPressed(0, 21) then
            SetEntityHeading(raycastObject, GetEntityHeading(raycastObject) - 1.5)
        elseif IsControlPressed(0, 215) then
            creating = false,
            lib.hideTextUI()
            if ec == vec3(0, 0, 0) then Notify(nil, translate('invalid_placement'), 'error', 5000) return false end
            FreezeEntityPosition(raycastObject, true)
            if type == 'ped' then
                creatorData.pedCoords = GetEntityCoords(raycastObject)
                creatorData.pedHeading = GetEntityHeading(raycastObject)
            elseif type == 'wash_coords' then
                table.insert(creatorData.washingCoords, GetEntityCoords(raycastObject))
            elseif type == 'truck' then
                creatorData.truckCoords = GetEntityCoords(raycastObject)
                creatorData.truckHeading = GetEntityHeading(raycastObject)
            end
            DeleteEntity(raycastObject)
            raycastObject = nil
            creatorContext()
            return true
        end
    end
end

function creatorContext()
    local disabled = true

    if creatorData.label ~= nil and creatorData.pedCoords ~= nil and creatorData.truckCoords ~= nil and #creatorData.washingCoords > 0 then 
        disabled = false
    end

    lib.registerContext({
        id = 'creator_context',
        title = translate('creator_context_title'),
        options = {
            {
                title = translate('carwash_label'),
                description = translate('carwash_label_description'),
                icon = icon.carwash_label,
                onSelect = function()
                    local input = lib.inputDialog(translate('carwash_label'), {
                        {type = 'input', label = translate('carwash_label'), description = translate('carwash_label_description'), required = true, min = 1, max = 50}
                    })
                    if not input then return end
                    creatorData.label = input[1]
                    creatorContext()
                end,
            },
            {
                title = translate('carwash_price'),
                description = translate('carwash_price_description'),
                icon = icon.carwash_price,
                onSelect = function()
                    local input = lib.inputDialog(translate('carwash_price'), {
                        {type = 'number', max = Config.Creator.maxPrice, min = Config.Creator.minPrice, label = translate('carwash_price'), description = translate('carwash_price_description'), icon = icon.carwash_price},
                    })
                    if not input then return end
                    creatorData.price = input[1]
                    creatorContext()
                end,
            },
            {
                title = translate('carwash_wash_pos'),
                description = translate('carwash_wash_pos_description'),
                icon = icon.carwash_wash_pos,
                onSelect = function()
                    raycast('wash_coords')
                end,
            },
            {
                title = translate('washing_coords'),
                description = translate('washing_coords_desc'),
                icon = icon.washing_coords_list,
                onSelect = function()
                    openCachedCoords()
                end
            },
            {
                title = translate('carwash_truck_pos'),
                description = translate('carwash_truck_pos_description'),
                icon = icon.carwash_truck_pos,
                onSelect = function()
                    raycast('truck')
                end,
            },
            {
                title = translate('carwash_ped_pos'),
                description = translate('carwash_ped_pos_description'),
                icon = icon.carwash_ped_pos,
                onSelect = function()
                    raycast('ped')
                end,
            },
            {
                title = translate('reset_all'),
                description = translate('reset_all_description'),
                icon = icon.reset_all,
                onSelect = function()
                    resetCreatorData()
                    creatorContext()
                end,
            },
            {
                title = translate('create_carwash'),
                icon = icon.create_carwash,
                disabled = disabled,
                onSelect = function()
                    lib.callback.await('matkez_ownablecarwash:createCarwash', false, creatorData)
                    Wait(100)
                    resetCreatorData()
                end,
            },
        }
    })

    lib.showContext('creator_context')
end

function openCachedCoords()
    local options = {}
    local coordsTable = creatorData.washingCoords

    table.insert(options, {
        title = translate('go_back'),
        description = translate('go_back_description'),
        icon = icon.go_back,
        onSelect = function()
            creatorContext()
        end,
    })

    for idx, v in ipairs(coordsTable) do
        table.insert(options, {
            title = '['..idx..'] '..tostring(v),
            description = translate('creator_delete_coord'),
            icon = icon.washing_coords,
            onSelect = function()
                table.remove(coordsTable, idx)
                openCachedCoords()
            end
        })
    end

    lib.registerContext({
        id = 'cachedCoords',
        title = translate('coords_title'),
        options = options
    })
    lib.showContext('cachedCoords')
end

lib.callback.register('matkez_ownablecarwash:client:creatorContext', creatorContext)