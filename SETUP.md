# Kurulum Kılavuzu (SETUP.md)

Bu belge, PC Build Simulator projesini kendi bilgisayarınızda (Linux veya Windows) çalıştırmak için gerekli adımları içerir.

## Gereksinimler
- **Godot 4.3 Stable** (Standard Edition, .NET versiyonu *değil*)
- **Git**
- *(Android export için)* OpenJDK 17, Android SDK

## Godot Kurulumu

### Windows
1. [godotengine.org](https://godotengine.org) adresinden Windows 64-bit zip dosyasını indirin.
2. Zip içerisindeki dosyayı herhangi bir klasöre çıkartın (kurulum gerektirmez).
3. `Godot_v4.3-stable_win64.exe` dosyasını çalıştırarak Godot'u başlatın.

### Linux (Ubuntu/Debian)
1. Godot'un resmi sitesinden Linux için portable binary dosyasını indirin.
2. Terminal üzerinden çalıştırılabilir yapın: `chmod +x Godot_v4.3-stable_linux.x86_64`
3. Opsiyonel: Terminalden kolayca açmak için symlink oluşturun:
   `sudo ln -s /path/to/Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot`

## Projeyi Klonlama
Projeyi bilgisayarınıza klonlamak için aşağıdaki komutu kullanın:
```bash
git clone https://github.com/ahmetseliim/pc-build-sim.git
```
Godot'u açın, **Import** butonuna tıklayın, klonladığınız proje klasörünü (içindeki `project.godot` dosyasını) seçin ve **Import & Edit** butonuna basın.

## Git Yapılandırması
- `.gitignore` ve `.gitattributes` dosyaları repo'da mevcuttur.
- Özellikle Windows'ta LF/CRLF satır sonu sorunu yaşanmaması için `.gitattributes` yapılandırılmıştır.

## İlk Çalıştırma
- Editör açıldıktan sonra projeyi test etmek için **F5** veya sağ üstteki **Play** butonuna basın.
- `Main.tscn` (Ana sahne) otomatik olarak çalışacaktır.

## Android Export Kurulumu (Opsiyonel)
Oyunu Android cihazlarda test etmek istiyorsanız:
1. **JDK 17**'yi sisteminize kurun.
2. **Android SDK / Android Studio** kurulumunu tamamlayın.
3. Debug için bir keystore oluşturun:
   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
   ```
4. Godot'ta `Editor -> Editor Settings -> Export -> Android` menüsüne gidin ve SDK, JDK, ve Debug Keystore yollarını ayarlayın.

## Sık Karşılaşılan Sorunlar
- **Import hataları veya bozuk sahneler**: Proje klasöründeki gizli `.godot/` klasörünü silip projeyi Godot üzerinden yeniden açın.
- **Sahne açılmıyor**: Godot sürümünüzü kontrol edin, mutlaka 4.3 Stable olmalıdır.
- **Android export başarısız**: Editor Settings altındaki SDK/JDK dosya yollarını doğru belirttiğinizden emin olun.
