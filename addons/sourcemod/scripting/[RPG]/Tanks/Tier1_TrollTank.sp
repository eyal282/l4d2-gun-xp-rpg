
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
	name        = "Troll Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Troll Tank that is free EXP but for a price...",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

int stunIndex, hunterIndex;

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "RPG_Tanks"))
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

	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

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
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_NotInfected)
			continue;

		RPG_Tanks_SetDamagePercent(i, client, 100.0);
	}
}

public Action Event_WeaponFire(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return Plugin_Continue;

	char sWeaponName[16];
	GetEventString(hEvent, "weapon", sWeaponName, sizeof(sWeaponName));

	if(!StrEqual(sWeaponName, "tank_claw"))
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return Plugin_Continue;

	int weapon = L4D_GetPlayerCurrentWeapon(client);
	
	if(weapon == -1)
		return Plugin_Continue;
		
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 0.3);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.3);

	return Plugin_Continue;
}

public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(1, 3, "Troll", "A tank that wants to ruin your day\nDeals no damage, takes almost no damage.", 1000000, 180, 0.0, 200, 400, DAMAGE_IMMUNITY_BULLETS|DAMAGE_IMMUNITY_MELEE|DAMAGE_IMMUNITY_EXPLOSIVES);

	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Mental Pain", "Tank deals no direct damage");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Close and Personal", "Tank attacks at high speed.\nTank cannot throw rocks.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Painful Goodbye", "Tank explodes after death killing all survivors in 512 unit radius\nEven if mission is lost, XP is still given.");
	RPG_Tanks_RegisterPassiveAbility(tankIndex, "Cheerful Goodbye?", "No matter the situation, all players are treated as inflicted 100{PERCENT} of Tank's HP in damage.");

	stunIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Stun", "Stuns 2 closest survivors for 30 seconds in a 512 unit radius\nThis can stack freely.", 20, 40);
	hunterIndex = RPG_Tanks_RegisterActiveAbility(tankIndex, "Tactical Stun", "Spawns a Hunter that pins closest survivor\nThis always works no matter how far the survivor is.\nThe hunter deals 1 base damage.", 30, 45);
}


public void RPG_Tanks_OnRPGTankCastActiveAbility(int client, int abilityIndex)
{  
	if(RPG_Tanks_GetClientTank(client) != tankIndex)
		return;

	if(abilityIndex == stunIndex)
		CastStun(client);

	else if(abilityIndex == hunterIndex)
		CastHunter(client);
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

	WritePackCell(DP, survivor);
	WritePackCell(DP, hunter);
}

public Action Timer_ForceHunter(Handle hTimer, DataPack DP)
{
	ResetPack(DP);

	int survivor = ReadPackCell(DP);
	int hunter = ReadPackCell(DP);

	L4D2_ForceJockeyVictim(survivor, hunter);

	return Plugin_Continue;
}

stock int FindRandomSurvivorNearby(int client, float fMaxDistance, int exception=0)
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
		else if(client == i || client == exception)
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