# Personal Guitar Coach

Нативний macOS-додаток для навчання гри на гітарі українською та англійською: уроки → інтерактивний гриф і табулатура → тюнер → практика під метроном → оцінка та рекомендації.

**Стан:** реалізовано навчальний цикл, тюнер, практику, оцінки й історію, шість двомовних уроків та обмежений нотний стан. Локальні Debug/Release .app доступні; фізичне приймання на гітарі та фінальні UI/VoiceOver перевірки залишаються відкритими.

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
python3 Scripts/build_local.py --configuration release --archive
python3 Scripts/check_local_bundle.py build/release/PersonalGuitarCoach.app --archive build/release/PersonalGuitarCoach.zip
open build/debug/PersonalGuitarCoach.app
```

`build_local.py` збирає ті самі App-джерела через SwiftPM, компілює String Catalogs, пакує нативну .app та ставить локальний ad-hoc підпис. Перед заміною попередньої .app перевіряє staged bundle, уроки, переклади, іконку та підпис. `--archive` також створює локальний ZIP. Production-сертифікати не потрібні. Результат — `build/debug/PersonalGuitarCoach.app` або `build/release/PersonalGuitarCoach.app`.

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

Read [CONTENT-AUTHORING.md](docs/CONTENT-AUTHORING.md) for the manifest, bilingual text, step references, version rules, and validation command. The app bundles [six original starter lessons](docs/STARTER-COURSE.md), fully readable in English/Ukrainian without audio permission. Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path Packages/GuitarCoachCore ValidateLessonContent Resources/Lessons` before changing lesson content.

## Musical views and UI-source validation

Select a lesson step to highlight its fretboard positions, or switch to Tablature to inspect event timing and select notes. Shift-click/Shift-Space extends a range. Fractions describe duration as part of a whole note; dashed lines group beats. Long exercises have bar navigation and a 1×–2× zoom.

Debug builds include Developer → Visual test fixtures (no audio) and a minimum-window resize helper. They exercise the real renderers without saving attempts or claiming input capture. They are absent from Release.

Run `python3 Scripts/check_ui_sources.py` to type-check UI-test sources against the selected Xcode SDK with Swift 6 and a macOS 14 deployment target. This also runs in CI and does not substitute for Xcode UI-test execution (U07).

Каталог уроків підтримує пошук у локалізованих назвах/описах і фільтри теми та складності. Кроки та події табулатури синхронізують гриф; останній урок/крок відновлюються після перезапуску. Позначка прочитаного зберігається окремо від результатів практики. Перехід до конкретної вправи відкриває практику з її строєм і темпом. Доступні тюнер, метроном, preflight, відлік, вибір цілих тактів, окремі повтори та збереження оцінки. Фізичний аудіопрохід потребує фінальних перевірок.

Аудіоналаштування тепер спільні для вікон: explicit input/output UID та канали, actual format, доступні hardware controls, meters і стани переривання. Від’єднаний пристрій не підміняється іншим входом. Фізичні USB/permission перевірки задачі 11 залишаються у `docs/USER-VALIDATION.md`; поточна перевірка охоплює native discovery/UI та synthetic lifecycle tests.


## Offline audio analysis

The shared capture worker now produces monophonic pitch, separate attack timestamps and bounded signal-quality evidence. Read [ADR 002](docs/decisions/002-monophonic-analysis.md), the [current assessment/DSP benchmark](docs/benchmarks/17-assessment.md), and [assessment rules](docs/decisions/004-assessment.md). Tuner, practice and bounded scoring are implemented; real electric-interface checks remain deferred.

```sh
python3 Scripts/check_audio_fixtures.py
swift run -c release --package-path Packages/GuitarCoachCore BenchmarkAudio Tests/Fixtures/Audio --quick --output /tmp/audio-benchmark.json
python3 Scripts/check_audio_benchmark.py /tmp/audio-benchmark.json
```

The committed public acoustic fixtures work offline and have [provenance/permission](Tests/Fixtures/Audio/README.md). Omit `--quick` for the full 3,360-case comparison. Software grading capability requires notes ≥200 ms; shorter examples remain available for visualization/playback. Raw user audio is not recorded.

An explicit, silent native-output transport smoke test is available when the named output is connected. It does not request microphone permission, change device rate/buffer, or establish audibility/round-trip latency:

```sh
COACH_TEST_OUTPUT_NAME='MacBook Pro Speakers' DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/GuitarCoachCore --filter TransportHardwareTests
```

Ordinary tests skip this hardware test. Choose the exact device name intentionally; no fallback output is selected.

Latency calibration is available from Audio setup → Latency calibration. Select input/output first. Estimated/manual profiles preserve pitch practice without enabling rhythm scores. Cable loopback measures the selected route; physical validation is pending. See [ADR 003](docs/decisions/003-calibration-time.md) for timestamp semantics, uncertainty and the final hardware procedure.


Practice checks a stable input signal after explicit physical-tuning confirmation, then starts the audio-clock count-in. Pause, seek, tempo or tuning changes close a partial attempt. Each repeat waits for analysis/save and starts a new count-in. Completed attempts save the exact inputs and score parameters; unreliable rhythm calibration produces pitch feedback only. Save failures stop automatic repetition and offer retry. Debug → Synthetic results presents the four result-validity states without capture or history writes. Results now include evidence-backed advice, per-event TAB symbols, saved conditions and compatible previous/best scores. Open Progress for saved attempts or View result after practice. Prepare a recommended fragment to restore its archived exercise, tuning target, bars and tempo without starting audio. Summary-only legacy history stays readable. See [feedback and progress rules](docs/decisions/005-feedback-progress.md). The six-lesson starter course now covers open strings, first frets, steady pulse, C major, A minor pentatonic and an Em arpeggio. Final physical/UI validation remains pending.

Зведена перевірка MVP, відтворення локального пакета, походження іконки та відкриті hardware gates: [VALIDATION.md](docs/VALIDATION.md). Прискорений 900-секундний synthetic event benchmark перевіряє обмеження пам’яті даних і збереження спроб; він не замінює 15 хвилин реальної гри.

Дослідження одночасних акордів завершило програмний експеримент із рішенням [не вмикати оцінювання](docs/research/21-chords.md): методи не пройшли вимоги точності, повноти нот та невизначеності. Показ форми акорду й оцінювання окремих нот арпеджіо залишаються доступними.

У режимі уроку доступний **Staff (prototype) / Нотний стан (прототип)**: та сама послідовність і вибір, гітарна записана октава, ключові знаки, паузи й прості beams. [ADR 007](docs/decisions/007-staff-notation.md) описує межі та майбутнє версіонування ties/tuplets/технік. Для відтворення окремих geometry artifacts: `COACH_STAFF_RENDER_DIR=build/staff-renders DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter StaffRenderTests`. Це не запускає native UI tests.
