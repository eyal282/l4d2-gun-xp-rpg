
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
    name        = "Multi Jump Skill --> Gun XP - RPG",
    author      = "Eyal282",
    description = "Skill that allows jumping mid-air.",
    version     = PLUGIN_VERSION,
    url         = ""
};

GlobalForward g_fwOnRPGJump;

int g_iLastButtons[MAXPLAYERS+1], g_iLastFlags[MAXPLAYERS+1], g_iJumps[MAXPLAYERS+1];

float g_fJumpBoost = 251.0;

// If you're falling, how good resisting is, aka how much extra jump to get.
float g_fJumpBoostResist = 600.0;

int jumpIndex;

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
    g_fwOnRPGJump = CreateGlobalForward("GunXP_Skills_OnMultiJump", ET_Ignore, Param_Cell, Param_CellByRef);

    HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);

    RegisterSkill();
}

public void GunXP_OnReloadRPGPlugins()
{
    GunXP_ReloadPlugin();
}


public void RPG_Perks_OnTimedAttributeExpired(int entity, char attributeName[64])
{
    if(!IsPlayer(entity))
        return;
        
    if(StrEqual(attributeName, "Frozen") || StrEqual(attributeName, "Stun"))
    {
        g_iJumps[entity] = 999999;
    }
}

// Requires RPG_Perks_RegisterReplicateCvar to fire.
public void RPG_Perks_OnGetReplicateCvarValue(int priority, int client, const char cvarName[64], char sValue[256])
{
    if(priority != 0)
        return;

    else if(!GunXP_RPGShop_IsSkillUnlocked(client, jumpIndex))
        return;

    else if(GunXP_RPG_GetClientLevel(client) < 40)
        return;

    else if(!StrEqual(cvarName, "sv_airaccelerate", false))
        return;

    sValue = "999999999";
}
public Action Event_PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    Call_StartForward(g_fwOnRPGJump);

    Call_PushCell(client);
    Call_PushCell(false);

    Call_Finish();

    return Plugin_Continue;
}

public void RegisterSkill()
{
    char sDescription[512];
    FormatEx(sDescription, sizeof(sDescription), "You gain these abilities based on your level:\n⬤ 30: Double Jump\n⬤ 40: Max Air Accelerate ( Steer mid-air, surfing is easier )\n⬤ 50: Triple Jump\n⬤ 60: Multi Jumps negate fall velocity");

    jumpIndex = GunXP_RPGShop_RegisterSkill("Multi Jump", "Multi Jump", sDescription,
    25000, GunXP_RPG_GetXPForLevel(30));

    if(LibraryExists("RPG_Perks"))
    {
        RPG_Perks_RegisterReplicateCvar("sv_airaccelerate");
    }
}

// Start of Double Jump plugin
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{

    int iCurFlags   = GetEntityFlags(client), iCurButtons = buttons;

    if (g_iLastFlags[client] & FL_ONGROUND) {
        if (!(iCurFlags & FL_ONGROUND) && !(g_iLastButtons[client] & IN_JUMP) && iCurButtons & IN_JUMP) {
            g_iJumps[client]++;
        }
    }
    else if (iCurFlags & FL_ONGROUND)
    {
        g_iJumps[client] = 0;
    }
    else if (!(g_iLastButtons[client] & IN_JUMP) && iCurButtons & IN_JUMP)
    {
        DoubleJump(client);
    }

    g_iLastFlags[client]    = iCurFlags;
    g_iLastButtons[client]  = iCurButtons;

    return Plugin_Continue;
}

void DoubleJump(int client)
{
    int iMaxJumps = 1;

    if(!GunXP_RPGShop_IsSkillUnlocked(client, jumpIndex))
        return;

    else if(L4D_IsPlayerStaggering(client))
        return;

    else if(IsClientAffectedByFling(client))
        return;

    else if(GunXP_RPG_GetClientLevel(client) >= 50)
    {
        iMaxJumps = 2;
    }

    if (0 <= g_iJumps[client] && g_iJumps[client] < iMaxJumps) {
        g_iJumps[client]++;

        float fVel[3];

        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);

        float fJumpBoostResist = g_fJumpBoostResist;

        if(GunXP_RPG_GetClientLevel(client) >= 60)
        {
            fJumpBoostResist = 65535.0;
        }

        // Client is already ascending, OR client is under a death fall.
        if(fVel[2] > g_fJumpBoost || fVel[2] < (-1.0 * fJumpBoostResist))
            return;

        if(fVel[2] >= 0.0)
        {
            fVel[2] = g_fJumpBoost;
        }

        if(fVel[2] < g_fJumpBoost)
        {
            float fIncrease = fJumpBoostResist;

            fVel[2] += fIncrease;

            if(fVel[2] >= g_fJumpBoost)
            {
                fVel[2] = g_fJumpBoost;
                fIncrease = 65535.0;
            }

            // Protect from fall damage without falling.

            SetEntPropFloat(client, Prop_Data, "m_flFallVelocity", GetEntPropFloat(client, Prop_Data, "m_flFallVelocity") - fIncrease);

            if(GetEntPropFloat(client, Prop_Data, "m_flFallVelocity") <= 0.0)
            {
                SetEntPropFloat(client, Prop_Data, "m_flFallVelocity", 0.0);
            }
        }

        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);

        Call_StartForward(g_fwOnRPGJump);

        Call_PushCell(client);
        Call_PushCell(true);

        Call_Finish();
    }
}


bool IsClientAffectedByFling(int client)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);
	switch (model[29])
	{
		case 'b':    // nick
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 661, 667, 669, 671, 672, 627, 628, 629, 630, 620:
					return true;
			}
		}
		case 'd':    // rochelle
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 668, 674, 676, 678, 679, 635, 636, 637, 638, 629:
					return true;
			}
		}
		case 'c':    // coach
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 650, 656, 658, 660, 661, 627, 628, 629, 630, 621:
					return true;
			}
		}
		case 'h':    // ellis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 665, 671, 673, 675, 676, 632, 633, 634, 635, 625:
					return true;
			}
		}
		case 'v':    // bill
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
		case 'n':    // zoey
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 813, 819, 821, 823, 824, 544, 545, 546, 547, 537:
					return true;
			}
		}
		case 'e':    // francis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 756, 762, 764, 766, 767, 538, 539, 540, 541, 531:
					return true;
			}
		}
		case 'a':    // louis
		{
			switch (GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 753, 759, 761, 763, 764, 535, 536, 537, 538, 528:
					return true;
			}
		}
	}
	return false;
}