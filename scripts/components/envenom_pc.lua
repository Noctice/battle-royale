local Envenom = Class(function(self, inst) 
	self.inst = inst

    self.frequency = 2  -- 2秒检查一次
    self.last_time = 0  -- 累计时间

    self.inst:DoTaskInTime(0, function() 
        self.inst:StartUpdatingComponent(self)
    end)

    -- 注册监听开始毒圈、死亡、复活事件 暂停和恢复 检查
    self.inst:ListenForEvent("death", function()
        --self.inst:StopUpdatingComponent(self)
    end)
    self.inst:ListenForEvent("respawnfromghost", function()
        self.last_time = 0
        if TheWorld.net.components.poisonouscircle_pc.state:value() then
            self.inst:StartUpdatingComponent(self)
        end
    end)
    -- 正式开始了
    self.inst:ListenForEvent("startpoisonouscircle", function()
        self.last_time = 0
        self.inst:StartUpdatingComponent(self)
    end, TheWorld)
    -- 结束了
    self.inst:ListenForEvent("discontinuepoisonouscircle", function()
        self.last_time = 0
        --self.inst:StopUpdatingComponent(self)
    end, TheWorld)
end)

-- 判断在毒圈里
function Envenom:IsInPoisonousCircle()
    local circle = TheWorld.net.components.poisonouscircle_pc
    local pos = circle.bigPos
    local x, y, z = self.inst.Transform:GetWorldPosition()
    if VecUtil_Dist(x, z, pos.x, pos.y) >= pos.r then
        return true
    end
end

local function DoHurtSound(inst)
    if inst.hurtsoundoverride ~= nil then
        inst.SoundEmitter:PlaySound(inst.hurtsoundoverride, nil, inst.hurtsoundvolume)
    elseif not inst:HasTag("mime") then
        inst.SoundEmitter:PlaySound((inst.talker_path_override or "dontstarve/characters/")..(inst.soundsname or inst.prefab).."/hurt", nil, inst.hurtsoundvolume)
    end
end

function Envenom:OnUpdate(dt)
    if self.last_time >= self.frequency then
        self.last_time = 0
        if self:IsInPoisonousCircle() then
            -- 判断一下玩家是鬼魂状态吗
            if self.inst and self.inst:IsValid() and (self.inst.components.health == nil or self.inst.components.health:IsDead()) then
                --self.inst:StopUpdatingComponent(self)
                return
            end
            local circle = TheWorld.net.components.poisonouscircle_pc
            if circle and self.inst and not self.inst:HasTag("playerghost") then
                local damage = circle.current and circle.current.damage or 1
                local invincible = self.inst.components.health:IsInvincible()
                self.inst.components.health:SetInvincible(false)
                self.inst.components.health:DoDelta(-damage * self.frequency / 2)
                if self.inst.sg:HasStateTag("idle") then
                    self.inst:PushEvent("attacked", { attacker = nil, damage = 0})
                    self.inst.player_classified.attackedpulseevent:push()
                else
                    self.inst.player_classified.attackedpulseevent:push()
                    DoHurtSound(self.inst)
                end
                self.inst.components.health:SetInvincible(invincible)
                -- self.inst.components.health:DoDelta(-damage, nil, "毒区伤害")
            end
        end
    else
        self.last_time = self.last_time + dt
    end
end

return Envenom