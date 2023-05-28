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

GlobalForward g_fwOnGetRPGKitDuration;
GlobalForward g_fwOnGetRPGReviveDuration;
GlobalForward g_fwOnCalculateDamage;


public void OnPluginEnd()
{
	g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
	g_hReviveDuration.FloatValue = g_hRPGReviveDuration.FloatValue;
}

public void OnPluginStart()
{
	HookEvent("revive_begin", Event_ReviveBeginPre, EventHookMode_Pre);

	g_fwOnGetRPGKitDuration = CreateGlobalForward("RPG_Perks_OnGetKitDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);
	g_fwOnGetRPGReviveDuration = CreateGlobalForward("RPG_Perks_OnGetReviveDuration", ET_Ignore, Param_Cell, Param_Cell, Param_FloatByRef);

	// Run an incap or held slot check to determine if you want to prevent interrupting actions.
	// public void RPG_Perks_OnCalculateDamage(int victim, int attacker, int inflictor, float &damage, int damagetype, bool &bDontInterruptActions)
	g_fwOnCalculateDamage = CreateGlobalForward("RPG_Perks_OnCalculateDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef, Param_Cell, Param_CellByRef);

	AutoExecConfig_SetFile("RPG-Perks");

	g_hKitDuration = FindConVar("first_aid_kit_use_duration");
	g_hRPGKitDuration = AutoExecConfig_CreateConVar("rpg_first_aid_kit_use_duration", "5", "Default time for use with first aid kit.");

	g_hReviveDuration = FindConVar("survivor_revive_duration");
	g_hRPGReviveDuration = AutoExecConfig_CreateConVar("rpg_survivor_revive_duration", "5", "Default time for reviving.");

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
			SDKHook(i, SDKHook_OnTakeDamage, Event_OnTakeDamage);
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

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
}

public Action Event_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// public void RPG_Perks_OnCalculateDamage(int victim, int attacker, float &damage, int damagetype)

	Call_StartForward(g_fwOnCalculateDamage);

	bool bDontInterruptActions;
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(inflictor);
	Call_PushFloatRef(damage);
	Call_Finish();

	if(damage == 0.0)
		return Plugin_Stop;

	else if(!IsPlayer(victim))
		return Plugin_Changed;

	// Time to die.
	else if(L4D_IsPlayerIncapacitated(victim) && damage >= float(GetEntityHealth(victim)))
		return Plugin_Changed;

	// Let fall damage insta kill.
	else if(attacker == victim || attacker == 0)
		return Plugin_Changed;

	else if(!bDontInterruptActions)
		return Plugin_Changed;

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