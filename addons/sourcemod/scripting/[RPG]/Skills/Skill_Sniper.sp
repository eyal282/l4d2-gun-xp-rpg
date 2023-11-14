
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

ConVar hcv_IncapAccuracyPenalty;
ConVar hcv_IncapCameraShake;

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

    hcv_IncapAccuracyPenalty = FindConVar("survivor_incapacitated_accuracy_penalty");
    hcv_IncapCameraShake = FindConVar("survivor_incapacitated_dizzy_severity");

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
                if(SetupAimbotStrike(entity, winner))
                    return;
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
                if(SetupAimbotStrike(entity, winner))
                    return;
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
                if(SetupAimbotStrike(entity, winner))
                    return;
            }
        }
    }
}

public bool SetupAimbotStrike(int client, int victim)
{
    float fOrigin[3], fVictimOrigin[3];
    GetClientEyePosition(client, fOrigin);

    GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", fVictimOrigin);

    for(float i=0.0;i <= 64.0;i += 8.0)
    {
        fVictimOrigin[2] += 8.0;

        float fAngle[3];
  	    MakeVectorFromPoints(fOrigin, fVictimOrigin, fAngle);
    
    	GetVectorAngles(fAngle, fAngle);

        TR_TraceRayFilter(fOrigin, fAngle, MASK_SHOT, RayType_Infinite, TraceFilter_HitTarget, victim);

        float fTest[3];
        TR_GetEndPosition(fTest);

        //TE_SetupBeamPoints(fOrigin, fTest, PrecacheModel("materials/vgui/white_additive.vmt"), 0, 0, 0, 10.0, 10.0, 10.0, 0, 10.0, { 255, 0, 0, 255 }, 50);
        //TE_SendToAllInRange(fOrigin, RangeType_Audibility);

        if(TR_DidHit() && TR_GetEntityIndex() == victim)
        {
            int weapon = L4D_GetPlayerCurrentWeapon(client);

            RPG_Perks_TakeDamage(victim, client, weapon, 115.0, DMG_BULLET);
            return true;
        }
    }

    return false;
}

public bool TraceFilter_HitTarget(int entity, int contentsMask, int target)
{
    if (entity == target)
        return true;

    return false;
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

    char sValue[32];

    FloatToString(hcv_IncapAccuracyPenalty.FloatValue, sValue, sizeof(sValue));
    RPG_SendConVarValue(client, hcv_IncapAccuracyPenalty, sValue);

    FloatToString(hcv_IncapCameraShake.FloatValue, sValue, sizeof(sValue));
    RPG_SendConVarValue(client, hcv_IncapCameraShake, sValue);

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
    if(!IsWeaponSniperRifle(weapon))
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

public void GunXP_RPGShop_OnSkillBuy(int client, int skillIndex, bool bAutoRPG)
{
    if(skillIndex != sniperIndex)
        return;

    RPG_SendConVarValue(client, hcv_IncapAccuracyPenalty, "0.0");
    RPG_SendConVarValue(client, hcv_IncapCameraShake, "0.0");
}

public void RPG_Perks_OnPlayerSpawned(int priority, int client, bool bFirstSpawn)
{
    if(priority != 0)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, sniperIndex))
        return;

    RPG_SendConVarValue(client, hcv_IncapAccuracyPenalty, "0.0");
    RPG_SendConVarValue(client, hcv_IncapCameraShake, "0.0");
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
    FormatEx(sDescription, sizeof(sDescription), "All weapons have Laser Sight\nPerfect accuracy when incapped and camera won't shake.\nSniper Rifles do +100{PERCENT} damage to non-Tanks, shoot +100{PERCENT} faster, have infinite ammo.\nAWP and Scout have Aimbot.");

    sniperIndex = GunXP_RPGShop_RegisterSkill("Sniper", "Sniper", sDescription,
    200000, 0);
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

stock void RPG_SendConVarValue(int client, ConVar cvar, char[] sValue)
{
    if(IsFakeClient(client))
    {
        char sCvarName[256];
        cvar.GetName(sCvarName, sizeof(sCvarName));

        SetFakeClientConVar(client, sCvarName, sValue);
    }
    else
    {
        SendConVarValue(client, cvar, sValue);
    }
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