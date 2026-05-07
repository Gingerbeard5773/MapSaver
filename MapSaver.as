// SonantDread & Gingerbeard @ November 14th 2024

/*
 Map Saving
 This tool saves the entire map so that it can be played at a later time.
 No longer will you have to worry about all your progress being lost due to crashes or network outages,
 as you can just simply save the game and return later.

 For an example of a complete implementation, visit Zombies Reborn- which is the mod this tool was originally created for.
 https://discord.gg/V29BBeba3C
 https://github.com/Gingerbeard5773/Zombies_Reborn
 
 Errors from this script typically mean that a save file is corrupted or outdated!
*/

#include "MapSaverCommon.as"

const string SaveFile = "MapSave_"; //MODIFY THIS TO ENSURE NO OTHER MODS OVERWRITE

// store tiles using run line encoding
string SerializeTileData(CMap@ map)
{
	string map_data = "";

	u16 last_type = map.getTile(0).type;
	u32 tile_count = 1;
	const u32 tilemapsize = map.tilemapheight * map.tilemapwidth;
	for (u32 i = 1; i < tilemapsize; i++)
	{
		const u16 type = map.getTile(i).type;
		if (type == last_type)
		{
			tile_count++;
		}
		else
		{
			map_data += last_type + " " + tile_count + ";";
			last_type = type;
			tile_count = 1;
		}
	}
	map_data += last_type + " " + tile_count + ";";

	return map_data;
}

// store dirt background using run line encoding
string SerializeDirtData(CMap@ map)
{
	string map_data = "";

	bool was_dirt = map.getTile(0).dirt == 80;
	u32 tile_count = 1;
	const u32 tilemapsize = map.tilemapheight * map.tilemapwidth;
	for (u32 i = 1; i < tilemapsize; i++)
	{
		const bool is_dirt = map.getTile(i).dirt == 80;
		if (is_dirt == was_dirt)
		{
			tile_count++;
		}
		else
		{
			map_data += (was_dirt ? "1" : "0") + " " + tile_count + ";";
			was_dirt = is_dirt;
			tile_count = 1;
		}
	}
	map_data += (was_dirt ? "1" : "0") + " " + tile_count + ";";

	return map_data;
}

// store water using run line encoding
string SerializeWaterData(CMap@ map)
{
	string map_data = "";

	bool was_water = map.isInWater(map.getTileWorldPosition(0));
	u32 tile_count = 1;
	const u32 tilemapsize = map.tilemapheight * map.tilemapwidth;
	for (u32 i = 1; i < tilemapsize; i++)
	{
		const bool has_water = map.isInWater(map.getTileWorldPosition(i));
		if (was_water == has_water)
		{
			tile_count++;
		}
		else
		{
			map_data += (was_water ? "1" : "0") + " " + tile_count + ";";
			was_water = has_water;
			tile_count = 1;
		}
	}
	map_data += (was_water ? "1" : "0") + " " + tile_count + ";";

	return map_data;
}

string SerializeBlobData(u16[]@ saved_netids)
{
	CBlob@[] blobs;
	getBlobs(@blobs);
	string blob_data = "";

	for (int i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (!canSaveBlob(blob)) continue;

		saved_netids.push_back(blob.getNetworkID());

		BlobDataHandler@ handler = getBlobHandler(blob.getName());
		const string data = handler.Serialize(blob);
		if (!data.isEmpty())
		{
			blob_data += data + ";"; // extra semicolon to seperate each blob
		}
	}

	return blob_data;
}

string SerializeInventoryData(u16[]@ saved_netids)
{
	string inventory_data;

	for (u16 i = 0; i < saved_netids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(saved_netids[i]);
		if (blob is null) continue;

		CBlob@ parent = blob.getInventoryBlob();
		if (parent is null) continue;

		const int parent_index = saved_netids.find(parent.getNetworkID());
		if (parent_index == -1) continue;

		inventory_data += i + " " + parent_index + ";";
	}

	return inventory_data;
}

string SerializeAttachmentData(u16[]@ saved_netids)
{
	string attachment_data;

	for (u16 i = 0; i < saved_netids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(saved_netids[i]);
		if (blob is null) continue;

		AttachmentPoint@[] aps;
		if (!blob.getAttachmentPoints(@aps)) continue;

		for (u16 a = 0; a < aps.length; a++)
		{
			AttachmentPoint@ ap = aps[a];
			CBlob@ occupied = ap.getOccupied();
			if (occupied is null) continue;

			const int occupied_index = saved_netids.find(occupied.getNetworkID());
			if (occupied_index == -1) continue;

			attachment_data += i + " " + occupied_index + " " + a + ";";
		}
	}

	return attachment_data;
}

/*
 This implementation for saving damage owner players could be better.
 For now, it only works if the player is online at the instance the world is saved as well as during loading.
 This could be fixed if damage owner players were completely moved to a string based format [e.g blob.get_string("damage_owner_player") ]
*/
string SerializeDamageOwnerPlayerData(u16[]@ saved_netids)
{
	string owner_data;

	string[] player_names;

	for (int i = 0; i < getPlayerCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null || player.isBot()) continue;

		player_names.push_back(player.getUsername());
	}

	u16[][] blob_indexes(player_names.length);

	for (u16 i = 0; i < saved_netids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(saved_netids[i]);
		if (blob is null) continue;

		CPlayer@ owner_player = blob.getDamageOwnerPlayer();
		if (owner_player is null) continue;

		if (blob is owner_player.getBlob()) continue;

		const int player_index = player_names.find(owner_player.getUsername());
		if (player_index == -1) continue;

		blob_indexes[player_index].push_back(i);
	}
	
	for (int i = 0; i < player_names.length; i++)
	{
		if (blob_indexes[i].length == 0) continue;

		owner_data += player_names[i] + "{";

		for (int b = 0; b < blob_indexes[i].length; b++)
		{
			owner_data += blob_indexes[i][b] + ";";
		}

		owner_data += "}";
	}

	return owner_data;
}

void SaveMap(CRules@ this, CMap@ map, const string&in save_slot = "AutoSave")
{
	InitializeBlobHandlers();

	ConfigFile@ config = ConfigFile();

	// collect all map data
	const string map_dimensions = map.tilemapwidth + ";" + map.tilemapheight;
	const string map_data = SerializeTileData(map);
	const string dirt_data = SerializeDirtData(map);
	const string water_data = SerializeWaterData(map);

	// collect all blob data
	u16[] saved_netids;
	const string blob_data = SerializeBlobData(@saved_netids);
	const string inventory_data = SerializeInventoryData(@saved_netids);
	const string attachment_data = SerializeAttachmentData(@saved_netids);
	const string owner_data = SerializeDamageOwnerPlayerData(@saved_netids);

	// collect rules data
	CRules@ rules = getRules();
	const f32 day_time = map.getDayTime();

	// save data to config file
	config.add_string("map_dimensions", map_dimensions);
	config.add_string("map_data", map_data);
	config.add_string("dirt_data", dirt_data);
	config.add_string("water_data", water_data);
	config.add_string("blob_data", blob_data);
	config.add_string("inventory_data", inventory_data);
	config.add_string("attachment_data", attachment_data);
	config.add_string("owner_data", owner_data);
	config.add_f32("day_time", day_time);

	config.saveFile(SaveFile + save_slot);

	blobHandlers.deleteAll();
}

/*
 Loading is divided into two parts.
 LoadSavedMap: called before rules scripts are initialized
 LoadSavedRules: called after rules scripts are initialized- for overwriting variables set onRestart in rules scripts
*/

bool LoadSavedMap(CRules@ this, CMap@ map)
{
	if (this.get_bool("loaded_saved_map")) return false;

	if (!isServer()) return true;

	const string save_slot = this.exists("mapsaver_save_slot") ? this.get_string("mapsaver_save_slot") : "AutoSave";

	ConfigFile config = ConfigFile();
	if (!config.loadFile("../Cache/" + SaveFile + save_slot)) return false;

	if (!config.exists("map_dimensions")) return false;

	const string[]@ map_dimensions = config.read_string("map_dimensions").split(";");
	if (map_dimensions.length < 2) return false;

	const int width = parseInt(map_dimensions[0]);
	const int height = parseInt(map_dimensions[1]);

	const string map_data = config.read_string("map_data", "");
	const string water_data = config.read_string("water_data", "");
	const string blob_data = config.read_string("blob_data", "");
	const string inventory_data = config.read_string("inventory_data", "");
	const string attachment_data = config.read_string("attachment_data", "");
	const string owner_data = config.read_string("owner_data", "");

	map.CreateTileMap(width, height, 8.0f, "Sprites/world.png");

	InitializeBlobHandlers();

	LoadTiles(map, map_data);
	LoadWater(map, water_data);

	CBlob@[] loaded_blobs;
	LoadBlobs(map, blob_data, @loaded_blobs);
	LoadInventories(map, inventory_data, @loaded_blobs);
	LoadAttachments(map, attachment_data, @loaded_blobs);
	LoadDamageOwnerPlayers(owner_data, @loaded_blobs);

	blobHandlers.deleteAll();

	return true;
}

bool LoadSavedRules(CRules@ this, CMap@ map)
{
	if (this.get_bool("loaded_saved_map")) return false;

	if (!isServer()) return true;

	const string save_slot = this.exists("mapsaver_save_slot") ? this.get_string("mapsaver_save_slot") : "AutoSave";

	ConfigFile config = ConfigFile();
	if (!config.loadFile("../Cache/" + SaveFile + save_slot)) return false;

	const string dirt_data = config.read_string("dirt_data", "");
	const f32 day_time = config.read_f32("day_time", 0.2f);
	map.SetDayTime(day_time);

	//dirt data has to be loaded late because of an engine issue..
	LoadDirt(map, dirt_data);

	this.set_bool("loaded_saved_map", true);

	return true;
}

void LoadTiles(CMap@ map, const string&in map_data)
{
	const string[]@ tiles = map_data.split(";");
	u32 current_index = 0;
	for (int i = 0; i < tiles.length - 1; i++)
	{
		string[]@ data = tiles[i].split(" ");
		if (data.length != 2) { error("MapSaver: Failed tile indices"); continue; }

		const int tile_type = parseInt(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			map.SetTile(current_index++, tile_type);
		}
	}
}

void LoadDirt(CMap@ map, const string&in map_data)
{
	const string[]@ tiles = map_data.split(";");
	u32 current_index = 0;
	for (int i = 0; i < tiles.length - 1; i++)
	{
		string[]@ data = tiles[i].split(" ");
		if (data.length != 2) { error("MapSaver: Failed dirt indices"); continue; }

		const bool is_dirt = parseBool(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			if (is_dirt)
			{
				map.RemoveTileFlag(current_index, Tile::LIGHT_SOURCE);
				map.SetTileDirt(current_index, 80);
			}
			current_index++;
		}
	}
}

void LoadWater(CMap@ map, const string&in map_data)
{
	const string[]@ tiles = map_data.split(";");
	u32 current_index = 0;
	for (int i = 0; i < tiles.length - 1; i++)
	{
		string[]@ data = tiles[i].split(" ");
		if (data.length != 2) { error("MapSaver: Failed water indices"); continue; }

		const bool has_water = parseBool(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			map.server_setFloodWaterOffset(current_index++, has_water);
		}
	}
}

void LoadBlobs(CMap@ map, const string&in blob_data, CBlob@[]@ loaded_blobs)
{
	// each blob is separated by 2x semicolon
	const string[]@ blobs = blob_data.split(";;");
	for (int i = 0; i < blobs.length; i++)
	{
		if (blobs[i].isEmpty()) continue;

		string[]@ data = blobs[i].split(";");
		if (data.length < 3) { error("MapSaver: Failed indexing for blob data"); continue; }

		const string name = data[0];
		const Vec2f pos(parseFloat(data[1]), parseFloat(data[2]));
		BlobDataHandler@ handler = getBlobHandler(name);

		CBlob@ blob = handler.CreateBlob(name, pos, data);
		loaded_blobs.push_back(blob);

		if (blob is null) { error("MapSaver: Failed to load blob '"+name+"'"); continue; }

		handler.LoadBlobData(blob, data);
	}
}

void LoadInventories(CMap@ map, const string&in inventory_data, CBlob@[]@ loaded_blobs)
{
	const string[]@ pairs = inventory_data.split(";");
	for (int i = 0; i < pairs.length - 1; i++)
	{
		const string[]@ indices = pairs[i].split(" ");
		if (indices.length != 2) { error("MapSaver: Failed inventory indices"); continue; }
		
		const int blob_index = parseInt(indices[0]);
		const int parent_index = parseInt(indices[1]);
		if (blob_index >= loaded_blobs.length || parent_index >= loaded_blobs.length) { error("MapSaver: Failed inventory indices [out of bounds]"); continue; }

		CBlob@ blob = loaded_blobs[blob_index];
		CBlob@ parent = loaded_blobs[parent_index];
		if (blob is null || parent is null) continue;

		parent.server_PutInInventory(blob);
	}
}

void LoadAttachments(CMap@ map, const string&in attachment_data, CBlob@[]@ loaded_blobs)
{
	const string[]@ pairs = attachment_data.split(";");
	for (int i = 0; i < pairs.length - 1; i++)
	{
		const string[]@ indices = pairs[i].split(" ");
		if (indices.length != 3) { error("MapSaver: Failed attachment indices"); continue; }

		const int blob_index = parseInt(indices[0]);
		const int parent_index = parseInt(indices[1]);
		if (blob_index >= loaded_blobs.length || parent_index >= loaded_blobs.length) { error("MapSaver: Failed attachment indices [out of bounds]"); continue; }

		CBlob@ blob = loaded_blobs[blob_index];
		CBlob@ parent = loaded_blobs[parent_index];
		if (blob is null || parent is null) continue;

		const int ap_index = parseInt(indices[2]);
		blob.server_AttachTo(parent, ap_index);
	}
}

void LoadDamageOwnerPlayers(const string&in owner_data, CBlob@[]@ loaded_blobs)
{
	const string[]@ players = owner_data.split("}");
	for (int p = 0; p < players.length - 1; p++)
	{
		const string[]@ owner_compartments = players[p].split("{");
		if (owner_compartments.length != 2) { error("MapSaver: Failed owner compartments"); continue; }

		const string player_name = owner_compartments[0];
		CPlayer@ player = getPlayerByUsername(player_name); 
		if (player is null) continue;

		const string[]@ blob_indexes = owner_compartments[1].split(";");
		for (int i = 0; i < blob_indexes.length - 1; i++)
		{
			const int blob_index = parseInt(blob_indexes[i]);
			if (blob_index >= loaded_blobs.length) { error("MapSaver: Failed owner [out of bounds]"); continue; }

			CBlob@ blob = loaded_blobs[blob_index];
			if (blob is null) continue;

			blob.SetDamageOwnerPlayer(player);
		}
	}
}
