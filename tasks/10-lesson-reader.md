# 10 — Каталог уроків і синхронізація кроків

GitHub: [#10](https://github.com/valtronforever/personal-guitar-coach/issues/10)

Статус: `todo`
Етап: MVP
Залежності: 05, 07, 08, 09

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Завершити сценарій «читаю → вибираю крок → бачу потрібні позиції й ноти».

## Робота

- Каталог з difficulty/topic/search, lesson detail, текстові блоки й кроки.
- Один selection model: крок → fingering/events → fretboard/tab; tab event → відповідний крок.
- Для event у кількох кроках залишати поточний відповідний крок або обирати перший за порядком; уникати selection loops.
- Restore last lesson/step; окрема від оцінки практики позначка прочитаного уроку.
- Practice entry з конкретним exercise ID; поки transport не реалізовано, не показувати фальшиву роботу кнопок playback.

## Критерії приймання

- Для sample lesson кожен крок підсвічує саме свої позиції; stale markers прибираються.
- Перемикання en/uk зберігає урок і вибраний крок.
- Broken content та порожній каталог мають пояснення; уроки доступні без аудіовходу.
- Вправа передається до Practice з правильною tuning policy.

## Перевірка

UI walkthrough обома мовами; click step, click tab, restore app, display-only chord, filtered catalog і invalid lesson fixture.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

