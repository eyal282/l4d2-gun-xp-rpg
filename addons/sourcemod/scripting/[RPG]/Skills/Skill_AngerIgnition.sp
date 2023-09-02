
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
    name        = "Anger Ignition Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes me steal bad buffs from MGFTW and turn them into skills",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar g_hDamagePriority;

int ignitionIndex;

float g_fChancePerLevels = 0.002;
int g_iChanceLevels = 5;

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

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == 10)
    {
        if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
            return;

        else if(RPG_Perks_GetZombieType(attacker) != ZombieType_CommonInfected)
            return;
    
        else if(!GunXP_RPGShop_IsSkillUnlocked(victim, ignitionIndex))
            return;

        else if(damage == 0.0)
            return;

        float fChance = g_fChancePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(attacker)) / float(g_iChanceLevels)));

        if(GetRandomFloat(0.0, 100.0) < fChance)
        {        
            CastAngerIgnition(victim);
        }
    }
}

public void CastAngerIgnition(int client)
{
    PrintToChat(client, "Anger Ignition was activated!");
    
    float fTargetOrigin[3];

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", fTargetOrigin);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client)
            continue;

        else if (!IsClientInGame(i))
            continue;

        else if (!IsPlayerAlive(i))
            continue;

        float fOrigin[3];
        GetEntPropVector(i, Prop_Data, "m_vecOrigin", fOrigin);

        if (GetVectorDistance(fOrigin, fTargetOrigin, false) < 512.0)
        {
            SDKHooks_TakeDamage(i, client, client, 0.0, DMG_BURN);
        }
    }

    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "infected")) != -1)
    {
        float fOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fOrigin);

        if (GetVectorDistance(fOrigin, fTargetOrigin, false) < 512.0)
        {
            SDKHooks_TakeDamage(iEntity, client, client, 0.0, DMG_BURN);
        }
    }

    iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "witch")) != -1)
    {
        float fOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fOrigin);

        if (GetVectorDistance(fOrigin, fTargetOrigin, false) < 512.0)
        {
            SDKHooks_TakeDamage(iEntity, client, client, 0.0, DMG_BURN);
        }
    }

    iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "weapon_gascan")) != -1)
    {
        float fOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fOrigin);

        if (GetVectorDistance(fOrigin, fTargetOrigin, false) < 512.0)
        {
            AcceptEntityInput(iEntity, "Ignite", client, client);
        }
    }
}
public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Taking damage from Common Infected has a chance to ignite everything around.\nRadius is 512 units.\nChance is %.1f{PERCENT} per %i Levels", g_fChancePerLevels * 100.0, g_iChanceLevels);
    ignitionIndex = GunXP_RPGShop_RegisterSkill("Anger Ignition", "Anger Ignition", sDescription,
    150000, 0);
}


