var gladiatorStore = {}
var joinedUsers = []
var userCount = 0
var battleStarted = false
var isBattleRoom = false
var dieRoll = null
var dieRoll2 = null
var dieRoll3 = null

var FIELDS = ["user_id","gladiator_id","gladiator_level","foozle","gladiator_name","achievements_tree","warfare_tree","arcane_tree","theatrics_tree","survival_tree","taunt_quote","victory_quote","wins","losses","DNA_tree","attribs_tree","talents_tree","stats_tree","gold","max_items","spells_tree","hotkeys_tree","inv"]

function init()
{
	trace("Initing ssmp_db extension")
	loadGladiatorData()
}

function destroy()
{
	trace("ssmp_db extension destroyed")
}

function serializeRecord(rec)
{
	var parts = []
	for (var i = 0; i < FIELDS.length; i++)
	{
		var v = rec[FIELDS[i]]
		if (v == undefined || v == null)
		{
			v = ""
		}
		parts.push(String(v))
	}
	return parts.join("|||")
}

function parseRecord(line)
{
	var parts = line.split("|||")
	var rec = {}
	for (var i = 0; i < FIELDS.length; i++)
	{
		rec[FIELDS[i]] = parts[i]
	}
	return rec
}

function loadGladiatorData()
{
	gladiatorStore = {}
	try
	{
		var f = new java.io.File("gladiator_data.txt")
		if (f.exists())
		{
			var reader = new java.io.BufferedReader(new java.io.FileReader(f))
			var line
			var count = 0
			while ((line = reader.readLine()) != null)
			{
				if (String(line).length > 0)
				{
					var rec = parseRecord(String(line))
					gladiatorStore[String(rec.gladiator_id)] = rec
					count++
				}
			}
			reader.close()
			trace("Loaded " + count + " saved gladiators from file")
		}
		else
		{
			trace("No existing gladiator_data.txt found - starting fresh")
		}
	}
	catch (e)
	{
		trace("Error loading gladiator data: " + e)
	}
}

function saveGladiatorDataToFile()
{
	try
	{
		var writer = new java.io.BufferedWriter(new java.io.FileWriter("gladiator_data.txt"))
		for (var key in gladiatorStore)
		{
			writer.write(serializeRecord(gladiatorStore[key]))
			writer.newLine()
		}
		writer.close()
	}
	catch (e)
	{
		trace("Error saving gladiator data: " + e)
	}
}

function handleRequest(cmd, params, user, fromRoom)
{

	if (cmd == "gladiator_top_list" || cmd == "show_my_gladiators" || cmd == "addData" || cmd == "saveData" || cmd == "saveInv" || cmd == "deleteData" || cmd == "loadData")
{
	isBattleRoom = false
	battleStarted = true
}

	if (cmd == "gladiator_top_list")
	{
		trace("gladiator_top_list requested by user_id: " + params.user_id)
		
		var response = {}
		response._cmd = "gladiator_top_list"
		response.db = []
		
		var sorted = []
		for (var key in gladiatorStore)
		{
			sorted.push(gladiatorStore[key])
		}
		
		var i = 0
		while (i < sorted.length)
		{
			var item = {}
			item.gladiator_name = sorted[i].gladiator_name
			item.gladiator_level = sorted[i].gladiator_level
			item.wins = sorted[i].wins
			item.losses = sorted[i].losses
			response.db.push(item)
			i++
		}
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "show_my_gladiators")
	{
		trace("show_my_gladiators requested by user_id: " + params.user_id)
		
		var response = {}
		response._cmd = "show_my_gladiators"
		response.db = []
		
		for (var key in gladiatorStore)
		{
			var rec = gladiatorStore[key]
			if (String(rec.user_id) == String(params.user_id))
			{
				var item = {}
				item.gladiator_id = rec.gladiator_id
				item.gladiator_name = rec.gladiator_name
				item.gladiator_level = Number(rec.gladiator_level)
				item.foozle = Number(rec.foozle)
				response.db.push(item)
			}
		}
		
		trace("Sending response.db with " + response.db.length + " items")
		for (var m = 0; m < response.db.length; m++)
		{
			trace("  item " + m + ": id=" + response.db[m].gladiator_id + " name=" + response.db[m].gladiator_name + " foozle=" + response.db[m].foozle)
		}
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "addData")
	{
		trace("addData requested - creating gladiator: " + params.gladiator_name)
		
		var newId = String(new Date().getTime())
		var rec = {}
		var i = 0
		while (i < FIELDS.length)
		{
			var key = FIELDS[i]
			rec[key] = params[key]
			i++
		}
		rec.gladiator_id = newId
		rec.user_id = params.user_id
		
		if (rec.gold == undefined) { rec.gold = 1000 }
		if (rec.max_items == undefined) { rec.max_items = 30 }
		if (rec.spells_tree == undefined) { rec.spells_tree = "0_0_0_0_0_0_0_0_0_0" }
		if (rec.hotkeys_tree == undefined) { rec.hotkeys_tree = "0_0_0_0_0_0_0_0" }
		if (rec.inv == undefined) { rec.inv = "0" }
		if (rec.wins == undefined) { rec.wins = 0 }
		if (rec.losses == undefined) { rec.losses = 0 }
		if (rec.foozle == undefined) { rec.foozle = 0 }
		
		gladiatorStore[newId] = rec
		saveGladiatorDataToFile()
		
		var response = {}
		response._cmd = "addData"
		response.gladiator_id = newId
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "loadData")
	{
		trace("loadData requested for gladiator_id: " + params.gladiator_id)
		
		var rec = gladiatorStore[String(params.gladiator_id)]
		
		if (rec != undefined)
		{
			var response = {}
			response._cmd = "loadData"
			response.user_id = rec.user_id
			
			var i = 0
			while (i < FIELDS.length)
			{
				response[FIELDS[i]] = rec[FIELDS[i]]
				i++
			}
			
			_server.sendResponse(response, -1, null, [user], "xml")
		}
		else
		{
			trace("loadData - gladiator not found: " + params.gladiator_id)
		}
	}
	else if (cmd == "saveData")
	{
		trace("saveData requested for gladiator: " + params.gladiator_name)
		
		var rec = gladiatorStore[String(params.gladiator_id)]
		if (rec != undefined)
		{
			var i = 0
			while (i < FIELDS.length)
			{
				var key = FIELDS[i]
				if (params[key] != undefined)
				{
					rec[key] = params[key]
				}
				i++
			}
			saveGladiatorDataToFile()
		}
		
		var response = {}
		response._cmd = "saveData"
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "saveInv")
	{
		trace("saveInv requested")
		
		var rec = gladiatorStore[String(params.gladiator_id)]
		if (rec != undefined)
		{
			if (params.gold != undefined && Number(params.gold) != -1)
			{
				rec.gold = params.gold
			}
			if (params.spells_tree != undefined)
			{
				rec.spells_tree = params.spells_tree
			}
			if (params.hotkeys_tree != undefined)
			{
				rec.hotkeys_tree = params.hotkeys_tree
			}
			saveGladiatorDataToFile()
		}
		
		var response = {}
		response._cmd = "saveInv"
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "deleteData")
	{
		trace("deleteData requested for gladiator_id: " + params.gladiator_id)
		
		delete gladiatorStore[String(params.gladiator_id)]
		saveGladiatorDataToFile()
		
		var response = {}
		response._cmd = "deleteData"
		
		_server.sendResponse(response, -1, null, [user], "xml")
	}
	else if (cmd == "gladiator_ready")
	{
		trace("gladiator_ready from: " + params.g_ready)
		
		if (dieRoll == null)
		{
			dieRoll = Math.floor(Math.random() * 140) + 1
			dieRoll2 = Math.floor(Math.random() * 3) + 1
			dieRoll3 = Math.floor(Math.random() * 3) + 1
		}
		
		var response = {}
		response._cmd = "gladiator_ready"
		response.g_ready = params.g_ready
		response.die_roll = dieRoll
		response.die_roll2 = dieRoll2
		response.die_roll3 = dieRoll3
		
		_server.sendResponse(response, -1, null, joinedUsers, "xml")
	}
	else if (cmd == "gladiator_left")
	{
		trace("gladiator_left from: " + params.g_left)
		
		var response = {}
		response._cmd = "gladiator_left"
		
		_server.sendResponse(response, -1, null, joinedUsers, "xml")
	}
	else if (cmd == "move")
	{
		var senderIndex = -1
		var userStr = String(user)
		for (var i = 0; i < joinedUsers.length; i++)
		{
			if (String(joinedUsers[i]) == userStr)
			{
				senderIndex = i
				break
			}
		}
		
		trace("move from pid: " + (senderIndex + 1) + " - move: " + params.move_s)
		
		var response = {}
		response._cmd = "move"
		response.pid = senderIndex + 1
		response.prio = params.prio
		response.move_s = params.move_s
		response.move_var1 = params.move_var1
		response.move_var2 = params.move_var2
		
		response.die_roll = Math.floor(Math.random() * 100) + 1
		response.die_roll2 = Math.floor(Math.random() * 100) + 1
		response.die_roll3 = Math.floor(Math.random() * 100) + 1
		response.die_roll4 = Math.floor(Math.random() * 100) + 1
		
		if (params.ran_num1 != undefined && params.ran_num2 != undefined)
		{
			var minR = Math.min(params.ran_num1, params.ran_num2)
			var maxR = Math.max(params.ran_num1, params.ran_num2)
			response.ran_var = Math.floor(Math.random() * (maxR - minR + 1)) + minR
		}
		else
		{
			response.ran_var = 0
		}
		
		_server.sendResponse(response, -1, null, joinedUsers, "xml")
	}
}

function handleInternalEvent(evt)
{
	trace("Event received: " + evt.name)
	
	if (evt.name == "newRoom")
{
   isBattleRoom = true
   joinedUsers = []
   battleStarted = false
}
	
	if (isBattleRoom && evt.name == "userJoin")
	{
		var uname = String(evt.user)
		var found = false
		var i = 0
		while (i < joinedUsers.length)
		{
			if (String(joinedUsers[i]) == uname)
			{
				found = true
			}
			i++
		}
		
		if (!found)
		{
			joinedUsers.push(evt.user)
			trace("Distinct users seen: " + joinedUsers.length)
		}
		
		if (joinedUsers.length >= 2 && !battleStarted)
		{
			battleStarted = true
			trace("Both players present - sending start")
			
			var response = {}
			response._cmd = "start"
			
			_server.sendResponse(response, -1, null, joinedUsers, "xml")
		}
	}
}