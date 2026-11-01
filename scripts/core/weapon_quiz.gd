class_name WeaponQuiz
extends RefCounted
## 购枪资格测验题库与判定逻辑（纯数据 + 静态方法，无场景依赖）
##
## 用法：
##   var rng := RandomNumberGenerator.new()
##   var questions: Array = WeaponQuiz.pick(3, rng)          # 随机抽取 3 题
##   var passed: bool = WeaponQuiz.is_passed(questions, answers)  # answers 为选项下标
##
## 每题结构：{"q": String, "options": [4 × String], "answer": int (0-3), "explain": String}
## 题库覆盖：枪口指向、扳机纪律、验空、保管上锁、运输、酒后、责任、用枪原则、
##          射击后处置、非法改装、未成年人、登记、哑弹、枪套、穿透风险、违规举报。

const BANK_SIZE := 16

const BANK: Array = [
	{
		"q": "在枪店验枪时，枪口应该指向哪里？",
		"options": [
			"店主站立的方向",
			"天花板或墙壁等安全方向",
			"自己的脚边",
			"窗外街道上的行人"
		],
		"answer": 1,
		"explain": "无论枪内是否有弹，枪口都应指向不会造成伤害的安全方向。"
	},
	{
		"q": "手指没有准备击发时，应该放在什么位置？",
		"options": [
			"轻放在扳机上",
			"搭在弹匣底部",
			"扳机护圈外的枪身上",
			"勾住扳机护圈"
		],
		"answer": 2,
		"explain": "这就是「金手指」原则：手指离开扳机，直到瞄准并决定射击。"
	},
	{
		"q": "拿到一把不熟悉的枪，第一步应该做什么？",
		"options": [
			"卸下弹匣并检查弹膛，确认无弹",
			"先扣一下扳机试试手感",
			"直接装上弹匣上膛",
			"用布把枪身擦亮"
		],
		"answer": 0,
		"explain": "任何枪械都要先按规程验空，确认弹膛无弹后再做其他操作。"
	},
	{
		"q": "在家中存放枪支，最稳妥的做法是？",
		"options": [
			"放在床头柜里，随取随用",
			"藏在沙发垫下面",
			"交给未成年的孩子保管",
			"枪弹分离并锁进枪柜，钥匙自己保管"
		],
		"answer": 3,
		"explain": "枪弹分离、上锁保管，能最大限度避免家人误触和被盗。"
	},
	{
		"q": "把刚买的枪带回住处，应该怎么携带？",
		"options": [
			"直接插在裤腰里走回家",
			"装进合规枪箱或枪套，按当地法规运输",
			"举在手里让别人都能看见",
			"交给朋友帮忙拿"
		],
		"answer": 1,
		"explain": "运输枪支要符合当地法规，使用枪箱或合规枪套并保持空膛。"
	},
	{
		"q": "喝过酒之后，正确的做法是？",
		"options": [
			"绝对不碰枪，把枪交给清醒的人保管",
			"只喝一点就可以持枪",
			"在室内持枪没关系",
			"酒后可以射击但不要上膛"
		],
		"answer": 0,
		"explain": "酒精会显著影响判断力，酒后持枪既极度危险又通常违法。"
	},
	{
		"q": "因为疏忽导致枪支走火伤到他人，责任由谁承担？",
		"options": [
			"枪店老板",
			"枪支生产厂商",
			"持枪者本人，需承担法律与赔偿责任",
			"没有人需要负责"
		],
		"answer": 2,
		"explain": "持枪者对自己的枪支负有完全的保管与使用责任。"
	},
	{
		"q": "警察在什么情况下才可以使用致命武力？",
		"options": [
			"嫌疑人试图逃跑时",
			"对方态度不配合时",
			"只要亮出武器就可以",
			"本人或他人面临迫在眉睫的生命威胁时"
		],
		"answer": 3,
		"explain": "致命武力只能作为保护生命的最后手段，且必须符合法律授权。"
	},
	{
		"q": "在靶场射击结束后，应该先做什么？",
		"options": [
			"把枪直接放进背包",
			"卸弹、验膛，再收枪入箱",
			"留在靶位让工作人员收",
			"把枪递给旁边的人"
		],
		"answer": 1,
		"explain": "射击结束同样要验空，确认安全后再收纳离场。"
	},
	{
		"q": "可以自己把半自动枪械改装成全自动吗？",
		"options": [
			"只要不上街就没问题",
			"在郊外练习时可以",
			"不可以，改装和持有都违反法律",
			"朋友同意就可以"
		],
		"answer": 2,
		"explain": "私自改装枪械通常属于严重违法，购买前必须了解当地法规。"
	},
	{
		"q": "未成年家人对枪很好奇，想拿去玩，你会怎么做？",
		"options": [
			"明确拒绝并说明危险，枪支必须上锁保管",
			"教他开一枪，满足好奇心",
			"让他自己拿去看看",
			"只要不装弹就可以随便玩"
		],
		"answer": 0,
		"explain": "未成年人不得接触枪支，好奇心要靠教育和安全保管来引导。"
	},
	{
		"q": "购买或转让枪支时，正确的做法是？",
		"options": [
			"私下现金交易，不留下记录",
			"只写一张收条就行",
			"不需要任何手续",
			"通过有资质的枪店并按规定登记"
		],
		"answer": 3,
		"explain": "合规购买与登记是持枪合法性的基础，也能避免枪支流入非法渠道。"
	},
	{
		"q": "扣下扳机却没有枪响（哑弹），首先应该怎么做？",
		"options": [
			"立刻把枪口转向自己检查",
			"用力连续扣动扳机",
			"保持枪口朝向安全方向，等待片刻后按规程处理",
			"把枪递给旁边的人看"
		],
		"answer": 2,
		"explain": "哑弹也可能迟发，必须保持枪口安全并等待，切勿立即转枪口或递枪。"
	},
	{
		"q": "随身携带枪支时，枪套应该满足什么要求？",
		"options": [
			"越松越好，方便快速拔枪",
			"随便用根绳子绑住",
			"不用枪套，直接塞进口袋",
			"完全包住扳机护圈并固定牢靠"
		],
		"answer": 3,
		"explain": "合格的枪套必须遮住扳机护圈并固定枪支，防止走火与掉落。"
	},
	{
		"q": "射击前要观察目标后方，是因为？",
		"options": [
			"子弹可能穿透目标，误伤后方的人或物",
			"这样拍照更好看",
			"可以打得更准",
			"后方的人会帮忙捡弹壳"
		],
		"answer": 0,
		"explain": "子弹可能穿透或跳弹，确认目标后方是安全区域才能射击。"
	},
	{
		"q": "发现有人违规携枪进入公共场所，应该怎么做？",
		"options": [
			"冲上去把枪夺下来",
			"围观拍照发到网上",
			"当作没看见继续走",
			"保持距离并立即报警，不要自行上前"
		],
		"answer": 3,
		"explain": "遇到违规持枪要保持距离、保护自己并立即报警，不要自行处置。"
	}
]


## 从题库中随机抽取 count 道不重复的题目（按 rng 洗牌，结果确定可复现）。
## count 超过题库数量时按题库上限截断；count <= 0 返回空数组。
static func pick(count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = BANK.duplicate(true)
	if count <= 0 or pool.is_empty():
		return []
	var n: int = mini(count, pool.size())
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	# Fisher-Yates，保证同一 seed 结果一致
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	pool.resize(n)
	return pool


## 全对才算通过。题数不一致、空题组、非法数据结构一律视为未通过。
static func is_passed(questions: Array, answers: Array) -> bool:
	if questions.is_empty() or questions.size() != answers.size():
		return false
	for i in range(questions.size()):
		var q: Variant = questions[i]
		if typeof(q) != TYPE_DICTIONARY:
			return false
		if int(answers[i]) != int(q.get("answer", -1)):
			return false
	return true


## 统计答对题数（供 UI 显示得分用）。
static func count_correct(questions: Array, answers: Array) -> int:
	var correct: int = 0
	var n: int = mini(questions.size(), answers.size())
	for i in range(n):
		var q: Variant = questions[i]
		if typeof(q) == TYPE_DICTIONARY and int(answers[i]) == int(q.get("answer", -1)):
			correct += 1
	return correct
