# 06 — Профіль гітари та вибір строю

GitHub: [#6](https://github.com/valtronforever/personal-guitar-coach/issues/6)

Статус: `done`
Етап: MVP
Залежності: 03, 04, 05

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Поточний фізичний стрій явно визначає ноти й ціль тюнера.

## Робота

- Standard, Drop D, D Standard, C Standard з явними string numbers; редактор custom tuning і reference A4.
- Орієнтація right/left, шість струн і 24 лади у MVP.
- Валідатор діапазонів; непідтримуваний DSP pitch дозволено позначити для перегляду, але заборонено тихо оцінювати.
- Версіонування редагованих профілів, preview відкритих нот і частот.
- Пояснення fixedTuning mismatch; зміна профілю під час практики припиняє поточну спробу.

## Критерії приймання

- Пресети точно відповідають MIDI mapping у ARCHITECTURE.md.
- Custom profile зберігається, редагується й відновлюється після запуску.
- Інші features отримують один tuning snapshot; зміна мови не змінює tuning ID.
- UI пояснює необхідність фізично переналаштувати струни, а не створює враження audio pitch shifting.

## Перевірка

Presets, invalid values, save/load, profile revisions, mismatch для fixedTuning і оновлення resolver для followsInstrument.

## Докази виконання

- Нативна Instrument-вкладка: Standard/Drop D/D Standard, custom editor, A4 400–480, орієнтація, відкриті ноти/частоти та пояснення фізичного переналаштування.
- Custom profiles мають сталі ID, послідовні revision, перевірку stale edit і атомарний запис. Пресети не перезаписуються; selected snapshot узгоджений із registry.
- Pitch.parse підтримує E2, F#3, B♭3 та octave boundaries. Перегляд дозволено ширше C2–E6; validateForPractice відхиляє позадіапазонні ноти, без обіцянки виміряної DSP-точності.
- Fixed-tuning validator і TuningRequirementView підготовлено для задач 10/16. Тестований instrumentWillChange спрацьовує перед публікацією snapshot; підключення running-attempt interruption належить задачі 16.
- 32 core + 7 AppTests: успішно. Custom save/edit/reload, revision conflicts, неправильні значення, invariants і localization-independent ID перевірені на ізольованих даних.
- Native CUA: пресети/частоти, Drop D після relaunch та зміни мови, invalid A4/Save disabled, A4 442/частоти, Cancel без змін, en/uk layouts. Повернуто Standard/System; тестові custom profiles у користувацькі дані не додавалися.
- Debug/Release native builds, strict codesign, project/catalog checks (118 ключів) успішні. [Self-review](../docs/reviews/06-review.md).

C Standard follow-up: see [scope and evidence](follow-up/c-standard-course.md). The shared preset adds strings 6 → 1, C2 F2 B♭2 E♭3 G3 C4, without changing Standard defaults or existing saved profiles.
