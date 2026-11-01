extends Node
## 静态数据表：职业 / 地点 / 房产 / 店铺 / 车辆 / 家具 / 帮派 / 任务
## 纯数据，不持有运行时状态（运行时状态在 Game 里）

# ─────────────────────────── 主题色 ───────────────────────────
const C_BG := Color(0.055, 0.067, 0.086)
const C_PANEL := Color(0.086, 0.106, 0.133)
const C_PANEL2 := Color(0.114, 0.137, 0.169)
const C_LINE := Color(0.18, 0.21, 0.25)
const C_TEXT := Color(0.902, 0.929, 0.953)
const C_DIM := Color(0.545, 0.580, 0.620)
const C_ACCENT := Color(0.298, 0.553, 1.0)
const C_TEAL := Color(0.208, 0.816, 0.729)
const C_GOLD := Color(1.0, 0.820, 0.400)
const C_RED := Color(0.949, 0.357, 0.376)
const C_GREEN := Color(0.290, 0.780, 0.470)
const C_PURPLE := Color(0.639, 0.451, 0.949)

# ─────────────────────────── 职业 ───────────────────────────
const JOBS := {
	"unemployed": {
		"name": "无业游民",
		"short": "无业",
		"desc": "自由自在，但没有稳定收入。去平板「职业」页申请一份工作吧。",
		"salary": 0,
		"color": Color(0.45, 0.47, 0.52),
		"need_shop": "",
	},
	"police": {
		"name": "警察",
		"short": "警察",
		"desc": "维护治安。在警局领取巡逻与追捕任务，完成任务获得报酬。可对通缉目标执行逮捕。",
		"salary": 260,
		"color": Color(0.30, 0.55, 0.98),
		"need_shop": "",
	},
	"firefighter": {
		"name": "消防员",
		"short": "消防",
		"desc": "扑灭城市各处的火灾。接到火警后前往火场，按住 E 灭火。",
		"salary": 240,
		"color": Color(0.92, 0.35, 0.28),
		"need_shop": "",
	},
	"doctor": {
		"name": "医生",
		"short": "医生",
		"desc": "救治街头的伤员。靠近伤员按住 E 进行急救，病人稳定后结算诊金。",
		"salary": 300,
		"color": Color(0.85, 0.90, 0.95),
		"need_shop": "",
	},
	"chef": {
		"name": "厨师",
		"short": "厨师",
		"desc": "需要拥有餐厅厨房的使用权。在厨房操作台开工，为顾客出餐赚取收入。",
		"salary": 0,
		"color": Color(0.98, 0.62, 0.25),
		"need_shop": "diner",
	},
	"clerk": {
		"name": "便利店老板",
		"short": "店长",
		"desc": "需要拥有便利店的使用权。在收银台开工，补货、收银、应付顾客。",
		"salary": 0,
		"color": Color(0.35, 0.82, 0.55),
		"need_shop": "mart",
	},
	"gangster": {
		"name": "帮派成员",
		"short": "帮派",
		"desc": "在城西仓库加入帮派。接取地盘、走私与抢劫任务，报酬丰厚但会提升通缉度。",
		"salary": 0,
		"color": Color(0.64, 0.45, 0.95),
		"need_shop": "",
	},
}

const JOB_ORDER := ["unemployed", "police", "firefighter", "doctor", "chef", "clerk", "gangster"]

# ─────────────────────────── 城市网格 ───────────────────────────
const BLOCK := 44.0      # 街区边长
const ROAD := 14.0       # 道路宽度
const GRID := 4          # 4x4 街区
const CELL_PITCH := BLOCK + ROAD

## 街区中心世界坐标
static func cell_center(cell: Vector2i) -> Vector3:
	var half := (GRID - 1) * 0.5
	return Vector3((cell.x - half) * CELL_PITCH, 0.0, (cell.y - half) * CELL_PITCH)

## 城市外半径（用于地图绘制）
const CITY_HALF := (GRID * BLOCK + (GRID + 1) * ROAD) * 0.5

# ─────────────────────────── 地点 ───────────────────────────
## kind: police / fire / hospital / diner / mart / garage / bank / gang / park / deco
const PLACES := [
	{"id": "police", "name": "第九分局", "kind": "police", "cell": Vector2i(0, 0),
		"size": Vector2(30, 20), "height": 10.0, "color": Color(0.22, 0.34, 0.55), "sign": "POLICE"},
	{"id": "fire", "name": "城市消防站", "kind": "fire", "cell": Vector2i(1, 0),
		"size": Vector2(28, 20), "height": 9.0, "color": Color(0.55, 0.20, 0.18), "sign": "FIRE 09"},
	{"id": "hospital", "name": "圣心医院", "kind": "hospital", "cell": Vector2i(2, 0),
		"size": Vector2(30, 22), "height": 16.0, "color": Color(0.86, 0.88, 0.90), "sign": "HOSPITAL"},
	{"id": "diner", "name": "日落餐厅", "kind": "diner", "cell": Vector2i(3, 0),
		"size": Vector2(26, 18), "height": 7.0, "color": Color(0.72, 0.42, 0.20), "sign": "SUNSET DINER"},
	{"id": "mart", "name": "24H 便利店", "kind": "mart", "cell": Vector2i(0, 1),
		"size": Vector2(22, 16), "height": 6.0, "color": Color(0.20, 0.48, 0.36), "sign": "24H MART"},
	{"id": "garage", "name": "扭矩车行", "kind": "garage", "cell": Vector2i(1, 1),
		"size": Vector2(30, 20), "height": 8.0, "color": Color(0.55, 0.50, 0.18), "sign": "TORQUE MOTORS"},
	{"id": "bank", "name": "中城区银行", "kind": "bank", "cell": Vector2i(2, 1),
		"size": Vector2(24, 18), "height": 12.0, "color": Color(0.30, 0.32, 0.36), "sign": "BANK"},
	{"id": "gang", "name": "西区仓库", "kind": "gang", "cell": Vector2i(0, 2),
		"size": Vector2(30, 22), "height": 9.0, "color": Color(0.28, 0.24, 0.34), "sign": "WAREHOUSE 7"},
	{"id": "park", "name": "中央公园", "kind": "park", "cell": Vector2i(1, 2),
		"size": Vector2(34, 34), "height": 0.0, "color": Color(0.24, 0.42, 0.26), "sign": ""},
	{"id": "shopfront", "name": "空置商铺", "kind": "shopfront", "cell": Vector2i(3, 2),
		"size": Vector2(24, 16), "height": 6.0, "color": Color(0.40, 0.38, 0.34), "sign": "FOR LEASE"},
	{"id": "deco_a", "name": "写字楼", "kind": "deco", "cell": Vector2i(0, 3),
		"size": Vector2(30, 24), "height": 22.0, "color": Color(0.34, 0.38, 0.44), "sign": ""},
	{"id": "deco_b", "name": "公寓楼", "kind": "deco", "cell": Vector2i(1, 3),
		"size": Vector2(30, 24), "height": 18.0, "color": Color(0.44, 0.40, 0.38), "sign": ""},
	{"id": "parking", "name": "公共停车场", "kind": "parking", "cell": Vector2i(2, 3),
		"size": Vector2(36, 36), "height": 0.0, "color": Color(0.22, 0.23, 0.26), "sign": ""},
	{"id": "deco_d", "name": "厂房", "kind": "deco", "cell": Vector2i(3, 3),
		"size": Vector2(32, 26), "height": 12.0, "color": Color(0.36, 0.34, 0.32), "sign": ""},
]

# ─────────────────────────── 可购买房产 ───────────────────────────
## 每个房产在指定街区里的局部偏移处生成一栋小房子
const PROPERTIES := [
	{"id": "apt201", "name": "河畔公寓 201", "cell": Vector2i(3, 1), "offset": Vector3(-12, 0, -6),
		"size": Vector2(16, 14), "price": 9800, "rooms": "一室一厅", "color": Color(0.55, 0.47, 0.42)},
	{"id": "apt202", "name": "河畔公寓 202", "cell": Vector2i(3, 1), "offset": Vector3(12, 0, -6),
		"size": Vector2(16, 14), "price": 11500, "rooms": "一室一厅 · 带阳台", "color": Color(0.48, 0.50, 0.46)},
	{"id": "cabin", "name": "松林小屋", "cell": Vector2i(2, 2), "offset": Vector3(-10, 0, 0),
		"size": Vector2(18, 16), "price": 18000, "rooms": "两室一厅", "color": Color(0.46, 0.36, 0.28)},
	{"id": "villa", "name": "湖景别墅", "cell": Vector2i(2, 2), "offset": Vector3(12, 0, 0),
		"size": Vector2(18, 18), "price": 26500, "rooms": "三室两厅 · 车库", "color": Color(0.62, 0.60, 0.55)},
	{"id": "loft", "name": "市中心阁楼", "cell": Vector2i(3, 1), "offset": Vector3(0, 0, 12),
		"size": Vector2(20, 14), "price": 34000, "rooms": "复式阁楼", "color": Color(0.38, 0.40, 0.46)},
]

# ─────────────────────────── 可租店铺 ───────────────────────────
const SHOPS := [
	{"id": "diner", "name": "日落餐厅 · 厨房使用权", "cell": Vector2i(3, 0), "rent": 1800, "job": "chef",
		"desc": "含后厨与用餐区。开业后顾客会陆续上门。"},
	{"id": "mart", "name": "24H 便利店 · 经营权", "cell": Vector2i(0, 1), "rent": 2200, "job": "clerk",
		"desc": "含货架与收银台。补货越勤，客流越旺。"},
	{"id": "shopfront", "name": "空置商铺 · 整租", "cell": Vector2i(3, 2), "rent": 1500, "job": "clerk",
		"desc": "位置偏但租金便宜，适合起步。"},
]

# ─────────────────────────── 车辆 ───────────────────────────
const VEHICLES := [
	{"id": "scooter", "name": "小踏板", "price": 1400, "top": 16.0, "accel": 9.0, "grip": 1.15,
		"size": Vector3(0.8, 1.1, 1.9), "color": Color(0.85, 0.75, 0.30), "seats": 1},
	{"id": "sedan", "name": "家用轿车", "price": 8500, "top": 24.0, "accel": 7.5, "grip": 1.0,
		"size": Vector3(1.9, 1.3, 4.4), "color": Color(0.62, 0.66, 0.72), "seats": 4},
	{"id": "van", "name": "厢式货车", "price": 11000, "top": 20.0, "accel": 5.5, "grip": 0.85,
		"size": Vector3(2.2, 2.2, 5.4), "color": Color(0.90, 0.90, 0.88), "seats": 2},
	{"id": "pickup", "name": "越野皮卡", "price": 15400, "top": 23.0, "accel": 6.8, "grip": 1.05,
		"size": Vector3(2.1, 1.7, 5.0), "color": Color(0.30, 0.36, 0.30), "seats": 4},
	{"id": "sports", "name": "GT 跑车", "price": 32000, "top": 36.0, "accel": 12.0, "grip": 1.25,
		"size": Vector3(2.0, 1.0, 4.3), "color": Color(0.85, 0.22, 0.25), "seats": 2},
]

const UPGRADES := {
	"engine": {
		"name": "引擎",
		"levels": [
			{"name": "原厂", "cost": 0, "bonus": 0.0},
			{"name": "一阶 · 进气排气", "cost": 2000, "bonus": 0.15},
			{"name": "二阶 · 涡轮", "cost": 4800, "bonus": 0.32},
			{"name": "三阶 · 锻造", "cost": 8500, "bonus": 0.50},
		],
	},
	"tires": {
		"name": "轮胎/悬挂",
		"levels": [
			{"name": "原厂", "cost": 0, "bonus": 0.0},
			{"name": "街道胎", "cost": 1200, "bonus": 0.12},
			{"name": "半热熔", "cost": 2800, "bonus": 0.26},
			{"name": "赛道套装", "cost": 5200, "bonus": 0.42},
		],
	},
}

const PAINTS := [
	{"name": "珍珠白", "color": Color(0.92, 0.93, 0.94), "cost": 400},
	{"name": "午夜黑", "color": Color(0.09, 0.10, 0.12), "cost": 400},
	{"name": "赛道红", "color": Color(0.85, 0.20, 0.22), "cost": 650},
	{"name": "深海蓝", "color": Color(0.15, 0.30, 0.62), "cost": 650},
	{"name": "芥末黄", "color": Color(0.88, 0.70, 0.18), "cost": 550},
	{"name": "薄荷绿", "color": Color(0.42, 0.78, 0.66), "cost": 550},
	{"name": "霓虹紫", "color": Color(0.62, 0.32, 0.85), "cost": 900},
]

# ─────────────────────────── 武器 ───────────────────────────
## 购买民用武器需要先通过购枪资格答题；Glock 17 仅警察免费配发
const WEAPONS := [
	{"id": "glock", "name": "Glock 17", "kind": "手枪", "price": 0, "free_for": "police",
		"damage": 22.0, "rate": 0.18, "auto": false, "mag": 17, "spread": 0.006, "range": 110.0,
		"color": Color(0.30, 0.32, 0.35),
		"desc": "警用制式手枪，警察入职免费配发，弹匣 17 发。"},
	{"id": "m4", "name": "M4 卡宾枪", "kind": "步枪", "price": 4200, "free_for": "",
		"damage": 30.0, "rate": 0.095, "auto": true, "mag": 30, "spread": 0.011, "range": 180.0,
		"color": Color(0.26, 0.28, 0.30),
		"desc": "全自动卡宾枪，射速高、后坐小。需要购枪资格。"},
	{"id": "ak", "name": "AK-47", "kind": "步枪", "price": 3600, "free_for": "",
		"damage": 38.0, "rate": 0.115, "auto": true, "mag": 30, "spread": 0.017, "range": 170.0,
		"color": Color(0.36, 0.24, 0.16),
		"desc": "威力大、后坐明显的老式突击步枪。需要购枪资格。"},
	{"id": "mac10", "name": "MAC-10", "kind": "冲锋枪", "price": 2400, "free_for": "",
		"damage": 18.0, "rate": 0.075, "auto": true, "mag": 30, "spread": 0.021, "range": 90.0,
		"color": Color(0.22, 0.23, 0.25),
		"desc": "紧凑型冲锋枪，射速极快但不精准。需要购枪资格。"},
]
const WEAPON_ORDER := ["glock", "m4", "ak", "mac10"]

# ─────────────────────────── 家具（装修） ───────────────────────────
## parts: 若干盒子的 {size, pos, color?} 组合，pos 为相对家具原点的偏移
const FURNITURE := [
	{"id": "sofa", "name": "布艺沙发", "price": 800, "size": Vector3(2.4, 1.0, 0.95),
		"parts": [
			{"size": Vector3(2.4, 0.45, 0.95), "pos": Vector3(0, 0.22, 0)},
			{"size": Vector3(2.4, 0.55, 0.22), "pos": Vector3(0, 0.72, -0.36)},
			{"size": Vector3(0.22, 0.35, 0.95), "pos": Vector3(-1.09, 0.62, 0)},
			{"size": Vector3(0.22, 0.35, 0.95), "pos": Vector3(1.09, 0.62, 0)},
		], "color": Color(0.32, 0.38, 0.52)},
	{"id": "bed", "name": "双人床", "price": 1200, "size": Vector3(2.0, 0.8, 2.2),
		"parts": [
			{"size": Vector3(2.0, 0.4, 2.2), "pos": Vector3(0, 0.3, 0)},
			{"size": Vector3(1.9, 0.18, 2.0), "pos": Vector3(0, 0.58, 0.05), "color": Color(0.86, 0.87, 0.90)},
			{"size": Vector3(2.0, 0.9, 0.18), "pos": Vector3(0, 0.65, -1.1)},
		], "color": Color(0.42, 0.33, 0.28)},
	{"id": "table", "name": "餐桌", "price": 600, "size": Vector3(1.8, 0.8, 1.0),
		"parts": [
			{"size": Vector3(1.8, 0.09, 1.0), "pos": Vector3(0, 0.75, 0)},
			{"size": Vector3(0.1, 0.75, 0.1), "pos": Vector3(-0.8, 0.37, -0.4)},
			{"size": Vector3(0.1, 0.75, 0.1), "pos": Vector3(0.8, 0.37, -0.4)},
			{"size": Vector3(0.1, 0.75, 0.1), "pos": Vector3(-0.8, 0.37, 0.4)},
			{"size": Vector3(0.1, 0.75, 0.1), "pos": Vector3(0.8, 0.37, 0.4)},
		], "color": Color(0.50, 0.38, 0.26)},
	{"id": "tv", "name": "平板电视", "price": 1500, "size": Vector3(1.6, 0.9, 0.3),
		"parts": [
			{"size": Vector3(1.6, 0.9, 0.08), "pos": Vector3(0, 1.1, 0), "color": Color(0.06, 0.07, 0.09)},
			{"size": Vector3(0.12, 0.7, 0.12), "pos": Vector3(0, 0.4, 0)},
			{"size": Vector3(0.7, 0.06, 0.4), "pos": Vector3(0, 0.04, 0)},
		], "color": Color(0.16, 0.17, 0.19)},
	{"id": "lamp", "name": "落地灯", "price": 300, "size": Vector3(0.4, 1.8, 0.4),
		"parts": [
			{"size": Vector3(0.08, 1.5, 0.08), "pos": Vector3(0, 0.75, 0)},
			{"size": Vector3(0.45, 0.35, 0.45), "pos": Vector3(0, 1.6, 0), "color": Color(1.0, 0.93, 0.72)},
			{"size": Vector3(0.5, 0.05, 0.5), "pos": Vector3(0, 0.02, 0)},
		], "color": Color(0.24, 0.24, 0.26)},
	{"id": "rug", "name": "地毯", "price": 400, "size": Vector3(3.0, 0.05, 2.2),
		"parts": [{"size": Vector3(3.0, 0.05, 2.2), "pos": Vector3(0, 0.03, 0)}],
		"color": Color(0.45, 0.28, 0.30)},
	{"id": "shelf", "name": "书架", "price": 700, "size": Vector3(1.6, 2.0, 0.4),
		"parts": [
			{"size": Vector3(1.6, 2.0, 0.35), "pos": Vector3(0, 1.0, 0)},
			{"size": Vector3(1.5, 0.06, 0.32), "pos": Vector3(0, 0.6, 0.02), "color": Color(0.55, 0.42, 0.30)},
			{"size": Vector3(1.5, 0.06, 0.32), "pos": Vector3(0, 1.3, 0.02), "color": Color(0.55, 0.42, 0.30)},
		], "color": Color(0.38, 0.29, 0.22)},
	{"id": "kitchen", "name": "厨房台", "price": 900, "size": Vector3(2.2, 0.95, 0.7),
		"parts": [
			{"size": Vector3(2.2, 0.85, 0.7), "pos": Vector3(0, 0.42, 0)},
			{"size": Vector3(2.3, 0.08, 0.78), "pos": Vector3(0, 0.88, 0), "color": Color(0.80, 0.82, 0.84)},
		], "color": Color(0.30, 0.33, 0.36)},
	{"id": "fridge", "name": "冰箱", "price": 1100, "size": Vector3(0.9, 1.9, 0.75),
		"parts": [{"size": Vector3(0.9, 1.9, 0.75), "pos": Vector3(0, 0.95, 0)}],
		"color": Color(0.80, 0.82, 0.84)},
	{"id": "plant", "name": "盆栽", "price": 250, "size": Vector3(0.7, 1.2, 0.7),
		"parts": [
			{"size": Vector3(0.5, 0.45, 0.5), "pos": Vector3(0, 0.22, 0)},
			{"size": Vector3(0.7, 0.8, 0.7), "pos": Vector3(0, 0.85, 0), "color": Color(0.24, 0.50, 0.28)},
		], "color": Color(0.55, 0.38, 0.28)},
	{"id": "desk", "name": "电脑桌", "price": 1000, "size": Vector3(1.6, 0.8, 0.8),
		"parts": [
			{"size": Vector3(1.6, 0.07, 0.8), "pos": Vector3(0, 0.76, 0)},
			{"size": Vector3(0.08, 0.76, 0.7), "pos": Vector3(-0.74, 0.38, 0)},
			{"size": Vector3(0.08, 0.76, 0.7), "pos": Vector3(0.74, 0.38, 0)},
			{"size": Vector3(0.55, 0.35, 0.06), "pos": Vector3(0, 1.0, -0.2), "color": Color(0.10, 0.11, 0.13)},
		], "color": Color(0.30, 0.30, 0.32)},
	{"id": "wardrobe", "name": "衣柜", "price": 850, "size": Vector3(1.8, 2.1, 0.6),
		"parts": [
			{"size": Vector3(1.8, 2.1, 0.6), "pos": Vector3(0, 1.05, 0)},
			{"size": Vector3(0.03, 1.9, 0.02), "pos": Vector3(0, 1.05, 0.31), "color": Color(0.15, 0.15, 0.16)},
		], "color": Color(0.44, 0.34, 0.26)},
]

# ─────────────────────────── 帮派 ───────────────────────────
const GANGS := [
	{"id": "viper", "name": "毒蛇帮", "color": Color(0.55, 0.85, 0.35),
		"desc": "掌控西区码头与走私线路。报酬高，但警察盯得紧。"},
	{"id": "ash", "name": "灰烬会", "color": Color(0.85, 0.45, 0.30),
		"desc": "老派家族式帮派，靠收保护费与赌档起家。"},
]

# ─────────────────────────── 任务 ───────────────────────────
## reward 为单次报酬；heat 为完成后增加的通缉度
const MISSION_TYPES := {
	"patrol": {"name": "街区巡逻", "job": "police", "reward": 180, "heat": 0.0,
		"desc": "依次前往 3 个巡逻点打卡，维护街区秩序。"},
	"arrest": {"name": "追捕通缉犯", "job": "police", "reward": 340, "heat": 0.0,
		"desc": "通缉目标已出现在地图标记处。靠近后按住 E 执行逮捕。"},
	"fire": {"name": "扑灭火情", "job": "firefighter", "reward": 300, "heat": 0.0,
		"desc": "前往火场，靠近火源按住 E 灭火。"},
	"heal": {"name": "紧急救护", "job": "doctor", "reward": 280, "heat": 0.0,
		"desc": "前往伤员位置，按住 E 进行急救。"},
	"capture": {"name": "抢占地盘", "job": "gangster", "reward": 520, "heat": 1.0,
		"desc": "在标记点驻守 12 秒，把地盘从对家手里抢过来。"},
	"deliver": {"name": "走私送货", "job": "gangster", "reward": 460, "heat": 0.5,
		"desc": "把货送到指定地点，途中别被警察拦下。"},
	"rob": {"name": "洗劫便利店", "job": "gangster", "reward": 880, "heat": 2.0,
		"desc": "前往便利店，按住 E 撬开收银台。会大幅提升通缉度。"},
}

const MISSION_ORDER := ["patrol", "arrest", "fire", "heal", "capture", "deliver", "rob"]

# ─────────────────────────── 杂项 ───────────────────────────
const START_CASH := 2000
const DAY_LENGTH := 720.0        # 一天 = 12 分钟真实时间
const START_HOUR := 8.0
const INTERACT_DIST := 3.2

const STREETS := ["枫叶大道", "中城路", "西码头街", "松林巷", "湖滨路"]
