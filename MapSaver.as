// SonantDread & Gingerbeard @ November 14th 2024

/*
 Map Saving
 This tool saves the entire map so that it can be played at a later time.
 No longer will you have to worry about all your progress being lost due to crashes or network outages,
 as you can just simply save the game and return later.

 For an example of a complete implementation, visit Zombies Reborn- which is the mod this tool was originally created for.
 https://discord.gg/V29BBeba3C
 https://github.com/Gingerbeard5773/Zombies_Reborn
*/

#include "MapSaverCommon.as";

// store tiles using run line encoding
string SerializeTileData(CMap@ map)
{
	string mapData = "";

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
			mapData += last_type + " " + tile_count + ";";
			last_type = type;
			tile_count = 1;
		}
	}
	mapData += last_type + " " + tile_count + ";";

	return mapData;
}

// store dirt background using run line encoding
string SerializeDirtData(CMap@ map)
{
	string mapData = "";

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
			mapData += (was_dirt ? "1" : "0") + " " + tile_count + ";";
			was_dirt = is_dirt;
			tile_count = 1;
		}
	}
	mapData += (was_dirt ? "1" : "0") + " " + tile_count + ";";

	return mapData;
}

// store water using run line encoding
string SerializeWaterData(CMap@ map)
{
	string mapData = "";

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
			mapData += (was_water ? "1" : "0") + " " + tile_count + ";";
			was_water = has_water;
			tile_count = 1;
		}
	}
	mapData += (was_water ? "1" : "0") + " " + tile_count + ";";

	return mapData;
}

string SerializeBlobData(u16[]@ saved_netids)
{
	CBlob@[] blobs;
	getBlobs(@blobs);
	string blobData = "";

	for (int i = 0; i < blobs.length; i++)
	{
		CBlob@ blob = blobs[i];
		if (!canSaveBlob(blob)) continue;

		saved_netids.push_back(blob.getNetworkID());

		BlobDataHandler@ handler = getBlobHandler(blob.getName());
		const string data = handler.Serialize(blob);
		if (!data.isEmpty())
		{
			blobData += data + ";"; // extra semicolon to seperate each blob
		}
	}

	return blobData;
}

string SerializeInventoryData(u16[]@ saved_netids)
{
	string inventoryData;

	for (u16 i = 0; i < saved_netids.length; i++)
	{
		CBlob@ blob = getBlobByNetworkID(saved_netids[i]);
		if (blob is null) continue;

		CBlob@ parent = blob.getInventoryBlob();
		if (parent is null) continue;

		const int parent_index = saved_netids.find(parent.getNetworkID());
		if (parent_index == -1) continue;

		inventoryData += i + " " + parent_index + ";";
	}

	return inventoryData;
}

string SerializeAttachmentData(u16[]@ saved_netids)
{
	string attachmentData;

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

			attachmentData += i + " " + occupied_index + " " + a + ";";
		}
	}

	return attachmentData;
}

void SaveMap(CRules@ this, CMap@ map, const string&in SaveSlot = "AutoSave")
{
	InitializeBlobHandlers();

	ConfigFile@ config = ConfigFile();

	// collect all map data
	const string map_dimensions = map.tilemapwidth + ";" + map.tilemapheight;
	const string mapData = SerializeTileData(map);
	const string dirtData = SerializeDirtData(map);
	const string waterData = SerializeWaterData(map);

	// collect all blob data
	u16[] saved_netids;
	const string blobData = SerializeBlobData(@saved_netids);
	const string inventoryData = SerializeInventoryData(@saved_netids);
	const string attachmentData = SerializeAttachmentData(@saved_netids);

	// collect rules data
	CRules@ rules = getRules();
	const f32 dayTime = map.getDayTime();

	// save data to config file
	config.add_string("map_dimensions", map_dimensions);
	config.add_string("map_data", mapData);
	config.add_string("dirt_data", dirtData);
	config.add_string("water_data", waterData);
	config.add_string("blob_data", blobData);
	config.add_string("inventory_data", inventoryData);
	config.add_string("attachment_data", attachmentData);
	config.add_f32("day_time", dayTime);

	config.saveFile(SaveFile+SaveSlot);
}

/*
 Loading is divided into two parts.
 LoadSavedMap: called before rules scripts are initialized
 LoadSavedRules: called after rules scripts are initialized- for the purpose of overwriting variables
*/

bool LoadSavedMap(CRules@ this, CMap@ map)
{
	if (this.get_bool("loaded_saved_map")) return false;

	if (!isServer()) return true;

	const string SaveSlot = this.get_string("mapsaver_save_slot");

	ConfigFile config = ConfigFile();
	if (!config.loadFile("../Cache/" + SaveFile + SaveSlot)) return false;

	if (!config.exists("map_dimensions")) return false;

	const string[]@ map_dimensions = config.read_string("map_dimensions").split(";");
	if (map_dimensions.length < 2) return false;

	const int width = parseInt(map_dimensions[0]);
	const int height = parseInt(map_dimensions[1]);

	const string mapData = config.read_string("map_data");
	const string waterData = config.read_string("water_data");
	const string blobData = config.read_string("blob_data");
	const string inventoryData = config.read_string("inventory_data");
	const string attachmentData = config.read_string("attachment_data");

	map.CreateTileMap(width, height, 8.0f, "Sprites/world.png");

	InitializeBlobHandlers();

	LoadTiles(map, mapData.split(";"));
	LoadWater(map, waterData.split(";"));

	CBlob@[] loaded_blobs;
	LoadBlobs(map, blobData, @loaded_blobs);
	LoadInventories(map, inventoryData, @loaded_blobs);
	LoadAttachments(map, attachmentData, @loaded_blobs);

	return true;
}

bool LoadSavedRules(CRules@ this, CMap@ map)
{
	if (this.get_bool("loaded_saved_map")) return false;

	if (!isServer()) return true;

	const string SaveSlot = this.get_string("mapsaver_save_slot");

	ConfigFile config = ConfigFile();
	if (!config.loadFile("../Cache/" + SaveFile + SaveSlot)) return false;

	const string dirtData = config.read_string("dirt_data");
	const f32 dayTime = config.read_f32("day_time");
	map.SetDayTime(dayTime);

	//dirt data has to be loaded late because of an engine issue..
	LoadDirt(map, dirtData.split(";"));

	this.set_bool("loaded_saved_map", true);

	return true;
}

void LoadTiles(CMap@ map, const string[]&in mapTiles)
{
	u32 current_index = 0;
	for (int i = 0; i < mapTiles.length; i++)
	{
		string[]@ data = mapTiles[i].split(" ");
		if (data.length != 2) continue;

		const int tile_type = parseInt(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			map.SetTile(current_index++, tile_type);
		}
	}
}

void LoadDirt(CMap@ map, const string[]&in mapTiles)
{
	u32 current_index = 0;
	for (int i = 0; i < mapTiles.length; i++)
	{
		string[]@ data = mapTiles[i].split(" ");
		if (data.length != 2) continue;

		const bool is_dirt = parseBool(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			if (is_dirt)
			{
				map.SetTileDirt(current_index, 80);
			}
			current_index++;
		}
	}
}

void LoadWater(CMap@ map, const string[]&in mapTiles)
{
	u32 current_index = 0;
	for (int i = 0; i < mapTiles.length; i++)
	{
		string[]@ data = mapTiles[i].split(" ");
		if (data.length != 2) continue;

		const bool has_water = parseBool(data[0]);
		const int tile_count = parseInt(data[1]);

		for (int j = 0; j < tile_count; j++)
		{
			map.server_setFloodWaterOffset(current_index++, has_water);
		}
	}
}

void LoadBlobs(CMap@ map, const string&in blobData, CBlob@[]@ loaded_blobs)
{
	// each blob is separated by 2x semicolon
	const string[]@ blobs = blobData.split(";;");

	for (int i = 0; i < blobs.length; i++)
	{
		if (blobs[i].isEmpty()) continue;

		string[]@ data = blobs[i].split(";");
		if (data.length == 0) continue;

		const string name = data[0];
		const Vec2f pos(parseFloat(data[1]), parseFloat(data[2]));
		BlobDataHandler@ handler = getBlobHandler(name);

		CBlob@ blob = handler.CreateBlob(name, pos, data);
		loaded_blobs.push_back(blob);

		if (blob is null) { error("MapSaver: Failed to load blob '"+name+"'"); continue; }

		handler.LoadBlobData(blob, data);
	}
}

void LoadInventories(CMap@ map, const string&in inventoryData, CBlob@[]@ loaded_blobs)
{
	const string[]@ pairs = inventoryData.split(";");
	for (int i = 0; i < pairs.length; i++)
	{
		const string[]@ indices = pairs[i].split(" ");
		if (indices.length != 2) return;

		CBlob@ blob = loaded_blobs[parseInt(indices[0])];
		CBlob@ parent = loaded_blobs[parseInt(indices[1])];
		if (blob is null || parent is null) continue;

		parent.server_PutInInventory(blob);
	}
}

void LoadAttachments(CMap@ map, const string&in attachmentData, CBlob@[]@ loaded_blobs)
{
	const string[]@ pairs = attachmentData.split(";");
	for (int i = 0; i < pairs.length; i++)
	{
		const string[]@ indices = pairs[i].split(" ");
		if (indices.length != 3) return;

		CBlob@ blob = loaded_blobs[parseInt(indices[0])];
		CBlob@ parent = loaded_blobs[parseInt(indices[1])];
		const int ap_index = parseInt(indices[2]);
		if (blob is null || parent is null) continue;

		blob.server_AttachTo(parent, ap_index);
	}
}
