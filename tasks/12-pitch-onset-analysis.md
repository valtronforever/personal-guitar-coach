# 12 — Розпізнавання висоти й атак нот

GitHub: [#12](https://github.com/valtronforever/personal-guitar-coach/issues/12)

Статус: `pending_user`
Етап: MVP
Залежності: 03, 11

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Отримувати достовірні monophonic note events із чистого гітарного сигналу.

## Робота

- Обрати й обґрунтувати pitch/onset algorithms первинними джерелами та benchmark.
- Аналіз selected mono channel: level/noise evidence, pitch Hz/MIDI/cents, confidence, onset timestamps.
- Відокремити transient/onset від стабільної pitch estimate; repeated same-pitch attacks від sustain.
- Обробити silence, clipping, harmonics, octave ambiguity, out-of-range і негативні polyphonic fixtures.
- Створити deterministic offline runner, annotated corpus/provenance і benchmark report.
- Визначити підтримувану матрицю pitch × note duration × BPM. Заборонити оцінювання за її межами, навіть якщо UI дозволяє показ/прослуховування.

## Критерії приймання

- Досягнуті або обґрунтовано переглянуті з evidence targets у AUDIO-AND-ASSESSMENT.md.
- Detected pitch незалежний від expected exercise note; немає автоматичного виправлення помилок користувача.
- Одна довга нота не стає серією extra notes; повторні атаки однакової ноти розрізняються.
- DSP обмежує queue/memory і не виконується у UI/audio callback.

## Перевірка

Corpus у 44.1/48 kHz, C2–E6, низькі ноти/домінантна друга гармоніка, реальні струни, тиша, шум, clipping, повтори, октави. Записати median/p95 accuracy і latency, не лише один середній показник.

## Докази виконання

Реалізовано original MPM/YIN comparison, окремий energy/spectral-flux onset detector, stable pitch та quality evidence на єдиному PCM worker. Capture публікує bounded events/quality spans; не записує raw audio. Invalid packet time/format не маскується наступним добрим packet. Domain validateForPractice перевіряє C2–E6, resolved 55–1500 Hz та мінімум 200 ms, незалежно від display/history.

Перевірки: 71 core tests / 12 suites, 30 App tests / 8 suites; 243 en/uk keys без нових UI-рядків; generated project/UI source checks; native Debug/Release builds зі strict ad-hoc signature verification. Синтетичний selected-channel PCM проходить справжній C ring та той самий worker; це не hardware capture.

Full offline benchmark: 3 360 cases, MPM/YIN, обидва sample rates, усі MIDI 36–88, A4 400/440/480, duration matrix 125/200/300/500 ms, noise/gain/attack variants та негативні сигнали. 34 public acoustic clips мають provenance/hashes і незалежні оцінені annotations. Для MPM synthetic pitch p95 0.048 cents; recorded p95 7.301 cents, 99.05% усіх stable frames у ±15 cents; onset p95 13.22 ms у duration matrix / 30 ms на записах, resolved-note p95 100 / 160 ms. Два додаткові unstable transients на acoustic A2 лишаються явно порахованими extras. Усі software gates пройдено.

Деталі: [ADR 002](../docs/decisions/002-monophonic-analysis.md), [benchmark](../docs/benchmarks/12-audio-analysis.md), [local implementing-agent review](../docs/reviews/12-review.md). CI повторює 360-case regression, включно з усіма public clips. UI XCTest execution лишається U07; task 12 не додає UI flow.

U02/U04 відкриті до фінального кроку після всіх 22 реалізацій: held-out/live electric DI, фізичний tuner settling/onset, акустика/п’єзо/кімнатний шум. Опубліковані акустичні записи не закривають ці перевірки. Issue лишається відкритим, Project — In review.
