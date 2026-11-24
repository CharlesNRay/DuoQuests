--[[
	Remotes (ModuleScript)
	Location: ReplicatedStorage > Shared > Remotes

	Names of the two remotes the UI uses. The server (ApiService) creates them
	in ReplicatedStorage > IdlePartyRemotes; the client waits for them.

	  Api   RemoteFunction   client -> server requests: Api:InvokeServer(action, ...)
	                         returns ok (boolean), data or a reason string
	  Push  RemoteEvent      server -> client notifications
	                           "Fight"  { Stage, Won, Duration, NextStage, Wait,
	                                      Reward = { Gold, XP, Shards } or nil }

	The client may only ASK. The server validates everything, so a modified
	client can never grant itself anything.
]]

return {
	FolderName = "IdlePartyRemotes",
	Api = "Api",
	Push = "Push",
}
