
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

int g_iHitsLeft[MAXPLAYERS+1];

int g_iHitsToTake = 5;

public Plugin myinfo =
{
    name        = "Retro Gamer Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Endgame Skill that makes you invincible for 5 hits after reaching 1 HP",
    version     = PLUGIN_VERSION,
    url         = ""
};

int retroGamerIndex;

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
    CreateTimer(0.5, Timer_MonitorRetrogamer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


public Action Timer_MonitorRetrogamer(Handle hTimer)
{
    for(int i=1;i <= MaxClients;i++)
    {
        if(!IsClientInGame(i))
            continue;

        else if(L4D_GetClientTeam(i) != L4DTeam_Survivor)
            continue;

        else if(!IsPlayerAlive(i))
            continue;

        float ratio = float(RPG_Perks_GetClientHealth(i)) / float(RPG_Perks_GetClientMaxHealth(i));

        if(RPG_Perks_GetClientHealth(i) > 100 && ratio >= 0.1)
        {
            g_iHitsLeft[i] = g_iHitsToTake;
        }
    }

    return Plugin_Continue;
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority == 10)
    {
        if(!IsPlayer(victim))
            return;

        else if(RoundFloat(damage) < RPG_Perks_GetClientHealth(victim) + RPG_Perks_GetClientTempHealth(victim))
            return;

        else if(g_iHitsLeft[victim] <= 0)
            return;

        else if(L4D_IsPlayerIncapacitated(victim))
            return;

        else if(!GunXP_RPGShop_IsSkillUnlocked(victim, retroGamerIndex))
            return;

        g_iHitsLeft[victim]--;

        damage = float(RPG_Perks_GetClientHealth(victim) + RPG_Perks_GetClientTempHealth(victim)) - 1.0;
    }
}
public void RegisterSkill()
{
    retroGamerIndex = GunXP_RPGShop_RegisterSkill("Retro Gamer", "Retro Gamer", "Your HP cannot drop below 1 for 5 hits\nAbility is refreshed when you heal above 100 or 10% HP, whichever is higher\nDoesn't work while you're incapped, and does not prevent instant kills",
    0, GunXP_RPG_GetXPForLevel(85));
}
