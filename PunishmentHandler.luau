local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local KICK_MSG = GameConfig.ANTI_CHEAT.KICK_MESSAGE
local WARN_TS = GameConfig.ANTI_CHEAT.WARN_TRUST
local THROTTLE_TS = GameConfig.ANTI_CHEAT.THROTTLE_TRUST
local KICK_TS = GameConfig.ANTI_CHEAT.TRUST_KICK_THRESHOLD
local NN_THRESHOLD = GameConfig.ANTI_CHEAT.NN_THRESHOLD
local CHAIN_KICK_SCORE = 80

local warned = {}
local throttled = {}
local throttleCounters = {}

local function getTrustScore(player)
	return player:GetAttribute("TrustScore") or 100
end

local function setTrustScore(player, val)
	player:SetAttribute("TrustScore", val)
	if _G.AC_Data and _G.AC_Data[player] then
		_G.AC_Data[player].ts = val
	end
end

local function kickPlayer(player)
	if not player.Parent then return end
	if _G.AC_AddFlag then
		_G.AC_AddFlag(player, "KICKED", 100)
	end
	warned[player] = nil
	throttled[player] = nil
	throttleCounters[player] = nil
	player:Kick(KICK_MSG)
end

local function evaluate(player)
	local ts = getTrustScore(player)
	local flagScore = 0
	local chainScore = 0

	if _G.AC_GetWeightedScore then
		flagScore = _G.AC_GetWeightedScore(player)
	end
	if _G.AC_GetChainScore then
		chainScore = _G.AC_GetChainScore(player)
	end

	local nnOut = 0
	if _G.AC_Data and _G.AC_Data[player] then
		nnOut = _G.AC_Data[player].lastNNOut or 0
	end

	if flagScore < 5 and nnOut < 0.75 then
		return "CLEAN"
	end

	if ts <= 0 or chainScore > CHAIN_KICK_SCORE then
		return "KICK"
	end

	if nnOut > NN_THRESHOLD and ts < KICK_TS then
		return "KICK"
	end

	if flagScore > 60 and ts < 40 then
		return "KICK"
	end

	if ts < KICK_TS then
		return "KICK"
	end

	if ts < THROTTLE_TS then
		return "THROTTLE"
	end

	if ts < WARN_TS then
		return "WARN"
	end

	return "CLEAN"
end

local function applyPunishment(player, action)
	if action == "KICK" then
		kickPlayer(player)
		return
	end

	if action == "THROTTLE" then
		if not throttled[player] then
			throttled[player] = true
			throttleCounters[player] = 0
		end
		throttleCounters[player] = throttleCounters[player] + 1

		if throttleCounters[player] > 5 then
			kickPlayer(player)
			return
		end

		local ts = getTrustScore(player)
		setTrustScore(player, math.max(0, ts - 3))
		return
	end

	if action == "WARN" then
		if not warned[player] then
			warned[player] = true
			local rs = game:GetService("ReplicatedStorage")
			local roundEvents = rs:FindFirstChild("RoundEvents")
			if roundEvents then
				local updateStatus = roundEvents:FindFirstChild("UpdateStatus")
				if updateStatus then
					updateStatus:FireClient(player, "Anti-Cheat Warning")
				end
			end
		end
		return
	end

	if action == "CLEAN" then
		warned[player] = nil
		throttled[player] = nil
		throttleCounters[player] = nil
		local ts = getTrustScore(player)
		if ts < 100 then
			setTrustScore(player, math.min(100, ts + 0.2))
		end
	end
end

Players.PlayerRemoving:Connect(function(p)
	warned[p] = nil
	throttled[p] = nil
	throttleCounters[p] = nil
end)

local lastPunishCheck = 0

RunService.Heartbeat:Connect(function()
	if not _G.AC_Data then return end

	local ct = tick()
	if ct - lastPunishCheck < 2 then return end
	lastPunishCheck = ct

	for p, _ in pairs(_G.AC_Data) do
		if not p.Parent then continue end
		local action = evaluate(p)
		applyPunishment(p, action)
	end
end)