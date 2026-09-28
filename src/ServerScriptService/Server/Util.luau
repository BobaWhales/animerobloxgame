--!nonstrict
-- Util (ModuleScript) -> ServerScriptService/Server/Util

local Net = require(script.Parent:WaitForChild("Net"))

local Util = {}

-- Streaming-safe teleport with a client flash + sound.
function Util.Teleport(player: Player, cf: CFrame, label: string?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 3)
	end)
	if not char.Parent or not root.Parent then
		return
	end
	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
	Net.FX(player, "Teleported", { Where = label })
end

return Util
