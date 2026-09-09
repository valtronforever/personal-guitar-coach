# 06 — Профіль гітари та вибір строю

GitHub: [#6](https://github.com/valtronforever/personal-guitar-coach/issues/6)

Статус: `todo`
Етап: MVP
Залежності: 03, 04, 05

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Поточний фізичний стрій явно визначає ноти й ціль тюнера.

## Робота

- Standard, Drop D, D Standard з явними string numbers; редактор custom tuning і reference A4.
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

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
