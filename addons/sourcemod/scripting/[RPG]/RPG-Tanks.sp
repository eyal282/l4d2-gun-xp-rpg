#include <GunXP-RPG>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <left4dhooks>
#include <smlib>
#include <ps_api>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <autoexecconfig>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name = "RPG Tanks",
	author = "Eyal282",
	description = "Powerful tanks for RPG gamemodes.",
	version = PLUGIN_VERSION,
	url = "NULL"
};

ConVar g_hPriorityImmunities;
ConVar g_hPriorityTankSpawn;

ConVar g_hEntriesUntiered;
ConVar g_hEntriesTierOne;
ConVar g_hEntriesTierTwo;
ConVar g_hEntriesTierThree;


enum struct enTank
{
	// Tier of the tank. 
	int tier;

	// Entries for that tier. Entries are calculated as chances to win. The more "fun" a tank is makes it reasonable to give it more entries.
	int entries;

	// Tank's name without "Tank"
	char name[32];
	char description[512];

	int maxHP;
	int speed;

	// reward of XP in Gun XP
	int XPRewardMin;
	int XPRewardMax;

	bool fireDamageImmune;
	bool meleeDamageImmune;
}

ArrayList g_aTanks;

GlobalForward g_fwOnRPGTankKilled;

int g_iCurrentTank[MAXPLAYERS+1] = { TANK_TIER_UNTIERED, ... };

// [victim][attacker]
int g_iDamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{

	CreateNative("RPG_Tanks_RegisterTank", Native_RegisterTank);
	CreateNative("RPG_Tanks_GetClientTank", Native_GetClientTank);
	CreateNative("RPG_Tanks_GetDamagePercent", Native_GetDamagePercent);
	CreateNative("RPG_Tanks_IsTankInPlay", Native_IsTankInPlay);


	// Do not check for this library!!!
	RegPluginLibrary("RPG Tanks");

	return APLRes_Success;
}


public int Native_RegisterTank(Handle caller, int numParams)
{
	enTank tank;

	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	int tier = GetNativeCell(1);
	int entries = GetNativeCell(2);

	char name[32];
	GetNativeString(3, name, sizeof(name));

	char description[512];
	GetNativeString(4, description, sizeof(description));

	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	int maxHP = GetNativeCell(5);

	int speed = GetNativeCell(6);

	int XPRewardMin = GetNativeCell(7);
	int XPRewardMax = GetNativeCell(8);

	bool fireDamageImmune = GetNativeCell(9);
	bool meleeDamageImmune = GetNativeCell(10);

	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank iTank;
		g_aTanks.GetArray(i, iTank);
		
		if(StrEqual(name, iTank.name))
			return i;
	}

	tank.tier = tier;
	tank.entries = entries;
	tank.name = name;
	tank.description = description;
	tank.maxHP = maxHP;
	tank.speed = speed;
	tank.XPRewardMin = XPRewardMin;
	tank.XPRewardMax = XPRewardMax;
	tank.fireDamageImmune = fireDamageImmune;
	tank.meleeDamageImmune = meleeDamageImmune;

	return g_aTanks.PushArray(tank);
}


public any Native_GetClientTank(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	return g_iCurrentTank[client];
}

public any Native_GetDamagePercent(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int tank = GetNativeCell(2);

	return float(g_iDamageTaken[tank][client]) / float(RPG_Perks_GetClientMaxHealth(tank)) * 100.0;
}

public any Native_IsTankInPlay(Handle caller, int numParams)
{
	int tankIndex = GetNativeCell(1);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;
			
		if(g_iCurrentTank[i] == tankIndex)
			return true;
	}

	return false;
}

public void OnPluginStart()
{

	//g_aUnlockItems = CreateArray(sizeof(enProduct));
	g_aTanks = CreateArray(sizeof(enTank));

	g_fwOnRPGTankKilled = CreateGlobalForward("RPG_Tanks_OnRPGTankKilled", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("RPG_Tanks");
	
	#endif

	//RegConsoleCmd("sm_tankinfo", Command_TankInfo);

	g_hPriorityImmunities = UC_CreateConVar("rpg_tanks_priority_immunities", "2", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 to give a tank their immunity from fire or melee.\nWhen making a plugin, feel free to track this cvar's value for reference.");
	g_hPriorityTankSpawn = UC_CreateConVar("rpg_tanks_priority_finale_tank_spawn", "-5", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 that when a tank spawns, check what tier to give it and give it max HP.");

	g_hEntriesUntiered = UC_CreateConVar("rpg_tanks_entries_untiered", "5", "Entries to spawn an untiered tank.");
	g_hEntriesTierOne = UC_CreateConVar("rpg_tanks_entries_tier_one", "0", "Entries to spawn a tier one tank.");
	g_hEntriesTierTwo = UC_CreateConVar("rpg_tanks_entries_tier_two", "0", "Entries to spawn a tier two tank.");
	g_hEntriesTierThree = UC_CreateConVar("rpg_tanks_entries_tier_three", "0", "Entries to spawn a tier three tank.");
	
	#if defined _autoexecconfig_included
	
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
	
	#endif

	RegPluginLibrary("RPG_Tanks");

	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public void OnMapStart()
{
	TriggerTimer(CreateTimer(1.0, Timer_ResetFrustration, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action Timer_ResetFrustration(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		// Not sure if frustration is 100 or 0 as a reset, but 50 will always work.
		SetEntProp(i, Prop_Send, "m_frustration", 50);
	}

	return Plugin_Continue;
}
public void GunXP_OnReloadRPGPlugins()
{
	#if defined _GunXP_RPG_included
		GunXP_ReloadPlugin();
	#endif

}


public void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass)
{
	if(priority != 0)
		return;
		
	else if(zclass != L4D2ZombieClass_Tank)
		return;

	int tankCount = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		tankCount++;
	}

	if(tankCount >= 2)
		zclass = view_as<L4D2ZombieClassType>(GetRandomInt(1, 6));
}
public void RPG_Perks_OnGetZombieMaxHP(int priority, int entity, int &maxHP)
{
	if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
		return;

	int client = entity;

	if(priority == -10)
	{
		g_iCurrentTank[client] = TANK_TIER_UNKNOWN;
	}
	if(priority != g_hPriorityTankSpawn.IntValue)
		return;

	for(int i=0;i < sizeof(g_iDamageTaken[]);i++)
	{
		g_iDamageTaken[client][i] = 0;
	}

	int initValue;
	
	int entries[4];
	
	entries[0] = g_hEntriesUntiered.IntValue;
	entries[1] = g_hEntriesTierOne.IntValue;
	entries[2] = g_hEntriesTierTwo.IntValue;
	entries[3] = g_hEntriesTierThree.IntValue;

	int totalEntries = 0;

	for(int i=0;i < sizeof(entries);i++)
	{
		totalEntries += entries[i];	
	}
	

	
	int RNG = GetRandomInt(1, totalEntries);

	int winnerTier = 0;

	for(int i=0;i < 3;i++)
	{
		if(RNG > initValue && RNG <= (initValue + entries[i]))
		{
			winnerTier = i;
			break;
		}
		initValue += entries[i];
	}

	if(winnerTier == 0)
	{
		g_iCurrentTank[client] = TANK_TIER_UNTIERED;
		return;
	}

	totalEntries = 0;

	initValue = 0;

	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank tank;
		g_aTanks.GetArray(i, tank);
		
		if(tank.tier != winnerTier)
			continue;

		totalEntries += tank.entries;
	}

	RNG = GetRandomInt(1, totalEntries);

	int winnerTankIndex;

	enTank winnerTank;

	winnerTank.tier = 0;

	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank tank;
		g_aTanks.GetArray(i, tank);

		if(RNG > initValue && RNG <= (initValue + tank.entries))
		{
			g_aTanks.GetArray(i, winnerTank);
			winnerTankIndex = i;
			break;
		}

		initValue += tank.entries;
	}

	if(winnerTank.tier == 0)
	{
		g_iCurrentTank[client] = TANK_TIER_UNTIERED;
		return;
	}

	g_iCurrentTank[client] = winnerTankIndex;

	maxHP = winnerTank.maxHP;

	char sName[64];
	FormatEx(sName, sizeof(sName), "%s Tank", winnerTank.name);

	SetClientName(client, sName);

	PrintToChatAll("A \x03Tier %i \x05%s Tank\x01 has spawned.", winnerTank.tier, winnerTank.name);
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == 10 && RPG_Perks_GetZombieType(victim) == ZombieType_Tank && g_iCurrentTank[victim] >= 0)
	{
		char sClassname[64];
		if(attacker != 0)
			GetEdictClassname(attacker, sClassname, sizeof(sClassname));

		if(IsPlayer(victim) && damage >= 600.0 && (attacker == victim || attacker == 0 || StrEqual(sClassname, "trigger_hurt") || StrEqual(sClassname, "point_hurt")))
		{
			PrintToChatAll(" \x03%N\x01 took lethal damage from the world. It will be converted to a normal Tank now.", victim);

			SetClientName(victim, "Tank");

			g_iCurrentTank[victim] = TANK_TIER_UNTIERED;
		}
	}
	if(priority != g_hPriorityImmunities.IntValue)
		return;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return;

	else if(g_iCurrentTank[victim] < 0)
		return;

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[victim], tank);

	if(tank.fireDamageImmune && damagetype & DMG_BURN)
	{
		bImmune = true;
	}

	if(tank.meleeDamageImmune && (L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw))
	{
		bImmune = true;
	}
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
		return Plugin_Continue;

	int damage = GetEventInt(hEvent, "dmg_health");

	g_iDamageTaken[victim][attacker] += damage;

	return Plugin_Continue;
}
public Action Event_PlayerIncap(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return Plugin_Continue;

	else if(g_iCurrentTank[victim] < 0)
	{
		g_iCurrentTank[victim] = TANK_TIER_UNKNOWN;
		return Plugin_Continue;
	}

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[victim], tank);

	int XPReward = GetRandomInt(tank.XPRewardMin, tank.XPRewardMax);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		
		if(LibraryExists("GunXP-RPG"))
		{
			PrintToChat(i, "You dealt\x03 %.1f%%\x01 of %N's max HP as damage", float(g_iDamageTaken[victim][i]) / float(RPG_Perks_GetClientMaxHealth(victim)) * 100.0, victim);
		}

		if(LibraryExists("GunXP-RPG") && float(g_iDamageTaken[victim][i]) / float(tank.maxHP) < 0.05)
		{
			PrintToChat(i, "This is not enough to gain XP rewards.", victim);

			continue;
		}


		if(LibraryExists("GunXP-RPG"))
		{
			PrintToChat(i, "This is enough to get XP rewards. You got\x03 %i\x05 XP", XPReward);
		}

		Call_StartForward(g_fwOnRPGTankKilled);

		
		Call_PushCell(victim);
		
		Call_PushCell(i);
		
		Call_PushCell(XPReward);

		Call_Finish();
	}

	g_iCurrentTank[victim] = TANK_TIER_UNKNOWN;

	return Plugin_Continue;
}