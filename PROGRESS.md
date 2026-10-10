# Yörünge — İlerleme

| Milestone | Tag | Durum | Tarih |
|---|---|---|---|
| (0) Kurulum | `m0` | ✅ tamam | 2026-10-10 |
| (a) Yerçekimi + karakter + kamera | `ma` | ✅ kullanıcı onayladı | 2026-10-10 |
| (b) Çoklu gezegen + geçişler | `mb` | ✅ | 2026-10-10 |
| (c) Toz, portal, seviye akışı, düşman, hasar | `mc` | ✅ | 2026-10-10 |
| (d) Shader ve görsel cila | `md` | ✅ | 2026-10-10 |
| (e) Ses + juice | `me` | ✅ | 2026-10-10 |
| (f) Menüler + kayıt | `mf` | ✅ | 2026-10-10 |
| (g) Prosedürel mod | `mg` | ✅ | 2026-10-10 |
| (h) Uçtan uca DemoBot testi | `mh` | ✅ | 2026-10-10 |

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

## (e) Ses + juice — 2026-10-10
### Kod
- **Ses:**
  - `audio/SynthPatch` (dalga, frekans süpürmesi, ADSR, vibrato, arpej, gürültü karışımı, duty, alçak geçiren filtre).
  - `audio/Synth` → mono PCM16 `AudioStreamWAV` (44,1 kHz).
  - Ortam pad'i 22,05 kHz, 6 sn döngü, `LOOP_FORWARD`. Tüm frekanslar ve tremolo hızları döngü başına tam devre yuvarlanıyor, böylece dikiş yerinde süreklilik var.
  - `audio/SfxLibrary`: 11 efekt + pad akoru.
- `autoload/AudioManager` (`AudioSystem.current`):
  - Önce efektleri, sonra pad'i **işçi iş parçacığında** render ediyor.
  - 8 sesli havuz, boş ses yoksa en eskisini durdurup kullanıyor; oynatmada ±%5 rastgele perde.
  - Music/SFX busları kodla oluşturuluyor, pad 2,5 sn'de içeri geliyor.
  - Sayaçlar: çalınan, düşen, çalmak için durdurulan ses, aynı anda en çok çalan ses.
- `autoload/Juice` (`JuiceSystem.current`): hit-stop, **nesil numarasıyla** geri açılıyor.
- `vfx/Vfx`: 6 tür tek seferlik GPU parçacık patlaması (toplama, toz, ezme halkası, hasar, portal, köz). Gezegenin yukarısına hizalı, yumuşak radyal sprite. Malzeme ve mesh tür başına önbellekli, seviye yüklenirken ısıtılıyor.
- `OrbitCameraRig.add_trauma`: sarsıntı = travma² × gürültü (kaydırma + yuvarlanma), saniyede 1,6 sönüyor.
- `PlayerVisual`: sönümlü yayla esneme/ezilme (hacim korunuyor). Zıplamada +0,28, sıçramada +0,2, inişte darbe × 0,025 (en fazla 0,4).
- `levels/LevelFeedback`: bütün tepkiler tek yerde. Oyun kodu yalnız sinyal yayıyor; `Level` yeni konumlu sinyaller ekledi. `Hud`: hasarda kırmızı ekran parlaması.
- `main/GameMain.quit_game()`: sesi durdurur, 5 kare bekler, sonra çıkar.

### Doğrulama
- **Headless `test_audio`** (63 kontrol):
  - 11 efektin hepsinde uzunluk = süre × 44 100, NaN yok, kırpma yok, tepe 0,15–0,45, 16-bit PCM.
  - Pad: 132 300 örnek; dikiş adımı **0,0050**, %99'luk komşu adım **0,0110** → tık yok.
  - Render deterministik; perde varyantı farklı.
- **Ölçüm düzeneği (headless):**
  - Ezme → hit-stop 1, `time_scale` sonra **1,00**, travma 0,45, `scale_y` 0,97–1,19, 2 patlama, 3 ses.
  - Yandan çarpma → hit-stop, zaman geri açıldı, travma 0,60.
- **Bulunan hatalar:**
  1. Hit-stop bitişi duvar saatiyle karşılaştırılıyordu; `--fixed-fps`'te kareler gerçek zamandan hızlı aktığı için oyun **0,05 hızda takılı kalıyordu**. Nesil numarasına geçildi.
  2. Ses render'ı ~1 sn sürüyor, ilk sesler düşüyordu. Tek render + oynatmada perde yayılımına geçildi; efektler artık 200–220 ms'de hazır.
  3. Her parçacık patlaması yeni malzeme oluşturuyordu: fizik süresi ortalama **8,4 ms** (p95 22 ms). Önbellekle 4,3 ms, ısıtmayla **1,3–2,0 ms** (en fazla 6 ms).
  4. Headless çıkışta 14–15 nesne sızıyordu (`AudioStreamPlaybackWAV`/`WAV`). Pencereli koşuda gerçek ses sürücüsüyle sızıntı yok. Sahte sürücü hiç karıştırma yapmadığı için oynatmalar serbest kalmıyor. Sürücü "Dummy" ise oynatma başlatılmıyor, sayaç artıyor → headless uyarı 0.
- **Beckett (demo, gerçek ses sürücüsü):**
  - `plays_total` 22, düşen 0, durdurulan 0, en çok 2 ses aynı anda.
  - T3'te travma tepe 0,12, `PlayerVisual.min_scale_y` 0,96. Uyarı 0.
- **Parçacık vitrini:** `levels/dev/vfx_showcase.tscn`, CLI `FrameCapture` ile görüntü alındı. İlk sürümde kare pikseller vardı; radyal gradyan dokusuyla yumuşak yuvarlak kıvılcımlara geçildi.
- **Performans** (12 sn, demo T1→T3): FPS **119,5 ort / 117 min**, fizik 1,3 ms. Bir pencerede seviye geçişine denk gelen tek 60 FPS düşüşü görüldü (seviye kuruluşu).
- **Headless demo:** 3 tutorial süreleri aynı (hit-stop yalnız hasar ve ezmede; demoda ikisi de olmadı). Hata ve uyarı 0. **Testler 1680 kontrol, 0 hata.**
- **Ses kalitesini ben duyamıyorum:** senin dinlemen gerekiyor.

## (f) Menüler + kayıt — 2026-10-10
### Kod
- `autoload/SaveManager` (`SaveSystem.current`):
  - `user://save.cfg`, sürüm 1, [settings] + [progress]. En iyi süreler 0,01 sn hassasiyetle saklanıp karşılaştırılıyor.
  - Okunamayan ya da yanlış sürüm dosya `.bak` olarak yedekleniyor, varsayılana dönülüyor.
  - Demo modu ayrı profil (`user://demo_save.cfg`); `--fresh-save` demo profilini varsayılana çeker.
  - Ses ve tam ekran ayarları anında uygulanıyor. Tam ekran yalnız editöre gömülü değilken ve headless değilken; kamera hassasiyeti ve Y tersleme `settings_changed` ile canlı güncelleniyor.
- `ui/UiTheme` (kodla tema: lacivert paneller, yuvarlak düğmeler, altın odak çerçevesi) ve `ui/UiBuilder` (düğmelere tık ve odak sesi).
- Ekranlar:
  - `MainMenu` ("YÖRÜNGE", Başla/Devam et, Seviyeler, Sonsuz Mod (g'de görünür), Ayarlar, Çıkış).
  - `LevelSelect`: kilitli/açık seviyeler ve en iyi süreler. Başlıklar sahnenin `level_title`'ından `SceneState` ile okunuyor; tek kaynak.
  - `SettingsPanel`, `PauseMenu` (karartma), `LevelCompleteScreen` (süre, rekor/en iyi, kalp, ezilen düşman, toz). `UiText`'e menü metinleri ve Türkçe virgüllü süre biçimi eklendi.
- `GameMain` ekran akışı: MAIN_MENU / LEVEL_SELECT / SETTINGS / PLAYING / PAUSED / LEVEL_COMPLETE.
  - Menüde arkada `world/menu_backdrop.tscn` (dönen gezegen).
  - Esc/Start duraklatır, menülerde geri götürür (`_input`).
  - Fare yalnız insan oyuncu oynarken yakalanıyor. `Level.set_player_control` menüdeyken girdiyi kapatıyor.
  - Duraklatma süreye eklenmiyor (`elapsed` `_process`'te).
- `ai/MenuAutopilot`: düğme `pressed` sinyalleriyle Ana menü → Seviyeler → 1. seviye → her sonda Sonraki/Bitir. T2'de bir kez: duraklat → Ayarlar → hassasiyet 1,35 → Geri → Devam. `--menu-delay=` ile yavaşlatılabiliyor.
- `FrameCapture` birden çok kare yakalayabiliyor (`--capture=…{frame}.png --capture-frame=a,b,c`).

### Doğrulama
- **Headless menülü demo** (`--demo --demo-exit-on-finish --fresh-save`):
  - Ekran sırası: MAIN_MENU → LEVEL_SELECT → PLAYING → LEVEL_COMPLETE → PLAYING (T2) → PAUSED → SETTINGS → PAUSED → PLAYING → LEVEL_COMPLETE → PLAYING (T3) → LEVEL_COMPLETE → "Bitir" → quit.
  - Hata/uyarı 0. T2 süresi duraklatmaya rağmen 16,47 sn (duraklatma sayılmıyor).
- **Kayıt** (`read_file user://demo_save.cfg`): `best_times` = {20,22; 16,47; 43,15}, `unlocked_tutorials=4`, `sensitivity=1.35`. **İkinci açılış:** `[Save] loaded user://demo_save.cfg (sensitivity=1.35, unlocked=4)` → kalıcı.
- **Beckett ve CLI görüntüleri:** ana menü, seviye sonu, duraklatma, ayarlar. Türkçe karakterler doğru, odak çerçevesi görünüyor. Bulunan ve düzeltilen kusurlar:

| Kusur | Sebep | Düzeltme |
|---|---|---|
| Menü sol üst köşede | `set_anchors_preset` ofsetleri koruyup boyutu 0×0 bırakıyor | `set_anchors_and_offsets_preset` |
| Aynı süre "Yeni rekor!" | Yuvarlanmış kayıt (20,22) ile yuvarlanmamış koşu (20,2166) karşılaştırılıyordu | Saklanan hassasiyette karşılaştırma + test |
| İpucu paneli seviye sonu panelinin altından taşıyor | HUD görünür kalıyordu | HUD yalnız oyun ve duraklatmada görünür |

- **Süreç sorunu:** `main.tscn` editörde açıktı; dışarıdan yazdığım sürüm editör tarafından ezildi (ekranlar kayboldu). Ekran düğümleri Beckett `batch_execute` (create_node + attach_script + save_scene) ile editör içinden eklendi. Kural `CLAUDE.md`'ye yazıldı.
- **Testler:** **1703 kontrol, 0 hata**. `test_save` 23 kontrol: varsayılanlar, ayar gidiş-dönüşü, hassasiyet sınırı, en iyi süre / aynı süre / kilit / sonsuz derinlik, bozuk ve eski sürüm → `.bak` + varsayılan. Test yalnız kendi `user://test_save.cfg` dosyalarını oluşturup siliyor.

## (g) Prosedürel mod — 2026-10-10
### Kod
- `levels/LevelSpec`: düğümsüz seviye tanımı. Tipli iç sınıflar `PlanetSpec`, `SurfacePoint`, `EnemySpec`; karşılaştırma için kanonik `to_text()`.
- `levels/LevelGenerator.generate(seed, depth)` (deterministik):
  - Gezegen sayısı 3 + derinlik/2 (+0/1), en fazla 8. Başlangıç gezegeni çimen, R 8–10.
  - Ağaç büyümesi: %65 en yeni gezegene, kalanı eskilere dal.
  - Bağlantı boşluğu 3,0 m ile min(3,5 + 0,35·derinlik, 7,2) arası. Herhangi iki gezegen arası ≥ 3,0 m.
  - Tip ağırlıkları: çimen 35 / buz 25 / lav 8 + 2,5·derinlik (en fazla 30) / ay 20. Aylar R 3,5–5 ve 18–35°/sn dönüyor.
  - 5 toz farklı gezegenlerde. Portal başlangıçtan en çok zıplama uzaklıktaki gezegende. Düşman sayısı min(derinlik − 1, 4); başlangıç gezegeninde ve R < 5 gezegende düşman yok.
  - `validate()` tüm kuralları kontrol ediyor. Derinliğe göre seed: `level_seed(base, depth)`.
- `levels/LevelBuilder.build(spec)`: tutorial'larla aynı sahneler. Dekorasyon seed'i spec'ten, başlık "Sonsuz · Seviye N · #seed".
- `GameState` sonsuz modu (başlangıç seed'i, derinlik; `has_next_level` her zaman true). `GameMain.start_endless`, ortak `_load_current` / `_spawn_level`, yeniden denemede aynı spec. `SaveSystem` sonsuz modda en derin seviyeyi tutuyor.
- `ui/EndlessSetup`: seed alanı (sayı aynen, kelime hash'lenir), Rastgele, Başla, en derin seviye. Ana menüde "Sonsuz Mod" görünür.
- `MenuAutopilot`: `--endless-levels=N --endless-seed=S`. Tutorial'lardan sonra Sonsuz → seed → Başla → N seviye → Ana menü → `finish_demo()`.
- `debug/endless_probe.tscn`: tek bir üretilmiş seviyeyi bota oynatıp iz basıyor (`--seed --depth --time --trace`).

### Bulunan ve düzeltilen sorunlar (sonsuz mod ilk kez koşunca)
1. **Lavda ileri geri savrulma:** bot lav gezegeninin komşuya bakan tarafında "ısı zıplaması" yapınca karşıya geri uçuyordu. Yukarı yön 40°'lik koni içinde zıplama menzilindeki bir gezegeni gösteriyorsa ısı zıplaması yok.
2. **Dönen ayda fırlatma noktasına hiç varamama** (T3'te 600 sn takıldı): yavaşlama tabanı (~1 m/s) ay yüzeyinin hızından (~2,1 m/s) düşüktü ve 6°'de denge oluşuyordu; hız koşulu da dünyaya göre ölçülüyordu.
   - Hız artık zemine göreli ölçülüyor ve yürüyüş yüzey hızının en az 1 m/s üstünde.
   - Fırlatma evresine takılma algılaması eklendi (2 sn → 20° içinde özensiz fırlatma, 7 sn → hedefi atla).
   - İlerleme ölçütü değişince takılma sayacı sıfırlanıyor. → **T3 43,15 → 20,55 sn.**
3. **Yakın gezegenler arasında süzülme** (fizik hatası, insanı da etkiler): 2,5 m boşlukta iki çekim birbirini neredeyse götürüyordu (24 vs 23 m/s²). Oyuncu yüzeyden 0,2–0,3 m'de süzülüyor, yukarı yönü saniyede ters dönüyordu.
   - **Zemin kilidi:** zemindeyken ya da alçalırken, mevcut gezegenin yüzeyinden 1,2 m'den alçaksa yalnız o gezegen çekiyor. Yükselirken toplanmış alan korunuyor; böylece takla kalkışta başlıyor.
   - İlk denemede kilidi yükselirken de uyguladım; 2,5 m'de kafa çarpması çıktı. İkinci denemede kilit yalnız zeminde ve alçalırken.
   - Ölçüm: 3,0–9,0 m iner, 2,0–2,5 m kaçar. 1,5 m boyundaki kaşif dar boşlukta takla tamamlanmadan kafayla çarpıyor.
   - → **Tasarım kuralı: en küçük boşluk 3,0 m.** Tutorial'ların hepsi ≥ 3,5 m. Ölçülen MAX_GAP 9,0 m değişmedi.

### Doğrulama
- **`test_generator`** (500 seed, derinlik 1–10): **geçersiz 0**, gezegen 3–8, en büyük bağlantı boşluğu 6,99 m (≤ 7,2), spec başına 0,08 ms. Aynı seed → aynı spec. 50 seed → 50 farklı seviye. Derinlik 1'de düşman 0, derinlik 9'da ortalama 4,0; ortalama gezegen 3,4 → 7,6. Builder spec'le birebir (gezegen, 5 toz, uyuyan portal, düşmanlar, doğma noktası).
- **`endless_probe`**, 6 seed × derinlik 1–6, paralel: **6/6 tamamlandı, 5/5 toz**, 12,4–39,0 sn, atlanan hedef 0. Önceden takılan seed 1573045651 / d2: 23,0 sn.
- **Tam headless demo** (`--endless-levels=2 --endless-seed=2026`): T1 19,25 / T2 16,48 / T3 20,55 / Sonsuz 1 (#1850228613, 4 gezegen) 17,27 / Sonsuz 2 (#1573045651, 5 gezegen, 1 düşman) 23,02 sn. Hasar 0, hata ve uyarı 0, çıkış temiz. Üretim 0,3–0,5 ms.
- **Ölçüm düzeneği** (zemin kilidi sonrası): ezme, yandan çarpma, lav ve yeniden doğma sonuçları değişmedi.
- **Beckett** (`endless_probe`, seed 2026 derinlik 5): ekran görüntüsü tutarlı (buz + çimen gezegenleri + diken). FPS 113,8 ort; tek 0,53 sn takılma yine bir Beckett işlemine bitişik. Bağımsız ölçüm (h)'de oyun içi kare süresi raporuyla yapılacak.
- **Testler:** **1722 kontrol, 0 hata.**

## (h) Uçtan uca DemoBot testi — 2026-10-10
### Kod
- `ai/DemoReport` (yalnız demo modunda). Her seviye için oyun içinde gerçek zamanlı ölçüyor:
  - Ortalama FPS, %1 düşük (= 1 / p99 kare süresi), en kötü kare ve seviyedeki anı.
  - Seviyenin ilk 5 karesi (sahne kurulumu) `load_hitch_ms`, ekran görüntüsünden sonraki 3 kare (GPU okuması) `screenshot_ms` olarak **ayrı sütunda** raporlanıyor. FPS istatistiğinden çıkarılıyorlar ama gizlenmiyorlar.
  - Hata ve uyarı sayısı: `OS.add_logger` ile hem motor hem script mesajları.
  - LevelStats, DemoBot sayaçları (zıplama/inen, atlanan hedef, ezme denemesi).
  - Seviye sonunda nesne, düğüm ve artık (orphan) düğüm sayısı.
  - 6. saniyede ekran görüntüsü; PNG işçi iş parçacığında yazılıyor.
  - Sonda tablo basıp `demo_report.json` yazıyor.
- `DemoMode.option()`: seçenek önce komut satırından, yoksa demo giriş sahnesinden okunuyor. `debug/demo_entry_full.tscn`: 3 tutorial + 5 sonsuz (seed 2026), temiz demo profili, rapor `user://demo_report`.
- `GameMain.quit_game()` çıkmadan önce raporu ayırıyor: PNG görevlerini bekliyor, logger'ı kaldırıyor.
- **Portal sonrası dokunulmazlık:** `PlayerHealth.immune` portal girişinde açılıyor. Hasar gelmiyor, lav ısısı birikmiyor.
- HUD başlığına 10 px koyu dış hat eklendi.
- Test koşucusu artık kare bekleyen (coroutine) testleri de bekliyor. Yeni testler: `test_report` (9 kontrol), `test_leaks` (4), `test_level_flow` +6 (lav kontrolü ve portal sonrası güvenlik).

### Bulunan ve düzeltilen sorunlar
| Sorun | Sebep | Düzeltme | Kanıt |
|---|---|---|---|
| **Portala girdikten sonra lavda kalp kaybı** | Seviye bittikten sonraki 1,2 sn'lik portal efekti sırasında oyuncu hâlâ hasar alabiliyordu. Final koşuda bu iki kez oldu: E2 ve E3 bitince, portal lav gezegenindeydi. Log `completed` satırından sonra `[Health] -1 (lava) hearts=2` diyordu. İstatistiğe girmiyordu ama kalp, hasar sesi, parçacık, hit-stop ve kırmızı parlama oluyordu. | `PlayerHealth.immune` portal girişinde açılıyor, ısı birikmiyor | Testler: kontrol olarak lavda 90 karede ≥ 1 hasar; portal sonrası 90 kare lavda hasar 0, ısı 0, oyuncu zeminde. Logda bitişten sonraki hasar olayı: düzeltmeden önce final koşuda 2, headless 3+8'de 3; düzeltmeden sonra headless 3+5'te **0**. Süreler, zıplamalar ve toplam hasar değişmedi. |
| Ekran görüntüleri diske yazılmıyordu | İşçi görevine bağlanan Callable, Image'ı zayıf tutuyordu | Lambda yakalaması | 8/8 PNG |
| Ekran görüntüleri yanlış seviye adıyla kaydediliyordu | `await frame_post_draw` bazen bir sonraki seviyede dönüyordu | Beklemeden, son çizilen kare okunuyor | Dosya adları içerikle eşleşiyor |
| Pencereli koşu çıkışta çöküyordu (signal 11, exit 134) | GDScript Logger çıkışta hâlâ kayıtlıydı | Çıkıştan önce `detach()` | Sonraki 4 pencereli koşunun hepsi exit 0 |
| HUD başlığı parlak lav/buz önünde okunmuyordu | Dış hat yoktu | 10 px koyu dış hat | Görüntü kırpıntıları |
| Rapor başlığında `%%` | Biçim dizesi | Düzeltildi | — |

### Koşular
Hepsi aynı plan: menü → 3 tutorial (T2'de duraklat → Ayarlar → hassasiyet → Geri → Devam) → Sonsuz → seed 2026 → 5 seviye → Ana menü → çıkış.

| Koşu | Ortam | Seviye | Hata / uyarı | Seviye süreleri toplamı | Hasar | Ezme | Zıplama | FPS (kare ağırlıklı) | %1 düşük < 60 olan seviye | En kötü kare |
|---|---|---|---|---|---|---|---|---|---|---|
| Headless | `--fixed-fps 60`, 3 + 8 seviye | 11 | 0 / 0 | 295,87 sn | 2 | 2 | 58/60 | anlamsız | — | — |
| Headless, düzeltme sonrası | `--fixed-fps 60`, son kod | 8 | 0 / 0 | 193,83 sn | 1 | 1 | 36/37 | anlamsız | — | — |
| Beckett 1 | editöre gömülü, 120 Hz | 8 | 0 / 0 | 193,87 sn | 1 | 1 | 36/37 | 118,6 | 0/8 | 313,5 ms |
| Beckett 2 | editöre gömülü, 120 Hz | 8 | 0 / 0 | 193,90 sn | 1 | 1 | 36/37 | 118,8 | 0/8 | 1006,8 ms (E3) |
| Pencereli 1 | bağımsız, 144 Hz | 8 | 0 / 0 | 193,96 sn | 1 | 1 | 36/37 | 131,0 | 2/8 (E4 33,1; E5 31,2) | 94,5 ms |
| Yalnız tutorial | bağımsız, 120 Hz | 3 | 0 / 0 | 56,30 sn | 0 | 0 | 7/7 | 119,2 | 0/3 | 1122,0 ms (T2, 10,21 sn) |
| **Final** | bağımsız, 144 Hz | 8 | 0 / 0 | 193,91 sn | 1 | 1 | 36/37 | **129,0** | 2/8 (E3 32,0; E4 33,2) | 1047,3 ms (E5, 1,86 sn) |
| vsync kapalı | bağımsız, 144 Hz; testlerimle paralel koştu | 8 | 0 / 0 | 193,79 sn | 1 | 1 | 36/37 | 108,3 | 6/8 (T3–E5, 31–34) | 86,6 ms |

- Oynanış deterministik: seviye süreleri koşular arasında en çok 0,05 sn farklı; hasar, ezme ve zıplama sayıları aynı.
- Pencereli 1 çıkışta çökmüştü (yukarıdaki düzeltme). Ondan sonraki pencereli koşuların hepsi exit 0.
- `--disable-vsync` macOS pencere kipinde kare hızını açmadı (T1/T2 yine 144,5–144,9 FPS). Bu yüzden tavansız kare maliyeti ölçülemedi.

### Final koşu (pencereli, 1280×720, 144 Hz ekran)
Exit 0, hata 0, uyarı 0. Koşu 218,3 sn; seviye süreleri toplamı 193,91 sn.

| # | Seviye | Süre (sn) | Hasar | Ölüm | Ezme | Toz | FPS ort | %1 düşük | En kötü kare ms (sn) | Yükleme ms | Zıplama | Atlanan hedef |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | tutorial_01 | 19,26 | 0 | 0 | 0 | 5/5 | 143,4 | 110,3 | 43,0 (10,05) | 46,9 | 2/2 | 0 |
| 2 | tutorial_02 | 16,50 | 0 | 0 | 0 | 5/5 | 144,9 | 119,4 | 9,4 | 21,6 | 3/3 | 0 |
| 3 | tutorial_03 | 20,56 | 0 | 0 | 0 | 5/5 | 142,5 | 112,9 | 67,1 (8,01) | 27,4 | 2/2 | 0 |
| 4 | E1 #1850228613 | 17,28 | 0 | 0 | 0 | 5/5 | 144,9 | 123,9 | 8,8 | 20,1 | 2/2 | 0 |
| 5 | E2 #1573045651 | 23,02 | 0 | 0 | 0 | 5/5 | 144,8 | 118,9 | 20,8 | 21,8 | 5/5 | 0 |
| 6 | E3 #1092744277 | 33,18 | 0 | 0 | 0 | 5/5 | 97,1 | 32,0 | 63,0 (27,63) | 22,6 | 7/8 | 0 |
| 7 | E4 #441252939 | 22,75 | 1 | 0 | 0 | 5/5 | 111,9 | 33,2 | 69,8 | 31,7 | 6/6 | 0 |
| 8 | E5 #1670399091 | 41,36 | 0 | 0 | 1 | 5/5 | 129,1 | 99,6 | 1047,3 (1,86) | 29,2 | 9/9 | 0 |

- E4'teki hasar dikenli küreden. Bot 8 seviyede 13 ezme denemesi yaptı, 1'i başarılı.
- Ekran görüntüleri (her seviyeden bir tane, 6. saniye) ve rapor: `out_20261010_mh/` (git dışı; `01_tutorial_01.png` … `08_endless_1670399091_5.png`, `grid.png`, `demo_report.json`, `run.log`). Sekiz karede HUD sayacı, kalpler ve başlık doğru. E4'te 2 kalp görünüyor (hasar 1). Türkçe karakterler doğru.

### Performans yorumu
- **Ortalama:** final koşuda her seviyede ≥ 97 FPS, kare ağırlıklı 129,0 FPS. 60 FPS hedefi ortalamada sağlanıyor.
- **%1 düşük:** final koşuda 8 seviyenin 5'inde ≥ 110 FPS; E3 ve E4'te ~32 FPS. Aynı seviyeler başka koşularda iyi (E3: pencereli 1'de 120,7, Beckett 2'de 96,9). Hangi seviyenin düştüğü koşudan koşuya değişiyor; oynanış ise aynı. Yani düşüş oyundaki belirli bir olaya bağlı görünmüyor.
- **~1 sn'lik tek kare takılmalar:** 5 gerçek zamanlı koşunun 3'ünde birer kez görüldü, her seferinde farklı seviyede ve anda.
- **Ölçüm sırasında makinenin durumu** (ölçüldü):
  - Unity Editor 20:42'den beri açıktı; 23:36'da %247 CPU ve 9,3 GB bellek kullanıyordu.
  - Takas 4,2–4,9 GB'tı; vsync kapalı koşu sırasında takas alanı 5 GB'tan 6 GB'a büyüdü.
  - Yük ortalaması 11 çekirdekte 7–10 arasındaydı.
- **A/B deneyi:** yalnız tutorial, pencereli, 144 Hz; iki koşu arka arkaya.
  - Olduğu gibi: kare ağırlıklı 140,6 FPS, %1 düşük 98,3 / 124,2 / 122,6.
  - 11 ek meşgul döngüyle (`yes`, yük ortalaması 8 → 20): 142,0 FPS, %1 düşük 115,3 / 124,5 / 124,9.
  - **Saf CPU yükü düşüş üretmedi.** macOS ön plandaki oyunu muhtemelen öne alıyor.
  - Buna karşılık vsync kapalı koşu, bellek kullanan headless Godot test süreçlerimle paralel koştuğunda T3'ten sonraki her seviyede %1 düşük 31–34 FPS'e indi. Aynı sürede takas alanı 5 GB'tan 6 GB'a büyüdü. Bu, önceki koşulardaki ~32 FPS iziyle aynı.
  - En güçlü aday **bellek baskısı** (Unity 9,3 GB + takas). **Kanıtlanmadı.** Makine zaten takastayken bilerek bellek baskısı deneyi yapmadım.
  - Tek tek ~1 sn'lik takılmalar iki koşulda da görüldü (yüklü koşuda T1'de 774,8 ms).
- **Seviye yükleme karesi:** final koşuda 20–47 ms (tek kare). Ekran görüntüsü karesi 7,5–19 ms; yalnız demo raporunda oluyor.

### Sızıntı ölçümü
- **`test_leaks`:** aynı üretilmiş seviye (`endless_591407285_6`) 1 ısınma + 6 kez yüklenip boşaltıldı, GameMain'in yaptığı gibi.
  - Nesne sayısı [1766, 1765, 1766, 1765, 1766, 1765] (±1 geçici).
  - Kaynak 127 → 127, ağaçtaki düğüm 16 → 16, artık düğüm 0.
  - Testin sızıntıyı yakaladığı da gösterildi: her yüklemede 1 `Node` sızdıran kasıtlı bir mutantta nesne sayısı [1741 … 1746] diye artıyor ve test 2 kontrolle kırılıyor. Mutant tek seferlik bir scratch betiğiydi, depoda yok.
- **Headless 3 + 8 seviyelik koşu:** her seviyenin sonunda artık düğüm 0. Nesne sayısı düğüm sayısıyla birlikte değişiyor. Doğrusal modelde seviye sırasının katsayısı 3,0 ± 1,8 nesne/seviye (%95 GA −1,3…7,3), yani sıfırdan ayırt edilemiyor. Her seviye `GameState.history`'ye kasıtlı olarak bir `LevelStats` ekliyor.

- **Beckett, son kodla** (`demo_entry_full`, editöre gömülü): T1 5/5 → seviye sonu → T2 yüklendi. `game_logs level=warning`: 0 kayıt. Ekran görüntüsünde T2 buz gezegeni, HUD "1 / 5", dış hatlı başlık "2 · Sıçrayış", 3 kalp ve buz ipucu var. Koşu T2'de durduruldu.

### Testler
**1741 kontrol, 0 hata** ((g)'de 1722). `test_leaks` ve yeni lav testleri, gerçek fizik kareleri beklediği için koşu ~10 sn uzadı.

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
- **Ses varyantları önceden render edilmiyor;** her ses bir kez render ediliyor, oynatmada ±%5 rastgele `pitch_scale` (plan 3 varyant diyordu). Gerekçe: efektler ~1 sn yerine ~0,2 sn'de hazır, ilk zıplama sesi kaybolmuyor.
- **Pad:** A minör çevresinde (A2 E3 A3 C4), 6 sn döngü, −12 dB müzik.
- **Hit-stop yalnız hasar (90 ms) ve ezmede (60 ms)**, hız 0,05. Toplama, iniş ve portal yalnız sarsıntı ve ses alıyor (akışı bozmasın).
- **Parçacıklar `StandardMaterial3D` (billboard)** kullanıyor; toon shader'ın parçacığa katkısı yok, asset de yok.
- **"Başla/Devam et" açık olan en ileri tutorial'ı başlatıyor;** belirli bir seviye için "Seviyeler" ekranı var.
- **Demo modu ayrı kayıt profili kullanıyor** (`user://demo_save.cfg`). DemoBot senin ilerlemene dokunmuyor.
- **Varsayılan ses:** ana 0,8, müzik 0,6, efektler 0,8. Hassasiyet 0,25–3,0 (varsayılan 1,0).
- **Menü arayüzü kodla kuruluyor** (`UiBuilder`); sahnelerde yalnız kök Control + script var. Gerekçe: beş ekranı okunabilir tek bir listede tutmak.
- **Zemin kilidi 1,2 m** (zemindeyken ya da alçalırken yalnız mevcut gezegen çeker). Gerekçe: yakın gezegenler arasında süzülme. Hissi elle denemen gerekiyor.
- **En küçük gezegen boşluğu 3,0 m** (ölçüm: 2,5 m'de kafa çarpması).
- **Sonsuz mod tek bir başlangıç seed'inden derinlikle ilerliyor;** her derinliğin kendi türetilmiş seed'i var (HUD'da #seed). Seed alanına kelime de yazılabiliyor.
- **Sonsuz modda zorluk:** boşluk, gezegen sayısı, lav oranı ve düşman sayısı derinlikle artıyor; derinlik 1'de düşman yok.
- **(h) "3 tutorial + 5 seed" yorumu:** tek bir sonsuz koşu, başlangıç seed'i 2026, derinlik 1–5. Bu 5 farklı türetilmiş seed demek: 1850228613, 1573045651, 1092744277, 441252939, 1670399091; zorluk her seviyede artıyor. Gerekçe: oyuncunun gerçekte oynadığı akış bu (Sonsuz Mod → seed → ardışık seviyeler). Alternatif: derinlik 1'de 5 ayrı başlangıç seed'i.
- **FPS ölçüsü:** %1 düşük = 1 / p99 kare süresi. Seviye yükleme kareleri (ilk 5) ve ekran görüntüsü kareleri (3) FPS'ten çıkarılıp ayrı sütunda raporlanıyor. Ekran görüntüsü her seviyenin 6. saniyesinde alınıyor.
- **Portala giren kaşif dokunulmaz:** seviye bittikten sonra lav ya da diken kalp götürmüyor (özet ekranı 1,2 sn sonra geliyor).

## Ölçümler
| Milestone | Sahne | FPS ort | FPS min | draw call ort | physics_process ort | Not |
|---|---|---|---|---|---|---|
| (a) | sandbox_a (1 gezegen) | 104 | 32 | 22 | 1,5 ms | 6 sn, editöre gömülü; min tek seferlik takılma |
| (a) rev1 | camera_test (1 gezegen + 4 kaya) | 98 | 72 | 22 | 2,6 ms | 3 sn; boom shape-cast her karede |
| (b) | sandbox_b (4 gezegen, demo) | 120 | 120 | 35 | 1,7 ms | 5 sn; 120 Hz vsync sınırı |
| (c) | tutorial_03 (4 gezegen, 3 düşman, demo) | 120 | 120 | 71 | 1,3 ms | 5 sn |
| (d) | gallery (4 tip, sabit kamera) | 119,8 | 118 | 80 | 1,4 ms | 10 sn, shader'lar + dekor + glow |
| (d) | tutorial_01 demo | 119,6 | 117 | 77 | 3,5 ms | 10 sn |
| (e) | demo T1→T3 (ses + parçacık + sarsıntı) | 119,5 | 117 | 90 | 1,3 ms | 12 sn; parçacık önbelleği + ısıtma sonrası |
| (h) | Beckett 2: 3 tutorial + 5 sonsuz, editöre gömülü, 120 Hz | 118,8 | %1 düşük 91,2 | — | — | `DemoReport`, kare ağırlıklı; E3'te 1006,8 ms tek takılma |
| (h) | Final: 3 tutorial + 5 sonsuz, bağımsız pencere, 144 Hz | 129,0 | %1 düşük 32,0 (E3) | — | — | 5/8 seviyede %1 düşük ≥ 110; Unity Editor açıkken |

## Açık sorunlar / notlar
- Seviye geçişinde (yeni seviye kurulurken) tek karelik takılma var: (h) final koşuda 20–47 ms. Sebep dekorasyon üretimi ve sahne kurulumu. Geçiş zaten bekleme süresine denk geliyor.
- (a) `get_performance_monitors` → `process_time` max 0,75 sn, ort 0,14 sn; bu, FPS ort 104 ile çelişiyordu. Beckett örneklemesi ve ekran görüntüsü sırasında ana iş parçacığı bekliyor. (h)'de FPS oyun içi `DemoReport` ile Beckett'ten bağımsız ölçüldü.
- Beckett MCP koparsa Claude Code'da `/mcp` ile yeniden bağlanmak gerekiyor; o sürede doğrulama CLI ile yapılıyor (bkz. CLAUDE.md).
- Beckett `validate_script`, geçici kopyada sınıf adını `__BeckettValidate` yapıyor. Bu yüzden `self`'i tipli parametreye geçiren kod doğrulamadan geçmiyor. Tasarım buna göre: Level, `player.input_source` ve `input.bind(player)` bağlamasını dışarıdan yapıyor.
- Beckett'in `update_file` çağrısı editörün henüz bilmediği bir dizindeki dosyayı kaydetmiyor. Tam tarama için Godot penceresinin odak alması gerekiyor (`osascript -e 'tell application "Godot" to activate'`). Bu yüzden plandaki tüm dizinler baştan oluşturuldu.
