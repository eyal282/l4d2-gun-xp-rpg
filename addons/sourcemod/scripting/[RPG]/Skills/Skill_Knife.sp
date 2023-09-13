
#include <GunXP-RPG>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];

public Plugin myinfo =
{
    name        = "Knife Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that a knife to free from Special Infected.",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar hcv_Difficulty;

int knifeIndex;

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

public void OnMapStart()
{
    for(int i=0;i < sizeof(g_fNextExpireJump);i++)
    {
        g_fNextExpireJump[i] = 0.0;

        g_iJumpCount[i] = 0;
    }
}
public void OnPluginStart()
{
    hcv_Difficulty = FindConVar("z_difficulty");
    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Knife", false))
        return;

    else if(priority != 0)
        return;

    maxUses++;

    char sDifficulty[16];
    hcv_Difficulty.GetString(sDifficulty, sizeof(sDifficulty));

    if(StrEqual(sDifficulty, "Hard", false))
    {
        maxUses++;
    }
    else if(StrEqual(sDifficulty, "Normal", false))
    {
        maxUses += 2;
    }
    else if(StrEqual(sDifficulty, "Easy", false))
    {
        maxUses += 3;
    }
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;

    if(g_bSpam[client] || L4D_GetPinnedInfected(client) == 0 || L4D_GetAttackerCarry(client) != 0)
        return Plugin_Continue;

    if(buttons & IN_JUMP && !(lastButtons & IN_JUMP) && g_fNextExpireJump[client] > GetGameTime())
    {
    
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsSkillUnlocked(client, knifeIndex))
        {
            bool success = RPG_Perks_UseClientLimitedAbility(client, "Knife");

            if(success)
            {
                int timesUsed, maxUses;

                RPG_Perks_GetClientLimitedAbility(client, "Knife", timesUsed, maxUses);

                PrintToChat(client, "Successfully used the Knife (%i/%i)", timesUsed, maxUses);

                g_iJumpCount[client] = 0;

                g_bSpam[client] = true;
            
                CreateTimer(1.0, Timer_SpamOff, client);

                int pinner = L4D_GetPinnedInfected(client);

                ClientCommand(client, "weapons/knife/knife_deploy.wav");

                if(RPG_Perks_GetZombieType(pinner) == ZombieType_Smoker)
                {
                    float fOrigin[3], fSmokerOrigin[3];

                    GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", fOrigin);
                    GetEntPropVector(pinner, Prop_Data, "m_vecAbsOrigin", fSmokerOrigin);

                    L4D_Smoker_ReleaseVictim(client, pinner);

                    if(GetVectorDistance(fOrigin, fSmokerOrigin) <= 128.0)
                    {
                        RPG_Perks_TakeDamage(pinner, client, client, 10000.0, DMG_SLASH);
                    }
                }
                else
                {
                    RPG_Perks_TakeDamage(pinner, client, client, 10000.0, DMG_SLASH);
                }
            }
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(buttons & IN_JUMP)
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
    knifeIndex = GunXP_RPGShop_RegisterSkill("Knife", "Knife", "Triple click +JUMP to instantly kill a Special Infected that pins you.\nYou only get 1 knife per round.\nYou get 1 extra knife per difficulty under Expert.",
    1000, 0);
}

