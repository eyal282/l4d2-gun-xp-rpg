
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
    name        = "Immolation Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes you ignite yourself for x seconds when you throw molotov on yourself",
    version     = PLUGIN_VERSION,
    url         = ""
};

int g_iMagnumShots = 2;
#define DAMAGE_IMMOLATION 80.0 * float(g_iMagnumShots)

Handle g_hTimer[MAXPLAYERS+1];

int immolationIndex;

float g_fDurationPerLevel = 0.5;

float g_fRadius = 512.0;

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
    for(int i=0;i < sizeof(g_hTimer);i++)
    {
        g_hTimer[i] = INVALID_HANDLE;
    }
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
	if(L4D2_GetWeaponId(weapon) != L4D2WeaponId_Molotov)
        return;

	else if(!GunXP_RPGShop_IsSkillUnlocked(client, immolationIndex))
		return;

	speedmodifier = 10.0;
}


public void RPG_Perks_OnTimedAttributeStart(int attributeEntity, char attributeName[64], float fDuration)
{
    if(StrEqual(attributeName, "Immolation") && IsPlayer(attributeEntity))
    {
        if(g_hTimer[attributeEntity] != INVALID_HANDLE)
        {
            CloseHandle(g_hTimer[attributeEntity]);
            g_hTimer[attributeEntity] = INVALID_HANDLE;
        }            

        g_hTimer[attributeEntity] = CreateTimer(1.0, Timer_CastImmolation, GetClientUserId(attributeEntity), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    }
}

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Immolation"))
        return;

    if(g_hTimer[oldClient] != INVALID_HANDLE)
    {
        CloseHandle(g_hTimer[oldClient]);
        g_hTimer[oldClient] = INVALID_HANDLE;
    }
    
    g_hTimer[newClient] = CreateTimer(1.0, Timer_CastImmolation, GetClientUserId(newClient), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void OnEntityDestroyed(int entity)
{
    if(!IsValidEntityIndex(entity))
        return;

    char sClassname[64];
    GetEdictClassname(entity, sClassname, sizeof(sClassname));
    
    if(!StrEqual(sClassname, "molotov_projectile"))
        return;
    
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");

    if(owner == -1)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(owner, immolationIndex))
        return;

    float fDetonationOrigin[3];

    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fDetonationOrigin);

    float fOrigin[3];

    GetEntPropVector(owner, Prop_Data, "m_vecAbsOrigin", fOrigin);

    if(!GunXP_RPGShop_IsSkillUnlocked(owner, immolationIndex))
        return;

    if(IsPlayerAlive(owner))
    {
        if(GetVectorDistance(fOrigin, fDetonationOrigin) < 128.0)
        {
            float fDuration = g_fDurationPerLevel * float(GunXP_RPG_GetClientLevel(owner));

            PrintToChat(owner, "Immolation is active for %.1f seconds.", fDuration);

            RPG_Perks_ApplyEntityTimedAttribute(owner, "Immolation", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);
        }
    }
    else
    {
        float fDuration = g_fDurationPerLevel * float(GunXP_RPG_GetClientLevel(owner));

        PrintToChat(owner, "Immolation is active on your dead body for %.1f seconds.", fDuration);

        int body = CreateEntityByName("info_target");

        DispatchSpawn(body);

        SetEntPropEnt(body, Prop_Send, "m_hOwnerEntity", owner);

        TeleportEntity(body, fDetonationOrigin, NULL_VECTOR, NULL_VECTOR);

        RPG_Perks_ApplyEntityTimedAttribute(body, "Immolation", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

        CreateTimer(1.0, Timer_CastImmolationOnBody, EntIndexToEntRef(body), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    }
}


public Action Timer_CastImmolation(Handle hTimer, int userid)
{
    int client = GetClientOfUserId(userid);

    if(client == 0)
        return Plugin_Stop;

    else if(!RPG_Perks_IsEntityTimedAttribute(client, "Immolation"))   
    {
        g_hTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    float fOrigin[3];

    GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

    InflictImmolationDamage(client, fOrigin);

    return Plugin_Continue;
}


public Action Timer_CastImmolationOnBody(Handle hTimer, int entRef)
{
    int body = EntRefToEntIndex(entRef);

    if(body == INVALID_ENT_REFERENCE)
        return Plugin_Stop;

    else if(!RPG_Perks_IsEntityTimedAttribute(body, "Immolation"))   
    {
        AcceptEntityInput(body, "Kill");

        return Plugin_Stop;
    }

    int owner = GetEntPropEnt(body, Prop_Send, "m_hOwnerEntity");

    if(owner == -1)
    {
        AcceptEntityInput(body, "Kill");

        return Plugin_Stop;
    }

    float fOrigin[3];

    GetEntPropVector(body, Prop_Data, "m_vecOrigin", fOrigin);

    InflictImmolationDamage(owner, fOrigin);

    return Plugin_Continue;
}

public void InflictImmolationDamage(int client, float fOrigin[3])
{
    int iFakeWeapon = CreateEntityByName("weapon_pistol_magnum");

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

        if (GetVectorDistance(fVictimOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DROWNRECOVER);

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

        if (GetVectorDistance(fVictimOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DROWNRECOVER);

            RPG_Perks_IgniteWithOwnership(victim, client);
        }
    }

    for(int i=0;i < numWitchRealm;i++)
    {
        int victim = witchRealm[i];

        float fVictimOrigin[3];
        GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

        if (GetVectorDistance(fVictimOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DROWNRECOVER);

            RPG_Perks_IgniteWithOwnership(victim, client);
        }
    }

    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "weapon_gascan")) != -1)
    {
        float fEntityOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);

        if (GetVectorDistance(fEntityOrigin, fOrigin, false) < g_fRadius)
        {
            AcceptEntityInput(iEntity, "Ignite", client, client);
        }
    }

    AcceptEntityInput(iFakeWeapon, "Kill");
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Throwing a molotov on yourself ignites you/r dead body, hurting Zombies near you.\nDuration is half your level, and stacks. Radius of damaging is %.0f units and ignores damage immunities.\nEvery second while active, zombies take damage equal to %i magnum shots\nDamage is boosted by Marksman, and Molotov deploys instantly", g_fRadius, g_iMagnumShots);
    immolationIndex = GunXP_RPGShop_RegisterSkill("Immolation", "Immolation", sDescription,
    150000, 0);
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}