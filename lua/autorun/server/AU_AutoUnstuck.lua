-------------------------------------------------
-- Auto Unstuck developed by: Ethorbit, inspired 
-- by servers that have abusable !stuck commands
-------------------------------------------------
local ToggleAddon = CreateConVar("AutoUnstuck_Enabled", 1, FCVAR_SERVER_CAN_EXECUTE, "Enables/Disables the Auto Unstuck addon")
local AnnounceTPs = CreateConVar("AutoUnstuck_Announce", 1, FCVAR_SERVER_CAN_EXECUTE, "Announce to everyone in the server if a player is teleported for being stuck")
local TPNearStuckSpot = CreateConVar("AutoUnstuck_TPNearSpot", 1, FCVAR_SERVER_CAN_EXECUTE, "Teleport players to the closest location that they got stuck at (Will not work if the map has no navigation mesh. Generate one with nav_generate)")
local TpIfOwnProps = CreateConVar("AutoUnstuck_If_PersonalEnt", 1, FCVAR_SERVER_CAN_EXECUTE, "Auto Unstuck if someone is stuck in their own stuff (If on, players can easily abuse it to teleport themselves)")
local TpIfAdmin = CreateConVar("AutoUnstuck_If_Admin", 1, FCVAR_SERVER_CAN_EXECUTE, "Auto Unstuck even if the they are an administrator")
local TPNearNPCs = CreateConVar("AutoUnstuck_NearNPCs", 1, FCVAR_SERVER_CAN_EXECUTE, "Automatically unstuck players at an AutoUnstuck_TPEntityClass spot that isn't near NPCs")
local NPCDisallowDist = CreateConVar("AutoUnstuck_NPC_Distance", 500, FCVAR_SERVER_CAN_EXECUTE, "Avoid teleporting players to an AutoUnstuck_TPEntityClass location if NPCs are this far away from them")
local IgnorePlayers = CreateConVar("AutoUnstuck_IgnorePlayers", 0, FCVAR_SERVER_CAN_EXECUTE, "Ignore players getting stuck in other players (If not then players can force teleports on people by noclipping inside them)")
local TimeBeforeTP = CreateConVar("AutoUnstuck_TimeForTP", 3, FCVAR_SERVER_CAN_EXECUTE, "The time (in seconds) before the stuck player is teleported")
local EntToTPTo = CreateConVar("AutoUnstuck_TPEntityClass", "info_player_start", FCVAR_SERVER_CAN_EXECUTE, "The entity classname to teleport the players to when they are stuck")
local TPSpots = {}
local AU_OriginalTPClass = ""
local ExcludeSpawnerTime = 2 -- Amount of seconds to exclude Auto Unstuck for players who spawn
local ExcludedPlayers = {} // Player Meta table was not working

local function PlayerSpawned(ply)
    table.insert(ExcludedPlayers, ply:EntIndex())
    timer.Simple(ExcludeSpawnerTime, function()
        table.RemoveByValue(ExcludedPlayers, ply:EntIndex())
    end)
end
hook.Add("PlayerSpawn", "AU_PlyHasSpawned", PlayerSpawned)

cvars.AddChangeCallback("AutoUnstuck_Enabled", function()
    if ToggleAddon:GetInt() < 1 then 
        print("[AU] Auto Unstuck has been disabled")
    else
        print("[AU] Auto Unstuck has been enabled")
    end
end)

local function AddToTPSpots(entTable) -- To cut down on the amount of identical pair loops   
    if istable(entTable) then 
        for k,v in pairs(entTable) do
            if v != nil then   
                table.insert(TPSpots, v) 
            end
        end
    end
end

local function AUAddEnts()
    TPSpots = {} 

    if TPNearStuckSpot:GetInt() > 0 and table.Count(navmesh.GetAllNavAreas()) < 1 then
        print("[AutoUnstuck] There is no navigation mesh on this map! Do nav_generate to generate the nav mesh, you only need to do it once per map! Using TPEntityClass entities instead..")
    end

    local TPClass = EntToTPTo:GetString() -- The AutoUnstuck_TPEntityClass ConVar
    local EntsWithTPClass = ents.FindByClass(TPClass)

    if table.Count(EntsWithTPClass) == 0 then -- If an entity with the classname from AutoUnstuck_TPEntityClass ConVar doesn't exist on the map
        if AU_OriginalTPClass != "info_player_*" then
            AU_OriginalTPClass = EntToTPTo:GetString()
        end
        
        AddToTPSpots(ents.FindByClass("info_player_*")) 
        EntToTPTo:SetString("info_player_*") -- Just to show them their value was overwritten
        print("[AutoUnstuck] The specified entity classname from AutoUnstuck_TPEntityClass is either incorrect or none were found on the map! Using all info_player entities instead..")
    else -- Using navs instead
        AddToTPSpots(EntsWithTPClass)
    end
end

local function FirstPlayerSpawn()
    if table.Count(TPSpots) > 0 then return end -- In TTT this hook was called more than once, so stop it if it does
    AUAddEnts() 
end
hook.Add("PlayerInitialSpawn", "AU_PlySpwnedFirstTime", FirstPlayerSpawn)

cvars.AddChangeCallback("AutoUnstuck_TPEntityClass", function() 
    if EntToTPTo:GetString() == "info_player_*" then return end -- This is the class that is auto set if the AutoUnstuck_TPEntityClass doesn't exist
    AUAddEnts() 
end)

local function RemoveFromTPList(ent) -- A necessity especially for TTT
    table.RemoveByValue(TPSpots, ent)
end
hook.Add("EntityRemoved", "AU_EntWasRemoved", RemoveFromTPList)

-- local function AnotherPlyClose(ply, boolean) -- Source engine is stupid and thinks clip brushes are the player themselves, so this needs to be done
--     local entsNearPly = ents.FindInSphere(ply:GetPos(), 50)
--     if entsNearPly == nil then return end

--     local entsDetected = {}
--     for k,v in pairs(entsNearPly) do
--         if v:IsPlayer() and v != ply then 
--             table.insert(entsDetected, v)
--         end
--     end

--     return table.Count(entsDetected) > 0
-- end

local function TraceBoundingBox(ply) -- Check if player is blocked using a trace based off player's Bounding Box (Supports all player sizes and models)
    // Maxs and Mins equation that works with all player sizes (ply:GetModelBounds() would not be good enough):
    local Maxs = Vector(ply:OBBMaxs().X / ply:GetModelScale(), ply:OBBMaxs().Y / ply:GetModelScale(), ply:OBBMaxs().Z / ply:GetModelScale()) 
    local Mins = Vector(ply:OBBMins().X / ply:GetModelScale(), ply:OBBMins().Y / ply:GetModelScale(), ply:OBBMins().Z / ply:GetModelScale())

    local Trace = {    
        start = ply:GetPos(),
        endpos = ply:GetPos(),
        maxs = Maxs, -- Exactly the size the player uses to collide with stuff
        mins = Mins, -- ^
        collisiongroup = COLLISION_GROUP_PLAYER, -- Collides with stuff that players collide with
        filter = function(ent) -- Slow but necessary
            --if ent == ply and ply:GetVelocity().z == -4.5 and !AnotherPlyClose(ply) then return true end -- Will make addon compatible with clip brushes again
            if IgnorePlayers:GetInt() > 0 and ent:IsPlayer() then return end -- The ent is a different player (AutoUnstuck_IgnorePlayers ConVar)

            local AUBlockOwnProp = true
            if TpIfOwnProps:GetInt() > 0 then -- Allow player to get unstuck from their own entity (if AutoUnstuck_If_PersonalEnt ConVar is on)
                AUBlockOwnProp = true
            else           
                AUBlockOwnProp = ent:GetNWEntity("AUPropOwner") != ply
            end

            if (ent:BoundingRadius() <= 60) then return end -- Stops triggering Auto Unstuck due to tiny entities
            if ent:GetCollisionGroup() != 20 and -- The ent can collide with the player that is stuck
            ent != ply and -- The ent is not the player that is stuck
            AUBlockOwnProp then return true end -- The ent is not owned by the player that is stuck (AutoUnstuck_If_PersonalEnt ConVar)
        end
    }
        
    return util.TraceHull(Trace).Hit
end

hook.Add("PlayerRevived", "AUExcludeRevivedPlys", function(ply) -- Exclude revived players to avoid unnecessary unstuck
    table.insert(ExcludedPlayers, ply:EntIndex())

    timer.Simple(2, function()
        if !IsValid(ply) then return end
        table.RemoveByValue(ExcludedPlayers, ply:EntIndex())
    end)
end)

local function PlayerIsStuck(ply) 
    -- Don't teleport players for being stuck while they are down:
    if gmod.GetGamemode().Name == "nZombies" then
        if !ply:GetNotDowned() then return false end
    end

    if table.HasValue(ExcludedPlayers, ply:EntIndex()) then return false end 

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

local AUPickTPSpot, AU_InvalidTPSpot -- Define at same time so they can call eachother
function AU_InvalidTPSpot(ply)
    print("[AutoUnstuck] A TP spot was invalid! Adding entities to TPSpots again...") 
    AUAddEnts() 
    AUPickTPSpot(ply) -- Don't let them just sit there being stuck
end

local TPdToSpot = Vector(0,0,0)
local function AUSendPlyToSpot(ply, spot) 
    local pos = 0

    if !ply:IsValid() then return end
    if !ply:Alive() then ply:ChatPrint("[AU] Teleport aborted.") return end

    if isvector(spot) then -- If AutoUnstuck_TPNearSpot ConVar is on then it gets nearest nav which is a position not an entity
        pos = spot
    else
        pos = spot:GetPos()
    end

    TPdToSpot = pos + Vector(0,0,2)
    ply:SetPos(pos + Vector(0,0,2)) -- up 2 on the z axis to fix spawning a tiny bit in the ground (map maker's fault)
    ply:SetEyeAngles(Angle(0,0,0)) -- Reset their view angles
    ply:ChatPrint("[AU] Auto Unstuck has teleported you out.")
    AnnounceTP(ply)
end

local function CheckNavForEnts(ply, pos)
    local NavTrace = {
        start = pos,
        endpos = pos,
        maxs = Vector(30, 30, 30), 
        mins = Vector(-30, -30, -30), 
        filter = ply, 
        collisiongroup = COLLISION_GROUP_PLAYER, -- Collides with stuff that players collide with
        ignoreworld = true -- The world will always be hit, but the player won't actually touch it
    }
    
    print(util.TraceHull(NavTrace).Entity)

    if util.TraceHull(NavTrace).Hit then
        local theTrace = util.TraceHull(NavTrace).Entity
        local traceClass = theTrace:GetClass()

        if string.find(traceClass, "brush") or theTrace:IsNPC() or theTrace:IsNextBot() then 
            return false
        else
            return util.TraceHull(NavTrace).Hit
        end
    end
end

local function SpotIsNearNPC(spot)
    local npcNear = false
    local EntsNearSpot = ents.FindInSphere(spot, NPCDisallowDist:GetInt()) -- Check each TP spot for NPCs

    for k,v in pairs(EntsNearSpot) do
        if v:IsNextBot() or v:IsNPC() then
            npcNear = true
            break
        end
    end

    return npcNear
end

local TpAwayFromNPCDelay = 0
local function AUPickSpotAwayFromNPCs(ply) -- Used internally by AUPickTPSpot
    local RandomTPSpot = table.Random(TPSpots)  
    if RandomTPSpot == nil then AU_InvalidTPSpot(ply) return end -- If it ever did happen a stack overflow would occur

    TpAwayFromNPCDelay = CurTime() + 10 -- Big enough delay to stop teleportation spam
    local AvailableTPSpots = {} -- Spots that don't have NPCs near them
    
    for i = 1, table.Count(TPSpots) do -- For each TP spot
        if !SpotIsNearNPC(TPSpots[i]:GetPos()) then
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

function AUPickTPSpot(ply) 
    local RandomTPSpot = table.Random(TPSpots)  
    if RandomTPSpot == nil then AU_InvalidTPSpot(ply) return end -- If it ever did happen a stack overflow would occur
    
    if CurTime() < TpAwayFromNPCDelay then return end -- Only happens if AutoUnstuck_NearNPCs ConVar is on
    
    if TPNearStuckSpot:GetInt() > 0 and table.Count(navmesh.GetAllNavAreas()) > 1 then -- AutoUnstuck_TPNearSpot ConVar is on
        local ClosestNav = navmesh.GetNearestNavArea(ply:GetPos())

        if !ClosestNav:GetCenter() then
            AUSendPlyToSpot(ply, RandomTPSpot)  
            ply:ChatPrint("[AU] Auto Unstuck tried to teleport you to the closest spot, but there was no nav area close by!")  
        else
            if SpotIsNearNPC(ClosestNav:GetCenter()) then
                ply:ChatPrint("[AU] An NPC is too close to the nearby spot, teleporting elsewhere!")
                AUPickSpotAwayFromNPCs(ply)  
            else if CheckNavForEnts(ply, ClosestNav:GetCenter()) then
                ply:ChatPrint("[AU] An entity is too close to the nearby spot, teleporting elsewhere!")
                AUSendPlyToSpot(ply, RandomTPSpot)
            else
                AUSendPlyToSpot(ply, ClosestNav:GetCenter())
            end
        end   
    end  
    return end

    if TPNearStuckSpot:GetInt() < 1 or TPNearStuckSpot:GetInt() > 0 and table.Count(navmesh.GetAllNavAreas()) < 1 then -- AutoUnstuck_TPNearSpot ConVar is off
        if table.Count(TPSpots) == 0 then -- This can happen if the lua file is reloaded at runtime
            AUAddEnts() 
            AUPickTPSpot(ply)
        return end

        if TPNearNPCs:GetInt() > 0 then -- AutoUnstuck_NearNPCs ConVar is on
            AUSendPlyToSpot(ply, RandomTPSpot)
        else
            AUPickSpotAwayFromNPCs(ply)
        end
    end
end

local function AU_EntWasCreated(createdEnt)
    -- Continuously check for TPEntityClass's existence if it's created after server start:
    if createdEnt:IsValid() then
        if string.lower(createdEnt:GetClass()) == string.lower(AU_OriginalTPClass) and string.lower(EntToTPTo:GetString()) != string.lower(AU_OriginalTPClass) then 
            print("[AutoUnstuck] The TPEntityClass entity just got created! Auto Unstuck will use this again.")
            EntToTPTo:SetString(AU_OriginalTPClass)
            AUAddEnts()
        end
    end

    if createdEnt:IsPlayer() then
        createdEnt:SetCustomCollisionCheck(true) -- Allow the player to be checked in the ShouldCollide hook
    end
end
hook.Add("OnEntityCreated", "AU_EntWasCreated", AU_EntWasCreated)

local function EntShouldCollide(ent1, ent2)   
    if ToggleAddon:GetInt() < 1 then return end -- AutoUnstuck_Enabled ConVar
    if !ent1:IsValid() then return end
    if !ent2:IsValid() and !ent2:IsWorld() then return end 
    if TpIfAdmin:GetInt() < 1 and ent1:IsAdmin() then return end -- Stop admins from being tp'd for being stuck (If AutoUnstuck_If_Admin is off)    
    
    if ent1:IsPlayer() and ent1:Alive() and ent1:GetVehicle() == NULL then 
        if ent1.jail then return end -- Player is ULX Jailed, if stuck in jail it would cause a teleportation loop spamming chat

        local TimerName = string.format("AU_Tp%s", ent1:UserID()) 
 
        if !PlayerIsStuck(ent1) and timer.Exists(TimerName) then -- Make sure to remove their timer if they aren't stuck anymore   
            if TPdToSpot == ent1:GetPos() then return end -- They aren't stuck anymore BECAUSE Auto Unstuck teleported them
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