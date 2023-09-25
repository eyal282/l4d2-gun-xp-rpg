
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
    name        = "Hyperactive Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes using meds give you faster attack speed with melee.",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar g_hDamagePriority;

int hyperactiveIndex;
float g_fMeleeDamagePerLevels = 0.2;
int g_iMeleeDamageLevels = 2;
float g_fFireRate = 0.1;
float g_fDurationPerLevel = 1.0;

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
    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_hyperactive_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    HookEvent("adrenaline_used", Event_AdrenOrPillsUsed);
    HookEvent("pills_used", Event_AdrenOrPillsUsed);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier)
{
    if(!GunXP_RPGShop_IsSkillUnlocked(client, hyperactiveIndex))
        return;

    else if(!RPG_Perks_IsEntityTimedAttribute(client, "Hyperactive") && !GetEntProp(client, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(client) <= 0.0)
        return;

    speedmodifier += g_fFireRate;
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

    else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;
        
    else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        return;
    
    else if(!GunXP_RPGShop_IsSkillUnlocked(attacker, hyperactiveIndex))
        return;

    else if(!RPG_Perks_IsEntityTimedAttribute(attacker, "Hyperactive") && !GetEntProp(attacker, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(attacker) <= 0.0)
        return;

    damage += damage * (1.0 + (g_fMeleeDamagePerLevels * float(RoundToFloor(float(GunXP_RPG_GetClientLevel(attacker)) / float(g_iMeleeDamageLevels)))));
}

public Action Event_AdrenOrPillsUsed(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(client == 0)
        return Plugin_Continue;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, hyperactiveIndex))
        return Plugin_Continue;

    float fDuration = float(GunXP_RPG_GetClientLevel(client)) * g_fDurationPerLevel;

    RPG_Perks_ApplyEntityTimedAttribute(client, "Hyperactive", fDuration, COLLISION_ADD, ATTRIBUTE_POSITIVE);

    return Plugin_Continue;
}
public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Using Adrenaline or Pills gives you +%i{PERCENT} melee damage per %i levels.\nAlso always works while Adrenaline is active.\nIt also gives you +%i{PERCENT} weapon fire rate.\nThis lasts %.1f sec per level.", RoundFloat(g_fMeleeDamagePerLevels * 100.0), g_iMeleeDamageLevels, RoundFloat(g_fFireRate * 100.0), g_fDurationPerLevel);

    hyperactiveIndex = GunXP_RPGShop_RegisterSkill("Hyperactive", "Hyperactive", sDescription,
    50000, 100000);
}

