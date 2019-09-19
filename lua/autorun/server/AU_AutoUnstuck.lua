-------------------------------------------------
-- Auto Unstuck developed by: Ethorbit, inspired 
-- by servers that have abusable !stuck commands
-------------------------------------------------
local ToggleAddon = CreateConVar("AutoUnstuck_Enabled", 1, FCVAR_SERVER_CAN_EXECUTE, "Enables/Disables the Auto Unstuck addon")
local AnnounceTPs = CreateConVar("AutoUnstuck_Announce", 1, FCVAR_SERVER_CAN_EXECUTE, "Announce to everyone in the server if a player is teleported for being stuck")
local TpIfOwnProps = CreateConVar("AutoUnstuck_If_PersonalEnt", 1, FCVAR_SERVER_CAN_EXECUTE, "Auto Unstuck if someone is stuck in their own stuff (If on, players can easily abuse it to teleport themselves)")
local TpIfAdmin = CreateConVar("AutoUnstuck_If_Admin", 1, FCVAR_SERVER_CAN_EXECUTE, "Auto Unstuck even if the they are an administrator")
local TPNearNPCs = CreateConVar("AutoUnstuck_NearNPCs", 1, FCVAR_SERVER_CAN_EXECUTE, "Automatically unstuck players at an AutoUnstuck_TPEntityClass spot that isn't near NPCs")
local NPCDisallowDist = CreateConVar("AutoUnstuck_NPC_Distance", 500, FCVAR_SERVER_CAN_EXECUTE, "Avoid teleporting players to an AutoUnstuck_TPEntityClass location if NPCs are this far away from them")
local IgnorePlayers = CreateConVar("AutoUnstuck_IgnorePlayers", 0, FCVAR_SERVER_CAN_EXECUTE, "Ignore players getting stuck in other players (If not then players can force teleports on people by noclipping inside them)")
local TimeBeforeTP = CreateConVar("AutoUnstuck_TimeForTP", 3, FCVAR_SERVER_CAN_EXECUTE, "The time (in seconds) before the stuck player is teleported")
local EntToTPTo = CreateConVar("AutoUnstuck_TPEntityClass", "info_player_start", FCVAR_SERVER_CAN_EXECUTE, "The entity classname to teleport the players to when they are stuck")
local TPSpots = {}

cvars.AddChangeCallback("AutoUnstuck_Enabled", function()
    if ToggleAddon:GetInt() < 1 then 
        print("[AU] Auto Unstuck has been disabled")
    else
        print("[AU] Auto Unstuck has been enabled")
    end
end)

local function AUAddEnts()
    TPSpots = {}       
    local TPClass = EntToTPTo:GetString() -- The AutoUnstuck_TPEntityClass ConVar
    local EntsWithTPClass = ents.FindByClass(TPClass)

    if table.Count(EntsWithTPClass) == 0 then -- If an entity with the classname from AutoUnstuck_TPEntityClass ConVar doesn't exist on the map
        for k,v in pairs(ents.GetAll()) do -- Add any info_player entity to the TPSpots table
            if string.find(v:GetClass(), "info_player") then 
                table.insert(TPSpots, v) 
            end
        end
        EntToTPTo:SetString("info_player_*") -- Just to show them their value was overwritten
        print("[AutoUnstuck] The specified entity classname from AutoUnstuck_TPEntityClass is either incorrect or none were found on the map! Using all info_player entities instead..")
    else 
        for k,v in pairs(EntsWithTPClass) do -- For every entity with the classname defined in the ConVar 'AutoUnstuck_TPEntityClass'
            table.insert(TPSpots, v) -- Add each entity to table for unstuck teleportation positions
        end
    end
end

local function RemoveFromTPList(ent) -- A necessity especially for TTT
    table.RemoveByValue(TPSpots, ent)
end
hook.Add("EntityRemoved", "AU_EntWasRemoved", RemoveFromTPList)

local function FirstPlayerSpawn()
    if table.Count(TPSpots) > 0 then return end -- In TTT this hook was called more than once, so stop it if it does
    AUAddEnts() 
end
hook.Add("PlayerInitialSpawn", "AU_PlySpwnedFirstTime", FirstPlayerSpawn)

cvars.AddChangeCallback("AutoUnstuck_TPEntityClass", function() 
    if EntToTPTo:GetString() == "info_player_*" then return end -- This is the class that is auto set if the AutoUnstuck_TPEntityClass doesn't exist
    AUAddEnts() 
end)

local function TraceBoundingBox(ply) -- Check if player is blocked using a trace based off player's Bounding Box (Supports all player sizes and models)
    -- Maxs and Mins equation that works with all player sizes (ply:GetModelBounds() would not be good enough):
    local Maxs = Vector(ply:OBBMaxs().X / ply:GetModelScale(), ply:OBBMaxs().Y / ply:GetModelScale(), ply:OBBMaxs().Z / ply:GetModelScale()) 
    local Mins = Vector(ply:OBBMins().X / ply:GetModelScale(), ply:OBBMins().Y / ply:GetModelScale(), ply:OBBMins().Z / ply:GetModelScale())

    local Trace = {    
        start = ply:GetPos(),
        endpos = ply:GetPos(),
        maxs = Maxs, -- Exactly the size the player uses to collide with stuff
        mins = Mins, -- ^
        collisiongroup = COLLISION_GROUP_PLAYER, -- Collides with stuff that players collide with
        filter = function(ent) -- Slow but necessary
            if IgnorePlayers:GetInt() > 0 and ent:IsPlayer() then return end -- The ent is a different player (AutoUnstuck_IgnorePlayers ConVar)
     
            local AUBlockOwnProp = true
            if TpIfOwnProps:GetInt() > 0 then -- Allow player to get unstuck from their own entity (if AutoUnstuck_If_PersonalEnt ConVar is on)
                AUBlockOwnProp = true
            else           
                AUBlockOwnProp = ent:GetNWEntity("AUPropOwner") != ply
            end

            if ent:GetCollisionGroup() != 20 and -- The ent can collide with the player that is stuck
            ent != ply and -- The ent is not the player that is stuck
            AUBlockOwnProp then return true end -- The ent is not owned by the player that is stuck (AutoUnstuck_If_PersonalEnt ConVar)
        end
    }
    
    return util.TraceHull(Trace).Hit, AUHitPlayer
end

local function PlayerIsStuck(ply) 
    if ply:GetMoveType() != MOVETYPE_NOCLIP then -- Player is not flying through stuff
        if TraceBoundingBox(ply) then -- The player is blocked by something
            return true
        end
    end
end

local function AnnounceTP(ply)
    if AnnounceTPs:GetInt() < 1 then return end -- AutoUnstuck_Announce ConVar
    local AnnounceString = string.format("[AU] %s %s", ply:Nick(), "was teleported because they were stuck!")
    for k,v in pairs(player.GetAll()) do
        if v != ply then  -- Don't announce to the player that was teleported  
            v:ChatPrint(AnnounceString)
        end
    end
end

local function AUSendPlyToSpot(ply, spot) 
    if !ply:IsValid() then return end
    if !ply:Alive() then ply:ChatPrint("[AU] Teleport aborted.") return end
    if !spot:IsValid() then 
        print("[AutoUnstuck] A TP spot was invalid! Adding entities to TPSpots again...") 
        AUAddEnts() 
    return end

    ply:SetPos(spot:GetPos() + Vector(0,0,2)) 
    ply:SetEyeAngles(Angle(0,0,0)) -- Reset their view angles
    ply:ChatPrint("[AU] Auto Unstuck has teleported you out.")
    AnnounceTP(ply)
end

local TpAwayFromNPCDelay = 0
local function AUPickTPSpot(ply) 
    if CurTime() < TpAwayFromNPCDelay then return end -- Only happens if AutoUnstuck_NearNPCs ConVar is on

    local RandomTPSpot = table.Random(TPSpots)    
    if table.Count(TPSpots) == 0 then -- This can happen if the lua file is reloaded at runtime
        AUAddEnts() 
        AUPickTPSpot(ply)
    return end

    if TPNearNPCs:GetInt() > 0 then -- AutoUnstuck_NearNPCs ConVar is on
        AUSendPlyToSpot(ply, RandomTPSpot)
    else
        TpAwayFromNPCDelay = CurTime() + 10 -- Big enough delay to stop teleportation spam
        local AvailableTPSpots = {} -- Spots that don't have NPCs near them

        for i = 1,table.Count(TPSpots) do -- For each TP spot
            local EntsNearSpot = ents.FindInSphere(TPSpots[i]:GetPos(), NPCDisallowDist:GetInt()) -- Check each TP spot for NPCs
            
            if !string.find(table.ToString(EntsNearSpot), "npc_") then -- If there are no entities with npc_ in the names
                table.insert(AvailableTPSpots, TPSpots[i])
            end

            if i == table.Count(TPSpots) then -- If all teleport spots have NPCs near them
                if table.Count(AvailableTPSpots) > 0 then -- A spot(s) away from NPCs exists
                    AUSendPlyToSpot(ply, table.Random(AvailableTPSpots))
                    TpAwayFromNPCDelay = 0   
                else
                    ply:ChatPrint("[AU] Tried to TP you to a spot away from NPCs, but there were none!")
                    AUSendPlyToSpot(ply, RandomTPSpot)    
                    TpAwayFromNPCDelay = 0  
                end
            end
        end
    end
end

local function SetCollisionCheck(createdEnt)
    if createdEnt:IsPlayer() then
        createdEnt:SetCustomCollisionCheck(true) -- Allow the player to be checked in the ShouldCollide hook
    end
end
hook.Add("OnEntityCreated", "AU_EntWasCreated", SetCollisionCheck)

local function EntShouldCollide(ent1, ent2)   
    if ToggleAddon:GetInt() < 1 then return end -- AutoUnstuck_Enabled ConVar
    if !ent1:IsValid() then return end
    if !ent2:IsValid() and !ent2:IsWorld() then return end 
    if TpIfAdmin:GetInt() < 1 and ent1:IsAdmin() then return end -- Stop admins from being tp'd for being stuck (If AutoUnstuck_If_Admin is off)    

    if ent1:IsPlayer() and ent1:Alive() and ent1:GetVehicle() == NULL then 
        if ent1.jail then return end -- Player is ULX Jailed, if stuck in jail it would cause a teleportation loop spamming chat
        local TimerName = string.format("AU_Tp%s", ent1:UserID()) 

        if !PlayerIsStuck(ent1) and timer.Exists(TimerName) then -- Make sure to remove their timer if they aren't stuck anymore
            timer.Remove(TimerName)
            ent1:ChatPrint("[AU] You are no longer determined to be stuck.")
        end
        
        if ent1:GetVelocity().x == 0 and ent2:GetVelocity().x == 0 then -- Both entities are not moving
            if PlayerIsStuck(ent1) then
                if timer.Exists(TimerName) then return end
                ent1:ChatPrint("[AU] Auto Unstuck has determined you're stuck, try moving...")                        
                
                timer.Create(TimerName, TimeBeforeTP:GetInt(), 1, function() -- Timer's time based on AutoUnstuck_TimeForTP ConVar
                    if !ent1:IsValid() then return end -- It's possible they could've left the server before the timer finished
                    if PlayerIsStuck(ent1) then 
                        AUPickTPSpot(ent1) 
                    end               
                end)
            end   
        end
    end
end
hook.Add("ShouldCollide", "AU_EntityIsColliding", EntShouldCollide)

local function MakeEntOwnership(ply, model, spawnedEnt)
    if !spawnedEnt:IsValid() then return end
    spawnedEnt:SetNWEntity("AUPropOwner", ply) -- Save ent owner for use with the AutoUnstuck_If_PersonalEnt ConVar later
end
local function MakeEntOwnership2(ply, spawnedEnt)
    if !spawnedEnt:IsValid() then return end
    spawnedEnt:SetNWEntity("AUPropOwner", ply) 
end
hook.Add("PlayerSpawnedProp", "AU_PlySpawnedProp", MakeEntOwnership)
hook.Add("PlayerSpawnedRagdoll", "AU_PlySpawnedRagdoll", MakeEntOwnership)
hook.Add("PlayerSpawnedVehicle", "AU_PlySpawnedVehicle", MakeEntOwnership2)
hook.Add("PlayerSpawnedSENT", "AU_PlySpawnedSENT", MakeEntOwnership2)
hook.Add("PlayerSpawnedNPC", "AU_PlySpawnedNPC", MakeEntOwnership2)