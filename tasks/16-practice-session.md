# 16 — Повний цикл практики

GitHub: [#16](https://github.com/valtronforever/personal-guitar-coach/issues/16)

Статус: `todo`
Етап: MVP
Залежності: 06, 10, 13, 14, 15

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

З'єднати вправу, сигнал, метроном і UI в керований цикл гри.

## Робота

- State machine із AUDIO-AND-ASSESSMENT.md; immutable snapshots exercise/tuning/audio/tempo/calibration.
- Preflight signal test, tuning mismatch, supported DSP range/tempo, count-in, running і finalization.
- Вибір фрагмента цілими тактами, repeat loops як окремі attempts, retry.
- Live expected/observed feedback без передчасної остаточної оцінки; finite analysis buffers.
- Pause/seek/tempo changes закривають partial attempt; resume = новий відлік і attempt.
- Hot-unplug, sleep, permission/format change зупиняють оцінювання з правильною причиною.

## Критерії приймання

- Урок відкриває саме свою вправу; курсор і очікувані ноти узгоджені зі звуком.
- Count-in не додає missed/extra events; фіналізація дочікується останньої аналізованої ноти.
- Переривання не виглядає як completed success або оцінка 0.
- Restart не зберігає попередні attack events; tuning snapshot не змінюється під час running.

## Перевірка

State transition tests із fake clock/device/observations; complete, cancel, pause/resume, empty signal, loop boundary, unplug і last-note tail. Повний hardware run до фіналізації evidence, до scoring інтеграції.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
