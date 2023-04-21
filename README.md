# Auto-Unstuck
Auto Unstuck is a server addon that detects whenever a player is stuck. It is very good at detecting this as it uses the player's bounding box which is what players use for collisions.

When a player is detected as being stuck, Auto Unstuck will wait a few seconds (3 by default) warning the player first and will then teleport the player out.

[![Video Preview](video_preview.png)](https://www.youtube.com/watch?v=NA_v0GNkiCE "Auto Unstuck Preview")

## Console Commands:
* AutoUnstuck_Enabled <0/1> 

* AutoUnstuck_TPNearSpot <0/2> (2 by default) - On 1 Auto Unstuck will TP the player to the closest available navmesh outside of obstruction, 2 will teleport the player to the last place they were NOT stuck at. (If there's no navmesh on the map, 2 will be used anyway)

* AutoUnstuck_TPEntityClass <entity classname> (info_player_start by default ) - the entities' classname Auto Unstuck should pick randomly for players to teleport to when they are stuck

* AutoUnstuck_TimeForTP <seconds> (3 by default ) - The amount of seconds Auto Unstuck should wait for before teleporting the player

* AutoUnstuck_Announce <0/1> (1 by default ) - If on will put [AU]<Name> was teleported because they were stuck! in the chat whenever someone is teleported

* AutoUnstuck_If_PersonalEnt <0/1> (1 by default ) - If off, Auto Unstuck will not do anything if the person that is stuck is inside their own entity

* AutoUnstuck_If_Admin <0/1> (1 by default ) - If off, Auto Unstuck won't do anything if the person that is stuck is an administrator on the server

* AutoUnstuck_NearNPCs <0/1> (1 by default)  - If off, Auto Unstuck will attempt to find a TP spot that is away from NPCs

* AutoUnstuck_NPC_Distance <number> (500 by default) - The distance Auto Unstuck will try to avoid teleporting the player to (if AutoUnstuck_NearNPCs is set to 0)
  
## Developer lua Hooks
You can use these hooks to run your own code on AU events (https://wiki.facepunch.com/gmod/Hook_Library_Usage)
* AU.PlayerStuck ( ply ) - When it detects a player as being stuck
* AU.PlayerNoLongerStuck ( ply )
* AU.PlayerTeleported ( ply, pos )
* AU.CanHandlePlayer ( ply ) - Return false to disable detection on the player
  
## Supports many popular gamemodes!
Auto Unstuck functions as intended for Sandbox, DarkRP, TTT, Murder, nZombies, Zombie Survival and many others!

## Compatible with any playermodel!
Tested with many different playermodels from the workshop, Auto Unstuck is guaranteed to work fine on all servers including DarkRP ones that use plenty of different jobs.

## Compatible with any player scale!
Auto Unstuck will calculate the correct size should the player ever get too big. Tested from scale 0.1 to 30!

## Compatible with any map!
Auto Unstuck will still be able to teleport players even if the AutoUnstuck_TPEntityClass does not exist on the map as long as there's a spawn point on it.

## Auto Unstuck is NOT compatible with the following:
Gamemodes that replace the player entity (Like Prop Hunt, Ragdoll Combat, etc)
