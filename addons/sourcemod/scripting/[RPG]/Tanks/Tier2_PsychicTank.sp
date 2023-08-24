
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
	name        = "Psychic Tank --> Gun XP - RPG",
	author      = "Eyal282",
	description = "Psychic Tank that uses mind power to strike survivors.",
	version     = PLUGIN_VERSION,
	url         = ""
};

int tankIndex;

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

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(victim) != L4DTeam_Survivor)
		return Plugin_Continue;

	else if(L4D_IsPlayerIncapacitated(victim))
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(attacker) != ZombieType_Tank)
		return Plugin_Continue;

	else if(RPG_Tanks_GetClientTank(attacker) != tankIndex)
		return Plugin_Continue;

	float fOrigin[3];

	GetClientAbsOrigin(victim, fOrigin);

	fOrigin[2] += 512.0;

	int jockey = L4D2_SpawnSpecial(view_as<int>(L4D2ZombieClass_Jockey), fOrigin, view_as<float>({0.0, 0.0, 0.0}));


	DataPack DP;
	CreateDataTimer(0.1, Timer_ForceJockey, DP, TIMER_FLAG_NO_MAPCHANGE);

	WritePackCell(DP, victim);
	WritePackCell(DP, jockey);

	return Plugin_Continue;
}

public Action Timer_ForceJockey(Handle hTimer, DataPack DP)
{
	ResetPack(DP);

	int victim = ReadPackCell(DP);
	int jockey = ReadPackCell(DP);

	L4D2_ForceJockeyVictim(victim, jockey);

	return Plugin_Continue;
}
public void GunXP_OnReloadRPGPlugins()
{
	GunXP_ReloadPlugin();
}

public void RegisterTank()
{
	tankIndex = RPG_Tanks_RegisterTank(1, 3, "Jockey", "A tank that likes Jockeys\nAll Special Infected spawned will be Jockeys instead\nThis tank shoots jockeys from his arms, and you will be pinned if it hits you.", 200000, 180, 300, 500, true, false);
}

public void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass)
{
	if(priority != 0)
		return;
		
	else if(zclass == L4D2ZombieClass_Tank)
		return;

	else if(!RPG_Tanks_IsTankInPlay(tankIndex))
		return;

	zclass = L4D2ZombieClass_Jockey;
}
