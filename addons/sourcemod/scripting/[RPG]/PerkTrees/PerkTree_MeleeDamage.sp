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
    name        = "Melee Damage Perk Tree --> Gun XP RPG",
    author      = "Eyal282",
    description = "Perk tree to increase base melee damage",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

ConVar g_hDamagePriority;
ConVar g_hTankDamageMultiplier;

int meleeDamageIndex = -1;

int g_iMeleeDamages[] =
{
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800
};

int g_iMeleeCosts[] =
{
    0,
    200,
    400,
    600,
    800,
    1000,
    1200,
    1400
};


int g_iMeleeReqs[] =
{
    0,
    0,
    1500,
    6000,
    10000,
    17500,
    30000,
    50000,
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
    AutoExecConfig_SetFile("GunXP-MeleeDamagePerkTree.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_melee_damage_priority", "-2", "Don't be shy to account for this cvar when setting your priority.\nDo not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");
    g_hTankDamageMultiplier = AutoExecConfig_CreateConVar("gun_xp_rpgshop_melee_damage_tank_multiplier", "1.5", "Melee damage multiplier for tanks");

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

    else if(L4D2_GetWeaponId(inflictor) != L4D2WeaponId_Melee)
        return;

    
    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(attacker, meleeDamageIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    damage = float(g_iMeleeDamages[perkLevel]);

    if(RPG_Perks_GetZombieType(victim) == ZombieType_Tank)
    {
        damage *= g_hTankDamageMultiplier.FloatValue;
    }
    // Tanks are immune to HS damage.
    else if(hitgroup == 1)
        damage *= 4;

    bDontInstakill = true;
}
public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_iMeleeDamages);i++)
    {
        char TempFormat[128];

        if(g_hTankDamageMultiplier.FloatValue == 1.0)
            FormatEx(TempFormat, sizeof(TempFormat), "Base damage of melee becomes %i", g_iMeleeDamages[i]);

        else
            FormatEx(TempFormat, sizeof(TempFormat), "Base damage of melee becomes %i, but tanks take %.1fx damage", g_iMeleeDamages[i], g_hTankDamageMultiplier.FloatValue);

        descriptions.PushString(TempFormat);
        costs.Push(g_iMeleeCosts[i]);
        xpReqs.Push(g_iMeleeReqs[i]);
    }

    meleeDamageIndex = GunXP_RPGShop_RegisterPerkTree("Base Melee Damage", "Melee Damage", descriptions, costs, xpReqs);
}
