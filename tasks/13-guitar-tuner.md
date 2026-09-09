# 13 — Тюнер поточного строю

GitHub: [#13](https://github.com/valtronforever/personal-guitar-coach/issues/13)

Статус: `todo`
Етап: MVP
Залежності: 06, 12

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Допомогти фізично налаштувати всі струни перед практикою.

## Робота

- Auto target і manual string selection для всіх tuning profiles; actual detected note/octave та target frequency.
- Cents indicator, flat/sharp/in-tune labels, confidence і hysteresis/smoothing.
- Початковий in-tune band ±5 cents зі стабільністю не менше 300 ms; уточнити за вимірами.
- Silence/unstable/clipping/out-of-range states; низька confidence не зберігає зелену «налаштовано».
- Спільний AudioCoordinator; вхід у tuner з практики лише після завершення/переривання її attempt.

## Критерії приймання

- Manual string6 у Drop D має target D2; зміна reference A4 змінює reference всіх струн.
- Auto mode не видає октавну гармоніку за правильно налаштовану струну без перевірки.
- Шум/тиша не підтверджують налаштування; feedback зрозумілий без кольору.
- Перехід tuner ↔ practice не створює другого capture pipeline.

## Перевірка

Synthetic detuning ±5/10/25/50 cents, silence after stable tone, near-boundary jitter, octave confusion; фізично налаштувати шість струн у Standard і Drop D, en/uk.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

