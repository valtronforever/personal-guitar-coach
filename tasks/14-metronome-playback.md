# 14 — Метроном, transport і прослуховування

GitHub: [#14](https://github.com/valtronforever/personal-guitar-coach/issues/14)

Статус: `pending_user`
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

Реалізовано `TransportRequest/TransportPlan/TransportOutput`, інтеграцію у спільний AudioSessionCoordinator та `PreviewModel/PreviewControls` у читачі уроку. Одна sample timeline керує count-in, метрономом, простими reference tones, таб-курсором і canonical event на грифі. Підтримано 40–200 BPM, 3/4 та 4/4, акцент, окремі гучності, паузи, display chords, first/last bar, seek і loop. Pause/resume/tempo використовують новий UUID/epoch/count-in; stop очищує чергу. Practice mode не синтезує reference tones й потребує practice capture owner.

85 автоматичних core-тестів пройшли (runner рахує 86 із 1 explicit hardware test skipped), 35 app-тестів пройшли. Offline tests перевіряють абсолютні межі протягом 15 хвилин при 44.1/48 kHz і 40/73/120/173/200 BPM: ≤0.5 sample rounding без накопичення; count-in/loop/rest/first/last note, chunk-independent PCM, partial first loop після seek, відсутність reference tones у practice. Coordinator tests покривають permission-free preview, output channel, exclusive owner і cancelled/restarted request IDs. App test покриває canonical event → pause → seek → resume з новим темпом.

Додатково явно запущено `COACH_TEST_OUTPUT_NAME='MacBook Pro Speakers' swift test --package-path Packages/GuitarCoachCore --filter TransportHardwareTests`: реальний нативний output при 44100 Hz/512 frames, channel1, обидві гучності 0; 16433 rendered frames, valid host anchor, completed і stop/read nil. Це **беззвучна перевірка вихідного backend**, без input capture, зміни hardware format чи доказу чутності.

304 en/uk UI keys; localization/project validators і UI source type-check пройшли. Debug/Release .app з ad-hoc signature зібрано. Native UI перевірено English dark та Ukrainian light; у мінімальному вікні всі шість струн і керування доступні. Параметри винесено зі stack уроку, locale передано явно до popover. Локальний review: [14-review.md](../docs/reviews/14-review.md).

U09 залишає чутність, USB output, фізичний 15-хвилинний timing-run та leakage на фінальну сесію після 22 задач. U07 — execution Xcode UI tests. Render host anchor/presentation estimate не називаються калібруванням; це наступна задача 15.
