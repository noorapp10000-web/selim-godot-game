extends RefCounted
# Shop catalog (v6). Prices are deliberately steep: a full chapter on easy pays roughly 230 coins early and
# ~650 late (map coins + enemy drops + clear reward), so a new weapon costs two to four chapters of saving and
# the player can never buy everything in one run. Upgrades get dearer with every level (see Game.item_price).
# "icon" = cell index in assets/ui/shop_icons_v2.png (128x128 cells), "cat" = shop tab,
# "tier" = card rarity frame (0 common, 1 rare, 2 epic, 3 legendary), "max" = upgrade levels.
const ITEMS := {
 "stick": {"name": "عصاية الجد", "desc": "متوازنة وخفيفة. أول سلاح في الرحلة.", "price": 0, "unlock": 1, "damage": 0, "reach": 0.0, "tempo": 1.0, "icon": 5, "cat": "weapon", "sfx": "", "tier": 0},
 "saber": {"name": "سيف الحارس", "desc": "حديد مسنون: ضرر أعلى ومدى أطول من العصاية.", "price": 450, "unlock": 2, "damage": 1, "reach": 8.0, "tempo": 1.0, "icon": 8, "cat": "weapon", "sfx": "saber", "tier": 1},
 "spear": {"name": "رمح النيل", "desc": "أطول مدى في الدكان. أبطأ شوية بس بيطول البعيد.", "price": 900, "unlock": 4, "damage": 1, "reach": 22.0, "tempo": 0.85, "icon": 9, "cat": "weapon", "sfx": "spear", "tier": 1},
 "hammer": {"name": "مطرقة حورس", "desc": "ضربة تقيلة تكسر الدروع. بطيئة لكن مرعبة.", "price": 1600, "unlock": 7, "damage": 3, "reach": 6.0, "tempo": 0.72, "icon": 10, "cat": "weapon", "sfx": "hammer", "tier": 2},
 "khopesh": {"name": "خُبش الشمس", "desc": "سلاح الفراعنة الأسطوري: سريع وضرره عالي.", "price": 2600, "unlock": 10, "damage": 2, "reach": 12.0, "tempo": 1.25, "icon": 11, "cat": "weapon", "sfx": "khopesh", "tier": 3},
 "health": {"name": "قلب البطل", "desc": "قلب إضافي دائم في كل ترقية.", "price": 300, "unlock": 1, "icon": 2, "cat": "upgrade", "tier": 2, "max": 4},
 "power": {"name": "قبضة الأسد", "desc": "كل ضرباتك وركلاتك أقوى بنقطة ضرر.", "price": 420, "unlock": 2, "icon": 12, "cat": "upgrade", "tier": 2, "max": 3},
 "armor": {"name": "درع الجعران", "desc": "فرصة ١٥٪ لكل ترقية إنك تصد الضربة من غير ما تتأذي.", "price": 480, "unlock": 4, "icon": 13, "cat": "upgrade", "tier": 3, "max": 3},
 "boots": {"name": "جزمة الرحالة", "desc": "سرعة +٨٪ وزحلقة أسرع مع كل ترقية.", "price": 260, "unlock": 3, "icon": 3, "cat": "upgrade", "tier": 1, "max": 3},
 "magnet": {"name": "عين حورس", "desc": "تجذب العملات من مسافة أبعد.", "price": 380, "unlock": 5, "icon": 14, "cat": "upgrade", "tier": 1, "max": 2},
 "potion": {"name": "إسعاف سريع", "desc": "يرجّع ٦ صحة في ثانية. تقدر تشيل ٥.", "price": 60, "unlock": 1, "icon": 0, "cat": "supply", "tier": 0},
 "bomb": {"name": "قنبلة دخان", "desc": "ضرر ٨ لكل اللي حواليك وحماية قصيرة. تقدر تشيل ٥.", "price": 95, "unlock": 3, "icon": 1, "cat": "supply", "tier": 0}
}
const WEAPONS := ["stick", "saber", "spear", "hammer", "khopesh"]
const UPGRADES := ["health", "power", "armor", "boots", "magnet"]
const CATEGORIES := [["weapon", "الأسلحة"], ["upgrade", "التطويرات"], ["supply", "المؤن"]]
const TIER_NAMES := ["عادي", "نادر", "ملحمي", "أسطوري"]
const TIER_COLORS := [Color(0.70, 0.67, 0.62), Color(0.60, 0.74, 0.84), Color(0.76, 0.66, 0.84), Color(0.95, 0.76, 0.44)]
# Each further upgrade level costs this much more than the base price (level 2 = x1.8, level 3 = x2.6 ...).
const UPGRADE_STEP := 0.8
const LOADOUT_SIZE := 2
