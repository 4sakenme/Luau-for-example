local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local function bfsMaxSpeed(startNode, gTable)
	local maxSpd = 0
	for _, nb in pairs(gTable) do
		local dt = math.abs(startNode.t - nb.t)
		if dt >= 0.5 and dt <= 3 then
			local df = startNode.p - nb.p
			local spd = Vector3.new(df.X, 0, df.Z).Magnitude / dt
			if spd > maxSpd then maxSpd = spd end
		end
	end
	return maxSpd
end
RunService.Heartbeat:Connect(function()
	if not _G.AC_Data then return end
	local ct = tick()
	for p, d in pairs(_G.AC_Data) do
		local c = p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum and hum.Sit then
			d.graceEnd = math.max(d.graceEnd or 0, ct + 4)
		end
		if d.graceEnd and ct < d.graceEnd then continue end
		if d.gIdx < 3 or not d.g[d.gIdx - 1] then continue end
		local ms = bfsMaxSpeed(d.g[d.gIdx - 1], d.g)
		d.ksEst = d.ksEst or 0
		d.ksErr = d.ksErr or 1
		local kg = d.ksErr / (d.ksErr + 4)
		d.ksEst = d.ksEst + kg * (ms - d.ksEst)
		d.ksErr = (1 - kg) * d.ksErr + 0.1
		local ts = p:GetAttribute("TrustScore") or 100
		local speedBonus = (hum and hum.WalkSpeed > 16) and (hum.WalkSpeed - 16) or 0
		local pingBonus = math.min(15, (p:GetNetworkPing() * 1000) / 40)
		local thresh = 24 + speedBonus + pingBonus
		if d.ksEst > thresh then
			local newTs = math.max(0, ts - 10)
			p:SetAttribute("TrustScore", newTs)
			if _G.AC_Data[p] then _G.AC_Data[p].ts = newTs end
			if _G.AC_AddFlag then _G.AC_AddFlag(p, "SPEED_HACK", 12) end
			d.ksEst = 0
		end
	end
end