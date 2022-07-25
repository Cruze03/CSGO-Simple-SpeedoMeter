#include <sourcemod> 
#include <clientprefs>
#include <multicolors> 

#pragma semicolon 1
#pragma newdecls required

#define SERVER_TAG "{green}[{lightgreen}SpeedOMeter{green}]{default}"

#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_THIRDPERSON 5

bool g_bHideSpeedMeter[MAXPLAYERS + 1] = {true, ...}, g_bMeterLocation, g_bLate = false;

ConVar g_hAdvertInterval, g_hMeterLocation;

Handle g_hClientSpeedCookie = INVALID_HANDLE, g_hTimer;

public Plugin myinfo =
{
	name = "Speed o Meter",
	author = "Cruze",
	description = "SpeedOMeter which is toggleable per player.",
	version = "1.1-BETA",
	url = "https://www.github.com/Cruze03/CSGO-Simple-SpeedoMeter"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart() 
{
	g_hMeterLocation = CreateConVar("ssm_location", "1", "where should speed meter be shown. 0 = CenterHUD, 1 = New CSGO HUD");
	g_hAdvertInterval = CreateConVar("ssm_advertinterval", "600.0", "Interval of time between advert");
	
	HookConVarChange(g_hMeterLocation, OnConVarValueChanged);
	HookConVarChange(g_hAdvertInterval, OnConVarValueChanged);
	
	AutoExecConfig(true, "cruze_speedometer");
	
	RegConsoleCmd("sm_speed", Toggle_Speed, "Toggle SpeedMeter");
	RegConsoleCmd("sm_speedmeter", Toggle_Speed, "Toggle SpeedMeter");
	RegConsoleCmd("sm_speedometer", Toggle_Speed, "Toggle SpeedMeter");

	g_hClientSpeedCookie = RegClientCookie("clientspeedcookiev2", "Cookie to check if speedmeter is blocked", CookieAccess_Private);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) 
		{
			continue;
		}
		OnClientPutInServer(i);
	}
}

public int OnConVarValueChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if(strcmp(oldVal, newVal, false) == 0)
	{
		return 0;
	}
	if(cvar == g_hAdvertInterval)
	{
		delete g_hTimer;
		g_hTimer = CreateTimer(cvar.FloatValue, Timer_Advert, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(cvar == g_hMeterLocation)
	{
		g_bMeterLocation = !!StringToInt(newVal);
	}
	return 1;
}

public void OnMapStart()
{
	g_bMeterLocation = g_hMeterLocation.BoolValue;
	
	if(!g_bLate)
	{
		g_hTimer = null;
	}
	else
	{
		delete g_hTimer;
		g_bLate = false;
	}
	g_hTimer = CreateTimer(g_hAdvertInterval.FloatValue, Timer_Advert, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Advert(Handle timer)
{
	CPrintToChatAll("%s Type {lime}!speedmeter{default} to toggle speed meter!", SERVER_TAG);
	return Plugin_Continue;
}

public Action Toggle_Speed(int client, int args)
{
	if(!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(!g_bHideSpeedMeter[client]) 
	{
		g_bHideSpeedMeter[client] = true;
		CPrintToChat(client, "%s {lightred}You have disabled speed meter.", SERVER_TAG);
	}
	else 
	{
		g_bHideSpeedMeter[client] = false;
		CPrintToChat(client, "%s {lime}You have enabled speed meter.", SERVER_TAG);
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_bHideSpeedMeter[client] = true;
	
	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}
}

public void OnClientCookiesCached(int client) 
{
	if(IsFakeClient(client))
	{
		return;
	}
	
	char sValue[8];
	GetClientCookie(client, g_hClientSpeedCookie, sValue, sizeof(sValue));
	
	g_bHideSpeedMeter[client] = (sValue[0] != '\0' && !!StringToInt(sValue));
}

public void OnClientDisconnect(int client) 
{
	if(IsFakeClient(client))
	{
		return;
	}
	
	char sValue[8];
	IntToString(g_bHideSpeedMeter[client], sValue, 8);
	SetClientCookie(client, g_hClientSpeedCookie, sValue);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3],
								int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) 
{

	//Thanks SHUFEN.jp(https://forums.alliedmods.net/member.php?u=250145) for helping me out here!! ^___^
	if(!IsFakeClient(client) && !g_bHideSpeedMeter[client])
	{	
		static float vVel[3], fVelocity;
		static int spectarget, specmode;
		
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		fVelocity = SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
		SetHudTextParamsEx(-1.0, 0.65, 0.1, {255, 255, 255, 255}, {0, 0, 0, 255}, 0, 0.0, 0.0, 0.0);
		
		if(IsPlayerAlive(client))
		{
			if(g_bMeterLocation)
			{
				ShowHudText(client, -1, "Speed: %.2f u/s", fVelocity);
			}
			else
			{
				PrintHintText(client, "<font color='#FF0000'> Speed</font>:<font color='#00ff00'> %.2f</font> u/s", fVelocity);
			}
		}
		else
		{
			spectarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			specmode = GetEntProp(client, Prop_Send, "m_iObserverMode");

			if (spectarget < 1 || spectarget > MaxClients || !IsClientInGame(spectarget))
				return;
			
			if(specmode != SPECMODE_FIRSTPERSON && specmode != SPECMODE_THIRDPERSON)
				return;

			if(g_bMeterLocation)
			{
				if(IsFakeClient(spectarget))
				{
					ShowHudText(client, -1, "BOT %N's Speed: %.2f u/s", spectarget, fVelocity);
				}
				else
				{
					ShowHudText(client, -1, "%N's Speed: %.2f u/s", spectarget, fVelocity);
				}
			}
			else
			{
				if(IsFakeClient(spectarget))
				{
					if (GetClientTeam(spectarget) == 2)
					{
						PrintHintText(client, "<font color='#ede749'>BOT %N</font>'s <font color='#FF0000'>Speed</font>: <font color='#00ff00'> %.2f</font> u/s", spectarget, fVelocity);
					}
					else
					{
						PrintHintText(client, "<font color='#3169c4'>BOT %N</font>'s <font color='#FF0000'>Speed</font>: <font color='#00ff00'> %.2f</font> u/s", spectarget, fVelocity);
					}
				}
				else
				{
					if (GetClientTeam(spectarget) == 2)
					{
						PrintHintText(client, "<font color='#ede749'>%N</font>'s <font color='#FF0000'>Speed</font>: <font color='#00ff00'> %.2f</font> u/s", spectarget, fVelocity);
					}
					else
					{
						PrintHintText(client, "<font color='#3169c4'>%N</font>'s <font color='#FF0000'>Speed</font>: <font color='#00ff00'> %.2f</font> u/s", spectarget, fVelocity);
					}
				}
			}
		}
	}
}
