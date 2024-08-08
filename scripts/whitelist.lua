local white_list = {
    KU_zPOwY2DT = true, -- ziwbi
}

-- 放到函数里避免直接修改
function IsPlayerWhitelisted(player)
    return white_list[player.userid]
end
