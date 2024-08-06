-- ScreenPos -> WidgetPos 从左下角到中间的坐标变换 x-w/2
-- WidgetPos -> MapPos MapPos也是位于中间的 公式就是 x*(2/w) 原理没有搞懂
local function ScreenPosToMapPos(x, y)
    local w, h = TheSim:GetScreenSize()
    return 2*x/w-1, 2*y/h-1
end
-- MapPos -> WidgetPos 公式就是 x*(w/2) 原理没有搞懂
-- WidgetPos -> ScreenPos 公式就是 x+w/2
local function MapPosToScreenPos(x, y)
    local w, h = TheSim:GetScreenSize()
    return (x+1)*w/2, (y+1)*h/2
end

-- 网络变量的关联 省了写value和set 而是正常的赋值和调用
local contact_net = {
    __index = function(t, k)        --对表(t)读取不存在的值(k)时。 t是被添加元表的表, 即setmetatable函数的第一个参数
        local p = rawget(t, "_")[k]
        if p ~= nil then
            return p:value()
        end
        return getmetatable(t)[k]
    end,
    __newindex = function(t, k, v)  --对表(t)给不存在的值(k)进行赋值(v)时。
        local p = rawget(t, "_")[k]
        if p == nil then
            rawset(t, k, v)
        else
            p:set(v)
        end
    end,
}
local FIRST_TIME = 5 --最开始等待刷新安全区
-- 毒圈的基本信息
local forest_data = {
    -- 不活跃时间    活跃缩圈时间  秒伤  小圆是大圆的倍数
    {inactive_time= 1920, active_time= 480, damage=0.5, mag = .5},
    {inactive_time= 480, active_time= 120, damage=1, mag = 0.3},
    {inactive_time= 360, active_time= 120, damage=3, mag = 0.3},
    {inactive_time= 120, active_time= 120, damage=20, mag = 0.4},
    {inactive_time= 120, active_time= 120, damage=75, mag = 0},
}

local cave_data = {
    -- 不活跃时间    活跃缩圈时间  秒伤  小圆是大圆的倍数
    {inactive_time= 1440, active_time= 480, damage=1, mag = 0.05},
    {inactive_time= 960, active_time= 120, damage=2, mag = 0.01},
    {inactive_time= 360, active_time= 120, damage=6, mag = 0},
    {inactive_time= 120, active_time= 120, damage=20, mag = 0},
    {inactive_time= 120, active_time= 120, damage=75, mag = 0},
}

local PoisonousCircle = Class(function(self, inst) 
	self.inst = inst
    self.ismastersim = TheWorld.ismastersim --是主机
    self.minimap = TheWorld.minimap and TheWorld.minimap.MiniMap or nil
    if self.minimap == nil then
        print("没有小地图吗？？？")
    end
    print("注册网络变量")
    -- 圈的位置和半径
    self.bigPos_x = net_float(self.inst.GUID, "minimap.bigPos_x")  -- 范围[-32767..32767] 这个也是够用的 地图大小是有限制的
    self.bigPos_y = net_float(self.inst.GUID, "minimap.bigPos_y")
    self.bigPos_r = net_float(self.inst.GUID, "minimap.bigPos_r") -- 范围[0..65535] 半径大概可到 16383块地皮哎 完全够用
    self.smallPos_x = net_float(self.inst.GUID, "minimap.smallPos_x")
    self.smallPos_y = net_float(self.inst.GUID, "minimap.smallPos_y")
    self.smallPos_r = net_float(self.inst.GUID, "minimap.smallPos_r")
    --------------------------------------
    -- 状态
    self.state = net_bool(self.inst.GUID, "minimap._state_zdy", "poisonouscircle_state")
    --------------------------------------
    -- 在缩圈吗
    self.is_shrink = net_bool(self.inst.GUID, "minimap.shrink", "onminimapshrink")
    -- 第几波
    self.number = net_smallbyte(self.inst.GUID, "minimap.number")
    -- 下次缩圈时间
    self.next_shrinking_time = net_float(self.inst.GUID, "minimap.next_shrinking_time")
    -- 当前毒圈伤害
    self.damage = net_float(self.inst.GUID, "minimap.damage")
    --------------------------------------

    -- 当前毒圈总信息参数
    self.current = {}
    self.current._ = {state = self.is_shrink, time = self.next_shrinking_time, damage = self.damage, n = self.number}
    setmetatable(self.current, contact_net)
    
    -- 大圈的WorldPos参数
    self.bigPos = {}
    self.bigPos._ = {x = self.bigPos_x, y = self.bigPos_y, r = self.bigPos_r}
    setmetatable(self.bigPos, contact_net)
    
    -- 小圈的WorldPos参数
    self.smallPos = {}
    self.smallPos._ = {x = self.smallPos_x, y = self.smallPos_y, r = self.smallPos_r}
    setmetatable(self.smallPos, contact_net)

    --服务器执行初始化一下大圆的半径
    if self.ismastersim then
        self.inst:DoTaskInTime(0,function()
            if self.state:value() == true then
                inst:DoTaskInTime(0, function() self:Start() end)
            else
                local w, h = TheWorld.Map:GetSize()
                self.bigPos.r = w*4*2 --没改地图大小是没有问题的 够用。
                inst:DoTaskInTime(5, function() self:Start() end)
            end
        end)
        self.state:set(false)
    end
    --客户端数据
    if not TheNet:IsDedicated() then
        -- 大小圆圈的ScreenPos坐标和半径 
        self.bigcir = {x = 0, y = 0, r = 0} --大圈shader映射参数
        self.smallcir = {x = 0, y = 0, r = 0, b = 2} --小圈shader映射参数 b是边界大小 border
    end
end)
------------------------- [[ 客户端执行 ]] -------------------------
function PoisonousCircle:GetBigScreenPos(is_r)
    -- 求ScreenPos的半径
    local x, y = self.minimap:WorldPosToMapPos(self.bigPos.x, self.bigPos.y, 0) --WorldPos坐标 转 MapPos坐标
    self.bigcir.x, self.bigcir.y = MapPosToScreenPos(x,y)

    if true then
        -- 求ScreenPos的半径
        x, y = self.minimap:WorldPosToMapPos(self.bigPos.x + self.bigPos.r, self.bigPos.y, 0)
        x, y = MapPosToScreenPos(x,y)
        local dx,dy = self.bigcir.x - x, self.bigcir.y - y
        local r = math.sqrt(dx*dx+dy*dy)
        self.bigcir.r = r
    end
    return self.bigcir
end
function PoisonousCircle:GetSmallScreenPos(is_r)
    -- 求ScreenPos的半径
    local x, y = self.minimap:WorldPosToMapPos(self.smallPos.x, self.smallPos.y, 0) --WorldPos坐标 转 MapPos坐标
    self.smallcir.x, self.smallcir.y = MapPosToScreenPos(x,y)

    if true then
        -- 求ScreenPos的半径
        x, y = self.minimap:WorldPosToMapPos(self.smallPos.x + self.smallPos.r, self.smallPos.y, 0)
        x, y = MapPosToScreenPos(x,y)
        local dx,dy = self.smallcir.x - x, self.smallcir.y - y
        local r = math.sqrt(dx*dx+dy*dy)
        self.smallcir.r = r
    end
    return self.smallcir
end

function PoisonousCircle:GetScreenPos()
    -- 世界坐标转屏幕坐标  应该还要在旋转处理一下
    -- local x,y = TheSim:GetScreenPos(self.bigPos.x, 0,self.bigPos.y)
    -- local x1,y1 = TheSim:GetScreenPos(self.bigPos.x + self.bigPos.r, 0,self.bigPos.y)
    -- local r = VecUtil_Dist(x, y, x1, y1)
    local x,y = TheSim:GetScreenPos(0, 0, 0)
    local x1,y1 = TheSim:GetScreenPos(0+8, 0,0)
    local r = VecUtil_Dist(x, y, x1, y1)
    return x, y, r
end
------------------------- [[ 服务器端执行 ]] -------------------------
-- 设置大圈的世界信息
function PoisonousCircle:SetBigWorldPos(x, y, r)
    print("设置大圆:",x,y,r)
    if not self.ismastersim then return end
    if type(x) == "number" then
        self.bigPos.x = x
    end
    if type(y) == "number" then
        self.bigPos.y = y
    end
    if type(r) == "number" and r >= 0 then --不能负数
        self.bigPos.r = r
    end
end
-- 设置小圈的世界信息
function PoisonousCircle:SetSmallWorldPos(x, y, r)
    print("设置小圆:",x,y,r)
    if not self.ismastersim then return end
    if type(x) == "number" then
        self.smallPos.x = x
    end
    if type(y) == "number" then
        self.smallPos.y = y
    end
    if type(r) == "number" and r >= 0 then --不能负数 要不判断一下是否大于大圆的半径？
        self.smallPos.r = r
    end
end
-- 设置缩圈参数
function PoisonousCircle:SetShrink(time1, time2, damage)
    -- 缩圈参数
    self.total_time = time1 or 0 --总收缩时间
    self.speed = (self.bigPos.r - self.smallPos.r) / self.total_time --计算收缩速度
    self.dissq = DistXYSq(self.bigPos, self.smallPos) --两圆初始距离平方
    -- 两圆内切时 大圆圆心移动xy方向分量
    self.dis = math.sqrt(self.dissq)
    if self.bigPos.x == self.smallPos.x and self.bigPos.y ~= self.smallPos.y then
        self.cos = 0
        self.sin = 1
    elseif self.bigPos.x ~= self.smallPos.x and self.bigPos.y == self.smallPos.y then
        self.cos = 1
        self.sin = 0
    elseif self.bigPos.x == self.smallPos.x and self.bigPos.y == self.smallPos.y then
        self.cos = 0
        self.sin = 0
    else
        local a = self.smallPos.x - self.bigPos.x
        local b = self.smallPos.y - self.bigPos.y
        self.cos = a/self.dis
        self.sin = b/self.dis
    end
    print("参数", self.speed, self.dissq, self.cos, self.sin)
    -- 设置毒圈其他参数
    self.current.time = time2 or 0
    self.current.damage = damage or 0
end

-- 找到安全区
function PoisonousCircle:FindSecurity(r1, r2)
    print("半径", r1, r2)
    local big_r = r1
    local small_r = r2 --比大圆半径小就行
    local big_r_sq = big_r * big_r
    local small_r_sq = small_r * small_r
    -- A方案
    -- 从陆地的各个节点 选择出范围内可以作为小圆圆心的节点 再随机一个作为圆心。
    local old_nodes = self.nodes or TheWorld.topology.nodes --初始时 全部节点都要遍历一次
    local nodes = {}
    local x, y = 0, 0
    for k,node in pairs(old_nodes) do
        local dissq = DistXYSq(self.bigPos, node) --是节点中心
        if big_r_sq >= (small_r + math.sqrt(dissq)) * (small_r + math.sqrt(dissq)) and not table.contains(node.tags, "not_mainland") and not table.contains(node.tags, "RoadPoison") then
            table.insert(nodes, {x = node.x, y = node.y}) --直接记录节点 和 记录新表 区别暂时未知阿
        end
    end
    
    -- 更新可用节点列表
    self.nodes = nodes

    -- print("A方案",#nodes)
    if #nodes > 0 then
        local n = nodes[math.random(#nodes)]
        x, y = n.x, n.y
    else
        -- B方案
        -- 如果是自定义类型的地图（海战类型） 可能没有合适的节点 此时应该从地图中随机一个 忽略掉在安全区在海洋的情况了。
        -- 因为小圆是被大圆内含或内切的 那么小圆的圆心坐标可以的区域是一个与大圆的同心圆 其半径是大圆半径-小圆半径
        -- 那么可以随机向量法来确定小圆圆心 即同心圆圆心为原点 随机一个角度 随机0~1的半径长度
        local r = big_r - small_r
        local angle = math.random()*2*PI
        r = math.sqrt(math.random())*r
        x = r*math.cos(angle) + self.bigPos.x
        y = r*math.sin(angle) + self.bigPos.y
    end    
    -- 可能可以对小圆圆心坐标进行规整化 抛去小数点 会不会更好嘞 待测试
    return x, y
end
-- 下一个安全区
function PoisonousCircle:NextSecurityZone()
    if not self.ismastersim then return end
    TheWorld:PushEvent("下一个安全区")
    -- 第一个圈 从各个节点中随机一个; 遍历全部节点 找到全部在半径内的节点
    -- 下一个圈 节点表>0 随机一个半径内的节点; 否则 遍历当前半径内的合适位置

    local map_width, map_height = TheWorld.Map:GetSize() --是地皮数量
    print("世界大小", map_width, map_height)
    -- 设置为下一波
    self.current.n = self.current.n + 1
    -- 获取下一次的信息
    local t = TheWorld:HasTag("cave") and cave_data[self.current.n] or forest_data[self.current.n]

    if t then
        local x, y = self.smallPos.x, self.smallPos.y --初始时 值为0
        local bigr = self.current.n > 1 and self.smallPos.r or (map_width * 4 * math.sqrt(2)) / 2 --初始时 值为0 故选择地图外接圆
        local smallr = self.current.n > 1 and t.mag * bigr or (map_width-OCEAN_WATERFALL_MAX_DIST)*2*t.mag-- 预设的值
        -- 先设置大圆的数据 找小圆要用到
        self:SetBigWorldPos(x, y, bigr)

        if smallr > 0 then --0的话 是最后的了 就往中间缩
            -- 初始时 保证小圆要在地图范内含或内切。 选择地图的内接圆, 地图因为有边缘锯齿不规则 所以再往里缩到保证可以形成完整正方形 所以为 (map_width-OCEAN_WATERFALL_MAX_DIST)*4
            x, y = self:FindSecurity(self.smallPos.r > 0 and bigr or (map_width-OCEAN_WATERFALL_MAX_DIST)*2, smallr)
        end

        -- 设置小圈的信息
        self:SetSmallWorldPos(x, y, smallr)

        -- 更新下次基础信息
        self:SetShrink(t.active_time, t.inactive_time, t.damage)
        print("self.current.damage",self.current.damage)
        if not TheWorld:HasTag("cave") then
            TheNet:Announce(string.format("安全区外的伤害已经提升至%0.1f点", self.current.damage))
            TheNet:Announce(string.format("下一个安全区将在%d秒后开始收缩", self.current.time))
        elseif self.current.n == 2 then
            TheNet:Announce(string.format("洞穴安全区外的伤害已经提升至%0.1f点", self.current.damage))
            TheNet:Announce("洞穴的下一个安全区将与地面保持同步")
        end
    else
        if not TheWorld:HasTag("cave") then
            TheNet:Announce(string.format("安全区已缩小至最小状态", self.total_time))
        end
        self:Discontinue()
        print("大圈", self.bigPos.r, self.bigPos.x, self.bigPos.y)
        print("小圈", self.smallPos.r, self.smallPos.x, self.smallPos.y)
    end

end

-- 开始收缩
function PoisonousCircle:StartShrink()
    if not self.ismastersim then return end
    if not TheWorld:HasTag("cave") then
        TheNet:Announce(string.format("安全区正在收缩！将在%d秒后完成收缩", self.total_time))
    elseif self.current.n == 1 then
        TheNet:Announce(string.format("洞穴安全区正在提前收缩！将在%d秒后完成收缩", self.total_time))
    end
    -- 重置时间
    TheWorld:PushEvent("onstartshrink")
    self.current.state = true
end

function PoisonousCircle:Start()
    self.inst:StopUpdatingComponent(self)
    if self.state:value() == false then
        self.state:set(true)
        -- 初始时 圆心都在地图中心 (0,0) 半径要比地图大 就好
        local w,h = TheWorld.Map:GetSize()
        self.bigPos.r = w*4*2 --没改地图大小是没有问题的 够用。
        self.current.n = 0
        self.current.state = false
        -- 设置初始参数
        self.inst:DoTaskInTime(FIRST_TIME, function()
            --TheNet:Announce("开始了")
            print("正式开始")
            TheWorld:PushEvent("startpoisonouscircle")
            self:NextSecurityZone() --第一波
            self.inst:StartUpdatingComponent(self)
        end)
    else
        self.inst:DoTaskInTime(FIRST_TIME, function()
            --TheNet:Announce("开始了")
            print("从断点开始")
            TheWorld:PushEvent("startpoisonouscircle")
            self.inst:StartUpdatingComponent(self)
        end)
    end
end
function PoisonousCircle:Discontinue()
    self.state:set(false)
    TheWorld:PushEvent("discontinuepoisonouscircle")
    --self.inst:StopUpdatingComponent(self)
end

function PoisonousCircle:OnSave()
	local data = {}
    data.current = {}
    data.current.state = self.current.state
    data.current.time = self.current.time
    data.current.damage = self.current.damage
    data.current.n = self.current.n

    data.bigPos = {}
    data.bigPos.x = self.bigPos.x
    data.bigPos.y = self.bigPos.y
    data.bigPos.r = self.bigPos.r

    data.smallPos = {}
    data.smallPos.x = self.smallPos.x
    data.smallPos.y = self.smallPos.y
    data.smallPos.r = self.smallPos.r

    data.state = self.state:value()

    data.total_time = self.total_time
    data.speed = self.speed
    data.dis = self.dis

    data.cos = self.cos
    data.sin = self.sin

	return data
end

function PoisonousCircle:OnLoad(data)
    if data ~= nil then
        if data.current ~= nil then
            self.current.state = data.current.state
            self.current.time = data.current.time
            self.current.damage = data.current.damage
            self.current.n = data.current.n
        end

        if data.bigPos ~= nil then
            print("获得大圆数据")
            self.bigPos.x = data.bigPos.x
            self.bigPos.y = data.bigPos.y
            self.bigPos.r = data.bigPos.r
        end

        if data.smallPos ~= nil then
            print("获得小圆数据")
            self.smallPos.x = data.smallPos.x
            self.smallPos.y = data.smallPos.y
            self.smallPos.r = data.smallPos.r
        end

        if data.state ~= nil then
            self.state:set(data.state)
        end

        if data.total_time ~= nil then
            self.total_time = data.total_time
        end

        if data.speed ~= nil then
            self.speed = data.speed
        end

        if data.dis ~= nil then
            self.dis = data.dis
        end

        if data.cos ~= nil then
            self.cos = data.cos
        end

        if data.sin ~= nil then
            self.sin = data.sin
        end
    end
end

function PoisonousCircle:OnUpdate(dt)
    if not self.ismastersim then self.inst:StopUpdatingComponent(self) return end

    if self.total_time == nil then
        self.total_time = 10000
    end

    -- 当前毒圈状态 判断是缩圈 还是 进行倒计时
    if self.current.state then
        local new_time = self.total_time - dt
        if new_time <= 0 then
            new_time = 0
            dt = self.total_time --说明没有多余的时间了
        end
        self.total_time = new_time
        -- 每帧半径缩小值
        local diffBigR = self.speed * dt;
        self.bigPos.r = self.bigPos.r - diffBigR
        --内切但没有重合时 每帧同时进行移动大圆的圆心 靠近小圆的圆心
        if self.bigPos.r > self.smallPos.r + self.dis then
        elseif self.bigPos.r > self.smallPos.r and self.bigPos.r <= self.smallPos.r + self.dis then
            self.bigPos.x = self.bigPos.x + self.cos*diffBigR
            self.bigPos.y = self.bigPos.y + self.sin*diffBigR
        else
        end
        -- print("", self.total_time, self.bigPos.x, self.bigPos.y, self.bigPos.r, diffBigR)   
        if self.total_time <= 0 then
            -- 寻找下一个安全区
            self:NextSecurityZone()
            self.current.state = false
        end
    elseif self.state:value() then
        -- 检查 下次毒圈活跃
        self.current.time = self.current.time - dt
        if self.current.time <= 0 then
            -- 开始缩圈了
            self:StartShrink()
        end
    end
end

function PoisonousCircle:LongUpdate(dt)
    self:OnUpdate(dt)
end

return PoisonousCircle