extends RefCounted

# Coordinates are in the horizontal X/Z plane. North is negative Z.
const ISLES = [
	["家园岛", 0, 0, 22, 17], ["采石场", 0, -19, 14, 14],
	["水晶矿洞", -24, -4, 17, 15], ["池塘岛", 21, 0, 13, 13],
	["金矿山", 0, 19, 13, 16], ["花草地", 18, -19, 12, 13],
	["古代遗迹", 37, -19, 17, 15], ["瀑布岛", 21, 17, 16, 14],
	["林间小岛", 39, 17, 11, 10], ["林中湖", -24, 13, 16, 14],
	["农田", -21, 29.5, 19, 14]
]
const LINKS = [[0,1],[0,2],[0,3],[0,4],[1,5],[5,6],[3,7],[7,8],[2,9],[9,10],[4,10]]
const NAMES = {
	"wood":"木头","stone":"石头","berry":"浆果","iron_ore":"铁矿石",
	"gold_ore":"金矿石","crystal":"水晶","brick":"砖块","iron":"铁锭",
	"gold":"金锭","carrot":"胡萝卜","cabbage":"卷心菜","turnip":"芜菁",
	"furnace":"熔炉","market":"市场","forge":"锻造台",
	"pick":"石镐","house":"农舍","bench":"工作台","chest":"遗迹宝箱"
}
const PRICES = {"wood":1,"stone":1,"berry":1,"iron_ore":3,"gold_ore":6,
	"crystal":9,"brick":4,"iron":9,"gold":19,"carrot":6,"cabbage":8,"turnip":10}
const ORDER = ["wood","stone","brick","iron_ore","iron","gold_ore","gold","crystal","berry","carrot","cabbage","turnip"]
const FOOD = {"berry":18,"carrot":24,"cabbage":32,"turnip":38}
const BUILD = {"furnace":{"stone":10,"wood":4},"market":{"wood":8,"brick":4},"forge":{"brick":6,"iron":2}}
const BUILD_DESC = {"furnace":"烧制砖块、冶炼矿石","market":"出售物品换取金币","forge":"打造更好的镐子、铸造金币"}
const RECIPES = {
	"brick":{"cost":{"stone":2},"time":2.0},
	"iron":{"cost":{"iron_ore":1,"wood":1},"time":3.0},
	"gold":{"cost":{"gold_ore":1,"wood":1},"time":3.5}
}
const SKILLS = {
	"power":["力量","采集伤害 +25%"],"craft":["工匠","制作速度 +30%"],
	"magnet":["磁力","拾取范围 +50%"],"energy":["耐力","能量上限 +25 并回满"],
	"luck":["幸运","额外掉落几率 +15%"]
}
const RESOURCES = {
	"tree":["树",4.0,3],"berrybush":["浆果丛",2.0,2],"stone":["岩石",3.0,3],
	"iron_ore":["铁矿",4.0,4],"gold_ore":["金矿",5.0,5],"crystal":["水晶矿脉",5.0,6]
}
const CROPS = ["carrot","cabbage","turnip"]
const GROW_TIME = {"carrot":42.0,"cabbage":60.0,"turnip":78.0}
const GOALS = [
	"采集木头和石头（WASD 移动，按住鼠标左键采集）",
	"靠近熔炉按 E，烧制 4 块砖","按 B 打开建造菜单，建造一座市场",
	"在市场出售物品，攒够 25 金币","走到桥头的价格牌旁按 E，买下一座新岛屿",
	"在采石场或水晶矿洞挖铁矿，用熔炉炼出铁锭","建造锻造台，把石镐升级为铁镐",
	"找到农田，亲手播种并收获一株作物","前往古代遗迹，打开石柱间的宝箱",
	"连接全部 11 座岛屿，点亮天空群岛"
]
