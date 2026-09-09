# Personal Guitar Coach

План нативного macOS-додатка для навчання гри на гітарі українською та англійською: уроки → інтерактивний гриф і табулатура → тюнер → практика під метроном → оцінка та рекомендації.

**Стан:** триває реалізація. Створено нативну SwiftUI-основу з локальними Debug/Release .app; функціональність додається за задачами.

- [AGENTS.md](AGENTS.md) — правила для агентів і розробників.
- [Опис продукту](docs/PRODUCT.md) — сценарії, межі MVP, інтерфейс.
- [Архітектура](docs/ARCHITECTURE.md) — модулі, музична модель, збереження.
- [Аудіо та оцінювання](docs/AUDIO-AND-ASSESSMENT.md) — сигнал, час, калібрування, правила оцінки.
- [План реалізації](tasks/README.md) — залежності та окремі файли задач.
- [Джерела](docs/REFERENCES.md) — офіційна документація Apple для технічних рішень.

Прогрес, залежності та evidence — у [плані задач](tasks/README.md). Основне джерело — електрогітара через інтерфейс; передбачено акустику через мікрофон або п'єзознімач. Залежні від користувача перевірки збираються для [фінального проходження](docs/USER-VALIDATION.md). Розповсюдження не планується.

## Локальна збірка

Перевірений toolchain: Xcode 26.6 (17F113), Swift 6.3.3, macOS SDK 26.5, arm64. Deployment target — macOS 14; запуск на macOS 14/Intel ще не перевірено. Команди використовують `DEVELOPER_DIR`, не змінюючи глобальний `xcode-select`.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --package-path Packages/GuitarCoachCore
python3 Scripts/build_local.py
python3 Scripts/build_local.py --configuration release
open build/debug/PersonalGuitarCoach.app
```

`build_local.py` збирає ті самі App-джерела через SwiftPM, компілює String Catalogs, пакує нативну .app та ставить локальний ad-hoc підпис. Production-сертифікати не потрібні. Результат — `build/debug/PersonalGuitarCoach.app` або `build/release/PersonalGuitarCoach.app`.

## Xcode-проєкт

`PersonalGuitarCoach.xcodeproj` і shared scheme включені в git. Після додавання/видалення App/UI-test файлів, ресурсів або package products оновити їх стандартним Python-генератором:

```sh
python3 Scripts/generate_project.py
python3 Scripts/generate_project.py --check
xcodebuild -project PersonalGuitarCoach.xcodeproj -scheme PersonalGuitarCoach -configuration Debug -destination 'platform=macOS' build
xcodebuild -project PersonalGuitarCoach.xcodeproj -scheme PersonalGuitarCoach -configuration Release -destination 'platform=macOS' build
xcodebuild -project PersonalGuitarCoach.xcodeproj -scheme PersonalGuitarCoach -destination 'platform=macOS' test
```

На поточному Mac `xcodebuild` не завантажує системний `DVTDownloads` потрібної версії. Це окрема від Swift-компілятора проблема встановлення Xcode, відкладена як U07. Не заявляємо проходження Xcode UI tests. CI перевіряє Xcode-проєкт у чистому середовищі; фактичний результат кожного запуску наведено у PR. Unit tests ядра запускаються окремо без UI та аудіопристрою.
