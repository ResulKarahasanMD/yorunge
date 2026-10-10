# Yörünge — İlerleme

| Milestone | Tag | Durum | Tarih |
|---|---|---|---|
| (0) Kurulum | `m0` | ✅ tamam | 2026-10-10 |
| (a) Yerçekimi + karakter + kamera | `ma` | ✅ kullanıcı onayladı | 2026-10-10 |
| (b) Çoklu gezegen + geçişler | `mb` | ✅ | 2026-10-10 |
| (c) Toz, portal, seviye akışı, düşman, hasar | `mc` | ✅ | 2026-10-10 |
| (d) Shader ve görsel cila | `md` | ✅ | 2026-10-10 |
| (e) Ses + juice | `me` | ⏳ sürüyor | |
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

## (b) Çoklu gezegen + geçişler — 2026-10-10
### Kod
- `core/VectorMath.rotate_toward`: zıt vektörlerde (gezegenler arası zıplamada yerçekimi tam tersine döner) yedek eksenle döner. Player up dönüşü ve kamera çerçevesi bunu kullanıyor. Eski kod 180°'de dönüşü atlıyordu; oyuncu kafa üstü inecekti.
- `gravity/PlanetGraph`: yüzey boşluğu, komşuluk, BFS yol, atlama sayısı. `gravity/JumpReach.MAX_GAP = 9,0` (ölçüldü).
- `player/RespawnTracker`: güvenli zemin anlık görüntüsünü gezegenin yerel çerçevesinde tutuyor (dönen ayda doğru yer). 3 sn baskın alan yoksa ya da 60 m'den uzaksa `lost_in_space` → `Level` oyuncuyu son güvenli noktaya ışınlıyor.
- Stiller: `ice.tres` (ivme ×0,35, fren ×0,06 → kaygan), `lava.tres` (`contact_damage = 1`, hasar (c)'de), `moon.tres`.
- `ai/DemoBot` SEEK davranışı:
  - Hedef seçimi en ucuz yol (atlama×100 + mesafe).
  - Aynı gezegende büyük çember boyunca yürür.
  - Başka gezegene giderken: fırlatma noktasına yürür, 20°'den itibaren yavaşlar, 4°'de ve ≤1,5 m/s'de zıplar; havada hedefe yönelir.
  - Yalnız gezegen varsa tur atar.
  - Takılma ve kaçan zıplama sayacı var.
- `Level`: gezegen grafiği, `planet_of`, `planet_path`, `demo_goals`, `demo_threats`, `demo_behavior` (sandbox_a = GREAT_CIRCLE).
- `world/space_backdrop.tscn`: paylaşılan ortam (env + güneş + dolgu). `levels/dev/sandbox_b.tscn` = yeni ana sahne (4 gezegen; boşluklar 4 / 3,5 / 6 m; ay 25°/sn dönüyor).
- `debug/physics_probe.tscn`: headless ölçüm düzeneği (menzil taraması, ay taşıma, yeniden doğma).

### Doğrulama
- **Menzil (headless, R8 → R6):**
  - Dikkatli mod (yavaşla, 4°'de zıpla): 2,0–9,0 m arası **12/12** iniş; 10, 11, 12 m'de kaçırıyor.
  - Özensiz mod (tam hız, 15° önce zıpla): 6–9 m iner, 10 m+ kaçar.
  - → `MAX_GAP = 9,0 m`. 8 m izi: A'dan çıkışta g = −20,1 (B şimdiden çekiyor), dengeleme noktası A yüzeyinin 4,2 m üstünde. Yukarı vektörü +X'ten B'ye doğru kesintisiz dönüyor.
- **Dönen ay:** boşta oyuncu 3 sn'de ayın çerçevesine göre 30°/sn'de **0,000 m**, 60°/sn'de **0,002 m** kayıyor; zeminde kalma oranı 1,00. Motorun platform taşıması yeterli, elle taşımaya gerek yok.
- **Yeniden doğma:** 40 m uzaya ışınlanan oyuncu 3,02 sn'de kayıp sayıldı, son güvenli noktaya **0,000 m** hatayla döndü, zeminde.
- **Headless demo (sandbox_b, 45 sn):** bağlantılar `Grassy→Icy,Small; Icy→Grassy,Moon; Moon→Icy; Small→Grassy`. İlk 16 sn'de 6/6 zıplama indi. Ay → Küçük için Ay→Buz→Çimen→Küçük yolu bulundu. Hata 0.
- **Beckett (`demo_entry` → sandbox_b):**
  - `hops_landed = 6 / hops = 6`, hata/uyarı 0.
  - `current_up` 40 örnekte sürekli; takla anında 80 ms'de ~30°.
  - Ekran görüntüsü: fırlatma noktası, hedef gezegen tepede.
  - 5 sn performans: FPS 120/120/120 (ort/min/p95, 120 Hz ekranda vsync sınırı), draw call ort 35, physics 1,7 ms.
- **Testler:** 1576 kontrol, 0 hata (+`test_vector_math` 24, `test_planet_graph` 12).

## (c) Toz, portal, seviye akışı, düşman, hasar — 2026-10-10
### Kod
- `world/`:
  - `SurfaceAnchor`: gezegen altındaki nesneyi yönü korunarak verilen yüksekliğe oturtur.
  - `Stardust` (Area3D, sallanır ve döner).
  - `ExitPortal` (uyuyan/aktif, halka döner).
  - `SpikeBall`: gezegen merkezinde döner, gövde yüzeyde. Dikenler ikosahedron yönlerinde koni. Ezme kuralı saf `is_stomp()`.
- `player/`:
  - `PlayerHealth`: 3 kalp, 1,5 sn dokunulmazlık, `died`.
  - `PlayerVisual`: dokunulmazken yanıp söner.
  - Controller'a `heat` (lav), `bounce()`, `take_hit()` (geri itme) eklendi.
- `levels/`:
  - `Level`: toz → portal → `completed(LevelStats)`. Ölümde `failed`; dinleyen yoksa sahne yeniden yüklenir. Uzayda kaybolma −1 kalp. DemoBot'a hedef ve tehdit listeleri.
  - `LevelStats`, `TutorialHint` (Resource) + `TutorialHints`: tetikleyiciler hatırlanır, her ipucu en az 3,5 sn ekranda kalır.
- `main/`: `GameMain` + `main.tscn` (yeni ana sahne). Seviyeyi `LevelHost` altına yükler, HUD'u bağlar, tutorial'ları sırayla oynatır, ölümde tekrar dener, demo modunda bitince çıkar.
- `ui/`:
  - `Hud`: yıldız sayacı, kalpler, başlık, ipucu paneli, bildirim yazısı, "pop" tween'i.
  - `HeartIcon` ve `StardustIcon`: parametrik eğri / poligon çizimi, asset yok.
  - `UiText`: tüm arayüz metinleri.
- `autoload/GameState`: tutorial listesi, ilerleme, geçmiş.
- `ai/DemoBot`:
  - Lavda ısı 0,4'ü geçince zıplar.
  - Yanan zeminden 8° içinde özensiz fırlatma yapar.
  - Önündeki düşmana zıplar ve havada üstüne yönelir.
- Tutorial seviyeleri (`levels/tutorial_0{1,2,3}.tscn`): tasarım bir Python betiğinden üretildi, boşluklar kontrol edildi (bağlı 3,5–5 m, bağlı olmayan ≥ 11 m).
  - **T1 İlk Adımlar:** Meadow R10 + Pebble R5.
  - **T2 Sıçrayış:** çimen R8 → buz R7 → çimen R6 → kaya R5.
  - **T3 Tehlike:** çimen R9 (1 diken) → lav R7 → dönen ay R4 (30°/sn) → çimen R7 (2 diken + portal).

### Doğrulama
- **Headless demo** (`main.tscn`, `--demo --demo-exit-on-finish`, sabit 60 FPS):

| Seviye | Süre | Hasar | Ölüm | Toz |
|---|---|---|---|---|
| T1 İlk Adımlar | 20,22 sn | 0 | 0 | 5/5 |
| T2 Sıçrayış | 16,47 sn | 0 | 0 | 5/5 |
| T3 Tehlike | 43,15 sn | 0 | 0 | 5/5 |

  Hata 0, kaçan zıplama 0, atlanan hedef 0. İpuçları sırayla geldi.
- **Mekanikler** (`physics_probe`; bot bu koşuda düşmanlarla hiç karşılaşmadığı için ayrıca ölçüldü):
  - Üstten düşme → top **yenildi**, hasar 0, sıçrama var.
  - Yandan çarpma → **hasar 1**, geri itme var, top sağ.
  - Lavda 4 sn boşta durma → **2 hasar**, 3 sıcak ayak sıçraması, en yüksek ısı 0,98.
  - Lavda zıplayarak gezme → **0 hasar**, en yüksek ısı 0,37.
  - Uzayda kaybolma → −1 kalp + yeniden doğma.
- **Beckett:**
  - `ui_snapshot`: HUD "1 / 5", 3 kalp, başlık "1 · İlk Adımlar", ipucu "Hoş geldin, kaşif! …". **Türkçe karakterler (İ ş ç ü ı) varsayılan fontta doğru.**
  - T1, T2 (buz) ve T3 (lav) ekran görüntüleri alındı.
  - Kalp simgeleri satır yüksekliğine gerilip uzuyordu (30×54) → `SIZE_SHRINK_CENTER` ile düzeltildi.
  - 5 sn performans (T3): FPS 120/120/120, draw call ort 71, physics 1,3 ms. Uyarı 0.
- **Testler:** **1602 kontrol, 0 hata** (+`test_hazards` 15, `test_level_flow` 11).

## (d) Shader ve görsel cila — 2026-10-10
### Kod
- `shaders/noise.gdshaderinc`: hash, değer gürültüsü, 4 oktav fbm, 3D voronoi (F1, F2, id).
- `shaders/toon_light.gdshaderinc`: iki adımlı toon diffuse, ışık yönlü kenar parlaması, sert yansıma bandı. Godot 4.7 belgesine göre `LIGHT_COLOR / PI` ve albedo çarpımını motor yapıyor (context7 ile doğrulandı).
- `toon.gdshader` + `outline.gdshader` (ters gövde dış hattı, `next_pass`): oyuncu, dikenli küre, portal halkası, kaya, dekorasyonlar.
- `planet_surface.gdshader`: nesne uzayında fbm renk rampası + yüzey tipine göre katman:
  - çimen: koyu sınırlar ve çiçek noktaları;
  - buz: levha çatlakları ve yanıp sönen parıltılar;
  - lav: kayan kabuk levhaları arasında ışıyan, nabız gibi atan dikişler;
  - kaya: kraterler.
  - Vertex displacement yok, çarpışma küresiyle birebir.
- `atmosphere.gdshader`: parıltı = görüş ışınının kabukta aldığı yol ÷ en uzun teğet kiriş (gezegen gölgesi düşülmüş). İki ara sürüm reddedildi:
  - N·V kenarı: yakından düz bir bant veriyordu.
  - "En yakın geçiş" ölçütü: kamera kabuğa girince bütün gökyüzünü yıkıyordu.
- `starfield_sky.gdshader`: iki katman yıldız (parıldar), fbm nebula, güneş diski ve halesi. Küp harita geçişinde yıldız yok; ışınım haritası 32 piksel.
- `stardust.gdshader`, `portal.gdshader` (girdap; `active` 0→1, 0,8 sn tween).
- `world/SurfaceDecorator`: MultiMesh dekorasyon (çimen tutamı ve çiçek / buz kristali / lav kayası ve köz / kaya). Yoğunluk m² başına, tür başına en fazla 1500. Gezegen adı ve yarıçapından seed. Saf `scatter_transforms()` fonksiyonu.
- `world/ToonMaterials` fabrikası. `Planet`: yüzey shader'ı, atmosfer kabuğu (1,15 R), dekoratör.
- Ortam (`space_backdrop.tscn`): gökyüzü arka planı, ortam ışığı renkten (0,8), yansıma kapalı, AgX tonemap, glow (screen, eşik 1,0). MSAA 3D 2×.
- `levels/dev/gallery.tscn` + `debug/ShowcaseCamera`: dört gezegen tipi tek karede.

### Doğrulama
- **Beckett galeri görüntüsü:** dört tip ayırt edilebiliyor. Ayrıca T1 (gece yüzü, güneş diski, hale) ve T3 (dört gezegen + 3 diken + yıldız tozları) görüntüleri alındı. Shader hata/uyarısı 0.
- **Görülen sorunlar ve düzeltmeleri** (ekran görüntüsüyle):

| Görülen | Sebep | Düzeltme |
|---|---|---|
| Gezegenlerde büyük beyaz leke | Mat yüzeyde geniş yansıma bandı | Yansıma 0; buzda 0,45 + parlaklık 96 |
| Kalın haleler | — | Ölçek 1,22 → 1,15, yoğunluk 0,55 |
| Ufukta su gibi katı bant ve kabuk içinde yıkanmış gökyüzü | Hale ölçütü | Yol uzunluğu modeline geçildi |
| Soluk beyaz çimen | Prizma yüzlerinde yansıma bandı + açık ton | Dekorasyonda yansıma 0, ton color_low → color_mid |

- **`set_debug_draw overdraw`:** gezegen + atmosfer ≈ 2 katman, sıcak nokta yok.
- **Performans** (1968×1107 oyun görüntüsü, 10 sn):
  - Galeri: FPS **119,8 ort / 118 min**, draw call 80, 255 bin primitive.
  - T1 demo: **119,6 / 117**, draw call 77.
  - Ekran görüntüsüyle paralel ölçülen pencerede min 87 ve 0,53 sn takılma görüldü; tek başına ölçümde yok. Beckett yakalama etkisi.
- **Headless demo:** 3 tutorial'ın süreleri (20,22 / 16,47 / 43,15 sn) önceki milestone'la birebir aynı; görsel değişiklik oynanışı etkilemedi.
- **Testler:** **1617 kontrol, 0 hata**. `test_visuals` 15 kontrol: dekor sayısı = alan × yoğunluk, üst sınır, yüzeyde ve dik duruyor, seed deterministik, outline geçişi, gezegen shader parametreleri. Not: MultiMesh verisi headless'ta okunamadığı için yerleşim saf fonksiyondan test ediliyor.

## Çalışma modu (2026-10-10, kullanıcı)
b→h tek oturumda, onay beklemeden. Her milestone'da şu adımlar:
1. Testler.
2. Headless demo.
3. Beckett doğrulaması (bağlıysa).
4. Bu dosyaya rapor.
5. Commit + tag.

Durup sorma koşulları: aynı sorunda 3 başarısız tur, harici asset/eklenti gereksinimi, silme ya da geçmişi yeniden yazma.

## Varsayılan kararlar
_(kullanıcı sonradan değiştirebilir; her biri gerekçesiyle)_
- **UI dili Türkçe** (plan varsayılanı, onaylandı).
- **3 kalp**, kalpler bitince seviye baştan (plan varsayılanı, onaylandı).
- **Tüm gezegenlerde yerçekimi 24 m/s²**, tam çekim yüzeyden 1,5 m'ye kadar, etki yüzeyden 10 m'ye kadar. Gerekçe: menzil hesabı tek profile dayanıyor; ölçülen menzil 9 m oyuna yetiyor.
- **Tasarım boşluğu ≤ 7,2 m** (MAX_GAP × 0,8). Tutorial'larda 3–6 m, prosedürel modda derinlikle artarak en fazla 7,2 m. Gerekçe: insan oyuncu bottan özensiz zıplar; özensiz modda da 9 m ölçüldü, %20 pay bırakıldı.
- **Dönen ay için motorun AnimatableBody3D platform taşıması kullanılıyor** (ölçülen kayma ≤ 0,002 m / 3 sn).
- **Uzayda kaybolma: 3 sn baskın alan yoksa son güvenli zemine ışınlanma, −1 kalp.**
- **Lav = ısı birikimi, her temasta hasar değil.** Lavda kesintisiz 0,8 sn → 1 hasar + sıcak ayak sıçraması; havada 1 sn'de soğur. Gerekçe: bütün yüzey lav olduğundan "her temas 1 kalp" 3–4 sn'de ölüm demekti. Zıplayarak geçmek beceri haline geliyor (ölçüm: zıplayan 0 hasar, boşta duran 4 sn'de 2 hasar).
- **Dikenli küre: üstten ezme ≥ 0,35 × yarıçap yükseklik ve ≤ 0,5 m/s yükselme.** Yandan temas 1 hasar + geri itme (6 m/s yatay, 5 m/s dikey). Devriye hızı 16–20°/sn.
- **İpucu metinleri seviye sahnelerinde** (`TutorialHint` kaynakları). Arayüz metinleri `ui/ui_text.gd`'de. Gerekçe: ipuçları seviye içeriği.
- **Seviye bitince 2,5 sn sonra sıradaki tutorial, ölümde 1,5 sn sonra tekrar.** (f)'de seviye sonu ekranı araya girecek.
- **Kalp ve yıldız simgeleri kodla çiziliyor** (harici asset yok).
- **Görsel dil: toon + ince koyu dış hat** (karakter, düşman, portal); gezegenlerde dış hat yok (büyük kürelerde kalın görünüyor). AgX tonemap ve glow.
- **Dekorasyonlar çarpışmasız** (oynanışı etkilemesin, DemoBot ölçümleri değişmesin). Gölge düşürmüyor (performans).
- **`shaders/debug_checker.gdshader` artık kullanılmıyor**; silme kullanıcı onayına bırakıldı (kural: silme öncesi sor).

## Ölçümler
| Milestone | Sahne | FPS ort | FPS min | draw call ort | physics_process ort | Not |
|---|---|---|---|---|---|---|
| (a) | sandbox_a (1 gezegen) | 104 | 32 | 22 | 1,5 ms | 6 sn, editöre gömülü; min tek seferlik takılma |
| (a) rev1 | camera_test (1 gezegen + 4 kaya) | 98 | 72 | 22 | 2,6 ms | 3 sn; boom shape-cast her karede |
| (b) | sandbox_b (4 gezegen, demo) | 120 | 120 | 35 | 1,7 ms | 5 sn; 120 Hz vsync sınırı |
| (c) | tutorial_03 (4 gezegen, 3 düşman, demo) | 120 | 120 | 71 | 1,3 ms | 5 sn |
| (d) | gallery (4 tip, sabit kamera) | 119,8 | 118 | 80 | 1,4 ms | 10 sn, shader'lar + dekor + glow |
| (d) | tutorial_01 demo | 119,6 | 117 | 77 | 3,5 ms | 10 sn |

## Açık sorunlar / notlar
- (a) `get_performance_monitors` → `process_time` max 0,75 sn, ort 0,14 sn. FPS ort 104 ile çelişiyor; büyük olasılıkla Beckett örneklemesi/ekran görüntüsü sırasında ana iş parçacığı bekliyor. (d)'de daha kalabalık sahnede yeniden ölçülecek.
- Beckett MCP koparsa Claude Code'da `/mcp` ile yeniden bağlanmak gerekiyor; o sürede doğrulama CLI ile yapılıyor (bkz. CLAUDE.md).
- Beckett `validate_script`, geçici kopyada sınıf adını `__BeckettValidate` yapıyor. Bu yüzden `self`'i tipli parametreye geçiren kod doğrulamadan geçmiyor. Tasarım buna göre: Level, `player.input_source` ve `input.bind(player)` bağlamasını dışarıdan yapıyor.
- Beckett'in `update_file` çağrısı editörün henüz bilmediği bir dizindeki dosyayı kaydetmiyor. Tam tarama için Godot penceresinin odak alması gerekiyor (`osascript -e 'tell application "Godot" to activate'`). Bu yüzden plandaki tüm dizinler baştan oluşturuldu.
