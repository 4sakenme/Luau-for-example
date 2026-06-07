local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BUCKET_CAP = 15
local REFILL_RT = 0.5
local SLIDE_WINDOW = 10
local SLIDE_MAX = 30
local WHITELIST = {
	["SpectateEvents"] = true,
	["CombatEvents"] = true,
	["RoundEvents"] = true,
	["UpdateMouse"] = true,
	["CameraMove"] = true,
	["BuyItemEvent"] = true,
	["EquipItemEvent"] = true,
	["GeneratorFixed"] = true,
	["StartSkillCheck"] = true,
	["StatusEvent"] = true
}

local function addFlag(player, flagType, severity)
	if _G.AC_AddFlag then
		_G.AC_AddFlag(player, flagType, severity)
	elseif _G.AC_Flags then
		if not _G.AC_Flags[player] then _G.AC_Flags[player] = {} end
		table.insert(_G.AC_Flags[player], {t = flagType, s = severity, time = tick()})
	end
end

local function hookRemote(rm)
	if WHITELIST[rm.Name] or (rm.Parent and WHITELIST[rm.Parent.Name]) then return end
	rm.OnServerEvent:Connect(function(p, ...)
		if not _G.AC_Data or not _G.AC_Data[p] then return end
		local d = _G.AC_Data[p]
		local ct = tick()
		d.rem[rm.Name] = d.rem[rm.Name] or {tk = BUCKET_CAP, lt = ct, slide = {}}
		local st = d.rem[rm.Name]
		local dt = ct - st.lt
		st.tk = math.min(BUCKET_CAP, st.tk + dt * REFILL_RT)
		st.lt = ct
		table.insert(st.slide, ct)
		while #st.slide > 0 and (ct - st.slide[1]) > SLIDE_WINDOW do
			table.remove(st.slide, 1)
		end
		if #st.slide > SLIDE_MAX then
			addFlag(p, "REMOTE_SPAM", 15)
			local ts = p:GetAttribute("TrustScore") or 100
			local newTs = math.max(0, ts - 10)
			p:SetAttribute("TrustScore", newTs)
			if _G.AC_Data[p] then
				_G.AC_Data[p].ts = newTs
				_G.AC_Data[p].remFreq = (_G.AC_Data[p].remFreq or 0) + 1
			end
			if newTs <= 0 then
				p:SetAttribute("TrustScore", 0)
				p:Kick("Mày tày r?i, dám cheat, cook")
			end
			return
		end
		if st.tk >= 1 then
			st.tk = st.tk - 1
		else
			addFlag(p, "REMOTE_RATE", 10)
			local ts = p:GetAttribute("TrustScore") or 100
			if ts > 0 then
				local newTs = math.max(0, ts - 8)
				p:SetAttribute("TrustScore", newTs)
				if _G.AC_Data[p] then
					_G.AC_Data[p].ts = newTs
					_G.AC_Data[p].remFreq = (_G.AC_Data[p].remFreq or 0) + 1
				end
			else
				p:SetAttribute("TrustScore", 0)
				p:Kick("Mày tày r?i, dám cheat, cook")
			end
		end
	end)
end

for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
	if v:IsA("RemoteEvent") then hookRemote(v) end
end
ReplicatedStorage.DescendantAdded:Connect(function(v)
	if v:IsA("RemoteEvent") then hookRemote(v) end
end)
