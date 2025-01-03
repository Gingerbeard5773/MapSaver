// Gingerbeard @ November 23, 2024

//this script MUST be the last script to be called in gamemode.cfg

#include "MapSaver.as";

void onInit(CRules@ this)
{
	Reset(this);

	const string savemap = "!savemap [save name] : save a map to a slot";
	const string loadmap = "!loadsave [save name] : load a map from a slot";
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
			const string SaveSlot = tokens.length > 1 ? tokens[1] : "AutoSave";
			const string message = "Map saved to your cache- Name: "+SaveSlot;
			print(message, 0xff66C6FF);
			client_AddToChat(message, 0xff6678FF);
			SaveMap(this, getMap(), SaveSlot);
			return false;
		}
		else if (tokens[0] == "!loadsave")
		{
			const string SaveSlot = tokens.length > 1 ? tokens[1] : "AutoSave"; 
			this.set_string("mapsaver_save_slot", SaveSlot);
			this.set_bool("loaded_saved_map", false);
			LoadNextMap();
			return false;
		}
	}

	return true;
}
