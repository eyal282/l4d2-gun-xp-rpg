
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
    HookEvent("hegrenade_detonate", Event_MolotovDetonate);

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

public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Immolation"))
        return;

    else if(oldClient == newClient)
        return;

    if(g_hTimer[oldClient] != INVALID_HANDLE)
    {
        CloseHandle(g_hTimer[oldClient]);
        g_hTimer[oldClient] = INVALID_HANDLE;
    }
    
    g_hTimer[newClient] = CreateTimer(1.0, Timer_CastImmolation, GetClientUserId(newClient), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}
public Action Event_MolotovDetonate(Handle hEvent, const char[] Name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    float fDetonationOrigin[3];

    fDetonationOrigin[0] = GetEventFloat(hEvent, "x");
    fDetonationOrigin[1] = GetEventFloat(hEvent, "y");
    fDetonationOrigin[2] = GetEventFloat(hEvent, "z");

    float fOrigin[3];

    GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);

    if(!GunXP_RPGShop_IsSkillUnlocked(client, immolationIndex))
        return Plugin_Continue;

    if(GetVectorDistance(fOrigin, fDetonationOrigin) < 128.0)
    {
        float fDuration = g_fDurationPerLevel * float(GunXP_RPG_GetClientLevel(client));

        PrintToChat(client, "Immolation is active for %.1f seconds.", fDuration);

        RPG_Perks_ApplyEntityTimedAttribute(client, "Immolation", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

        if(g_hTimer[client] != INVALID_HANDLE)
        {
            CloseHandle(g_hTimer[client]);
            g_hTimer[client] = INVALID_HANDLE;
        }

        g_hTimer[client] = CreateTimer(1.0, Timer_CastImmolation, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    }

    return Plugin_Continue;
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
            RPG_Perks_TakeDamage(i, client, iFakeWeapon, 80.0, DMG_BULLET);

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
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, 80.0, DMG_BULLET);
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
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, 80.0, DMG_BULLET);
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
	FormatEx(sDescription, sizeof(sDescription), "Throwing a molotov on yourself ignites you, igniting all Zombies around.\nDuration is half your level, and stacks.\nRadius of damaging is %.0f units\nEvery second while active, zombies take damage equal to 1 magnum shot\nThis ignores burn immunity, treated as bullet damage instead.", g_fRadius);
   	immolationIndex = GunXP_RPGShop_RegisterSkill("Immolation", "Immolation", sDescription,
	150000, 0);
}


