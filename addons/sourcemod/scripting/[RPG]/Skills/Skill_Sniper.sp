
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

ConVar g_hDamagePriority;

int g_iTargetsHit[MAXPLAYERS+1];

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
    HookEvent("bullet_impact", Event_BulletImpact, EventHookMode_Post);
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

    AutoExecConfig_SetFile("GunXP-SniperSkill.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_sniper_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(StrEqual(attributeName, "Aimbot Check Miss"))
    {
        if(g_iTargetsHit[entity] == 0)
        {
            float fOrigin[3];
            GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fOrigin);

            int winner = 0;
            float fWinnerDist;

            for(int i=1;i <= MaxClients;i++)
            {
                if(!IsClientInGame(i))
                    continue;

                else if(L4D_GetClientTeam(i) != L4DTeam_Infected)
                    continue;

                else if(RPG_Perks_GetZombieType(i) == ZombieType_Tank)
                    continue;
                
                int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

                if(IsPlayer(owner) && L4D_GetClientTeam(owner) == L4DTeam_Survivor)
                    continue;

                float fTargetOrigin[3];
                GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

                float fDist = GetVectorDistance(fOrigin, fTargetOrigin);

                if(winner == 0 || fDist < fWinnerDist)
                {
                    winner = i;
                    fWinnerDist = fDist;
                }
            }

            if(winner != 0)
            {
                if(GunXP_SetupAimbotStrike(entity, winner, AimbotLevel_Two))
                {
                    int weapon = L4D_GetPlayerCurrentWeapon(entity);

                    RPG_Perks_TakeDamage(winner, entity, weapon, 115.0, DMG_BULLET);

                    return;
                }
            }

            winner = 0;
            int witch = -1;

            while((witch = FindEntityByClassname(witch, "witch")) != -1)
            {
                float fTargetOrigin[3];
                GetEntPropVector(witch, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

                float fDist = GetVectorDistance(fOrigin, fTargetOrigin);

                if(winner == 0 || fDist < fWinnerDist)
                {
                    winner = witch;
                    fWinnerDist = fDist;
                }
            }

            if(winner != 0)
            {
                if(GunXP_SetupAimbotStrike(entity, winner, AimbotLevel_Two))
                {
                    int weapon = L4D_GetPlayerCurrentWeapon(entity);

                    RPG_Perks_TakeDamage(winner, entity, weapon, 115.0, DMG_BULLET);
                    
                    return;
                }
            }

            winner = 0;
            int infected = -1;

            while((infected = FindEntityByClassname(infected, "infected")) != -1)
            {
                float fTargetOrigin[3];
                GetEntPropVector(infected, Prop_Data, "m_vecAbsOrigin", fTargetOrigin);

                float fDist = GetVectorDistance(fOrigin, fTargetOrigin);

                if(winner == 0 || fDist < fWinnerDist)
                {
                    winner = infected;
                    fWinnerDist = fDist;
                }
            }

            if(winner != 0)
            {
                if(GunXP_SetupAimbotStrike(entity, winner, AimbotLevel_Two))
                {
                    int weapon = L4D_GetPlayerCurrentWeapon(entity);

                    RPG_Perks_TakeDamage(winner, entity, weapon, 115.0, DMG_BULLET);
                    
                    return;
                }
            }
        }
    }
}

public Action Event_BulletImpact(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if(weapon == -1)
        return Plugin_Continue;

    else if(!IsWeaponBadSniperRifle(weapon))
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return Plugin_Continue;

    // This breaks if a weapon can fire faster than 0.1 sec. Good thing we're working with bolt action snipers...
    RPG_Perks_ApplyEntityTimedAttribute(client, "Aimbot Check Miss", 0.1, COLLISION_SET, ATTRIBUTE_NEUTRAL);
    return Plugin_Continue;
}

public Action Event_WeaponFire(Handle hEvent, char[] Name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    if(weapon == -1)
        return Plugin_Continue;

    else if(!IsWeaponSniperRifle(weapon))
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return Plugin_Continue;

    SetEntProp(weapon, Prop_Send, "m_iClip1", 16);

    g_iTargetsHit[client] = 0;

    return Plugin_Continue;
}

public void GunXP_RPGShop_OnResetRPG(int client)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    int weapon = GetPlayerWeaponSlot(client, view_as<int>(L4DWeaponSlot_Primary));

    if(weapon != -1)
    {
        if(L4D2_IsWeaponUpgradeCompatible(weapon))
        {
            if(L4D2_GetWeaponUpgrades(weapon) & L4D2_WEPUPGFLAG_LASER)
            {
                RemoveClientWeaponUpgrade(client, 2);
            }
        }
    }
}


public void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier)
{
    if(!IsWeaponBadSniperRifle(weapon))
        return;
    
    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    speedmodifier += 1.0;
}


public void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier)
{
    if(!IsWeaponSniperRifle(weapon))
        return;
    
    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    speedmodifier += 10.0;
}

// Requires RPG_Perks_RegisterReplicateCvar to fire.
public void RPG_Perks_OnGetReplicateCvarValue(int priority, int client, const char cvarName[64], char sValue[256])
{
    if(priority != 0)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    else if(!StrEqual(cvarName, "survivor_incapacitated_dizzy_severity", false) && !StrEqual(cvarName, "survivor_incapacitated_accuracy_penalty"))
        return;

    sValue = "0.0";
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == -10)
    {
        if(IsPlayer(attacker) && RPG_Perks_GetZombieType(victim) != ZombieType_Invalid && RPG_Perks_GetZombieType(victim) != ZombieType_NotInfected)
        {
            g_iTargetsHit[attacker]++;
        }
    }
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

    else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;

    int weapon = L4D_GetPlayerCurrentWeapon(attacker);

    if(weapon == -1)
        return;
        
    else if(!IsWeaponSniperRifle(weapon))
        return;
        
    else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, sniperIndex))
        return;

    else if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
        return;

    damage *= 2.0;
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
    FormatEx(sDescription, sizeof(sDescription), "All weapons have Laser Sight\nPerfect accuracy when incapped and camera won't shake.\nSniper Rifles do +100{PERCENT} damage to non-Tanks, have infinite ammo.\nAWP and Scout shoot +100{PERCENT} faster, have Aimbot\nAimbot doesn't locate tanks.");

    sniperIndex = GunXP_RPGShop_RegisterSkill("Sniper", "Sniper", sDescription,
    260000, 0);

    if(LibraryExists("RPG_Perks"))
    {
        RPG_Perks_RegisterReplicateCvar("survivor_incapacitated_accuracy_penalty");
        RPG_Perks_RegisterReplicateCvar("survivor_incapacitated_dizzy_severity");
    }
}

stock void GiveClientWeaponUpgrade(int client, int upgrade)
{
    char code[256];

    FormatEx(code, sizeof(code), "GetPlayerFromUserID(%d).GiveUpgrade(%i);", GetClientUserId(client), upgrade);
    L4D2_ExecVScriptCode(code);
}

stock void RemoveClientWeaponUpgrade(int client, int upgrade)
{
    char code[256];

    FormatEx(code, sizeof(code), "GetPlayerFromUserID(%d).RemoveUpgrade(%i);", GetClientUserId(client), upgrade);
    L4D2_ExecVScriptCode(code);
}

stock bool IsWeaponSniperRifle(int weapon)
{
    if(L4D2_GetWeaponId(weapon) == L4D2WeaponId_SniperAWP || L4D2_GetWeaponId(weapon) == L4D2WeaponId_SniperScout || L4D2_GetWeaponId(weapon) == L4D2WeaponId_SniperMilitary || L4D2_GetWeaponId(weapon) == L4D2WeaponId_HuntingRifle)
        return true;

    return false;
}

stock bool IsWeaponBadSniperRifle(int weapon)
{
    if(L4D2_GetWeaponId(weapon) == L4D2WeaponId_SniperAWP || L4D2_GetWeaponId(weapon) == L4D2WeaponId_SniperScout)
        return true;

    return false;
}

stock void GetAngleBetweenVectors(float vec1[3], float vec2[3], float result[3])
{
    float Result2[3];
    SubtractVectors(vec1, vec2, result);	
    NormalizeVector(result, result);
    GetVectorAngles(result, Result2); 
    
    result = Result2;
}