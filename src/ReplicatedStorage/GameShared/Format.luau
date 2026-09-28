--!nonstrict
-- Format (ModuleScript) -> ReplicatedStorage/GameShared/Format
-- Number / time formatting shared by server and client.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Abbrev(n: number): string
	n = tonumber(n) or 0
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n == math.floor(n) then tostring(math.floor(n)) else string.format("%.1f", n)
		return (negative and "-" or "") .. s
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local s
	if scaled >= 100 then
		s = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		s = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		s = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return (negative and "-" or "") .. s .. SUFFIXES[tier + 1]
end

function Format.Commas(n: number): string
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

function Format.Percent(p: number): string
	if p >= 1 then
		return string.format("%g%%", math.floor(p * 10 + 0.5) / 10)
	end
	return string.format("%.2g%%", p)
end

return Format
