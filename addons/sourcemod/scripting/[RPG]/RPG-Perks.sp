#undef REQUIRE_PLUGIN
#include <GunXP-RPG>
#include <ps_api>
#define REQUIRE_PLUGIN
#include <autoexecconfig>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =
{
	name        = "RPG Perks",
	author      = "Eyal282",
	description = "Perks for RPG that normally don't work well if multiple plugins want to grant them.",
	version     = PLUGIN_VERSION,
	url         = ""
};

// Those are the default speeds
#define DEFAULT_RUN_SPEED		220.0
#define DEFAULT_WATER_SPEED 	115.0
#define DEFAULT_LIMP_SPEED		150.0
#define DEFAULT_WALK_SPEED		85.0
#define DEFAULT_CRITICAL_SPEED	85.0
#define DEFAULT_CROUCH_SPEED	75.0
#define DEFAULT_SCOPE_SPEED	85.0

// Max and minimum speeds are applied for legacy kernel, because it works terrible on extreme values
#define MAX_SPEED				650.0
#define MIN_SPEED				65.0	

// Player Absolute Speeds
float g_fAbsRunSpeed[MAXPLAYERS+1];			// Normal player speed (default = 220.0)
float g_fAbsWalkSpeed[MAXPLAYERS+1];		// Player speed while walking (default = 85.0)
float g_fAbsCrouchSpeed[MAXPLAYERS+1];		// Player speed while crouching (default = 75.0)
float g_fAbsLimpSpeed[MAXPLAYERS+1];		// Player speed while limping (default = 150.0)
float g_fAbsCriticalSpeed[MAXPLAYERS+1];		// Player speed when 1 HP after 1 incapacitation (default = 85.0)
float g_fAbsWaterSpeed[MAXPLAYERS+1];		// Player speed on water (default = 115.0)
float g_fAbsAdrenalineSpeed[MAXPLAYERS+1];		// Player speed when running under adrenaline effect
float g_fAbsScopeSpeed[MAXPLAYERS+1];		// Player speed while looking through a sniper scope
float g_fAbsCustomSpeed[MAXPLAYERS+1];		// Player speed while under custom condition.

int g_iAbsLimpHealth[MAXPLAYERS+1];
int g_iOverrideSpeedState[MAXPLAYERS+1] = { SPEEDSTATE_NULL, ... };

float g_fRoundStartTime;
float g_fSpawnPoint[3];

ConVar g_hRPGIncapPistolPriority;

ConVar g_hRPGTankHealth;

ConVar g_hKitDuration;
ConVar g_hRPGKitDuration;

ConVar g_hReviveDuration;
ConVar g_hRPGReviveDuration;
ConVar g_hRPGLedgeReviveDuration;

ConVar g_hIncapHealth;
ConVar g_hRPGIncapHealth;

ConVar g_hLedgeHangHealth;
ConVar g_hRPGLedgeHangHealth;

ConVar g_hAdrenalineDuration;
ConVar g_hRPGAdrenalineDuration;
ConVar g_hRPGAdrenalineRunSpeed;

ConVar g_hAdrenalineHealPercent;
ConVar g_hRPGAdrenalineHealPercent;

ConVar g_hPainPillsHealPercent;
ConVar g_hRPGPainPillsHealPercent;

ConVar g_hCriticalSpeed;
ConVar g_hLimpHealth;
ConVar g_hRPGLimpHealth;

ConVar g_hStartIncapWeapon;

GlobalForward g_fwOnGetRPGMaxHP;
GlobalForward g_fwOnRPGPlayerSpawned;
GlobalForward g_fwOnRPGZombiePlayerSpawned;

GlobalForward g_fwOnGetRPGAdrenalineDuration;
GlobalForward g_fwOnGetRPGMedsHealPercent;
GlobalForward g_fwOnGetRPGKitHealPercent;
GlobalForward g_fwOnGetRPGReviveHealthPercent;

GlobalForward g_fwOnGetRPGKitDuration;
GlobalForward g_fwOnGetRPGReviveDuration;

GlobalForward g_fwOnGetRPGIncapWeapon;
GlobalForward g_fwOnGetRPGIncapHealth;

GlobalForward g_fwOnGetRPGSpeedModifiers;
GlobalForward g_fwOnCalculateDamage;

int g_iHealth[MAXPLAYERS+1];
int g_iLastTemporaryHealth[MAXPLAYERS+1];
char g_sLastSecondaryClassname[MAXPLAYERS+1][64];
int g_iLastSecondaryClip[MAXPLAYERS+1];
bool g_bLastSecondaryDual[MAXPLAYERS+1];

public void OnPluginEnd()
{
	g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
	g_hReviveDuration.FloatValue = g_hRPGReviveDuration.FloatValue;
	g_hLimpHealth.IntValue = g_hRPGLimpHealth.IntValue;
	g_hAdrenalineHealPercent.IntValue = g_hRPGAdrenalineHealPercent.IntValue;
	g_hPainPillsHealPercent.IntValue = g_hRPGPainPillsHealPercent.IntValue;
}



public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{	
	CreateNative("RPG_Perks_SetClientHealth", Native_SetClientHealth);
	CreateNative("RPG_Perks_GetClientHealth", Native_GetClientHealth);
	return APLRes_Success;
}


public int Native_GetClientHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);

	if(g_iHealth[client] <= 65535)
	{
		// An incapped tank is dead.
		if(L4D_IsPlayerIncapacitated(client) && L4D_GetClientTeam(client) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
		{
			return 0;
		}

		return GetEntityHealth(client);
	}

	return g_iHealth[client];
}

public int Native_SetClientHealth(Handle caller, int numParams)
{
	int client = GetNativeCell(1);
	
	int hp = GetNativeCell(2);

	if(hp <= 65535)
		hp = -1;
	
	g_iHealth[client] = hp;

	if(g_iHealth[client] <= 65535)
	{
		SetEntityHealth(client, g_iHealth[client]);
		g_iHealth[client] = -1;
	}
	else
	{
		SetEntityHealth(client, 65535);
	}

	return 0;
}

public void OnMapStart()
{
	g_fRoundStartTime = 0.0;

	TriggerTimer(CreateTimer(1.0, Timer_CheckSpeedModifiers, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action Timer_CheckSpeedModifiers(Handle hTimer)
{
	g_hLimpHealth.IntValue = 0;
	g_hAdrenalineDuration.FloatValue = 0.0;
	g_hAdrenalineHealPercent.IntValue = 0;
	g_hPainPillsHealPercent.IntValue = 0;
	// Prediction error fix.
	g_hCriticalSpeed.FloatValue = DEFAULT_RUN_SPEED;

	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;

		else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		g_iOverrideSpeedState[i] = SPEEDSTATE_NULL;
		g_iAbsLimpHealth[i] = g_hRPGLimpHealth.IntValue;
		g_fAbsRunSpeed[i] = DEFAULT_RUN_SPEED;
		g_fAbsWalkSpeed[i] = DEFAULT_WALK_SPEED;
		g_fAbsCrouchSpeed[i] = DEFAULT_CROUCH_SPEED;
		g_fAbsLimpSpeed[i] = DEFAULT_LIMP_SPEED;
		g_fAbsCriticalSpeed[i] = DEFAULT_CRITICAL_SPEED;
		g_fAbsWaterSpeed[i] = DEFAULT_WATER_SPEED;
		g_fAbsAdrenalineSpeed[i] = g_hRPGAdrenalineRunSpeed.FloatValue;
		g_fAbsScopeSpeed[i] = DEFAULT_SCOPE_SPEED;
		g_fAbsCustomSpeed[i] = 0.0;


		for(int a=-10;a <= 10;a++)
		{
			Call_StartForward(g_fwOnGetRPGSpeedModifiers);

			Call_PushCell(a);
			Call_PushCell(i);
			Call_PushCellRef(g_iOverrideSpeedState[i]);
			Call_PushCellRef(g_iAbsLimpHealth[i]);
			Call_PushFloatRef(g_fAbsRunSpeed[i]);
			Call_PushFloatRef(g_fAbsWalkSpeed[i]);
			Call_PushFloatRef(g_fAbsCrouchSpeed[i]);
			Call_PushFloatRef(g_fAbsLimpSpeed[i]);
			Call_PushFloatRef(g_fAbsCriticalSpeed[i]);
			Call_PushFloatRef(g_fAbsWaterSpeed[i]);
			Call_PushFloatRef(g_fAbsAdrenalineSpeed[i]);
			Call_PushFloatRef(g_fAbsScopeSpeed[i]);
			Call_PushFloatRef(g_fAbsCustomSpeed[i]);

			Call_Finish();
		}
	}

	return Plugin_Continue;
}

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStartPre, EventHookMode_Pre);
	HookEvent("heal_begin", Event_HealBegin);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("adrenaline_used", Event_AdrenalineUsed);
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_PlayerReplacesABot, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_BotReplacesAPlayer, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrabPre, EventHookMode_Pre);
	HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);

	g_fwOnGetRPGMaxHP = CreateGlobalForward("RPG_Perks_OnGetMaxHP", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnRPGPlayerSpawned = CreateGlobalForward("RPG_Perks_OnPlayerSpawned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_fwOnRPGZombiePlayerSpawned = CreateGlobalForward("RPG_Perks_OnZombiePlayerSpawned", ET_Ignore, Param_Cell);

	g_fwOnGetRPGAdrenalineDuration = CreateGlobalForward("RPG_Perks_OnGetAdrenalineDuration", ET_Ignore, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGMedsHealPercent = CreateGlobalForward("RPG_Perks_OnGetMedsHealPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGKitHealPercent = CreateGlobalForward("RPG_Perks_OnGetKitHealPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGReviveHealthPercent = CreateGlobalForward("RPG_Perks_OnGetReviveHealthPercent", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);

	g_fwOnGetRPGKitDuration = CreateGlobalForward("RPG_Perks_OnGetKitDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGReviveDuration = CreateGlobalForward("RPG_Perks_OnGetReviveDuration", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);

	g_fwOnGetRPGIncapHealth = CreateGlobalForward("RPG_Perks_OnGetIncapHealth", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGIncapWeapon = CreateGlobalForward("RPG_Perks_OnGetIncapWeapon", ET_Ignore, Param_Cell, Param_CellByRef);

	g_fwOnGetRPGSpeedModifiers = CreateGlobalForward("RPG_Perks_OnGetRPGSpeedModifiers", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef, Param_FloatByRef);
	g_fwOnCalculateDamage = CreateGlobalForward("RPG_Perks_OnCalculateDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);

	AutoExecConfig_SetFile("RPG-Perks");

	g_hRPGIncapPistolPriority = AutoExecConfig_CreateConVar("rpg_incap_pistol_priority", "0", "Do not blindly edit this cvar.\nSetting to an absurd number will remove incap pistol functionality\nThis is a priority from -10 to 10 indicating an order of priority to grant an incapped player their pistol when they spawn.");

	g_hRPGTankHealth = AutoExecConfig_CreateConVar("rpg_z_tank_health", "4000", "Default health of the Tank");

	g_hKitDuration = FindConVar("first_aid_kit_use_duration");
	g_hRPGKitDuration = AutoExecConfig_CreateConVar("rpg_first_aid_kit_use_duration", "5", "Default time for use with first aid kit.");

	g_hReviveDuration = FindConVar("survivor_revive_duration");
	g_hRPGReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_revive_duration", "5", "Default time for reviving.");
	g_hRPGLedgeReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_ledge_revive_duration", "5", "Default time for reviving from a ledge.");


	g_hIncapHealth = FindConVar("survivor_incap_health");
	g_hRPGIncapHealth = AutoExecConfig_CreateConVar("rpg_survivor_incap_health", "300", "Default HP for being incapacitated");

	g_hLedgeHangHealth = FindConVar("survivor_ledge_grab_health");
	g_hRPGLedgeHangHealth = AutoExecConfig_CreateConVar("rpg_survivor_ledge_grab_health", "300", "Default HP for ledge hanging");

	g_hCriticalSpeed = FindConVar("survivor_limp_walk_speed");
	g_hLimpHealth = FindConVar("survivor_limp_health");
	g_hRPGLimpHealth = AutoExecConfig_CreateConVar("rpg_survivor_limp_health", "40", "Default HP under which you start limping");

	g_hRPGAdrenalineHealPercent = AutoExecConfig_CreateConVar("rpg_adrenaline_health_buffer", "25", "Default percent of max HP adrenaline heals for");
	g_hAdrenalineHealPercent = FindConVar("adrenaline_health_buffer");

	g_hRPGPainPillsHealPercent = AutoExecConfig_CreateConVar("rpg_pain_pills_health_value", "50", "Default percent of max HP pain pills heal for");
	g_hPainPillsHealPercent = FindConVar("pain_pills_health_value");

	g_hRPGAdrenalineDuration = AutoExecConfig_CreateConVar("rpg_adrenaline_duration", "15.0", "Default time adrenaline lasts for.");
	g_hAdrenalineDuration = FindConVar("adrenaline_duration");

	g_hRPGAdrenalineRunSpeed = AutoExecConfig_CreateConVar("rpg_adrenaline_run_speed", "260", "Default HP for ledge hanging");

	g_hStartIncapWeapon = AutoExecConfig_CreateConVar("rpg_start_incap_weapon", "0", "0 - No weapon. 1 - Pistol. 2 - Double Pistol. 3 - Magnum");

	AutoExecConfig_ExecuteFile();

	AutoExecConfig_CleanFile();

	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
	}

	int count = GetEntityCount();
	for (int i = MaxClients+1;i < count;i++)
	{
		if(!IsValidEdict(i))
			continue;

		char sClassname[64];
		GetEdictClassname(i, sClassname, sizeof(sClassname));

		if(StrEqual(sClassname, "infected") || StrEqual(sClassname, "witch"))
		{
			SDKHook(i, SDKHook_TraceAttack, Event_TraceAttack);
			SDKHook(i, SDKHook_OnTakeDamage, Event_TakeDamage);

		}
	}

	RegPluginLibrary("RPG_Perks");
}

public void GunXP_OnReloadRPGPlugins()
{
	#if defined _GunXP_RPG_included
		GunXP_ReloadPlugin();
	#endif
   
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
	TriggerTimer(CreateTimer(0.0, Timer_CheckSpeedModifiers, _, TIMER_FLAG_NO_MAPCHANGE));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "info_survivor_position"))
	{
		SDKHook(entity, SDKHook_SpawnPost, Event_OnSpawnpointSpawnPost);
	}
}

public void Event_OnSpawnpointSpawnPost(int entity)
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", g_fSpawnPoint);
}
// Must add natives for after a player spawns for incap hidden pistol.
public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
	if(priority != g_hRPGIncapPistolPriority.IntValue)
		return;

	else if(!L4D_IsPlayerIncapacitated(client))
		return;

	else if(L4D_IsPlayerHangingFromLedge(client))
		return;

	int index = g_hStartIncapWeapon.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapWeapon);

	Call_PushCell(client);
	Call_PushCellRef(index);

	Call_Finish();
	
	switch(index)
	{
		case 0:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);
		}
		case 1:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");

			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);

			EquipPlayerWeapon(client, weapon);
		}
		case 2:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");
			
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(client, weapon);

			SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1") * 2);
		}
		default:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			GivePlayerItem(client, "weapon_pistol_magnum");
		}
	}
}

public Action Event_ReviveBeginPre(Event event, const char[] name, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if(reviver == 0)
		return Plugin_Continue;

	float fDuration = g_hRPGReviveDuration.FloatValue;

	if(L4D_IsPlayerHangingFromLedge(subject))
	{
		fDuration = g_hRPGLedgeReviveDuration.FloatValue;
	}

	Call_StartForward(g_fwOnGetRPGReviveDuration);

	Call_PushCell(reviver);
	Call_PushCell(subject);
	Call_PushCell(L4D_IsPlayerHangingFromLedge(subject));
	Call_PushFloatRef(fDuration);

	Call_Finish();

	g_hReviveDuration.FloatValue = fDuration;

	return Plugin_Continue;
}

public Action Event_RoundStart(Handle hEvent, char[] Name, bool dontBroadcast)
{
	g_fRoundStartTime = GetGameTime();

	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	int UserId = GetEventInt(hEvent, "userid");
	
	RequestFrame(Event_PlayerSpawnFrame, UserId);

	return Plugin_Continue;
}

public Action Event_PlayerHurt(Handle hEvent, char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(client == 0)
		return Plugin_Continue;

	else if(!IsPlayerAlive(client))
		return Plugin_Continue;

	else if(GetEntityHealth(client) <= 0)
		return Plugin_Continue;

	else if(g_iHealth[client] <= 65535)
		return Plugin_Continue;

	else if(L4D_GetClientTeam(client) != L4DTeam_Infected)
		return Plugin_Continue;

	int hpLost = 65535 - GetEntityHealth(client);

	g_iHealth[client] -= hpLost;

	if(g_iHealth[client] <= 65535)
	{
		SetEntityHealth(client, g_iHealth[client]);
		g_iHealth[client] = -1;
	}
	else
	{
		SetEntityHealth(client, 65535);
	}

	return Plugin_Continue;
}
public void Event_PlayerSpawnFrame(int UserId)
{
	int client = GetClientOfUserId(UserId);

	g_iHealth[client] = -1;

	if(client == 0)
		return;
	
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
	{
		if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Infected)
			return;

		
		if(L4D2_GetPlayerZombieClass(client) == L4D2ZombieClass_Tank)
		{
			int hp = g_hRPGTankHealth.IntValue;

			if(hp > 65535)
			{
				g_iHealth[client] = hp;

				SetEntityMaxHealth(client, 65535);
				SetEntityHealth(client, 65535);
			}
			else
			{
				SetEntityMaxHealth(client, hp);
				SetEntityHealth(client, hp);
			}
		}


		Call_StartForward(g_fwOnRPGZombiePlayerSpawned);

		Call_PushCell(client);

		Call_Finish();

		return;
	}

	else if(!IsPlayerAlive(client))
	{
		if(GetGameTime() < g_fRoundStartTime + 25.0)
			L4D_RespawnPlayer(client);

		else
			return;
	}

	int maxHP = 100;
	
	for(int a=-10;a <= 10;a++)
	{
		Call_StartForward(g_fwOnGetRPGMaxHP);

		Call_PushCell(a);
		Call_PushCell(client);
		
		Call_PushCellRef(maxHP);

		Call_Finish();	
	}

	if(maxHP <= 0)
		maxHP = 100;

	SetEntityMaxHealth(client, maxHP);

	for(int a=-10;a <= 10;a++)
	{
		Call_StartForward(g_fwOnRPGPlayerSpawned);

		Call_PushCell(a);
		Call_PushCell(client);

		if(GetGameTime() < g_fRoundStartTime + 25.0 || !L4D_HasAnySurvivorLeftSafeArea())
			Call_PushCell(true);

		else
			Call_PushCell(false);

		Call_Finish();	
	}

	if(GetGameTime() < g_fRoundStartTime + 25.0 || !L4D_HasAnySurvivorLeftSafeArea())
	{

		if(IsPlayerStuck(client))
		{
			if(UC_IsNullVector(g_fSpawnPoint))
			{
				int spawn = FindEntityByClassname(-1, "info_survivor_position");

				if(spawn != -1)
				{	
					GetEntPropVector(spawn, Prop_Data, "m_vecAbsOrigin", g_fSpawnPoint);
				}
			}

			if(!UC_IsNullVector(g_fSpawnPoint))
			{
				TeleportEntity(client, g_fSpawnPoint, NULL_VECTOR, NULL_VECTOR);
			}
		}

		PSAPI_FullHeal(client);

		L4D_SetPlayerTempHealth(client, 0);
	}
}

public Action Event_PlayerIncapStartPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	// Tanks get incapacitated on death.
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	int health = g_hRPGIncapHealth.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapHealth);

	Call_PushCell(client);
	Call_PushCell(false);
	Call_PushCellRef(health);

	Call_Finish();

	g_hIncapHealth.IntValue = health;

	int weapon = GetPlayerWeaponSlot(client, 1);
	
	if(weapon != -1)
	{
		GetEdictClassname(weapon, g_sLastSecondaryClassname[client], sizeof(g_sLastSecondaryClassname[]));

		g_iLastSecondaryClip[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");
		
		if(HasEntProp(weapon, Prop_Send, "m_isDualWielding"))
			g_bLastSecondaryDual[client] = view_as<bool>(GetEntProp(weapon, Prop_Send, "m_isDualWielding"));

		else
			g_bLastSecondaryDual[client] = false;
	}
	else
	{
		g_sLastSecondaryClassname[client][0] = EOS;	
		g_iLastSecondaryClip[client] = 0;
		g_bLastSecondaryDual[client] = false;
	}

	return Plugin_Continue;
}


public Action Event_BotReplacesAPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	int newPlayer = GetClientOfUserId(GetEventInt(event, "bot"));

	g_iLastTemporaryHealth[newPlayer] = 0;

	return Plugin_Continue;
}
public Action Event_PlayerReplacesABot(Handle event, const char[] name, bool dontBroadcast)
{
	int newPlayer = GetClientOfUserId(GetEventInt(event, "player"));

	g_sLastSecondaryClassname[newPlayer][0] = EOS;
	g_iLastSecondaryClip[newPlayer] = 0;
	g_bLastSecondaryDual[newPlayer] = false;

	g_iLastTemporaryHealth[newPlayer] = 0;

	return Plugin_Continue;
}

public Action Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	int healed = GetClientOfUserId(GetEventInt(event, "subject"));

	g_iLastTemporaryHealth[healed] = L4D_GetPlayerTempHealth(healed);

	return Plugin_Continue;
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int healed = GetClientOfUserId(GetEventInt(event, "subject"));

	if(client == 0)
		return Plugin_Continue;
	
	int restored = event.GetInt("health_restored");

	int percentToHeal = 0;

	Call_StartForward(g_fwOnGetRPGKitHealPercent);

	Call_PushCell(client);
	Call_PushCell(healed);

	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal <= 0)
		return Plugin_Continue;
	
	SetEntityHealth(healed, GetEntityHealth(healed) - restored);

	GunXP_GiveClientHealth(healed, RoundToFloor(GetEntityMaxHealth(healed) * (float(percentToHeal) / 100)), g_iLastTemporaryHealth[healed]);

	return Plugin_Continue;
}

public Action Event_AdrenalineUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int percentToHeal = g_hRPGAdrenalineHealPercent.IntValue;

	Call_StartForward(g_fwOnGetRPGMedsHealPercent);

	Call_PushCell(client);
	Call_PushCell(true);
	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal > 0)
	{
		GunXP_GiveClientHealth(client, 0, RoundToFloor(GetEntityMaxHealth(client) * (float(percentToHeal) / 100)));
	}

	float fDuration = g_hRPGAdrenalineDuration.FloatValue;

	Call_StartForward(g_fwOnGetRPGAdrenalineDuration);

	Call_PushCell(client);
	Call_PushFloatRef(fDuration);

	Call_Finish();

	Terror_SetAdrenalineTime(client, fDuration);

	return Plugin_Continue;
}


public Action Event_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int percentToHeal = g_hRPGPainPillsHealPercent.IntValue;

	Call_StartForward(g_fwOnGetRPGMedsHealPercent);

	Call_PushCell(client);
	Call_PushCell(false);
	Call_PushCellRef(percentToHeal);

	Call_Finish();

	if(percentToHeal > 0)
	{
		GunXP_GiveClientHealth(client, 0, RoundToFloor(GetEntityMaxHealth(client) * (float(percentToHeal) / 100)));
	}

	return Plugin_Continue;
}

public Action Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int revived = GetClientOfUserId(event.GetInt("subject"));

	if(revived == 0)
		return Plugin_Continue;

	else if(GetEventBool(event, "ledge_hang"))
		return Plugin_Continue;

	int temporaryHealthPercent = 0;
	int permanentHealthPercent = 0;

	Call_StartForward(g_fwOnGetRPGReviveHealthPercent);

	Call_PushCell(client);
	Call_PushCell(revived);

	Call_PushCellRef(temporaryHealthPercent);
	Call_PushCellRef(permanentHealthPercent);

	Call_Finish();

	if(temporaryHealthPercent > 0 || permanentHealthPercent > 0)
	{
		if(temporaryHealthPercent < 0)
			temporaryHealthPercent = 0;

		if(permanentHealthPercent < 0)
			permanentHealthPercent = 0;

		SetEntityHealth(revived, 0);
		L4D_SetPlayerTempHealth(revived, 0);

		GunXP_GiveClientHealth(revived, RoundToFloor(GetEntityMaxHealth(revived) * (float(permanentHealthPercent) / 100)), RoundToFloor(GetEntityMaxHealth(revived) * (float(temporaryHealthPercent) / 100)));
	}
	int weapon = GetPlayerWeaponSlot(revived, 1);

	if(g_sLastSecondaryClassname[revived][0] != EOS)
	{
		if(weapon != -1)
		{
			RemovePlayerItem(revived, weapon);
		}

		int newWeapon = GivePlayerItem(revived, g_sLastSecondaryClassname[revived]);

		SetEntProp(newWeapon, Prop_Send, "m_iClip1", g_iLastSecondaryClip[revived]);

		if(g_bLastSecondaryDual[revived])
		{
			SetEntProp(newWeapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(revived, newWeapon);
			SetEntProp(newWeapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(revived, newWeapon);

			// We already restore ammo.
			//SetEntProp(newWeapon, Prop_Send, "m_iClip1", GetEntProp(newWeapon, Prop_Send, "m_iClip1") * 2);
		}
	}

	return Plugin_Continue;
}



public Action Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	// Fastest reviver in the west
	if(!L4D_IsPlayerIncapacitated(client))
		return Plugin_Continue;

	// Tanks get incapacitated on death.
	else if(L4D_GetClientTeam(client) != L4DTeam_Survivor)
		return Plugin_Continue;

	int index = g_hStartIncapWeapon.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapWeapon);

	Call_PushCell(client);
	Call_PushCellRef(index);

	Call_Finish();
	
	switch(index)
	{
		case 0:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);
		}
		case 1:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");

			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);

			EquipPlayerWeapon(client, weapon);
		}
		case 2:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			weapon = GivePlayerItem(client, "weapon_pistol");
			
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 0);
			SDKHooks_DropWeapon(client, weapon);
			SetEntProp(weapon, Prop_Send, "m_isDualWielding", 1);

			EquipPlayerWeapon(client, weapon);

			SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1") * 2);
		}
		default:
		{
			int weapon = GetPlayerWeaponSlot(client, 1);

			if(weapon != -1)
				RemovePlayerItem(client, weapon);

			GivePlayerItem(client, "weapon_pistol_magnum");
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerLedgeGrabPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return Plugin_Continue;

	int health = g_hRPGLedgeHangHealth.IntValue;

	Call_StartForward(g_fwOnGetRPGIncapHealth);

	Call_PushCell(client);
	Call_PushCell(true);
	Call_PushCellRef(health);

	Call_Finish();

	g_hLedgeHangHealth.IntValue = health;

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, Event_TraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, Event_TakeDamage);
}

public Action Event_TakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if(damage == 0.0)
		return Plugin_Continue;

	// Avoid double reduction of damage in both Event_TraceAttack and Event_TakeDamage
	else if(IsPlayer(attacker))
		return Plugin_Continue;

	float fFinalDamage = damage;
	
	Action rtn = RPG_OnTraceAttack(victim, attacker, inflictor, fFinalDamage, damagetype, 0, 0);

	damage = fFinalDamage;

	return rtn;
}
public Action Event_TraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{	
	if(damage == 0.0)
		return Plugin_Continue;

	// Account for fire and fall damage in function above.
	else if(damagetype & DMG_FALL || damagetype & DMG_BURN)
		return Plugin_Continue;

	// Commons don't trigger this event, maybe they will in the future?
	else if(!IsPlayer(attacker))
		return Plugin_Continue;

	float fFinalDamage = damage;
	
	Action rtn = RPG_OnTraceAttack(victim, attacker, inflictor, fFinalDamage, damagetype, hitbox, hitgroup);

	damage = fFinalDamage;

	// Only on trace attack
	if(rtn == Plugin_Continue)
		rtn = Plugin_Changed;

	return rtn;
}

public Action RPG_OnTraceAttack(int victim, int attacker, int inflictor, float& damage, int damagetype, int hitbox, int hitgroup)
{
	bool bDontInterruptActions;
	bool bDontStagger;
	bool bDontInstakill;

	for(int i=-10;i <= 10;i++)
	{
		Call_StartForward(g_fwOnCalculateDamage);

		Call_PushCell(i);
		Call_PushCell(victim);
		Call_PushCell(attacker);
		Call_PushCell(inflictor);
		Call_PushFloatRef(damage);
		Call_PushCell(damagetype);
		Call_PushCell(hitbox);
		Call_PushCell(hitgroup);
		Call_PushCellRef(bDontInterruptActions);
		Call_PushCellRef(bDontStagger);
		Call_PushCellRef(bDontInstakill);

		Call_Finish();
	}

	if(IsPlayer(attacker) && L4D_GetClientTeam(attacker) == L4DTeam_Infected && L4D2_GetPlayerZombieClass(attacker) == L4D2ZombieClass_Tank)
		bDontInterruptActions = false;

	if(IsPlayer(attacker) && IsPlayer(victim) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
		bDontInterruptActions = false;
	
	if(damage == 0.0)
		return Plugin_Stop;

	else if(!IsPlayer(victim))
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	// Time to die / incap
	else if(damage >= float(GetEntityHealth(victim) + L4D_GetPlayerTempHealth(victim)))
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	// Let fall damage insta kill.
	else if(attacker == victim || attacker == 0)
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	if(L4D_GetClientTeam(victim) == L4DTeam_Survivor)
	{
		if(!bDontInterruptActions)
			return bDontInstakill ? Plugin_Changed : Plugin_Continue;

		//SDKHooks_TakeDamage(victim, victim, attacker, damage, damagetype, 0, NULL_VECTOR, NULL_VECTOR, true);

		if(damage < float(GetEntityHealth(victim)))
		{
			SetEntityHealth(victim, GetEntityHealth(victim) - RoundToFloor(damage));
		}
		else
		{

			// Above is already a detection if damage exceeds the player's entire health, no need to check.
			L4D_SetPlayerTempHealth(victim, L4D_GetPlayerTempHealth(victim) - RoundToFloor(damage));

			SetEntityHealth(victim, 1);
		}
		
		Event hNewEvent = CreateEvent("player_hurt", true);

		SetEventInt(hNewEvent, "userid", GetClientUserId(victim));

		if(IsPlayer(attacker))
		{
			SetEventInt(hNewEvent, "attacker", GetClientUserId(attacker));
		}
		else
		{
			SetEventInt(hNewEvent, "attacker", 0);
		}

		if(inflictor != 0 && !IsPlayer(inflictor))
		{

			char sWeaponName[64];
			GetEdictClassname(inflictor, sWeaponName, sizeof(sWeaponName));

			ReplaceStringEx(sWeaponName, sizeof(sWeaponName), "weapon_", "");

			SetEventString(hNewEvent, "weapon", sWeaponName);
		}
		else if(inflictor == attacker && IsPlayer(attacker))
		{
			int weapon = L4D_GetPlayerCurrentWeapon(attacker);

			if(weapon != -1)
			{
				
				char sWeaponName[64];
				GetEdictClassname(weapon, sWeaponName, sizeof(sWeaponName));

				ReplaceStringEx(sWeaponName, sizeof(sWeaponName), "weapon_", "");

				SetEventString(hNewEvent, "weapon", sWeaponName);
			}
		}
		SetEventInt(hNewEvent, "attackerentid", attacker);
		SetEventInt(hNewEvent, "health", GetEntityHealth(victim));
		SetEventInt(hNewEvent, "dmg_health", RoundFloat(damage));
		SetEventInt(hNewEvent, "dmg_armor", 0);
		SetEventInt(hNewEvent, "hitgroup", 0);
		SetEventInt(hNewEvent, "type", damagetype);

		FireEvent(hNewEvent);
		
		return Plugin_Stop;
	}
	else if(L4D_GetClientTeam(victim) == L4DTeam_Infected)
	{
		if(!bDontStagger)
		{
			return bDontInstakill ? Plugin_Changed : Plugin_Continue;
		}

		SetEntityHealth(victim, GetEntityHealth(victim) - RoundFloat(damage));
		Event hNewEvent = CreateEvent("player_hurt", true);

		SetEventInt(hNewEvent, "userid", GetClientUserId(victim));

		if(IsPlayer(attacker))
		{
			SetEventInt(hNewEvent, "attacker", GetClientUserId(attacker));
		}
		else
		{
			SetEventInt(hNewEvent, "attacker", 0);
		}
		
		SetEventInt(hNewEvent, "attackerentid", attacker);
		SetEventInt(hNewEvent, "health", GetEntityHealth(victim));
		SetEventInt(hNewEvent, "dmg_health", RoundFloat(damage));
		SetEventInt(hNewEvent, "dmg_armor", 0);
		SetEventInt(hNewEvent, "hitgroup", 0);
		SetEventInt(hNewEvent, "type", damagetype);

		FireEvent(hNewEvent);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action L4D2_BackpackItem_StartAction(int client, int entity)
{
	float fDuration = g_hRPGKitDuration.FloatValue;

	int target = 0;

	Call_StartForward(g_fwOnGetRPGKitDuration);

	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushFloatRef(fDuration);

	Call_Finish();

	g_hKitDuration.FloatValue = fDuration;

	return Plugin_Continue;
}

public void L4D2_BackpackItem_StartAction_Post(int client, int entity)
{
	g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
}


public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
	
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_RUN))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_ADRENALINE: retVal = g_fAbsAdrenalineSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
	}

	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;


	return Plugin_Handled;
}

public Action L4D_OnGetWalkTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
		
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_WALK))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
		case SPEEDSTATE_CUSTOM: retVal = g_fAbsCustomSpeed[client];
	}	

	// Let the client walk instead of zooming forward while walking.
	if(retVal > g_fAbsWalkSpeed[client])
		retVal = g_fAbsWalkSpeed[client];
		
	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;

	return Plugin_Handled;
}	

public Action L4D_OnGetCrouchTopSpeed(int client, float &retVal)
{
	if(!IsPlayerAlive(client) || L4D_GetClientTeam(client) != L4DTeam_Survivor) return Plugin_Continue;
	
	switch(GetMostRestrictiveSpeed(client, SPEEDSTATE_CROUCH))
	{
		case SPEEDSTATE_NULL: return Plugin_Continue;
		case SPEEDSTATE_RUN: retVal = g_fAbsRunSpeed[client];
		case SPEEDSTATE_WALK: retVal = g_fAbsWalkSpeed[client];
		case SPEEDSTATE_CROUCH: retVal = g_fAbsCrouchSpeed[client];
		case SPEEDSTATE_LIMP: retVal = g_fAbsLimpSpeed[client];
		case SPEEDSTATE_CRITICAL: retVal = g_fAbsCriticalSpeed[client];
		case SPEEDSTATE_WATER: retVal = g_fAbsWaterSpeed[client];
		case SPEEDSTATE_SCOPE: retVal = g_fAbsScopeSpeed[client];
		case SPEEDSTATE_CUSTOM: retVal = g_fAbsCustomSpeed[client];
	}

	// Let the client crouch instead of zooming forward while crouching.
	if(retVal > g_fAbsCrouchSpeed[client])
		retVal = g_fAbsCrouchSpeed[client];

	if(retVal > MAX_SPEED)
		retVal = MAX_SPEED;

	else if(retVal < MIN_SPEED)
		retVal = MIN_SPEED;

	return Plugin_Handled;
}


/**
 * Checks all the status of the client to decide what condition is the most restrictive to apply to the survivor
 * in the case is under adrenaline effect it will do the oposite and will apply the fastest speed possible based on logic
 * it works assuming that injuries, water or exhaustion will only decrease movement speed, if they are set faster than normal speeds they won't boost players
 */
int GetMostRestrictiveSpeed(int client, int speedType)	// speedType -> speed of the survivor that depends of what the player is doing
{
	// Ignore dead or incap players to avoid innecesary function calls
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated") )
		return SPEEDSTATE_NULL;

	if(g_iOverrideSpeedState[client] != SPEEDSTATE_NULL)
	{
		return g_iOverrideSpeedState[client];
	}
	bool bAdrenaline = view_as<bool>(GetEntProp(client, Prop_Send, "m_bAdrenalineActive"));
	bool bScoped = GetEntPropEnt(client, Prop_Send, "m_hZoomOwner") != -1;
	int result;
	float fSpeed;
	switch( speedType )
	{
		case SPEEDSTATE_RUN:
		{
			// if the client is scoping, first of all try to check if scoping is slower than running (it should...)
			if( bScoped && g_fAbsScopeSpeed[client] < g_fAbsRunSpeed[client] )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsRunSpeed[client];
				result = SPEEDSTATE_RUN;
			}
			/** 
			 * In case the adrenaline is on, it will try to get the fastest available speed (should be adrenaline)
			 * unless survivor is using sniper scope, where it will use the slower option (scope or the adrenaline speed)
			 * in other words overrides water/exhaustion/injuries speed penalty
			 */
			if( bAdrenaline )
			{
				// Survivor is running so it should apply adrenaline if faster
				if( result == SPEEDSTATE_RUN && g_fAbsAdrenalineSpeed[client] >= fSpeed )
				{
					// No need to check anything more
					return SPEEDSTATE_ADRENALINE;
				}
				return result;
			}
		}
		
		case SPEEDSTATE_WALK:
		{
			if( bScoped && g_fAbsScopeSpeed[client] < g_fAbsWalkSpeed[client] )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsWalkSpeed[client];
				result = SPEEDSTATE_WALK;
			}
			// On walking/crouching adrenaline speed won't be applied, only ignore everything after this
			if( bAdrenaline )
				return result;
		}
		
		case SPEEDSTATE_CROUCH:
		{
			fSpeed = g_fAbsCrouchSpeed[client];
			if( bScoped && g_fAbsScopeSpeed[client] < fSpeed )
			{
				fSpeed = g_fAbsScopeSpeed[client];
				result = SPEEDSTATE_SCOPE;
			}
			else
			{
				fSpeed = g_fAbsCrouchSpeed[client];
				result = SPEEDSTATE_CROUCH;
			}
			if( bAdrenaline )
				return result;
		}
	}
	
	// Start restrictions 
	if( GetEntityFlags(client) & FL_INWATER && g_fAbsWaterSpeed[client] < fSpeed ) // Survivor is on water
	{
		fSpeed = g_fAbsWaterSpeed[client];
		result = SPEEDSTATE_WATER;
	}
	int limping = GetLimping(client);

	if( limping == SPEEDSTATE_CRITICAL && g_fAbsCriticalSpeed[client] < fSpeed )
		return SPEEDSTATE_CRITICAL;
		
	if( limping == SPEEDSTATE_LIMP && g_fAbsLimpSpeed[client] < fSpeed )
		return SPEEDSTATE_LIMP;
		
	return result;
}

/**
 * This determines if the survivor has reached the limp situation (by default absolute health is under 40)
 * This function never must be called under adrenaline because it doesn't check this situation
 * Avoid calls under adrenaline or you will get false results
 */
int GetLimping(int client)
{
	int iAbsHealth = GetEntityHealth(client) + L4D_GetPlayerTempHealth(client);

	if(iAbsHealth >= 1 && iAbsHealth < g_iAbsLimpHealth[client])
	{
		if( iAbsHealth == 1 && GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0) return SPEEDSTATE_CRITICAL;
			
		else return SPEEDSTATE_LIMP;
	}
	else return SPEEDSTATE_RUN;
}

stock int GetClosestPlayerToAim(int client)
{
	float fOrigin[3], fAngles[3], fFwd[3];

	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);

	GetAngleVectors(fAngles, fFwd, NULL_VECTOR, NULL_VECTOR);

	int winner = 0;
	float winnerProduct = 1.0;

	for(int i=1;i <= MaxClients;i++)
	{
		if(client == i)
			continue;

		else if(!IsClientInGame(i))
			continue;

		else if(!IsPlayerAlive(i))
			continue;

		else if(GetClientTeam(i) != GetClientTeam(client))
			continue;

		else if(!ArePlayersInLOS(client, i))
			continue;

		float fTargetOrigin[3];
		GetClientEyePosition(i, fTargetOrigin);

		float fSubOrigin[3];

		SubtractVectors(fOrigin, fTargetOrigin, fSubOrigin);

		NormalizeVector(fSubOrigin, fSubOrigin);

		float fDotProduct = GetVectorDotProduct(fFwd, fSubOrigin);

		if(winnerProduct > fDotProduct)
		{
			winnerProduct = fDotProduct;
			winner = i;
		}
	}

	if(winner == 0)
	{
		return 0;
	}

	return winner;
}

stock bool ArePlayersInLOS(int client1, int client2)
{
	float vecMin[3], vecMax[3], vecOriginClient1[3], vecOriginClient2[3];

	GetClientMins(client1, vecMin);
	GetClientMaxs(client1, vecMax);

	GetClientAbsOrigin(client1, vecOriginClient1);
	GetClientAbsOrigin(client2, vecOriginClient2);

	TR_TraceHullFilter(vecOriginClient1, vecOriginClient2, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);

	return !TR_DidHit();
}

public bool TraceRayDontHitPlayers(int entityhit, int mask)
{
	return (entityhit > MaxClients || entityhit == 0);
}



stock bool IsPlayerStuck(int client, const float Origin[3] = NULL_VECTOR, float HeightOffset = 0.0)
{
	float vecMin[3], vecMax[3], vecOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);

	if (UC_IsNullVector(Origin))
	{
		GetClientAbsOrigin(client, vecOrigin);

		vecOrigin[2] += HeightOffset;
	}
	else
	{
		vecOrigin = Origin;

		vecOrigin[2] += HeightOffset;
	}

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayers);
	return TR_DidHit();
}

stock bool UC_IsNullVector(const float Vector[3])
{
	return (Vector[0] == NULL_VECTOR[0] && Vector[0] == NULL_VECTOR[1] && Vector[2] == NULL_VECTOR[2]);
}