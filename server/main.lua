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
    local success = MySQL.insert.await('INSERT INTO delivery_orders (business_id, shop_name, units, wholesale_price, buy_price, product, coords, taken_by, warehouse_id, invoice_cost) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        orderData.businessId,
        orderData.shopName,
        math.min(orderData.units, Config.MaxUnits),
        orderData.wholesalePrice,
        orderData.buyPrice,
        orderData.product,
        string.format("%.2f,%.2f,%.2f", coords.x, coords.y, coords.z),
        0, -- taken_by
        0, -- warehouse_id
        0  -- invoice_cost
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
    local success, orders = pcall(function()
        return MySQL.query.await('SELECT id, business_id, shop_name, units, wholesale_price, buy_price, product, coords, taken_by, warehouse_id, invoice_cost FROM delivery_orders WHERE taken_by = 0 OR taken_by = ?', { source })
    end)
    if not success or not orders then
        DebugPrint(string.format("[esx_delivery] Gracz %d: Błąd SQL lub brak wyników: %s", source, tostring(orders)))
        cb({ orders = {}, activeOrder = nil, isValidVehicle = false })
        return
    end
    local availableOrders = {}
    local activeOrder = nil
    DebugPrint(string.format("[esx_delivery] Gracz %d: Pobrano %d zleceń z bazy", source, #orders))
    for i, order in ipairs(orders) do
        DebugPrint(string.format("[esx_delivery] Zlecenie %d: id=%d, shop_name=%s, taken_by=%d", i, order.id, order.shop_name, order.taken_by))
        if order.taken_by == source then
            local warehouse = order.warehouse_id ~= 0 and Config.Warehouses[order.warehouse_id] or nil
            activeOrder = {
                id = order.id,
                shopName = order.shop_name,
                units = order.units,
                product = order.product,
                price = order.buy_price,
                wholesalePrice = order.wholesale_price,
                warehouse = warehouse,
                invoiceCost = order.invoice_cost
            }
        elseif order.taken_by == 0 then
            table.insert(availableOrders, {
                id = order.id,
                shopName = order.shop_name,
                units = order.units,
                product = order.product,
                price = order.buy_price,
                wholesalePrice = order.wholesale_price,
                reward = math.floor(order.units * Config.BaseReward * 0.1)
            })
        end
    end
    local response = { orders = availableOrders, activeOrder = activeOrder, isValidVehicle = false }
    DebugPrint(string.format("[esx_delivery] Gracz %d: Zwracam dane: %s", source, json.encode(response)))
    cb(response)
end)

RegisterServerEvent('esx_delivery:abandonOrder')
AddEventHandler('esx_delivery:abandonOrder', function(orderId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        xPlayer.showNotification(TranslateCap('not_delivery_job'))
        return
    end
    local order = MySQL.single.await('SELECT * FROM delivery_orders WHERE id = ? AND taken_by = ?', { orderId, source })
    if not order then
        xPlayer.showNotification(TranslateCap('invalid_order'))
        return
    end
    local success = MySQL.update.await('UPDATE delivery_orders SET taken_by = 0, warehouse_id = 0, invoice_cost = 0 WHERE id = ?', { orderId })
    if not success then
        xPlayer.showNotification(TranslateCap('server_error'))
        DebugPrint(string.format("[esx_delivery] Błąd SQL przy porzucaniu zlecenia ID %d dla gracza %d", orderId, source))
        return
    end
    xPlayer.showNotification("Zlecenie zostało porzucone")
    DebugPrint(string.format("[esx_delivery] Gracz %d porzucił zlecenie ID %d", source, orderId))
end)

ESX.RegisterServerCallback('esx_delivery:getUnavailableOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        DebugPrint(string.format("[esx_delivery] Gracz %d nie jest dostawcą", source))
        cb({})
        return
    end
    local unavailableOrders = {}
    local orders = MySQL.query.await('SELECT id, business_id, shop_name, units, wholesale_price, buy_price, product, coords, taken_by FROM delivery_orders WHERE taken_by != 0 AND taken_by != ?', { source })
    for _, order in ipairs(orders) do
        table.insert(unavailableOrders, {
            id = order.id,
            shopName = order.shop_name,
            units = order.units,
            product = order.product,
            price = order.buy_price,
            takenBy = order.taken_by
        })
    end
    DebugPrint(string.format("[esx_delivery] Gracz %d: Pobrano %d niedostępnych zleceń", source, #unavailableOrders))
    cb(unavailableOrders)
end)


RegisterServerEvent('esx_delivery:selectWarehouse')
AddEventHandler('esx_delivery:selectWarehouse', function(orderId, warehouseIndex, vehicleValid)
    DebugPrint(string.format("[esx_delivery] Gracz %d: vehicleValid=%s", source, tostring(vehicleValid)))
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= Config.DeliveryJob then
        xPlayer.showNotification(TranslateCap('not_delivery_job'))
        return
    end
    local order = MySQL.single.await('SELECT * FROM delivery_orders WHERE id = ? AND taken_by = 0', { orderId })
    if not order then
        xPlayer.showNotification(TranslateCap('order_unavailable'))
        return
    end
    local warehouse = Config.Warehouses[warehouseIndex]
    if not warehouse then
        xPlayer.showNotification(TranslateCap('invalid_warehouse'))
        return
    end
    if not vehicleValid then
        xPlayer.showNotification(TranslateCap('no_delivery_vehicle'))
        return
    end
    local invoiceCost = math.floor(order.wholesale_price * warehouse.priceMultiplier * order.units)
    local success = MySQL.update.await('UPDATE delivery_orders SET taken_by = ?, warehouse_id = ?, invoice_cost = ? WHERE id = ?', {
        _source, warehouseIndex, invoiceCost, orderId
    })
    if not success then
        xPlayer.showNotification(TranslateCap('server_error'))
        return
    end
    local x, y, z = order.coords:match("([^,]+),([^,]+),([^,]+)")
    if not (x and y and z) then
        xPlayer.showNotification("Błędny format koordynatów zlecenia")
        DebugPrint(string.format("[esx_delivery] Błąd: Nieprawidłowy format coords dla zlecenia ID %d: %s", orderId, tostring(order.coords)))
        return
    end
    local orderData = {
        businessId = order.business_id,
        shopName = order.shop_name,
        units = order.units,
        wholesalePrice = order.wholesale_price,
        buyPrice = order.buy_price,
        product = order.product,
        coords = vector3(tonumber(x), tonumber(y), tonumber(z)),
        warehouse = warehouse,
        invoiceCost = invoiceCost
    }
    TriggerClientEvent('esx_delivery:startDelivery', _source, orderId, orderData)
    DebugPrint(string.format("[esx_delivery] Gracz %d wybrał hurtownię %s dla zlecenia ID %d, koszt faktury: %d", _source, warehouse.name, orderId, invoiceCost))
end)

RegisterServerEvent('esx_delivery:completeOrder')
AddEventHandler('esx_delivery:completeOrder', function(orderId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if not xPlayer then
        DebugPrint(string.format("[esx_delivery] Błąd: Gracz %d nie istnieje", _source))
        return
    end
    local order = MySQL.single.await('SELECT * FROM delivery_orders WHERE id = ? AND taken_by = ?', { orderId, _source })
    if not order then
        xPlayer.showNotification(TranslateCap('invalid_order'))
        DebugPrint(string.format("[esx_delivery] Błąd: Zlecenie ID %d nie istnieje lub nie należy do gracza %d", orderId, _source))
        return
    end
    if not exports.esx_economyreworked:ValidateFrameworkReady(_source, "esx_delivery:completeOrder") then
        xPlayer.showNotification(TranslateCap('server_error'))
        DebugPrint(string.format("[esx_delivery] Błąd: Framework esx_economyreworked niegotowy dla zlecenia ID %d, gracz %d", orderId, _source))
        return
    end
    local profit = order.buy_price - order.invoice_cost
    local success = MySQL.transaction.await({
        { 'UPDATE businesses SET stock = stock + ?, funds = funds - ? WHERE id = ?', { order.units, order.buy_price, order.business_id } },
        { 'INSERT INTO deliveries (business_id, units, cost, type) VALUES (?, ?, ?, ?)', { order.business_id, order.units, order.invoice_cost, 'standard' } },
        { 'DELETE FROM delivery_orders WHERE id = ?', { orderId } }
    })
    if not success then
        xPlayer.showNotification(TranslateCap('server_error'))
        DebugPrint(string.format("[esx_delivery] Błąd SQL przy zakończeniu zlecenia ID %d dla gracza %d", orderId, _source))
        return
    end
    if profit == 0 then
        xPlayer.showNotification(TranslateCap('no_profit'))
        DebugPrint(string.format("[esx_delivery] Zlecenie ID %d zakończone przez gracza %d, zysk: 0", orderId, _source))
    elseif profit < 0 then
        local loss = math.abs(profit)
        if xPlayer.getMoney() >= loss then
            xPlayer.removeMoney(loss, 'Delivery loss')
            xPlayer.showNotification(TranslateCap('loss', ESX.Math.GroupDigits(loss)))
            DebugPrint(string.format("[esx_delivery] Zlecenie ID %d zakończone przez gracza %d, strata: %d", orderId, _source, loss))
        else
            xPlayer.showNotification(TranslateCap('insufficient_funds'))
            DebugPrint(string.format("[esx_delivery] Gracz %d nie ma dość pieniędzy na pokrycie straty %d dla zlecenia ID %d", _source, loss, orderId))
        end
    else
        xPlayer.addMoney(profit, 'Delivery profit')
        xPlayer.showNotification(TranslateCap('delivery_completed', ESX.Math.GroupDigits(profit)))
        DebugPrint(string.format("[esx_delivery] Zlecenie ID %d zakończone przez gracza %d, zysk: %d", orderId, _source, profit))
    end
    exports.esx_economyreworked:UpdateBusinessCache(order.business_id, { stock = order.units, funds = -order.buy_price })
    TriggerClientEvent('esx_shops:refreshBlips', -1)
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
        local success = MySQL.update.await('UPDATE delivery_orders SET taken_by = 0, warehouse_id = 0, invoice_cost = 0 WHERE taken_by = ?', { source })
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