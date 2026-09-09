# 15 — Калібрування затримки та спільний час

GitHub: [#15](https://github.com/valtronforever/personal-guitar-coach/issues/15)

Статус: `todo`
Етап: MVP
Залежності: 11, 12, 14

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Не штрафувати користувача за затримку інтерфейсу й аналізатора.

## Робота

- Задокументувати capture/render timestamp semantics обраного бекенда, hardware latency і mapping у host timeline.
- Calibration profiles для route/channel/rate/buffer/backend; estimated/measured/manual status та uncertainty.
- Loopback flow за доступності; доступний estimated/manual шлях без неправдивої гарантії точності.
- Єдина формула residualOffset, позитивний error = late; не віднімати latency двічі.
- Invalidation при зміні конфігурації; drift detection для підтримуваних різних input/output devices.
- UI explanation і rhythm capability gate, якщо uncertainty перевищує половину tolerance.

## Критерії приймання

- Відомі штучні offsets +50 ms/−50 ms коректно компенсуються зі знаком.
- Profile від іншого route не застосовується без перевірки.
- Немає точного калібрування — тюнер і pitch practice доступні; rhythm/overall мають чесний статус.
- На baseline hardware виміряно residual error та записано процедуру відтворення.

## Перевірка

Synthetic delay injection, buffer/rate/device change, missing loopback, manual offset semantics, hardware round trip і long-run drift. Ціль residual p95 ≤20 ms або явно звужена rhythm capability.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
