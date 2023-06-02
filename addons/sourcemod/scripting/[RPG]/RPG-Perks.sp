#include <GunXP-RPG>
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

ConVar g_hKitDuration;
ConVar g_hRPGKitDuration;

ConVar g_hReviveDuration;
ConVar g_hRPGReviveDuration;

ConVar g_hIncapHealth;
ConVar g_hRPGIncapHealth;

ConVar g_hLedgeHangHealth;
ConVar g_hRPGLedgeHangHealth;

ConVar g_hStartIncapWeapon;

GlobalForward g_fwOnGetRPGKitDuration;
GlobalForward g_fwOnGetRPGReviveDuration;
GlobalForward g_fwOnGetRPGIncapWeapon;
GlobalForward g_fwOnGetRPGIncapHealth;
GlobalForward g_fwOnCalculateDamage;

char g_sLastSecondaryClassname[MAXPLAYERS+1][64];
int g_iLastSecondaryClip[MAXPLAYERS+1];
bool g_bLastSecondaryDual[MAXPLAYERS+1];

public void OnPluginEnd()
{
	g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
	g_hReviveDuration.FloatValue = g_hRPGReviveDuration.FloatValue;
}

public void OnPluginStart()
{
	HookEvent("player_incapacitated_start", Event_PlayerIncapStartPre, EventHookMode_Pre);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_PlayerReplacesABot, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrabPre, EventHookMode_Pre);
	HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);

	g_fwOnGetRPGKitDuration = CreateGlobalForward("RPG_Perks_OnGetKitDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGReviveDuration = CreateGlobalForward("RPG_Perks_OnGetReviveDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGIncapHealth = CreateGlobalForward("RPG_Perks_OnGetIncapHealth", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_fwOnGetRPGIncapWeapon = CreateGlobalForward("RPG_Perks_OnGetIncapWeapon", ET_Ignore, Param_Cell, Param_CellByRef);

	g_fwOnCalculateDamage = CreateGlobalForward("RPG_Perks_OnCalculateDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef);

	AutoExecConfig_SetFile("RPG-Perks");

	g_hKitDuration = FindConVar("first_aid_kit_use_duration");
	g_hRPGKitDuration = AutoExecConfig_CreateConVar("rpg_first_aid_kit_use_duration", "5", "Default time for use with first aid kit.");

	g_hReviveDuration = FindConVar("survivor_revive_duration");
	g_hRPGReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_revive_duration", "5", "Default time for reviving.");


	g_hIncapHealth = FindConVar("survivor_incap_health");
	g_hRPGIncapHealth = AutoExecConfig_CreateConVar("rpg_survivor_incap_health", "300", "Default HP for being incapacitated");

	g_hLedgeHangHealth = FindConVar("survivor_ledge_grab_health");
	g_hRPGLedgeHangHealth = AutoExecConfig_CreateConVar("rpg_survivor_ledge_grab_health", "300", "Default HP for ledge hanging");

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
			SDKHook(i, SDKHook_TraceAttack, Event_TraceAttack);
	}
}

// Must add natives for after a player spawns for incap hidden pistol.
public void GunXP_RPG_OnPlayerSpawned(int client)
{
	// Fastest reviver in the west
	if(!L4D_IsPlayerIncapacitated(client))
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

	if(reviver == 0)
		return Plugin_Continue;

	float fDuration = g_hRPGReviveDuration.FloatValue;

	Call_StartForward(g_fwOnGetRPGReviveDuration);

	Call_PushCell(reviver);
	Call_PushCell(GetClientOfUserId(event.GetInt("subject")));
	Call_PushFloatRef(fDuration);

	Call_Finish();

	g_hReviveDuration.FloatValue = fDuration;

	return Plugin_Continue;
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

public Action Event_PlayerReplacesABot(Handle event, const char[] name, bool dontBroadcast)
{
	int newPlayer = GetClientOfUserId(GetEventInt(event, "player"));

	g_sLastSecondaryClassname[newPlayer][0] = EOS;
	g_iLastSecondaryClip[newPlayer] = 0;
	g_bLastSecondaryDual[newPlayer] = false;

	return Plugin_Continue;
}


public Action Event_ReviveSuccess(Handle event, const char[] name, bool dontBroadcast)
{
	int revived = GetClientOfUserId(GetEventInt(event, "subject"));

	if(revived == 0)
		return Plugin_Continue;

	else if(GetEventBool(event, "ledge_hang"))
		return Plugin_Continue;

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
}

public Action Event_TraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{	
	if(damage == 0.0)
		return Plugin_Continue;

	bool bDontInterruptActions;
	bool bDontStagger;
	bool bDontInstakill;

	for(int i=-5;i <= 5;i++)
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

	if(damage == 0.0)
		return Plugin_Stop;

	else if(!IsPlayer(victim))
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	// Time to die / incap
	else if(damage >= float(GetEntityHealth(victim)))
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	// Let fall damage insta kill.
	else if(attacker == victim || attacker == 0)
		return bDontInstakill ? Plugin_Changed : Plugin_Continue;

	if(L4D_GetClientTeam(victim) == L4DTeam_Survivor)
	{
		if(!bDontInterruptActions)
			return bDontInstakill ? Plugin_Changed : Plugin_Continue;

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