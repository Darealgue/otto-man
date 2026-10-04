# Kamp: kurtarılanlar ve erken çıkış çarkı

## Kampta görünen kurtarılanlar
- `scenes/camp_rescued_crowd.gd` (`CampRescuedCrowd`): `DungeonRunState.pending_rescued_villagers/cariyes` listesini okur (değiştirmez) ve her kayıt için çeşmenin çevresine bir `CampRescuedNpc` koyar. En çok 14 kişi. `CampScene.setup_mid_run()` sonunda `_spawn_rescued_crowd()` çağırır.
- `scenes/camp_rescued_npc.gd` (`CampRescuedNpc`): gerçek Worker / Concubine sahnesini "zindan tutsağı" kipinde kullanır (`is_dungeon_prisoner = true`; köy kaydı, görev, AI yok), fiziği kapatıp davranışı kendi sürer. Köylüler yürür, durur, oturur, uzanır; cariyelerin yalnız yürüme ve durma animasyonu var. Etkileşim yok, isim levhası gizli.
- Görünüm kayıttaki `appearance` sözlüğünden (`VillagerAppearance.from_dict`) gelir; boşsa rastgele üretilir.

## Erken çıkış çarkı
- **Kural:** run tamamlanmadan (`!DungeonRunState.is_run_complete()`) kamptaki çıkış kapısından çıkılırsa kurtarılan her kişi `DungeonRunState.EARLY_EXIT_SURVIVE_CHANCE` (şu an 0.6) şansla seninle çıkar. Run tamamlanmışsa herkes gelir. (Ölümde hepsi kaybolur, dünya haritası olayları ayrıdır.)
- `DungeonRunState.roll_early_exit_rescued()` sonuçları ÖNCEDEN çeker, bekleyen listeleri yalnız hayatta kalanlara indirir ve `[{kind, data, survived}]` döndürür.
- `ui/RescueWheelOverlay.gd`: `await RescueWheelOverlay.show_for(host, results, chance)`. Her kişi için vesikalıklı (küçük SubViewport'ta gerçek sprite) sırayla bir çark döner; yeşil dilim "seninle çıkar", kırmızı "geride kalır", dilim genişliği şansa eşit. Çark yalnız önceden çekilen sonuca iner. Herhangi bir tuş hızlandırır.
- Metinler `camp.wheel.*` anahtarlarında (TR + EN).