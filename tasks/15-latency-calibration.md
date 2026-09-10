# 15 — Калібрування затримки та спільний час

GitHub: [#15](https://github.com/valtronforever/personal-guitar-coach/issues/15)

Статус: `pending_user`
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

- Реалізовано валідовані Domain profiles/routes/evidence, атомарне сховище version 1, selected-stream hardware metadata, normalization та rhythm gate. [ADR 003](../docs/decisions/003-calibration-time.md) фіксує timestamp semantics, формулу, припущення та процедуру hardware перевірки.
- Loopback має короткий (~26 с) і довгий (~15 хв) режими, irregular pulses, зіставлення onset events, bounded history, confidence/clock checks, скасування через UUID lease. Невдалий або перерваний run не зберігає часткового профілю.
- Нативний екран en/uk: параметри маршруту, estimated/manual/measured статус, offset/uncertainty, інструкції кабелю й обмеження rhythm. Тюнер/pitch не потребують measured profile; застосування gate до результатів — задачі 16/17.
- `swift test --package-path Packages/GuitarCoachCore`: 97 автоматичних тестів пройшли; 1 opt-in hardware test пропущено (98 у звіті). Синтетичний PCM через actual renderer/analyzer: усі 12 імпульсів, offsets ±50 ms при 44.1/48 kHz, error ≤20 ms і residual p95 ≤20 ms; +50-ms варіанти також містять слабку фонову синусоїду. Це не hardware evidence.
- `swift test`: 38 App tests пройшли, включно зі збереженням completed synthetic measurement, route-change interruption, failed writes і restore.
- Генерація Xcode project, 338 en/uk keys, UI-test source type-check, Debug/Release local .app/ad-hoc signing. Нативно оглянуто English dark та Ukrainian light, scrolling/manual controls і disabled missing-route state. Реальний input не запускався.
- [Локальний review](../docs/reviews/15-review.md). U03/U08/U09: USB round trip, actual residual p95, long-run drift та normal microphone permission залишаються до фінальної користувацької сесії. U07: actual UI-test execution. Issue залишається відкритим / Project In review після merge.
