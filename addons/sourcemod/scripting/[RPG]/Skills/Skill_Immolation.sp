
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

    if(GetVectorDistance(fOrigin, fDetonationOrigin) < 128.0)
    {
        float fDuration = g_fDurationPerLevel * float(GunXP_RPG_GetClientLevel(owner));

        PrintToChat(owner, "Immolation is active for %.1f seconds.", fDuration);

        RPG_Perks_ApplyEntityTimedAttribute(owner, "Immolation", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

        if(g_hTimer[owner] != INVALID_HANDLE)
        {
            CloseHandle(g_hTimer[owner]);
            g_hTimer[owner] = INVALID_HANDLE;
        }

        g_hTimer[owner] = CreateTimer(1.0, Timer_CastImmolation, GetClientUserId(owner), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
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

    int iFakeWeapon = CreateEntityByName("weapon_pistol_magnum");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (i == client)
            continue;

        else if (!IsClientInGame(i))
            continue;

        else if (!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(client) == L4D_GetClientTeam(i))
            continue;

        float fEntityOrigin[3];
        GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", fEntityOrigin);

        if (GetVectorDistance(fEntityOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(i, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DIRECT);

            if(!RPG_Tanks_IsDamageImmuneTo(i, DAMAGE_IMMUNITY_BURN))
            {
                RPG_Perks_IgniteWithOwnership(i, client);
            }
        }
    }

    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "infected")) != -1)
    {
        float fEntityOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);

        if (GetVectorDistance(fEntityOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DIRECT);
            RPG_Perks_IgniteWithOwnership(iEntity, client);
        }
    }

    iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "witch")) != -1)
    {
        float fEntityOrigin[3];
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin);

        if (GetVectorDistance(fEntityOrigin, fOrigin, false) < g_fRadius)
        {
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, DAMAGE_IMMOLATION, DMG_BULLET|DMG_DIRECT);
            RPG_Perks_IgniteWithOwnership(iEntity, client);
        }
    }

    iEntity = -1;
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
    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Throwing a molotov on yourself ignites you, igniting and damaging all Zombies around.\nDuration is half your level, and stacks.\nRadius of damaging is %.0f units\nEvery second while active, zombies take damage equal to %i magnum shots\nDamage is boosted by Marksman, and bypasses all protection\nDeploy Molotov instantly.", g_fRadius, g_iMagnumShots);
    immolationIndex = GunXP_RPGShop_RegisterSkill("Immolation", "Immolation", sDescription,
    150000, 0);
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}
