# Yörünge — İlerleme

| Milestone | Tag | Durum | Tarih |
|---|---|---|---|
| (0) Kurulum | `m0` | ✅ tamam | 2026-10-10 |
| (a) Yerçekimi + karakter + kamera | `ma` | ⏳ sürüyor | |
| (b) Çoklu gezegen + geçişler | `mb` | ⬜ | |
| (c) Toz, portal, seviye akışı, düşman, hasar | `mc` | ⬜ | |
| (d) Shader ve görsel cila | `md` | ⬜ | |
| (e) Ses + juice | `me` | ⬜ | |
| (f) Menüler + kayıt | `mf` | ⬜ | |
| (g) Prosedürel mod | `mg` | ⬜ | |
| (h) Uçtan uca DemoBot testi | `mh` | ⬜ | |

## (0) Kurulum — 2026-10-10
- Git deposu açıldı, tek dal `main`.
- `.gitignore` token taşıyan dosyaları dışlıyor: `.beckett/`, `.mcp.json`, `.cursor/`, `.vscode/`, `.claude/settings.local.json`.
- Proje ayarları:
  - `config/name="Yörünge"`
  - `physics/common/physics_interpolation=true`
  - pencere 1280×720
  - `yorunge/demo_mode=false`
  - autoload `GameState`
- Kod: `core/game_log.gd`, `core/demo_mode.gd`, `core/input_bindings.gd`, `autoload/game_state.gd`. Dördü de `validate_script` → OK.
- Input action'ları kodla kaydediliyor:
  - `move_*`: WASD + oklar + sol çubuk
  - `jump`: Space / A
  - `pause`: Esc / P / Start
  - `look_*`: sağ çubuk; mouse kamera tarafında okunuyor

## Ölçümler
_(her milestone'da eklenecek)_

## Açık sorunlar / notlar
- Beckett'in `update_file` çağrısı editörün henüz bilmediği bir dizindeki dosyayı kaydetmiyor. Tam tarama için Godot penceresinin odak alması gerekiyor (`osascript -e 'tell application "Godot" to activate'`). Bu yüzden plandaki tüm dizinler baştan oluşturuldu.
