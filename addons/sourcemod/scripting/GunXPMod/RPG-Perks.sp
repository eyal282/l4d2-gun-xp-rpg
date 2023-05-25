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


public void OnPluginEnd()
{
    g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
    g_hReviveDuration.FloatValue = g_hRPGReviveDuration.FloatValue;
}

public void OnPluginStart()
{
    g_fwOnGetRPGKitDuration = CreateGlobalForward("RPG_Perks_OnGetKitDuration", ET_Ignore, Param_Cell, Param_FloatByRef);
    g_fwOnGetRPGReviveDuration = CreateGlobalForward("RPG_Perks_OnGetReviveDuration", ET_Ignore, Param_Cell, Param_FloatByRef);

    g_hKitDuration = FindConVar("first_aid_kit_use_duration");
    g_hRPGKitDuration = CreateConVar("rpg_first_aid_kit_use_duration", "5", "Default time for use with first aid kit.");

    g_hReviveDuration = FindConVar("survivor_revive_duration");
    g_hRPGReviveDuration = CreateConVar("rpg_survivor_revive_duration", "5", "Default time for reviving.");
}

public Action L4D2_BackpackItem_StartAction(int client, int entity)
{
    float fDuration = g_hRPGKitDuration.FloatValue;

    Call_StartForward(g_fwOnGetRPGKitDuration);

    Call_PushCell(client);
    Call_PushFloatRef(fDuration);

    Call_Finish();

    g_hKitDuration.FloatValue = fDuration;

    return Plugin_Continue;
}

public void L4D2_BackpackItem_StartAction_Post(int client, int entity)
{
    g_hKitDuration.FloatValue = g_hRPGKitDuration.FloatValue;
}