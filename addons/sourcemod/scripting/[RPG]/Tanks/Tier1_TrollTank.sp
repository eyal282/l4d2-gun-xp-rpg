
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define MODEL_EXPLOSIVE		"models/props_junk/propanecanister001a.mdl"

public Plugin myinfo =
{
	name        = "Troll Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Troll Tank that is free EXP but for a price...",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

int stunIndex, hunterIndex, mutationIndex;

float g_fExplosionRange = 512.0;

ConVar g_hDifficulty;

public void OnLibraryAdded(const char[] name)
{
	// GunXP-RPG is to make Mutation only work with GunXP - RPG
	if (StrEqual(name, "RPG_Tanks") || StrEqual(name, "GunXP-RPG"))
	{
		RegisterTank();
	}
}

public void OnConfigsExecuted()
{
	RegisterTank();

}
public void OnPluginStart()
{
	g_hDifficulty = FindConVar("z_difficulty");

	RegisterTank();
}

public void OnMapStart()
{
	TriggerTimer(CreateTimer(1.0, Timer_TrollTank, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action L4D_OnCThrowActivate(int ability)
{
	int tank = GetEntPropEnt(ability, Prop_Send, "m_hOwnerEntity");

	if(tank == -1)
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(tank) != tankIndex)
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_TrollTank(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Tanks_GetClientTank(i) != tankIndex)
			continue;


		OnTrollTankTimer(i);
	}

	return Plugin_Continue;
}

public void OnTrollTankTimer(int client)
{
	char sValue[16];
	g_hDifficulty.GetString(sValue, sizeof(sValue));

	if(!StrEqual(sValue, "impossible"))
	{
		if(RPG_Perks_GetClientHealth(client) * 2 > RPG_Perks_GetClientMaxHealth(client))
		{
			RPG_Perks_SetClientHealth(client, RPG_Perks_GetClientMaxHealth(client) / 2);
		}
	}
	int weapon = L4D_GetPlayerCurrentWeapon(client);

	if(weapon != -1)
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 2000000000.0);
		SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", 2000000000.0);
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		RPG_Tanks_SetDamagePercent(i, client, 100.0);
	}
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RPG_Tanks_OnRPGTankKilled(int victim, int attacker)
{
	if(RPG_Tanks_GetClientTank(victim) != tankIndex)
		return;

	float fOrigin[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fOrigin);

	int entity = CreateEntityByName("prop_physics");
	if( entity != -1 )
	{
		DispatchKeyValue(entity, "model", MODEL_EXPLOSIVE);

		// Hide from view (multiple hides still show the gascan/propane tank for a split second sometimes, but works better than only using 1 of them)
		SDKHook(entity, SDKHook_SetTransmit, SDKEvent_NeverTransmit);

		// Hide from view
		int flags = GetEntityFlags(entity);
		SetEntityFlags(entity, flags|FL_EDICT_DONTSEND);

		// Make invisible
		SetEntityRenderMode(entity, RENDER_TRANSALPHAADD);
		SetEntityRenderColor(entity, 0, 0, 0, 0);

		// Prevent collision and movement
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1, 1);
		SetEntityMoveType(entity, MOVETYPE_NONE);

		// Teleport
		TeleportEntity(entity, fOrigin, NULL_VECTOR, NULL_VECTOR);

		// Spawn
		DispatchSpawn(entity);

		// Set attacker
		SetEntPropEnt(entity, Prop_Data, "m_hPhysicsAttacker", victim);
		SetEntPropFloat(entity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());

		// Explode
		AcceptEntityInput(entity, "Break", victim);
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		float fSurvivorOrigin[3];
		GetClientAbsOrigin(i, fSurvivorOrigin);

		if (GetVectorDistance(fOrigin, fSurvivorOrigin) < g_fExplosionRange)
		{
			RPG_Perks_InstantKill(i, victim, victim, DMG_BLAST);
		}
	}
}

public Action SDKEvent_NeverTransmit(int victim, int viewer)
{
	return Plugin_Handled;
}
public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(1, 3, "Troll", "A tank that wants to ruin your day\nDeals no damage, takes almost no damage.", 250000, 180, 0.0, 200, 400, DAMAGE_IMMUNITY_BULLETS|DAMAGE_IMMUNITY_MELEE|DAMAGE_IMMUNITY_EXPLOSIVES);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Mental Pain", "Tank deals no direct damage");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Close and Personal", "Tank attacks at high speed.\nTank cannot throw rocks.");

	char sDescription[512];
	FormatEx(sDescription, sizeof(sDescription), "Tank explodes after death killing all survivors in %i unit radius\nEven if mission is lost, XP is still given.", RoundFloat(g_fExplosionRange));

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Painful Goodbye", sDescription);
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Cheerful Goodbye?", "No matter the situation, all players are treated as inflicted 100{PERCENT} of Tank's HP in damage.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Fair Fight?", "Tank's max HP is halved below Expert difficulty");

	stunIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Stun", "Stuns 2 closest survivors for 30 seconds in a 512 unit radius\nThis can stack freely.", 20, 40);
	hunterIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Tactical Stun", "Spawns a Hunter that pins closest survivor\nThis always works no matter how far the survivor is.", 30, 45);

	if(LibraryExists("GunXP-RPG"))
	{
		mutationIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Mutation", "Mutates 4 closest survivors for 15 seconds in a 512 unit radius\nMutated survivors are treated as level 0 and lose all abilities.", 90, 120);
	}
}

public void RPG_Perks_OnGetTankSwingSpeed(int priority, int client, float &delay)
{
	if(priority != -2)
		return;

	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	delay = 0.0;
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	if(abilityIndex == stunIndex)
		CastStun(client);

	else if(abilityIndex == hunterIndex)
		CastHunter(client);

	else if(abilityIndex == mutationIndex)
		CastMutation(client);
}

public void CastStun(int client)
{
	int survivor1 = FindRandomSurvivorNearby(client, 512.0);

	if(survivor1 == -1)
		return;

	float fDuration = 30.0;

	RPG_Perks_ApplyEntityTimedAttribute(survivor1, "Stun", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

	int survivor2 = FindRandomSurvivorNearby(client, 512.0, survivor1);

	if(survivor2 == -1)
	{
		PrintToChatAll("%N is stunned for %.0f seconds.", survivor1, fDuration);
	}
	else
	{
		RPG_Perks_ApplyEntityTimedAttribute(survivor2, "Stun", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

		PrintToChatAll("%N & %N are stunned for %.0f seconds.", survivor1, survivor2, fDuration);
	}
}


public void CastHunter(int client)
{
	int survivor = FindRandomSurvivorNearby(client, 65535.0);

	if(survivor == -1)
		return;

	float fOrigin[3];

	GetClientAbsOrigin(survivor, fOrigin);

	fOrigin[2] += 512.0;

	int hunter = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Hunter), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	DataPack DP;
	CreateDataTimer(0.1, Timer_ForceHunter, DP, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, GetClientUserId(survivor));
	WritePackCell(DP, GetClientUserId(hunter));
}

public Action Timer_ForceHunter(Handle hTimer, DataPack DP)
{
	ResetPack(DP);

	int survivor = GetClientOfUserId(ReadPackCell(DP));
	int hunter = GetClientOfUserId(ReadPackCell(DP));

	if(survivor == 0 || hunter == 0)
		return Plugin_Continue;

	L4D_ForceHunterVictim(survivor, hunter);

	return Plugin_Continue;
}


public void CastMutation(int client)
{
	int survivor1 = FindRandomSurvivorNearby(client, 512.0);

	if(survivor1 == -1)
		return;

	float fDuration = 15.0;

	RPG_Perks_ApplyEntityTimedAttribute(survivor1, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);

	int survivor2 = FindRandomSurvivorNearby(client, 512.0, survivor1);


	int survivor3 = FindRandomSurvivorNearby(client, 512.0, survivor1, survivor2);


	int survivor4 = FindRandomSurvivorNearby(client, 512.0, survivor1, survivor2, survivor3);

	if(survivor2 == -1)
	{
		PrintToChatAll("%N is mutated for %.0f seconds.", survivor1, fDuration);
	}
	else if(survivor3 == -1)
	{
		PrintToChatAll("%N & %N are mutated for %.0f seconds.", survivor1, survivor2, fDuration);

		RPG_Perks_ApplyEntityTimedAttribute(survivor2, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
	}
	else if(survivor4 == -1)
	{
		PrintToChatAll("%N & %N are mutated for %.0f seconds.", survivor1, survivor2, fDuration);
		PrintToChatAll("%N is mutated for %.0f seconds.", survivor3, fDuration);

		RPG_Perks_ApplyEntityTimedAttribute(survivor2, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
		RPG_Perks_ApplyEntityTimedAttribute(survivor3, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
	}
	else
	{
		PrintToChatAll("%N & %N are mutated for %.0f seconds.", survivor1, survivor2, fDuration);
		PrintToChatAll("%N & %N are mutated for %.0f seconds.", survivor3, survivor4, fDuration);

		RPG_Perks_ApplyEntityTimedAttribute(survivor2, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
		RPG_Perks_ApplyEntityTimedAttribute(survivor3, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
		RPG_Perks_ApplyEntityTimedAttribute(survivor4, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
	}

	PrintToChatAll("Mutated players lose all abilities");
}

stock int FindRandomSurvivorNearby(int client, float fMaxDistance, int exception=0, int exception2=0, int exception3=0)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	int   winner    = -1;
	float winnerDistance = fMaxDistance;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		// Technically unused because the tank can never be survivor but still...
		else if(client == i || exception == i || exception2 == i || exception3 == i)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		float fSurvivorOrigin[3];
		GetClientAbsOrigin(i, fSurvivorOrigin);

		if (GetVectorDistance(fOrigin, fSurvivorOrigin) < winnerDistance)
		{
			winner    = i;
			winnerDistance = GetVectorDistance(fOrigin, fSurvivorOrigin);
		}
	}

	return winner;
}