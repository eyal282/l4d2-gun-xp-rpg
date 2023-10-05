
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define SOUND_CHANNEL 7284

#define HYPERACTIVE_SOUND "*music/wam_music.mp3"

// How much times to play the sound?
#define HYPERACTIVE_SOUND_MULTIPLIER 100

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
float g_fMeleeDamagePerLevels = 0.05;
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


public void OnMapStart()
{
    TriggerTimer(CreateTimer(0.5, Timer_MonitorHyperactive, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT));

    PrecacheSound(HYPERACTIVE_SOUND);
}

public Action Timer_MonitorHyperactive(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        else if(!GunXP_RPGShop_IsSkillUnlocked(i, hyperactiveIndex))
            continue;

        else if(!RPG_Perks_IsEntityTimedAttribute(i, "Hyperactive") && !GetEntProp(i, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(i) <= 0.0)
        {
            if(RPG_Perks_IsEntityTimedAttribute(i, "Hyperactive Music"))
            {
                RPG_Perks_ApplyEntityTimedAttribute(i, "Hyperactive Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                StopHyperactiveSound(i);
            }

            continue;
        }

        if(!RPG_Perks_IsEntityTimedAttribute(i, "Hyperactive Music"))
        {
            RPG_Perks_ApplyEntityTimedAttribute(i, "Hyperactive Music", 30.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            EmitHyperactiveSound(i);
        }
    }

    return Plugin_Continue;
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

public void RPG_Perks_OnTimedAttributeExpired(int attributeEntity, char attributeName[64])
{
    if(StrEqual(attributeName, "Hyperactive Music"))
    {
        int client = attributeEntity;

        if(!RPG_Perks_IsEntityTimedAttribute(client, "Hyperactive") && !GetEntProp(client, Prop_Send, "m_bAdrenalineActive") && Terror_GetAdrenalineTime(client) <= 0.0)
            return;

        EmitHyperactiveSound(client);
        RPG_Perks_ApplyEntityTimedAttribute(client, "Hyperactive Music", 30.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
    }
    else if(StrEqual(attributeName, "Hyperactive"))
    {
        int client = attributeEntity;

        if(GetEntProp(client, Prop_Send, "m_bAdrenalineActive") || Terror_GetAdrenalineTime(client) > 0.0)
            return;

        if(RPG_Perks_IsEntityTimedAttribute(client, "Hyperactive Music"))
        {
            RPG_Perks_ApplyEntityTimedAttribute(client, "Hyperactive Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            StopHyperactiveSound(client);
        }
    }
}


public void RPG_Perks_OnTimedAttributeTransfered(int oldClient, int newClient, char attributeName[64])
{
    if(!StrEqual(attributeName, "Hyperactive Music"))
        return;

    // Infinite loop otherwise
    else if(oldClient == newClient)
        return;

    StopHyperactiveSound(oldClient);
    RPG_Perks_ApplyEntityTimedAttribute(newClient, "Hyperactive Music", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
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


stock void EmitHyperactiveSound(int client)
{
    for(int i=0;i < HYPERACTIVE_SOUND_MULTIPLIER;i++)
    {
        EmitSoundToClient(client, HYPERACTIVE_SOUND, _, SOUND_CHANNEL + i, 150, _, 1.0, 100);
    }
}

stock void StopHyperactiveSound(int client)
{
    for(int i=0;i < HYPERACTIVE_SOUND_MULTIPLIER;i++)
    {
        StopSound(client, SOUND_CHANNEL + i, HYPERACTIVE_SOUND);
    }
}