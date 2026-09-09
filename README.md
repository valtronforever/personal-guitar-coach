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

## App navigation and language

Use ⌘1–⌘4 for Lessons, Practice, Tuner, and Progress; ⌘, opens Settings. Language and appearance changes apply immediately. System language uses the first supported English/Ukrainian preference, falling back to English; macOS controls system dialogs and standard menus. Validate catalogs with `python3 Scripts/check_localizations.py`.

## Local persistence

Instrument settings and immutable practice summaries use atomic, versioned JSON in the app’s sandbox-aware Application Support/PersonalGuitarCoach directory. Unreadable files stay available for recovery; the history index can be rebuilt. Raw audio is not saved. Run UI state tests separately with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`; core tests remain `swift test --package-path Packages/GuitarCoachCore`.

## Lesson authoring

Read [CONTENT-AUTHORING.md](docs/CONTENT-AUTHORING.md) for the manifest, bilingual text, step references, version rules, and validation command. The current app bundles an original open-string lesson and supports reading it in English/Ukrainian without audio permission. Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons` before changing lesson content.

## Musical views and UI-source validation

Select a lesson step to highlight its fretboard positions, or switch to Tablature to inspect event timing and select notes. Shift-click/Shift-Space extends a range. Fractions describe duration as part of a whole note; dashed lines group beats. Long exercises have bar navigation and a 1×–2× zoom.

Debug builds include Developer → Visual test fixtures (no audio) and a minimum-window resize helper. They exercise the real renderers without saving attempts or claiming input capture. They are absent from Release.

Run `python3 Scripts/check_ui_sources.py` to type-check UI-test sources against the selected Xcode SDK with Swift 6 and a macOS 14 deployment target. This also runs in CI and does not substitute for Xcode UI-test execution (U07).

Каталог уроків підтримує пошук у локалізованих назвах/описах і фільтри теми та складності. Кроки та події табулатури синхронізують гриф; останній урок/крок відновлюються після перезапуску. Позначка прочитаного зберігається окремо від результатів практики. Перехід до конкретної вправи показує її стрій і темп; transport та оцінювана сесія реалізуються наступними задачами.

Аудіоналаштування тепер спільні для вікон: explicit input/output UID та канали, actual format, доступні hardware controls, meters і стани переривання. Від’єднаний пристрій не підміняється іншим входом. Фізичні USB/permission перевірки задачі 11 залишаються у `docs/USER-VALIDATION.md`; поточна перевірка охоплює native discovery/UI та synthetic lifecycle tests.
