local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local function addFlag(player, flagType, severity)
	if _G.AC_AddFlag then
		_G.AC_AddFlag(player, flagType, severity)
	elseif _G.AC_Flags then
		if not _G.AC_Flags[player] then _G.AC_Flags[player] = {} end
		table.insert(_G.AC_Flags[player], {t = flagType, s = severity, time = tick()})
	end
end
local function getPathLength(d, depth)
	local dist = 0
	local currIdx = d.gIdx - 1
	for i = 1, depth do
		local curr = d.g[currIdx]
		local prev = d.g[currIdx - 1]
		if not curr or not prev then break end
		local df = curr.p - prev.p
		dist = dist + Vector3.new(df.X, 0, df.Z).Magnitude
		currIdx = currIdx - 1
	end
	return dist
end
local function detectInstantTeleport(d)
	if d.gIdx < 2 then return false end
	local curr = d.g[d.gIdx - 1]
	local prev = d.g[d.gIdx - 2]
	if not curr or not prev then return false end
	local dt = math.abs(curr.t - prev.t)
	if dt < 0.01 or dt > 2 then return false end
	local dist = (curr.p - prev.p).Magnitude
	local speed = dist / dt
	return speed > 350
end
RunService.Heartbeat:Connect(function()
	if not _G.AC_Data then return end
	local ct = tick()
	for p, d in pairs(_G.AC_Data) do
		if not p.Parent then continue end
		if d.gIdx < 3 then continue end
		if not d.g[d.gIdx - 1] then continue end
		d.lastTpCheck = d.lastTpCheck or 0
		if ct - d.lastTpCheck < 0.5 then continue end
		d.lastTpCheck = ct
		local c = p.Character
		local inGrace = false
		if d.graceEnd and ct < d.graceEnd then inGrace = true end
		if c then
			local hum = c:FindFirstChildOfClass("Humanoid")
			if hum then
				if hum.Sit then
					d.graceEnd = math.max(d.graceEnd or 0, ct + 2.5)
					inGrace = true
				end
			end
		end
		if inGrace then continue end
		local ts = p:GetAttribute("TrustScore") or 100
		local ping = p:GetNetworkPing() * 1000
		local pingBonus = math.min(25, ping / 40)
		if detectInstantTeleport(d) then
			addFlag(p, "INSTANT_TP", 30)
			local newTs = math.max(0, ts - 20)
			p:SetAttribute("TrustScore", newTs)
			if _G.AC_Data[p] then _G.AC_Data[p].ts = newTs end
			continue
		end
		local dist = getPathLength(d, 4)
		local maxAllowed = 75 + (ts / 100) * 35 + pingBonus
		if dist > maxAllowed then
			addFlag(p, "TELEPORT", 22)
			local newTs = math.max(0, ts - 14)
			p:SetAttribute("TrustScore", newTs)
			if _G.AC_Data[p] then _G.AC_Data[p].ts = newTs end
		end
	end
end)