Config = {}
Config.Locale = GetConvar('esx:locale', 'en')
Config.DeliveryJob = 'delivery'
Config.LaptopCoords = vector3(152.21, -3211.67, 5.88)
Config.ReturnPoint = vector3(178.20, -3264.82, 5.64)
Config.TruckModel = 'phantom'
Config.TrailerModel = 'trailers2'
Config.TruckDeposit = 5000
Config.TruckOnlyDeposit = 2500
Config.SpawnTimeout = 300
Config.DefaultWholesalePrice = 50 -- Domyślna cena za 1 zasób w warehouse_catalog

Config.SpawnPoints = {
    trucks = {
        { coords = vector3(165.68, -3217.28, 5.96), heading = 269.27 },
        { coords = vector3(165.89, -3223.13, 5.95), heading = 269.48 },
        { coords = vector3(166.49, -3230.96, 5.95), heading = 269.79 },
        { coords = vector3(166.75, -3236.25, 5.95), heading = 270.83 }
    },
    trailers = {
        { coords = vector3(164.63, -3181.17, 5.91), heading = 270.17 },
        { coords = vector3(164.64, -3176.72, 5.91), heading = 270.23 },
        { coords = vector3(164.62, -3172.46, 5.91), heading = 270.23 },
        { coords = vector3(164.97, -3163.13, 5.90), heading = 270.65 }
    }
}

Config.Warehouses = {
    {
        name = "Cypress Warehouse",
        coords = vector3(1013.32, -2525.47, 28.31),
        priceMultiplier = 2.0
    },
    -- Placeholder dla innych hurtowni, do uzupełnienia przez server ownerów
    {
        name = "Bilgeco Shipping Warehouse",
        coords = vector3(-1028.56, -2218.05, 8.98), -- Przykładowe koordynaty
        priceMultiplier = 1.5
    },
    {
        name = "Sandy Shores",
        coords = vector3(1721.0, 3313.0, 41.22), -- Przykładowe koordynaty
        priceMultiplier = 1.0
    }
}

Config.BaseReward = 500
Config.MaxUnits = 300
Config.SpawnRadius = 5.0