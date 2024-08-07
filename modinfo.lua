name = ChooseTranslationTable({"Battle Royale", zh = "大逃杀"})
description = [[
修改自mod制作者 月 的毒圈mod
已取得原作者允许]]
author = "月, 亚丹"

version = "1.0.28"

api_version = 10

all_clients_require_mod = true
client_only_mod = false
dst_compatible = true

forumthread = ""

priority = 0 -- 优先级

server_filter_tags = {
	"毒圈",
	"大逃杀",
	"吃鸡",
	"PVP",
}
-- 模组依赖
-- mod_dependencies = { { workshop = "workshop-2710978964"} }

-- icon_atlas = "fishingrod.xml"
-- icon = "fishingrod.tex"


-- mod设置选项
configuration_options = {
	{
        name = "whitelisted",
        label = ChooseTranslationTable({"Whitelist", zh = "白名单"}),
        hover = ChooseTranslationTable({"Use a whitelist, needs to be added manually.", zh = "启用白名单（需要手动添加）"}),
        options =
        {
            {description = ChooseTranslationTable({"Yes", zh = "是"}), data = true},
            {description = ChooseTranslationTable({"No", zh = "否"}), data = false},
        },
        default = true,
    },
}