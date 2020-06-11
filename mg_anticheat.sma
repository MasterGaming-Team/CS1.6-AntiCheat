#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <mg_anticheat_settings>
#if defined BANSYSTEM
	#include <mg_bansystem_api>
#endif

#define PLUGIN "[MG] Anticheat"
#define VERSION "1.0"
#define AUTHOR "Vieni"

#define TASKID1 5231

new gVpnIpListFile[] = "/vpn-iplist/iplist.txt"

new gStmIdChangerCmdList[][] = 
{
	"steamid", "steam_set_id", "sid_value", "ct_green_luma_set_value", "ct_steam_set_value"
}

new Array:arrayCheckHLTV
new Array:arrayCheckSteamIdChange

new Trie:trieVpnIpList

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	arrayCheckHLTV = ArrayCreate(1)
	arrayCheckSteamIdChange = ArrayCreate(1)

	trieVpnIpList = TrieCreate()

	loadVpnIpList()

	taskCheckPlayers()
}

public addPlayerToSteamIdCheck(taskId)
{
	new id = taskId - TASKID1

	ArrayPushCell(arrayCheckSteamIdChange, id)
}

public client_authorized(id)
{
	if(checkVpnIpList(id))
		return
	
	if(checkSteamIdChanger(id))
		return
}

public client_disconnected(id)
{
	new lArrayId
	
	lArrayId = ArrayFindValue(arrayCheckHLTV, id)
	if(lArrayId != -1)
		ArrayDeleteItem(arrayCheckHLTV, lArrayId)

	remove_task(TASKID1+id)
	lArrayId = ArrayFindValue(arrayCheckSteamIdChange, id)
	if(lArrayId != -1)
		ArrayDeleteItem(arrayCheckSteamIdChange, lArrayId)
}

taskCheckPlayers()
{
	new lArraySize, lPlayerId, CsTeams:lUserTeam, lUserAuthId[MAX_AUTHID_LENGTH+1]

	lArraySize = ArraySize(arrayCheckHLTV)
	for(new i; i  < lArraySize; i++)
	{
		lPlayerId = ArrayGetCell(arrayCheckHLTV, i)

		lUserTeam = cs_get_user_team(lPlayerId)

		if(!(lUserTeam == CS_TEAM_CT || lUserTeam == CS_TEAM_T))
			continue
		
		ArrayDeleteItem(arrayCheckHLTV, i)
		kickPlayer(lPlayerId, "KICK_HLTV")
	}

	lArraySize = ArraySize(arrayCheckSteamIdChange)
	for(new i; i < lArraySize; i++)
	{
		lPlayerId = ArrayGetCell(arrayCheckSteamIdChange, i)

		get_user_authid(lPlayerId, lUserAuthId, charsmax(lUserAuthId))

		if(!(equal(lUserAuthId, "STEAM_0:0:1") || equal(lUserAuthId, "VALVE_0:0:1")))
			continue
		
		ArrayDeleteItem(arrayCheckSteamIdChange, i)
		banPlayer(lPlayerId, BANTIME_CHANGER, "BAN_STEAMIDCHANGER")
	}

	set_task(7.0, "taskCheckPlayers")
}

checkSteamIdChanger(id)
{
	new lAuthId[MAX_AUTHID_LENGTH+1]

	get_user_authid(id, lAuthId, charsmax(lAuthId))

	if(equal(lAuthId, "STEAM_0:1:", 10))
		return false

	if(containi(lAuthId, "VALVE_ID_LAN") || containi(lAuthId, "STEAM_ID_LAN"))
	{
		kickPlayer(id, "KICK_AINTVALIDID")
		return true
	}

	if(containi(lAuthId, "HLTV"))
	{
		ArrayPushCell(arrayCheckHLTV, id)
		return true
	}

	sendSteamIdChangeMessages(id)
	set_task(1.0, "addPlayerToSteamIdCheck", TASKID1+id)
	return false
}

sendSteamIdChangeMessages(id)
{
	for(new i; i < sizeof(gStmIdChangerCmdList); i++)
		client_cmd(id, "%s 1", gStmIdChangerCmdList[i])
}

checkVpnIpList(id)
{
	new lIp[20]

	get_user_ip(id, lIp, charsmax(lIp), true)

	if(!TrieKeyExists(trieVpnIpList, lIp))
		return false
	
	kickPlayer(id, "KICK_VPNIP")
	return true
}

loadVpnIpList()
{
	new lIp[20], lFileLocation[256]

	get_configsdir(lFileLocation, charsmax(lFileLocation))
	format(lFileLocation, charsmax(lFileLocation), "%s%s", lFileLocation, gVpnIpListFile)

	new lLine

	while((lLine = read_file("lFileLocation", lLine, lIp, charsmax(lIp))))
	{
		if(contain(lIp, "/") != -1)
			continue
		
		TrieSetCell(trieVpnIpList, lIp, 1)
	}
}

kickPlayer(id, const reason[])
{
	new lKickTxt[64]

	formatex(lKickTxt, charsmax(lKickTxt), "kick #%i ^"[KICK]%L^"", get_user_userid(id), id, reason)
	server_cmd(lKickTxt)
}

banPlayer(id, minutes, const reason[])
{
	#if defined BANSYSTEM
		mg_bansystem_user_ban(id, minutes, reason)
	#else
		kickPlayer(id, reason)
	#endif
}