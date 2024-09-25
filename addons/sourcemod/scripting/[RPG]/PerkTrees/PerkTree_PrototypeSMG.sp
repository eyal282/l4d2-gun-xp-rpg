
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define MODEL_EXPLOSIVE		"models/props_junk/propanecanister001a.mdl"

public Plugin myinfo =
{
    name        = "Prototype SMG Perk Tree --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Perk Tree that makes SMG have a grenade launcher",
    version     = PLUGIN_VERSION,
    url         = ""
};

int prototypeIndex;
int g_explosionSprite;
int g_iProjectile[4096];
bool g_bGlobalProjectile;
float g_fVelocity[4096][3];

int g_iPrototypeCooldown[] =
{
    100,
    90,
    80,
    70,
    60,
    40
};

float g_fPrototypeExplodeDelay[] =
{
    1.0,
    0.8,
    0.7,
    0.6,
    0.5,
    0.2
};


int g_iPrototypeCosts[] =
{
    499,
    1500,
    2500,
    5500,
    10000,
    15000
};

int g_iPrototypeReqLevels[] =
{
    15,
    18,
    21,
    24,
    27,
    30
};

float g_fRadius = 512.0;
#define DAMAGE_MINI_EXPLOSION 150.0

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_SkillShop"))
    {
        RegisterPerkTree();
    }
}

public void OnConfigsExecuted()
{
    RegisterPerkTree();

}

public void OnMapStart()
{
    g_explosionSprite = PrecacheModel("sprites/blueglow2.vmt");

    CreateTimer(1.0, Timer_CooldownTicksWhenEquipped, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_CooldownTicksWhenEquipped(Handle hTimer)
{
    for(int i=1;i<=MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        int activeWeapon = L4D_GetPlayerCurrentWeapon(i);

        if(activeWeapon == -1)
            continue;

        char sClassname[64];
        GetEdictClassname(activeWeapon, sClassname, sizeof(sClassname));

        WeaponType type = L4D2_GetIntWeaponAttribute(sClassname, L4D2IWA_WeaponType);

        if(type == WEAPONTYPE_SMG)
            continue;

        float fDelay;
        RPG_Perks_IsEntityTimedAttribute(i, "Prototype SMG Cooldown", fDelay);

        if(fDelay > 0.0)
        {
            RPG_Perks_ApplyEntityTimedAttribute(i, "Prototype SMG Cooldown", 1.0, COLLISION_ADD, ATTRIBUTE_NEUTRAL);
        }
    }

    return Plugin_Continue;
}
public void OnPluginStart()
{
    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

int g_iLastButtons[MAXPLAYERS+1];


public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(GunXP_RPGShop_IsPerkTreeUnlocked(client, prototypeIndex) > PERK_TREE_NOT_UNLOCKED)
    {
        // Set max legal cooldown.
        RPG_Perks_ApplyEntityTimedAttribute(client, "Prototype SMG Cooldown", float(g_iPrototypeCooldown[0]), COLLISION_SET, ATTRIBUTE_NEUTRAL);
    }
}
public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(StrEqual(attributeName, "Prototype SMG Cooldown") && IsPlayer(entity))
    {
        ClientCommand(entity, "#ui/helpful_event_1.wav");
    }
    if(StrEqual(attributeName, "Prototype Explode"))
    {
        int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

        int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, prototypeIndex);

        if(perkLevel == PERK_TREE_NOT_UNLOCKED)
            return;

        float fVelocity[3];
        GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", fVelocity);

        if(GetVectorLength(fVelocity) / GetVectorLength(g_fVelocity[entity]) <= 0.5)
        {
            g_iProjectile[entity] -= RoundToCeil(g_fPrototypeExplodeDelay[perkLevel] / g_fPrototypeExplodeDelay[sizeof(g_fPrototypeExplodeDelay)-1]);

            if(g_iProjectile[entity] <= 0)
            {
                L4D_DetonateProjectile(entity);

                g_iProjectile[entity] = 0;
            }
        }

        TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, g_fVelocity[entity]);

        RPG_Perks_ApplyEntityTimedAttribute(entity, "Prototype Explode", g_fPrototypeExplodeDelay[perkLevel], COLLISION_SET, ATTRIBUTE_NEUTRAL);

        float fOrigin[3];
        GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

        TE_SetupExplosion(fOrigin, g_explosionSprite, 2.0, 1, 0, 20, 40, {0.0, 0.0, 1.0});

        int clientsNormal[MAXPLAYERS+1], clientsShadow[MAXPLAYERS+1];
        int numClientsNormal, numClientsShadow;

        RPG_Perks_GetClientsInRealms(clientsNormal, numClientsNormal, clientsShadow, numClientsShadow);

        int clients[MAXPLAYERS+1];
        int numClients;

        if(RPG_Perks_IsEntityTimedAttribute(entity, "Shadow Realm"))
        {
            for(int i=0;i < numClientsShadow;i++)
            {
                if(!IsClientInGame(clientsShadow[i]))
                    continue;

                clients[numClients++] = clientsShadow[i];
            }
        }
        else
        {
            for(int i=0;i < numClientsNormal;i++)
            {
                if(!IsClientInGame(clientsNormal[i]))
                    continue;

                clients[numClients++] = clientsNormal[i];
            }
        }

        TE_Send(clients, numClients);

        InflictExplosionDamage(entity, fOrigin);
    }
}

public Action SDKEvent_NeverTransmit(int victim, int viewer)
{
    return Plugin_Handled;
}

public Action L4D2_GrenadeLauncher_Detonate(int entity, int client)
{
    if(g_iProjectile[entity] || g_bGlobalProjectile)
        return Plugin_Handled;

    return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!IsValidEntityIndex(entity))
		return;

	if(!StrEqual(classname, "grenade_launcher_projectile"))
    {
        g_iProjectile[entity] = 0;
    }
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0)
        return Plugin_Continue;

    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;

    if(buttons & IN_ZOOM && !(lastButtons & IN_ZOOM))
    {
        int activeWeapon = L4D_GetPlayerCurrentWeapon(client);

        if(activeWeapon == -1)
            return Plugin_Continue;

        int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, prototypeIndex);

        if(perkLevel == PERK_TREE_NOT_UNLOCKED)
            return Plugin_Continue;

        char sClassname[64];
        GetEdictClassname(activeWeapon, sClassname, sizeof(sClassname));

        WeaponType type = L4D2_GetIntWeaponAttribute(sClassname, L4D2IWA_WeaponType);

        if(type != WEAPONTYPE_SMG)
            return Plugin_Continue;

        float fDelay;
        RPG_Perks_IsEntityTimedAttribute(client, "Prototype SMG Cooldown", fDelay);

        if(fDelay > 0.0)
        {
            UC_PrintToChat(client, "Prototype SMG cooldown expires in %i sec, and only while equipped", RoundToFloor(fDelay));
            return Plugin_Continue;
        }
        float fEyePos[3], fEyeAngles[3], fVel[3];
        GetClientEyePosition(client, fEyePos);
        GetClientEyeAngles(client, fEyeAngles);
        VelocityByAim(client, 256.0, fVel);

        g_bGlobalProjectile = true;

        int prj = L4D2_GrenadeLauncherPrj(client, fEyePos, fEyeAngles, fVel);

        g_iProjectile[prj] = 4;

        g_bGlobalProjectile = false;

        SetEntityGravity(prj, 0.000000001);

        TeleportEntity(prj, NULL_VECTOR, NULL_VECTOR, fVel);

        g_fVelocity[prj] = fVel;

        RPG_Perks_ApplyEntityTimedAttribute(prj, "Prototype Explode", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);

        RPG_Perks_ApplyEntityTimedAttribute(client, "Prototype SMG Cooldown", float(g_iPrototypeCooldown[perkLevel]), COLLISION_SET, ATTRIBUTE_NEUTRAL);

        SetEntPropString(prj, Prop_Data, "m_iName", "RPG Prototype Projectile");
        fDelay = 0.0;

        RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm", fDelay);

        if(fDelay > 0.0)
        {
            RPG_Perks_ApplyEntityTimedAttribute(prj, "Shadow Realm", fDelay, COLLISION_SET, ATTRIBUTE_NEUTRAL);
        }

        SDKHook(prj, SDKHook_TouchPost, SDKEvent_ProjectileTouch);

        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public void SDKEvent_ProjectileTouch(int projectile, int other)
{
    if(other == 0)
    {
        g_iProjectile[projectile] = 0;

        L4D_DetonateProjectile(projectile);
        return;
    }

    float fVelocity[3];
    GetEntPropVector(projectile, Prop_Data, "m_vecAbsVelocity", fVelocity);

    if(GetVectorLength(fVelocity) <= 64.0)
    {
        L4D_DetonateProjectile(projectile);

        g_iProjectile[projectile] = 0;

        return;
    }
}
public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iPrototypeCosts);i++)
    {
        char TempFormat[128];
        FormatEx(TempFormat, sizeof(TempFormat), "Explodes every %.1f sec, CD %i sec", g_fPrototypeExplodeDelay[i], g_iPrototypeCooldown[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iPrototypeCosts[i]);
        xpReqs.Push(GunXP_RPG_GetXPForLevel(g_iPrototypeReqLevels[i]));
    }
    

    char sDescription[256];
    FormatEx(sDescription, sizeof(sDescription), "Press ZOOM to shoot recursively exploding projectile. Radius %i units\nDeals damage of 2 Magnum shots, boosted by Marksman.", RoundToFloor(g_fRadius));

    prototypeIndex = GunXP_RPGShop_RegisterPerkTree("Prototype SMG", "Prototype SMG", descriptions, costs, xpReqs, _, _, sDescription);
}

stock void VelocityByAim(int client, float fSpeed, float fVec[3])
{
    float eyeOrigin[3], eyeAngles[3], vecFwd[3];

    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeAngles);

    GetAngleVectors(eyeAngles, vecFwd, NULL_VECTOR, NULL_VECTOR);

    NormalizeVector(vecFwd, vecFwd);
    ScaleVector(vecFwd, fSpeed);

    fVec = vecFwd;
}


public void InflictExplosionDamage(int entity, float fOrigin[3])
{
    int iFakeWeapon = CreateEntityByName("weapon_pistol_magnum");

    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

    int siRealm[MAXPLAYERS+1], numSIRealm;
    int ciRealm[MAXPLAYERS+1], numCIRealm;
    int witchRealm[MAXPLAYERS+1], numWitchRealm;

    /*RPG_Perks_GetZombiesInRealms(
        siNormal, numSINormal, siShadow, numSIShadow,
        ciNormal, numCINormal, ciShadow, numCIShadow,
        witchNormal, numWitchNormal, witchShadow, numWitchShadow);*/




    if(RPG_Perks_IsEntityTimedAttribute(entity, "Shadow Realm"))
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
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);

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
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);

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
            RPG_Perks_TakeDamage(victim, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);

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

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}