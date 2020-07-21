local availableUnits, licenseLabels, propertyLabels = {}, {}, {}
ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

MySQL.ready(function()
	-- Get license labels
	MySQL.Async.fetchAll('SELECT type, label FROM licenses', {}, function(result)
		for k,v in ipairs(result) do
			licenseLabels[v.type] = v.label
		end
	end)

	-- Get property labels
	MySQL.Async.fetchAll('SELECT name, label FROM properties', {}, function(result)
		for k,v in ipairs(result) do
			propertyLabels[v.name] = v.label
		end
	end)
end)

AddEventHandler('esx_policejob:updateAvailableUnits', function(units)
	availableUnits = units
end)

ESX.RegisterServerCallback('mdt:executeAction', function(source, cb, data)
	local callbackData = {success = false, message = 'Invalid request'}

	if data.action == 'removeRecord' then
		MySQL.Async.execute('DELETE FROM records WHERE recordid = @id', {
			['@id'] = data.recordid,
		}, function(rowsChanged)
			if rowsChanged > 0 then
				cb({success = true, message = 'Deleted record.'})
			end
		end)
	elseif data.action == 'createRecord' then
		local recorddata = data.data

		MySQL.Async.fetchAll('SELECT fullname, identifier FROM users WHERE UPPER(fullname) = UPPER(@playerName)', {
			['@playerName'] = recorddata.player
		}, function(resp)
			if #resp == 1 then
				recorddata.player = resp[1].fullname
				recorddata.identifier = resp[1].identifier

				MySQL.Async.execute('INSERT into records (issuer, player, type, notes) VALUES (@issuer, @player, @type, @notes)', {
					['@issuer'] = recorddata.issuer,
					['@player'] = recorddata.player,
					['@type'] = recorddata.type,
					['@notes'] = recorddata.notes
				}, function(rowsChanged)
					if rowsChanged > 0 then
						if recorddata.type == 'warrant' then
							TriggerClientEvent('customNotification', -1, 'A warrant has been put out for <span style="color: red;">' .. recorddata.player .. '</span>');
						end

						cb({
							success = true,
							message = 'Record sucessfully created.',
							player = recorddata.player
						})
					else
						cb({success = false, message = 'Something went wrong.'})
					end
				end)
			else
				cb({success = false, message = 'Couldn\'t find a player with that name.'})
			end
		end)
	elseif data.action == 'getRecord' then
		MySQL.Async.fetchAll('SELECT * FROM records WHERE recordid = @recordid', {
			['@recordid'] = data.recordid
		}, function(resp)
			cb(resp[1])
		end)
	elseif data.action == 'requestPlayersLike' then
		MySQL.Async.fetchAll('SELECT * FROM characters WHERE UPPER(fullname) LIKE UPPER(@playerName)', {
			['@playerName'] = '%'..data.name..'%'
		}, function(resp)
			cb(resp)
		end)
	elseif data.action == 'requestPlayer' then
		local callbackData, userData = {}

		MySQL.Async.fetchAll('SELECT * FROM characters WHERE identifier = @identifier AND characterID = @characterID', {
			['@identifier'] = data.identifier,
			['@characterID'] = data.characterID
		}, function(resp)
			callbackData.userdata = resp[1]
			userData = resp[1]

			MySQL.Async.fetchAll('SELECT * FROM records WHERE player = @username', {
				['@username'] = userData.fullname
			}, function(resp)
				callbackData.records = resp
			end)

			if userData.licenses == nil then
				userData.licenses = '[]'
			end

			callbackData.licenses = json.decode(userData.licenses)

			for k,v in ipairs(callbackData.licenses) do
				MySQL.Async.fetchScalar('SELECT type FROM user_licenses WHERE id = @id', {
					['@id'] = v.id
				}, function(type)
					callbackData.licenses[k].type = type
					callbackData.licenses[k].label = licenseLabels[type]
				end)
			end

			callbackData.propertydata = json.decode(userData.properties)

			for k,v in ipairs(callbackData.propertydata) do
				MySQL.Async.fetchScalar('SELECT name FROM owned_properties WHERE id = @id', {
					['@id'] = v.id
				}, function(name)
					callbackData.propertydata[k].name = name
					callbackData.propertydata[k].label = propertyLabels[name]
				end)
			end
		end)

		for i=1, 5 do
			SetTimeout(1000 * i, function()
				if callbackData.records then
					cb(callbackData)
				end
			end)
		end

	elseif data.action == 'requestVehicle' then
		MySQL.Async.fetchAll('SELECT bolo, plate, owner, real_owner FROM owned_vehicles WHERE plate = @plate LIMIT 1', {
			['@plate'] = data.plate
		}, function(vehicle)
			if vehicle[1] then
				MySQL.Async.fetchAll('SELECT fullname, characterID, vehicles FROM characters WHERE identifier = @identifier LIMIT 3', {
					['@identifier'] = vehicle[1].real_owner
				}, function(playerCharacters)
					local character

					for k,char in ipairs(playerCharacters) do
						local vehicles = json.decode(char.vehicles)

						for _,vehicleData in ipairs(vehicles) do
							vehicleData.plate = ESX.Math.Trim(vehicleData.plate) -- since some plates include whitespaces from old vehicleshop 2019-06 :/

							if vehicleData.plate == data.plate then
								character = char
								break
							end
						end

						if character then
							break
						end
					end

					if character then
						MySQL.Async.fetchAll('SELECT * FROM records WHERE UPPER(player) = UPPER(@username) AND type = "warrant"', {
							['@username'] = character.fullname
						}, function(resp2)
							character.warrants = resp2

							vehicle[1].ownerData = character
							vehicle[1].rented = false

							cb(vehicle)
						end)
					else
						cb({})
					end
				end)
			else
				cb({})
			end
		end)

	elseif data.action == 'placeBolo' then
		MySQL.Async.execute('UPDATE owned_vehicles SET bolo = "true" WHERE plate = @plate', {
			['@plate'] = data.plate
		}, function(rowsChanged)
			if rowsChanged > 0 then
				cb({success = true, message = 'Placed Bolo'})
			else
				cb({success = false, message = 'Something went wrong.'})
			end
		end)
	elseif data.action == 'removeBolo' then
		MySQL.Async.execute('UPDATE owned_vehicles SET bolo = "false" WHERE plate = @plate', {
			['@plate'] = data.plate
		}, function(rowsChanged)
			if rowsChanged > 0 then
				cb({success = true, message = 'Removed Bolo'})
			else
				cb({success = false, message = 'Something went wrong.'})
			end
		end)
	elseif data.action == 'checkWarrants' then
		MySQL.Async.fetchAll('SELECT * FROM records WHERE type = "warrant"', {}, function(resp)
			cb(resp)
		end)
	end
end)

RegisterServerEvent('inv_policemdt:sendGlobalPoliceMessage')
AddEventHandler('inv_policemdt:sendGlobalPoliceMessage', function(message)
	for playerId,_ in pairs(availableUnits) do
		TriggerClientEvent('chat:addMessage', playerId, {args = {'', message}})
	end
end)

RegisterServerEvent('inv_policemdt:sendGlobalPoliceWaypoint')
AddEventHandler('inv_policemdt:sendGlobalPoliceWaypoint', function(x, y)
	for playerId,_ in pairs(availableUnits) do
		TriggerClientEvent('inv_policemdt:sendGlobalPoliceWaypoint', playerId, x, y)
	end
end)
