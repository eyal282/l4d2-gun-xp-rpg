
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
    name        = "Cryo Protection Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Activatable Skill that freezes you for 12 seconds, giving you invincibility for more.",
    version     = PLUGIN_VERSION,
    url         = ""
};

int skillIndex;

int g_iLastImpulse[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

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

public void OnAllPluginsLoaded()
{
    ConVar cvar = FindConVar("l4d2_points_survivor_flashlight_alias");

    if(cvar != null)
        cvar.SetString("");
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Cryo Protection", false))
        return;

    else if(priority != 1)
        return;

    if(!GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
    {
        maxUses = 0;

        return;
    }

    maxUses++;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastImpulse = g_iLastImpulse[client];

    g_iLastImpulse[client] = impulse;

    if(g_bSpam[client] || L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0 || L4D_IsPlayerIncapacitated(client))
        return Plugin_Continue;

    if(impulse == 100 && lastImpulse != 100 && g_fNextExpireJump[client] > GetGameTime())
    {
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, skillIndex))
        {
            
            g_iJumpCount[client] = 0;

            g_bSpam[client] = true;
            
            CreateTimer(1.0, Timer_SpamOff, client);

            if(RPG_Perks_IsEntityTimedAttribute(client, "Frozen") && RPG_Perks_IsEntityTimedAttribute(client, "Invincible"))
            {
                PrintToChat(client, "You have unfrozen yourself.");
                RPG_Perks_ApplyEntityTimedAttribute(client, "Frozen", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
            }
            else
            {
                bool success = RPG_Perks_UseClientLimitedAbility(client, "Cryo Protection");

                if(success)
                {
                    int timesUsed, maxUses;

                    RPG_Perks_GetClientLimitedAbility(client, "Cryo Protection", timesUsed, maxUses);

                    PrintToChat(client, "Cryo Protection is active (%i/%i)", timesUsed, maxUses);

                    float fDuration = 12.0;

                    RPG_Perks_ApplyEntityTimedAttribute(client, "Frozen", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                    RPG_Perks_ApplyEntityTimedAttribute(client, "Invincible", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                }
            }
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(impulse == 100)
        {
            g_iJumpCount[client]++;
        }
    }

    return Plugin_Continue;
}

public Action Timer_SpamOff(Handle Timer, int client)
{
    g_bSpam[client] = false;

    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "Once per Round: Triple press FLASHLIGHT to become frozen and invincible for 12 sec\nUse this skill again to unfreeze & lose invincibility");

    skillIndex = GunXP_RPGShop_RegisterSkill("Cryo Protection", "Cryo Protection", sDescription,
    1500000, 0);
}


