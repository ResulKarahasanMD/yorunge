# Yörünge — İlerleme

| Milestone | Tag | Durum | Tarih |
|---|---|---|---|
| (0) Kurulum | `m0` | ✅ tamam | 2026-10-10 |
| (a) Yerçekimi + karakter + kamera | `ma` | 🟡 rev 2 doğrulandı, kullanıcının son onayı bekleniyor | 2026-10-10 |
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

## (a) Yerçekimi + karakter + kamera — 2026-10-10

### Kod
- `gravity/`:
  - `GravitySource`: yüzey + 1,5 m'ye kadar tam çekim, sonra `influence_radius`'a kadar smoothstep ile söner.
  - `GravityResolver`: ağırlıklı toplam + baskın kaynak.
  - `GravitySample`.
- `world/`:
  - `Planet` (@tool AnimatableBody3D): yarıçaptan çarpışma, mesh ve yerçekimi kuyusunu kendisi kurar; çocuklar kaydedilmez.
  - `PlanetStyle` (Resource) + `styles/grass.tres`.
- `player/`:
  - `PlayerController` (CharacterBody3D, orijin ayakta). Her karede up güncellenir, zemindeyken hız paralel taşınır. Coyote time, jump buffer ve değişken zıplama var.
  - `PlayerInput` (strateji) ve `HumanInput`.
  - `player.tscn`: primitive'lerden kaşif (gövde, kask, vizör, sırt çantası, anten).
- `camera/OrbitCameraRig`: top_level, paralel taşınan çerçeve + SpringArm3D. Mouse/sağ çubuk girdisi ve hareket yönüne otomatik hizalama var.
- `ai/DemoBot` (a sürümü): büyük çember üzerinde yürür, 3 sn'de bir zıplar.
- `levels/Level` (girdi stratejisini kurar), `levels/dev/sandbox_a.tscn` (ana sahne, elle oynamak için).
- `debug/demo_entry.tscn`: demo modunu zorlar.
- `tests/`: `TestSuite`, `run_tests.gd`, `test_gravity.gd`.

### Doğrulama
- **Beckett, `demo_entry`:**
  - `game_logs` hata/uyarı **0**.
  - Log akışı: `[Level] ready: Sandbox A (input=DemoBot, planets=1)` ve `[Gravity] dominant=Grassy`.
- **`monitor_properties` Player.global_position** (20 örnek / 10 sn):
  - Zemindeki örneklerde merkeze uzaklık **10,00 m** (yarıçap 10). Zıplama örnekleri 12,7–12,8 m.
  - y ekseninde **+12,7 ile −9,97** arası, yani tam büyük çember turu; oyuncu arka yüze geçiyor.
- **`[DemoBot]` logu:** t=1,0 sn'de alt=0,001 m, hız 6,99 m/s (hedef 7,0).
- **Kamera rig'i `global_basis`** (4 örnek):
  - Y ekseni (0; −0,42; 0,91) → (0; 0,83; 0,56) arasında oyuncunun yukarısını yumuşakça izliyor.
  - X ekseni her örnekte (1, 0, 0): yaw sıçraması ve yuvarlanma yok.
- **Ekran görüntüsü:** gezegenin altında (y≈−10) bile oyuncu ekranda "üstte", kamera arkasında.
- **Headless birim testleri:** `Godot --headless --path . --script res://tests/run_tests.gd` → **17 kontrol, 0 hata**, exit 0.
- **Headless demo:** `Godot --headless --path . --quit-after 400 -- --demo` → `demo_mode=true`. t=1,0 konumu (0,00; 8,08; −5,89), editör koşusuyla birebir aynı (deterministik).

### (a) revizyon 1 — kullanıcı geri bildirimi (2026-10-10)
| # | Sorun | Düzeltme | Kanıt |
|---|---|---|---|
| 1 | SpringArm çarpınca 8 m → 1–2 m tek karede sıçrama | SpringArm3D kaldırıldı. Rig kendi küre shape-cast'ini yapıyor (r=0,3). Boom uzunluğu üstel yaklaşım + hız tavanıyla değişiyor: içeri 25/s & ≤30 m/s, dışarı 8/s & ≤18 m/s. dt 1/30 sn'de kırpılıyor. | Headless: 8→1,5 ilk kare 0,500 m, %95'e 0,233 sn. 1,5→8 kare başı ≤0,300 m, %95'e 0,483 sn. 0,25 sn takılmada adım ≤1,0 m. Oyunda `camera_test.tscn`, 9 kapanma olayı: tek karedeki en büyük adım 0,278 m (9,3 ms kare) / 0,500 m (16,7 ms kare); adım/dt hızı her zaman ≤30,0 m/s. |
| 1b | Pitch alt sınırı kamerayı zemine sokuyor | Pitch aralığı −65°…**−5°** (kamera hiçbir zaman pivotun altına inmiyor) | Test: R=3…25 için en alçak kamerada bile zemine boşluk ≥ 0,5 m. |
| 2 | Alçak açıda ufuk kadrajdan çıkıyor | Varsayılan pitch **−22°**; aralık geometrik olarak doğrulandı | `horizon_offset_deg`: pitch −65…−5 ve R ∈ {3,4,6,8,10,14,20,25} için ufuk görüş ekseninden **−8,5° … +28,6°** (kadraj ±35°, ≥5° pay). Varsayılan pitch'te R=10 için ufuk merkeze 10°'den yakın. |
| 3 | Gece yüzü neredeyse siyah | Ortam ışığı 0,55 → 1,0 (renk biraz açıldı). Güneşin tersinden gölgesiz soğuk dolgu ışığı (0,35). | Sabit gece pozu (`night_test` / `night_test_old_lighting`, n·L = −0,87), sRGB parlaklık: gezegen **40,1 → 73,4**, dama kontrastı 21,9 → 36,7, karakter 70,5 → 97,5. |
| 4 | Hız hissi yok | Geçici `shaders/debug_checker.gdshader`: nesne uzayında fwidth ile filtrelenmiş 3D dama, 1,5 m hücre. (d)'de değişecek. | Ekran görüntüsü: hücreler küre üstünde düzgün, kutup sıkışması yok. |

Test toplamı: `run_tests.gd` → **521 kontrol, 0 hata**. `test_camera.gd` yeni: ufuk, zemin boşluğu, zoom hızı, takılma sınırı.
Headless demo (`--fixed-fps 60 --quit-after 400 -- --demo`): 6,7 sn simülasyon, hata 0; yürüme, zıplama ve tam tur normal.
Yeni dev sahneleri: `levels/dev/camera_test.tscn` (+ `debug/demo_camera_test.tscn`), `levels/dev/night_test*.tscn`, `world/floating_rock.tscn`.

### (a) revizyon 2 — kullanıcı geri bildirimi (2026-10-10)
| # | İstek | Yapılan | Kanıt |
|---|---|---|---|
| 1 | Engel varsa aynı karede içeri gir; çıkış yumuşak kalsın; engellenen kare = 0 | Yerleştirme yeniden yazıldı. Kamera, oyuncunun **başından** ideal kamera noktasına giden hatta duruyor. Baş noktası göğüsten süpürülerek güvenli kılınıyor (göğüs kapsül içinde, her zaman boş). Hat boyunca küre süpürmesi yapılıyor; göğüs ışını kesilirse mesafe ikili aramayla kısaltılıyor. İçeri **anında**, dışarı ≤18 m/s. Boom uzunluğu gezegen yarıçapına göre hesaplanan tavanla sınırlı. | `camera_test`, headless 120 sn (7199 kare): boom 1429 karede engellendi (49 olay). Kameradan başa ışın engelli **0**, göğse **0**. Tek karedeki en büyük dışa adım 0,300 m; herhangi bir nedenle tek karede en büyük mesafe artışı 0,300 m. |
| 1b | (yan bulgu) | **`PlayerController` yönelim hatası:** kafa çarpması sonrası hız ters dönünce `slerp(facing, travel)` zıt vektörlerde tanımsız eksen seçiyordu. Gövde `basis.y`'si `current_up`'tan 35–40° sapıp kare kare titriyordu. Hem kamerayı hem gövde çizimini etkiliyordu. `turn_facing()` artık up ekseni etrafında işaretli açıyla dönüyor. | `test_player.gd`: 52 kontrol; zıt yönde bile birim uzunluk, teğet ve body.Y = up. Kamera testindeki 0,6–1,5 m'lik tek kare sıçramalar bununla kayboldu. |
| 2 | Yukarı bakış (≈25°) + ufuk/yüzey kanıtı | Pitch **−65°…+25°**. Boom, gezegen yarıçapına göre hesaplanan tavana kadar iniyor; tavan boom **boyunca** ≥0,5 m boşluk bırakacak şekilde ikili aramayla bulunuyor. Pitch'in tavanı aşan kısmı kameranın kendi ekseninde yukarı eğilmesi olarak uygulanıyor. Neden: R ≥ 14 m'de saf boom ile 25° yukarı bakmak kamerayı zeminin içine sokuyor (hesap: −90°, yani gezegen içi). | Tavanlar: R3 +35,5°, R10 +21,7°, R25 +14,2°. Tüm pitch × R ∈ {3…25} için ufuk **−19,2° … +28,6°** (kadraj ±35°, ≥5° pay). En büyük eğim 10,8° (oyuncu merkezin en fazla 10,8° altında). Boom boşluğu her yerde ≥ 0,5 m. 1471 kontrol. |
| 3 | Gündüz önce/sonra | CLI `FrameCapture` ile aynı sabit pozlarda 4 kare (1280×720) | Gündüz gezegen 139,2 → 146,3 (+%5); dama kontrastı 56,9 → 60,3; göreli kontrast **0,210 → 0,212** (değişmedi); patlamış piksel %0,06 → %0,09; karakter 131 → 148. Gece 40,1 → 73,3. **Soluklaşma yok, ışık değiştirilmedi.** Dolgu güneşin tam tersinden geldiği için zaten yalnız gece yarıküresine düşüyor; gündüzdeki +%5 ortam ışığından. |

Yeni: `core/frame_capture.gd` (CLI ekran görüntüsü), `Level.input_mode` (NONE = sabit poz, fare serbest), `levels/dev/day_test*.tscn`, `tests/test_player.gd`.
Test toplamı **1540 kontrol, 0 hata**. Headless demo 10 sn: hata 0.
Beckett MCP oturumu bu revizyon sırasında koptu (Godot 8770'te dinliyor, Claude Code tarafı ECONNREFUSED aldı). Doğrulamalar CLI ile yapıldı.

## Ölçümler
| Milestone | Sahne | FPS ort | FPS min | draw call ort | physics_process ort | Not |
|---|---|---|---|---|---|---|
| (a) | sandbox_a (1 gezegen) | 104 | 32 | 22 | 1,5 ms | 6 sn, editöre gömülü; min tek seferlik takılma |
| (a) rev1 | camera_test (1 gezegen + 4 kaya) | 98 | 72 | 22 | 2,6 ms | 3 sn; boom shape-cast her karede |

## Açık sorunlar / notlar
- (a) `get_performance_monitors` → `process_time` max 0,75 sn, ort 0,14 sn. FPS ort 104 ile çelişiyor; büyük olasılıkla Beckett örneklemesi/ekran görüntüsü sırasında ana iş parçacığı bekliyor. (d)'de daha kalabalık sahnede yeniden ölçülecek.
- Beckett MCP koparsa Claude Code'da `/mcp` ile yeniden bağlanmak gerekiyor; o sürede doğrulama CLI ile yapılıyor (bkz. CLAUDE.md).
- Beckett `validate_script`, geçici kopyada sınıf adını `__BeckettValidate` yapıyor. Bu yüzden `self`'i tipli parametreye geçiren kod doğrulamadan geçmiyor. Tasarım buna göre: Level, `player.input_source` ve `input.bind(player)` bağlamasını dışarıdan yapıyor.
- Beckett'in `update_file` çağrısı editörün henüz bilmediği bir dizindeki dosyayı kaydetmiyor. Tam tarama için Godot penceresinin odak alması gerekiyor (`osascript -e 'tell application "Godot" to activate'`). Bu yüzden plandaki tüm dizinler baştan oluşturuldu.
