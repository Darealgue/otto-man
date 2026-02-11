# Ticaret Sistemi Önerileri ve Entegrasyon Planı

## 1. TÜCCAR ÇEŞİTLİLİĞİ

### Mevcut Durum
- Şu anda tüm tüccarlar aynı şekilde oluşturuluyor
- Sadece isimleri farklı

### Öneri: Tüccar Tipleri Sistemi

#### Tüccar Tipleri:
1. **Zengin Tüccar** (RICH_TRADER)
   - Daha pahalı ama nadir ürünler satar
   - Daha fazla ürün çeşidi (3-4 ürün)
   - İlişki bonusu daha yüksek etkili

2. **Fakir Tüccar** (POOR_TRADER)
   - Ucuz ama temel ürünler satar
   - Az ürün çeşidi (1-2 ürün)
   - İlişki bonusu daha düşük etkili

3. **Özel Ürün Tüccarı** (SPECIAL_TRADER)
   - Belirli bir ürün tipinde uzmanlaşmış
   - O ürünü çok ucuza satar, diğerlerini pahalı
   - İlişkiye göre özel ürün fiyatı değişir

4. **Gezgin Tüccar** (NOMAD_TRADER)
   - Çok çeşitli ürünler (4-5 ürün)
   - Fiyatlar ortalama
   - Daha uzun süre kalır (4-6 gün)

### Entegrasyon Kodu:

```gdscript
# MissionManager.gd içine eklenecek

enum TraderType { NORMAL, RICH, POOR, SPECIAL, NOMAD }

func add_active_trader(origin_settlement: Dictionary, arrives_day: int, stays_days: int = 3, trader_type: TraderType = TraderType.NORMAL) -> Dictionary:
	if settlements.is_empty():
		create_settlements()
	
	var settlement_name = origin_settlement.get("name", "Bilinmeyen Köy")
	var relation = int(origin_settlement.get("relation", 50))
	
	# Tüccar tipine göre özellikler
	var trader_config = _get_trader_config(trader_type, relation)
	
	# Tüccar ismi oluştur (tipine göre)
	var trader_name = _generate_trader_name(trader_type)
	
	# Ürünler oluştur (tipine göre)
	var products = _generate_trader_products(trader_type, relation, origin_settlement)
	
	var trader = {
		"id": "trader_%d" % Time.get_unix_time_from_system(),
		"name": trader_name,
		"type": trader_type,
		"origin_settlement": settlement_name,
		"origin_settlement_id": origin_settlement.get("id", ""),
		"products": products,
		"arrives_day": arrives_day,
		"leaves_day": arrives_day + trader_config["stays_days"],
		"relation_multiplier": trader_config["relation_multiplier"],
		"relation": relation
	}
	
	active_traders.append(trader)
	active_traders_updated.emit()
	
	# Haber gönder
	var type_name = _get_trader_type_name(trader_type)
	post_news("Başarı", "💰 %s Geldi" % type_name, "%s köyünüze geldi!" % trader_name, Color(0.8,1,0.8))
	
	return trader

func _get_trader_config(trader_type: TraderType, relation: int) -> Dictionary:
	match trader_type:
		TraderType.RICH:
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.004),  # Daha fazla indirim
				"product_count": randi_range(3, 4),
				"price_range": [80, 150]  # Daha pahalı
			}
		TraderType.POOR:
			return {
				"stays_days": 2,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.002),  # Daha az indirim
				"product_count": randi_range(1, 2),
				"price_range": [30, 70]  # Daha ucuz
			}
		TraderType.SPECIAL:
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.005),  # Çok fazla indirim
				"product_count": randi_range(2, 3),
				"price_range": [40, 100],
				"special_resource": _get_settlement_special_resource(origin_settlement)
			}
		TraderType.NOMAD:
			return {
				"stays_days": randi_range(4, 6),
				"relation_multiplier": 1.0 - ((relation - 50) * 0.003),
				"product_count": randi_range(4, 5),
				"price_range": [50, 120]
			}
		_:  # NORMAL
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.003),
				"product_count": randi_range(2, 3),
				"price_range": [50, 130]
			}

func _generate_trader_name(trader_type: TraderType) -> String:
	var names_by_type = {
		TraderType.RICH: ["Zengin", "Varlıklı", "Büyük", "Ünlü"],
		TraderType.POOR: ["Fakir", "Küçük", "Seyyar", "Yoksul"],
		TraderType.SPECIAL: ["Uzman", "Özel", "Nadir", "Değerli"],
		TraderType.NOMAD: ["Gezgin", "Göçebe", "Seyyah", "Dolaşan"]
	}
	
	var prefixes = names_by_type.get(trader_type, ["Normal"])
	var first_names = ["Ahmet", "Mehmet", "Ali", "Hasan", "Hüseyin"]
	
	return prefixes[randi() % prefixes.size()] + " " + first_names[randi() % first_names.size()] + " Tüccar"
```

### VillageManager'da Kullanım:

```gdscript
# VillageManager.gd - _trigger_village_event içinde

"trade_caravan":
	# Tüccar tipini rastgele seç (ilişkiye göre ağırlıklandır)
	var trader_type = _select_trader_type_by_relation(settlement)
	if mm.has_method("add_active_trader"):
		mm.add_active_trader(settlement, day, stays_days, trader_type)

func _select_trader_type_by_relation(settlement: Dictionary) -> int:
	var relation = settlement.get("relation", 50)
	var rand_val = randf()
	
	# İyi ilişkilerde daha iyi tüccarlar gelir
	if relation >= 70:
		if rand_val < 0.3:
			return MissionManager.TraderType.RICH
		elif rand_val < 0.5:
			return MissionManager.TraderType.SPECIAL
		elif rand_val < 0.7:
			return MissionManager.TraderType.NOMAD
		else:
			return MissionManager.TraderType.NORMAL
	elif relation >= 40:
		if rand_val < 0.2:
			return MissionManager.TraderType.SPECIAL
		elif rand_val < 0.4:
			return MissionManager.TraderType.NOMAD
		else:
			return MissionManager.TraderType.NORMAL
	else:
		if rand_val < 0.3:
			return MissionManager.TraderType.POOR
		else:
			return MissionManager.TraderType.NORMAL
```

---

## 2. İLİŞKİ SİSTEMİ GELİŞTİRMESİ

### Mevcut Durum
- İlişki sadece fiyat çarpanını etkiliyor
- İlişki arttıkça daha fazla tüccar gelmesi yok

### Öneri: İlişki Bazlı Tüccar Sistemi

#### Özellikler:
1. **İyi İlişkiler (70+)**
   - Daha sık tüccar gelir (%30 şans yerine %50)
   - Daha iyi tüccar tipleri (Zengin, Özel)
   - Daha fazla ürün çeşidi
   - Daha uzun kalma süresi

2. **Kötü İlişkiler (30-)**
   - Nadiren tüccar gelir (%10 şans)
   - Sadece fakir tüccarlar gelir
   - Az ürün çeşidi
   - Kısa kalma süresi

3. **İlişki Artışı**
   - Tüccardan satın alma yapınca +1 ilişki
   - Tüccar cariye görevi başarılı olunca +2-5 ilişki
   - Büyük alımlar bonus ilişki verir

### Entegrasyon Kodu:

```gdscript
# MissionManager.gd - buy_from_trader fonksiyonuna ekleme

func buy_from_trader(trader_id: String, resource: String, quantity: int) -> bool:
	# ... mevcut kod ...
	
	# İlişki artışı (satın alma sonrası)
	var trader = _find_trader_by_id(trader_id)
	if not trader.is_empty():
		var settlement_id = trader.get("origin_settlement_id", "")
		_increase_settlement_relation(settlement_id, 1)  # +1 ilişki
		
		# Büyük alımlar bonus ilişki verir
		if quantity >= 10:
			_increase_settlement_relation(settlement_id, 1)  # +1 bonus
		if quantity >= 25:
			_increase_settlement_relation(settlement_id, 1)  # +1 bonus daha
	
	return true

func _increase_settlement_relation(settlement_id: String, amount: int):
	for s in settlements:
		if s.get("id") == settlement_id:
			var old_relation = s.get("relation", 50)
			s["relation"] = clamp(old_relation + amount, 0, 100)
			
			# İlişki değişikliği haberi
			if amount > 0:
				post_news("Bilgi", "İlişki Artışı", "%s ile ilişkiler +%d arttı (Yeni: %d)" % [s.get("name", "?"), amount, s["relation"]], Color(0.8,1,0.8))
			break
```

### VillageManager'da İlişki Bazlı Event Şansı:

```gdscript
# VillageManager.gd - _check_and_trigger_village_event içinde

func _check_and_trigger_village_event(day: int) -> bool:
	# İlişkiye göre tüccar gelme şansı
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return false
	
	var settlements = mm.settlements if mm.has("settlements") else []
	if settlements.is_empty():
		return false
	
	# En yüksek ilişkiye sahip yerleşimden tüccar gelme şansı
	var best_settlement = null
	var best_relation = 0
	for s in settlements:
		var rel = s.get("relation", 50)
		if rel > best_relation:
			best_relation = rel
			best_settlement = s
	
	if not best_settlement:
		return false
	
	# İlişkiye göre şans hesapla
	var base_chance = 0.1  # %10 temel şans
	var relation_bonus = (best_relation - 50) * 0.01  # Her 1 ilişki = %1 bonus
	var final_chance = clamp(base_chance + relation_bonus, 0.05, 0.5)  # Min %5, Max %50
	
	if randf() < final_chance:
		_trigger_village_event("trade_caravan", day)
		return true
	
	return false
```

---

## 3. TİCARET ROTALARI

### Mevcut Durum
- Tüccarlar rastgele geliyor
- Rotasyon veya öncelik yok

### Öneri: Ticaret Rotası Sistemi

#### Özellikler:
1. **Rota Tanımlama**
   - Her yerleşim belirli rotalara sahip
   - Rotada belirli ürünler taşınır
   - Rota mesafesi ve risk seviyesi var

2. **Rota Avantajları**
   - Aynı rotada ticaret yapınca ilişki daha hızlı artar
   - Rota üzerinde ticaret yapınca bonus kâr
   - Rota güvenliği artınca risk azalır

3. **Dinamik Rotalar**
   - İlişki arttıkça yeni rotalar açılır
   - Düşmanlık durumunda rotalar kapanır
   - Bandit aktivitesi rotaları etkiler

### Entegrasyon Kodu:

```gdscript
# MissionManager.gd içine eklenecek

var trade_routes: Array[Dictionary] = []  # [{from, to, products:[], distance, risk, active}]

func _initialize_trade_routes():
	# Yerleşimler arası rotalar oluştur
	if settlements.size() < 2:
		return
	
	for i in range(settlements.size()):
		for j in range(i + 1, settlements.size()):
			var from_settlement = settlements[i]
			var to_settlement = settlements[j]
			
			# Rota oluştur (ilişkiye göre aktif/pasif)
			var relation_from = from_settlement.get("relation", 50)
			var relation_to = to_settlement.get("relation", 50)
			var avg_relation = (relation_from + relation_to) / 2.0
			
			var route = {
				"from": from_settlement.get("id", ""),
				"from_name": from_settlement.get("name", ""),
				"to": to_settlement.get("id", ""),
				"to_name": to_settlement.get("name", ""),
				"products": _get_route_products(from_settlement, to_settlement),
				"distance": randf_range(1.0, 5.0),
				"risk": _calculate_route_risk(avg_relation),
				"active": avg_relation >= 30,  # 30+ ilişki gerekli
				"relation": avg_relation
			}
			
			trade_routes.append(route)

func _get_route_products(from_settlement: Dictionary, to_settlement: Dictionary) -> Array[String]:
	# Her yerleşimin bias'ına göre ürünler
	var from_biases = from_settlement.get("biases", {})
	var to_biases = to_settlement.get("biases", {})
	
	var products: Array[String] = []
	
	# From'dan To'ya giden ürünler (from'un fazla ürettiği)
	for resource in from_biases.keys():
		if from_biases[resource] > 1:
			products.append(resource)
	
	# To'dan From'a giden ürünler (to'nun fazla ürettiği)
	for resource in to_biases.keys():
		if to_biases[resource] > 1 and not resource in products:
			products.append(resource)
	
	# En az 1 ürün olsun
	if products.is_empty():
		products = ["food", "wood", "stone"]
	
	return products

func _calculate_route_risk(relation: float) -> String:
	if relation >= 70:
		return "Düşük"
	elif relation >= 50:
		return "Orta"
	elif relation >= 30:
		return "Yüksek"
	else:
		return "Çok Yüksek"

# Tüccar cariye görevi oluştururken rota kullan
func create_trade_mission_for_route(cariye_id: int, route_id: String, products: Dictionary, soldier_count: int = 0) -> Mission:
	var route = _find_route_by_id(route_id)
	if route.is_empty():
		return null
	
	var mission = Mission.new()
	mission.id = "trade_route_%d" % Time.get_unix_time_from_system()
	mission.name = "Ticaret: %s → %s" % [route.get("from_name", "?"), route.get("to_name", "?")]
	mission.description = "%s'ye ticaret malı götür." % route.get("to_name", "?")
	mission.mission_type = Mission.MissionType.TİCARET
	mission.difficulty = _get_route_difficulty(route)
	mission.duration = route.get("distance", 2.0) * 60.0  # Mesafe * 60 dakika
	mission.success_chance = _calculate_trade_success_chance(route, cariye_id)
	mission.required_cariye_level = 1
	mission.required_army_size = soldier_count
	mission.required_resources = products  # Götürülecek mallar
	mission.rewards = _calculate_trade_rewards(route, products)
	mission.penalties = _calculate_trade_penalties(route)
	mission.target_location = route.get("to_name", "?")
	mission.distance = route.get("distance", 2.0)
	mission.risk_level = route.get("risk", "Orta")
	
	return mission
```

---

## 4. TÜCCAR CARİYE YETENEKLERİ

### Mevcut Durum
- Cariyelerin TİCARET yeteneği var ama ticaret görevlerinde kullanılmıyor
- Sadece başarı şansını etkiliyor

### Öneri: Ticaret Yeteneği Sistemi

#### Özellikler:
1. **Kâr Hesaplama**
   - Ticaret yeteneği yüksek cariyeler daha iyi fiyatlar alır
   - Her 10 yetenek = %5 kâr bonusu
   - Seviye de bonus verir

2. **İlişki Artışı**
   - Ticaret yeteneği yüksek cariyeler ilişkiyi daha fazla artırır
   - Başarılı ticaret görevleri +2-5 ilişki yerine +3-7 ilişki

3. **Özel Yetenekler**
   - 80+ Ticaret: "Pazarlık Ustası" - %10 ekstra kâr
   - 90+ Ticaret: "Ticaret Efendisi" - İlişki artışı x1.5
   - 100 Ticaret: "Ticaret Efsanesi" - Risk %50 azalır

### Entegrasyon Kodu:

```gdscript
# MissionManager.gd - Ticaret görevi tamamlandığında

func _process_trade_mission_completion(cariye_id: int, mission_id: String, successful: bool, route: Dictionary, products: Dictionary):
	if not successful:
		return
	
	var cariye = concubines.get(cariye_id)
	if not cariye:
		return
	
	var trade_skill = cariye.get_skill_level(Concubine.Skill.TİCARET)
	var level = cariye.level
	
	# Kâr hesaplama (yetenek ve seviye bonusu)
	var base_profit = _calculate_base_profit(route, products)
	var skill_bonus_multiplier = 1.0 + (trade_skill * 0.005)  # Her 1 yetenek = %0.5 bonus
	var level_bonus_multiplier = 1.0 + (level * 0.02)  # Her 1 seviye = %2 bonus
	
	# Özel yetenekler
	if trade_skill >= 100:
		skill_bonus_multiplier *= 1.1  # %10 ekstra (Efsane)
	elif trade_skill >= 90:
		skill_bonus_multiplier *= 1.05  # %5 ekstra (Efendi)
	elif trade_skill >= 80:
		skill_bonus_multiplier *= 1.02  # %2 ekstra (Usta)
	
	var final_profit = int(base_profit * skill_bonus_multiplier * level_bonus_multiplier)
	
	# Altın ekle
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		gpd.gold += final_profit
	
	# İlişki artışı (yetenek bonuslu)
	var base_relation_gain = 2 + randi_range(0, 3)  # 2-5 temel
	var skill_relation_bonus = 1.0
	if trade_skill >= 90:
		skill_relation_bonus = 1.5  # %50 bonus
	elif trade_skill >= 80:
		skill_relation_bonus = 1.25  # %25 bonus
	
	var final_relation_gain = int(base_relation_gain * skill_relation_bonus)
	_increase_settlement_relation(route.get("to", ""), final_relation_gain)
	
	# Cariye deneyim kazancı (ticaret görevleri için özel)
	var exp_gain = 30 + (trade_skill / 2)  # Yetenek arttıkça daha fazla exp
	cariye.add_experience(int(exp_gain))
	
	# Haber
	var skill_text = ""
	if trade_skill >= 100:
		skill_text = " (Efsanevi Ticaret Ustası!)"
	elif trade_skill >= 90:
		skill_text = " (Ticaret Efendisi)"
	elif trade_skill >= 80:
		skill_text = " (Pazarlık Ustası)"
	
	post_news("Başarı", "Ticaret Başarılı%s" % skill_text, 
		"%s ticaret görevini tamamladı. +%d altın kazandınız, +%d ilişki artışı." % [cariye.name, final_profit, final_relation_gain],
		Color(0.8,1,0.8))

func _calculate_base_profit(route: Dictionary, products: Dictionary) -> int:
	# Temel kâr hesaplama (ürünlerin değerine göre)
	var total_profit = 0
	for resource in products.keys():
		var quantity = products[resource]
		var base_value = _get_resource_base_value(resource)
		var route_multiplier = 1.2 + (route.get("relation", 50) - 50) * 0.01  # İlişkiye göre kâr
		total_profit += int(base_value * quantity * route_multiplier)
	
	return total_profit

func _get_resource_base_value(resource: String) -> int:
	match resource:
		"food": return 40
		"wood": return 35
		"stone": return 45
		"water": return 30
		_: return 40
```

---

## ÖZET: ENTEGRASYON ADIMLARI

1. **Tüccar Çeşitliliği** (Kolay)
   - `TraderType` enum ekle
   - `add_active_trader` fonksiyonunu genişlet
   - VillageManager'da tip seçimi ekle

2. **İlişki Sistemi** (Orta)
   - `buy_from_trader` içine ilişki artışı ekle
   - VillageManager'da ilişki bazlı event şansı ekle
   - Ticaret görevlerinde ilişki artışı ekle

3. **Ticaret Rotaları** (Zor)
   - `trade_routes` array'i ekle
   - Rota oluşturma fonksiyonları ekle
   - Ticaret görevi oluştururken rota kullan

4. **Tüccar Cariye Yetenekleri** (Orta)
   - Ticaret görevi tamamlandığında yetenek bonusları ekle
   - Kâr hesaplamasına yetenek ekle
   - Özel yetenek kontrolleri ekle

Hangi öneriyi önce uygulayalım?
