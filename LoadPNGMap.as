// loads a classic KAG .PNG map
// fileName is "" on client!

#include "BasePNGLoader.as";
#include "MinimapHook.as";
#include "MapSaver.as";

bool LoadMap(CMap@ map, const string& in fileName)
{
	PNGLoader loader();

	if (!isServer())
	{
		map.CreateTileMap(0, 0, 8.0f, "Sprites/world.png");
	}

	SetupBackground(map);

	if (LoadSavedMap(getRules(), map))
	{
		print("LOADING SAVED MAP", 0xff66C6FF);
		return true;
	}

	MiniMap::Initialise();

	print("LOADING PNG MAP " + fileName);
	return loader.loadMap(map, fileName);
}

void SetupBackground(CMap@ map)
{
	// sky
	map.CreateSky(color_black, Vec2f(1.0f, 1.0f), 200, "Sprites/Back/cloud", 0);
	map.CreateSkyGradient("Sprites/skygradient.png"); // override sky color with gradient

	// background
	map.AddBackground("Sprites/Back/BackgroundPlains.png", Vec2f(0.0f, -40.0f), Vec2f(0.06f, 20.0f), color_white);
	map.AddBackground("Sprites/Back/BackgroundTrees.png", Vec2f(0.0f,  -100.0f), Vec2f(0.18f, 70.0f), color_white);
	map.AddBackground("Sprites/Back/BackgroundIsland.png", Vec2f(0.0f, -220.0f), Vec2f(0.3f, 180.0f), color_white);

	// fade in
	SetScreenFlash(255,   0,   0,   0);
}