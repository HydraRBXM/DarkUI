local origRaycast = util.Raycast
util.Raycast = function(self, origin, direction, dist, ...)
	if s_active and not isLobby() and aimActive() then
		local target = getTarget(origin.X, origin.Y, origin.Z)
		if target and mrand(100) <= s_accuracy then
			local hrp = target.Parent:FindFirstChild("HumanoidRootPart")
			local vel = hrp and hrp.AssemblyLinearVelocity or ZERO3

			local tx = target.Position.X
			local ty = target.Position.Y
			local tz = target.Position.Z

			-- step 1: estimate where target is right now accounting for ping
			local ping = getPing()
			local px = tx + vel.X * ping
			local py = ty + vel.Y * ping
			local pz = tz + vel.Z * ping

			-- step 2: bullet travel time from origin to predicted pos
			local dx = px - origin.X
			local dy = py - origin.Y
			local dz = pz - origin.Z
			local travelTime = msqrt(dx*dx + dy*dy + dz*dz) / 300

			-- step 3: add bullet travel on top of ping prediction
			local fx = px + vel.X * travelTime
			local fy = py + vel.Y * travelTime
			local fz = pz + vel.Z * travelTime

			-- step 4: iterate once more for precision (UE style second pass)
			local dx2 = fx - origin.X
			local dy2 = fy - origin.Y
			local dz2 = fz - origin.Z
			local travelTime2 = msqrt(dx2*dx2 + dy2*dy2 + dz2*dz2) / 300

			local finalX = tx + vel.X * (ping + travelTime2)
			local finalY = ty + vel.Y * (ping + travelTime2)
			local finalZ = tz + vel.Z * (ping + travelTime2)

			return origRaycast(self, origin, Vector3.new(finalX, finalY, finalZ), dist, ...)
		end
	end
	return origRaycast(self, origin, direction, dist, ...)
end
