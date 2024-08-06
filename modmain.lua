GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

-- 注意scripts/prefabs/staff.lua文件使用了替换法来实现更改传送杖的目标落点效果，在游戏更新后需要检查其是否会引起bug

GLOBAL.HUMAN_MEAT_ENABLED = true

local _GetGameModeProperty = GLOBAL.GetGameModeProperty
GLOBAL.GetGameModeProperty = function(setting, ...)
    if setting == "lobbywaitforallplayers" then
        return true
    end
    return _GetGameModeProperty(gamemode, ...)
end

local TheNet_idx = getmetatable(TheNet).__index
if TheNet_idx then
    local old_GetClientTable = TheNet_idx.GetClientTable
    TheNet_idx.GetClientTable = function(self)
        local data = old_GetClientTable(self)
        for k, client in ipairs(data) do
            if client --[[and client.performance == nil]] then 
                client.name = STRINGS.NAMES[string.upper(client.prefab)] or "未知人物"
                client.equip = {}
            end
        end
        return data
    end
    local old_GetClientTableForUser = TheNet_idx.GetClientTableForUser
    TheNet_idx.GetClientTableForUser = function(self, userid)
        local client = old_GetClientTableForUser(self, userid)
        if client then
            client.name = STRINGS.NAMES[string.upper(client.prefab)] or "未知人物"
            client.equip = {}
        end
        return client
    end
end


PrefabFiles = {"poison_miasma_cloud_fx"}
Assets = {
    Asset("SHADER", "shaders/ui_round.ksh"),
    -- 要制作着色器文件 (.ksh)，您需要一个顶点着色器 (.vs) 文件和一个像素/片段着色器 (.ps) 文件
    -- cmd: cd /d D:\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools\tools\bin
    -- cmd: ShaderCompiler.exe -little "ui_round" "zdy.vs" "zdy.ps" "ui_round.ksh" -oglsl
}

-- TheNet:GetServerIsClientHosted() 获取服务器和客户端是一个机器
local IsServer = TheNet:GetIsServer() or TheNet:IsDedicated()

-----------------------------------
-- 对玩家进行更改
AddPlayerPostInit(function(inst)
    if TheWorld.ismastersim then
        inst:AddComponent("envenom_pc") --持续检查
        inst.components.grogginess.resistance = 18
        inst.components.grogginess.decayrate = inst.components.grogginess.decayrate * 6
        inst.components.freezable:SetResistance(inst.components.freezable.resistance * 1.5)
        inst.components.freezable.wearofftime = 1
        inst.components.combat:SetPlayerStunlock(PLAYERSTUNLOCK.SOMETIMES)
    end
end)
AddPrefabPostInit("world", function(inst)
    inst:AddComponent("poisonfxmanager_pc")
    if not inst.ismastersim then
        return
    end
end)
AddPrefabPostInit("forest_network", function(inst)
    inst:AddComponent("worldcharacterselectlobby")
    inst:AddComponent("poisonouscircle_pc")
end)
AddPrefabPostInit("cave_network", function(inst)
    inst:AddComponent("poisonouscircle_pc")
end)

local SpDamageUtil = require("components/spdamageutil")

local Combat = require("components/combat")
local Combat_Old_GetAttacked = Combat.GetAttacked
function Combat:GetAttacked(attacker, damage, weapon, stimuli, spdamage, ...)
    if self.inst:HasTag("player") then
        spdamage = SpDamageUtil.ApplySpDefense(self.inst, spdamage)
        local newdamage = damage
        if damage and spdamage then
            newdamage = damage + SpDamageUtil.CalcTotalDamage(spdamage)
        end
        return Combat_Old_GetAttacked(self, attacker, newdamage, weapon, stimuli, {}, ...)
    else
        return Combat_Old_GetAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...)
    end
end

local Grogginess = require("components/grogginess")
local Grogginess_Old_OnUpdate = Grogginess.OnUpdate
function Grogginess:OnUpdate(dt, ...)
    if self:IsKnockedOut() then
        self.knockouttime = self.knockouttime + dt * 4
    end
    return Grogginess_Old_OnUpdate(self, dt, ...)
end

-- TheWorld.net.components.poisonouscircle_pc:Start() --正式开始游戏
---------------------------------------- [[ 仅客机的内容 ]] ------------------------ 
if TheNet:GetServerIsClientHosted() or TheNet:GetIsClient() then
    AddClassPostConstruct("widgets/mapwidget", function(self)
        self.circleimg = self:AddChild(Image())
        self.circleimg:SetHAnchor(ANCHOR_MIDDLE)
        self.circleimg:SetVAnchor(ANCHOR_MIDDLE)
        self.circleimg.inst.ImageWidget:SetBlendMode( BLENDMODE.Additive )

        -- 图片ui添加shader
        self.circleimg.inst.ImageWidget:SetEffect(resolvefilepath("shaders/ui_round.ksh")) --resolvefilepath 官方使用时不会加这个 mod得加

        self.poisoncircle = TheWorld.net.components.poisonouscircle_pc

        self.setBig = function(self, is_r)
            local bigcir = self.poisoncircle:GetBigScreenPos(is_r)
            self.circleimg:SetEffectParams(bigcir.x, bigcir.y, bigcir.r*(is_r and 1 or 1), 0) --1/self.minimap:GetZoom()
        end
        self.setSmall = function(self, is_r)
            local smallcir = self.poisoncircle:GetSmallScreenPos(is_r)
            self.circleimg:SetEffectParams2(smallcir.x, smallcir.y, smallcir.r*(is_r and 1 or 1), smallcir.b)
        end
        -- 初始化
        self:setBig()
        self:setSmall()

        -- 持续变化
        local old_OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, dt, ...)
            if not self.shown then return end
            if self.poisoncircle.is_shrink:value() then --缩圈中
                self:setBig()
                self:setSmall()
            elseif TheInput:IsControlPressed(CONTROL_ROTATE_LEFT) or TheInput:IsControlPressed(CONTROL_ROTATE_RIGHT) then --检查是否按下旋转了
                self:setBig()
                self:setSmall()
            end
            self.minimap:Offset( 0, 0 )
            self:UpdateMapscreenDecorations()

            old_OnUpdate(self, dt, ...)
        end

        local old_SetTextureHandle = self.SetTextureHandle
        self.SetTextureHandle = function(self, handle, ...)
            self.circleimg.inst.ImageWidget:SetTextureHandle(handle)
            old_SetTextureHandle(self, handle, ...)
        end

        -- 跟着一起进行偏移
        local map_idx = getmetatable(self.minimap).__index
        if map_idx then
            local old_Offset = map_idx.Offset
            map_idx.Offset = function(t, dx, dy)
                old_Offset(t, dx, dy)
                self:setBig()
                self:setSmall()
            end
        end

        -- 重新设置安全区了 手动更新一下
        TheWorld:ListenForEvent("onminimapshrink", function() 
            self:setBig()
            self:setSmall()
        end)
    end)
end

local Grid = require "widgets/grid"
local Widget = require "widgets/widget"

AddClassPostConstruct( "widgets/waitingforplayers", function(self)
	-- Dynamically scales the player portraits in the waiting lobby to fit the number of connected players.
	self.UpdatePlayerListing = function()
		local screen_width = 900--520--560--639.32--750--812 -- This was found through testing
		local screen_height = 450
		local widget_scalar = 0.43
		local widget_width = widget_scalar*324--125
		local widget_height = widget_scalar*511--250
		local offset_width = 110.68--250--125
		local offset_height = 30 + 20
		local col = 0
		local row = 1
		local scalar = 3
		local scalar_percent_increment = 0.005

		local player_count = TheNet:GetDefaultMaxPlayers()
		while col*row < player_count do
			col = col + 1
			-- Find the next scalar
			local next_scalar = scalar
			local count = 0
			while (col * (widget_width + offset_width) - offset_width) * next_scalar > screen_width or ((widget_height + offset_height) * row - offset_height)*next_scalar > screen_height do
				count = count + 1
				next_scalar = scalar*(1 - scalar_percent_increment*count)
			end
			scalar = next_scalar
			-- If the current player badge is smaller than the size it would be if another row is added then add another row instead of a column.
			if ((widget_height + offset_height) * (row + 1) - offset_height)*scalar < screen_height then
				row = row + 1
				col = col - 1
				scalar = 2 / row
			end
		end
		-- Remove any leftover column space from recent new rows.
		while (col - 1)*row >= player_count do
			col = col - 1
		end
		-- Scale each widget based on number of max players
		for i,widget in pairs(self.player_listing) do
			if i <= player_count then
				widget:SetScale(scalar)
				widget:Show()
			else
				widget:Hide()
			end
		end
		-- Clear and Update grid based on amount of players
		local old_grid = self.list_root
		self.list_root = self.proot:AddChild(Grid())
		self.list_root:FillGrid(col, (widget_width + offset_width) * scalar, (widget_height + offset_height) * scalar, self.player_listing)
		self.list_root:SetPosition(-(widget_width + offset_width) * scalar * (col - 1)/2, (widget_height + offset_height)*scalar*(row - 1)/2 + 20)
		old_grid:Kill()
	end
	self:UpdatePlayerListing()
end)





return