--!nonstrict
-- SFX (ModuleScript) -> ReplicatedStorage/GameShared/SFX
-- Client-side sound design. Every effect is a "cue" made of layered sounds
-- (pitch-shifted, delayed, with reverb/distortion) so hits feel punchy
-- without needing to upload any audio.
--
-- Sources are Roblox built-in engine sounds (always available) plus the
-- classic Roblox sword sounds. If an asset fails to load it automatically
-- falls back to a built-in sound. Swap any source in Config.SoundOverrides.
--
-- Mixing: everything plays through one SoundGroup with a gentle compressor
-- and a soft high cut (keeps the mix quiet and smooth), and every cue is
-- rate-limited so a burst of hits / pickups never stacks into noise.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("Config"))

local SFX = {}

local SOURCES = {
	Boom = "rbxasset://sounds/impact_explosion_03.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Whoosh = "rbxasset://sounds/action_jump.mp3",
	Thud = "rbxasset://sounds/action_jump_land.mp3",
	Blip = "rbxasset://sounds/volume_slider.ogg",
	Bubble = "rbxasset://sounds/action_swim.mp3",
	Rise = "rbxasset://sounds/action_get_up.mp3",
	Slash = "rbxassetid://12222216",
	Lunge = "rbxassetid://12222208",
	Unsheath = "rbxassetid://12222225",
}
-- If a web asset can't load, use {builtInSource, pitchMultiplier}.
local FALLBACK = {
	Slash = { "Whoosh", 1.75 },
	Lunge = { "Whoosh", 1.25 },
	Unsheath = { "Blip", 0.6 },
}
local unavailable = {}

-- Musical ratios for arpeggios / chords (major scale from the root).
local NOTE = { C = 1, D = 1.1225, E = 1.2599, F = 1.3348, G = 1.4983, A = 1.6818, B = 1.8877, C2 = 2, E2 = 2.5198, G2 = 2.9966, C3 = 4 }

--[[ Layer fields
	S  = source key       V = volume        P = pitch or {min,max}
	D  = delay (s)        Fx = {Reverb=true, Distort=0.3, Bass=6, Echo=true}
	Arp = {pitches...} with Gap (plays S once per pitch)
	Chord = {pitches...} (plays S at every pitch at once)
]]
local CUES = {
	Swing = {
		{ S = "Slash", V = 0.5, P = { 0.95, 1.15 } },
		{ S = "Whoosh", V = 0.12, P = { 1.9, 2.2 } },
	},
	SwingHeavy = {
		{ S = "Lunge", V = 0.65, P = { 0.8, 0.9 } },
		{ S = "Boom", V = 0.15, P = { 1.9, 2.1 } },
		{ S = "Whoosh", V = 0.2, P = { 1.2, 1.3 } },
	},
	-- Impacts are built from four layers: a bright transient "tick", a body
	-- thump, a short crunch and a tiny tail, each slightly randomised.
	Hit = {
		{ S = "Blip", V = 0.12, P = { 3.6, 4 } },
		{ S = "Thud", V = 0.55, P = { 1.3, 1.6 }, Fx = { Bass = 3 } },
		{ S = "Boom", V = 0.22, P = { 2.6, 3.1 }, Fx = { Distort = 0.15 } },
		{ S = "Splash", V = 0.06, P = { 2.4, 2.8 }, D = 0.02 },
	},
	HitBlade = {
		{ S = "Slash", V = 0.28, P = { 1.35, 1.55 } },
		{ S = "Blip", V = 0.1, P = { 3.8, 4.2 } },
		{ S = "Thud", V = 0.45, P = { 1.5, 1.8 } },
		{ S = "Unsheath", V = 0.12, P = { 1.8, 2.1 }, D = 0.01 },
	},
	HitBlunt = {
		{ S = "Thud", V = 0.7, P = { 0.9, 1.1 }, Fx = { Bass = 6 } },
		{ S = "Boom", V = 0.3, P = { 1.9, 2.2 }, Fx = { Distort = 0.2 } },
		{ S = "Blip", V = 0.08, P = { 3, 3.3 } },
	},
	HitEnergy = {
		{ S = "Splash", V = 0.25, P = { 2.2, 2.6 } },
		{ S = "Boom", V = 0.22, P = { 2.8, 3.2 } },
		{ S = "Blip", V = 0.14, P = { 2.6, 3 }, Fx = { Echo = true } },
	},
	Crit = {
		{ S = "Blip", V = 0.18, P = 4.2 },
		{ S = "Boom", V = 0.6, P = { 1.5, 1.7 }, Fx = { Bass = 8 } },
		{ S = "Thud", V = 0.7, P = { 1, 1.15 } },
		{ S = "Slash", V = 0.2, P = { 1.8, 2 } },
		{ S = "Blip", Chord = { NOTE.C2, NOTE.G2 }, V = 0.3, D = 0.03 },
	},
	Exposed = {
		{ S = "Blip", Arp = { NOTE.E2, NOTE.G2 }, Gap = 0.04, V = 0.3 },
		{ S = "Thud", V = 0.4, P = 1.9 },
	},
	AoE = {
		{ S = "Boom", V = 0.6, P = { 0.9, 1 }, Fx = { Reverb = true } },
		{ S = "Splash", V = 0.35, P = { 1.4, 1.5 } },
		{ S = "Whoosh", V = 0.3, P = { 0.7, 0.75 } },
	},
	Kill = {
		{ S = "Boom", V = 0.45, P = { 1.25, 1.4 } },
		{ S = "Splash", V = 0.2, P = { 1.9, 2.1 } },
		{ S = "Blip", Arp = { NOTE.G, NOTE.C2 }, Gap = 0.05, V = 0.3 },
	},
	EliteKill = {
		{ S = "Boom", V = 0.7, P = 0.9, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2, NOTE.E2 }, Gap = 0.05, V = 0.35 },
	},
	BossKill = {
		{ S = "Boom", V = 0.72, P = 0.55, Fx = { Reverb = true, Bass = 8 } },
		{ S = "Boom", V = 0.8, P = 0.8, D = 0.18, Fx = { Reverb = true } },
		{ S = "Splash", V = 0.5, P = 0.6, D = 0.1 },
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3 }, Gap = 0.06, V = 0.4, D = 0.35, Fx = { Echo = true } },
	},
	OrePickup = {
		{ S = "Blip", V = 0.45, P = 1.5 },
		{ S = "Blip", V = 0.3, P = 2, D = 0.04 },
	},
	RarePickup = {
		{ S = "Blip", Arp = { NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3 }, Gap = 0.045, V = 0.45, Fx = { Echo = true } },
		{ S = "Splash", V = 0.2, P = 2.2 },
	},
	Coins = {
		{ S = "Blip", Arp = { NOTE.E2, NOTE.C3 }, Gap = 0.07, V = 0.45 },
	},
	Forge = {
		{ S = "Boom", V = 0.55, P = 0.7, Fx = { Bass = 6 } },
		{ S = "Splash", V = 0.55, P = 0.55 },
		{ S = "Unsheath", V = 0.5, P = 0.9, D = 0.15 },
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2 }, Gap = 0.07, V = 0.4, D = 0.2 },
	},
	ForgeTierUp = {
		{ S = "Boom", V = 0.9, P = 0.5, Fx = { Reverb = true, Bass = 8 } },
		{ S = "Unsheath", V = 0.7, P = 0.75, D = 0.1, Fx = { Reverb = true } },
		{ S = "Blip", Chord = { NOTE.C, NOTE.E, NOTE.G }, V = 0.3, D = 0.25, Fx = { Distort = 0.12, Reverb = true } },
		{ S = "Blip", Chord = { NOTE.C2, NOTE.E2, NOTE.G2 }, V = 0.3, D = 0.5, Fx = { Distort = 0.12, Reverb = true } },
	},
	Sell = {
		{ S = "Thud", V = 0.5, P = 1.2 },
		{ S = "Blip", Arp = { NOTE.C2, NOTE.E2, NOTE.G2 }, Gap = 0.05, V = 0.4 },
	},
	Rebirth = {
		{ S = "Rise", V = 0.8, P = 0.6, Fx = { Reverb = true } },
		{ S = "Boom", V = 0.72, P = 0.4, D = 0.6, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Splash", V = 0.6, P = 0.4, D = 0.6 },
		{ S = "Blip", Arp = { NOTE.C, NOTE.D, NOTE.E, NOTE.G, NOTE.A, NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3 }, Gap = 0.06, V = 0.4, D = 0.7, Fx = { Echo = true } },
	},
	RaceTick = {
		{ S = "Blip", V = 0.35, P = 1.6 },
	},
	RaceReveal = {
		{ S = "Boom", V = 0.5, P = 1, Fx = { Reverb = true } },
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2 }, Gap = 0.06, V = 0.4 },
	},
	RaceRevealLegend = {
		{ S = "Boom", V = 0.72, P = 0.45, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Rise", V = 0.7, P = 0.8 },
		{ S = "Blip", Chord = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2 }, V = 0.3, D = 0.15, Fx = { Distort = 0.15, Reverb = true } },
		{ S = "Blip", Arp = { NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3, NOTE.G2, NOTE.C3 }, Gap = 0.07, V = 0.4, D = 0.3, Fx = { Echo = true } },
	},
	Overdrive = {
		{ S = "Whoosh", V = 0.7, P = 0.5, Fx = { Reverb = true } },
		{ S = "Boom", V = 0.72, P = 0.35, D = 0.25, Fx = { Reverb = true, Bass = 6 } },
		-- "power chord sting"
		{ S = "Blip", Chord = { NOTE.C, NOTE.G, NOTE.C2 }, V = 0.45, D = 0.25, Fx = { Distort = 0.15, Reverb = true } },
		{ S = "Blip", Chord = { NOTE.D, NOTE.A, 2.245 }, V = 0.45, D = 0.5, Fx = { Distort = 0.15, Reverb = true } },
	},
	Zenkai = {
		{ S = "Boom", V = 0.9, P = 0.5, Fx = { Reverb = true, Bass = 8 } },
		{ S = "Blip", Chord = { NOTE.C, NOTE.G, NOTE.C2 }, V = 0.4, Fx = { Distort = 0.15 } },
	},
	PlotArmor = {
		{ S = "Blip", Arp = { NOTE.C3, NOTE.G2, NOTE.C3 }, Gap = 0.08, V = 0.5, Fx = { Echo = true } },
		{ S = "Thud", V = 0.7, P = 0.8 },
	},
	BossSpawn = {
		{ S = "Boom", V = 0.72, P = 0.3, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Boom", V = 0.8, P = 0.28, D = 0.45, Fx = { Reverb = true, Bass = 6 } },
	},
	BossSlam = {
		{ S = "Boom", V = 0.72, P = 0.65, Fx = { Bass = 8 } },
		{ S = "Thud", V = 0.9, P = 0.6 },
	},
	Telegraph = {
		{ S = "Blip", Arp = { 0.7, 0.7, 0.7 }, Gap = 0.25, V = 0.5 },
	},
	Hurt = {
		{ S = "Thud", V = 0.6, P = 0.75 },
		{ S = "Boom", V = 0.15, P = 3 },
	},
	-- tactile UI: a crisp "key press" tick with a soft low tap under it
	UIClick = {
		{ S = "Blip", V = 0.22, P = 2.9 },
		{ S = "Thud", V = 0.25, P = 3.3 },
	},
	UIHover = { { S = "Blip", V = 0.07, P = { 3.4, 3.6 } } },
	UIOpen = {
		{ S = "Whoosh", V = 0.1, P = 2.8 },
		{ S = "Blip", V = 0.16, P = 2.2 },
		{ S = "Blip", V = 0.12, P = 2.9, D = 0.05 },
	},
	UIClose = {
		{ S = "Whoosh", V = 0.08, P = 2.4 },
		{ S = "Blip", V = 0.14, P = 2.2 },
		{ S = "Blip", V = 0.1, P = 1.7, D = 0.05 },
	},
	-- footsteps (one-shot, per floor material)
	StepStone = {
		{ S = "Thud", V = 0.16, P = { 2.1, 2.4 }, Fx = { Treble = 3 } },
		{ S = "Blip", V = 0.02, P = { 4.6, 5 } },
	},
	StepGrass = {
		{ S = "Thud", V = 0.13, P = { 1.6, 1.9 }, Fx = { Muffle = true } },
		{ S = "Splash", V = 0.035, P = { 3.4, 3.8 }, Fx = { Muffle = true } },
	},
	StepWood = {
		{ S = "Thud", V = 0.2, P = { 1.35, 1.55 }, Fx = { Hollow = true } },
	},
	StepMetal = {
		{ S = "Thud", V = 0.15, P = { 2, 2.2 } },
		{ S = "Blip", V = 0.035, P = { 3.1, 3.4 }, Fx = { Echo = true } },
	},
	StepSoft = {
		{ S = "Thud", V = 0.1, P = { 1.4, 1.6 }, Fx = { Muffle = true } },
	},
	StepHeavy = {
		{ S = "Thud", V = 0.6, P = { 0.55, 0.65 }, Fx = { Bass = 8 } },
		{ S = "Boom", V = 0.15, P = { 0.9, 1 }, Fx = { Muffle = true } },
	},
	Error = { { S = "Blip", Arp = { 0.7, 0.6 }, Gap = 0.08, V = 0.45 } },
	Purchase = {
		{ S = "Blip", Arp = { NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3 }, Gap = 0.06, V = 0.45 },
		{ S = "Thud", V = 0.4, P = 1.4 },
	},
	Teleport = {
		{ S = "Splash", V = 0.4, P = 1.6 },
		{ S = "Whoosh", V = 0.4, P = 0.7 },
		{ S = "Blip", Arp = { NOTE.C3, NOTE.G2, NOTE.E2, NOTE.C2 }, Gap = 0.04, V = 0.3 },
	},
	PowerGain = { { S = "Blip", V = 0.18, P = { 1.7, 1.9 } } },
	TowerStart = {
		{ S = "Boom", V = 0.8, P = 0.5, Fx = { Reverb = true } },
		{ S = "Blip", Arp = { NOTE.C, NOTE.C, NOTE.G }, Gap = 0.15, V = 0.45 },
	},
	TowerWin = {
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2, NOTE.G, NOTE.C2 }, Gap = 0.08, V = 0.45, Fx = { Echo = true } },
		{ S = "Boom", V = 0.5, P = 1.2 },
	},
	TowerLose = {
		{ S = "Blip", Arp = { NOTE.G, NOTE.F, 1.189, NOTE.C }, Gap = 0.14, V = 0.45 },
	},
	Equip = { { S = "Unsheath", V = 0.5, P = 1 } },
	Discover = {
		{ S = "Rise", V = 0.5, P = 1.2 },
		{ S = "Blip", Arp = { NOTE.G, NOTE.C2, NOTE.E2, NOTE.G2 }, Gap = 0.08, V = 0.45, Fx = { Echo = true } },
	},
	Milestone = {
		{ S = "Boom", V = 0.6, P = 0.8, Fx = { Reverb = true } },
		{ S = "Blip", Arp = { NOTE.C, NOTE.G, NOTE.C2 }, Gap = 0.06, V = 0.4 },
	},
	Stage = {
		{ S = "Rise", V = 0.5, P = 0.9 },
		{ S = "Blip", Arp = { NOTE.G, NOTE.C2 }, Gap = 0.1, V = 0.4 },
	},
	-- weapons / abilities
	HeavySwing = {
		{ S = "Lunge", V = 0.6, P = { 0.7, 0.8 } },
		{ S = "Whoosh", V = 0.3, P = { 0.6, 0.7 } },
	},
	ScytheSwing = {
		{ S = "Slash", V = 0.5, P = { 0.75, 0.85 } },
		{ S = "Whoosh", V = 0.25, P = { 0.9, 1 } },
	},
	Punch = {
		{ S = "Whoosh", V = 0.25, P = { 2.2, 2.5 } },
		{ S = "Thud", V = 0.35, P = { 1.6, 1.9 } },
	},
	GunShot = {
		{ S = "Boom", V = 0.25, P = { 3.2, 3.6 } },
		{ S = "Blip", V = 0.2, P = { 3, 3.3 } },
	},
	SpiritShot = {
		{ S = "Blip", V = 0.35, P = { 2.4, 2.7 }, Fx = { Echo = true } },
		{ S = "Whoosh", V = 0.2, P = 2.4 },
	},
	CeroShot = {
		{ S = "Boom", V = 0.2, P = { 2.6, 3 } },
		{ S = "Blip", V = 0.15, P = { 1.9, 2.1 }, Fx = { Distort = 0.2 } },
	},
	Getsuga = {
		{ S = "Whoosh", V = 0.8, P = 0.45, Fx = { Reverb = true } },
		{ S = "Lunge", V = 0.7, P = 0.6 },
		{ S = "Boom", V = 0.8, P = 0.6, D = 0.05, Fx = { Bass = 8 } },
		{ S = "Blip", Chord = { NOTE.C, NOTE.G, NOTE.C2 }, V = 0.3, D = 0.05, Fx = { Distort = 0.12, Reverb = true } },
	},
	ChargeUp = {
		{ S = "Rise", V = 0.6, P = 1.4 },
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2, NOTE.E2 }, Gap = 0.2, V = 0.25 },
	},
	RasenganHit = {
		{ S = "Boom", V = 0.72, P = 0.5, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Splash", V = 0.7, P = 1.6 },
		{ S = "Whoosh", V = 0.6, P = 0.5 },
	},
	BigBlast = {
		{ S = "Boom", V = 0.9, P = 0.7, Fx = { Reverb = true, Bass = 8 } },
		{ S = "Whoosh", V = 0.5, P = 0.8 },
	},
	Vortex = {
		{ S = "Whoosh", V = 0.7, P = 0.35, Fx = { Reverb = true } },
		{ S = "Bubble", V = 0.5, P = 0.25 },
	},
	Dash = {
		{ S = "Whoosh", V = 0.5, P = { 1.3, 1.5 } },
	},
	Ultimate = {
		{ S = "Rise", V = 0.8, P = 0.7, Fx = { Reverb = true } },
		{ S = "Boom", V = 0.9, P = 0.45, D = 0.15, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Blip", Chord = { NOTE.C, NOTE.E, NOTE.G }, V = 0.35, D = 0.15, Fx = { Distort = 0.2, Reverb = true } },
	},
	NoStamina = { { S = "Blip", Arp = { 0.8, 0.7 }, Gap = 0.06, V = 0.3 } },
	EnemyWindup = {
		{ S = "Rise", V = 0.6, P = 0.6 },
		{ S = "Blip", Arp = { 0.9, 1, 1.12 }, Gap = 0.15, V = 0.3 },
	},
	-- loot / retention
	ChestTick = { { S = "Blip", V = 0.35, P = { 1.3, 1.5 } } },
	ChestOpen = {
		{ S = "Thud", V = 0.7, P = 0.9 },
		{ S = "Splash", V = 0.4, P = 1.4 },
	},
	PlaytimeReward = {
		{ S = "Blip", Arp = { NOTE.C, NOTE.E, NOTE.G, NOTE.C2, NOTE.E2 }, Gap = 0.07, V = 0.45, Fx = { Echo = true } },
		{ S = "Rise", V = 0.4, P = 1.3 },
	},
	PowerUp = {
		{ S = "Boom", V = 0.9, P = 0.5, Fx = { Reverb = true, Bass = 6 } },
		{ S = "Blip", Chord = { NOTE.C, NOTE.G, NOTE.C2 }, V = 0.4, D = 0.1, Fx = { Distort = 0.12 } },
		{ S = "Blip", Arp = { NOTE.C2, NOTE.E2, NOTE.G2, NOTE.C3 }, Gap = 0.06, V = 0.4, D = 0.3 },
	},
	Potion = {
		{ S = "Splash", V = 0.5, P = 1.5 },
		{ S = "Blip", Arp = { NOTE.E, NOTE.G, NOTE.C2 }, Gap = 0.08, V = 0.35 },
	},
	PromptShow = { { S = "Blip", V = 0.15, P = 2.4 } },
	PromptTrigger = { { S = "Blip", Arp = { NOTE.G, NOTE.C2 }, Gap = 0.05, V = 0.35 } },
}

---------------------------------------------------------------------
-- Sound groups (so the Settings panel can mute music / sfx separately)
---------------------------------------------------------------------
local function getGroup(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = volume
		g.Parent = SoundService
	end
	return g
end
local sfxGroup = getGroup("GameSFX", 0.55)
local musicGroup = getGroup("GameMusic", 0.3)

-- master bus: glue compressor + soft high cut (less harsh, more even)
if not sfxGroup:FindFirstChild("BusCompressor") then
	local comp = Instance.new("CompressorSoundEffect")
	comp.Name = "BusCompressor"
	comp.Threshold = -20
	comp.Ratio = 3
	comp.Attack = 0.01
	comp.Release = 0.18
	comp.GainMakeup = 0
	comp.Parent = sfxGroup
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "BusEQ"
	eq.LowGain = 1
	eq.MidGain = 0
	eq.HighGain = -4
	eq.Parent = sfxGroup
end

-- minimum seconds between two plays of the same cue (default 0.03)
local RATE = {
	Hit = 0.05, HitBlade = 0.05, HitBlunt = 0.05, HitEnergy = 0.05, Crit = 0.09, Kill = 0.07,
	Swing = 0.05, HeavySwing = 0.08, ScytheSwing = 0.06, Punch = 0.05, GunShot = 0.05, SpiritShot = 0.06, CeroShot = 0.05,
	OrePickup = 0.06, RarePickup = 0.15, Coins = 0.1, PowerGain = 0.1, Sell = 0.2,
	UIHover = 0.05, UIClick = 0.04, Telegraph = 0.2, EnemyWindup = 0.15, Hurt = 0.12, Stage = 0.2, Discover = 0.3,
	StepStone = 0.05, StepGrass = 0.05, StepWood = 0.05, StepMetal = 0.05, StepSoft = 0.05,
}
-- per-cue trim on top of the layer volumes (loud, frequent cues pulled down)
local TRIM = {
	Hit = 0.8, HitBlade = 0.8, HitBlunt = 0.75, HitEnergy = 0.8, Swing = 0.85, Kill = 0.8,
	BossSpawn = 0.7, BossKill = 0.75, Rebirth = 0.75, Overdrive = 0.7, Ultimate = 0.75, Telegraph = 0.6,
	PowerGain = 0.7, OrePickup = 0.8, UIClick = 0.8, UIHover = 0.7,
}
local lastPlayed: { [string]: number } = {}

function SFX.SetSFXVolume(v: number)
	sfxGroup.Volume = v
end
function SFX.SetMusicVolume(v: number)
	musicGroup.Volume = v
end

---------------------------------------------------------------------
local function resolve(key: string): (string, number)
	local override = Config.SoundOverrides and Config.SoundOverrides[key]
	if typeof(override) == "string" and override ~= "" then
		return override, 1
	end
	if unavailable[key] and FALLBACK[key] then
		local fb = FALLBACK[key]
		return SOURCES[fb[1]], fb[2]
	end
	return SOURCES[key] or SOURCES.Blip, 1
end

local function addFx(sound: Sound, fx)
	if not fx then
		return
	end
	if fx.Reverb then
		local r = Instance.new("ReverbSoundEffect")
		r.DecayTime = 1.6
		r.WetLevel = -4
		r.DryLevel = 0
		r.Parent = sound
	end
	if fx.Echo then
		local e = Instance.new("EchoSoundEffect")
		e.Delay = 0.12
		e.Feedback = 0.25
		e.WetLevel = -8
		e.Parent = sound
	end
	if fx.Distort then
		local d = Instance.new("DistortionSoundEffect")
		d.Level = fx.Distort
		d.Parent = sound
	end
	if fx.Bass then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = fx.Bass
		eq.MidGain = 0
		eq.HighGain = -2
		eq.Parent = sound
	end
	if fx.Treble then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -4
		eq.MidGain = 0
		eq.HighGain = fx.Treble
		eq.Parent = sound
	end
	if fx.Muffle then
		-- soft ground: cut the highs
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 2
		eq.MidGain = -4
		eq.HighGain = -18
		eq.Parent = sound
	end
	if fx.Hollow then
		-- wood: boosted mids for a hollow knock
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -2
		eq.MidGain = 6
		eq.HighGain = -6
		eq.Parent = sound
	end
end

local function pick(p): number
	if typeof(p) == "table" then
		return p[1] + math.random() * (p[2] - p[1])
	end
	return p or 1
end

local function makeParent(at): (Instance, Instance?)
	if typeof(at) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		return a, a
	elseif typeof(at) == "Instance" then
		return at, nil
	end
	return SoundService, nil
end

local function playOne(key: string, volume: number, pitch: number, parent: Instance, fx, positional: boolean)
	local id, pitchMul = resolve(key)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch * pitchMul
	s.SoundGroup = sfxGroup
	if positional then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
	end
	addFx(s, fx)
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	Debris:AddItem(s, 6)
end

-- SFX.Play("Hit", {At = position | part, Pitch = 1, Volume = 1})
function SFX.Play(name: string, opts)
	local cue = CUES[name]
	if not cue then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or -1) < (RATE[name] or 0.03) then
		return
	end
	lastPlayed[name] = now
	opts = opts or {}
	local volMul = (opts.Volume or 1) * (TRIM[name] or 1)
	local pitchMul = opts.Pitch or 1
	local parent, temp = makeParent(opts.At)
	local positional = parent ~= SoundService
	local longest = 0

	for _, layer in ipairs(cue) do
		local delay = layer.D or 0
		local vol = (layer.V or 0.5) * volMul
		if layer.Arp then
			local gap = layer.Gap or 0.06
			for i, p in ipairs(layer.Arp) do
				local t = delay + (i - 1) * gap
				longest = math.max(longest, t)
				task.delay(t, playOne, layer.S, vol, p * pitchMul, parent, layer.Fx, positional)
			end
		elseif layer.Chord then
			for _, p in ipairs(layer.Chord) do
				task.delay(delay, playOne, layer.S, vol, p * pitchMul, parent, layer.Fx, positional)
			end
		else
			longest = math.max(longest, delay)
			if delay > 0 then
				task.delay(delay, playOne, layer.S, vol, pick(layer.P) * pitchMul, parent, layer.Fx, positional)
			else
				playOne(layer.S, vol, pick(layer.P) * pitchMul, parent, layer.Fx, positional)
			end
		end
	end

	if temp then
		Debris:AddItem(temp, longest + 6)
	end
end

-- Looping ambient sound on a part (forge bubbling, portal hum...).
function SFX.Loop(sourceKey: string, parent: Instance, volume: number, pitch: number): Sound
	local id, pitchMul = resolve(sourceKey)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = volume
	s.PlaybackSpeed = pitch * pitchMul
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 90
	s.SoundGroup = sfxGroup
	s.Parent = parent
	s:Play()
	return s
end

---------------------------------------------------------------------
-- Music (optional; ids in Config.Music)
---------------------------------------------------------------------
local currentMusic: Sound? = nil
local currentMusicId = nil
function SFX.PlayMusic(assetId: number?)
	if assetId == currentMusicId then
		return
	end
	currentMusicId = assetId
	local old = currentMusic
	if old then
		local t = TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 })
		t:Play()
		t.Completed:Once(function()
			old:Destroy()
		end)
		currentMusic = nil
	end
	if not assetId or assetId == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(assetId)
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = 0.45 }):Play()
	currentMusic = s
end

---------------------------------------------------------------------
-- Preload + detect unavailable web assets (falls back automatically)
---------------------------------------------------------------------
function SFX.Init()
	task.spawn(function()
		local list = {}
		for key, id in pairs(SOURCES) do
			local s = Instance.new("Sound")
			s.Name = key
			s.SoundId = id
			table.insert(list, s)
		end
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId, status)
				if status ~= Enum.AssetFetchStatus.Success then
					for key, id in pairs(SOURCES) do
						if id == contentId then
							unavailable[key] = true
						end
					end
				end
			end)
		end)
		if not ok then
			warn("[SFX] preload failed:", err)
		end
		for _, s in ipairs(list) do
			s:Destroy()
		end
	end)
end

SFX.Sources = SOURCES
return SFX
