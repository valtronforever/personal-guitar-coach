# 22 — Нотний стан і розширена нотація

GitHub: [#22](https://github.com/valtronforever/personal-guitar-coach/issues/22)

Статус: `pending_user`
Етап: Після MVP
Залежності: 20

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Розширити показ музики після стабільного навчального циклу з табулатурою.

## Робота

- Підготувати окремий notation ADR: стандартний staff, ключ, тональність, enharmonic spelling, rhythmic beaming.
- Врахувати гітарну нотацію на октаву вище реального звучання; domain MIDI залишається sounding pitch.
- Спланувати ties, tuplets, tempo changes та позначення технік (bend/slide/hammer-on/pull-off) із schema versioning.
- Визначити, які техніки лише показуються, а які потребують нового аналізатора й критеріїв.
- Підготувати обмежений staff prototype, синхронізований із тими самими event IDs і табулатурою.

## Критерії приймання

- Prototype не дублює musical timeline і не змінює висоту аудіо через written-octave presentation.
- Є перевірений приклад гам із правильними accidental/duration і синхронним selection.
- Unsupported assessment techniques явно позначені.
- Складено окремі implementation tasks для затвердженого розширення; імпорт сторонніх форматів не додано автоматично.

## Перевірка

Sounding E2 → правильна гітарна written note, key/accidental fixtures, event selection parity, layout і accessibility в en/uk.

## Докази виконання

Прототип реалізовано: [ADR 007](../docs/decisions/007-staff-notation.md), [локальний review](../docs/reviews/22-review.md), [подальші задачі нотації](follow-up/notation.md).

- Режим Staff (prototype) в уроці використовує ту саму TimelineModel, event IDs, LessonSelection і preview cursor, що й табулатура. Записана октава +12 не змінює звук, стрій або оцінювання.
- Ключові знаки neutral/G major/F major, accidental memory по октавах із reset такту, ledger lines, п'ять тривалостей нот/пауз, uniform beaming і клавіатурні bindings. Непідтримувані такти явно пояснено en/uk.
- 6 staff model/selection tests, golden C-major sequence та весь курс; full App suite 59/18 пройдено. Окремий opt-in ImageRenderer прогін створив 48 geometry artifacts; оглянуто ключ, паузи, beams, ledger lines та hollow heads у темах. Це не native UI/VoiceOver test.
- 503 UI keys en/uk, актуальний Xcode-проєкт, UI-source type-check, локальні Debug/Release й підписаний ZIP. Final CI/merge evidence публікується в GitHub issue #22.
- `pending_user`: U05/U07 — нативний keyboard/VoiceOver, мінімальне вікно, en/uk тексти й user musical review. Повторне CUA-підключення повернуло pipe-closed error; обхід не застосовано.
- Ties, tuplets, tempo map та bend/slide/hammer-on/pull-off сплановано з версіонуванням і новими assessment gates. Імпорт форматів і неперевірене оцінювання технік не додані.
