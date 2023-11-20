
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
    name        = "Athlete Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes you instantly get up when you clear from pin.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int g_iLastCarryVictim[MAXPLAYERS+1];

int athleteIndex;

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_SkillShop"))
    {
        RegisterSkill();
    }
}
public void OnConfigsExecuted()
{
    RegisterSkill();

}
public void OnPluginStart()
{
    HookEvent("tongue_release", Event_PinEnded);
    HookEvent("pounce_end", Event_PinEnded);
    HookEvent("jockey_ride_end", Event_PinEnded);
    HookEvent("charger_pummel_end", Event_PinEnded);
    HookEvent("charger_carry_start", Event_CarryStarted);
    HookEvent("charger_carry_end", Event_CarryEnded);
    HookEvent("player_death", Event_PlayerDeath);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public Action Event_PlayerDeath(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int charger = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    
    if(charger == 0)
        return Plugin_Continue;

    int carried = GetClientOfUserId(g_iLastCarryVictim[charger]);

    if(carried == 0)
        return Plugin_Continue;

    g_iLastCarryVictim[charger] = 0;
    CheckAthleteGetup(carried);

    return Plugin_Continue;
}


public Action Event_CarryStarted(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));
    
    if(victim == 0)
        return Plugin_Continue;

    else if(attacker == 0)
        return Plugin_Continue;

    g_iLastCarryVictim[attacker] = 0;

    return Plugin_Continue;
}

public Action Event_CarryEnded(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));
    
    if(victim == 0)
        return Plugin_Continue;

    else if(attacker == 0)
        return Plugin_Continue;

    g_iLastCarryVictim[attacker] = GetClientUserId(victim);

    return Plugin_Continue;
}
public Action Event_PinEnded(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(hEvent, "victim"));
    int attacker = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    if(victim == 0)
        return Plugin_Continue;

    if(attacker != 0)
    {
        g_iLastCarryVictim[attacker] = 0;
    }

    CheckAthleteGetup(victim);

    return Plugin_Continue;
}

public void CheckAthleteGetup(int victim)
{
    if(L4D_IsPlayerIncapacitated(victim))
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(victim, athleteIndex))
        return;

    char TempFormat[128];
    FormatEx(TempFormat, sizeof(TempFormat), "GetPlayerFromUserID(%i).SetModel(GetPlayerFromUserID(%i).GetModelName())", GetClientUserId(victim), GetClientUserId(victim));
    L4D2_ExecVScriptCode(TempFormat);
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "You instantly get up when a Special Infected stops pinning you.\nThis won't apply if you're incapped.");
    athleteIndex = GunXP_RPGShop_RegisterSkill("Instantly Getup After Pinned", "Athlete", sDescription,
    200000, 0);
}


