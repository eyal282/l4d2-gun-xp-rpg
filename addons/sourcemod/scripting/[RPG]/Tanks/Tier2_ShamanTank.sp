
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name        = "Shaman Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Shaman Tank that casts magical abilities to kill the survivors.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

int infernoIndex, vomitIndex, jockeyIndex, mutationIndex, regenIndex;

float g_fVomitRadius;

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
	RegisterTank();

	HookEvent("player_now_it", Event_Boom, EventHookMode_Post);
}

public void OnMapStart()
{
	TriggerTimer(CreateTimer(1.0, Timer_ShamanTank, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
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

public Action Event_Boom(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(!RPG_Tanks_IsTankInPlay(tankIndex))
		return Plugin_Continue;

	RPG_Perks_ApplyEntityTimedAttribute(victim, "Nightmare", 30.0, COLLISION_SET_IF_LOWER, ATTRIBUTE_NEGATIVE);

	return Plugin_Continue;
}

public Action Timer_ShamanTank(Handle hTimer)
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

		OnShamanTankTimer(i);
	}

	return Plugin_Continue;
}

public void OnShamanTankTimer(int client)
{
	int weapon = L4D_GetPlayerCurrentWeapon(client);

	if(weapon != -1)
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", 2000000000.0);
		SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", 2000000000.0);
	}
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public Action SDKEvent_NeverTransmit(int victim, int viewer)
{
	return Plugin_Handled;
}
public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(2, 3, "Shaman", "A wizard Tank that uses magical abilities to kill survivors.", 5000000, 180, 0.3, 2500, 4000, DAMAGE_IMMUNITY_BURN);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Weak Phyisique", "Tank deals less damage when punching\nTank cannot throw rocks.\nTank attacks slower");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Confusion and Horror", "No matter the source, Survivors gain NIGHTMARE for 30 seconds when Biled.");

	regenIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Regeneration", "Tank heals 100k HP", 60, 60);

	infernoIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Inferno", "Spawns an Inferno on the Tank's location", 20, 30);

	char TempFormat[256];
	FormatEx(TempFormat, sizeof(TempFormat), "Biles all survivors in a %.0f unit radius", g_fVomitRadius);

	vomitIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Vomit", TempFormat, 30, 40);

	jockeyIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Summon Minion Jesters", "Spawns 2 Jockeys that pin closest 2 survivors\nThis always works no matter how far the survivors are.", 75, 90);

	if(LibraryExists("GunXP-RPG"))
	{
		mutationIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Mutation", "Mutates all survivors for 10 seconds", 120, 120);
	}
}

public void RPG_Perks_OnGetTankSwingSpeed(int priority, int client, float &delay)
{
	if(priority != 0)
		return;

	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	delay += 1.0;
}

public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	if(abilityIndex == jockeyIndex)
		CastJockey(client);

	else if(abilityIndex == vomitIndex)
		CastVomit(client);

	else if(abilityIndex == mutationIndex)
		CastMutation(client);

	else if(abilityIndex == regenIndex)
		CastRegen(client);

	else if(abilityIndex == infernoIndex)
		CastInferno(client);
}

public void CastJockey(int client)
{
	int survivor1 = FindRandomSurvivorNearby(client, 65535.0);

	if(survivor1 == -1)
		return;

	float fOrigin[3];

	GetClientAbsOrigin(survivor1, fOrigin);

	fOrigin[2] += 512.0;

	int jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	DataPack DP;
	CreateDataTimer(0.1, Timer_ForceJockey, DP, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, GetClientUserId(survivor1));
	WritePackCell(DP, GetClientUserId(jockey));

	int survivor2 = FindRandomSurvivorNearby(client, 65535.0, survivor1);

	if(survivor2 == -1)
		return;

	GetClientAbsOrigin(survivor2, fOrigin);

	fOrigin[2] += 512.0;

	jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	DataPack DP2;
	CreateDataTimer(0.1, Timer_ForceJockey, DP2, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, GetClientUserId(survivor2));
	WritePackCell(DP, GetClientUserId(jockey));
}
public Action Timer_ForceJockey(Handle hTimer, DataPack DP)
{
	ResetPack(DP);

	int survivor = GetClientOfUserId(ReadPackCell(DP));
	int jockey = GetClientOfUserId(ReadPackCell(DP));

	if(survivor == 0 || jockey == 0)
		return Plugin_Continue;

	L4D2_ForceJockeyVictim(survivor, jockey);

	return Plugin_Continue;
}

public void CastVomit(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

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

		if (GetVectorDistance(fOrigin, fSurvivorOrigin) < g_fVomitRadius && !IsPlayerBoomerBiled(i))
		{
			L4D_CTerrorPlayer_OnVomitedUpon(i, client);
		}
	}
}

public void CastInferno(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	L4D_DetonateProjectile(L4D_MolotovPrj(client, fOrigin, view_as<float>({0.0, 0.0, 0.0})));
}


public void CastMutation(int client)
{
	float fDuration = 10.0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		RPG_Perks_ApplyEntityTimedAttribute(i, "Mutated", fDuration, COLLISION_ADD, ATTRIBUTE_NEGATIVE);
	}

	PrintToChatAll("All survivors are mutated for %.0f seconds.", fDuration);
	PrintToChatAll("Mutated players lose all abilities");
}

public void CastRegen(int client)
{
	GunXP_RegenerateTankHealth(client, 100000);
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

stock bool IsPlayerBoomerBiled(int iClient)
{
    return (GetGameTime() <= GetEntPropFloat(iClient, Prop_Send, "m_itTimer", 1));
}