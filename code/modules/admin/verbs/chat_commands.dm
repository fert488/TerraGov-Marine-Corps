#define TGS_STATUS_THROTTLE 5

/datum/tgs_chat_command/tgscheck
	name = "check"
	help_text = "Gets the playercount, gamemode, and address of the server"
	var/last_tgs_check = 0


/datum/tgs_chat_command/tgscheck/Run(datum/tgs_chat_user/sender, params)
	var/rtod = REALTIMEOFDAY
	if(rtod - last_tgs_check < TGS_STATUS_THROTTLE)
		return
	last_tgs_check = rtod
	var/server = CONFIG_GET(string/server)
	return "Round ID: [GLOB.round_id] | Round Time: [gameTimestamp("hh:mm")] | Players: [length(GLOB.clients)] | Ground Map: [length(SSmapping.configs) ? SSmapping.configs[GROUND_MAP].map_name : "Loading..."] | Ship Map: [length(SSmapping.configs) ? SSmapping.configs[SHIP_MAP].map_name : "Loading..."] | Mode: [GLOB.master_mode] | Round Status: [SSticker.HasRoundStarted() ? (SSticker.IsRoundInProgress() ? "Active" : "Finishing") : "Starting"] | Link: [server ? server : "<byond://[world.internet_address]:[world.port]>"]"


/datum/tgs_chat_command/ahelp
	name = "ahelp"
	help_text = "<ckey|ticket #> <message|ticket <close|resolve|icissue|reject|reopen|tier <ticket #>|list>>"
	admin_only = TRUE


/datum/tgs_chat_command/ahelp/Run(datum/tgs_chat_user/sender, params)
	var/list/all_params = splittext(params, " ")
	if(length(all_params) < 2)
		return "Insufficient parameters"
	var/target = all_params[1]
	all_params.Cut(1, 2)
	var/id = text2num(target)
	if(id != null)
		var/datum/admin_help/AH = GLOB.ahelp_tickets.TicketByID(id)
		if(AH)
			target = AH.initiator_ckey
		else
			return "Ticket #[id] not found!"
	var/res = TgsPm(target, all_params.Join(" "), sender.friendly_name)
	return res


/datum/tgs_chat_command/namecheck
	name = "namecheck"
	help_text = "Returns info on the specified target"
	admin_only = TRUE


/datum/tgs_chat_command/namecheck/Run(datum/tgs_chat_user/sender, params)
	params = trim(params)
	if(!params)
		return "Insufficient parameters"
	log_admin("Chat Name Check: [sender.friendly_name] on [params]")
	message_admins("Name checking [params] from [sender.friendly_name]")
	return keywords_lookup(params, TRUE)


/datum/tgs_chat_command/adminwho
	name = "adminwho"
	help_text = "Lists administrators currently on the server"
	admin_only = TRUE


/datum/tgs_chat_command/adminwho/Run(datum/tgs_chat_user/sender, params)
	return tgsadminwho()


/datum/tgs_chat_command/sdql
	name = "sdql"
	help_text = "Runs an SDQL query"
	admin_only = TRUE


/datum/tgs_chat_command/sdql/Run(datum/tgs_chat_user/sender, params)
	if(GLOB.AdminProcCaller)
		return "Unable to run query, another admin proc call is in progress. Try again later."
	GLOB.AdminProcCaller = "CHAT_[sender.friendly_name]"	//_ won't show up in ckeys so it'll never match with a real admin
	var/list/results = world.SDQL2_query(params, GLOB.AdminProcCaller, GLOB.AdminProcCaller, TRUE)
	GLOB.AdminProcCaller = null
	if(!results)
		return "Query produced no output"
	var/list/text_res = results.Copy(1, 3)
	var/list/refs = results[4]
	var/list/names = results[5]
	. = "[text_res.Join("\n")][length(refs) ? "\nRefs: [refs.Join(" ")]" : ""][length(names) ? "\nText: [replacetext(names.Join(" "), "<br>", "")]" : ""]"


/datum/tgs_chat_command/reload_admins
	name = "reload_admins"
	help_text = "Forces the server to reload admins."
	admin_only = TRUE


/datum/tgs_chat_command/reload_admins/Run(datum/tgs_chat_user/sender, params)
	ReloadAsync()
	log_admin("[sender.friendly_name] reloaded admins via chat command.")
	message_admins("[sender.friendly_name] reloaded admins via chat command.")
	return "Admins reloaded."


/datum/tgs_chat_command/reload_admins/proc/ReloadAsync()
	set waitfor = FALSE
	load_admins()


/client/proc/toggle_cdn()
	set name = "Toggle CDN"
	set category = "Server"
	var/static/admin_disabled_cdn_transport = null
	if (alert(usr, "Are you sure you want to toggle the CDN asset transport?", "Confirm", "Yes", "No") != "Yes")
		return
	var/current_transport = CONFIG_GET(string/asset_transport)
	if (!current_transport || current_transport == "simple")
		if (admin_disabled_cdn_transport)
			CONFIG_SET(string/asset_transport, admin_disabled_cdn_transport)
			admin_disabled_cdn_transport = null
			SSassets.OnConfigLoad()
			message_admins("[key_name_admin(usr)] re-enabled the CDN asset transport")
			log_admin("[key_name(usr)] re-enabled the CDN asset transport")
		else
			to_chat(usr, "<span class='adminnotice'>The CDN is not enabled!</span>")
			if (alert(usr, "The CDN asset transport is not enabled! If you having issues with assets you can also try disabling filename mutations.", "The CDN asset transport is not enabled!", "Try disabling filename mutations", "Nevermind") == "Try disabling filename mutations")
				SSassets.transport.dont_mutate_filenames = !SSassets.transport.dont_mutate_filenames
				message_admins("[key_name_admin(usr)] [(SSassets.transport.dont_mutate_filenames ? "disabled" : "re-enabled")] asset filename transforms")
				log_admin("[key_name(usr)] [(SSassets.transport.dont_mutate_filenames ? "disabled" : "re-enabled")] asset filename transforms")
	else
		admin_disabled_cdn_transport = current_transport
		CONFIG_SET(string/asset_transport, "simple")
		SSassets.OnConfigLoad()
		SSassets.transport.dont_mutate_filenames = TRUE
		message_admins("[key_name_admin(usr)] disabled the CDN asset transport")
		log_admin("[key_name(usr)] disabled the CDN asset transport")
