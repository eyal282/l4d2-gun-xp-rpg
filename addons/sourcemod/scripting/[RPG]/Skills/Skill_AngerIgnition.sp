
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
        if(RPG_Perks_GetZombieType(attacker) != ZombieType_CommonInfected || RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
            return;
    
        else if(!GunXP_RPGShop_IsSkillUnlocked(victim, ignitionIndex))
            return;

        else if(damage == 0.0 || bImmune)
            return;

        float fChance = g_fChancePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(victim)) / float(g_iChanceLevels)));

        float fGamble = GetRandomFloat(0.0, 1.0);

        if(fGamble < fChance)
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

    int pinner = L4D_GetPinnedInfected(client);

    if(pinner != 0)
    {
        if(RPG_Perks_GetZombieType(pinner) == ZombieType_Smoker)
        {
            float fOrigin[3], fSmokerOrigin[3];

            GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);
            GetEntPropVector(pinner, Prop_Data, "m_vecAbsOrigin", fSmokerOrigin);

            L4D_Smoker_ReleaseVictim(client, pinner);

            if(GetVectorDistance(fOrigin, fSmokerOrigin) <= 128.0)
            {
                RPG_Perks_IgniteWithOwnership(pinner, client);
                RPG_Perks_TakeDamage(pinner, client, client, 10000.0, DMG_BURN|DMG_DROWNRECOVER);
            }
        }
        else
        {
            RPG_Perks_IgniteWithOwnership(pinner, client);
            RPG_Perks_TakeDamage(pinner, client, client, 10000.0, DMG_BURN|DMG_DROWNRECOVER);
        }
    }

    int siRealm[MAXPLAYERS+1], numSIRealm;
    int ciRealm[MAXPLAYERS+1], numCIRealm;
    int witchRealm[MAXPLAYERS+1], numWitchRealm;

    /*RPG_Perks_GetZombiesInRealms(
        siNormal, numSINormal, siShadow, numSIShadow,
        ciNormal, numCINormal, ciShadow, numCIShadow,
        witchNormal, numWitchNormal, witchShadow, numWitchShadow);*/

    if(RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm"))
    {
        RPG_Perks_GetZombiesInRealms(
            _, _, siRealm, numSIRealm,
            _, _, ciRealm, numCIRealm,
            _, _, witchRealm, numWitchRealm);
    }
    else
    {
        RPG_Perks_GetZombiesInRealms(
            siRealm, numSIRealm, _, _,
            ciRealm, numCIRealm, _, _,
            witchRealm, numWitchRealm, _, _);
    }

    for(int i=0;i < numSIRealm;i++)
    {
        int victim = siRealm[i];

        if(!IsPlayerAlive(victim))
            continue;

        float fVictimOrigin[3];
        GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

        if (GetVectorDistance(fVictimOrigin, fTargetOrigin, false) < 512.0)
        {
            if(!RPG_Tanks_IsDamageImmuneTo(victim, DAMAGE_IMMUNITY_BURN))
            {
                RPG_Perks_IgniteWithOwnership(victim, client);
            }
        }
    }

    for(int i=0;i < numCIRealm;i++)
    {
        int victim = ciRealm[i];

        float fVictimOrigin[3];
        GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

        if (GetVectorDistance(fVictimOrigin, fTargetOrigin, false) < 512.0)
        {
            RPG_Perks_IgniteWithOwnership(victim, client);
        }
    }

    for(int i=0;i < numWitchRealm;i++)
    {
        int victim = witchRealm[i];

        float fVictimOrigin[3];
        GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

        if (GetVectorDistance(fVictimOrigin, fTargetOrigin, false) < 512.0)
        {
            RPG_Perks_IgniteWithOwnership(victim, client);
        }
    }

    int iEntity = -1;
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
    FormatEx(sDescription, sizeof(sDescription), "Taking damage from Common Infected has a chance to ignite everything around.\nRadius is 512 units.\nKills any pinning Special Infected.\nChance is %.1f{PERCENT} per %i Levels", g_fChancePerLevels * 100.0, g_iChanceLevels);
    ignitionIndex = GunXP_RPGShop_RegisterSkill("Anger Ignition", "Anger Ignition", sDescription,
    75000, 750000);
}


