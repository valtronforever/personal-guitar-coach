# 18 — Результати, рекомендації й прогрес

GitHub: [#18](https://github.com/valtronforever/personal-guitar-coach/issues/18)

Статус: `todo`
Етап: MVP
Залежності: 05, 10, 17

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Перетворити виміри на зрозумілий наступний крок навчання.

## Робота

- Results view: overall за доступності, pitch/rhythm, validity/confidence, per-event annotations у табулатурі.
- 1–3 rule-based recommendations із evidence counts, тактами, рекомендованим темпом і deep link у repeat fragment.
- Separate signal/setup advice від performance advice; localized parameterized templates.
- Збереження і відновлення історії спроб, last/best для сумісних умов.
- Порівняння з урахуванням versions/BPM/tuning/range; прочитання уроку окремо від practice outcome.

## Критерії приймання

- Кожна рекомендація має відтворюваний зв'язок із конкретними спостереженнями.
- Немає тверджень про «неправильний палець» або фактично зіграну струну.
- Uncalibrated/interrupted/insufficient signal показують причину без оманливого overall.
- Retry suggestion відкриває правильний фрагмент і темп; мова історії перемикається без втрати даних.

## Перевірка

Rule fixtures з мінімальною evidence, result → retry flow, persistence reload, en/uk числівники й довгі тексти, incomparable attempts, accessibility без color-only markers.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

