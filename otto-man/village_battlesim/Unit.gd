extends CharacterBody2D
class_name Unit

# <<< YENİ: Birim öldüğünde gönderilecek sinyal >>>
signal died(unit)

# Bu birimin istatistiklerini tutan Resource dosyası
@export var stats: UnitStats = null

# Mevcut can puanı
var current_hp: int = 100
# Hangi takıma ait (örn: 0 = oyuncu, 1 = düşman)
var team_id: int = 0 

# Birimin olası durumları
enum State {
    IDLE,
    MOVING,
    ATTACKING,
    FLEEING
}
var current_state = State.MOVING # Başlangıç durumu (MOVING olarak başlasın)

# Hareket hedefi (şimdilik basit bir yön)
var move_direction: Vector2 = Vector2.ZERO

# Sahnedeki Sprite noduna erişim
@onready var sprite: Sprite2D = $Sprite2D

# Hedef düşman
var target_enemy: Unit = null 

# Saldırı zamanlayıcısı
var attack_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var friendly_detection_area: Area2D = $FriendlyDetectionArea
# @onready var collision_shape: CollisionShape2D = $DetectionArea/CollisionShape2D # Gerekirse

var position_debug_timer: float = 0.0
const POSITION_DEBUG_INTERVAL: float = 5.0 # Saniye cinsinden yazdırma aralığı

const ARCHER_FLEE_DISTANCE = 60.0 # Yakın dövüşçü bu mesafeye girerse okçu kaçar

# <<< YENİ: Zamanlayıcı Değişkenleri >>>
var threat_check_timer: float = 0.0
const THREAT_CHECK_INTERVAL: float = 0.5 # Saniye cinsinden tehdit kontrol aralığı
var current_threat: Unit = null # Mevcut tehdidi takip etmek için
# <<< YENİ SONU >>>

# <<< YENİ: Jitter Hareketi için Değişkenler >>>
var jitter_timer: float = 0.0
const JITTER_INTERVAL: float = 0.6 # Saniye cinsinden yön değiştirme sıklığı (Artırıldı)
var jitter_target_offset: Vector2 = Vector2.ZERO # Gidilecek küçük hedef ofseti

# <<< YENİ: BattleScene referansı >>>
var battle_scene_ref = null

# <<< YENİ: Savaş alanı sınırı >>>
var battle_area_limit: Rect2 = Rect2(0,0,0,0) # BattleScene tarafından atanacak

# <<< YENİ: Hasar Görsel Efekti Zamanlayıcısı >>>
var damage_flash_timer: float = 0.0
const DAMAGE_FLASH_DURATION: float = 0.2 # Saniye cinsinden

# <<< YENİ: Ayrılma Ağırlığı >>>
const SEPARATION_WEIGHT = 0.1 # Ayrılma davranışının etkisini belirler (0.0 - 1.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    if stats == null:
        printerr("Unit (%s) has no stats assigned!" % name)
        queue_free()
        return

    current_hp = stats.max_hp
    attack_timer = stats.attack_speed # Başlangıçta hemen saldırmasın

    # <<< GÜNCELLENDİ: Fizik, Düşman Algılama ve Dost Algılama Katman Ayarları >>>
    # Physics Body: Tüm birimler Layer 1'de, Layer 1 ile çarpışır.
    self.collision_layer = 1
    self.collision_mask = 1 
    
    # Detection Area (Düşman Algılama): Takımlar sadece birbirini algılar.
    # Friendly Detection Area (Dost Algılama): Takımlar sadece kendini algılar.
    if team_id == 0: # Player
        # Düşman Algılama: Layer 11, Detects Layer 12 (Enemy Area)
        detection_area.collision_layer = pow(2, 10) # 1024
        detection_area.collision_mask = pow(2, 11)  # 2048
        # Dost Algılama: Layer 3, Detects Layer 3 (Friendly Area)
        friendly_detection_area.collision_layer = pow(2, 2) # 4
        friendly_detection_area.collision_mask = pow(2, 2)  # 4
        friendly_detection_area.monitorable = true # Tespit edilebilmesi için
    elif team_id == 1: # Enemy
        # Düşman Algılama: Layer 12, Detects Layer 11 (Player Area)
        detection_area.collision_layer = pow(2, 11) # 2048
        detection_area.collision_mask = pow(2, 10)  # 1024
        # Dost Algılama: Layer 4, Detects Layer 4 (Friendly Area)
        friendly_detection_area.collision_layer = pow(2, 3) # 8
        friendly_detection_area.collision_mask = pow(2, 3)  # 8
        friendly_detection_area.monitorable = true # Tespit edilebilmesi için
    else:
        printerr("Unit (%s) has invalid team_id: %d" % [name, team_id])
        # Hata durumunda çarpışmayı/algılamayı kapat
        self.collision_layer = 0
        self.collision_mask = 0
        detection_area.collision_layer = 0
        detection_area.collision_mask = 0
        friendly_detection_area.collision_layer = 0 # <<< YENİ
        friendly_detection_area.collision_mask = 0  # <<< YENİ

    # Alanların izleme/izlenebilirlik durumunu her zaman açık tutalım
    detection_area.monitoring = true
    detection_area.monitorable = true
    friendly_detection_area.monitoring = true # <<< YENİ
    # <<< AYARLAR SONU >>>

    # Sinyalleri bağla (Bu kısım aynı kalıyor)
    detection_area.area_entered.connect(_on_detection_area_area_entered)
    detection_area.area_exited.connect(_on_detection_area_area_exited)

    # Başlangıç hareket yönü (MOVING state içinde dinamik)
    # if team_id == 0: move_direction = Vector2.RIGHT
    # elif team_id == 1: move_direction = Vector2.LEFT

# Hasar alma fonksiyonu
func take_damage(damage_amount: int) -> void:
    # <<< YENİ: Blok Kontrolü >>>
    if stats != null and stats.block_chance > 0:
        if randf() < stats.block_chance:
            print("%s BLOKLADI!" % name)
            # Hasar efektini yine de tetikleyebiliriz (isteğe bağlı)
            # damage_flash_timer = DAMAGE_FLASH_DURATION * 0.5 # Daha kısa bir flash?
            # sprite.modulate = Color.GRAY # Farklı bir renk?
            return # Hasar almadı

    # Savunmayı hesaba kat
    var actual_damage = max(0, damage_amount - stats.defense)
    current_hp -= actual_damage
    print("%s took %d damage (%d raw). HP left: %d / %d" % [name, actual_damage, damage_amount, current_hp, stats.max_hp])

    # Hasar Efektini Başlat
    damage_flash_timer = DAMAGE_FLASH_DURATION
    sprite.modulate = Color.RED

    # Ölüm kontrolü
    print("DEBUG: Checking death for %s. HP: %d" % [name, current_hp])
    if current_hp <= 0:
        _die()

# Ölüm fonksiyonu (şimdilik basitçe kendini yok ediyor)
func _die() -> void:
    # <<< YENİ: Ölüm sinyalisni gönder >>>
    died.emit(self)

    print("DEBUG: _die() called for %s" % name) # <<< YENİ DEBUG
    if is_queued_for_deletion(): return # Zaten siliniyorsa tekrar çağırma
    
    print("%s died!" % name) # DEBUG
    queue_free() # Sahneden sil

# _process fonksiyonu ileride hareket, saldırı vb. için kullanılacak
# func _process(delta: float) -> void:
#	pass

func _physics_process(delta: float) -> void:
    # <<< YENİ: Hasar Efektini Güncelle >>>
    if damage_flash_timer > 0:
        damage_flash_timer -= delta
        if damage_flash_timer <= 0:
            sprite.modulate = Color.WHITE # Rengi normale döndür


    var move_direction = Vector2.ZERO
    var target_velocity = Vector2.ZERO

    # Okçu Tehlike Kontrolü
    if stats != null and stats.unit_type_id == "archer":
        threat_check_timer += delta
        if threat_check_timer >= THREAT_CHECK_INTERVAL:
            var found_threat = _find_nearby_melee_threat()
            if found_threat != current_threat:
                # print("DEBUG (%s): Threat check result: %s (Previous: %s)" % [name, found_threat, current_threat]) # Biraz kalabalık yapıyor, şimdilik kapalı
                current_threat = found_threat
            elif found_threat == null and current_threat != null:
                 # print("DEBUG (%s): Previous threat %s no longer found by timer check." % [name, current_threat]) # Biraz kalabalık yapıyor, şimdilik kapalı
                 current_threat = null
            threat_check_timer = 0.0

    # Tehdide Tepki
    if stats != null and stats.unit_type_id == "archer" and current_state != State.FLEEING:
        if current_threat != null and is_instance_valid(current_threat):
            # Geçerli tehdit var, FLEEING durumuna geç
            # print("DEBUG (%s): Reacting to valid threat %s. Switching to FLEEING." % [name, current_threat.name]) # Biraz kalabalık yapıyor, şimdilik kapalı
            current_state = State.FLEEING
            target_enemy = null # Kaçarken hedefi bırak
            # Kaçış yönü FLEEING state içinde belirlenecek
            # Bu frame'de state değiştiği için match bloğunun FLEEING kısmına girecek
            # return # Gerek yok, state değişti, match bloğu halleder

    # --- Durum Makinesi ---
    match current_state:
        State.MOVING:
            if target_enemy != null and is_instance_valid(target_enemy):
                var distance_to_target = global_position.distance_to(target_enemy.global_position)
                var is_ranged = stats.attack_range > 50.0 # Menzilli birim kontrolü (geçici eşik)

                if is_ranged:
                    # Menzilli Birim Mantığı
                    if distance_to_target <= stats.attack_range:
                        # Menzil içinde, dur ve saldırıya geç
                        move_direction = Vector2.ZERO
                        current_state = State.ATTACKING
                        attack_timer = 0.0 # Hemen saldırıya hazır ol
                    else:
                        # Menzil dışı, yaklaş
                        move_direction = (target_enemy.global_position - global_position).normalized()
                else:
                    # Yakın Dövüşçü Birim Mantığı
                    if distance_to_target <= stats.attack_range:
                        # Menzil içinde (yakınında), dur ve saldırıya geç
                        move_direction = Vector2.ZERO
                        current_state = State.ATTACKING
                        attack_timer = 0.0
                    else:
                        # Menzil dışı, yaklaş
                        move_direction = (target_enemy.global_position - global_position).normalized()
            else:
                # Belirli bir hedef yok, en yakını ara
                var closest_enemy = _find_closest_enemy_on_map()
                if closest_enemy != null and is_instance_valid(closest_enemy):
                    var distance_to_closest = global_position.distance_to(closest_enemy.global_position)
                    var is_ranged = stats.attack_range > 50.0 # Menzilli birim kontrolü

                    if is_ranged:
                        # Menzilli Birim Mantığı (Hedef Yok)
                        if distance_to_closest <= stats.attack_range:
                            # En yakın düşman menzilde, onu hedef al ve saldırıya geç
                            target_enemy = closest_enemy
                            move_direction = Vector2.ZERO
                            current_state = State.ATTACKING
                            attack_timer = 0.0
                        else:
                            # En yakın düşmana yaklaş
                            move_direction = (closest_enemy.global_position - global_position).normalized()
                    else:
                        # Yakın Dövüşçü Birim Mantığı (Hedef Yok)
                        # Her zaman en yakına doğru hareket et
                        move_direction = (closest_enemy.global_position - global_position).normalized()
                else:
                    # Düşman yok, IDLE'a geç
                    current_state = State.IDLE
                    move_direction = Vector2.ZERO

            # Sprite yönünü ayarla
            if move_direction.x > 0.1: sprite.flip_h = false
            elif move_direction.x < -0.1: sprite.flip_h = true

        State.ATTACKING:
            if target_enemy != null and is_instance_valid(target_enemy):
                var distance_to_target = global_position.distance_to(target_enemy.global_position)
                var exit_range = stats.attack_range + 5.0
                
                if distance_to_target <= exit_range:
                    # Hala menzilde, saldırmaya devam et
                    # Sprite yönünü ayarla
                    if target_enemy.global_position.x > global_position.x: sprite.flip_h = false
                    else: sprite.flip_h = true

                    # Saldırı zamanlayıcısını işle
                    attack_timer -= delta
                    if attack_timer <= 0:
                        # Saldırı zamanı!
                        move_direction = Vector2.ZERO # Saldırı anında dur
                        jitter_target_offset = Vector2.ZERO # Jitter'ı sıfırla
                        _attack(target_enemy)
                        attack_timer = stats.attack_speed
                    else:
                        # <<< GÜNCELLENDİ: Yakın Dövüşçü Jitter Mantığı >>>
                        var is_melee = stats.attack_range <= 50.0 # Yakın dövüşçü mü?
                        if is_melee:
                            jitter_timer += delta
                            if jitter_timer >= JITTER_INTERVAL:
                                jitter_timer = 0.0
                                # Mevcut pozisyona göre DAHA BÜYÜK rastgele bir ofset belirle (X ağırlıklı)
                                jitter_target_offset = Vector2(randf_range(-30.0, 30.0), randf_range(-5.0, 5.0))

                            # Eğer bir jitter hedefi varsa ona doğru git
                            if jitter_target_offset != Vector2.ZERO:
                                var jitter_target_pos = global_position + jitter_target_offset
                                move_direction = (jitter_target_pos - global_position).normalized()
                            else:
                                move_direction = Vector2.ZERO
                        else:
                            # Menzilli birim saldırırken sabit durur
                            move_direction = Vector2.ZERO
                        # <<< JITTER SONU >>>
                else:
                    # Menzilden çıktı, MOVING'e geç
                    current_state = State.MOVING
                    jitter_target_offset = Vector2.ZERO # Jitter'ı sıfırla
            else:
                # Hedef geçersiz, MOVING'e geç
                target_enemy = null
                current_state = State.MOVING
                jitter_target_offset = Vector2.ZERO # Jitter'ı sıfırla
        
        State.FLEEING: # <-- GÜNCELLENMİŞ DURUM
             # Tehdit hala geçerli mi? (is_instance_valid kontrolü önemli)
             if current_threat != null and is_instance_valid(current_threat):
                 # Tehditten uzağa kaçış yönünü belirle
                 move_direction = (global_position - current_threat.global_position).normalized()

                 # <<< YENİ: Sınır Kontrolü >>>
                 if battle_area_limit.size != Vector2.ZERO: # Eğer sınırlar atanmışsa
                     var next_pos = global_position + move_direction * stats.move_speed * delta * 1.1 # Biraz ileri bak

                     # X ekseninde sınıra çarpıyor mu?
                     if (move_direction.x < 0 and next_pos.x < battle_area_limit.position.x) or \
                        (move_direction.x > 0 and next_pos.x > battle_area_limit.end.x):
                         move_direction.x = 0 # X yönünde hareketi durdur

                     # Y ekseninde sınıra çarpıyor mu?
                     if (move_direction.y < 0 and next_pos.y < battle_area_limit.position.y) or \
                        (move_direction.y > 0 and next_pos.y > battle_area_limit.end.y):
                         move_direction.y = 0 # Y yönünde hareketi durdur

                     # Eğer her iki yönde de hareket durduysa (köşeye sıkıştıysa), MOVING'e geç
                     if move_direction == Vector2.ZERO:
                         # print("DEBUG (%s): Cornered while fleeing! Switching to MOVING." % name)
                         current_state = State.MOVING
                         current_threat = null # Tehdit artık öncelikli değil
             else:
                 # Tehdit yok, MOVING'e geç
                 current_threat = null
                 current_state = State.MOVING
             # Kaçarken jitter yapmasın
             jitter_target_offset = Vector2.ZERO

        State.IDLE:
            # <<< YENİ: IDLE durumunda da en yakın düşmanı ara ve MOVING'e geç >>>
            var closest_enemy = _find_closest_enemy_on_map()
            if closest_enemy != null and is_instance_valid(closest_enemy):
                # print("DEBUG (%s): Found enemy %s while IDLE. Switching to MOVING." % [name, closest_enemy.name]) # Kalabalık yapabilir
                current_state = State.MOVING
            # else: Yapacak bir şey yoksa IDLE kalmaya devam et.
            # IDLE iken jitter yapmasın
            jitter_target_offset = Vector2.ZERO

        _: # Beklenmedik durum
            current_state = State.IDLE
            move_direction = Vector2.ZERO
            jitter_target_offset = Vector2.ZERO

    # <<< YENİ: Ayrılma (Separation) Mantığı >>>
    var separation_vector = _calculate_separation_vector()
    var final_direction = move_direction # Varsayılan yön

    # Eğer ayrılma kuvveti varsa, asıl yönle birleştir
    if separation_vector != Vector2.ZERO:
         final_direction = (move_direction * (1.0 - SEPARATION_WEIGHT) + separation_vector * SEPARATION_WEIGHT).normalized()
    # <<< Ayrılma Mantığı Sonu >>>

    # Hızı hesapla ve move_and_slide çağır
    if stats != null:
        # <<< GÜNCELLENDİ: final_direction kullan >>>
        if final_direction != Vector2.ZERO:
            target_velocity = final_direction * stats.move_speed
        else:
            target_velocity = Vector2.ZERO # Eğer son yön sıfırsa dur
    else:
        target_velocity = Vector2.ZERO

    # Hızı CharacterBody2D'nin velocity özelliğine ata
    velocity = target_velocity 
    move_and_slide()

    # Sprite yönünü ayarla (move_and_slide sonrası gerçek hıza göre)
    if velocity.x > 0.1: sprite.flip_h = false
    elif velocity.x < -0.1: sprite.flip_h = true

    # Pozisyon Debug
    position_debug_timer += delta
    if position_debug_timer >= POSITION_DEBUG_INTERVAL:
        var target_name = "None"
        if target_enemy != null and is_instance_valid(target_enemy): # Yine de garanti olsun
            target_name = target_enemy.name
        print("POS DEBUG: %s at %s (State: %s, Target: %s, HP: %d)" % [
            name, 
            global_position.round(), 
            State.keys()[current_state], 
            target_name,
            current_hp 
        ])
        position_debug_timer = 0.0

# Haritadaki en yakın düşmanı bulur (Atlılar için okçu, Okçular için Kalkanlı önceliği ile)
func _find_closest_enemy_on_map() -> Unit:
    if battle_scene_ref == null or not is_instance_valid(battle_scene_ref):
        return null
    var enemies: Array[Unit] = []
    if team_id == 0: enemies = battle_scene_ref.enemy_units
    elif team_id == 1: enemies = battle_scene_ref.player_units
    else: return null

    var my_stats = self.stats # Kendi istatistiklerimize erişim
    if my_stats == null: return null # Güvenlik kontrolü

    var is_cavalry = my_stats.unit_type_id == "cavalry"
    var is_archer = my_stats.unit_type_id == "archer"

    # <<< YENİ: Okçu için Kalkanlı Önceliği >>>
    if is_archer:
        var closest_shieldbearer: Unit = null
        var min_shieldbearer_dist_sq: float = INF
        # Önce SADECE Kalkanlıları ara
        for enemy in enemies:
            if not is_instance_valid(enemy) or enemy.stats == null or enemy.stats.unit_type_id != "shieldbearer":
                continue # Bu bir kalkanlı değil, atla
            var distance_sq = global_position.distance_squared_to(enemy.global_position)
            if distance_sq < min_shieldbearer_dist_sq:
                min_shieldbearer_dist_sq = distance_sq
                closest_shieldbearer = enemy
        
        # Eğer Kalkanlı bulunduysa onu döndür
        if closest_shieldbearer != null:
            # print("DEBUG (%s - Archer): Prioritizing shieldbearer %s" % [name, closest_shieldbearer.name]) # Log gerekirse açılabilir
            return closest_shieldbearer
        # else: Kalkanlı bulunamadıysa, aşağıdaki genel/atlı arama devam edecek.
        # print("DEBUG (%s - Archer): No shieldbearers found, searching normally." % name)
    
    # <<< Atlılar için Okçu Önceliği (Bu kısım aynı kaldı) >>>
    if is_cavalry:
        var closest_archer: Unit = null
        var min_archer_distance_sq: float = INF
        # Önce SADECE okçuları ara
        for enemy in enemies:
            if not is_instance_valid(enemy) or enemy.stats == null or enemy.stats.unit_type_id != "archer":
                continue # Bu bir okçu değil, atla
            var distance_sq = global_position.distance_squared_to(enemy.global_position)
            if distance_sq < min_archer_distance_sq:
                min_archer_distance_sq = distance_sq
                closest_archer = enemy
        
        if closest_archer != null:
            # print("DEBUG (%s - Cavalry): Prioritizing archer %s" % [name, closest_archer.name])
            return closest_archer
        # print("DEBUG (%s - Cavalry): No archers found, searching for closest general enemy." % name)
    
    # <<< Genel en yakın düşman arama >>>
    var closest_enemy: Unit = null
    var min_distance_sq: float = INF
    for enemy in enemies:
        if not is_instance_valid(enemy) or enemy.stats == null:
            continue # Geçersiz düşmanı atla
        
        var distance_sq = global_position.distance_squared_to(enemy.global_position)
        if distance_sq < min_distance_sq:
            min_distance_sq = distance_sq
            closest_enemy = enemy

    if closest_enemy != null:
        var reason = "(Not Cavalry)" if not is_cavalry else "(No Archer Found)"
        # print("DEBUG (%s %s): Closest general enemy is %s" % [name, reason, closest_enemy.name]) # <<< Log Kapatıldı
    return closest_enemy

func _attack(target: Unit) -> void:
    if stats == null or target == null or not is_instance_valid(target):
        return

    # <<< YENİ: Iskalama Kontrolü >>>
    if stats.hit_chance < 1.0: # Eğer %100 vurmuyorsa kontrol et
        if randf() > stats.hit_chance:
            print("%s ISKALADI! -> %s" % [name, target.name])
            attack_timer = stats.attack_speed # Iskalasa bile bekleme süresi sıfırlansın
            return # Hedefe hasar verme

    var damage = stats.attack_damage
    target.take_damage(damage)

# Yakındaki yakın dövüş tehdidini bulur (Okçular için)
func _find_nearby_melee_threat() -> Unit:
    if stats == null or stats.unit_type_id != "archer": return null 
    if battle_scene_ref == null or not is_instance_valid(battle_scene_ref): return null # BattleScene ref lazım

    # <<< DEBUG: Bu fonksiyon artık sadece timer ile çağrılmalı >>>
    # print("DEBUG (%s): _find_nearby_melee_threat CALLED (by timer)" % name) # İstersen bu logu açabilirsin

    var enemies: Array[Unit]
    if team_id == 0: enemies = battle_scene_ref.enemy_units
    elif team_id == 1: enemies = battle_scene_ref.player_units
    else: return null

    var closest_threat: Unit = null
    var min_distance_sq = ARCHER_FLEE_DISTANCE * ARCHER_FLEE_DISTANCE # Kareli mesafe ile karşılaştır

    for enemy in enemies:
        if not is_instance_valid(enemy): continue
        if enemy.stats == null or enemy.stats.unit_type_id != "swordsman": continue # Sadece yakın dövüşçüler

        var distance_sq = global_position.distance_squared_to(enemy.global_position)
        if distance_sq < min_distance_sq:
            # print("DEBUG (%s): Potential melee threat %s at distance %s (sq)" % [name, enemy.name, distance_sq]) # Kalabalık yapabilir
            # En yakını değil, _herhangi_ biri yeterli olabilir, ama şimdilik en yakını bulalım
            # Şimdilik ilk bulduğunu döndürelim
            # print("DEBUG (%s):    - >>> MELEE THREAT FOUND: %s <<<" % [name, enemy.name])
            return enemy # Tehdit bulundu!

    return null # Tehdit yok

# <<< YENİ: Yardımcı Fonksiyon >>>
# Algılama alanındaki en yakın okçuyu bulur
func _find_closest_archer_in_detection_area() -> Unit:
    var closest_archer: Unit = null
    var min_distance_sq: float = INF
    
    if not is_instance_valid(detection_area): return null # Safety check

    var overlapping_areas = detection_area.get_overlapping_areas()
    for area in overlapping_areas:
        var owner = area.get_owner()
        # Check if owner is a Unit, not self, different team, and valid
        if owner is Unit and owner != self and owner.team_id != self.team_id and is_instance_valid(owner) and owner.stats != null:
            # Check if it's an archer
            if owner.stats.unit_type_id == "archer":
                var distance_sq = global_position.distance_squared_to(owner.global_position)
                if distance_sq < min_distance_sq:
                    min_distance_sq = distance_sq
                    closest_archer = owner
                    
    return closest_archer
# <<< YENİ SONU >>>

# --- Sinyal Callbackleri ---
func _on_detection_area_area_entered(area: Area2D) -> void:
    if current_state == State.FLEEING: return
    var owner = area.get_owner()
    if owner is Unit and owner != self and owner.team_id != self.team_id:
        var potential_target = owner as Unit
        if not is_instance_valid(potential_target) or potential_target.stats == null:
            return

        var my_stats = self.stats
        if my_stats == null: return

        var is_cavalry = my_stats.unit_type_id == "cavalry"
        var is_archer = my_stats.unit_type_id == "archer"
        
        var potential_is_archer = potential_target.stats.unit_type_id == "archer"
        var potential_is_shieldbearer = potential_target.stats.unit_type_id == "shieldbearer" # <<< YENİ

        var has_valid_target = target_enemy != null and is_instance_valid(target_enemy) and target_enemy.stats != null
        var current_target_is_archer = false
        var current_target_is_shieldbearer = false # <<< YENİ
        var current_target_name = "None"
        if has_valid_target:
            current_target_is_archer = target_enemy.stats.unit_type_id == "archer"
            current_target_is_shieldbearer = target_enemy.stats.unit_type_id == "shieldbearer" # <<< YENİ
            current_target_name = target_enemy.name

        # Değişken tanımlarını temizle ve tip belirt
        var should_target: bool = false
        var reason: String = ""
        
        # <<< GÜNCELLENDİ: Okçu hedefleme mantığı eklendi >>>
        if is_archer:
            if potential_is_shieldbearer:
                if not has_valid_target or not current_target_is_shieldbearer:
                    should_target = true
                    reason = "New shieldbearer, current target is not shieldbearer (or none)"
                elif global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
                    should_target = true
                    reason = "New shieldbearer closer than current shieldbearer target"
            else: # Giren Kalkanlı değilse
                if not has_valid_target or (not current_target_is_shieldbearer and global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position)):
                    should_target = true
                    reason = "New non-shieldbearer, no current shieldbearer target (or closer)"
                # Mevcut hedef Kalkanlı ise, Kalkanlı olmayan birine geçme.
                
        elif is_cavalry:
            # <<< GÜNCELLENDİ: Orijinal Atlı Okçu hedefleme mantığı geri eklendi >>>
            if potential_is_archer:
                # Giren okçuysa ve mevcut hedef okçu DEĞİLSE, her zaman hedefle.
                if not has_valid_target or not current_target_is_archer:
                    should_target = true
                    reason = "New archer, current target is not archer (or none)"
                # Mevcut hedef zaten okçuysa, sadece yenisi daha yakınsa değiştir.
                elif global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
                    should_target = true
                    reason = "New archer closer than current archer target"
            else: # Giren okçu değilse
                # Sadece mevcut hedef YOKSA hedefle.
                if not has_valid_target:
                    should_target = true
                    reason = "New non-archer, no current target"
                # Mevcut hedef varsa (ve bu mantığa göre okçu olmalı), okçu olmayanı hedefleme.
                elif not current_target_is_archer and global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
                     # Mevcut hedef de okçu değilse VE yeni giren daha yakınsa, hedefle.
                    should_target = true
                    reason = "New non-archer closer than current non-archer target"
        else:
            # Diğer Birimler (Kılıçlı, Mızraklı vb.) - Eski Mantık:
            if not has_valid_target or global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
                should_target = true

        if should_target:
            target_enemy = potential_target
            # print("DEBUG (%s): SWITCHING TARGET to %s. Reason: %s" % [name, potential_target.name, reason]) # Gerekirse logu aç
            if current_state == State.IDLE:
                current_state = State.MOVING
        else:
            pass # Bu dıştaki else: pass kalabilir

func _on_detection_area_area_exited(area: Area2D) -> void:
    # print(">>> SIGNAL area_exited FIRED for %s <<<" % name)
    var owner = area.get_owner()
    if owner is Unit and owner == target_enemy:
        # print("DEBUG (%s): Current target %s exited detection area." % [name, target_enemy.name]) # Kalabalık yapabilir
        # Hedef algılama alanından çıktı.
        # ATTACKING state zaten menzili kontrol ediyor, MOVING state en yakını bulacak.
        # Belki hedefi hemen null yapabiliriz?
        # target_enemy = null # Şimdilik kalsın, MOVING halleder
        pass

# <<< YENİ Fonksiyon: Ayrılma Vektörü Hesaplama >>>
func _calculate_separation_vector() -> Vector2:
    var separation_force = Vector2.ZERO
    var neighbor_count = 0

    if not is_instance_valid(friendly_detection_area): return Vector2.ZERO

    # Dost algılama alanındaki diğer alanları (yani diğer dost birimlerin dost alanlarını) al
    var overlapping_areas = friendly_detection_area.get_overlapping_areas()
    for area in overlapping_areas:
        var neighbor = area.get_owner()
        # Katman/Maske ayarı sayesinde bunların dost olması garanti ama yine de kontrol edelim
        if neighbor is Unit and neighbor != self and neighbor.team_id == self.team_id and is_instance_valid(neighbor):
            var to_neighbor = neighbor.global_position - global_position
            var dist_sq = to_neighbor.length_squared()

            # Çok yakınsa güçlü it, sıfır mesafeden kaçın
            if dist_sq > 0.01: 
                 # Uzaklığın karesiyle ters orantılı itme kuvveti
                 separation_force -= to_neighbor.normalized() / dist_sq
                 neighbor_count += 1

    if neighbor_count > 0:
        # Ortalama kuvvete gerek yok, yön yeterli
        return separation_force.normalized()
    else:
        return Vector2.ZERO
# <<< YENİ Fonksiyon Sonu >>>
