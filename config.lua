Config = {}
Config.Locale = GetConvar('esx:locale', 'pl')
Config.DeliveryJob = 'delivery'
Config.LaptopCoords = vector3(152.21, -3211.67, 5.88)
Config.ReturnPoint = vector3(178.20, -3264.82, 5.64)
Config.TruckModel = 'phantom'
Config.TrailerModel = 'trailers2'
Config.TruckDeposit = 5000
Config.TruckOnlyDeposit = 2500
Config.SpawnTimeout = 300
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
    { name = "Los Santos Central", coords = vector3(216.76, -141.55, 60.65), priceMultiplier = 1.5 },
    { name = "Los Santos Docks", coords = vector3(1115.45, -2383.99, 30.76), priceMultiplier = 1.3 },
    { name = "Route 68 Depot", coords = vector3(555.67, 2672.74, 42.15), priceMultiplier = 1.1 },
    { name = "Sandy Shores Storage", coords = vector3(1732.34, 3709.45, 34.14), priceMultiplier = 1.0 },
    { name = "Paleto Bay Warehouse", coords = vector3(-321.85, 6072.58, 31.49), priceMultiplier = 0.8 }
}
Config.BaseReward = 500
Config.MaxUnits = 300
Config.SpawnRadius = 5.0