local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
RunService.Heartbeat:Connect(function()
	if not _G.AC_Data then return end
	local ct = tick()
	for p, d in pairs(_G.AC_Data) do
		d.lastNoclipCheck = d.lastNoclipCheck or 0
		if ct - d.lastNoclipCheck < 0.5 then continue end
		d.lastNoclipCheck = ct
		local c = p.Character
		if not c then continue end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum and hum.Sit then
			d.graceEnd = math.max(d.graceEnd or 0, ct + 4)
		end
		if d.graceEnd and ct < d.graceEnd then
			d.lastNoclipPos = nil
			d.noclipCount = 0
			continue
		end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end
		local pos = hrp.Position
		if not d.lastNoclipPos then
			d.lastNoclipPos = pos
			continue
		end
		local delta = pos - d.lastNoclipPos
		local xzDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if xzDist > 2 then
			local rParams = RaycastParams.new()
			rParams.FilterDescendantsInstances = {c}
			rParams.FilterType = Enum.RaycastFilterType.Exclude
			rParams.IgnoreWater = true
			local offset = Vector3.new(0, 2, 0)
			local startPos = d.lastNoclipPos + offset
			local endPos = pos + offset
			local dir = endPos - startPos
			local hitForward = Workspace:Raycast(startPos, dir, rParams)
			if hitForward and hitForward.Instance and hitForward.Instance.CanCollide then
				local hitBackward = Workspace:Raycast(endPos, -dir, rParams)
				if hitBackward and hitBackward.Instance and hitBackward.Instance.CanCollide then
					d.noclipCount = (d.noclipCount or 0) + 1
					if d.noclipCount > 5 then
						local ts = p:GetAttribute("TrustScore") or 100
						local newTs = math.max(0, ts - 15)
						p:SetAttribute("TrustScore", newTs)
						if _G.AC_Data[p] then _G.AC_Data[p].ts = newTs end
						if _G.AC_AddFlag then _G.AC_AddFlag(p, "NOCLIP", 18) end
						d.noclipCount = 0
					end
				else
					d.noclipCount = math.max(0, (d.noclipCount or 0) - 1)
				end
			else
				d.noclipCount = math.max(0, (d.noclipCount or 0) - 1)
			end
		end
		d.lastNoclipPos = pos
	end
end)