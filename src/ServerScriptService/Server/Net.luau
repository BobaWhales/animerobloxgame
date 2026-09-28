--!nonstrict
-- Net (ModuleScript) -> ServerScriptService/Server/Net
-- Creates the RemoteEvents in ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

Net.Ability = remote("Ability") -- client -> server: (action, payload) combat input
Net.Interact = remote("Interact") -- client -> server: custom ProximityPrompt triggered
Net.Request = remote("Request") -- client -> server: (action, arg)
Net.Sync = remote("Sync") -- server -> client: data snapshot
Net.FXEvent = remote("FX") -- server -> client: (kind, payload)
folder.Parent = ReplicatedStorage

function Net.FX(player: Player, kind: string, payload)
	Net.FXEvent:FireClient(player, kind, payload or {})
end

function Net.FXAll(kind: string, payload)
	Net.FXEvent:FireAllClients(kind, payload or {})
end

function Net.Notify(player: Player, text: string, color: Color3?, sound: string?)
	Net.FXEvent:FireClient(player, "Notify", { Text = text, Color = color, Sound = sound })
end

return Net
