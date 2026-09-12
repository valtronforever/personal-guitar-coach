# Контракт аудіо та оцінювання

Це проєктні вимоги та початкові параметри, а не виміряні характеристики готового застосунку. Числові пороги потрібно перевірити в задачах 02, 12, 15 і 17, після чого зафіксувати версію параметрів. Зміна порога потребує evidence, а не підгонки під одну демонстрацію.

## Вхід та підтримуваний сигнал

- Основний сценарій: чиста гітара → instrument/Hi-Z input USB-інтерфейсу → один вибраний канал. Не додавати distortion, reverb, backing track або software monitoring у сигнал аналізу.
- Перша ціль DSP: C2–E6, приблизно 65–1319 Hz. Власний стрій може містити інші ноти, але вправи поза перевіреним діапазоном мають явне обмеження оцінювання; тюнер показує out-of-range замість випадкової ноти.
- Перевірити фактичні 44.1 і 48 kHz, різні доступні buffer sizes і багатоканальний input. Не припускати 48 kHz або stereo. Unsupported format пояснюється до старту.
- Рівень: RMS/peak, clipping indicator, silence/noise estimate. Hardware gain не завжди керується через API; показувати інструкцію повернути ручку gain, якщо контроль недоступний.
- Permission: localized `NSMicrophoneUsageDescription`, відповідний audio-input entitlement для sandbox/hardened configuration, обробка authorized/denied/restricted/notDetermined. Перевірити поведінку під обраним SDK у реальному app bundle.
- Пристрій зберігається за UID, не ephemeral AudioDeviceID. Зниклий пристрій не підміняти мовчки вбудованим мікрофоном посеред оцінювання.

## Обробка

```text
input callback + timestamps
  → preallocated bounded PCM buffer
  → selected channel / format conversion
  → level + noise + clipping evidence
  → onset detection + monophonic pitch detection
  → timestamped note events + confidence
  → alignment with expected exercise events
  → validity / metrics / advice
```

Audio callback лише копіює потрібні дані й timestamps у заздалегідь виділену пам'ять. На окремому worker виконуються conversion/DSP. Переповнення буфера позначається як data loss; не блокувати render thread. UI отримує агреговані результати з обмеженою частотою, орієнтовно 20–30 Hz.

У задачі 12 порівняти придатні monophonic алгоритми, наприклад YIN та autocorrelation. Не використовувати найбільший FFT bin як єдину оцінку висоти гітари. Врахувати домінантні гармоніки, низькі ноти, початковий transient, згасання та стрибки октави.

Pitch frame не дорівнює зіграній ноті. Onset detector окремо знаходить атаки, включно з повторними ударами тієї самої висоти. Sustain не має породжувати багато «зайвих нот». Pitch визначається у стабільному фрагменті після атаки; timestamp атаки не переноситься на кінець pitch window.

Не «підтягувати» розпізнану ноту до очікуваної заради кращої оцінки. Tuner може обмежувати пошук вибраною струною, але practice зберігає незалежну оцінку та uncertainty. Одночасні струни й перевантажений сигнал не трактуються як надійна monophonic evidence.

## Час та метроном

- Джерело transport time — audio/host clock. Click buffers плануються наперед; UI cursor читає transport. SwiftUI animation або Timer не визначає реальний момент кліку.
- Перетворення: `seconds = ticks / PPQ × 60 / BPM`, PPQ = 960. Кожна спроба фіксує BPM, time signature, start epoch та loop range.
- Sample time завжди належить конкретному потоку та sample rate. Для порівняння input/output використовувати нормалізований host-time mapping; окремі пристрої можуть мати clock drift.
- Expected event time враховує момент, коли клік доходить до виходу; observed time — оцінку моменту вхідної атаки. Точну семантику timestamps обраного бекенда описати в ADR задачі 02 і калібруванні задачі 15.
- Відлік не оцінюється. Guard intervals до/після вправи визначені явно; затримані samples фіналізуються перед обчисленням результату, щоб не загубити останню ноту.

## Калібрування

Calibration profile прив'язаний до input UID/channel, output UID/channel, actual sample rate, buffer configuration та версії бекенда. Route/config change робить профіль застарілим. Report зберігає використаний offset і його uncertainty.

Базова оцінка затримки отримується з доступних hardware/stream latency values, з документованою семантикою. Точне end-to-end вимірювання — керований loopback test за наявності відповідного маршруту/кабелю; воно не вимагається для читання уроків і тюнера. Немає loopback — показати estimated status і доступний ручний offset. Ручне підлаштування людиною не називати апаратно точним вимірюванням.

Домовленість: `timingError = observedNormalizedTime − expectedNormalizedTime − residualOffset`. Додатна помилка означає «пізно». Якщо hardware latency вже врахована в normalized timestamps, не віднімати її вдруге. Тести включають відомі +50 ms і −50 ms, а не лише нуль.

Якщо uncertainty більша за половину rhythm tolerance, rhythm metric та загальна оцінка недоступні; можна показати pitch-only feedback із причиною. Оціночна або ручна компенсація допускається для повної оцінки лише з валідованою межею uncertainty. Довга сесія з різними пристроями перевіряється на drift; неперевірені маршрути не оголошуються підтримуваними.

## Стани практики

`idle → preflight → countIn → running → finalizing → completed`

Відгалуження: `preflightFailed`, `paused`, `interrupted`, `cancelled`. Pause/seek/tempo change закриває attempt як partial без загальної оцінки. Resume/retry створює новий attempt і відлік. Повтор loop автоматично створює окрему оцінювану спробу для кожного завершеного кола.

Preflight перевіряє permission, route/channel, валідний формат, тестовий сигнал, відповідність строю, підтримку темпу/нот і статус калібрування. Фізичний стрій підтверджується користувачем після тюнера; сам вибір профілю цього не доводить.

Hot-unplug, sleep/wake, зміна маршруту, критична втрата buffers переривають спробу. Якщо користувач після успішного preflight просто не зіграв ноти, а capture справно працював, це пропуски. Якщо тестовий сигнал узагалі не підтверджено або stream зник, це проблема входу, а не нуль за вміння.

## Зіставлення подій

Зіставляти очікувані ноти з observed onsets один-до-одного, зберігаючи порядок; використовувати bounded alignment із ціною пропуску та вставки. Matching ґрунтується на часі й послідовності, а не лише на pitch: неправильно зіграна нота залишається кандидатом своєї очікуваної позиції. Сусідня правильна нота не повинна «лікувати» попередню помилку.

Match window ширше rhythm tolerance, але обмежене темпом та сусідніми подіями; конкретні параметри визначити й версіонувати в задачі 17. Одна атака не задовольняє дві очікувані ноти. Ноти після завершального guard interval не належать спробі. Атаки на паузах — зайві. Tied notes поки не підтримуються, а sustain однієї ноти не потребує повторної атаки.

## Початкова модель оцінки

Наведена формула є стартовою специфікацією для перевірки на annotated fixtures. Оцінюється висота й час атаки; тривалість утримання показується як допоміжний показник тільки за надійного offset detection і не входить у MVP score.

Для `N` очікуваних нот (без пауз):

- Matched event: `p_i = max(0, 1 − abs(centsError) / 50)`. Cents error рахується від **цільової частоти**, а не від найближчої розпізнаної ноти. Помилка на півтон/октаву дає 0.
- `r_i = max(0, 1 − abs(timingErrorMs) / rhythmToleranceMs)`.
- Missed event: `p_i = 0`, `r_i = 0`.
- `P = sum(p_i) / N`, `R = sum(r_i) / N`.
- `extraRatio = extraOnsets / (N + extraOnsets)`.
- `score = round(clamp(100 × (0.6 × P + 0.4 × R) − 20 × extraRatio, 0, 100))`.

Початковий rhythm tolerance: 100 ms, не більше 45% найкоротшого інтервалу між очікуваними атаками у вправі; для одиночної ноти — 100 ms. У задачах 12/17 підтвердити допустимі комбінації pitch/BPM/duration, щоб tolerance не ставав меншим за реальну точність аналізатора. Відхилення за межами допуску не прирівнювати до недостатньої якості сигналу.

`N = 0` — помилка контенту для оцінюваної вправи, не ділення на нуль. Однаково гучні ноти не дають бонусів. Perfect fixture = 100; healthy all-missed fixture = 0; системна затримка після коректної компенсації не знижує результат.

Confidence невизначених подій не можна використовувати для прихованого видалення складних нот зі знаменника. Попереднє правило: якщо понад 20% очікуваних нот пов'язані з неоднозначним/зіпсованим сигналом або критичні capture gaps перетинають вправу, overall score недоступний. При меншій кількості uncertain events показати неповноту й консервативний результат із цими подіями як 0; їх не використовувати для тверджень про техніку. Остаточну політику валідності перевірити й зафіксувати у задачі 17.

Результат завжди містить статус валідності, denominator, кількість matched/missed/extra/uncertain, середнє/медіанне signed timing error, pitch deviation та версію параметрів. Порівнювати спроби лише з однаковими exercise version, tuning, BPM, range та scoring version; інакше позначати різницю умов.

## Рекомендації

Правила мають поріг мінімальної evidence та посилання на фактичні події:

- Стабільно пізні/ранні атаки за надійного калібрування → повтор короткого фрагмента повільніше.
- Повторна помилка конкретної висоти → показати очікувану ноту/аплікатуру та запропонувати повтор.
- Стійке відхилення висоти кількох нот → запропонувати перевірку тюнером, не стверджувати причину.
- Зайві атаки на паузах → вправа на зупинку звуку/ритмічні паузи, із прикладом такту.
- Недостатній або clipped input → рекомендація налаштувати сигнал; це не порада про виконавську майстерність.

## Цілі вимірювань

Ці пороги — acceptance targets для перевірених умов, не маркетингові гарантії:

| Перевірка | Початкова ціль |
| --- | --- |
| Synthetic stable pitch C2–E6 | median absolute error ≤ 5 cents, p95 ≤ 10 cents після settling |
| Clean recorded sustained notes | ≥ 95% стабільних voiced frames у межах ±15 cents на розміченому corpus |
| Tuner settle | p95 ≤ 300 ms після стабільної атаки; silence не дає «in tune» |
| Offline onset timing | median absolute error ≤ 15 ms, p95 ≤ 30 ms на корпусі з відомими атаками |
| Metronome scheduling | offline intervals у межах одного sample; hardware jitter виміряти окремо |
| Calibrated route | residual error p95 ≤ 20 ms на loopback; інакше уточнити rhythm capability |
| Тривала сесія | 15 хвилин на baseline Mac/USB route без втрачених buffers та необмеженого росту пам'яті |

Corpus включає 44.1/48 kHz, Standard/Drop D/D Standard, низькі/високі ноти, тихі/гучні атаки, повтори однієї ноти, sustain, паузи, шум, dominant harmonics, clipping, помилки октави, контрольовану затримку та негативний polyphonic приклад. Реальні записи мають labels і provenance; самі лише синусоїди не закривають точність на гітарі.


## Реалізація задачі 12

Алгоритм `mono-mpm-flux-1` і software capability `mono-capability-1` описані в [ADR 002](decisions/002-monophonic-analysis.md). [Повний benchmark](benchmarks/12-audio-analysis.md) містить 3 360 сценаріїв, coverage, median/p95, onsets/misses/extras і processing cost. Додано 34 public acoustic clips із hashes, provenance та оціненими pitch/onset annotations. Це development corpus, не заміна U02/U04 з реальною електрогітарою/п’єзо/кімнатним мікрофоном.

Поточне оцінювання дозволене для C2–E6, resolved 55–1500 Hz, note duration ≥200 ms і input 44.1/48 kHz. Quarter: 40–200 BPM; eighth: ≤150 BPM; sixteenth: ≤75 BPM. A4 обчислюється зі snapshot строю. 125 ms перевіряється як позамежовий випадок і не дозволяється для grading. Ці межі не змінюють playback/visualization і не дають дозволу на rhythm score без калібрування.

Між стартом capture і першою оцінюваною атакою має бути щонайменше 80 ms для causal onset history; звичайний preflight/count-in забезпечує більший запас. Немає reliable estimate — немає підстав називати звук правильною нотою. Capture quality spans та monotonically increasing event IDs треба споживати без пропусків; 128 events / 256 spans — rolling bounds, не сховище всієї спроби.


## Реалізація циклу практики (задача 16)

Snapshot обмежений 1024 очікуваними нотами, 900 s та 2048 observed attacks; collector також обмежує clipped intervals до 4096. Межі фрагмента — цілі такти, крім кінця останнього неповного такту вправи. Відлік — один такт у UI; Domain допускає 1–4. Тестовий сигнал має бути свіжим, reliable ≥200 ms за DSP frame time, без clipping/data loss; preflight timeout — 10 s. Підтверджений фізичний стрій не виводиться з автоматичної pitch detection.

Нормалізовані атаки після віднімання зафіксованого residual потрапляють у `[expectedStart − 0.100, expectedEnd + 0.100)`. Це явний guard для ранньої першої/пізньої останньої атаки; інші count-in та post-exercise атаки виключено. Після output completion capture триває щонайменше 1.4 s + відому input hardware latency. Додатково потрібен analyzer watermark за `expectedEnd + 0.100 + 0.300` після компенсації residual. Без watermark або здорового потоку результат перерваний, а не передчасно completed.

Кожен repeat має нові attempt/transport UUID, порожні observation arrays, власний render epoch і count-in; input lease зберігається лише доки потік справний. Між колами є пауза на фіналізацію. Input clock baseline береться з analyzer origin (host − frame/rate) початкового capture: попередній preflight або repeat drift не обнуляється зі стартом нового вихідного сегмента. Regression перевіряє збереження 30 ms, потім 60 ms накопиченого drift. Максимальний drift або втрата валідного clock evidence передаються задачі 17 для rhythm gate.


## Реалізація оцінювання (задача 17)

Контракт `monophonic-assessment-1`, конкретні match/quality windows, формула, persistence та перевірки визначені в [ADR 004](decisions/004-assessment.md). Bounded DP не використовує pitch для вибору відповідності; кожна eligible атака зберігається як match або extra. Перевантаження та тривалі non-silent uncertain spans відрізняються від справної тиші. Невизначені очікувані ноти та додаткові атаки враховуються у quality gate; приховано видаляти їх не можна.

Event pitch тепер має версію `mono-mpm-flux-2`: п’ять підтверджених post-onset estimates, медіанна частота, незмінний onset timestamp і timeout 300 ms. Live display й оцінка події мають різні вимоги до стабільності. Попередні route profiles не підходять до нового backend version автоматично. Старі збережені оцінки лишаються зі своїми analysis/scoring versions і не перераховуються.

Follow-up 2026-09-12: analyzer `mono-mpm-flux-3` accepts observations down to one semitone below 55 Hz (about 51.913 Hz), so the Drop A target A1/55 Hz can be approached from flat and does not oscillate out-of-range due to estimator precision. Target range remains 55–1500 Hz and grading remains MIDI C2–E6; measured frequencies are not snapped. Synthetic tuner checks cover A1 at −75/−25/0/+25/+75 cents in 44.1/48 kHz and reject 50 Hz. Physical low-string validation remains pending.
