# **Map Saver**

The Map Saver is a tool for [King Arthur's Gold](https://github.com/transhumandesign/kag-base) that allows maps to be saved and then loaded at a later time, bypassing server shutdowns, crashes, and network failures.

## What can it save?
* Tiles and tile damage.
* Blobs and their unique data/states. Attachments, inventories, etc.
* Rules information such as day time.
* Anything else specific that you add into the saver's logic.

## How it works
The tool functions by serializing map information and blob information to a `.cfg` file, which is saved to your cache. The tool also allows for multiple saves to be created. Each save is its own `.cfg` file.

## How to use
The files provided here are not meant to be the final product. Modders will have to edit the files for their own mod's needs—such as by adding in the missing 'autosave' system or adding in handlers for their mod's blobs.  
For an example of a mod with a complete implementation, visit [Zombies Reborn](https://github.com/Gingerbeard5773/Zombies_Reborn)—which is the mod that this tool was originally created for.

To try out the tool, two chat commands are provided:

- `!savemap [save slot]`  
  Save the current map to the specified save slot.

- `!loadsave [save slot]`  
  Load the map from the specified save slot.

## Credits
- SonantDread
- Gingerbeard
