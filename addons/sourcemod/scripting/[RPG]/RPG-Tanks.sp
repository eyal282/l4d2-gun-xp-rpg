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

ConVar g_hDifficulty;

ConVar g_hMinigunDamageMultiplier;
ConVar g_hRPGDamageMultiplier;

ConVar g_hPriorityImmunities;
ConVar g_hPriorityTankSpawn;

ConVar g_hEntriesUntiered;
ConVar g_hEntriesTierOne;
ConVar g_hEntriesTierTwo;
ConVar g_hEntriesTierThree;

enum struct enActiveAbility
{
	char name[32];
	char description[256];
	int minCooldown;
	int maxCooldown;
}

enum struct enPassiveAbility
{
	char name[32];
	char description[512];
}
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

	float damageMultiplier;

	// reward of XP in Gun XP
	int XPRewardMin;
	int XPRewardMax;

	int damageImmunities;

	ArrayList aActiveAbilities;
	ArrayList aPassiveAbilities;
}

ArrayList g_aTanks;

GlobalForward g_fwOnRPGTankKilled;
GlobalForward g_fwOnRPGTankCastActiveAbility;

int g_iCurrentTank[MAXPLAYERS+1] = { TANK_TIER_UNTIERED, ... };

// [victim][attacker]
int g_iDamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{

	CreateNative("RPG_Tanks_IsDamageImmuneTo", Native_IsDamageImmuneTo);
	CreateNative("RPG_Tanks_RegisterTank", Native_RegisterTank);
	CreateNative("RPG_Tanks_RegisterActiveAbility", Native_RegisterActiveAbility);
	CreateNative("RPG_Tanks_RegisterPassiveAbility", Native_RegisterPassiveAbility);
	CreateNative("RPG_Tanks_GetClientTank", Native_GetClientTank);
	CreateNative("RPG_Tanks_GetDamagePercent", Native_GetDamagePercent);
	CreateNative("RPG_Tanks_SetDamagePercent", Native_SetDamagePercent);
	CreateNative("RPG_Tanks_IsTankInPlay", Native_IsTankInPlay);


	// Do not check for this library!!!
	RegPluginLibrary("RPG Tanks");

	return APLRes_Success;
}


public int Native_IsDamageImmuneTo(Handle caller, int numParams)
{
	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	int client = GetNativeCell(1);

	// DAMAGE_IMMUNITY_*
	int damageType = GetNativeCell(2);

	if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return false;
		
	if(g_iCurrentTank[client] < 0)
	{
		return false;
	}

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[client], tank);

	if(tank.damageImmunities == NO_DAMAGE_IMMUNITY)
		return false;

	return tank.damageImmunities & damageType;
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
	float damageMultiplier = GetNativeCell(7);

	int XPRewardMin = GetNativeCell(8);
	int XPRewardMax = GetNativeCell(9);

	int damageImmunities = GetNativeCell(10);

	int foundIndex = TankNameToTankIndex(name);

	tank.tier = tier;
	tank.entries = entries;
	tank.name = name;
	tank.description = description;
	tank.maxHP = maxHP;
	tank.speed = speed;
	tank.damageMultiplier = damageMultiplier;
	tank.XPRewardMin = XPRewardMin;
	tank.XPRewardMax = XPRewardMax;
	tank.damageImmunities = damageImmunities;
	tank.aActiveAbilities = CreateArray(sizeof(enActiveAbility));
	tank.aPassiveAbilities = CreateArray(sizeof(enPassiveAbility));


	if(foundIndex != -1)
	{
		g_aTanks.SetArray(foundIndex, tank);

		return foundIndex;
	}

	return g_aTanks.PushArray(tank);
}

public int Native_RegisterActiveAbility(Handle caller, int numParams)
{
	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	int pos = GetNativeCell(1);

	enTank tank;
	g_aTanks.GetArray(pos, tank);

	char name[32];
	GetNativeString(2, name, sizeof(name));

	char sInfo[64];
	Format(sInfo, sizeof(sInfo), "[ACTIVATED] %s", name);
	int foundIndex = AbilityNameToAbilityIndex(sInfo, pos, false);



	char description[256];
	GetNativeString(3, description, sizeof(description));

	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	int minCooldown = GetNativeCell(4);
	int maxCooldown = GetNativeCell(5);

	enActiveAbility activeAbility;

	activeAbility.name = name;
	activeAbility.description = description;
	activeAbility.minCooldown = minCooldown;
	activeAbility.maxCooldown = maxCooldown;

	if(foundIndex != -1)
	{
		tank.aActiveAbilities.SetArray(foundIndex, activeAbility);

		return foundIndex;
	}
	return tank.aActiveAbilities.PushArray(activeAbility);
}

public int Native_RegisterPassiveAbility(Handle caller, int numParams)
{
	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	int pos = GetNativeCell(1);

	enTank tank;
	g_aTanks.GetArray(pos, tank);

	char name[32];
	GetNativeString(2, name, sizeof(name));

	char sInfo[64];
	Format(sInfo, sizeof(sInfo), "[PASSIVE] %s", name);
	int foundIndex = AbilityNameToAbilityIndex(sInfo, pos, true);

	if(foundIndex != -1)
		return foundIndex;

	char description[512];
	GetNativeString(3, description, sizeof(description));

	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	enPassiveAbility passiveAbility;

	passiveAbility.name = name;
	passiveAbility.description = description;

	return tank.aPassiveAbilities.PushArray(passiveAbility);
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

	float damagePercent = float(g_iDamageTaken[tank][client]) / float(RPG_Perks_GetClientMaxHealth(tank)) * 100.0;

	if(damagePercent > 100.0)
		return 100.0;
		
	return damagePercent;
}

public any Native_SetDamagePercent(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	int tank = GetNativeCell(2);
	float damagePercent = GetNativeCell(3);

	g_iDamageTaken[tank][client] = RoundFloat((damagePercent / 100.0) * float(RPG_Perks_GetClientMaxHealth(tank)));

	return 0;
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
	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	g_fwOnRPGTankKilled = CreateGlobalForward("RPG_Tanks_OnRPGTankKilled", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnRPGTankCastActiveAbility = CreateGlobalForward("RPG_Tanks_OnRPGTankCastActiveAbility", ET_Ignore, Param_Cell, Param_Cell);

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("RPG_Tanks");
	
	#endif

	RegConsoleCmd("sm_tankinfo", Command_TankInfo);
	RegConsoleCmd("sm_tankhp", Command_TankHP);

	g_hMinigunDamageMultiplier = UC_CreateConVar("rpg_tanks_minigun_damage_multiplier", "0.1", "Minigun damage multiplier");
	g_hRPGDamageMultiplier = UC_CreateConVar("rpg_tanks_rpg_damage_multiplier", "0.05", "RPG damage multiplier");

	g_hPriorityImmunities = UC_CreateConVar("rpg_tanks_priority_immunities", "2", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 to give a tank their immunity from fire or melee.\nWhen making a plugin, feel free to track this cvar's value for reference.");
	g_hPriorityTankSpawn = UC_CreateConVar("rpg_tanks_priority_rpg_tank_spawn", "-5", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 that when a tank spawns, check what tier to give it and give it max HP.");

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
	HookEvent("player_entered_checkpoint", Event_EnterCheckpoint, EventHookMode_Post);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	HookEntityOutput("trigger_gravity", "OnStartTouch", OnStartTouchTriggerGravity);

	g_hDifficulty = FindConVar("z_difficulty");

	HookConVarChange(g_hDifficulty, cvChange_Difficulty);
}

public void OnMapStart()
{
	for(int i=0;i < sizeof(g_iCurrentTank);i++)
	{
		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}

	TriggerTimer(CreateTimer(0.5, Timer_TanksOpenDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public void OnClientConnected(int client)
{
	for(int i=1;i <= MaxClients;i++)
	{
		g_iDamageTaken[client][i] = 0;
		g_iDamageTaken[i][client] = 0;
	}
}
public Action Timer_TanksOpenDoors(Handle hTimer)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		int count = GetEntityCount();

		float fOrigin[3];
		GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", fOrigin);

		for (int a = MaxClients+1;a < count;a++)
		{
			if(!IsValidEdict(a))
				continue;

			char sClassname[64];
			GetEdictClassname(a, sClassname, sizeof(sClassname));

			if(strncmp(sClassname, "prop_door_rotating", 18) == 0 || strncmp(sClassname, "func_door", 9) == 0)
			{
				float fDoorOrigin[3];
				GetEntPropVector(a, Prop_Data, "m_vecOrigin", fDoorOrigin);

				if(GetVectorDistance(fOrigin, fDoorOrigin) < 128.0)
				{
					AcceptEntityInput(a, "Open");
				}
			}
			else if(StrEqual(sClassname, "func_breakable"))
			{
				float fDoorOrigin[3];
				GetEntPropVector(a, Prop_Data, "m_vecOrigin", fDoorOrigin);

				if(GetVectorDistance(fOrigin, fDoorOrigin) < 128.0)
				{
					AcceptEntityInput(a, "Break");
				}
			}
		}
	}

	return Plugin_Continue;
}

public void cvChange_Difficulty(ConVar convar, const char[] oldValue, const char[] newValue)
{
    Func_DifficultyChanged(newValue);
}

public void Func_DifficultyChanged(const char[] newValue)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		PrintToChatAll(" \x03%N\x01 will be converted to a normal Tank for the difficulty change.", i);

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}
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
	{
		if(IsFakeClient(client))
		{
			L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
			KickClient(client);
		}
	}
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

	for(int i=0;i <= 3;i++)
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

		if(tank.tier != winnerTier)
			continue;

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

	PrintToChatAll(" \x01A \x03Tier %i \x05%s Tank\x01 has spawned.", winnerTank.tier, winnerTank.name);

	int size = winnerTank.aActiveAbilities.Length;

	for(int i=0;i < size;i++)
	{
		enActiveAbility activeAbility;
		winnerTank.aActiveAbilities.GetArray(i, activeAbility);

		if(activeAbility.minCooldown == 0 && activeAbility.maxCooldown == 0)
			continue;

		char TempFormat[64];
		FormatEx(TempFormat, sizeof(TempFormat), "Cast Active Ability #%i", i);

		RPG_Perks_ApplyEntityTimedAttribute(client, TempFormat, GetRandomFloat(float(activeAbility.minCooldown), float(activeAbility.maxCooldown)), COLLISION_SET, ATTRIBUTE_POSITIVE);
	}
}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(strncmp(attributeName, "Cast Active Ability #", 21) != 0)
		return;

	if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
		return;

	if(g_iCurrentTank[entity] < 0)
		return;

	char sAbilityIndex[64];
	strcopy(sAbilityIndex, sizeof(sAbilityIndex), attributeName);
	ReplaceStringEx(sAbilityIndex, sizeof(sAbilityIndex), "Cast Active Ability #", "");

	int abilityIndex = StringToInt(sAbilityIndex);

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[entity], tank);

	enActiveAbility activeAbility;
	tank.aActiveAbilities.GetArray(abilityIndex, activeAbility);

	RPG_Perks_ApplyEntityTimedAttribute(entity, attributeName, GetRandomFloat(float(activeAbility.minCooldown), float(activeAbility.maxCooldown)), COLLISION_SET, ATTRIBUTE_POSITIVE);

	Call_StartForward(g_fwOnRPGTankCastActiveAbility);

	
	Call_PushCell(entity);
	
	Call_PushCell(abilityIndex);

	Call_Finish();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == 10 && RPG_Perks_GetZombieType(victim) == ZombieType_Tank && g_iCurrentTank[victim] >= 0)
	{
		char sClassname[64];
		if(attacker != 0)
			GetEdictClassname(attacker, sClassname, sizeof(sClassname));

		if(IsPlayer(victim) && (damage >= 100.0 && (attacker == victim || attacker == 0 || strncmp(sClassname, "trigger_hurt", 12) == 0 || strncmp(sClassname, "point_hurt", 10) == 0)))
		{
			PrintToChatAll(" \x03%N\x01 took lethal damage from the world. It will be converted to a normal Tank now.", victim);

			SetClientName(victim, "Tank");

			RPG_Perks_SetClientHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[victim] = TANK_TIER_UNTIERED;
		}
	}
	if(priority != g_hPriorityImmunities.IntValue)
		return;

	if(RPG_Perks_GetZombieType(attacker) == ZombieType_Tank)
	{
		char sClassname[64];
		GetEdictClassname(inflictor, sClassname, sizeof(sClassname));

		if(g_iCurrentTank[attacker] >= 0 && StrEqual(sClassname, "weapon_tank_claw"))
		{
			enTank tank;
			g_aTanks.GetArray(g_iCurrentTank[attacker], tank);

			damage = damage * tank.damageMultiplier;
		}
		
		return;
	}
	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return;

	else if(g_iCurrentTank[victim] < 0)
		return;

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[victim], tank);

	if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && damagetype & DMG_BURN)
	{
		bImmune = true;
	}

	if(tank.damageImmunities & DAMAGE_IMMUNITY_EXPLOSIVES && damagetype & DMG_BLAST)
	{
		bImmune = true;
	}

	if(tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE && (L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw))
	{
		if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN || !(damagetype & DMG_BURN))
		{
			bImmune = true;
		}
	}

	if(tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS && damagetype & DMG_BULLET)
	{
		bImmune = true;
	}

	char sClassname[64];
	GetEdictClassname(inflictor, sClassname, sizeof(sClassname));

	if(L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Machinegun || StrEqual(sClassname, "prop_minigun"))
	{
		damage = damage * g_hMinigunDamageMultiplier.FloatValue;
	}

	if(L4D2_GetWeaponId(inflictor) == L4D2WeaponId_GrenadeLauncher || StrEqual(sClassname, "grenade_launcher_projectile"))
	{
		damage = damage * g_hRPGDamageMultiplier.FloatValue;
	}
}

public Action Command_TankHP(int client, int args)
{
	int bestTank = 0;

	if(L4D2_IsTankInPlay())
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(IsFakeClient(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
				continue;
			
			else if(L4D_IsPlayerIncapacitated(i))
				continue;

			else if(g_iCurrentTank[i] < 0)
				continue;

			if(bestTank == 0 || RPG_Perks_GetClientHealth(i) > RPG_Perks_GetClientHealth(bestTank))
				bestTank = i;
		}

		if(bestTank == 0)
			return Plugin_Handled;

		PrintToChat(client, "Damage dealt to %N:", bestTank);

		char PlayerFormat[256];

		int count = 0;

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			//else if(IsFakeClient(i))
			//	continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			if(count % 2 == 1)
			{
				Format(PlayerFormat, sizeof(PlayerFormat), "%s%N [%.1f{PERCENT}]", PlayerFormat, i, RPG_Tanks_GetDamagePercent(i, bestTank));

				ReplaceString(PlayerFormat, sizeof(PlayerFormat), "{PERCENT}", "%%");
				PrintToChat(client, PlayerFormat);

				PlayerFormat[0] = EOS;
			}
			else
			{
				Format(PlayerFormat, sizeof(PlayerFormat), "%s%N [%.1f{PERCENT}] | ", PlayerFormat, i, RPG_Tanks_GetDamagePercent(i, bestTank));
			}

			count++;
		}

		if(count % 2 == 1)
		{
			PlayerFormat[strlen(PlayerFormat) - 2] = EOS;

			ReplaceString(PlayerFormat, sizeof(PlayerFormat), "{PERCENT}", "%%");
			PrintToChat(client, PlayerFormat);
		}
	}
	return Plugin_Handled;
}
public Action Command_TankInfo(int client, int args)
{
	Handle hMenu = CreateMenu(TankInfo_MenuHandler);

	char TempFormat[200];

	bool tiersThatExist[4];

	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank tank;
		g_aTanks.GetArray(i, tank);
		
		tiersThatExist[tank.tier] = true;
	}	

	for(int i=1;i <= 3;i++)
	{
		if(tiersThatExist[i])
		{
			Format(TempFormat, sizeof(TempFormat), "Tier %i Tanks", i);
			char sInfo[11];
			IntToString(i, sInfo, sizeof(sInfo));

			AddMenuItem(hMenu, sInfo, TempFormat, ITEMDRAW_DEFAULT);
		}
	}

	FormatEx(TempFormat, sizeof(TempFormat), "Choose a Tier to learn about its Tanks\nEntries are a Jackpot based system to determine a winner\nEntries for Untiered Tank : %i", g_hEntriesUntiered.IntValue);
	SetMenuTitle(hMenu, TempFormat);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int TankInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[11];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		ShowTankList(client, StringToInt(sInfo));
	}	

	return 0;
}

public Action ShowTankList(int client, int tier)
{
	Handle hMenu = CreateMenu(TankList_MenuHandler);

	char TempFormat[200];

	ArrayList aTanks = g_aTanks.Clone();

	SortADTArrayCustom(aTanks, SortADT_Tanks);

	for(int i=0;i < aTanks.Length;i++)
	{
		enTank tank;
		aTanks.GetArray(i, tank);

		if(tank.tier != tier)
			continue;

		Format(TempFormat, sizeof(TempFormat), "%s Tank", tank.name);

		AddMenuItem(hMenu, tank.name, TempFormat, ITEMDRAW_DEFAULT);
	}

	delete aTanks;

	int entries[4];
	
	entries[0] = g_hEntriesUntiered.IntValue;
	entries[1] = g_hEntriesTierOne.IntValue;
	entries[2] = g_hEntriesTierTwo.IntValue;
	entries[3] = g_hEntriesTierThree.IntValue;

	FormatEx(TempFormat, sizeof(TempFormat), "Choose a Tank to view its Info\nEntries for Tier %i Tank : %i", tier, entries[tier]);
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int TankList_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Command_TankInfo(client, 0);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[32];
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo));

		ShowTargetTankInfo(client, TankNameToTankIndex(sInfo));
	}	

	return 0;

}


public Action ShowTargetTankInfo(int client, int tankIndex)
{
	Handle hMenu = CreateMenu(TargetTankInfo_MenuHandler);

	char TempFormat[512];

	enTank tank;
	g_aTanks.GetArray(tankIndex, tank);


	for(int i=0;i < tank.aPassiveAbilities.Length;i++)
	{
		enPassiveAbility passiveAbility;
		tank.aPassiveAbilities.GetArray(i, passiveAbility);

		Format(TempFormat, sizeof(TempFormat), "[PASSIVE] %s", passiveAbility.name);

		AddMenuItem(hMenu, tank.name, TempFormat, ITEMDRAW_DEFAULT);
	}

	for(int i=0;i < tank.aActiveAbilities.Length;i++)
	{
		enActiveAbility activeAbility;
		tank.aActiveAbilities.GetArray(i, activeAbility);

		Format(TempFormat, sizeof(TempFormat), "[ACTIVATED] %s", activeAbility.name);

		AddMenuItem(hMenu, tank.name, TempFormat, ITEMDRAW_DEFAULT);
	}

	if(GetMenuItemCount(hMenu) == 0)
		AddMenuItem(hMenu, tank.name, "No Abilities", ITEMDRAW_DEFAULT);

	char immunityFormat[32];
	FormatEx(immunityFormat, sizeof(immunityFormat), "Nothing");

	if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE && tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS )
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Melee, Fire & Bullets");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE)
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Melee & Fire");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE && tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS )
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Melee & Bullets");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS )
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Fire & Bullets");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN)
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Fire");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE)
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Melee");
	}
	else if(tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS )
	{
		FormatEx(immunityFormat, sizeof(immunityFormat), "Bullets");
	}

	FormatEx(TempFormat, sizeof(TempFormat), "%s Tank | Choose an Ability for info\nMax HP : %i | Entries : %i\nAverage XP : %i | Immune to : %s\n%s", tank.name, tank.maxHP, tank.entries, (tank.XPRewardMin + tank.XPRewardMax) / 2, immunityFormat, tank.description);
	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int TargetTankInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		char sInfo[32];
		GetMenuItem(hMenu, 0, sInfo, sizeof(sInfo));

		enTank tank;
		g_aTanks.GetArray(TankNameToTankIndex(sInfo), tank);

		ShowTankList(client, tank.tier);
	}
	else if(action == MenuAction_Select)
	{		
		char sName[64], sInfo[32];
		int dummy_value;
		GetMenuItem(hMenu, item, sInfo, sizeof(sInfo), dummy_value, sName, sizeof(sName));

		if(StrEqual(sName, "No Abilities"))
		{
			GetMenuItem(hMenu, 0, sInfo, sizeof(sInfo));

			enTank tank;
			g_aTanks.GetArray(TankNameToTankIndex(sInfo), tank);

			ShowTankList(client, tank.tier);

			return 0;
		}

		int tankIndex = TankNameToTankIndex(sInfo);

		ShowTargetAbilityInfo(client, tankIndex, sName);
	}	

	return 0;
}

public Action ShowTargetAbilityInfo(int client, int tankIndex, char sName[64])
{
	Handle hMenu = CreateMenu(TargetAbilityInfo_MenuHandler);

	char TempFormat[512];

	enTank tank;
	g_aTanks.GetArray(tankIndex, tank);

	char description[512];

	if(strncmp(sName, "[PASSIVE] ", 10) == 0)
	{
		int abilityIndex = AbilityNameToAbilityIndex(sName, tankIndex, true);

		enPassiveAbility passiveAbility;
		tank.aPassiveAbilities.GetArray(abilityIndex, passiveAbility);

		strcopy(description, sizeof(description), passiveAbility.description);

		FormatEx(TempFormat, sizeof(TempFormat), " %s\n%s", sName, description);
	}
	else
	{
		int abilityIndex = AbilityNameToAbilityIndex(sName, tankIndex, false);

		enActiveAbility activeAbility;
		tank.aActiveAbilities.GetArray(abilityIndex, activeAbility);

		strcopy(description, sizeof(description), activeAbility.description);

		if(activeAbility.minCooldown == 0 && activeAbility.maxCooldown == 0)
		{
			FormatEx(TempFormat, sizeof(TempFormat), " %s\nDelay: Controlled by Passive Abilities\n%s", sName, description);
		}
		else if(activeAbility.minCooldown == activeAbility.maxCooldown)
		{
			FormatEx(TempFormat, sizeof(TempFormat), " %s\nDelay: %i seconds\n%s", sName, activeAbility.minCooldown, description);
		}
		else
		{
			FormatEx(TempFormat, sizeof(TempFormat), " %s\nDelay: %i ~ %i seconds\n%s", sName, activeAbility.minCooldown, activeAbility.maxCooldown, description);
		}
	}

	AddMenuItem(hMenu, tank.name, "Back", ITEMDRAW_DEFAULT);

	SetMenuTitle(hMenu, TempFormat);

	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int TargetAbilityInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		hMenu = INVALID_HANDLE;
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		char sInfo[32];
		GetMenuItem(hMenu, 0, sInfo, sizeof(sInfo));

		int tankIndex = TankNameToTankIndex(sInfo);
		enTank tank;
		g_aTanks.GetArray(tankIndex, tank);

		ShowTargetTankInfo(client, tankIndex);
	}
	else if(action == MenuAction_Select)
	{		
		char sInfo[32];
		GetMenuItem(hMenu, 0, sInfo, sizeof(sInfo));

		int tankIndex = TankNameToTankIndex(sInfo);
		enTank tank;
		g_aTanks.GetArray(tankIndex, tank);

		ShowTargetTankInfo(client, tankIndex);
	}	

	return 0;
}


public int SortADT_Tanks(int index1, int index2, Handle array, Handle hndl)
{
	enTank tank1;
	enTank tank2;

	GetArrayArray(array, index1, tank1);
	GetArrayArray(array, index2, tank2);

	if(tank1.maxHP != tank2.maxHP)
	{
		return tank1.maxHP - tank2.maxHP;
	}

	return strcmp(tank1.name, tank2.name);
	
}


public void OnStartTouchTriggerGravity(const char[] output, int caller, int activator, float delay)
{
	int client = activator;
	
	if(!IsPlayer(client))
		return;

	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor && RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		PrintToChatAll(" \x03%N\x01 entered a trigger_gravity. %N will be converted to a normal Tank now.", client, i);

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return Plugin_Continue;

	if(g_iCurrentTank[victim] >= 0)
	{
		enTank tank;
		g_aTanks.GetArray(g_iCurrentTank[victim], tank);

		if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && L4D_IsPlayerOnFire(victim))
		{
			ExtinguishEntity(victim);
		}
	}

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(attacker == 0)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
		return Plugin_Continue;

	int damage = GetEventInt(hEvent, "dmg_health");

	g_iDamageTaken[victim][attacker] += damage;

	return Plugin_Continue;
}

public Action Event_EnterCheckpoint(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor && RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return Plugin_Continue;

	int door = GetEventInt(hEvent, "door");

	if(L4D_GetCheckpointLast() == door)
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
				continue;

			else if(L4D_IsPlayerIncapacitated(i))
				continue;

			else if(g_iCurrentTank[i] < 0)
				continue;

			PrintToChatAll(" \x03%N\x01 entered a safe room. %N will be converted to a normal Tank now.", client, i);

			SetClientName(i, "Tank");

			RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[i] = TANK_TIER_UNTIERED;
		}
	}

	return Plugin_Continue;
}


public Action Event_FinaleWin(Handle hEvent, char[] Name, bool dontBroadcast)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		PrintToChatAll(" The Finale was won. %N will be converted to a normal Tank now.", i);

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}

	return Plugin_Continue;
}

public Action Event_RoundEnd(Handle hEvent, char[] Name, bool dontBroadcast)
{
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		else if(g_iCurrentTank[i] < 0)
			continue;

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}

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

	if(L4D_IsFinaleEscapeInProgress())
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
				continue;

			else if(L4D_IsPlayerIncapacitated(i))
				continue;

			else if(g_iCurrentTank[i] < 0)
				continue;

			PrintToChatAll(" The Finale was won. %N will be converted to a normal Tank now.", i);

			SetClientName(i, "Tank");

			RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[i] = TANK_TIER_UNTIERED;
		}

	}
	
	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[victim], tank);

	int XPReward = GetRandomInt(tank.XPRewardMin, tank.XPRewardMax);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		
		float fDamageRatio = RPG_Tanks_GetDamagePercent(i, victim) / 100.0;

		if(LibraryExists("GunXP-RPG"))
		{
			PrintToChat(i, "You dealt\x03 %.1f%%\x01 of %N's max HP as damage", fDamageRatio * 100.0, victim);
		}

		float fMinDamageRatio = 0.05;

		if(LibraryExists("GunXP-RPG") && GunXP_RPG_GetClientLevel(i) <= 6)
			fMinDamageRatio = 0.01;

		if(LibraryExists("GunXP-RPG") && fDamageRatio < fMinDamageRatio)
		{
			PrintToChat(i, "This is not enough to gain XP rewards. (Min. %.0f%%)", victim, fMinDamageRatio * 100.0);

			Call_StartForward(g_fwOnRPGTankKilled);

			
			Call_PushCell(victim);
			
			Call_PushCell(i);
			
			Call_PushCell(-1);

			Call_Finish();

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

	int tankCount = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			return Plugin_Continue;

		else if(L4D_IsPlayerIncapacitated(i))
			continue;

		tankCount++;
	}

	return Plugin_Continue;
}

stock int TankNameToTankIndex(char name[32])
{
	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank iTank;
		g_aTanks.GetArray(i, iTank);
		
		if(StrEqual(name, iTank.name))
			return i;
	}

	return -1;
}

stock int AbilityNameToAbilityIndex(char name[64], int tankIndex, bool passive)
{
	enTank tank;
	g_aTanks.GetArray(tankIndex, tank);

	char abilityName[32];
	char dummy_value[32];

	int pos = BreakString(name, dummy_value, sizeof(dummy_value));

	FormatEx(abilityName, sizeof(abilityName), name[pos]);

	if(strncmp(name, "[PASSIVE] ", 10) == 0)
	{
		for(int i=0;i < tank.aPassiveAbilities.Length;i++)
		{
			enPassiveAbility passiveAbility;
			tank.aPassiveAbilities.GetArray(i, passiveAbility);
			
			if(StrEqual(abilityName, passiveAbility.name))
				return i;
		}
	}
	else
	{
		for(int i=0;i < tank.aActiveAbilities.Length;i++)
		{
			enActiveAbility activeAbility;
			tank.aActiveAbilities.GetArray(i, activeAbility);
			
			if(StrEqual(abilityName, activeAbility.name))
				return i;
		}
	}



	return -1;
}