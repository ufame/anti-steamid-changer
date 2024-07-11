#include <amxmodx>
#include <amxmisc>
#include <reapi>

//will the configuration iFile be created automatically?
#define AUTO_CREATE_CONFIG

//The path to the iFile relative to addons/amxmodx/configs
new const WHITE_LIST_FILE[] = "settings/settings_asc_whitelist.ini";

const MAX_REASON_LENGTH     = 32;
const MAX_COMMAND_LENGTH    = 32;
const DEFAULT_ACCESS        = ADMIN_CFG; //Flag for access to the asc_add_white and asc_clear_cache commands

enum _: Client {
  ClientIp[MAX_IP_LENGTH],
  ClientAuthid[MAX_AUTHID_LENGTH]
};

new Array: g_aClientsInfo;
new g_iClients;

new Array: g_aWhiteList;
new g_iWhiteList;

new Array: g_aPunishCache;
new g_iPunishCache;

new g_szReason[MAX_REASON_LENGTH];
new g_szPunishmentCommand[MAX_COMMAND_LENGTH];

new g_iCommandsAccess = DEFAULT_ACCESS;

new g_szCfg[MAX_RESOURCE_PATH_LENGTH];

public plugin_init() {
  register_plugin("Anti steamid changer", "1.0.4", "ufame");

  load_white_list();

  new pCvar = create_cvar(
    "asc_flags",
    "l",
    _,
    "Flag for access to the asc_add_white and asc_clear_cache commands"
  );
  hook_cvar_change(pCvar, "cvarhook_asc_flags");
  cvarhook_asc_flags(pCvar);

  pCvar = create_cvar(
    "asc_reason",
    "SteamID Changer",
    _,
    "The reason for the punishment"
  );
  bind_pcvar_string(pCvar, g_szReason, MAX_REASON_LENGTH - 1);

  pCvar = create_cvar(
    "asc_command",
    "fb_ban 44640 #userid#",
    _,
    "The command to execute the punishment"
  );
  bind_pcvar_string(pCvar, g_szPunishmentCommand, MAX_COMMAND_LENGTH - 1);

#if defined AUTO_CREATE_CONFIG
  AutoExecConfig(true, "anti_steamid_change", "punishments");
#endif

  register_concmd("asc_clear_cache", "concmd_clear_cache");
  register_concmd("asc_add_white", "concmd_add_white", _, "- <name|steamid|userid>");
}

public cvarhook_asc_flags(pcvar) {
  new szFlag[2];
  get_pcvar_string(pcvar, szFlag, charsmax(szFlag));

  g_iCommandsAccess = (szFlag[0] != EOS) ? read_flags(szFlag) : DEFAULT_ACCESS;
}

public concmd_clear_cache(id) {
  if (!access(id, g_iCommandsAccess)) {
    server_print("[ASC] No have access to that command");

    return PLUGIN_HANDLED;
  }

  new bDestroy = ArrayDestroy(g_aPunishCache);
  server_print("[ASC] %s punishments cache. Total [%d]", bDestroy ? "Succesfully cleared" : "No had a", g_iPunishCache);

  g_iPunishCache = 0;

  return PLUGIN_HANDLED;
}

public concmd_add_white(id) {
  if (!access(id, g_iCommandsAccess)) {
    server_print("[ASC] No have access to that command");

    return PLUGIN_HANDLED;
  }

  new szArg[MAX_AUTHID_LENGTH];
  read_argv(1, szArg, MAX_AUTHID_LENGTH - 1);

  new player = cmd_target(id, szArg, CMDTARGET_NO_BOTS);

  if (!player) {
    server_print("[ASC] No players find yet");

    return PLUGIN_HANDLED;
  }

  new szIp[MAX_IP_LENGTH];
  get_user_ip(player, szIp, MAX_IP_LENGTH - 1, 1);

  if (g_iWhiteList && ArrayFindString(g_aWhiteList, szIp) != -1) {
    server_print("[ASC] This player already have immunity");

    return PLUGIN_HANDLED;
  }

  new iFile, szBuffer[64];
  formatex(szBuffer, charsmax(szBuffer), "%s    ; %n", szIp, player);

  new iExists = file_exists(g_szCfg);
  iFile = fopen(g_szCfg, iExists ? "at" : "wt");

  if (!iExists) {
    fputs(iFile, "; Anti SteamID Changer - whitelist");
    fputs(iFile, "; Formatting iFile is - <ip> ; comment");
  }

  if (!iFile) {
    server_print("[ASC] White list iFile read error");

    return PLUGIN_HANDLED;
  }

  new bSuccess = fputs(iFile, szBuffer);
  server_print("[ASC] Player %n (%s) %s added to white list", player, szIp, bSuccess ? "successfully" : "failure");

  if (!g_aWhiteList)
    g_aWhiteList = ArrayCreate(MAX_IP_LENGTH + 1, 1);

  ArrayPushString(g_aWhiteList, szIp);

  fclose(iFile);

  return PLUGIN_HANDLED;
}

public client_putinserver(id) {
  if (is_user_bot(id) || is_user_hltv(id))
    return;

  new szIp[MAX_IP_LENGTH];
  get_user_ip(id, szIp, MAX_IP_LENGTH - 1, 1);

  if (g_iPunishCache && ArrayFindString(g_aPunishCache, szIp) != -1) {
    server_cmd("kick #%d %s", get_user_userid(id), g_szReason);

    return;
  }

  //We have a saved players?
  if (g_iClients) {
    new szOutput[Client], iItemId;

    for (new i; i < g_iClients; i++) {
      ArrayGetArray(g_aClientsInfo, i, szOutput, sizeof szOutput);

      //check: client in array
      if (equal(szOutput[ClientIp], szIp))   {
        iItemId = i;

        break;
      }
    }

    //gotcha
    if (iItemId) {
      new szAuthid[MAX_AUTHID_LENGTH];
      get_user_authid(id, szAuthid, MAX_AUTHID_LENGTH - 1);

      //check: client authid != authid in disconnected
      if (!equal(szAuthid, szOutput[ClientAuthid])) {
        client_punishment(id); //punishment a bad player *uwu*

        ArrayDeleteItem(g_aClientsInfo, iItemId); //clear this client from array to prevent double punishment
        g_iClients--;

        if (!g_aPunishCache)
          g_aPunishCache = ArrayCreate(MAX_IP_LENGTH + 1, 1);

        //add to cache
        ArrayPushString(g_aPunishCache, szIp);
        g_iPunishCache++;
      }
    }
  }
}

public client_disconnected(id) {
  if (is_user_bot(id) || is_user_hltv(id))
    return;

  if (!g_aClientsInfo)
    g_aClientsInfo = ArrayCreate(Client);

  new szInput[Client];

  get_user_ip(id, szInput[ClientIp], MAX_IP_LENGTH - 1, 1);
  get_user_authid(id, szInput[ClientAuthid], MAX_AUTHID_LENGTH - 1);

  if (g_iWhiteList) {
    if (ArrayFindString(g_aWhiteList, szInput[ClientIp]) != -1)
    return;
  }

  ArrayPushArray(g_aClientsInfo, szInput);
  g_iClients++;
}

stock client_punishment(id) {
  new szIp[MAX_IP_LENGTH], szAuthid[MAX_AUTHID_LENGTH];

  get_user_ip(id, szIp, MAX_IP_LENGTH - 1, 1);
  get_user_authid(id, szAuthid, MAX_AUTHID_LENGTH - 1);

  new tempPunishCommand[MAX_COMMAND_LENGTH];
  copy(tempPunishCommand, MAX_COMMAND_LENGTH - 1, g_szPunishmentCommand);

  replace_string(tempPunishCommand, charsmax(tempPunishCommand), "#userid#", fmt("#%d", get_user_userid(id)), false);
  replace_string(tempPunishCommand, charsmax(tempPunishCommand), "#ip#", szIp, false);
  replace_string(tempPunishCommand, charsmax(tempPunishCommand), "#authid#", szAuthid, false);

  if (contain(tempPunishCommand, "addip") != -1 || contain(tempPunishCommand, "banid") != -1) {
    server_cmd("%s; writeip; writeid; wait; kick #%d %s", tempPunishCommand, get_user_userid(id), tempPunishCommand);
    server_exec();

    return;
  }

  server_cmd("%s %s", tempPunishCommand, g_szReason);
  server_exec();
}

stock load_white_list() {
  get_configsdir(g_szCfg, MAX_RESOURCE_PATH_LENGTH - 1);
  add(g_szCfg, charsmax(g_szCfg), fmt("/%s", WHITE_LIST_FILE));

  if (!file_exists(g_szCfg)) {
    log_error(AMX_ERR_NATIVE, "File '%s' is not exists", g_szCfg);

    return;
  }

  new iFile = fopen(g_szCfg, "rt");

  if (!iFile) {
    log_error(AMX_ERR_NATIVE, "File %s open error", g_szCfg);

    return;
  }

  g_aWhiteList = ArrayCreate(MAX_IP_LENGTH + 1, 1);

  new szBuffer[64], szIp[MAX_IP_LENGTH];

  while (!feof(iFile)) {
    fgets(iFile, szBuffer, charsmax(szBuffer));

    if (szBuffer[0] == EOS || szBuffer[0] == ';')
      continue;

    delete_comment(szBuffer);
    trim(szBuffer);

    parse(szBuffer, szIp, charsmax(szIp));

    g_iWhiteList++;
    ArrayPushString(g_aWhiteList, szIp);
  }

  log_amx("Successfully loaded whitelist, count : %d", g_iWhiteList);

  fclose(iFile);
}

new const COMMENTS[] = {
  '#', ';'
};

new const QUOTE = '^"';

stock delete_comment(szString[]) {
  new len = strlen(szString);
  new bool: bInQuotes;

  for (new i; i < len; i++) {
    if (szString[i] == QUOTE) {
      bInQuotes = !bInQuotes;

      if (bInQuotes)
        continue;

      for (new c; c < sizeof COMMENTS; c++) {
        if (szString[i] == COMMENTS[c]) {
          szString[i] = EOS;

          break;
        }
      }
    }
  }
}
