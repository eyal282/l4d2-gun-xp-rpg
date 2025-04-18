#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <left4dhooks>
#include <smlib>
#include <ps_api>

//#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <autoexecconfig>
#include <GunXP-RPG>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

#define SOUND_CHANNEL SNDCHAN_STATIC

#define IMMUNITY_SOUND "level/puck_fail.wav"

// How much times to play the sound?
#define IMMUNITY_SOUND_MULTIPLIER 100


public Plugin myinfo = {
	name = "RPG Tanks",
	author = "Eyal282",
	description = "Powerful tanks for RPG gamemodes.",
	version = PLUGIN_VERSION,
	url = "NULL"
};

ConVar g_hDifficulty;

ConVar g_hCarAlarmTankChance;

ConVar g_hInstantFinale;
ConVar g_hComboNeeded;
ConVar g_hMinigunDamageMultiplier;
ConVar g_hShotgunDamageMultiplier;
ConVar g_hRPGDamageMultiplier;

ConVar g_hPriorityImmunities;
ConVar g_hPriorityTankSpawn;

ConVar g_hXPRatioNotEnough;
ConVar g_hEntriesUntiered;
ConVar g_hEntriesTierOne;
ConVar g_hEntriesTierTwo;
ConVar g_hEntriesTierThree;
ConVar g_hEntriesTierFour;
ConVar g_hEntriesTierFive;

ConVar g_hAggroPerLevel;
ConVar g_hAggroCap;
ConVar g_hAggroPerSecond;
ConVar g_hAggroIncap;

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
	char chatDescription[512];

	int maxHP;
	int speed;

	float damageMultiplier;

	// reward of XP in Gun XP
	int XPRewardMin;
	int XPRewardMax;

	int damageImmunities;

	ArrayList aActiveAbilities;
	ArrayList aPassiveAbilities;

	int color;
}

ArrayList g_aTanks;
ArrayList g_aSpawningQueue;

GlobalForward g_fwOnRPGZombiePlayerSpawned;
GlobalForward g_fwOnRPGTankKilled;
GlobalForward g_fwOnUntieredTankKilled;
GlobalForward g_fwOnRPGTankCastActiveAbility;

int g_iMaxTier;
int g_iValidMaxTier;

int g_iCurrentTank[MAXPLAYERS+1] = { TANK_TIER_UNTIERED, ... };
int g_iAggroTarget[MAXPLAYERS+1] = { 0, ... };
bool g_bGaveTankAggro[MAXPLAYERS+1];

int g_iKillCombo;
int g_iOverrideNextTier = TANK_TIER_UNKNOWN;
int g_iOverrideNextTank = TANK_TIER_UNKNOWN;

// [victim][attacker]
int g_iDamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];

int g_iSpawnflags[2049] = { -1, ... };

bool g_bButtonLive = false;

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{

	CreateNative("RPG_Tanks_IsDamageImmuneTo", Native_IsDamageImmuneTo);
	CreateNative("RPG_Tanks_GetMaxTier", Native_GetMaxTier);
	CreateNative("RPG_Tanks_RegisterTank", Native_RegisterTank);
	CreateNative("RPG_Tanks_RegisterActiveAbility", Native_RegisterActiveAbility);
	CreateNative("RPG_Tanks_RegisterPassiveAbility", Native_RegisterPassiveAbility);
	CreateNative("RPG_Tanks_GetClientTank", Native_GetClientTank);
	CreateNative("RPG_Tanks_SetClientTank", Native_SetClientTank);
	CreateNative("RPG_Tanks_SpawnTank", Native_SpawnTank);
	CreateNative("RPG_Tanks_GetClientTankTier", Native_GetClientTankTier);
	CreateNative("RPG_Tanks_LoopTankArray", Native_LoopTankArray);
	CreateNative("RPG_Tanks_GetDamagePercent", Native_GetDamagePercent);
	CreateNative("RPG_Tanks_SetDamagePercent", Native_SetDamagePercent);
	CreateNative("RPG_Tanks_IsTankInPlay", Native_IsTankInPlay);
	CreateNative("RPG_Tanks_GetOverrideTier", Native_GetOverrideTier);
	CreateNative("RPG_Tanks_SetOverrideTier", Native_SetOverrideTier);
	CreateNative("RPG_Tanks_GetOverrideTank", Native_GetOverrideTank);
	CreateNative("RPG_Tanks_SetOverrideTank", Native_SetOverrideTank);


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

	else if(damageType & DMG_DROWNRECOVER)
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

public int Native_GetMaxTier(Handle caller, int numParams)
{
	if(GetNativeCell(1))
		return g_iMaxTier;
	
	return g_iValidMaxTier;
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

	char chatDescription[512];
	GetNativeString(5, chatDescription, sizeof(chatDescription));

	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");
	ReplaceString(chatDescription, sizeof(chatDescription), "{PERCENT}", "%%");

	int maxHP = GetNativeCell(6);

	int speed = GetNativeCell(7);
	float damageMultiplier = GetNativeCell(8);

	int XPRewardMin = GetNativeCell(9);
	int XPRewardMax = GetNativeCell(10);

	int damageImmunities = GetNativeCell(11);

	int color = GetNativeCell(12);
	int foundIndex = TankNameToTankIndex(name);

	tank.tier = tier;
	tank.entries = entries;
	tank.name = name;
	tank.description = description;
	tank.chatDescription = chatDescription;
	tank.maxHP = maxHP;
	tank.speed = speed;
	tank.damageMultiplier = damageMultiplier;
	tank.XPRewardMin = XPRewardMin;
	tank.XPRewardMax = XPRewardMax;
	tank.damageImmunities = damageImmunities;
	tank.aActiveAbilities = CreateArray(sizeof(enActiveAbility));
	tank.aPassiveAbilities = CreateArray(sizeof(enPassiveAbility));
	tank.color = color;

	if(tier > g_iMaxTier)
		g_iMaxTier = tier;

	if(entries > 0 && tier > g_iValidMaxTier)
		g_iValidMaxTier = tier;

	if(foundIndex != -1)
	{
		g_aTanks.SetArray(foundIndex, tank);

		if(LibraryExists("GunXP_RPG"))
			GunXP_RPG_RegisterNavigationRef("Tank", name, description, foundIndex);

		return foundIndex;
	}

	foundIndex = g_aTanks.PushArray(tank);

	if(LibraryExists("GunXP_RPG"))
		GunXP_RPG_RegisterNavigationRef("Tank", name, description, foundIndex);

	return foundIndex;
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

	// We register tankIndex, not abilityIndex.

	if(LibraryExists("GunXP_RPG"))
		GunXP_RPG_RegisterNavigationRef("Active Ability", name, description, pos);

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

	char description[512];
	GetNativeString(3, description, sizeof(description));

	ReplaceString(description, sizeof(description), "{PERCENT}", "%%");

	enPassiveAbility passiveAbility;

	passiveAbility.name = name;
	passiveAbility.description = description;


	// We register tankIndex, not abilityIndex.
	if(LibraryExists("GunXP_RPG"))
		GunXP_RPG_RegisterNavigationRef("Passive Ability", name, description, pos);

	if(foundIndex != -1)
	{
		tank.aPassiveAbilities.SetArray(foundIndex, passiveAbility);

		return foundIndex;
	}

	return tank.aPassiveAbilities.PushArray(passiveAbility);
}

public any Native_GetClientTank(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	return g_iCurrentTank[client];
}

public any Native_SetClientTank(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	int index = GetNativeCell(2);

	if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return false;

	g_iCurrentTank[client] = index;

	if(index == TANK_TIER_UNTIERED)
		return true;

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[client], tank);

	RPG_Perks_SetClientMaxHealth(client, tank.maxHP);
	RPG_Perks_SetClientHealth(client, tank.maxHP);

	char sName[64];
	FormatEx(sName, sizeof(sName), "%s Tank", tank.name);

	SetClientName(client, sName);

	if(!GetNativeCell(3))
		PrintToChatAll(" \x01A \x03Tier %i \x05%s Tank\x01 was apported:", tank.tier, tank.name);

	PrintToChatAll(tank.chatDescription);

	CalculateTankColor(client);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		g_iDamageTaken[client][i] = 0;

		if(tank.tier == 1)
			ClientCommand(i, "play ui/survival_medal.wav");

		else if(tank.tier == 2)
			ClientCommand(i, "play ui/critical_event_1.wav");

		else if(tank.tier == 3)
			ClientCommand(i, "play @#music/terror/clingingtohell4.wav");
	}

	for(int prio=-10;prio <= 10;prio++)
	{
		bool bApport = true;

		Call_StartForward(g_fwOnRPGZombiePlayerSpawned);

		Call_PushCell(prio);
		Call_PushCell(client);
		Call_PushCellRef(bApport);

		Call_Finish();
	}

	int size = tank.aActiveAbilities.Length;

	for(int i=0;i < size;i++)
	{
		enActiveAbility activeAbility;
		tank.aActiveAbilities.GetArray(i, activeAbility);

		if(activeAbility.minCooldown == 0 && activeAbility.maxCooldown == 0)
			continue;

		char TempFormat[64];
		FormatEx(TempFormat, sizeof(TempFormat), "Cast Active Ability #%i", i);

		RPG_Perks_ApplyEntityTimedAttribute(client, TempFormat, GetRandomFloat(float(activeAbility.minCooldown), float(activeAbility.maxCooldown)), COLLISION_SET, ATTRIBUTE_NEUTRAL);
	}

	return true;
}

public any Native_SpawnTank(Handle caller, int numParams)
{
	int index = GetNativeCell(1);

	int target = GetAnyClient();

	float fOrigin[3];

	// Accepts invalid client
	if(!L4D_GetRandomPZSpawnPosition(target, view_as<int>(L4D2ZombieClass_Tank), 10, fOrigin))
		return 0;

	g_iOverrideNextTank = index;

	int client = L4D2_SpawnTank(fOrigin, view_as<float>({0.0, 0.0, 0.0}));

	g_aSpawningQueue.Push(GetClientUserId(client));

	return client;
}

public any Native_GetClientTankTier(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return TANK_TIER_UNTIERED;

	else if(g_iCurrentTank[client] < 0)
		return TANK_TIER_UNTIERED;

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[client], tank);

	return tank.tier;
}


public any Native_LoopTankArray(Handle caller, int numParams)
{
	int index = GetNativeCell(1);

	if(index >= g_aTanks.Length)
		return false;

	enTank tank;
	g_aTanks.GetArray(index, tank);

	SetNativeCellRef(2, tank.tier);
	SetNativeString(3, tank.name, 32);

	return true;
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

public any Native_GetOverrideTier(Handle caller, int numParams)
{
	return g_iOverrideNextTier;
}

public any Native_SetOverrideTier(Handle caller, int numParams)
{
	int tier = GetNativeCell(1);

	if(tier <= g_iMaxTier)
	{
		g_iOverrideNextTier = tier;
	}

	return 0;
}


public any Native_GetOverrideTank(Handle caller, int numParams)
{
	return g_iOverrideNextTank;
}

public any Native_SetOverrideTank(Handle caller, int numParams)
{
	int tank = GetNativeCell(1);

	g_iOverrideNextTank = tank;

	if(g_iOverrideNextTank <= TANK_TIER_UNKNOWN)
		g_iOverrideNextTank = TANK_TIER_UNKNOWN;

	return 0;
}

public void OnPluginEnd()
{
	int door = L4D_GetCheckpointLast();

	if(door != -1)
	{
		AcceptEntityInput(door, "InputUnlock");
		SetEntProp(door, Prop_Data, "m_bLocked", 0);
		ChangeEdictState(door, 0);

		if(g_iSpawnflags[door] != -1)
		{
			SetEntProp(door, Prop_Send, "m_spawnflags", g_iSpawnflags[door]);
		}

		g_iSpawnflags[door] = -1;
	}
}
public void OnPluginStart()
{

	//g_aUnlockItems = CreateArray(sizeof(enProduct));
	if(g_aTanks == null)
		g_aTanks = CreateArray(sizeof(enTank));

	if(g_aSpawningQueue == null)
		g_aSpawningQueue = CreateArray(1);

	g_fwOnRPGZombiePlayerSpawned = CreateGlobalForward("RPG_Perks_OnZombiePlayerSpawned", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnRPGTankKilled = CreateGlobalForward("RPG_Tanks_OnRPGTankKilled", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnUntieredTankKilled = CreateGlobalForward("RPG_Tanks_OnUntieredTankKilled", ET_Ignore, Param_Cell, Param_Cell);
	g_fwOnRPGTankCastActiveAbility = CreateGlobalForward("RPG_Tanks_OnRPGTankCastActiveAbility", ET_Ignore, Param_Cell, Param_Cell);

	#if defined _autoexecconfig_included
	
	AutoExecConfig_SetFile("RPG_Tanks");
	
	#endif

	RegConsoleCmd("sm_findtank", Command_FindTank, "sm_findtank <value> - Finds a Tank, Active Ability, or Passive Ability by name.");
	RegConsoleCmd("sm_tankinfo", Command_TankInfo);
	RegConsoleCmd("sm_tankhp", Command_TankHP);

	g_hAggroCap = UC_CreateConVar("rpg_tanks_aggro_cap", "100.0", "Maximum amount of aggro that can be earned. Plugins that modify aggro will ignore this.");
	g_hAggroPerSecond = UC_CreateConVar("rpg_tanks_aggro_per_second", "3.5", "Aggro gained per second you are damaging the tank. 1 Aggro is lost per second you are not damaging the tank.");
	g_hAggroPerLevel = UC_CreateConVar("rpg_tanks_aggro_per_level", "0.2", "Aggro gained per Gun-XP Level. This aggro cannot be lost and is a bonus on top of whatever aggro you have.");
	g_hAggroIncap = UC_CreateConVar("rpg_tanks_aggro_incap", "0.5", "Multiplies a survivor's aggro by this much when they are incapacitated");
	
	g_hInstantFinale = UC_CreateConVar("rpg_tanks_instant_finale", "1", "Finale is instant? WARNING! This can cheese the tanks due to low common infected");
	g_hComboNeeded = UC_CreateConVar("rpg_tanks_finale_combo_needed", "3", "Amount of Tank kills needed to trigger a powerful tank event");

	g_hShotgunDamageMultiplier = UC_CreateConVar("rpg_tanks_shotgun_damage_multiplier", "1.2", "Shotgun damage multiplier");
	g_hMinigunDamageMultiplier = UC_CreateConVar("rpg_tanks_minigun_damage_multiplier", "0.1", "Minigun damage multiplier");
	g_hRPGDamageMultiplier = UC_CreateConVar("rpg_tanks_rpg_damage_multiplier", "0.05", "RPG damage multiplier");

	g_hPriorityImmunities = UC_CreateConVar("rpg_tanks_priority_immunities", "2", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 to give a tank their immunity from fire or melee.\nWhen making a plugin, feel free to track this cvar's value for reference.");
	g_hPriorityTankSpawn = UC_CreateConVar("rpg_tanks_priority_rpg_tank_spawn", "-5", "Do not mindlessly edit this cvar.\nThis cvar is the order of priority from -10 to 10 that when a tank spawns, check what tier to give it and give it max HP.");

	g_hXPRatioNotEnough = UC_CreateConVar("rpg_tanks_xp_ratio_not_enough_damage", "0.05", "Ratio of XP to gain when a player doesn't do minimum damage.");
	g_hEntriesUntiered = UC_CreateConVar("rpg_tanks_entries_untiered", "5", "Entries to spawn an untiered tank.");
	g_hEntriesTierOne = UC_CreateConVar("rpg_tanks_entries_tier_one", "0", "Entries to spawn a tier one tank.");
	g_hEntriesTierTwo = UC_CreateConVar("rpg_tanks_entries_tier_two", "0", "Entries to spawn a tier two tank.");
	g_hEntriesTierThree = UC_CreateConVar("rpg_tanks_entries_tier_three", "0", "Entries to spawn a tier three tank.");
	g_hEntriesTierFour = UC_CreateConVar("rpg_tanks_entries_tier_four", "0", "Entries to spawn a tier four tank.");
	g_hEntriesTierFive = UC_CreateConVar("rpg_tanks_entries_tier_five", "0", "Entries to spawn a tier five tank (unlikely to be ever enabled).");
	
	#if defined _autoexecconfig_included
	
	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();
	
	#endif

	RegPluginLibrary("RPG_Tanks");

	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Pre);
	HookEvent("tank_killed", Event_TankKilledOrDisconnect, EventHookMode_Post);
	HookEvent("player_disconnect", Event_TankKilledOrDisconnect, EventHookMode_Post);
	HookEvent("finale_start", Event_FinaleStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	HookEntityOutput("trigger_gravity", "OnStartTouch", OnStartTouchTriggerGravity);

	g_hCarAlarmTankChance = CreateConVar("rpg_tanks_car_alarm_tank_chance", "50", "Chance to spawn tank when an alarm is tripped", _, true, 0.0, true, 100.0);

	g_hDifficulty = FindConVar("z_difficulty");

	HookConVarChange(g_hDifficulty, cvChange_Difficulty);
}

public void OnMapStart()
{
	g_iMaxTier = TANK_TIER_UNTIERED;
	g_iValidMaxTier = TANK_TIER_UNTIERED;

	for(int i=0;i < g_aTanks.Length;i++)
	{
		enTank tank;
		g_aTanks.GetArray(i, tank);

		if(tank.tier > g_iMaxTier)
			g_iMaxTier = tank.tier;

		if(tank.entries > 0 && tank.tier > g_iValidMaxTier)
			g_iValidMaxTier = tank.tier;
	}
	
	for(int i=0;i < sizeof(g_iCurrentTank);i++)
	{
		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}

	g_iKillCombo = 0;
	g_iOverrideNextTier = TANK_TIER_UNKNOWN;
	g_bButtonLive = false;

	PrecacheSound(IMMUNITY_SOUND);

	// Also used for aggro system and finale convert system
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

public void OnClientDisconnect(int client)
{
	if(g_aSpawningQueue.FindValue(GetClientUserId(client)) != -1)
	{
		g_aSpawningQueue.Erase(g_aSpawningQueue.FindValue(GetClientUserId(client)));
	}
}

public void OnEntityDestroyed(int entity)
{
	if(!IsValidEntityIndex(entity))
		return;

	g_iSpawnflags[entity] = -1;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsValidEntityIndex(entity))
		return;

	if(StrEqual(classname, "info_changelevel"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, Event_TrueEnterEndCheckpoint);
	}
}

public void Event_TrueEnterEndCheckpoint(int zoneEntity, int toucher)
{
	if(!IsPlayer(toucher))
		return;

	else if(L4D_GetClientTeam(toucher) != L4DTeam_Survivor)
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

		else if(!L4D2_IsGenericCooperativeMode())
			continue;

		PrintToChatAll(" \x03%N\x01 entered a safe room. %N will be converted to a normal Tank now.", toucher, i);

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}
}
#define MAX_BUTTONS 26

int g_iLastButtons[MAXPLAYERS+1];

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(IsPlayerAlive(client))
	{
		for (int i = 0; i < MAX_BUTTONS; i++)
		{
			int button = (1 << i);

			if ((buttons & button))
			{
				if (!(g_iLastButtons[client] & button))
				{
					OnButtonPressed(client, button);
				}
			}
		}
	}

	g_iLastButtons[client] = buttons;

	return Plugin_Continue;
}

public void OnButtonPressed(int client, int button)
{
	if(!(button & IN_USE))
		return;

	else if(L4D2_GetCurrentFinaleStage() != FINALE_GAUNTLET_ESCAPE)
		return;

	int target = GetClientAimTarget(client, false);

	if(target == -1)
		return;

	char sClassname[64];
	GetEdictClassname(target, sClassname, sizeof(sClassname));

	if(!StrEqual(sClassname, "trigger_finale"))
		return;

	else if(GetAimDistanceFromTarget(client, target) > 100.0)
		return;

	char sModelname[PLATFORM_MAX_PATH];
	GetEntPropString(target, Prop_Data, "m_ModelName", sModelname, sizeof(sModelname));

	if(StrContains(sModelname, "radio", false) == -1)
		return;

	else if(!g_bButtonLive)
		return;

	int tier = GetRandomInt(2, 3);

	char sValue[16];
	g_hDifficulty.GetString(sValue, sizeof(sValue));
	
	if(!StrEqual(sValue, "Impossible", false))
	{
		if(StrEqual(sValue, "Hard"))
		{
			tier = 2;
		}
		else
		{
			tier = 1;
		}
	}

	char sVoteSubject[64];
	FormatEx(sVoteSubject, sizeof(sVoteSubject), "Spawn Tier %i Tank?", tier);

	if(StartCustomVote(-1 * tier, "@survivors", 51, sVoteSubject) != 0)
		return;

	g_iKillCombo = 0;
	g_bButtonLive = false;
	L4D2_SetEntityGlow(target, L4D2Glow_None, 0, 0, {255, 255, 255}, false);
}

public void sm_vote_OnVoteFinished_Post(int client, int VotesFor, int VotesAgainst, int PercentsToPass, bool bCanVote[MAXPLAYERS], char[] VoteSubject, bool bInternal, Handle Caller)
{
	if(Caller != GetMyHandle())
		return;
	
	float ForPercents = (float(VotesFor) / (float(VotesFor) + float(VotesAgainst))) * 100.0;

	if(ForPercents < PercentsToPass)
		return;

	int tier = -1 * client;

	if(tier > 3 || tier < 1)
		return;

	g_iOverrideNextTier = tier;

	PrintToChatAll("\x04[Gun-XP] \x01The next Tank that spawns will be\x03 Tier %i", tier);
}

public void Plugins_OnCarAlarmPost(int userid)
{
	float fChance = g_hCarAlarmTankChance.FloatValue / 100.0;

	float fGamble = GetRandomFloat(0.0, 1.0);

	if(fGamble < fChance)
	{
		if(L4D2_IsTankInPlay())
			return;

		int client = GetClientOfUserId(userid);

		float fOrigin[3];

		// Accepts invalid client of user id.
		if(!L4D_GetRandomPZSpawnPosition(client, view_as<int>(L4D2ZombieClass_Tank), 10, fOrigin))
			return;

		L4D2_SpawnTank(fOrigin, view_as<float>({0.0, 0.0, 0.0}));

		PrintToChatAll("\x04[Gun-XP] \x01A Tank will spawn from the\x03 Car Alarm");
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

		CalculateTankAggro(i);

		enTank tank;
		g_aTanks.GetArray(g_iCurrentTank[i], tank);

		if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN)
		{
			if(L4D_IsPlayerOnFire(i))
			{
				ExtinguishEntity(i);
			}
		}

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

		if(L4D_IsFinaleEscapeInProgress() && L4D2_IsGenericCooperativeMode())
		{
			PrintToChatAll(" The Finale was won. %N will be converted to a normal Tank now.", i);

			SetClientName(i, "Tank");

			RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[i] = TANK_TIER_UNTIERED;
		}
	}

	return Plugin_Continue;
}

// Runs every 0.5 sec, so remember to account for actions that involve 1 second (to prevent duplication involving the fact it runs twice a second), especially given that aggro is a timed attribute in seconds.
stock void CalculateTankAggro(int tank)
{
	int winner = 0;

	float fWinnerAggro;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		if(g_bGaveTankAggro[i])
		{
			// Divide by 2 because this is called twice a second.
			float fAggroToGive = g_hAggroPerSecond.FloatValue / 2.0;

			// Negate loss of 1 aggro per second if we gained aggro by damaging the Tank.
			fAggroToGive += 0.5;
			RPG_Perks_ApplyEntityTimedAttribute(i, "Tank Aggro", fAggroToGive, COLLISION_ADD, ATTRIBUTE_NEUTRAL);
			RPG_Perks_ApplyEntityTimedAttribute(i, "Tank Aggro", g_hAggroCap.FloatValue, COLLISION_SET_IF_HIGHER, ATTRIBUTE_NEUTRAL);

			g_bGaveTankAggro[i] = false;


		}

		if(RPG_Perks_IsEntityTimedAttribute(i, "Invincible"))
		{
			// If a Survivor is invincible, the Tank will not target them..
			RPG_Perks_ApplyEntityTimedAttribute(i, "Tank Aggro", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
		}
	}

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		if(winner == 0)
		{
			float fAggro;
			RPG_Perks_IsEntityTimedAttribute(i, "Tank Aggro", fAggro);

			fAggro += (g_hAggroPerLevel.FloatValue * GunXP_RPG_GetClientLevel(i));

			if(L4D_IsPlayerIncapacitated(i))
			{
				fAggro *= g_hAggroIncap.FloatValue;
			}

			winner = i;
			fWinnerAggro = fAggro;
		}		
		else
		{
			float fAggro;
			RPG_Perks_IsEntityTimedAttribute(i, "Tank Aggro", fAggro);

			fAggro += (g_hAggroPerLevel.FloatValue * GunXP_RPG_GetClientLevel(i));

			if(L4D_IsPlayerIncapacitated(i))
			{
				fAggro *= g_hAggroIncap.FloatValue;
			}

			if(fAggro > fWinnerAggro)
			{
				winner = i;
				fWinnerAggro = fAggro;
			}

		}
	}

	float fAggro;
	RPG_Perks_IsEntityTimedAttribute(1, "Tank Aggro", fAggro);

	g_iAggroTarget[tank] = winner;

	// Lose aggro twice as fast if you are the tank's target.
	RPG_Perks_ApplyEntityTimedAttribute(winner, "Tank Aggro", -0.5, COLLISION_ADD, ATTRIBUTE_NEUTRAL);
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

		else if(!L4D2_IsGenericCooperativeMode())
			continue;

		PrintToChatAll(" \x03%N\x01 will be converted to a normal Tank for the difficulty change.", i);

		SetClientName(i, "Tank");

		RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
		//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[i] = TANK_TIER_UNTIERED;
	}

	g_iOverrideNextTier = TANK_TIER_UNKNOWN;
}

public void GunXP_OnReloadRPGPlugins()
{
	#if defined _GunXP_RPG_included

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

		UC_PrintToChatRoot("Didn't reload RPG-Tanks.smx because a tiered tank is alive.");
		return;
	}

	GunXP_ReloadPlugin();
	#endif

}

public void GunXP_OnTriggerNavigationRef(int client, int navSerial, int serial, char[] classification, char[] name, char[] description)
{
	if(StrEqual(classification, "Tank"))
	{
		ShowTargetTankInfo(client, serial);
	}
	char sInfo[64];

	if(StrEqual(classification, "Activated Ability"))
	{
		FormatEx(sInfo, sizeof(sInfo), "[ACTIVATED] %s", name);
		ShowTargetAbilityInfo(client, serial, sInfo);
	}
	if(StrEqual(classification, "Passive Ability"))
	{
		FormatEx(sInfo, sizeof(sInfo), "[PASSIVE] %s", name);
		ShowTargetAbilityInfo(client, serial, sInfo);
	}
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if(L4D2_GetPlayerZombieClass(specialInfected) != L4D2ZombieClass_Tank)
		return Plugin_Continue;

	else if(g_iAggroTarget[specialInfected] == 0)
		return Plugin_Continue;

	// PrintToChatAll("%N is targeting %N.", specialInfected, g_iAggroTarget[specialInfected]);
	curTarget = g_iAggroTarget[specialInfected];
	return Plugin_Changed;
}
public Action RPG_Perks_OnShouldClosetsRescue()
{
	if(L4D_IsMissionFinalMap(true) && L4D2_GetCurrentFinaleStage() == 18)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void RPG_Perks_OnGetSpecialInfectedClass(int priority, int client, L4D2ZombieClassType &zclass)
{
	if(priority != 0)
		return;
		
	else if(zclass != L4D2ZombieClass_Tank)
	{
		if(zclass != L4D2ZombieClass_Tank)
		{
			return;
		}
	}

	int tankCount = 0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		tankCount++;
	}

	if(tankCount >= 2 && L4D_IsCoopMode() && g_iOverrideNextTier == TANK_TIER_UNKNOWN && g_iOverrideNextTank == TANK_TIER_UNKNOWN)
	{
		if(IsFakeClient(client))
		{
			L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
			KickClient(client);
		}
	}
}

public void RPG_Perks_OnZombiePlayerSpawned(int priority, int client, bool &bApport)
{
	if(priority == -10)
	{
		if(g_aSpawningQueue.FindValue(GetClientUserId(client)) != -1)
		{
			g_aSpawningQueue.Erase(g_aSpawningQueue.FindValue(GetClientUserId(client)));
			bApport = true;
		}
	}
	if(priority != 10)
		return;

	else if(RPG_Perks_GetZombieType(client) != ZombieType_Tank)
		return;
	
	// To let apport or any plugin check if a spawning tank is overrided (of course this only works before RPG_Perks_OnZombiePlayerSpawned on priority 10 (so choose a lower priority!))

	g_iOverrideNextTank = TANK_TIER_UNKNOWN;
	g_iOverrideNextTier = TANK_TIER_UNKNOWN;
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
	
	int entries[6];
	
	entries[0] = g_hEntriesUntiered.IntValue;
	entries[1] = g_hEntriesTierOne.IntValue;
	entries[2] = g_hEntriesTierTwo.IntValue;
	entries[3] = g_hEntriesTierThree.IntValue;
	entries[4] = g_hEntriesTierFour.IntValue;
	entries[5] = g_hEntriesTierFive.IntValue;
	

	int totalEntries = 0;

	for(int i=0;i < sizeof(entries);i++)
	{
		totalEntries += entries[i];	
	}
	
	int RNG = GetRandomInt(1, totalEntries);

	int winnerTier = 0;

	for(int i=0;i <= g_iValidMaxTier;i++)
	{
		if(RNG > initValue && RNG <= (initValue + entries[i]))
		{
			winnerTier = i;
			break;
		}
		initValue += entries[i];
	}

	if(g_iOverrideNextTier != TANK_TIER_UNKNOWN)
	{
		winnerTier = g_iOverrideNextTier;

		// Let apport see these changes.
		// g_iOverrideNextTier = TANK_TIER_UNKNOWN;
	}

	if(winnerTier == 0 && g_iOverrideNextTank == TANK_TIER_UNKNOWN)
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

	if(g_iOverrideNextTank != TANK_TIER_UNKNOWN)
	{
		if(g_iOverrideNextTank == TANK_TIER_UNTIERED)
		{
			winnerTank.tier = 0;
			winnerTankIndex = TANK_TIER_UNTIERED;
		}
		else
		{
			g_aTanks.GetArray(g_iOverrideNextTank, winnerTank);
			winnerTankIndex = g_iOverrideNextTank;
		}

		// Let apport see these changes.
		// g_iOverrideNextTank = TANK_TIER_UNKNOWN;
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


	PrintToChatAll(" \x01A \x03Tier %i \x05%s Tank\x01 has spawned:", winnerTank.tier, winnerTank.name);
	PrintToChatAll(winnerTank.chatDescription);

	CalculateTankColor(client);

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(IsFakeClient(i))
			continue;

		if(winnerTank.tier == 1)
			ClientCommand(i, "play ui/survival_medal.wav");

		else if(winnerTank.tier == 2)
			ClientCommand(i, "play ui/critical_event_1.wav");

		else if(winnerTank.tier == 3)
			ClientCommand(i, "play @#music/terror/clingingtohell4.wav");
	}
	int size = winnerTank.aActiveAbilities.Length;

	for(int i=0;i < size;i++)
	{
		enActiveAbility activeAbility;
		winnerTank.aActiveAbilities.GetArray(i, activeAbility);

		if(activeAbility.minCooldown == 0 && activeAbility.maxCooldown == 0)
			continue;

		char TempFormat[64];
		FormatEx(TempFormat, sizeof(TempFormat), "Cast Active Ability #%i", i);

		RPG_Perks_ApplyEntityTimedAttribute(client, TempFormat, GetRandomFloat(float(activeAbility.minCooldown), float(activeAbility.maxCooldown)), COLLISION_SET, ATTRIBUTE_NEUTRAL);
	}

	int door = L4D_GetCheckpointLast();

	if(door != -1)
	{
		AcceptEntityInput(door, "Close");

		AcceptEntityInput(door, "InputLock");
		SetEntProp(door, Prop_Data, "m_bLocked", 1);
		ChangeEdictState(door, 0);

		if(g_iSpawnflags[door] == -1)
		{
			g_iSpawnflags[door] = GetEntProp(door, Prop_Send, "m_spawnflags");
		}

		SetEntProp(door, Prop_Send, "m_spawnflags", DOOR_FLAG_IGNORE_USE); // Prevent +USE

		int survivor = 0;

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			else if(L4D_IsInLastCheckpoint(i))
				continue;

			survivor = i;
		}

		float fOrigin[3];

		if(survivor != 0)
		{
			GetEntPropVector(survivor, Prop_Data, "m_vecAbsOrigin", fOrigin);
		}

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			else if(!L4D_IsInLastCheckpoint(i))
				continue;

			if(survivor == 0)
			{
				// Slay the newborn tank to prevent issues...
				ForcePlayerSuicide(client);

				// Return and not break or continue
				return;
			}

			TeleportEntity(i, fOrigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
	if(RPG_Perks_GetZombieType(entity) != ZombieType_Tank)
		return;

	else if(g_iCurrentTank[entity] < 0)
		return;

	CalculateTankColor(entity);

	if(strncmp(attributeName, "Cast Active Ability #", 21) != 0)
		return;


	char sAbilityIndex[64];
	strcopy(sAbilityIndex, sizeof(sAbilityIndex), attributeName);
	ReplaceStringEx(sAbilityIndex, sizeof(sAbilityIndex), "Cast Active Ability #", "");

	int abilityIndex = StringToInt(sAbilityIndex);

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[entity], tank);

	enActiveAbility activeAbility;
	tank.aActiveAbilities.GetArray(abilityIndex, activeAbility);

	if(activeAbility.minCooldown == 0 && activeAbility.maxCooldown == 0)
		return;

	RPG_Perks_ApplyEntityTimedAttribute(entity, attributeName, GetRandomFloat(float(activeAbility.minCooldown), float(activeAbility.maxCooldown)), COLLISION_SET, ATTRIBUTE_NEUTRAL);

	Call_StartForward(g_fwOnRPGTankCastActiveAbility);
	
	Call_PushCell(entity);
	
	Call_PushCell(abilityIndex);

	Call_Finish();
}

public void CalculateTankColor(int entity)
{
	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[entity], tank);

	L4D2GlowType glowType = L4D2Glow_Constant;
	int color[4];
	int hexcolor = tank.color;

	if(hexcolor == 1)
		color = {255, 255, 255, 255};

	else 
		GunXP_GenerateRGBColor(hexcolor, color);

	SetEntityRenderColor(entity, color[0], color[1], color[2], color[3]);

	int skin = -1;

	while((skin = FindEntityByClassname(skin, "commentary_dummy")) != -1)
	{
		if(GetEntPropEnt(skin, Prop_Data, "m_hMoveParent") == entity)
		{
			int rgb[3];
			rgb[0] = color[0];
			rgb[1] = color[1];
			rgb[2] = color[2];

			L4D2_SetEntityGlow_Color(skin, rgb);
			L4D2_SetEntityGlow_Type(skin, glowType);
		}
	}
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
	if(priority == 10 && RPG_Perks_GetZombieType(victim) == ZombieType_Tank && g_iCurrentTank[victim] >= 0)
	{
		// Prevent gaining infinite aggro from using a molotov on the tank. DMG_DROWNRECOVER means the damage is done by a skill, which also shouldn't give aggro.
		if(!(damagetype & DMG_BURN) && !(damagetype & DMG_DROWNRECOVER))
		{
			g_bGaveTankAggro[attacker] = true;
		}

		if(RPG_Perks_GetClientHealth(victim) > RPG_Perks_GetClientMaxHealth(victim) && L4D2_IsGenericCooperativeMode())
		{
			PrintToChatAll(" \x03%N\x01 had more HP than max HP. It will be converted to a normal Tank now.", victim);

			SetClientName(victim, "Tank");

			RPG_Perks_SetClientHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[victim] = TANK_TIER_UNTIERED;
		}
		char sClassname[64];
		if(attacker != 0)
			GetEdictClassname(attacker, sClassname, sizeof(sClassname));

		if(damage >= 200 && (attacker == victim || attacker == 0 || strncmp(sClassname, "trigger_hurt", 12) == 0 || strncmp(sClassname, "point_hurt", 10) == 0))
		{
			PrintToChatAll(" \x03%N\x01 took lethal damage from the world. It will be converted to a normal Tank now.", victim);

			SetClientName(victim, "Tank");

			RPG_Perks_SetClientHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[victim] = TANK_TIER_UNTIERED;

			return;
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

	if(!(damagetype & DMG_DROWNRECOVER))
	{
		if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN && damagetype & DMG_BURN)
		{
			bImmune = true;

			TryPlayImmunitySound(attacker);			
		}

		if(tank.damageImmunities & DAMAGE_IMMUNITY_EXPLOSIVES == DAMAGE_IMMUNITY_EXPLOSIVES && damagetype & DMG_BLAST)
		{
			bImmune = true;

			TryPlayImmunitySound(attacker);
		}

		if(tank.damageImmunities & DAMAGE_IMMUNITY_MELEE == DAMAGE_IMMUNITY_MELEE && (L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw))
		{
			if(tank.damageImmunities & DAMAGE_IMMUNITY_BURN == DAMAGE_IMMUNITY_BURN || !(damagetype & DMG_BURN))
			{
				bImmune = true;

				TryPlayImmunitySound(attacker);
			}
		}

		if(tank.damageImmunities & DAMAGE_IMMUNITY_BULLETS == DAMAGE_IMMUNITY_BULLETS && damagetype & DMG_BULLET)
		{
			bImmune = true;
			TryPlayImmunitySound(attacker);
		}
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
	else if(inflictor == attacker && IsPlayer(attacker))
	{
		int activeWeapon = L4D_GetPlayerCurrentWeapon(attacker);
		GetEdictClassname(activeWeapon, sClassname, sizeof(sClassname));

		if(StrEqual(sClassname, "weapon_shotgun_chrome") || StrEqual(sClassname, "weapon_shotgun_spas") || StrEqual(sClassname, "weapon_pumpshotgun") || StrEqual(sClassname, "weapon_autoshotgun"))
		{
			damage = damage * g_hShotgunDamageMultiplier.FloatValue;
		}
	}
}

public void TryPlayImmunitySound(int attacker)
{
	if(!IsPlayer(attacker))
		return;

	else if(IsFakeClient(attacker))
		return;

	else if(RPG_Perks_IsEntityTimedAttribute(attacker, "Immunity Sound Cooldown"))
		return;
	
	else if(!RPG_Perks_GetSoundMode(attacker))
		return;

	RPG_Perks_ApplyEntityTimedAttribute(attacker, "Immunity Sound Cooldown", 2.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);

	EmitImmunitySound(attacker);
}

stock void EmitImmunitySound(int client)
{
	for(int i=0;i < IMMUNITY_SOUND_MULTIPLIER;i++)
	{
		EmitSoundToClient(client, IMMUNITY_SOUND, _, SOUND_CHANNEL, 150, _, 1.0, 100);
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

		char PlayerFormat[512];

		int count = 0;

		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(IsFakeClient(i))
				continue;

			else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
				continue;

			float fDamageRatio, fMinDamageRatio;
			CalculateIsEnoughDamage(i, bestTank, fDamageRatio, fMinDamageRatio);

			if(count % 2 == 1)
			{
				Format(PlayerFormat, sizeof(PlayerFormat), "%s%N [%s%.1f{PERCENT}{NORMAL}]", PlayerFormat, i, fDamageRatio >= fMinDamageRatio ? "{OLIVE}" : "", RPG_Tanks_GetDamagePercent(i, bestTank));

				UC_PrintToChat(client, PlayerFormat);

				PlayerFormat[0] = EOS;
			}
			else
			{
				Format(PlayerFormat, sizeof(PlayerFormat), "%s%N [%s%.1f{PERCENT}{NORMAL}] | ", PlayerFormat, i, fDamageRatio >= fMinDamageRatio ? "{OLIVE}" : "", RPG_Tanks_GetDamagePercent(i, bestTank));
			}

			count++;
		}

		if(count % 2 == 1)
		{
			PlayerFormat[strlen(PlayerFormat) - 2] = EOS;
			
			UC_PrintToChat(client, PlayerFormat);
		}
	}
	return Plugin_Handled;
}

public Action Command_FindTank(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "Usage: sm_findtank <value>");
		return Plugin_Handled;
	}

	char lookup_value[64];

	GetCmdArgString(lookup_value, sizeof(lookup_value));

	int error, serial;
	char classification[16];
	ArrayList include;
	include = new ArrayList(64);

	include.PushString("Tank");
	include.PushString("Activated Ability");
	include.PushString("Passive Ability");

	if(!GunXP_RPG_IsValidNavigationRef(lookup_value, error, _, serial, classification, _, _, _, include))
	{
		if(error == NAVREF_ERROR_DISAMBIGUOUS)
		{
			ReplyToCommand(client, "Ambiguous lookup value. Please be more specific.");
			return Plugin_Handled;
		}
		else if(error == NAVREF_ERROR_NOTFOUND)
		{
			ReplyToCommand(client, "Lookup value cannot be found.");
			return Plugin_Handled;
		}
	}

	GunXP_RPG_TriggerNavigationRef(client, lookup_value, _, include);

	delete include;

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

	for(int i=1;i <= g_iMaxTier;i++)
	{
		if(tiersThatExist[i])
		{
			Format(TempFormat, sizeof(TempFormat), "Tier %i Tanks", i);
			char sInfo[11];
			IntToString(i, sInfo, sizeof(sInfo));

			AddMenuItem(hMenu, sInfo, TempFormat, ITEMDRAW_DEFAULT);
		}
	}

	char sDifficultyMultiplier[128];
	char sDifficulty[64];

	ConVar cvar = FindConVar("gun_xp_difficulty_multiplier");
	ConVar difficultyCvar = FindConVar("z_difficulty");

	difficultyCvar.GetString(sDifficulty, sizeof(sDifficulty));

	if(StrEqual(sDifficulty, "easy", false))
		sDifficulty = "Easy";

	else if(StrEqual(sDifficulty, "normal", false))
		sDifficulty = "Normal";

	else if(StrEqual(sDifficulty, "hard", false))
		sDifficulty = "Advanced";

	else if(StrEqual(sDifficulty, "impossible", false))
		sDifficulty = "Expert";

	if(cvar != null)
	{
		FormatEx(sDifficultyMultiplier, sizeof(sDifficultyMultiplier), "\nXP Multiplier for %s Difficulty : x%.1f", sDifficulty, cvar.FloatValue);
	}

	FormatEx(TempFormat, sizeof(TempFormat), "Choose a Tier to learn about its Tanks\nEntries are a Jackpot based system to determine a winner\nEntries for Untiered Tank : %i%s", g_hEntriesUntiered.IntValue, sDifficultyMultiplier);
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

	FormatEx(TempFormat, sizeof(TempFormat), "%s Tank | Choose an Ability for info. If it has a radius, you'll see it if no Tank is alive\nMax HP : %i | Entries : %i\nAverage XP : %i | Immune to : %s\n%s", tank.name, tank.maxHP, tank.entries, (tank.XPRewardMin + tank.XPRewardMax) / 2, immunityFormat, tank.description);
	SetMenuTitle(hMenu, TempFormat);

	SetMenuPagination(hMenu, 6);

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
			FormatEx(TempFormat, sizeof(TempFormat), " %s\nDelay: Controlled by Abilities\n%s", sName, description);
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

	bool bTanks = false;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
			continue;

		else if(float(RPG_Perks_GetClientHealth(i)) / float(RPG_Perks_GetClientMaxHealth(i)) >= 0.99)
			continue;

		bTanks = true;
	}

	if(!bTanks)
	{
		int spriteRing = PrecacheModel("materials/sprites/laserbeam.vmt");
		int haloIndex = PrecacheModel("sprites/glow01.spr");

		int pos = -1;
		while((pos = StrContains(description[pos+1], " unit", false)) != -1)
		{
			int start = pos;
			char TempStr[12];
			int size = 0;

			while(start > 0 && (IsCharNumeric(description[start-1]) || description[start-1] == ',')) {
				TempStr[size++] = description[start-1];
				start--;
			}

			ReplaceString(TempStr, sizeof(TempStr), ",", "");

			int strLen = strlen(TempStr);

			char TempStrReverse[12];

			for(int i = strLen - 1, num = 0;i >= 0;i--,num++)
			{
				TempStrReverse[num] = TempStr[i];
			}

			int distance = StringToInt(TempStrReverse);

			float fOrigin[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

			fOrigin[2] += 16.0;

			int RGBA[4] = {255, 255, 255, 255};
			
			for(int i=0;i < 3;i++)
			{
				RGBA[i] = GetRandomInt(32, 255);
			}

			// Multiple distance by 2 because you need circumference, not radius.
			// In simpler terms, the size of the ring goes both forward and backwards, not just forward.
			TE_SetupBeamRingPoint(fOrigin, 
				float(distance) * 2.0,
				(float(distance) * 2.0) + 1.0,
				spriteRing,
				haloIndex,
				0, // Starting frame
				0, // Frame rate 
				5.0, // Life 
				5.0, // Width
				1.0, // Spread
				RGBA, // RGBA Color
				0, // Speed
				0 // Flags
				); 

			TE_SendToClient(client);

			TE_SetupBeamRingPoint(fOrigin, 
				1.0,
				8.0,
				spriteRing,
				haloIndex,
-    			0, // Starting frame
				0, // Frame rate 
				3.0, // Life 
				8.0, // Width
				1.0, // Spread
				RGBA, // RGBA Color
				0, // Speed
				0 // Flags
				); 

			TE_SendToClient(client);
		}
	}
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

		else if(!L4D2_IsGenericCooperativeMode())
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

public Action Event_FinaleStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int entity = FindEntityByClassname(-1, "trigger_finale");

	if(entity != -1)
	{
		int type = GetEntProp(entity, Prop_Data, "m_type");
		
		if(type == 2 && L4D_IsCoopMode() && g_hInstantFinale.BoolValue)
		{
			g_bButtonLive = false;
			PrintToChatAll("Rescue vehicle is here. Either leave or defeat the Tanks.");
			L4D2_SendInRescueVehicle();
			L4D2_ChangeFinaleStage(FINALE_GAUNTLET_ESCAPE, "");
			L4D2_SetEntityGlow(entity, L4D2Glow_None, 0, 0, {255, 255, 255}, false);
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

		else if(!L4D2_IsGenericCooperativeMode())
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

	g_bButtonLive = false;
	g_iKillCombo = 0;
	g_iOverrideNextTier = TANK_TIER_UNKNOWN;

	return Plugin_Continue;
}

public Action Event_PlayerIncap(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;

	else if(RPG_Perks_GetZombieType(victim) != ZombieType_Tank)
		return Plugin_Continue;

	int tankCount = 0;

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

		tankCount++;
	}

	if(tankCount <= 0)
	{
		int door = L4D_GetCheckpointLast();

		if(door != -1)
		{
			AcceptEntityInput(door, "InputUnlock");
			SetEntProp(door, Prop_Data, "m_bLocked", 0);
			ChangeEdictState(door, 0);

			if(g_iSpawnflags[door] != -1)
			{
				SetEntProp(door, Prop_Send, "m_spawnflags", g_iSpawnflags[door]);
			}

			g_iSpawnflags[door] = -1;
		}
	}
	
	if(g_iCurrentTank[victim] < 0)
	{
		g_iCurrentTank[victim] = TANK_TIER_UNKNOWN;

		if(RPG_Perks_GetClientHealth(victim) < 10000)
		{
			for(int i=1;i <= MaxClients;i++)
			{
				if(!IsClientInGame(i))
					continue;

				else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
					continue;

				Call_StartForward(g_fwOnUntieredTankKilled);
				
				Call_PushCell(victim);
				
				Call_PushCell(i);

				Call_Finish();
			}
		}
		return Plugin_Continue;

	}

	if(RPG_Perks_GetClientHealth(victim) >= 10000)
	{
		PrintToChatAll("%N died in mysterious ways and will be converted to a normal Tank now.", victim);

		SetClientName(victim, "Tank");

		// Don't heal incapped tank please...
		// RPG_Perks_SetClientHealth(victim, GetConVarInt(FindConVar("rpg_z_tank_health")));

		g_iCurrentTank[victim] = TANK_TIER_UNKNOWN;

		return Plugin_Continue;
	}

	if(L4D_IsFinaleEscapeInProgress() && L4D2_IsGenericCooperativeMode())
	{
		for(int i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;

			else if(!IsPlayerAlive(i))
				continue;

			else if(RPG_Perks_GetZombieType(i) != ZombieType_Tank)
				continue;

			else if(g_iCurrentTank[i] < 0)
				continue;

			else if(!L4D2_IsGenericCooperativeMode())
				continue;
				
			PrintToChatAll(" The Finale was won. %N will be converted to a normal Tank now.", i);

			SetClientName(i, "Tank");

			RPG_Perks_SetClientHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));
			//RPG_Perks_SetClientMaxHealth(i, GetConVarInt(FindConVar("rpg_z_tank_health")));

			g_iCurrentTank[i] = TANK_TIER_UNTIERED;
		}

		return Plugin_Continue;
	}

	enTank tank;
	g_aTanks.GetArray(g_iCurrentTank[victim], tank);

	int XPReward = GetRandomInt(tank.XPRewardMin, tank.XPRewardMax);

	int ReducedXPReward = RoundToFloor(float(XPReward) * g_hXPRatioNotEnough.FloatValue);

	if(ReducedXPReward <= 0)
		ReducedXPReward = -1;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		float fDamageRatio, fMinDamageRatio;
		CalculateIsEnoughDamage(i, victim, fDamageRatio, fMinDamageRatio);

		if(LibraryExists("GunXP-RPG"))
		{
			UC_PrintToChat(i, "You dealt\x03 %.1f{PERCENT}\x01 of %N's max HP as damage", fDamageRatio * 100.0, victim);
		}

		if(LibraryExists("GunXP-RPG") && fDamageRatio < fMinDamageRatio)
		{
			if(ReducedXPReward == -1)
				UC_PrintToChat(i, "This is not enough to gain XP rewards. (Min. %.0f{PERCENT})", fMinDamageRatio * 100.0);

			else
			{
				UC_PrintToChat(i, "This is not enough to gain full XP rewards. (Min. %.0f{PERCENT})", fMinDamageRatio * 100.0);
				UC_PrintToChat(i, "You got\x03 %i\x01 XP (Original XP Reward:\x04 %i\x01)", ReducedXPReward, XPReward);
			}
			
			Call_StartForward(g_fwOnRPGTankKilled);
			
			Call_PushCell(victim);
			
			Call_PushCell(i);

			Call_PushCell(ReducedXPReward);

			Call_Finish();

			continue;
		}


		if(LibraryExists("GunXP-RPG"))
		{
			UC_PrintToChat(i, "This is enough to get XP rewards. You got\x03 %i\x05 XP", XPReward);
		}

		Call_StartForward(g_fwOnRPGTankKilled);

		
		Call_PushCell(victim);
		
		Call_PushCell(i);
		
		Call_PushCell(XPReward);

		Call_Finish();
	}

	g_iCurrentTank[victim] = TANK_TIER_UNKNOWN;

	g_iKillCombo++;
	
	RPG_CheckFinaleKillCombo();

	return Plugin_Continue;
}

public Action Event_TankKilledOrDisconnect(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int tankCount = 0;

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

		tankCount++;
	}

	if(tankCount <= 0)
	{
		int door = L4D_GetCheckpointLast();

		if(door != -1)
		{
			AcceptEntityInput(door, "InputUnlock");
			SetEntProp(door, Prop_Data, "m_bLocked", 0);
			ChangeEdictState(door, 0);

			if(g_iSpawnflags[door] != -1)
			{
				SetEntProp(door, Prop_Send, "m_spawnflags", g_iSpawnflags[door]);
			}

			g_iSpawnflags[door] = -1;
		}
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

	if(strncmp(name, "[PASSIVE] ", 10) == 0 || passive)
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

stock void CalculateIsEnoughDamage(int survivor, int tank, float &fDamageRatio, float &fMinDamageRatio )
{
	fDamageRatio = RPG_Tanks_GetDamagePercent(survivor, tank) / 100.0;

	fMinDamageRatio = 0.05;

	if(LibraryExists("GunXP-RPG") && GunXP_RPG_GetClientRealLevel(survivor) <= 23)
		fMinDamageRatio = 0.01;
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}

stock void RPG_CheckFinaleKillCombo()
{
	if(g_iKillCombo < g_hComboNeeded.IntValue)
		return;

	if(L4D2_GetCurrentFinaleStage() != FINALE_GAUNTLET_ESCAPE)
		return;

	int finale = FindEntityByClassname(-1, "trigger_finale");

	if(finale == -1)
		return;

	char sModelname[PLATFORM_MAX_PATH];
	GetEntPropString(finale, Prop_Data, "m_ModelName", sModelname, sizeof(sModelname));

	if(StrContains(sModelname, "radio", false) == -1)
		return;

	g_bButtonLive = true;
	L4D2_SetEntityGlow(finale, L4D2Glow_Constant, 0, 0, {255, 0, 0}, true);

	
	PrintToChatAll("\x04[Gun-XP] \x01Virgil spotted a Powerful Tank. Contact the Radio to lure it.");
}


// Shamelessly stolen from Shanapu MyJB.
float GetAimDistanceFromTarget(int client, int target)
{
	float vAngles[3];
	float vOrigin[3];
	float g_fPos[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceFilterHitTarget, target);

	TR_GetEndPosition(g_fPos);

	return GetVectorDistance(vOrigin, g_fPos, false);
}

public bool TraceFilterHitTarget(int entity, int contentsMask, int target)
{
	if (entity == target)
		return true;

	return false;
}

int GetAnyClient()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && L4D_GetClientTeam(i) == L4DTeam_Survivor && IsPlayerAlive(i) )
			return i;
	}
	return 0;
}