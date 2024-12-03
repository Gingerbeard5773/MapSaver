// SonantDread & Gingerbeard @ November 14th 2024

#include "MakeScroll.as";
#include "MakeSeed.as";
#include "MakeCrate.as";

/*
 HOW TO SAVE CUSTOM BLOB DATA FOR YOUR MOD
 1) Create a blob handler class for your blob, with the applicable functions.
 2) Then set the class with the associated blob name into InitializeBlobHandlers().
 3) Delete the save file every time you modify blob handlers- doing this will avoid crashes caused by faulty data reading
*/

const string SaveFile = "MapSaver_Save"; //MODIFY THIS TO ENSURE NO OTHER MODS OVERWRITE

dictionary blobHandlers;
void InitializeBlobHandlers()
{
	if (blobHandlers.getSize() != 0) return;

	blobHandlers.set("default",    BlobDataHandler());
	blobHandlers.set("seed",       SeedBlobHandler());
	blobHandlers.set("crate",      CrateBlobHandler());
	blobHandlers.set("scroll",     ScrollBlobHandler());
	blobHandlers.set("lever",      LeverBlobHandler());

	blobHandlers.set("tree_bushy", TreeBlobHandler());
	blobHandlers.set("tree_pine",  TreeBlobHandler());
}

bool canSaveBlob(CBlob@ blob)
{
	if (blob.hasTag("temp blob") || blob.hasTag("dead") || blob.hasTag("projectile")) return false;

	if (blob.getPlayer() !is null) return false;

	return true;
}

BlobDataHandler@ basicHandler = BlobDataHandler();
class BlobDataHandler
{
	// Write our blob's information into the config
	// Each piece of data must be divided by the token ';'
	string Serialize(CBlob@ blob)
	{
		string data = blob.getName() + ";";
		CShape@ shape = blob.getShape();
		Vec2f pos = blob.getPosition();
		data += pos.x + ";" + pos.y + ";";
		data += blob.getHealth() + ";";
		data += blob.getTeamNum() + ";";
		data += shape !is null && shape.isStatic() ? "1;" : "0;";
		data += blob.getAngleDegrees() + ";";
		data += blob.getQuantity() + ";";
		data += blob.isFacingLeft() ? "1;" : "0;";
		return data;
	}

	// Creation protocols for the particular blob
	// Necessary because some blobs must have data set to the blob *before* the blob is initialized. 
	CBlob@ CreateBlob(const string&in name, const Vec2f&in pos, const string[]@ data)
	{
		return server_CreateBlob(name, 0, pos);
	}

	// Load in any special properties/states for the particular blob
	// Note; all other classes will need updated if you change the amount of data that is processed in this base class
	void LoadBlobData(CBlob@ blob, const string[]@ data)
	{
		const f32 health = parseFloat(data[3]);
		const int team = parseInt(data[4]);
		const bool isStatic = parseBool(data[5]);
		const f32 angle = parseFloat(data[6]);
		const u16 quantity = parseInt(data[7]);
		const bool facingLeft = parseBool(data[8]);

		blob.server_SetHealth(health);
		blob.server_setTeamNum(team);
		blob.setAngleDegrees(angle);

		CShape@ shape = blob.getShape();
		if (shape !is null)
		{
			shape.SetStatic(isStatic);
		}

		blob.server_SetQuantity(quantity);
		blob.SetFacingLeft(facingLeft);
	}
}

class SeedBlobHandler : BlobDataHandler
{
	string Serialize(CBlob@ blob) override
	{
		string data = basicHandler.Serialize(blob);
		data += blob.get_string("seed_grow_blobname") + ";";
		return data;
	}

	CBlob@ CreateBlob(const string&in name, const Vec2f&in pos, const string[]@ data) override
	{
		const string seedName = data[9];
		return server_MakeSeed(pos, seedName);
	}
}

class CrateBlobHandler : BlobDataHandler
{
	string Serialize(CBlob@ blob) override
	{
		string data = basicHandler.Serialize(blob);
		const string packed = blob.exists("packed") ? blob.get_string("packed") : "";
		if (!packed.isEmpty())
		{
			data += packed + ";";
		}
		return data;
	}

	CBlob@ CreateBlob(const string&in name, const Vec2f&in pos, const string[]@ data) override
	{
		CBlob@ crate = server_CreateBlobNoInit("crate");
		crate.setPosition(pos);
		const string packed = data.length > 9 ? data[9] : "";
		if (!packed.isEmpty())
		{
			crate.set_string("packed", packed);
		}
		crate.Init();
		return crate;
	}
}

class ScrollBlobHandler : BlobDataHandler
{
	string Serialize(CBlob@ blob) override
	{
		string data = basicHandler.Serialize(blob);
		data += blob.get_string("scroll defname0") + ";";
		return data;
	}

	CBlob@ CreateBlob(const string&in name, const Vec2f&in pos, const string[]@ data) override
	{
		const string scroll_name = data[9];
		return server_MakePredefinedScroll(pos, scroll_name);
	}
}

class LeverBlobHandler : BlobDataHandler
{
	string Serialize(CBlob@ blob) override
	{
		string data = basicHandler.Serialize(blob);
		data += (blob.get_bool("activated") ? "1;" : "0;");
		return data;
	}

	void LoadBlobData(CBlob@ blob, const string[]@ data) override
	{
		basicHandler.LoadBlobData(blob, data);
		const bool activated = parseBool(data[9]);
		blob.set_bool("activated", activated);
	}
}

class TreeBlobHandler : BlobDataHandler
{
	CBlob@ CreateBlob(const string&in name, const Vec2f&in pos, const string[]@ data) override
	{
		CBlob@ blob = server_CreateBlobNoInit(name);
		blob.setPosition(pos);
		blob.Tag("startbig");
		blob.Init();
		return blob;
	}
}

BlobDataHandler@ getBlobHandler(const string&in name)
{
	BlobDataHandler@ handler;
	if (!blobHandlers.get(name, @handler))
	{
		blobHandlers.get("default", @handler);
	}

	return handler;
}

bool parseBool(const string&in data)
{
	return data == "1";
}
