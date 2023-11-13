
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
    name        = "Beast Tamer Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes you able to ride on your pet.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int tamerIndex;

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

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action RPG_Perks_OnShouldIgnoreEntireTeamTouch(int client)
{
    if(IsFakeClient(client) && L4D2_GetCurrentFinaleStage() != FINALE_GAUNTLET_ESCAPE)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action L4D2_OnEntityShoved(int client, int victim, int weapon, float vecDir[3], bool bIsHighPounce)
{
    if(RPG_Perks_GetZombieType(victim) != ZombieType_Charger)
        return Plugin_Continue;

    int owner = GetEntPropEnt(victim, Prop_Send, "m_hOwnerEntity");

    if(owner == -1)
         return Plugin_Continue;

    else if(RPG_Perks_GetZombieType(owner) != ZombieType_NotInfected)
         return Plugin_Continue;

    if(L4D2_Pets_GetCarrier(client) == victim)
    {
        L4D2_Pets_ForceCarry(client, -1);

        return Plugin_Continue;
    }
    else if(L4D2_Pets_GetCarrier(client) == -1 && GunXP_RPGShop_IsSkillUnlocked(client, tamerIndex) && GetClientButtons(client) & IN_USE)
    {
        L4D2_Pets_ForceCarry(client, victim);
    }

    return Plugin_Continue;
}

public Action L4D2_Pets_OnTryEndCarry(int victim, int pet, int owner)
{
    if(victim != owner)
        return Plugin_Continue;

    else if(L4D_GetPinnedInfected(victim) != 0)
        return Plugin_Continue;

    else if(L4D_IsInLastCheckpoint(victim))
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(victim, tamerIndex))
        return Plugin_Continue;

    return Plugin_Handled;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Shove your Pet while holding E to start/stop getting carried.\nYour pet will go to safe room if able\nIf it cannot, or if you're holding SHIFT, it'll attack normally"); 

    tamerIndex = GunXP_RPGShop_RegisterSkill("Ride on your Pet", "Beast Tamer", sDescription,
    0, 1000000);
}
