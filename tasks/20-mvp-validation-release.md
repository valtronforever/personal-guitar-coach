# 20 — Перевірка MVP та локальна release-збірка

GitHub: [#20](https://github.com/valtronforever/personal-guitar-coach/issues/20)

Статус: `pending_user`
Етап: MVP
Залежності: 01–19

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Підтвердити, що додаток придатний до реального використання, і підготувати відтворювану release-збірку.

## Робота

- Перевірити всі критерії PRODUCT.md та task evidence; consolidated docs/VALIDATION.md з відомими обмеженнями.
- Повний hardware сценарій на Mac і USB-інтерфейсі: channel → tuning → tuner → lesson → practice → calibrated assessment → retry → history.
- Перевірити permission denial/recovery, hot-plug, sleep/wake, rate/buffer changes, corrupt storage, unsupported route.
- 15-хвилинна практика: callback underruns/dropped buffers, bounded memory, CPU, timing drift; визначити baseline hardware.
- EN/UK, клавіатура/VoiceOver, light/dark, мінімальний розмір вікна, довгі тексти.
- Release archive/app bundle, entitlements, icons/resources, offline запуск і build instructions. Локальний ad-hoc підпис. За уточненням користувача signing для розповсюдження, notarization та публікація не входять у задачу.

## Критерії приймання

- Релевантні automated tests і build пройдено; реальний USB hardware gate закрито.
- Немає критичних збоїв, оманливих оцінок або непрацюючих основних сценаріїв.
- Доступна локальна Release .app/архів із точними командами відтворення.
- Локальна .app має валідний ad-hoc підпис; зовнішнє розповсюдження та notarization не вимагаються.
- Жоден потрібний hardware check не прихований за mock test.

## Перевірка

Заповнений checklist з hardware/software versions, fixtures, метриками та фактичними build/test результатами. Якщо доступний лише один Mac або один інтерфейс, compatibility claims обмежити саме перевіреною матрицею.

## Докази виконання

Програмна реалізація: [зведена матриця приймання](../docs/VALIDATION.md), [локальний review](../docs/reviews/20-review.md), [900-секундний synthetic event benchmark](../docs/benchmarks/20-practice-soak.json) та [Release/ZIP report](../docs/benchmarks/20-local-release.json).

- Оригінальна іконка з десятьма macOS-розмірами; staged packaging перевіряє підпис, entitlements, ресурси й контент перед заміною .app. Локальний ZIP розпаковується й перевіряється повторно.
- Debug/Release збірки, 52 App tests, 360 quick DSP cases/gates, 492 локалізовані UI keys, генератор проєкту, UI-source type-check та corpus checks пройдено.
- Full core run: 128 перевірок пройдено; новий тест спільного ліміту спочатку мав неправильне очікування рівного розподілу. Після виправлення всі 5 collector tests проходять. Повний CI повторює 129 тестів на фінальному PR head.
- Прискорена симуляція: 45 231 snapshots, 900 атак, окрема нова спроба, два незмінні відновлені записи; не PCM і не фізичні 15 хвилин.
- `pending_user`: U01–U10, справжній USB/мікрофон/п'єзо, калібрування, тривалий CPU/RSS/drift, offline launch і фінальний UI/VoiceOver. Ці gates явно відкриті за вказівкою користувача; розповсюдження відсутнє.
