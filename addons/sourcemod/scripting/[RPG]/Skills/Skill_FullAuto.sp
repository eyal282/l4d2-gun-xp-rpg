
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
    name        = "Full Auto Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes every weapon fully automatic",
    version     = PLUGIN_VERSION,
    url         = ""
};

bool g_bFullAuto[MAXPLAYERS+1];

int fullAutoIndex;

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
    RegisterSkill();
}


public void OnMapStart()
{
    TriggerTimer(CreateTimer(10.0, Timer_MonitorFullAuto, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action Timer_MonitorFullAuto(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        g_bFullAuto[i] = GunXP_RPGShop_IsSkillUnlocked(i, fullAutoIndex);
    }

    return Plugin_Continue;
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, fullAutoIndex))
        return;
        
    g_bFullAuto[client] = false;
}

public void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG)
{
    if(skillIndex != fullAutoIndex)
        return;

    g_bFullAuto[client] = true;
}

public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
    if(priority != 0)
        return;

    g_bFullAuto[client] = GunXP_RPGShop_IsSkillUnlocked(client, fullAutoIndex);
}

public void RegisterSkill()
{
    fullAutoIndex = GunXP_RPGShop_RegisterSkill("Full Auto", "Full Auto", "All weapons are fully automatic",
    90000, 0);
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{   
    if(!g_bFullAuto[client])
        return Plugin_Continue;

    if (buttons & IN_ATTACK)
    {
        if(!IsClientInGame(client)
            || !IsPlayerAlive(client)
            || L4D_GetClientTeam(client) != L4DTeam_Survivor
            || IsUsingMinigun(client))
            return Plugin_Continue;

        int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        
        if(!IsValidEntity(iActiveWeapon)
                || GetEntPropFloat(iActiveWeapon, Prop_Send, "m_flCycle") > 0
                || GetEntProp(iActiveWeapon, Prop_Send, "m_bInReload") > 0)
        return Plugin_Continue;

        // SetEntProp(CurrentWeapon, Prop_Send, "m_isHoldingFireButton", 1); //Is holding the IN_ATTACK
        SetEntProp(iActiveWeapon, Prop_Send, "m_isHoldingFireButton", 0); //Is not holding the IN_ATTACK // LOOOOOOOOOOOOOOOL SEMS LEGIT

        int offset;
        FindDataMapInfo(iActiveWeapon, "m_isHoldingFireButton", _, _, offset);
        ChangeEdictState(iActiveWeapon, offset);
            
        //EmitSoundToClient(client,"^weapons/pistol/gunfire/pistol_fire.wav"); // The "Normal" Fire sound is little buggy...
    }
    return Plugin_Continue;
}