
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
    name        = "Karma Survivor Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that makes you survive any karma once per round.",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar hcv_Difficulty;

int karmaSurvivorIndex;

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
    hcv_Difficulty = FindConVar("z_difficulty");
    
    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void RPG_Perks_OnGetMaxLimitedAbility(int priority, int client, char identifier[32], int &maxUses)
{
    if(!StrEqual(identifier, "Karma Survivor", false))
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

/**
 * Description
 *
 * @param victim             Player who got killed by the karma event. This can be anybody. Useful to revive the victim.
 * @param attacker           Artist that crafted the karma event. The only way to check if attacker is valid is: if(attacker > 0)
 * @param KarmaName          Name of karma: "Charge", "Impact", "Jockey", "Slap", "Punch", "Smoke", "Jump"
 * @param lastPos            Origin from which the jump began.
 * @param jumperWeapons		 Weapon Refs of the jumper at the moment of the jump. Every invalid slot is -1
 * @param jumperHealth    	 jumperHealth[0] and jumperHealth[1] = Health and Temp health from which the jump began.
 * @param jumperTimestamp    Timestamp from which the jump began.
 * @param jumperSteamId      jumper's Steam ID.
 * @param jumperName     	 jumper's name

 * @note					 Some values may be exclusive to karma jumps, but all values needed to respawn the player are guaranteed to be there in every karma.
 * @noreturn

 */

public void KarmaKillSystem_OnRPGKarmaEventPost(int victim, int attacker, const char[] KarmaName, float lastPos[3], int jumperWeapons[64], int jumperHealth[2], float jumperTimestamp, char[] jumperSteamId, char[] jumperName)
{
    if (victim == 0)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(victim, karmaSurvivorIndex))
        return;

    bool success = RPG_Perks_UseClientLimitedAbility(victim, "Karma Survivor");

    if(!success)
        return;

    int timesUsed, maxUses;

    RPG_Perks_GetClientLimitedAbility(victim, "Karma Survivor", timesUsed, maxUses);

    PrintToChat(victim, "Successfully survived Karma %s (%i/%i)", KarmaName, timesUsed, maxUses);

    Handle DP = CreateDataPack();

    WritePackCell(DP, victim);
    WritePackFloat(DP, lastPos[0]);
    WritePackFloat(DP, lastPos[1]);
    WritePackFloat(DP, lastPos[2]);

    WritePackCell(DP, jumperHealth[0]);
    WritePackCell(DP, jumperHealth[1]);

    int num = 0;

    for (int i = 0; i < 64; i++)
    {
        int weapon = EntRefToEntIndex(jumperWeapons[i]);

        if (weapon != INVALID_ENT_REFERENCE)
        {
            num++;
        }
    }

    WritePackCell(DP, num);

    for (int i = 0; i < 64; i++)
    {
        int weapon = EntRefToEntIndex(jumperWeapons[i]);

        if (weapon != INVALID_ENT_REFERENCE)
        {
            WritePackCell(DP, weapon);
        }
    }

    RequestFrame(Frame_Respawn, DP);
}

public void Frame_Respawn(Handle DP)
{
	ResetPack(DP);

	int victim = ReadPackCell(DP);

	float lastPos[3];

	lastPos[0] = ReadPackFloat(DP);
	lastPos[1] = ReadPackFloat(DP);
	lastPos[2] = ReadPackFloat(DP);

	int health     = ReadPackCell(DP);
	int tempHealth = ReadPackCell(DP);

	int num = ReadPackCell(DP);

	int weapons[64] = { -1, ... };

	for (int i = 0; i < num; i++)
	{
		weapons[i] = ReadPackCell(DP);
	}

	CloseHandle(DP);

	// Clients cannot replace eachother in a single frame, only invalidate.
	if (!IsClientInGame(victim))
		return;

	L4D_RespawnPlayer(victim);

	TeleportEntity(victim, lastPos, NULL_VECTOR, NULL_VECTOR);

	SetEntityHealth(victim, health);
	L4D_SetPlayerTempHealth(victim, tempHealth);

	for (int i = 0; i < num; i++)
	{
		int weapon = weapons[i];

		if(IsValidEdict(weapon))
		{
			EquipPlayerWeapon(victim, weapon);
		}
	}
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "You will respawn after getting karma killed, in your last grounded position\nYou only get 1 activation per round.\nYou get 1 extra activation per difficulty under Expert");
    karmaSurvivorIndex = GunXP_RPGShop_RegisterSkill("Karma Survivor", "Karma Survivor", sDescription,
    42000, 850000);
}


