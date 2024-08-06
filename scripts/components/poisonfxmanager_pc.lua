
local PoisonFxManager = Class(function(self, inst) 
	self.inst = inst
    self.ismastersim = TheWorld.ismastersim --是主机
    self.inst.pool = { valid = true, ents = {}, active_ents = {} }

    inst.generatedfx = {}

    if not TheNet:IsDedicated() then
        self.inst:StartUpdatingComponent(self)
    else
        self.inst:StopUpdatingComponent(self)
    end
end)

local function GetPooledFx(inst, prefab, pool)
	local fx = table.remove(pool.ents)
	if fx ~= nil then
        if fx.index_x then
            inst.generatedfx[fx.index_x][fx.index_z] = nil
        end
	else
		fx = SpawnPrefab(prefab)
		fx.pool = pool
	end
    pool.active_ents[fx] = true
	return fx
end

local function ClearPoolEnts(ents)
	for i = 1, #ents do
		ents[i]:Remove()
		ents[i] = nil
	end
end

local function IsPointInPoisonousCircle(x, y, z)
    local circle = TheWorld.net.components.poisonouscircle_pc
    local pos = circle.bigPos
    if VecUtil_Dist(x, z, pos.x, pos.y) >= pos.r + 4 then
        return true
    end
end

function PoisonFxManager:OnUpdate(dt)
    if not ThePlayer or not ThePlayer:IsValid() then return end
    for k, v in pairs(self.inst.pool.active_ents) do
        k:OnUpdate()
    end
    local x, y, z = ThePlayer.Transform:GetWorldPosition()
    local tx, ty, tz = TheWorld.Map:GetTileCenterPoint(x, y, z)
    local w, h = TheWorld.Map:GetSize()
    if not tx then return end
    for i = tx - 40, tx + 40, 4 do
        for j = tz - 40, tz + 40, 4 do
            if IsPointInPoisonousCircle(i, 0, j) and ThePlayer:GetDistanceSqToPoint(i, 0, j) < 42 * 42 
            and ((i - (w % 2) * 2) / 4) % 2 == 0 and ((j - (w % 2) * 2) / 4) % 2 == 0 then
                if self.inst.generatedfx == nil then
                    self.inst.generatedfx = {}
                end
                if self.inst.generatedfx[i] == nil then self.inst.generatedfx[i] = {} end
                if self.inst.generatedfx[i] and self.inst.generatedfx[i][j] ~= true then
                    self.inst.generatedfx[i][j] = true
                    local cloud = GetPooledFx(self.inst, "poison_miasma_cloud", self.inst.pool)
                    cloud.Transform:SetPosition(i, 0, j)
                    cloud:OnChangePlace()
                    cloud.index_x = i
                    cloud.index_z = j
                end
            end
        end
    end
end

return PoisonFxManager