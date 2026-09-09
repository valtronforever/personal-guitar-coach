# 02 — Аудіопрототип і вибір бекенда

GitHub: [#2](https://github.com/valtronforever/personal-guitar-coach/issues/2)

Статус: `pending_user`
Етап: MVP
Залежності: 01

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Рано довести, що застосунок отримує реальний гітарний сигнал із вибраного інтерфейсу та може синхронізувати його з кліком.

## Робота

- Зібрати мінімальний capture/playback прототип за production service boundary, який можна розвинути у задачі 11.
- Перевірити Core Audio enumeration, конкретний input UID/канал, capture timestamps і вихід click buffer.
- Перевірити AVAudioEngine шлях та, якщо потрібно, AUHAL. Обрати один підхід за вимірами; не будувати два повні бекенди.
- Скласти матрицю: один USB-інтерфейс для input/output; USB input + built-in output; built-in input/output. Підтримку різних пристроїв не припускати.
- Зафіксувати actual sample rates/buffers, permission/entitlements, timestamp semantics, відновлення після від'єднання й можливість latency measurement.
- Написати docs/decisions/001-audio-backend.md із рішенням, tradeoffs, доступними маршрутами та відкритими ризиками.

## Критерії приймання

- Принаймні один фізичний USB-інтерфейс дає PCM саме з вибраного інструментального каналу в macOS app.
- Одночасно чути запланований клік на підтримуваному виході; input не містить навмисно підмішаного кліку.
- У звіті зазначені Mac/macOS, інтерфейс, драйвер за потреби, channels, sample rate/buffer і тип вимірювання затримки.
- Є обраний бекенд і рішення щодо непідтримуваних маршрутів. Без hardware evidence задача залишається відкритою, навіть якщо mock працює.

## Перевірка

Реальна гітара, багатоканальний input, 44.1/48 kHz де підтримуються, unplug/replug і capture+click. Loopback за доступності; його відсутність позначити.

## Докази виконання

- AUHAL input + окремий AVAudioEngine output; actor-isolated hardware lifecycle, C SPSC PCM buffer, explicit channel extraction і timestamps.
- Нативний audio setup: пристрій, канал, вихід, реальний формат, start/stop, рівень і діагностика; en/uk.
- Scarlett 2i2 USB визначено: 2 входи/2 виходи, 44,100 Hz, 512 frames. Output click start/stop перевірено в UI.
- 7 package tests пройдено, включно з concurrent 10,000-packet FIFO test. Debug/Release .app зібрано й підпис перевірено.
- [ADR і hardware matrix](../docs/decisions/001-audio-backend.md), [local review та fixes](../docs/reviews/02-review.md).
- Реальний capture очікує системного дозволу; U01/U02/U03/U04/U08 відкладено до фінальної сесії. Synthetic tests не замінюють ці перевірки.
- Гілка: `codex/02-audio-feasibility`; PR та merge evidence — на GitHub.
