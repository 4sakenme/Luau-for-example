local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

_G.AC_Data = _G.AC_Data or {}
_G.AC_Locks = _G.AC_Locks or {}
_G.AC_Flags = _G.AC_Flags or {}

local HIST = 32
local MAX_XZ = 50
local MAX_Y = 180
local MAX_ACC = 400
local Z_THRESH = 3.2
local NN_KICK = 0.92
local TS_KICK = 30
local LOCK_TIMEOUT = 0.5

local W1 = { 
	{0.55, -0.18, 0.42, 0.31, -0.27, 0.15},
	{-0.12, 0.78, -0.35, 0.22, 0.45, -0.08},
	{0.48, 0.15, -0.62, -0.38, 0.55, 0.28},
	{-0.33, 0.62, 0.18, -0.45, 0.72, -0.22},
	{0.25, -0.42, 0.55, 0.68, -0.15, 0.38},
	{-0.48, 0.28, -0.52, 0.35, 0.42, -0.65},
	{0.72, -0.55, 0.32, -0.18, 0.58, 0.22},
	{-0.22, 0.45, -0.28, 0.52, -0.38, 0.72}
}
local B1 = {-0.15, -0.08, -0.22, 0.05, -0.12, -0.18, 0.08, -0.05}

local W2 = {
	{0.65, -0.32, 0.48, -0.22, 0.55, -0.18, 0.42, -0.28},
	{-0.42, 0.58, -0.15, 0.72, -0.35, 0.48, -0.22, 0.65},
	{0.38, -0.48, 0.62, -0.28, 0.55, -0.42, 0.32, -0.55},
	{-0.55, 0.22, -0.38, 0.65, -0.18, 0.72, -0.48, 0.35}
}
local B2 = {-0.12, 0.08, -0.18, 0.05}

local W3 = {{0.72, -0.45, 0.58, -0.32}}
local B3 = {-0.25}

local function lReLU(x) return x > 0 and x or 0.01 * x end
local function sig(x) return 1 / (1 + math.exp(-math.max(-20, math.min(20, x)))) end

local function mmul(mat, vec, bias, act)
	local res = {}
	for i = 1, #mat do
		local s = bias[i]
		for j = 1, #vec do s = s + mat[i][j] * vec[j] end
		table.insert(res, act(s))
	end
	return res
end

local function nnEval(emaV, zScore, tsDelta, posVar, accSpike, remFreq)
	local inp = {
		math.min(1, emaV / 25),
		math.min(1, zScore / 6),
		math.min(1, math.abs(tsDelta) / 15),
		math.min(1, posVar / 50),
		math.min(1, accSpike / 10),
		math.min(1, remFreq / 8)
	}
	local h1 = mmul(W1, inp, B1, lReLU)
	local h2 = mmul(W2, h1, B2, lReLU)
	return mmul(W3, h2, B3, sig)[1]
end

local function addFlag(player, flagType, severity)
	if _G.AC_AddFlag then
		_G.AC_AddFlag(player, flagType, severity)
	else
		if not _G.AC_Flags[player] then _G.AC_Flags[player] = {} end
		local flags = _G.AC_Flags[player]
		table.insert(flags, {
			t = flagType,
			s = severity,
			time = tick()
		})
		if #flags > 64 then
			local cleaned = {}
			local cutoff = tick() - 120
			for _, f in ipairs(flags) do
				if f.time > cutoff then
					table.insert(cleaned, f)
				end
			end
			_G.AC_Flags[player] = cleaned
		end
	end
end

local function initPlayer(player)
	_G.AC_Data[player] = {
		idx = 1,
		velHist = table.create(HIST, 0),
		accHist = table.create(HIST, 0),
		lT = tick(),
		lP = Vector3.new(),
		lV = 0,
		emaV = 0,
		emaA = 0,
		ts = 100,
		graceEnd = tick() + 2,
		sampleCount = 0,
		rem = {},
		posVar = 0,
		accSpike = 0,
		remFreq = 0,
		lastNNOut = 0,
		g = {},
		gIdx = 1 
	}
	_G.AC_Flags[player] = {}
	player:SetAttribute("TrustScore", 100)
end

Players.PlayerAdded:Connect(function(p)
	initPlayer(p)
	p.CharacterAdded:Connect(function(c)
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		local d = _G.AC_Data[p]
		if not d then initPlayer(p) d = _G.AC_Data[p] end

		d.idx = 1
		d.lT = tick()
		d.lP = Vector3.new()
		d.lV = 0
		d.emaV = 0
		d.emaA = 0
		d.velHist = table.create(HIST, 0)
		d.accHist = table.create(HIST, 0)
		d.graceEnd = tick() + 2
		d.sampleCount = 0
		d.posVar = 0
		d.accSpike = 0
		d.remFreq = 0
		d.lastNNOut = 0
		d.g = {}
		d.gIdx = 1

		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Seated
				or new == Enum.HumanoidStateType.Jumping
				or new == Enum.HumanoidStateType.Freefall then
				if _G.AC_Data[p] then
					_G.AC_Data[p].graceEnd = tick() + 0.8
				end
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	_G.AC_Data[p] = nil
	_G.AC_Flags[p] = nil
	_G.AC_Locks[p] = nil
end)

for _, p in ipairs(Players:GetPlayers()) do
	initPlayer(p)
end

RunService.Heartbeat:Connect(function()
	local ct = tick()
	for p, d in pairs(_G.AC_Data) do
		if not p.Parent then
			_G.AC_Data[p] = nil
			_G.AC_Flags[p] = nil
			continue
		end

		local dt = ct - d.lT
		if dt < 0.1 then continue end

		local c = p.Character
		if not c then continue end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local pos = hrp.Position

		if d.graceEnd and ct < d.graceEnd then
			d.lP = pos
			d.lT = ct
			continue
		end

		if d.lP.Magnitude < 0.01 then
			d.lP = pos
			d.lT = ct
			continue
		end

		local df = pos - d.lP
		local xzVel = Vector3.new(df.X, 0, df.Z).Magnitude / dt
		local yVel = math.max(0, df.Y) / dt
		local rawVel = xzVel
		local rawAcc = math.abs(rawVel - d.lV) / dt

		if xzVel > MAX_XZ or yVel > MAX_Y or rawAcc > MAX_ACC then
			addFlag(p, "INSTANT_VIOLATION", 25)
			d.ts = math.max(0, d.ts - 20)
			p:SetAttribute("TrustScore", d.ts)
		end

		local alpha = 2 / (HIST + 1)
		d.emaV = (rawVel * alpha) + (d.emaV * (1 - alpha))
		d.emaA = (rawAcc * alpha) + (d.emaA * (1 - alpha))

		if rawAcc > 80 then d.accSpike = d.accSpike + 1 end

		local ringIdx = (d.idx % HIST) + 1
		d.velHist[ringIdx] = rawVel
		d.accHist[ringIdx] = rawAcc
		d.idx = ringIdx
		d.sampleCount = (d.sampleCount or 0) + 1

		local posDelta = (pos - d.lP).Magnitude
		d.posVar = d.posVar * 0.95 + posDelta * 0.05

		if d.sampleCount >= HIST then
			local sumV, sumSqV = 0, 0
			for i = 1, HIST do
				local v = d.velHist[i]
				sumV = sumV + v
				sumSqV = sumSqV + (v * v)
			end

			local meanV = sumV / HIST
			local varV = (sumSqV / HIST) - (meanV * meanV)
			local stdV = math.sqrt(math.max(64, varV))
			local zScore = (rawVel - meanV) / stdV

			if zScore > Z_THRESH and rawVel > 28 then
				d.ts = math.max(0, d.ts - 8)
				addFlag(p, "Z_SCORE_SPIKE", 12)
			elseif zScore < 1.5 and rawVel < 20 then
				d.ts = math.min(100, d.ts + 0.5)
			end

			p:SetAttribute("TrustScore", d.ts)

			local tsDelta = d.ts - 100
			local nnOut = nnEval(d.emaV, zScore, tsDelta, d.posVar, d.accSpike, d.remFreq)
			d.lastNNOut = nnOut

			if nnOut > 0.75 then
				addFlag(p, "NN_SUSPECT", math.floor(nnOut * 20))
				d.ts = math.max(0, d.ts - 5)
				p:SetAttribute("TrustScore", d.ts)
			end

			d.accSpike = math.max(0, d.accSpike - 1)
			d.remFreq = math.max(0, d.remFreq - 0.5)
		end

		local nodeId = d.gIdx
		d.gIdx = nodeId + 1
		local node = {id = nodeId, p = pos, t = ct, e = {}}

		if d.g[nodeId - 1] then
			table.insert(d.g[nodeId - 1].e, node)
			table.insert(node.e, d.g[nodeId - 1])
		end

		d.g[nodeId] = node

		if d.gIdx > 60 then
			local old = d.g[d.gIdx - 60]
			if old then
				for _, nb in ipairs(old.e) do
					for i, back in ipairs(nb.e) do
						if back.id == old.id then
							table.remove(nb.e, i)
							break
						end
					end
				end
				d.g[d.gIdx - 60] = nil
			end
		end

		d.lP = pos
		d.lT = ct
		d.lV = d.emaV
	end
end)