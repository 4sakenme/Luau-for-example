local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local function raycastGround(hrp, char)
	local rParams = RaycastParams.new()
	rParams.FilterDescendantsInstances = {char}
	rParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayHit = Workspace:Raycast(hrp.Position, Vector3.new(0, -9, 0), rParams)
	return rayHit ~= nil
end
RunService.Heartbeat:Connect(function()
	if not _G.AC_Data then return end
	local ct = tick()
	for p, d in pairs(_G.AC_Data) do
		local c = p.Character
		if not c then continue end
		local hrp = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then continue end
		if hum.Sit then
			d.graceEnd = math.max(d.graceEnd or 0, ct + 4)
		end
		if d.graceEnd and ct < d.graceEnd then
			d.lastFlyCheck = ct
			continue
		end
		local state = hum:GetState()
		local isClimbing = state == Enum.HumanoidStateType.Climbing
		local isSwimming = state == Enum.HumanoidStateType.Swimming
		if isClimbing or isSwimming or hum.Sit then
			d.inAirTime = 0
			d.lastFlyCheck = ct
			continue
		end
		local onGround = (hum.FloorMaterial ~= Enum.Material.Air) or raycastGround(hrp, c)
		local vel = hrp.AssemblyLinearVelocity
		local yVel = vel.Y
		local hasForce = false
		for _, descendant in ipairs(c:GetDescendants()) do
			if descendant:IsA("BodyForce") or descendant:IsA("BodyVelocity") or descendant:IsA("LinearVelocity") or descendant:IsA("AlignPosition") or descendant:IsA("VectorForce") then
				hasForce = true
				break
			end
		end
		if not onGround and not hasForce then
			local dt = ct - (d.lastFlyCheck or ct)
			if yVel >= -5 then
				d.inAirTime = (d.inAirTime or 0) + dt
				if d.inAirTime > 2.5 then
					local ts = p:GetAttribute("TrustScore") or 100
					local newTs = math.max(0, ts - 15)
					p:SetAttribute("TrustScore", newTs)
					if _G.AC_Data[p] then _G.AC_Data[p].ts = newTs end
					if _G.AC_AddFlag then _G.AC_AddFlag(p, "FLY_HACK", 20) end
					d.inAirTime = 0
				end
			else
				d.inAirTime = math.max(0, (d.inAirTime or 0) - dt * 2)
			end
		else
			d.inAirTime = 0
		end
		d.lastFlyCheck = ct
	end
end)