local QBCore = exports['qbx-core']:GetCoreObject()


-- Functions

local function HasCitizenIdHasKey(CitizenId, Traphouse)
    local retval = false
    if Config.TrapHouses[Traphouse].keyholders ~= nil and next(Config.TrapHouses[Traphouse].keyholders) ~= nil then
        for _, data in pairs(Config.TrapHouses[Traphouse].keyholders) do
            if data.citizenid == CitizenId then
                retval = true
                break
            end
        end
    end
    return retval
end

local function HasTraphouseAndOwner(CitizenId)
    local retval = nil
    for Traphouse,_ in pairs(Config.TrapHouses) do
        for _, v in pairs(Config.TrapHouses[Traphouse].keyholders) do
            if v.citizenid == CitizenId then
                if v.owner then
                    retval = Traphouse
                end
            end
        end
    end
    return retval
end

local function HasTraphouseAndOwner(CitizenId)
    local retval = nil
    for Traphouse,_ in pairs(Config.TrapHouses) do
        for _, v in pairs(Config.TrapHouses[Traphouse].keyholders) do
            if v.citizenid == CitizenId then
                if v.owner then
                    retval = Traphouse
                end
            end
        end
    end
    return retval
end

--Creating stash for each traphouse 
local function RegisterStash(stashName, slots)
    local label = 'Trap House'
    local weight = 100000
    exports.ox_inventory:RegisterStash(stashName, label, slots, weight)
end

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        for i, trapHouse in pairs(Config.TrapHouses) do
            local stashName = trapHouse.inventory -- Generate a unique stash name for each trap house
            RegisterStash(stashName, trapHouse.slots)
        end
    end
end)


local function ProcessTrapHouses()
    for i = 1, #Config.TrapHouses do
        local trapHouse = Config.TrapHouses[i]
        local stashName = trapHouse.inventory --getting StashName from Config 
        for itemName, itemData in pairs(Config.AllowedItems) do
            local count = exports.ox_inventory:GetItemCount(stashName, itemName) --Checking Wheather Config.AllowedItems is present in the inventory 
            if count >= 1 then
                exports.ox_inventory:RemoveItem(stashName, itemName, count)
                trapHouse.money = trapHouse.money + (itemData.reward * count) -- Adding money to the trapHouse
                TriggerClientEvent('qb-traphouse:client:SyncData', -1, i, trapHouse)
            end
        end
    end

    -- Call the function again after configured time
    SetTimeout(60000*Config.Sellingtime, ProcessTrapHouses)
end

-- Start the loop by calling the function initially
ProcessTrapHouses()

-- events

RegisterServerEvent('qb-traphouse:server:TakeoverHouse', function(Traphouse)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid

    if not HasCitizenIdHasKey(CitizenId, Traphouse) then
        if Player.Functions.RemoveMoney('cash', Config.TakeoverPrice) then
            TriggerClientEvent('qb-traphouse:client:TakeoverHouse', src, Traphouse)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
        end
    end
end)


RegisterServerEvent('qb-traphouse:server:AddHouseKeyHolder', function(CitizenId, TraphouseId, IsOwner)
    local src = source

    if Config.TrapHouses[TraphouseId] ~= nil then
        if IsOwner then
            Config.TrapHouses[TraphouseId].keyholders = {}
            Config.TrapHouses[TraphouseId].pincode = math.random(1111, 4444)
        end

        if Config.TrapHouses[TraphouseId].keyholders == nil then
            Config.TrapHouses[TraphouseId].keyholders[#Config.TrapHouses[TraphouseId].keyholders+1] = {
                citizenid = CitizenId,
                owner = IsOwner,
            }
            TriggerClientEvent('qb-traphouse:client:SyncData', -1, TraphouseId, Config.TrapHouses[TraphouseId])
        else
            if #Config.TrapHouses[TraphouseId].keyholders + 1 <= 6 then
                if not HasCitizenIdHasKey(CitizenId, TraphouseId) then
                    Config.TrapHouses[TraphouseId].keyholders[#Config.TrapHouses[TraphouseId].keyholders+1] = {
                        citizenid = CitizenId,
                        owner = IsOwner,
                    }
                    TriggerClientEvent('qb-traphouse:client:SyncData', -1, TraphouseId, Config.TrapHouses[TraphouseId])
                end
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_slots"))
            end
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.occured"))
    end
end)

RegisterServerEvent('qb-traphouse:server:TakeMoney', function(TraphouseId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Config.TrapHouses[TraphouseId].money ~= 0 then
        Player.Functions.AddMoney('cash', Config.TrapHouses[TraphouseId].money)
        Config.TrapHouses[TraphouseId].money = 0
        TriggerClientEvent('qb-traphouse:client:SyncData', -1, TraphouseId, Config.TrapHouses[TraphouseId])
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_money"), 'error')
    end
end)

RegisterServerEvent('qb-traphouse:server:RobNpc', function(Traphouse)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Chance = math.random(1, 10)
    local odd = math.random(1, 10)

    if Chance == odd then
        local info = {
            label = Lang:t('info.pincode', {value = Config.TrapHouses[Traphouse].pincode})
        }
        Player.Functions.AddItem("stickynote", 1, false, info)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["stickynote"], "add")
    else
        local amount = math.random(1, 80)
        Player.Functions.AddMoney('cash', amount)
    end
end)

-- Commands

QBCore.Commands.Add("multikeys", Lang:t("info.give_keys"), {{name = "id", help = "Player id"}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetId = tonumber(args[1])
    local TargetData = QBCore.Functions.GetPlayer(TargetId)
    local IsOwner = false
    local Traphouse = HasTraphouseAndOwner(Player.PlayerData.citizenid)

    if TargetData ~= nil then
        if Traphouse ~= nil then
            if not HasCitizenIdHasKey(TargetData.PlayerData.citizenid, Traphouse) then
                if Config.TrapHouses[Traphouse] ~= nil then
                    if IsOwner then
                        Config.TrapHouses[Traphouse].keyholders = {}
                        Config.TrapHouses[Traphouse].pincode = math.random(1111, 4444)
                    end

                    if Config.TrapHouses[Traphouse].keyholders == nil then
                        Config.TrapHouses[Traphouse].keyholders[#Config.TrapHouses[Traphouse].keyholders+1] = {
                            citizenid = TargetData.PlayerData.citizenid,
                            owner = IsOwner,
                        }
                        TriggerClientEvent('qb-traphouse:client:SyncData', -1, Traphouse, Config.TrapHouses[Traphouse])
                    else
                        if #Config.TrapHouses[Traphouse].keyholders + 1 <= 6 then
                            if not HasCitizenIdHasKey(TargetData.PlayerData.citizenid, Traphouse) then
                                Config.TrapHouses[Traphouse].keyholders[#Config.TrapHouses[Traphouse].keyholders+1] = {
                                    citizenid = TargetData.PlayerData.citizenid,
                                    owner = IsOwner,
                                }
                                TriggerClientEvent('qb-traphouse:client:SyncData', -1, Traphouse, Config.TrapHouses[Traphouse])
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_slots"))
                        end
                    end
                else
                    TriggerClientEvent('QBCore:Notify', src, Lang:t("error.occured"))
                end
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.have_keys"), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owner"), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_online"), 'error')
    end
end)

