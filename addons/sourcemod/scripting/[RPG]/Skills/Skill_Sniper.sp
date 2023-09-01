
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
    name        = "Sniper Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that gives you near perfect aim while standing and incapped.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int sniperIndex;

ConVar hcv_IncapAccuracyPenalty;
ConVar hcv_IncapCameraShake;

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
    hcv_IncapAccuracyPenalty = FindConVar("survivor_incapacitated_accuracy_penalty");
    hcv_IncapCameraShake = FindConVar("survivor_incapacitated_dizzy_severity");

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    char sValue[32];

    FloatToString(hcv_IncapAccuracyPenalty.FloatValue, sValue, sizeof(sValue));
    SendConVarValue(client, hcv_IncapAccuracyPenalty, sValue);

    FloatToString(hcv_IncapCameraShake.FloatValue, sValue, sizeof(sValue));
    SendConVarValue(client, hcv_IncapCameraShake, sValue);
}

public void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG)
{
    if(skillIndex != sniperIndex)
        return;

    SendConVarValue(client, hcv_IncapAccuracyPenalty, "0.0");
    SendConVarValue(client, hcv_IncapCameraShake, "0.0");
}

public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
    if(priority != 0)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    SendConVarValue(client, hcv_IncapAccuracyPenalty, "0.0");
    SendConVarValue(client, hcv_IncapCameraShake, "0.0");
}
public void OnMapStart()
{
    TriggerTimer(CreateTimer(1.5, Timer_MonitorSniper, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));
}

public Action Timer_MonitorSniper(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(!GunXP_RPGShop_IsSkillUnlocked(i, sniperIndex))
            continue;

        int weapon = GetPlayerWeaponSlot(i, view_as<int>(L4DWeaponSlot_Primary));

        if(weapon != -1)
        {
            if(L4D2_IsWeaponUpgradeCompatible(weapon))
            {
                if(!(L4D2_GetWeaponUpgrades(weapon) & L4D2_WEPUPGFLAG_LASER))
                {
                    GiveClientWeaponUpgrade(i, 2);
                }
            }
        }
    }

    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "All weapons you use will have laser sights.\nYour camera won't shake while incapactitated.\nBeing incapped suffers no weapon inaccuracy.");

    sniperIndex = GunXP_RPGShop_RegisterSkill("Sniper", "Sniper", sDescription,
    200000, 0);
}

stock void GiveClientWeaponUpgrade(int client, int upgrade)
{
    char code[512];

    FormatEx(code, sizeof(code), "ret <- GetPlayerFromUserID(%d).GiveUpgrade(%i); <RETURN>ret</RETURN>", GetClientUserId(client), upgrade);

    char sOutput[512];
    L4D2_GetVScriptOutput(code, sOutput, sizeof(sOutput));
}