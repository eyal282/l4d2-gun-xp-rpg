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
    name        = "Marksman Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to multiply ranged weapon damage.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

ConVar g_hDamagePriority;

int marksmanIndex = -1;

float g_fMarksmanDamageIncrease[] =
{
    0.4,
    0.8,
    1.2,
    2.0,
    2.8,
    3.6,
    4.2,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
    11.0,
    12.0,
    13.0,
    14.0,
    15.0,
    16.0,
    17.0,
    18.0,
    19.0,
    20.0,
    21.0,
    23.0,
    25.0
};

int g_iMarksmanCosts[] =
{
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,
    1500,
    1600,
    1700,
    1800,
    1900,
    2000,
    2500,
    3000,
    3500,
    4000,
    4500,
    5000
};


int g_iMarksmanReqs[] =
{
    0,
    0,
    500,
    1000,
    2000,
    3000,
    4000,
    5000,
    6000,
    8000,
    10000,
    15000,
    25000,
    35000,
    50000,
    75000,
    100000,
    150000,
    200000,
    250000,
    1000000,
    2000000,
    3000000,
    4000000,
    5000000,
    10000000
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
    AutoExecConfig_SetFile("GunXP-RPGShop.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_marksman_damage_priority", "0", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();

    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(IsPlayer(victim) && IsPlayer(attacker) && L4D_GetClientTeam(victim) == L4D_GetClientTeam(attacker))
        return;

    else if(!IsPlayer(attacker) || L4D_GetClientTeam(attacker) != L4DTeam_Survivor)
        return;
        
    else if(L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Melee || L4D2_GetWeaponId(inflictor) == L4D2WeaponId_Chainsaw)
        return;
    
    char sClassname[64];
    GetEdictClassname(inflictor, sClassname, sizeof(sClassname));

    if(StrEqual(sClassname, "entityflame") || StrEqual(sClassname, "inferno"))
        return;
        
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, marksmanIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    damage += damage * g_fMarksmanDamageIncrease[perkLevel];
}
public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fMarksmanDamageIncrease);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "+%i{PERCENT} damage for all guns, including RPG.", RoundFloat(g_fMarksmanDamageIncrease[i] * 100.0));

        descriptions.PushString(TempFormat);
        costs.Push(g_iMarksmanCosts[i]);
        xpReqs.Push(g_iMarksmanReqs[i]);
    }

    marksmanIndex = GunXP_RPGShop_RegisterPerkTree("Gun damage multiplier", "Marksman", descriptions, costs, xpReqs);
}
