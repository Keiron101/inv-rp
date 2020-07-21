ESX = nil
local scanningDistance, mdtActive, officerName = 40.0

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(100)
	end

	ESX.PlayerData = ESX.GetPlayerData()
	officerName = ESX.PlayerData.name
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx:setName')
AddEventHandler('esx:setName', function(newName)
	officerName = newName
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()

		if IsPedInAnyPoliceVehicle(playerPed) and CheckPolice() then

			if IsControlJustReleased(0, 168) then
				local vehicle = GetVehiclePedIsUsing(playerPed, false)

				if canOpenMDT(playerPed, vehicle) then
					openMDT()
				end
			end

		else
			Citizen.Wait(500)
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed, canSleep = PlayerPedId(), true
		local coords = GetEntityCoords(playerPed)

		for i=1, #Config.StationMDTs do
			if GetDistanceBetweenCoords(coords, Config.StationMDTs[i], true) < 1.5 then
				canSleep = false
				if CheckPolice() then
					ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to access the ~y~Police MDT~s~.')
					if IsControlJustReleased(0, 38) then
						openMDT()
					end
				end
			end
		end

		if canSleep then
			Citizen.Wait(500)
		end
	end
end)

function CheckPolice()
	if not ESX.PlayerData.job then
		return false
	end

	local job = ESX.PlayerData.job.name

	if job == 'police' then
		return true
	elseif job == 'state' then
		return true
	elseif job == 'sheriff' then
		return true
	elseif job == 'usmarshal' then
		return true
	elseif job == 'dod' then
		return true
	elseif job == 'fib' then
		return true
	elseif job == 'doj' then
		return true
	end

	return false
end

function GetVehicleInfrontOfEntity(entity)
	local coords = GetOffsetFromEntityInWorldCoords(entity, 0.0, 1.0, 0.3)
	local coords2 = GetOffsetFromEntityInWorldCoords(entity, 0.0, scanningDistance, 0.0)
	local rayHandle = StartShapeTestRay(coords, coords2, 10, entity, 0)
	local numRayHandle, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

	if hit == 1 and IsEntityAVehicle(entityHit) then
		return entityHit
	else
		return nil
	end
end

function canOpenMDT(playerPed, vehicle)
	local driverPed = GetPedInVehicleSeat(vehicle, -1)
	local passengerPed = GetPedInVehicleSeat(vehicle, 0)

	if driverPed == playerPed then
		return true
	elseif passengerPed == playerPed then
		return true
	end

	return false
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()

		if IsPedInAnyPoliceVehicle(playerPed) and CheckPolice() then
			if IsControlJustReleased(0, 29) then
				local playerVehicle = GetVehiclePedIsIn(playerPed, false)
				local vehicleInFront = GetVehicleInfrontOfEntity(playerVehicle)
				
				if canOpenMDT(playerPed, playerVehicle) and vehicleInFront then
					local inFrontPlate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicleInFront))
					scanVehicle(inFrontPlate)
				end
			end
		else
			Citizen.Wait(500)
		end
	end
end)

RegisterNUICallback('mdtAction', function(data, cb)
	ESX.TriggerServerCallback('mdt:executeAction', function(response)
		cb(response)
	end, data)
end)

function scanVehicle(plate)
	SendNUIMessage({
		type = 'MDT',
		action = 'scanVehicle',
		name = officerName,
		plate = plate
	})

	SetNuiFocus(true, true)
	mdtActive = true
end

function openMDT()
	SendNUIMessage({
		type = 'MDT',
		action = 'open',
		name = officerName
	})

	SetNuiFocus(true, true)
	mdtActive = true
end

RegisterNUICallback('closeMDT', function()
	SendNUIMessage({
		type = 'MDT',
		action = 'close',
		name = officerName
	})

	local playerPed = PlayerPedId()
	ClearPedTasks(playerPed)

	SetNuiFocus(false)
	mdtActive = false
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustReleased(0, 57) then
			if IsInputDisabled(0) and CheckPolice() then
				local playerPed = PlayerPedId()
				local coords = GetEntityCoords(playerPed)
				local streetName, crossing = GetStreetNameAtCoord(coords.x, coords.y)
				streetName, message = GetStreetNameFromHashKey(streetName)
	
				if crossing then
					crossing = GetStreetNameFromHashKey(crossing)
					message = ('^4%s^1 has called a 10-33 near ^3%s^1 and ^3%s^1, all units break and roll code 3!'):format(officerName, streetName, crossing)
				else
					message = ('^4%s^1 has called a 10-33 near ^3%s^1, all units break and roll code 3!'):format(officerName, streetName)
				end
	
				TriggerServerEvent('inv_policemdt:sendGlobalPoliceMessage', message)
				TriggerServerEvent('inv_policemdt:sendGlobalPoliceWaypoint', coords.x, coords.y)
			end
		end
	end
end)

RegisterNetEvent('inv_policemdt:sendGlobalPoliceWaypoint')
AddEventHandler('inv_policemdt:sendGlobalPoliceWaypoint', function(x, y)
	SetNewWaypoint(x, y)
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if mdtActive then
			SetNuiFocus(false)
		end
	end
end)