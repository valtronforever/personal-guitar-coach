# 01 — Основа нативного macOS-проєкту

GitHub: [#1](https://github.com/valtronforever/personal-guitar-coach/issues/1)

Статус: `pending_user`
Етап: MVP
Залежності: —

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Отримати відтворюваний macOS app target, на якому можна перевіряти UI й реальний аудіовхід.

## Робота

- Перевірити повний Xcode, обрати стабільну версію та зафіксувати Swift, SDK, deployment target macOS 14+ і підтримувані архітектури.
- Створити PersonalGuitarCoach.xcodeproj, shared scheme, SwiftUI App lifecycle і локальний package зі структурою з ARCHITECTURE.md.
- Налаштувати app resources, unit/UI test targets, Debug/Release і repository ignores. Production signing secrets не потрібні для scaffold.
- Додати мінімальне вікно з локалізованою назвою та testable composition root. Контракти модулів вводити за потреби, не заповнювати проєкт порожніми абстракціями.
- Записати точні build/test/run-команди та версію toolchain у README; додати базову macOS CI-конфігурацію для доступного середовища.

## Критерії приймання

- Чистий checkout збирає й запускає справжній macOS .app за документованими кроками.
- Shared scheme доступна з xcodebuild; package tests можна запускати окремо.
- Немає machine-specific absolute paths у project configuration.
- Якщо Xcode недоступний, є точна діагностика; успішну збірку не заявлено.

## Перевірка

Build Debug і Release, запуск вікна, перевірка test discovery та одного smoke UI-сценарію. Зберегти версії інструментів і фактичні результати команд.

## Докази виконання

- Нативна SwiftUI .app, Xcode-проєкт зі shared scheme та SwiftPM build тих самих джерел.
- Xcode 26.6 / Swift 6.3.3 / SDK 26.5; arm64; deployment target macOS 14.
- 2 тести ядра пройдено. Debug/Release .app зібрано, обидва ad-hoc підписи перевірено.
- English welcome screen перевірено через native accessibility і screenshot; en/uk ресурси присутні в обох bundles.
- Генератор проєкту і plist перевірено. [Локальний review](../docs/reviews/01-review.md) містить findings і fixes.
- U07: Xcode project commands/UI tests чекають виправлення системного DVTDownloads. Це не блокує наступні задачі за прямою вказівкою користувача.
- Гілка: `codex/01-project-scaffold`; PR та merge evidence — на GitHub.
