
/* What the l4d2_bile_goggles.txt file contains:

"Games"
{
	"left4dead"
	{
		"Signatures"
		{
			"CTerrorPlayer::OnITExpired"
			{
				"library"		"server"
				"linux"			"@_ZN13CTerrorPlayer11OnITExpiredEv"
				"windows"		"\xD9\x05\x2A\x2A\x2A\x2A\x56\x57\x8B\xF9\xD8\x9F\x2A\x2A\x00\x00\x8D\xB7\x2A\x2A\x00\x00\xDF\xE0\xF6\xC4\x2A\x7B\x13\x8B\x46\xF8\x8B\x10\x8D\x4E\xF8\x56\xFF\xD2\xD9\x2A\x2A\x2A\x2A\x2A\xD9\x1E\x8B\x37\x6A"
			}
		}
	}
	"left4dead2"
	{
		"Signatures"
		{
			"CTerrorPlayer::OnITExpired"
			{
				"library"		"server"
				"linux"			"@_ZN13CTerrorPlayer11OnITExpiredEv"
				"windows"		"\x56\x57\x8B\x2A\xF3\x2A\x2A\x2A\x2A\x2A\x2A\x2A\x0F\x2A\x2A\x2A\x2A\x2A\x2A\x8D\x2A\x2A\x2A\x2A\x2A\x9F\xF6\x2A\x2A\x7B\x2A\x8B\x2A\x2A\x8B\x2A\x8D\x2A\x2A\x56\xFF\x2A\xF3\x2A\x2A\x2A\x2A\x2A\x2A\x2A\xF3\x2A\x2A\x2A\x8B\x2A\x6A"
			}
		}
	}
}


// End of the file l4d2_bile_goggles.txt */

// https://forums.alliedmods.net/showpost.php?p=1712698&postcount=1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#pragma newdecls required

bool g_bTookGogglesOff[MAXPLAYERS+1], g_bBlindEyes[MAXPLAYERS+1];
float g_fBileTimer[MAXPLAYERS+1];
bool g_bSpam[MAXPLAYERS+1];

Handle g_hVomitTimer[MAXPLAYERS+1] = { INVALID_HANDLE, ... };


public Plugin myinfo = 
{
	name = "[L4D2] Bile Goggles",
	author = "Eyal282",
	description = "Goggles that you can wear off at any time you want to clear bile.",
	version = "1.0"
}

GlobalForward g_fwOnDoesHaveBileGoggles;+

public void OnPluginStart()
{
	g_fwOnDoesHaveBileGoggles = CreateGlobalForward("BileGoggles_OnDoesHaveBileGoggles", ET_Ignore, Param_Cell, Param_CellByRef, Param_FloatByRef);

	HookEvent("player_now_it", Event_Boom, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStartOrEnd, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundStartOrEnd, EventHookMode_PostNoCopy);
}

public void GunXP_OnReloadRPGPlugins()
{
	#if defined _GunXP_RPG_included
		GunXP_ReloadPlugin();
	#endif

}

public Action Event_RoundStartOrEnd(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for(int i=0;i < sizeof(g_bTookGogglesOff);i++)
	{
		g_bTookGogglesOff[i] = false;
		g_fBileTimer[i] = 0.0;
		g_bBlindEyes[i] = false;
		g_bSpam[i] = false;
		g_hVomitTimer[i] = INVALID_HANDLE;
	}

	return Plugin_Continue;
}

public Action Event_Boom(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return Plugin_Continue;
		
	Call_StartForward(g_fwOnDoesHaveBileGoggles);

	bool bHasGoggles;
	float fCleanTime = 15.0;

	Call_PushCell(victim);
	Call_PushCellRef(bHasGoggles);
	Call_PushFloatRef(fCleanTime);
	Call_Finish();

	if(!bHasGoggles)
		return Plugin_Continue;

	
	if(g_hVomitTimer[victim] != INVALID_HANDLE)
	{
		CloseHandle(g_hVomitTimer[victim]);
		g_hVomitTimer[victim] = INVALID_HANDLE;
	}	

	g_hVomitTimer[victim] = CreateTimer(0.1, Timer_CountDown, victim, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

	if(!g_bTookGogglesOff[victim]) // victim has not taken goggles. Now print message that he can press "G" to take them off.
	{
		PrintToChat(victim, "You have Bile Goggles. Press +ZOOM to take them off and see clearly.");	

		g_fBileTimer[victim] = fCleanTime; // 15 seconds of Goggles Blindness / Eyes Blindness.
		
		g_bBlindEyes[victim] = false;
	}
	
	else
	{
		PrintToChat(victim, "You were blinded without your goggles. They can not help you now.");
		
		if(g_fBileTimer[victim] < 15.0)
			g_fBileTimer[victim] = 15.0; // 15 seconds of Goggles Blindness / Eyes Blindness.)
			
		g_bBlindEyes[victim] = true; // Player was blind without goggles on ( goggles will be useless can't be used )
	}

	return Plugin_Continue;
}

public Action Timer_CountDown(Handle Timer, int victim)
{
	g_fBileTimer[victim] -= 0.1;
	if(g_fBileTimer[victim] > 0)
	{
		return Plugin_Continue;
	}

	g_fBileTimer[victim] = 0.0; // No risking.
	
	if(g_bBlindEyes[victim])
		PrintToChat(victim, "Your eyes recovered from the bile. Goggles are ready for use");
		
	else
		PrintToChat(victim, "Your Goggles recovered from the bile. They are ready for use.");
		
	g_bTookGogglesOff[victim] = false;
	g_bBlindEyes[victim] = false;
	
	g_hVomitTimer[victim] = INVALID_HANDLE;

	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(! ( buttons & IN_ZOOM ) || g_fBileTimer[client] == 0 || g_bSpam[client])
		return Plugin_Continue;
	
	Call_StartForward(g_fwOnDoesHaveBileGoggles);

	bool bHasGoggles;
	float fCleanTime = 15.0;

	Call_PushCell(client);
	Call_PushCellRef(bHasGoggles);
	Call_PushFloatRef(fCleanTime);
	Call_Finish();
	
	if(!bHasGoggles)
		return Plugin_Continue;

	g_bSpam[client] = true;
	
	CreateTimer(1.0, Timer_SpamOff, client);
	
	if(g_bBlindEyes[client])
	{
		PrintToChat(client, "The Boomer Bile hit your eyes. Goggles will not help for %d seconds.", RoundFloat(g_fBileTimer[client]));
	}
	
	else
	{
		if(!g_bTookGogglesOff[client])
		{
			PrintToChat(client, "You have successfully taken off your Goggles. They will be put on in %d seconds.", RoundFloat(g_fBileTimer[client]));
			
			g_bTookGogglesOff[client] = true;
			
			L4D_OnITExpired(client);
			
			SetEntPropFloat(client, Prop_Send, "m_vomitFadeStart", GetGameTime() + 0.01); // To allow the player to be boomed again within the 15 seconds.
			
			Event event = CreateEvent("player_no_longer_it"); // This to allow the player to be boomed again within the 15 seconds.
			
			if (event != null)
			{
				event.SetInt("userid", GetClientUserId(client));
				event.Fire();
			}
		}
		
		else
		{
			PrintToChat(client, "Your Bile Goggles will be put on in %d seconds.", RoundFloat(g_fBileTimer[client]));
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_SpamOff(Handle Timer, int client)
{
	g_bSpam[client] = false;

	return Plugin_Continue;
}