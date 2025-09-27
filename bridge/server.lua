
function SpawnVehicle(source, model, coords)
    local vehicle = CreateVehicle(model, coords.xyz, coords.w, true, false)
    while not DoesEntityExist(vehicle) do
        Wait(0)
    end
    return vehicle
end
