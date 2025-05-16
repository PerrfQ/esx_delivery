ESX = exports['es_extended']:getSharedObject()
local DebugServer = true
local activeVehicles = {} -- { [source] = { truck = netId, trailer = netId, depositPaid = timestamp, plate = string } }

local function DebugPrint(...)
    if DebugServer then
        print(...)
    end
end

local function GeneratePlate()
    local chars = '0123456789'
    local plate = 'JOB'
    for i = 1, 4 do
        plate = plate .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return plate
end

local function IsValidDeliveryVehicle(source, vehicle)
    if not vehicle or GetEntityModel(vehicle) ~= GetHashKey(Config.TruckModel) or not activeVehicles[source] then
        DebugPrint(string.format("[esx_delivery] Nieprawidłowy pojazd dla gracza %d: model=%s, activeVehicle=%s", 
            source, vehicle and GetEntityModel(vehicle) or "nil", activeVehicles[source] and "true" or "false"))
        return false
    end
    local plate = GetVehicleNumberPlateText(vehicle) or ""
    plate = string.gsub(plate, "%s+", ""):upper()
    local hasJob = string.match(plate, "JOB") ~= nil
    DebugPrint(string.format("[esx_delivery] Weryfikacja tablicy dla gracza %d: '%s', hasJOB=%s", source, plate, tostring(hasJob)))
    if not hasJob then
        DebugPrint("[esx_delivery] Tablica nie zawiera 'JOB'")
    end
    return hasJob
end

RegisterServerEvent('esx_delivery:registerOrder')
AddEventHandler('esx_delivery:registerOrder', function(orderData)
    if not orderData or not orderData.businessId or not orderData.units or not orderData.shopName or not orderData.product then
        DebugPrint("[esx_delivery] Błąd: Nieprawidłowe dane zlecenia: " .. json.encode(orderData))
        return
    end
    local coords = nil
    for _, config in ipairs(exports.esx_economyreworked:GetConfig().Businesses) do
        if config.businessId == orderData.businessId then
            coords = config.coords
            break
        end
    end
    if not coords then
        DebugPrint("[esx_delivery] Błąd: Brak koordynatów dla biznesu ID " .. orderData.businessId)
        return
    end
    local success = MySQL.insert.await('INSERT INTO delivery_orders (business_id, shop_name, units, wholesale_price, buy_price, product, coords) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        orderData.businessId,
        orderData.shopName,
        math.min(orderData.units, Config.MaxUnits),
        orderData.wholesalePrice,
        orderData.buyPrice,
        orderData.product,
        string.format("%.2f,%.2f,%.2f", coords.x, coords.y, coords.z)
    })
    if success then
        DebugPrint(string.format("[esx_delivery] Zarejestrowano zlecenie dla biznesu ID %d, produkt: %s, jednostki: %d", orderData.businessId, orderData.product, orderData.units))
    else
        DebugPrint("[esx_delivery] Błąd SQL przy rejestracji zlecenia")
    end
end)

RegisterServerEvent('esx_delivery:requestVehicle')
AddEventHandler('esx_delivery:requestVehicle', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        xPlayer.showNotification(TranslateCap('not_delivery_job'))
        return
    end
    if activeVehicles[source] then
        xPlayer.showNotification(TranslateCap('already_has_vehicle'))
        return
    end
    if xPlayer.getMoney() < Config.TruckDeposit then
        xPlayer.showNotification(TranslateCap('not_enough_deposit', ESX.Math.GroupDigits(Config.TruckDeposit)))
        return
    end
    xPlayer.removeMoney(Config.TruckDeposit, 'Truck deposit')
    local plate = GeneratePlate()
    activeVehicles[source] = { depositPaid = os.time(), plate = plate }
    TriggerClientEvent('esx_delivery:spawnVehicle', source, plate)
    DebugPrint(string.format("[esx_delivery] Gracz %d pobrał tira, rejestracja: %s", source, plate))
end)

ESX.RegisterServerCallback('esx_delivery:validateSpawnPoint', function(source, cb, truckIndex, trailerIndex)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob or not activeVehicles[source] then
        cb(false)
        return
    end
    local truckPoint = Config.SpawnPoints.trucks[truckIndex]
    local trailerPoint = Config.SpawnPoints.trailers[trailerIndex]
    cb(truckPoint and trailerPoint)
end)

RegisterServerEvent('esx_delivery:registerVehicles')
AddEventHandler('esx_delivery:registerVehicles', function(truckNetId, trailerNetId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and activeVehicles[source] then
        activeVehicles[source].truck = truckNetId
        activeVehicles[source].trailer = trailerNetId
        DebugPrint(string.format("[esx_delivery] Gracz %d zarejestrował tira (netId: %d) i naczepę (netId: %d)", source, truckNetId, trailerNetId))
    end
end)

ESX.RegisterServerCallback('esx_delivery:hasActiveVehicle', function(source, cb)
    cb(activeVehicles[source] ~= nil)
    DebugPrint(string.format("[esx_delivery] Gracz %d ma aktywny pojazd: %s", source, activeVehicles[source] and "true" or "false"))
end)

ESX.RegisterServerCallback('esx_delivery:getAvailableOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        DebugPrint(string.format("[esx_delivery] Gracz %d nie jest dostawcą", source))
        cb({ orders = {}, activeOrder = nil, isValidVehicle = false })
        return
    end
    local availableOrders = {}
    local activeOrder = nil
    local orders = MySQL.query.await('SELECT id, business_id, shop_name, units, wholesale_price, buy_price, product, coords, taken_by, warehouse_id, invoice_cost FROM delivery_orders WHERE taken_by IS NULL OR taken_by = ?', { source })
    DebugPrint(string.format("[esx_delivery] Gracz %d: Pobrano %d zleceń z bazy", source, #orders))
    for i, order in ipairs(orders) do
        DebugPrint(string.format("[esx_delivery] Zlecenie %d: id=%d, shop_name=%s, taken_by=%s", i, order.id, order.shop_name, tostring(order.taken_by)))
        if order.taken_by == source then
            local warehouse = order.warehouse_id and Config.Warehouses[order.warehouse_id] or nil
            activeOrder = {
                id = order.id,
                shopName = order.shop_name,
                units = order.units,
                product = order.product,
                price = order.buy_price,
                warehouse = warehouse,
                invoiceCost = order.invoice_cost
            }
        elseif not order.taken_by then
            table.insert(availableOrders, {
                id = order.id,
                shopName = order.shop_name,
                units = order.units,
                product = order.product,
                price = order.buy_price,
                reward = math.floor(order.units * Config.BaseReward * 0.1)
            })
        end
    end
    DebugPrint(string.format("[esx_delivery] Gracz %d: Dostępnych zleceń: %d, aktywne zlecenie: %s", source, #availableOrders, activeOrder and tostring(activeOrder.id) or "brak"))
    cb({ orders = availableOrders, activeOrder = activeOrder, isValidVehicle = false })
end)

RegisterServerEvent('esx_delivery:selectWarehouse')
AddEventHandler('esx_delivery:selectWarehouse', function(orderId, warehouseIndex)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        xPlayer.showNotification(TranslateCap('not_delivery_job'))
        return
    end
    local order = MySQL.single.await('SELECT * FROM delivery_orders WHERE id = ? AND taken_by IS NULL', { orderId })
    if not order then
        xPlayer.showNotification(TranslateCap('order_unavailable'))
        return
    end
    local warehouse = Config.Warehouses[warehouseIndex]
    if not warehouse then
        xPlayer.showNotification(TranslateCap('invalid_warehouse'))
        return
    end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if not IsValidDeliveryVehicle(source, vehicle) then
        xPlayer.showNotification(TranslateCap('no_delivery_vehicle'))
        return
    end
    local invoiceCost = math.floor(order.wholesale_price * warehouse.priceMultiplier * order.units)
    local success = MySQL.update.await('UPDATE delivery_orders SET taken_by = ?, warehouse_id = ?, invoice_cost = ? WHERE id = ?', {
        source, warehouseIndex, invoiceCost, orderId
    })
    if not success then
        xPlayer.showNotification(TranslateCap('server_error'))
        return
    end
    local orderData = {
        businessId = order.business_id,
        shopName = order.shop_name,
        units = order.units,
        wholesalePrice = order.wholesale_price,
        buyPrice = order.buy_price,
        product = order.product,
        coords = vector3(table.unpack({order.coords:match("([^,]+),([^,]+),([^,]+)")})),
        warehouse = warehouse,
        invoiceCost = invoiceCost
    }
    TriggerClientEvent('esx_delivery:startDelivery', source, orderId, orderData)
    DebugPrint(string.format("[esx_delivery] Gracz %d wybrał hurtownię %s dla zlecenia ID %d, koszt faktury: %d", source, warehouse.name, orderId, invoiceCost))
end)

RegisterServerEvent('esx_delivery:completeOrder')
AddEventHandler('esx_delivery:completeOrder', function(orderId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local order = MySQL.single.await('SELECT * FROM delivery_orders WHERE id = ? AND taken_by = ?', { orderId, source })
    if not xPlayer or not order then
        xPlayer.showNotification(TranslateCap('invalid_order'))
        return
    end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if not IsValidDeliveryVehicle(source, vehicle) then
        xPlayer.showNotification(TranslateCap('no_delivery_vehicle'))
        return
    end
    local trailer = GetVehicleTrailerVehicle(vehicle)
    if not trailer or GetEntityModel(trailer) ~= GetHashKey(Config.TrailerModel) then
        xPlayer.showNotification(TranslateCap('no_trailer'))
        return
    end
    local revenue = order.buy_price * order.units
    local profit = revenue - order.invoice_cost
    local success = MySQL.transaction.await({
        { 'UPDATE businesses SET stock = stock + ?, funds = funds - ? WHERE id = ?', { order.units, revenue, order.business_id } },
        { 'INSERT INTO deliveries (business_id, units, cost, type) VALUES (?, ?, ?, ?)', { order.business_id, order.units, order.invoice_cost, 'standard' } },
        { 'DELETE FROM delivery_orders WHERE id = ?', { orderId } }
    })
    if not success then
        xPlayer.showNotification(TranslateCap('server_error'))
        DebugPrint(string.format("[esx_delivery] Błąd SQL przy zakończeniu zlecenia ID %d", orderId))
        return
    end
    xPlayer.addMoney(profit, 'Delivery profit')
    xPlayer.showNotification(TranslateCap('delivery_completed', ESX.Math.GroupDigits(profit)))
    exports.esx_economyreworked:UpdateBusinessCache(order.business_id, { stock = businessCache[order.business_id].stock + order.units, funds = businessCache[order.business_id].funds - revenue })
    exports.esx_economyreworked:UpdateBusinessDetails(-1, order.business_id)
    DebugPrint(string.format("[esx_delivery] Zlecenie ID %d zakończone przez gracza %d, zysk: %d", orderId, source, profit))
end)

RegisterServerEvent('esx_delivery:returnVehicle')
AddEventHandler('esx_delivery:returnVehicle', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not activeVehicles[source] then
        xPlayer.showNotification(TranslateCap('no_vehicle'))
        return
    end
    local coords = GetEntityCoords(GetPlayerPed(source))
    if #(coords - Config.ReturnPoint) > 10.0 then
        xPlayer.showNotification(TranslateCap('not_at_return_point'))
        return
    end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if not IsValidDeliveryVehicle(source, vehicle) then
        xPlayer.showNotification(TranslateCap('no_delivery_vehicle'))
        return
    end
    local trailer = GetVehicleTrailerVehicle(vehicle)
    local deposit = trailer and GetEntityModel(trailer) == GetHashKey(Config.TrailerModel) and Config.TruckDeposit or Config.TruckOnlyDeposit
    for _, netId in pairs(activeVehicles[source]) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    xPlayer.addMoney(deposit, 'Truck deposit refund')
    xPlayer.showNotification(TranslateCap('vehicle_returned', ESX.Math.GroupDigits(deposit)))
    activeVehicles[source] = nil
    TriggerClientEvent('esx_delivery:vehicleReturned', source)
    DebugPrint(string.format("[esx_delivery] Gracz %d zwrócił tira, kaucja zwrócona: %d", source, deposit))
end)

AddEventHandler('playerDropped', function(source)
    if activeVehicles[source] then
        for _, netId in pairs(activeVehicles[source]) do
            local entity = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        activeVehicles[source] = nil
    end
    local hasOrders = MySQL.single.await('SELECT 1 FROM delivery_orders WHERE taken_by = ?', { source })
    if hasOrders then
        local success = MySQL.update.await('UPDATE delivery_orders SET taken_by = NULL, warehouse_id = NULL, invoice_cost = NULL WHERE taken_by = ?', { source })
        if success then
            DebugPrint(string.format("[esx_delivery] Zlecenia gracza %d wróciły na tablicę po rozłączeniu", source))
        end
    end
end)

CreateThread(function()
    while true do
        for source, vehicles in pairs(activeVehicles) do
            if vehicles.depositPaid + Config.SpawnTimeout <= os.time() then
                for _, netId in pairs(vehicles) do
                    local entity = NetworkGetEntityFromNetworkId(netId)
                    if DoesEntityExist(entity) then
                        DeleteEntity(entity)
                    end
                end
                activeVehicles[source] = nil
                DebugPrint(string.format("[esx_delivery] Pojazdy gracza %d usunięte z powodu timeoutu", source))
            end
        end
        Wait(60000)
    end
end)