class_name UiText
extends RefCounted
## Every player-facing interface string (Turkish), in one place for review and
## a future translation table. Tutorial hint lines live with their levels.

# HUD
const STARDUST_COUNT := "%d / %d"
const PORTAL_OPEN := "Portal açıldı!"
const LEVEL_COMPLETE := "Seviye tamamlandı!"
const LEVEL_FAILED := "Kalpler bitti — yeniden deneniyor…"
const HEART_LOST := "Ah!"
const ENEMY_DEFEATED := "Ezildi!"

# Main menu
const GAME_TITLE := "YÖRÜNGE"
const GAME_SUBTITLE := "Küçük gezegenlerde bir kaşif"
const START := "Başla"
const CONTINUE := "Devam et"
const LEVELS := "Seviyeler"
const ENDLESS := "Sonsuz Mod"
const SETTINGS := "Ayarlar"
const QUIT := "Çıkış"

# Endless setup
const ENDLESS_TITLE := "Sonsuz Mod"
const SEED_LABEL := "Seed (sayı ya da kelime)"
const SEED_PLACEHOLDER := "örn. 2026"
const RANDOM_SEED := "Rastgele seed"
const BEST_DEPTH := "En derin seviye: %d"
const ENDLESS_LEVEL_TITLE := "Sonsuz · Seviye %d  ·  #%d"

# Level select
const LEVEL_SELECT_TITLE := "Seviyeler"
const LEVEL_LOCKED := "%s  (kilitli)"
const LEVEL_BEST := "%s  —  en iyi %s"
const BACK := "Geri"

# Settings
const SETTINGS_TITLE := "Ayarlar"
const MASTER_VOLUME := "Ana ses"
const MUSIC_VOLUME := "Müzik"
const SFX_VOLUME := "Efektler"
const SENSITIVITY := "Fare / kamera hassasiyeti"
const INVERT_Y := "Dikey ekseni ters çevir"
const FULLSCREEN := "Tam ekran"
const FULLSCREEN_UNAVAILABLE := "Tam ekran (editörde kullanılamaz)"

# Pause
const PAUSED := "Duraklatıldı"
const RESUME := "Devam"
const RESTART := "Yeniden başlat"
const MAIN_MENU := "Ana menü"

# Level complete
const COMPLETE_TITLE := "Seviye tamamlandı!"
const TIME_LINE := "Süre: %s"
const NEW_RECORD := "Yeni rekor!"
const BEST_LINE := "En iyi: %s"
const DEPTH_LINE := "Derinlik %d · En derin %d"
const DAMAGE_LINE := "Kaybedilen kalp: %d"
const STOMPS_LINE := "Ezilen düşman: %d"
const STARDUST_LINE := "Yıldız tozu: %d / %d"
const NEXT_LEVEL := "Sonraki seviye"
const FINISH := "Bitir"
const PLAY_AGAIN := "Tekrar oyna"
const SECONDS := "%s sn"


## Seconds with one decimal and a Turkish decimal comma: 20.25 -> "20,3 sn".
static func seconds(value: float) -> String:
	return SECONDS % ("%.1f" % value).replace(".", ",")
