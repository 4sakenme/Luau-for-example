local Players = game:GetService("Players")
_G.AC_Flags = _G.AC_Flags or {}
local function dfsChain(flags, startIdx, visited)
	local chain = {flags[startIdx]}
	visited[startIdx] = true
	local stack = {startIdx}
	local head = 1
	while head <= #stack do
		local curr = stack[head]
		head = head + 1
		for i, f in ipairs(flags) do
			if not visited[i] then
				local timeDiff = f.time - flags[curr].time
				if timeDiff > 0 and timeDiff < 5 then
					visited[i] = true
					table.insert(chain, f)
					table.insert(stack, i)
				end
			end
		end
	end
	return chain
end
local function addFlag(player, flagType, severity)
	if not _G.AC_Flags[player] then _G.AC_Flags[player] = {} end
	local flag = {
		t = flagType,
		s = severity,
		time = tick()
	}
	table.insert(_G.AC_Flags[player], flag)
	if #_G.AC_Flags[player] > 64 then
		local now = tick()
		local cleaned = {}
		for _, f in ipairs(_G.AC_Flags[player]) do
			if now - f.time < 120 then
				table.insert(cleaned, f)
			end
		end
		_G.AC_Flags[player] = cleaned
	end
end
local function getWeightedScore(player)
	local flags = _G.AC_Flags[player]
	if not flags then return 0 end
	local now = tick()
	local score = 0
	for _, f in ipairs(flags) do
		local age = now - f.time
		local decay = math.exp(-age / 60)
		score = score + f.s * decay
	end
	return score
end
local function getTopFlags(player, count)
	local flags = _G.AC_Flags[player]
	if not flags then return {} end
	local temp = {}
	for _, f in ipairs(flags) do
		table.insert(temp, {s = f.s, t = f.t, time = f.time})
	end
	table.sort(temp, function(a, b) return a.s > b.s end)
	local result = {}
	for i = 1, math.min(count, #temp) do
		table.insert(result, temp[i])
	end
	return result
end
local function detectChains(player)
	local flags = _G.AC_Flags[player]
	if not flags or #flags < 3 then return {} end
	local copy = {}
	for _, f in ipairs(flags) do table.insert(copy, f) end
	table.sort(copy, function(a, b) return a.time < b.time end)
	local visited = {}
	local chains = {}
	for i = 1, #copy do
		if not visited[i] then
			local chain = dfsChain(copy, i, visited)
			if #chain >= 3 then
				table.insert(chains, chain)
			end
		end
	end
	return chains
end
local function getChainScore(player)
	local chains = detectChains(player)
	local totalScore = 0
	for _, chain in ipairs(chains) do
		local chainWeight = #chain * 2.5
		for _, f in ipairs(chain) do
			totalScore = totalScore + f.s * chainWeight
		end
	end
	return totalScore
end
_G.AC_AddFlag = addFlag
_G.AC_GetWeightedScore = getWeightedScore
_G.AC_GetTopFlags = getTopFlags
_G.AC_DetectChains = detectChains
_G.AC_GetChainScore = getChainScore