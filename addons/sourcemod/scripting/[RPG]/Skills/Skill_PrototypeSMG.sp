
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define EXPLOSION_DELAY 0.2

#define MODEL_EXPLOSIVE		"models/props_junk/propanecanister001a.mdl"

public Plugin myinfo =
{
    name        = "Prototype SMG Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes SMG have a grenade launcher",
    version     = PLUGIN_VERSION,
    url         = ""
};

int skillIndex;
int g_explosionSprite;

float g_fRadius = 512.0;
#define DAMAGE_MINI_EXPLOSION 150.0

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
    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

int g_iLastButtons[MAXPLAYERS+1];


public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(StrEqual(attributeName, "Prototype SMG Cooldown") && IsPlayer(entity))
    {
        ClientCommand(entity, "#ui/helpful_event_1.wav");
    }
    if(StrEqual(attributeName, "Prototype Explode"))
    {
        RPG_Perks_ApplyEntityTimedAttribute(entity, "Prototype Explode", EXPLOSION_DELAY, COLLISION_SET, ATTRIBUTE_NEUTRAL);

        float fOrigin[3];
        GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

        TE_SetupExplosion(fOrigin, g_explosionSprite, 2.0, 1, 0, 20, 40, {0.0, 0.0, 1.0});
        TE_SendToAll();

        InflictExplosionDamage(entity, fOrigin);
    }
}

public Action SDKEvent_NeverTransmit(int victim, int viewer)
{
    return Plugin_Handled;
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

        else if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
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
        
        int prj = L4D2_GrenadeLauncherPrj(client, fEyePos, fEyeAngles, fVel);

        SetEntityGravity(prj, 0.000000001);

        TeleportEntity(prj, NULL_VECTOR, NULL_VECTOR, fVel);

        RPG_Perks_ApplyEntityTimedAttribute(prj, "Prototype Explode", EXPLOSION_DELAY, COLLISION_SET, ATTRIBUTE_NEUTRAL);

        RPG_Perks_ApplyEntityTimedAttribute(client, "Prototype SMG Cooldown", 60.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);

        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Press ZOOM to fire a slow high explosive shot that explodes every %.1f sec when travelling in the air.\nMini explosion radius is %i units, only hit Tanks that take Bullet damage, and ignores Explosion immunity.\n60 sec cooldown", EXPLOSION_DELAY, RoundToFloor(g_fRadius));
    skillIndex = GunXP_RPGShop_RegisterSkill("Prototype SMG", "Prototype SMG", sDescription,
    1000, 0);
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
            RPG_Perks_TakeDamage(i, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);

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
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);
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
            RPG_Perks_TakeDamage(iEntity, client, iFakeWeapon, DAMAGE_MINI_EXPLOSION, DMG_BULLET);
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
}