// Gingerbeard @ November 23, 2024

//this script MUST be the last script to be called in gamemode.cfg

#include "MapSaver.as";

void onInit(CRules@ this)
{
	Reset(this);

	const string savemap = "!savemap [save slot] : save a map to a slot";
	const string loadmap = "!loadsave [save slot] : load a map from a slot";
	client_AddToChat(savemap, 0xff6678FF);
	client_AddToChat(loadmap, 0xff6678FF);
	print(savemap, 0xff66C6FF);
	print(loadmap, 0xff66C6FF);
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void Reset(CRules@ this)
{
	LoadSavedRules(this, getMap());
}

bool onServerProcessChat(CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player)
{
	if (textIn.substr(0, 1) == "!")
	{
		const string[]@ tokens = textIn.split(" ");
		if (tokens[0] == "!savemap")
		{
			const u8 SaveSlot = tokens.length > 1 ? parseInt(tokens[1]) : 0;
			print("Map saved to your cache: Slot [ "+SaveSlot+" ]", 0xff66C6FF);
			SaveMap(getMap(), SaveSlot);
			return false;
		}
		else if (tokens[0] == "!loadsave")
		{
			const u8 SaveSlot = tokens.length > 1 ? parseInt(tokens[1]) : 0; 
			this.set_u8("mapsaver_save_slot", SaveSlot);
			this.set_bool("loaded_saved_map", false);
			LoadNextMap();
			return false;
		}
	}

	return true;
}
