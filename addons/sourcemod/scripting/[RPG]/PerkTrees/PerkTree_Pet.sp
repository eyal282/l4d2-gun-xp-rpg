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
    description = "Perk tree to LET'S FUCKING GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO.",
    version     = PLUGIN_VERSION,
    url         = ""
};

#define MIN_FLOAT -2147483647.0

ConVar g_hDamagePriority;

int petIndex = -1;

float g_fPetDamages[] =
{
    400.0,
    1500.0,
    3500.0,
    7000.0,
    11000.0,
    17000.0,
    25000.0,
    45000.0,

};

int g_iPetCosts[] =
{
    50000,
    100000,
    200000,
    400000,
    800000,
    1600000,
    3200000,
    6400000
};


int g_iPetReqs[] =
{
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
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
    AutoExecConfig_SetFile("GunXP-PetPerkTree.cfg");

    g_hDamagePriority = AutoExecConfig_CreateConVar("gun_xp_rpgshop_pet_damage_priority", "-2", "Do not mindlessly edit this without understanding what it does.\nThis controls the order at which the damage editing plugins get to alter it.\nThis is important because this plugin sets the damage, negating any modifier another plugin made, so it must go first");

    AutoExecConfig_ExecuteFile();

    AutoExecConfig_CleanFile();

    RegisterPerkTree();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}

public Action L4D2_Pets_OnCanHavePets(int client, L4D2ZombieClassType zclass, bool &bCanHave)
{
    if(zclass != L4D2ZombieClass_Charger)
    {
        bCanHave = false;
        return Plugin_Handled;
    }

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(client, petIndex);

    if(perkLevel >= 0)
        bCanHave = true;

    ConVar cvar = FindConVar("l4d2_pets_dmg_scale");

    if(cvar != null)
    {
        int flags = cvar.Flags;

    	cvar.Flags = (flags & ~FCVAR_NOTIFY);

    	cvar.SetFloat(1.0, true);

    	cvar.Flags = flags;
    }

    return Plugin_Handled;
}
public void RPG_Perks_OnCalculateDamage(int priority, int victim, int attacker, int inflictor, float &damage, int damagetype, int hitbox, int hitgroup, bool &bDontInterruptActions, bool &bDontStagger, bool &bDontInstakill, bool &bImmune)
{   
    if(priority != g_hDamagePriority.IntValue)
        return;

    else if(!IsPlayer(attacker))
        return;

    else if(L4D_GetClientTeam(attacker) != L4DTeam_Infected)
        return;

    int owner = GetEntPropEnt(attacker, Prop_Send, "m_hOwnerEntity");

    if(!IsPlayer(owner))
        return;

    else if(RPG_Perks_GetZombieType(victim) == ZombieType_NotInfected)
    {
        damage = 0.0;
        bImmune = true;
        return;
    }

    int perkLevel = GunXP_RPGShop_IsPerkTreeUnlocked(owner, petIndex);

    if(perkLevel == -1)
        perkLevel = 0;

    damage = g_fPetDamages[perkLevel];
}

public void RegisterPerkTree()
{
    ArrayList descriptions, costs, xpReqs;
    descriptions = new ArrayList(128);
    costs = new ArrayList(1);
    xpReqs = new ArrayList(1);

    for(int i=0;i < sizeof(g_fPetDamages);i++)
    {
        char TempFormat[128];

        FormatEx(TempFormat, sizeof(TempFormat), "Use command sm_pet [remove] to spawn / despawn Pet\nPet deals %.0f damage.", g_fPetDamages[i]);

        descriptions.PushString(TempFormat);
        costs.Push(g_iPetCosts[i]);
        xpReqs.Push(g_iPetReqs[i]);
    }

    petIndex = GunXP_RPGShop_RegisterPerkTree("Charger Pet", "Charger Pet", descriptions, costs, xpReqs);
}
