ESX = exports['es_extended']:getSharedObject()
local DebugClient = true
local currentOrder = nil
local truckBlip = nil
local trailerBlip = nil
local warehouseBlip = nil
local shopBlip = nil

local function DebugPrint(...)
    if DebugClient then
        print(...)
    end
end

CreateThread(function()
    local returnBlip = nil
    local companyBlip = nil
    local hasVehicle = false
    local warehouseBlips = nil

    -- Inicjalne sprawdzenie pojazdu
    if ESX.PlayerData.job and ESX.PlayerData.job.name == Config.DeliveryJob then
        ESX.TriggerServerCallback('esx_delivery:hasActiveVehicle', function(active)
            hasVehicle = active
            DebugPrint(string.format("[esx_delivery] Inicjalny stan pojazdu: %s", tostring(hasVehicle)))
        end)
    end

    while true do
        local sleep = 1000
        if ESX.PlayerData.job and ESX.PlayerData.job.name == Config.DeliveryJob then
            sleep = 0
            HandleLaptopMarker()
            HandleReturnPoint()
            UpdateWarehouseBlips()
            if not companyBlip then
                companyBlip = AddBlipForCoord(Config.LaptopCoords.x, Config.LaptopCoords.y, Config.LaptopCoords.z)
                SetBlipSprite(companyBlip, 477)
                SetBlipColour(companyBlip, 2)
                SetBlipAsShortRange(companyBlip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(TranslateCap('company_name'))
                EndTextCommandSetBlipName(companyBlip)
                DebugPrint("[esx_delivery] Dodano blip firmy logistycznej")
            end
            if hasVehicle and not returnBlip then
                returnBlip = AddBlipForCoord(Config.ReturnPoint.x, Config.ReturnPoint.y, Config.ReturnPoint.z)
                SetBlipSprite(returnBlip, 478)
                SetBlipColour(returnBlip, 2)
                SetBlipAsShortRange(returnBlip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(TranslateCap('return_vehicle'))
                EndTextCommandSetBlipName(returnBlip)
                DebugPrint("[esx_delivery] Dodano blip punktu zwrotu")
            elseif not hasVehicle and returnBlip then
                RemoveBlip(returnBlip)
                returnBlip = nil
                DebugPrint("[esx_delivery] Usunięto blip punktu zwrotu")
            end
        elseif companyBlip then
            RemoveBlip(companyBlip)
            companyBlip = nil
            if returnBlip then
                RemoveBlip(returnBlip)
                returnBlip = nil
            end
            if warehouseBlips then
                for _, blip in ipairs(warehouseBlips) do
                    RemoveBlip(blip)
                end
                warehouseBlips = nil
            end
            hasVehicle = false
            DebugPrint("[esx_delivery] Usunięto blipy firmy, zwrotu i hurtowni po zmianie pracy")
        end
        Wait(sleep)
    end
end)

-- Funkcja do zarządzania blipami hurtowni
function UpdateWarehouseBlips()
    if ESX.PlayerData.job and ESX.PlayerData.job.name == Config.DeliveryJob then
        if not warehouseBlips then
            warehouseBlips = {}
            AddTextEntry("BLIP_CAT_12", TranslateCap('warehouse_category')) -- Niestandardowa kategoria
            for i, warehouse in ipairs(Config.Warehouses) do
                local blip = AddBlipForCoord(warehouse.coords.x, warehouse.coords.y, warehouse.coords.z)
                SetBlipSprite(blip, 473)
                SetBlipColour(blip, 2)
                SetBlipAsShortRange(blip, true)
                SetBlipCategory(blip, 12) -- Grupowanie w kategorii "Hurtownia"
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(warehouse.name) -- Bez prefiksu "Hurtownia:"
                EndTextCommandSetBlipName(blip)
                warehouseBlips[i] = blip
                DebugPrint(string.format("[esx_delivery] Dodano blip dla hurtowni: %s", warehouse.name))
            end
        end
    elseif warehouseBlips then
        for _, blip in ipairs(warehouseBlips) do
            RemoveBlip(blip)
        end
        warehouseBlips = nil
        DebugPrint("[esx_delivery] Usunięto blipy hurtowni po zmianie pracy")
    end
end


local function IsValidDeliveryVehicle(vehicle)
    if not vehicle or GetEntityModel(vehicle) ~= GetHashKey(Config.TruckModel) then
        DebugPrint(string.format("[esx_delivery] Nieprawidłowy pojazd: model=%s", vehicle and GetEntityModel(vehicle) or "nil"))
        return false
    end
    local plate = GetVehicleNumberPlateText(vehicle) or ""
    plate = string.gsub(plate, "%s+", ""):upper()
    local hasJob = string.match(plate, "JOB") ~= nil
    DebugPrint(string.format("[esx_delivery] Weryfikacja tablicy: '%s', hasJOB=%s", plate, tostring(hasJob)))
    if not hasJob then
        DebugPrint("[esx_delivery] Tablica nie zawiera 'JOB'")
    end
    return hasJob
end


function HandleLaptopMarker()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local distance = #(coords - Config.LaptopCoords)
    if distance < 10.0 then
        DrawMarker(29, Config.LaptopCoords.x, Config.LaptopCoords.y, Config.LaptopCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 50, 200, 50, 100, false, true, 2, nil, nil, false)
        if distance < 2.0 then
            ESX.ShowHelpNotification(TranslateCap('press_to_access'))
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('esx_delivery:requestVehicle')
            end
        end
    end
end

function HandleReturnPoint()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local distance = #(coords - Config.ReturnPoint)
    if distance < 10.0 then
        DrawMarker(29, Config.ReturnPoint.x, Config.ReturnPoint.y, Config.ReturnPoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 50, 200, 50, 100, false, true, 2, nil, nil, false)
        if distance < 2.0 then
            ESX.ShowHelpNotification(TranslateCap('press_to_return'))
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('esx_delivery:returnVehicle')
            end
        end
    end
end

RegisterKeyMapping('deliverymenu', TranslateCap('delivery_menu'), 'keyboard', 'F6')
RegisterCommand('deliverymenu', function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if ESX.PlayerData.job.name ~= Config.DeliveryJob then
        ESX.ShowNotification(TranslateCap('not_delivery_job'))
        return
    end
    local retval, trailer = GetVehicleTrailerVehicle(vehicle)
    DebugPrint(string.format("[esx_delivery] Trailer check for menu: retval=%s, trailer=%d, model=%d, expected=%d", tostring(retval), trailer, GetEntityModel(trailer), GetHashKey(Config.TrailerModel)))
    OpenDeliveryMenu()
end, false)




function OpenDeliveryMenu()
    ESX.TriggerServerCallback('esx_delivery:getAvailableOrders', function(data)
        DebugPrint(string.format("[esx_delivery] Otrzymano dane z getAvailableOrders: %s", json.encode(data)))
        local savedOrders = data.orders or {}
        local savedActiveOrder = data.activeOrder
        DebugPrint(string.format("[esx_delivery] Zapisano orders: %s, activeOrder: %s", json.encode(savedOrders), json.encode(savedActiveOrder)))
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        local isValidVehicle = IsValidDeliveryVehicle(vehicle)
        local elements = {
            { label = TranslateCap('manage_orders'), value = 'manage_orders' }
        }
        if isValidVehicle then
            table.insert(elements, { label = TranslateCap('warehouses'), value = 'warehouses' })
        end
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'delivery_menu', {
            title = TranslateCap('delivery_menu_title'),
            align = 'right',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'manage_orders' then
                local orderElements = {}
                if savedActiveOrder ~= nil then
                    DebugPrint(string.format("[esx_delivery] Wyświetlam aktywne zlecenie: id=%d, shopName=%s", savedActiveOrder.id, savedActiveOrder.shopName))
                    table.insert(orderElements, {
                        label = string.format("Aktywne zlecenie: %s (%d jednostek, $%s)", savedActiveOrder.shopName, savedActiveOrder.units, ESX.Math.GroupDigits(savedActiveOrder.price)),
                        unselectable = true
                    })
                    table.insert(orderElements, {
                        label = TranslateCap('abandon_order'),
                        value = 'abandon_order'
                    })
                else
                    DebugPrint("[esx_delivery] Brak aktywnego zlecenia")
                    table.insert(orderElements, { label = TranslateCap('no_active_order_label'), unselectable = true })
                end
                table.insert(orderElements, {
                    label = TranslateCap('available_orders_label'), value = 'available_orders'
                })
                table.insert(orderElements, {
                    label = TranslateCap('unavailable_orders_label'), value = 'unavailable_orders'
                })
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'manage_orders', {
                    title = "Zarządzanie zleceniami",
                    align = 'right',
                    elements = orderElements
                }, function(data2, menu2)
                    if data2.current.value == 'available_orders' then
                        local availableElements = {}
                        DebugPrint(string.format("[esx_delivery] Używam zapisanych orders: %s", json.encode(savedOrders)))
                        if #savedOrders == 0 then
                            table.insert(availableElements, { label = TranslateCap('no_orders'), value = 'none' })
                        else
                            DebugPrint(string.format("[esx_delivery] Wyświetlam %d dostępnych zleceń", #savedOrders))
                            for i, order in ipairs(savedOrders) do
                                DebugPrint(string.format("[esx_delivery] Zlecenie %d: id=%d, shopName=%s, product=%s, units=%d, price=%d", i, order.id, order.shopName, order.product, order.units, order.price))
                                table.insert(availableElements, {
                                    label = TranslateCap('order_entry', order.shopName, order.product, order.units, ESX.Math.GroupDigits(order.price)),
                                    value = order.id
                                })
                            end
                        end
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'available_orders', {
                            title = "Dostępne zlecenia",
                            align = 'right',
                            elements = availableElements
                        }, function(data3, menu3)
                            if type(data3.current.value) == 'number' then
                                if not isValidVehicle then
                                    ESX.ShowNotification(TranslateCap('no_delivery_vehicle'))
                                    return
                                end
                                local orderIndex = nil
                                for i, order in ipairs(savedOrders) do
                                    if order.id == data3.current.value then
                                        orderIndex = i
                                        break
                                    end
                                end
                                if not orderIndex then
                                    ESX.ShowNotification(TranslateCap('order_unavailable'))
                                    return
                                end
                                local warehouseElements = {}
                                for i, warehouse in ipairs(Config.Warehouses) do
                                    local cost = math.floor((savedOrders[orderIndex].wholesalePrice or Config.DefaultWholesalePrice) * warehouse.priceMultiplier * savedOrders[orderIndex].units)
                                    table.insert(warehouseElements, {
                                        label = string.format("%s ($%s)", warehouse.name, ESX.Math.GroupDigits(cost)),
                                        value = i
                                    })
                                end
                                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'warehouse_menu', {
                                    title = TranslateCap('select_warehouse'),
                                    align = 'right',
                                    elements = warehouseElements
                                }, function(data4, menu4)
                                    TriggerServerEvent('esx_delivery:selectWarehouse', data3.current.value, data4.current.value, isValidVehicle)
                                    menu4.close()
                                    menu3.close()
                                    menu2.close()
                                    menu.close()
                                end, function(data4, menu4)
                                    menu4.close()
                                end)
                            end
                        end, function(data3, menu3)
                            menu3.close()
                        end)
                    elseif data2.current.value == 'unavailable_orders' then
                        ESX.TriggerServerCallback('esx_delivery:getUnavailableOrders', function(unavailableOrders)
                            local unavailableElements = {}
                            if #unavailableOrders == 0 then
                                table.insert(unavailableElements, { label = TranslateCap('no_unavailable_orders'), value = 'none' })
                            else
                                for _, order in ipairs(unavailableOrders) do
                                    table.insert(unavailableElements, {
                                        label = string.format("%s: %s (%d jednostek, $%s, wzięte przez gracza %d)", order.shopName, order.product, order.units, ESX.Math.GroupDigits(order.price), order.takenBy),
                                        value = 'none'
                                    })
                                end
                            end
                            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'unavailable_orders', {
                                title = "Niedostępne zlecenia",
                                align = 'right',
                                elements = unavailableElements
                            }, function(data3, menu3)
                                menu3.close()
                            end, function(data3, menu3)
                                menu3.close()
                            end)
                        end)
                    elseif data2.current.value == 'abandon_order' then
                        if savedActiveOrder ~= nil then
                            TriggerServerEvent('esx_delivery:abandonOrder', savedActiveOrder.id)
                            currentOrder = nil
                            menu2.close()
                            menu.close()
                        end
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            elseif data.current.value == 'warehouses' then
                local catalogElements = {}
                if warehouseBlip then
                    table.insert(catalogElements, {
                        label = TranslateCap('remove_warehouse'),
                        value = 'remove_warehouse'
                    })
                end
                for i, warehouse in ipairs(Config.Warehouses) do
                    table.insert(catalogElements, {
                        label = string.format("%s ($%s/1 zasób)", warehouse.name, ESX.Math.GroupDigits(Config.DefaultWholesalePrice * warehouse.priceMultiplier)),
                        value = i
                    })
                end
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'warehouse_catalog', {
                    title = TranslateCap('warehouse_catalog'),
                    align = 'right',
                    elements = catalogElements
                }, function(data2, menu2)
                    if data2.current.value == 'remove_warehouse' then
                        if warehouseBlip then
                            RemoveBlip(warehouseBlip)
                            warehouseBlip = nil
                            ESX.ShowNotification(TranslateCap('warehouse_blip_removed'))
                            DebugPrint("[esx_delivery] Usunięto blip hurtowni z menu")
                        end
                        menu2.close()
                    elseif type(data2.current.value) == 'number' then
                        TriggerEvent('esx_delivery:setWarehouseRoute', Config.Warehouses[data2.current.value])
                        menu2.close()
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            end
        end, function(data, menu)
            menu.close()
        end)
    end)
end



RegisterNetEvent('esx_delivery:spawnVehicle')
AddEventHandler('esx_delivery:spawnVehicle', function(plate)
    local truckSpawn, trailerSpawn, truckIndex, trailerIndex
    for i, point in ipairs(Config.SpawnPoints.trucks) do
        if #ESX.Game.GetVehiclesInArea(point.coords, Config.SpawnRadius) == 0 and #ESX.Game.GetPlayersInArea(point.coords, Config.SpawnRadius) == 0 then
            truckSpawn = point
            truckIndex = i
            break
        end
    end
    for i, point in ipairs(Config.SpawnPoints.trailers) do
        if #ESX.Game.GetVehiclesInArea(point.coords, Config.SpawnRadius) == 0 and #ESX.Game.GetPlayersInArea(point.coords, Config.SpawnRadius) == 0 then
            trailerSpawn = point
            trailerIndex = i
            break
        end
    end
    if not truckSpawn or not trailerSpawn then
        ESX.ShowNotification(TranslateCap('no_spawn_point'))
        return
    end
    ESX.TriggerServerCallback('esx_delivery:validateSpawnPoint', function(isValid)
        if not isValid then
            ESX.ShowNotification(TranslateCap('no_spawn_point'))
            return
        end
        ESX.Game.SpawnVehicle(Config.TruckModel, truckSpawn.coords, truckSpawn.heading, function(truck)
            SetVehicleDoorsLocked(truck, 1)
            SetVehicleNumberPlateText(truck, plate)
            truckBlip = AddBlipForEntity(truck)
            SetBlipSprite(truckBlip, 477)
            SetBlipColour(truckBlip, 2)
            SetBlipAsShortRange(truckBlip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(TranslateCap('delivery_truck'))
            EndTextCommandSetBlipName(truckBlip)
            ESX.Game.SpawnVehicle(Config.TrailerModel, trailerSpawn.coords, trailerSpawn.heading, function(trailer)
                SetVehicleDoorsLocked(trailer, 1)
                trailerBlip = AddBlipForEntity(trailer)
                SetBlipSprite(trailerBlip, 479)
                SetBlipColour(trailerBlip, 2)
                SetBlipAsShortRange(trailerBlip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(TranslateCap('delivery_trailer'))
                EndTextCommandSetBlipName(trailerBlip)
                TriggerServerEvent('esx_delivery:registerVehicles', NetworkGetNetworkIdFromEntity(truck), NetworkGetNetworkIdFromEntity(trailer))
                TriggerEvent('esx_delivery:updateVehicleState', true)
            end)
        end)
    end, truckIndex, trailerIndex)
end)


RegisterNetEvent('esx_delivery:startDelivery')
AddEventHandler('esx_delivery:startDelivery', function(orderId, order)
    if currentOrder then
        ESX.ShowNotification(TranslateCap('already_in_delivery'))
        return
    end
    currentOrder = {
        id = orderId,
        coords = order.coords,
        warehouseCoords = order.warehouse.coords,
        invoiceCost = order.invoiceCost,
        loaded = false,
        shopName = order.shopName,
        warehouseName = order.warehouse.name
    }
    warehouseBlip = AddBlipForCoord(order.warehouse.coords.x, order.warehouse.coords.y, order.warehouse.coords.z)
    SetBlipSprite(warehouseBlip, 473)
    SetBlipColour(warehouseBlip, 2)
    SetBlipAsShortRange(warehouseBlip, false)
    SetNewWaypoint(order.warehouse.coords.x, order.warehouse.coords.y)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('warehouse', order.warehouse.name))
    EndTextCommandSetBlipName(warehouseBlip)
    ESX.ShowNotification(TranslateCap('delivery_started', order.shopName))
    DebugPrint(string.format("[esx_delivery] Rozpoczęto dostawę do %s, waypoint na hurtowni %s", order.shopName, order.warehouse.name))
    HandleDelivery()
end)


RegisterNetEvent('esx_delivery:setWarehouseRoute')
AddEventHandler('esx_delivery:setWarehouseRoute', function(warehouse)
    if warehouseBlip then
        RemoveBlip(warehouseBlip)
    end
    warehouseBlip = AddBlipForCoord(warehouse.coords.x, warehouse.coords.y, warehouse.coords.z)
    SetBlipSprite(warehouseBlip, 473)
    SetBlipColour(warehouseBlip, 2)
    SetBlipAsShortRange(warehouseBlip, false)
    SetNewWaypoint(warehouse.coords.x, warehouse.coords.y)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('warehouse', warehouse.name))
    EndTextCommandSetBlipName(warehouseBlip)
    ESX.ShowNotification(TranslateCap('warehouse_selected', warehouse.name))
    DebugPrint(string.format("[esx_delivery] Ustawiono waypoint do hurtowni: %s (%s)", warehouse.name, tostring(warehouse.coords)))
end)


function HandleDelivery()
    CreateThread(function()
        while currentOrder do
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            if trailerBlip then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                if vehicle and GetEntityModel(vehicle) == GetHashKey(Config.TruckModel) then
                    local retval, trailer = GetVehicleTrailerVehicle(vehicle)
                    DebugPrint(string.format("[esx_delivery] Trailer check for blip: retval=%s, trailer=%d, model=%d, expected=%d", tostring(retval), trailer, GetEntityModel(trailer), GetHashKey(Config.TrailerModel)))
                    if retval and GetEntityModel(trailer) == GetHashKey(Config.TrailerModel) then
                        RemoveBlip(trailerBlip)
                        trailerBlip = nil
                        DebugPrint("[esx_delivery] Blip naczepy usunięty po podłączeniu")
                    end
                end
            end
            if not currentOrder.loaded then
                local warehouseDistance = #(coords - currentOrder.warehouseCoords)
                if warehouseDistance < 100.0 then
                    DrawMarker(1, currentOrder.warehouseCoords.x, currentOrder.warehouseCoords.y, currentOrder.warehouseCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 2.0, 50, 200, 50, 100, false, true, 2, nil, nil, false)
                    if warehouseDistance < 5.0 then
                        ESX.ShowHelpNotification(TranslateCap('press_to_load'))
                        if IsControlJustReleased(0, 38) then
                            local vehicle = GetVehiclePedIsIn(playerPed, false)
                            if not IsValidDeliveryVehicle(vehicle) then
                                ESX.ShowNotification(TranslateCap('no_delivery_vehicle'))
                                return
                            end
                            local retval, trailer = GetVehicleTrailerVehicle(vehicle)
                            DebugPrint(string.format("[esx_delivery] Trailer check at warehouse: retval=%s, trailer=%d, model=%d, expected=%d", tostring(retval), trailer, GetEntityModel(trailer), GetHashKey(Config.TrailerModel)))
                            if not retval or GetEntityModel(trailer) ~= GetHashKey(Config.TrailerModel) then
                                ESX.ShowNotification(TranslateCap('no_trailer'))
                                currentOrder.loaded = false
                                return
                            end
                            currentOrder.loaded = true
                            RemoveBlip(warehouseBlip)
                            warehouseBlip = nil
                            shopBlip = AddBlipForCoord(currentOrder.coords.x, currentOrder.coords.y, currentOrder.coords.z)
                            SetBlipSprite(shopBlip, 52)
                            SetBlipColour(shopBlip, 2)
                            SetBlipAsShortRange(shopBlip, false)
                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentSubstringPlayerName(TranslateCap('shop', currentOrder.shopName))
                            EndTextCommandSetBlipName(shopBlip)
                            SetNewWaypoint(currentOrder.coords.x, currentOrder.coords.y)
                            ESX.ShowNotification(TranslateCap('products_loaded', currentOrder.warehouseName, ESX.Math.GroupDigits(currentOrder.invoiceCost)))
                            DebugPrint(string.format("[esx_delivery] Gracz załadował towary w hurtowni: %s dla zlecenia ID %d", currentOrder.warehouseName, currentOrder.id))
                        end
                    end
                end
            elseif currentOrder.loaded then
                local shopDistance = #(coords - currentOrder.coords)
                print(shopDistance)
                if shopDistance < 200.0 then
                    DrawMarker(29, currentOrder.coords.x, currentOrder.coords.y, currentOrder.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 50, 200, 50, 100, false, true, 2, nil, nil, false)
                    if shopDistance < 30.0 then
                        ESX.ShowHelpNotification(TranslateCap('press_to_deliver'))
                        if IsControlJustReleased(0, 38) then
                            local vehicle = GetVehiclePedIsIn(playerPed, false)
                            if not IsValidDeliveryVehicle(vehicle) then
                                ESX.ShowNotification(TranslateCap('no_delivery_vehicle'))
                                return
                            end
                            local retval, trailer = GetVehicleTrailerVehicle(vehicle)
                            DebugPrint(string.format("[esx_delivery] Trailer check at shop: retval=%s, trailer=%d, model=%d, expected=%d", tostring(retval), trailer, GetEntityModel(trailer), GetHashKey(Config.TrailerModel)))
                            if not retval or GetEntityModel(trailer) ~= GetHashKey(Config.TrailerModel) then
                                ESX.ShowNotification(TranslateCap('no_trailer'))
                                return
                            end
                            TriggerServerEvent('esx_delivery:completeOrder', currentOrder.id)
                            RemoveBlip(shopBlip)
                            shopBlip = nil
                            DebugPrint(string.format("[esx_delivery] Gracz dostarczył towary do sklepu dla zlecenia ID %d", currentOrder and currentOrder.id or "unknown"))

                            currentOrder = nil    
                        end
                    end
                end
            end
            Wait(0)
        end
        RemoveBlip(truckBlip)
        truckBlip = nil
        if trailerBlip then
            RemoveBlip(trailerBlip)
            trailerBlip = nil
        end
        if warehouseBlip then
            RemoveBlip(warehouseBlip)
            warehouseBlip = nil
        end
        if shopBlip then
            RemoveBlip(shopBlip)
            shopBlip = nil
        end
    end)
end

RegisterNetEvent('esx_delivery:vehicleReturned')
AddEventHandler('esx_delivery:vehicleReturned', function()
    TriggerEvent('esx_delivery:updateVehicleState', false)
    DebugPrint("[esx_delivery] Otrzymano powiadomienie o zwrocie pojazdu")
end)

RegisterNetEvent('esx_delivery:updateVehicleState')
AddEventHandler('esx_delivery:updateVehicleState', function(state)
    hasVehicle = state
    DebugPrint(string.format("[esx_delivery] Zaktualizowano stan pojazdu: %s", tostring(hasVehicle)))
end)

AddEventHandler('esx:setJob', function(job)
    if job.name ~= Config.DeliveryJob and currentOrder then
        RemoveBlip(truckBlip)
        truckBlip = nil
        if trailerBlip then
            RemoveBlip(trailerBlip)
            trailerBlip = nil
        end
        if warehouseBlip then
            RemoveBlip(warehouseBlip)
            warehouseBlip = nil
        end
        if shopBlip then
            RemoveBlip(shopBlip)
            shopBlip = nil
        end
        currentOrder = nil
        ESX.ShowNotification(TranslateCap('delivery_cancelled'))
    end
end)