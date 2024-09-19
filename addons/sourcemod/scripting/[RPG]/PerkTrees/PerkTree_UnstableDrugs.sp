#include <GunXP-RPG>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public Plugin myinfo =
{
    name        = "Unstable Drugs Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to enter the Shadow Realm",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

int shadowRealmIndex = -1;

int g_iLastButtons[MAXPLAYERS+1];
float g_fNextExpireJump[MAXPLAYERS+1];
int g_iJumpCount[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

float g_fVisionRanges[] =
{
    8.0,
    200.0,
    450.0,
    768.0
};

int g_iShadowRealmCosts[] =
{
    32000,
    64000,
    128000,
    5000000
};


int g_iShadowRealmReqs[] =
{
    0,
    0,
    0,
    50000000
};


public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "GunXP_PerkTreeShop"))
    {
        RegisterPerkTree();
    }
}

public void OnConfigsExecuted()
{
    RegisterPerkTree();

}

public void OnPluginStart()
{
    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnGetShadowRealmVision(int client, float &fVision)
{
    int perkTree = GunXP_RPGShop_IsPerkTreeUnlocked(client, shadowRealmIndex);

    if(perkTree == -1)
        return;

    fVision += g_fVisionRanges[perkTree];
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    int lastButtons = g_iLastButtons[client];

    g_iLastButtons[client] = buttons;

    int buttonsCopy = buttons;

    if(HasPillsEquipped(client))
        buttons &= ~IN_RELOAD;

    if(g_bSpam[client] || L4D_GetPinnedInfected(client) != 0 || L4D_GetAttackerCarry(client) != 0)
        return Plugin_Continue;
        
    if(buttonsCopy & IN_RELOAD && !(lastButtons & IN_RELOAD) && g_fNextExpireJump[client] > GetGameTime())
    {
    
        g_fNextExpireJump[client] = GetGameTime() + 1.5;
        g_iJumpCount[client]++;

        if(g_iJumpCount[client] >= 3 && GunXP_RPGShop_IsPerkTreeUnlocked(client, shadowRealmIndex) != -1)
        {
            if(HasPillsEquipped(client))
            {
                int curWeapon = GetPlayerWeaponSlot(client, L4D_WEAPON_SLOT_PILLS);

                AcceptEntityInput(curWeapon, "Kill");

                float fDuration = 60.0;

                if(L4D2_IsTankInPlay())
                    fDuration = 20.0;
                    
                RPG_Perks_ApplyEntityTimedAttribute(client, "Shadow Realm", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);

                for(int i=1;i <= MaxClients;i++)
                {
                    if(!IsClientInGame(i))
                        continue;

                    else if(L4D_GetClientTeam(i) == L4D_GetClientTeam(client))
                        continue;

                    int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

                    if(owner != client)
                        continue;

                    RPG_Perks_ApplyEntityTimedAttribute(i, "Shadow Realm", fDuration, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                }
            }
            else if(HasPrimaryEquipped(client) && RPG_Perks_IsEntityTimedAttribute(client, "Shadow Realm"))
            {
                for(int i=1;i <= MaxClients;i++)
                {
                    if(!IsClientInGame(i))
                        continue;

                    else if(L4D_GetClientTeam(i) == L4D_GetClientTeam(client))
                        continue;

                    int owner = GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity");

                    if(owner != -1)
                        continue;

                    else if(!RPG_Perks_IsEntityTimedAttribute(i, "Shadow Realm"))
                        continue;

                    PrintToChat(client, "You must kill all Special Infected to leave!");
                    break;
                }

                RPG_Perks_ApplyEntityTimedAttribute(client, "Shadow Realm", 0.0, COLLISION_SET, ATTRIBUTE_NEUTRAL);
                PrintToChat(client, "You left the Shadow Realm!");
            }

            g_iJumpCount[client] = 0;
        }

        return Plugin_Continue;
    }

    if(g_fNextExpireJump[client] <= GetGameTime())
    {
        g_iJumpCount[client] = 0;
        g_fNextExpireJump[client] = GetGameTime() + 1.5;

        if(buttonsCopy & IN_RELOAD)
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

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fVisionRanges);i++)
    {
        char TempFormat[128];

        if(g_fVisionRanges[i] <= 8.0)
            FormatEx(TempFormat, sizeof(TempFormat), "You are blind in the Shadow Realm");
        else
            FormatEx(TempFormat, sizeof(TempFormat), "%.0f vision radius in Shadow Realm.", g_fVisionRanges[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iShadowRealmCosts[i]);
        xpReqs.Push(g_iShadowRealmReqs[i]);
    }

    shadowRealmIndex = GunXP_RPGShop_RegisterPerkTree("Shadow Realm Pills", "Unstable Drugs", descriptions, costs, xpReqs, _, _, "Triple click RELOAD with Pills to consume them and go to the Shadow Realm.\nTriple press RELOAD with a Primary Weapon to exit the Shadow Realm.\nLasts 20 sec, or 65 sec if a Tank is dead");

    UC_SilentCvar("l4d_gear_transfer_method", "1");
}

stock bool HasPillsEquipped(int client, int weapon = -1)
{
    if(weapon == -1)
    {
        weapon = L4D_GetPlayerCurrentWeapon(client);
    }

    char sClassname[64];
    GetEdictClassname(weapon, sClassname, sizeof(sClassname));

    if(StrEqual(sClassname, "weapon_pain_pills"))
    {
        return true;
    }

    return false;
}


stock bool HasPrimaryEquipped(int client, int weapon = -1)
{
    if(weapon == -1)
    {
        weapon = L4D_GetPlayerCurrentWeapon(client);
    }
    

    if(GetPlayerWeaponSlot(client, L4D_WEAPON_SLOT_PRIMARY) == weapon)
    {
        return true;
    }

    return false;
}