# 14 — Метроном, transport і прослуховування

GitHub: [#14](https://github.com/valtronforever/personal-guitar-coach/issues/14)

Статус: `todo`
Етап: MVP
Залежності: 03, 09, 10, 11

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Дати урокам і практиці спільну точну часову шкалу та еталонне звучання.

## Робота

- Audio-clock transport, sample-scheduled click buffers, count-in, 40–200 BPM, 3/4 і 4/4, accent, volume.
- Еталонний tone playback canonical events із підтримкою rests/durations та простих display chords.
- Start/stop/pause/seek/loop; UI cursor і fretboard activation від transport position.
- Count-in і event start epoch узгодити; на stop очистити scheduled buffers і активні tones.
- Preview mode окремий від assessed practice; reference tones у scored input session вимкнені.
- Зміни темпу застосовувати через новий transport segment/attempt, без накопиченої clock помилки.

## Критерії приймання

- Чутний приклад, tab cursor і fretboard відповідають одній події.
- Немає пропущеної першої чи останньої ноти, подвійного кліку на loop boundary.
- UI load не змінює запланований пульс.
- Output route відповідає обраному підтримуваному маршруту.

## Перевірка

Offline sample interval tests, count-in/bar boundaries, rests, stop/restart, seek і looping; hardware click на кількох BPM та 15-хвилинний timing run із вимірами. Input contamination перевірити окремо.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

