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

Поточний UI має [два незалежні налаштування](PERSONAL-SYNCHRONIZATION.md): вихід (типово 0 мс, необов’язкові 16 натискань під метроном без аудіовходу) та інструмент (окремі 16 нот після перевірки сигналу). Для оцінювання зберігається сума зсуву виходу й залишкового зсуву інструменту; вона застосовується один раз. Для курсора використовується лише зсув виходу. Зміна виходу потребує повторного вимірювання інструменту. Метод `personal` включає особистий таймінг людини й залишається приблизним. Кабельного сценарію немає; старі профілі й історія читаються без перерахунку.

Домовленість: `timingError = observedNormalizedTime − expectedNormalizedTime − residualOffset`. Додатна помилка означає «пізно». Якщо hardware latency вже врахована в normalized timestamps, не віднімати її вдруге. Тести включають відомі +50 ms і −50 ms, а не лише нуль.

Якщо allowance більший за половину rhythm tolerance, rhythm metric та загальна оцінка недоступні. Personal mode у scoring v2 має максимум ±200 ms (також обмежений інтервалами нот) та явний `approximate` статус; measured — попередні ±100 ms і duration gate. Allowance персонального режиму характеризує повторюваність, не абсолютну точність. Legacy manual/estimated профілі самі по собі не відкривають rhythm score. За прямим вибором користувача новий `manualPersonal` дозволяє приблизний rhythm score з позначкою «Ручне налаштування», валідним сигналом і live clocks; allowance 50 мс є політикою оцінювання, а не виміряною точністю. Зміна аудіосеансу/маршруту або інструменту потребує повторного майстра. Збережений зсув фіксується до початку практики; помилки уроку його не змінюють.

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

Поточне оцінювання дозволене для A1–E6, resolved 55–1500 Hz, note duration ≥200 ms і input 44.1/48 kHz. Quarter: 40–200 BPM; eighth: ≤150 BPM; sixteenth: ≤75 BPM. A4 обчислюється зі snapshot строю. 125 ms перевіряється як позамежовий випадок і не дозволяється для grading. Ці межі не змінюють playback/visualization і не дають дозволу на rhythm score без калібрування.

Між стартом capture і першою оцінюваною атакою має бути щонайменше 80 ms для causal onset history; звичайний preflight/count-in забезпечує більший запас. Немає reliable estimate — немає підстав називати звук правильною нотою. Capture quality spans та monotonically increasing event IDs треба споживати без пропусків; 128 events / 256 spans — rolling bounds, не сховище всієї спроби.


## Реалізація циклу практики (задача 16)

Snapshot обмежений 1024 очікуваними нотами, 900 s та 2048 observed attacks; collector також обмежує clipped intervals до 4096. Межі фрагмента — цілі такти, крім кінця останнього неповного такту вправи. Відлік — один такт у UI; Domain допускає 1–4. Тестовий сигнал має бути свіжим, reliable ≥200 ms за DSP frame time, без clipping/data loss; preflight timeout — 10 s. Підтверджений фізичний стрій не виводиться з автоматичної pitch detection.

Нормалізовані атаки після віднімання зафіксованого residual потрапляють у `[expectedStart − 0.100, expectedEnd + 0.100)`. Це явний guard для ранньої першої/пізньої останньої атаки; інші count-in та post-exercise атаки виключено. Після output completion capture триває щонайменше 1.4 s + відому input hardware latency. Додатково потрібен analyzer watermark за `expectedEnd + 0.100 + 0.300` після компенсації residual. Без watermark або здорового потоку результат перерваний, а не передчасно completed.

Кожен repeat має нові attempt/transport UUID, порожні observation arrays, власний render epoch і count-in; input lease зберігається лише доки потік справний. Між колами є пауза на фіналізацію. Input clock baseline береться з analyzer origin (host − frame/rate) початкового capture: попередній preflight або repeat drift не обнуляється зі стартом нового вихідного сегмента. Regression перевіряє збереження 30 ms, потім 60 ms накопиченого drift. Максимальний drift або втрата валідного clock evidence передаються задачі 17 для rhythm gate.


## Реалізація оцінювання (задача 17)

Контракт `monophonic-assessment-1`, конкретні match/quality windows, формула, persistence та перевірки визначені в [ADR 004](decisions/004-assessment.md). Bounded DP не використовує pitch для вибору відповідності; кожна eligible атака зберігається як match або extra. Перевантаження та тривалі non-silent uncertain spans відрізняються від справної тиші. Невизначені очікувані ноти та додаткові атаки враховуються у quality gate; приховано видаляти їх не можна.

Event pitch тепер має версію `mono-mpm-flux-2`: п’ять підтверджених post-onset estimates, медіанна частота, незмінний onset timestamp і timeout 300 ms. Live display й оцінка події мають різні вимоги до стабільності. Попередні route profiles не підходять до нового backend version автоматично. Старі збережені оцінки лишаються зі своїми analysis/scoring versions і не перераховуються.

Follow-up 2026-09-12: analyzer `mono-mpm-flux-3` accepts observations down to one semitone below 55 Hz (about 51.913 Hz), so the Drop A target A1/55 Hz can be approached from flat and does not oscillate out-of-range due to estimator precision. Target range remains 55–1500 Hz and grading remains MIDI C2–E6; measured frequencies are not snapped. Synthetic tuner checks cover A1 at −75/−25/0/+25/+75 cents in 44.1/48 kHz and reject 50 Hz. Physical low-string validation remains pending.

## Opt-in recording for AI advice

The Record & analyze action records exactly one bounded practice take via the existing PCM reader. Channel 1 is clean selected input; WAV channel 2 is the scheduled metronome reference aligned by render/capture host time. It does not measure actual headphone output or solve Bluetooth latency. Imported WAV/MP3 has unverified correspondence/start alignment. Offline audio measurements and the immutable lesson/assessment snapshot feed the optional local CLI coach. AI prose cannot update numeric assessment or invent evidence. See [the audio-file contract](AUDIO-AGENT-COACH.md) for privacy, bounds, XPC privileges and retention.

## Input-level display guidance

Audio setup, personal synchronization and practice preflight share a −60…0 dBFS peak meter with RMS readout. Zones are presentation guidance: weak below −30 dBFS, working from −30 to below −6 dBFS, high from −6 dBFS, and overload at the existing 0.995 peak-amplitude guard (about −0.044 dBFS). These gain guides apply while plucking, not to pauses or note decay; they do not change DSP silence/quiet thresholds, pitch confidence or calibration eligibility. Stopped/missing/invalid capture never displays a live working-level status. English/Ukrainian text and symbols supplement colored zones.

## Practice score display

Practice TAB uses a continuous fractional display coordinate from the existing transport sample count, with the same bounded reported-output-latency subtraction. One visual count-in bar precedes the selected range (three beats in 3/4, four in 4/4); it adds no exercise/assessment events. SwiftUI interpolates incoming cursor positions over 55 ms and scrolls wrapped rows over 400 ms. These are display animations, never audio clocks or timing evidence. Personal input/player compensation is not applied as an output-only offset; unknown Bluetooth latency remains unknown. Stopped/stale transport data cannot autonomously advance the cursor.

Follow-up 2026-09-16: `mono-mpm-flux-4` / `mono-capability-2` expands graded targets to A1–E6 while retaining actual 55–1500 Hz, ≥200 ms and 44.1/48 kHz gates. The onset background excludes the latest two 10 ms hops, avoiding a broad low-note transient raising its own threshold. The [4,476-case regression](benchmarks/low-register-audio.json) includes 540 MPM repeated-low-note cases (2,160 attacks, zero misses/extras), sustained-note and recorded-corpus checks. A1 at A4=400 is below 55 Hz and remains unsupported. Analyzer identity participates in route calibration identity; previous calibration cannot silently become valid for v4. Historical evidence remains readable without rescoring. Real instrument validation remains U02/U04.

## Opt-in sustained-note coverage (rhythm extension)

`mono-capability-3` adds the author flag `assessSustain` and a ≥0.5 s gate for marked notes. Attack analysis remains `mono-mpm-flux-4`; ordinary ≥0.2 s targets and calibration identity are unchanged. A separate `sustain-window-center-1` derived trace samples at 50 Hz after the 4096-sample window is filled. Its timestamp is the window center, converted through the input route exactly once. Reliable stable estimates carry pitch; clipping/invalid/ambiguous frames remain uncertain. Silence uses a 20 ms raw-input neighborhood at the same center with local DC removal (RMS <0.001), avoiding the high-pass filter's release tail being mistaken for continuing sound. The worker holds at most 512 frames; only marked practice collects up to 45,100 frames. Lost prefixes, noncontiguous IDs/times and overflow interrupt rather than manufacture coverage. No additional work is performed in the capture callback; no waveform is persisted by this feature.

`sustain-assessment-1` evaluates from the matched observed attack +200 ms through the written duration −50 ms. Missing attacks use the expected time plus the archived compensation. Input/player offset is never subtracted twice. Target pitch within ±50 cents counts as held; measured silence is reported separately. Unknown coverage above 20% makes the attempt `insufficientSignal`, with no success scores. Known wrong pitch does not count as silence. These settling/release allowances mean this metric is NOT exact note-off timing. At the shortest allowed target, release ambiguity can prevent grading: a synthetic 0.5 s A1 target stopped at 0.25 s at 48 kHz has 24% uncertain coverage and is intentionally withheld, not relabeled a playing mistake.

`monophonic-assessment-3` retains existing attack matching and rhythm eligibility. With marked notes, the pre-extra-penalty aggregate is 80% existing attack score +20% sustain coverage; with no marked notes it is unchanged. Sustain can be shown with uncalibrated rhythm, but overall/timing scores remain unavailable. Interrupted attempts have no aggregate sustain score. `feedback-2` can recommend complete-note fragments for inadequate coverage. Result annotations distinguish sustain problems from correct attacks. Versions 1/2 and unmarked events remain readable; default-false flags are omitted during encoding to preserve archived coach digests. Historical results are never recomputed.

Palm-muted reference cues are display-only: the 90 ms synthetic decay illustrates short versus ringing sound, not real instrument timbre. Neither palm placement nor muted-note correctness is scored. A separate clean unmuted exercise is required for monophonic graded practice. The practice renderer still excludes reference guitar tones.

## Moving pitch and bend assessment

`periodic-window-center-1` shares the 4096-sample window and 50 Hz frame clock with sustain, but its pitched state requires a valid periodic estimate rather than a stable note. Existing `mono-mpm-flux-4` attack and stable-sustain outputs are unchanged. The new worker trace has a 512-frame bound; a bend-marked attempt collects up to 45,100 frames, using the same monotonic-ID/cadence/lost-prefix interruption rules and a single input-route clock conversion. No second capture pipeline, callback allocation or automatic waveform recording is added.

`bend-capability-1` gates starting frequencies 195.9–880 Hz, targets ≤1100 Hz, phases ≥0.4 s and speed ≤400 cents/s at the selected tempo. `bend-assessment-1` compares the audible trajectory with linear-in-cents rise/hold/release segments, within ±35 cents. Initial 200 ms settling and 60 ms on both sides of later boundaries are excluded; 60 ms exceeds half the longest detector window. Plateau/ramp boundary blending is not presented as instantaneous pitch accuracy. Unknown coverage >20% in any phase withholds the aggregate bend/attempt score. Known silence and wrong pitch are measured misses, distinct from unreliable input.

The curve is aligned to the matched observed attack, falling back to the expected attack plus archived offset. A +120 ms route/player correction plus a +70 ms late attack is tested without double subtraction. Bend-internal spectral-flux observations (from rise −60 ms to note end on that same observed clock) remain in evidence but are excluded from extra-attack penalties, uncertainty counts, rest feedback and saved summary counts. Sound cannot prove whether the player repicked during that interval. Outside the interval, ordinary extras still count.

New bend attempts select `monophonic-assessment-4`; ordinary attempts keep v3 and old canonical encoding. Each bend phase has equal weight, each bend note has equal weight, then bend and ordinary attack/rhythm scores combine 50/50 before extras; optional sustain subsequently keeps its established 80/20 weighting. All parameter/evidence/assessment versions are frozen in saved history, never recomputed on read. The trace, phase metrics and positive/negative pitch error remain available for diagnosis. `feedback-3` identifies measured bend-path deviations without assigning a physical cause.

Synthetic coverage includes clean harmonic rise/hold/return at G3/C4/A4/A5 at 44.1/48 kHz, incorrect target/absent return, silence/noise/clipping, target-window uncertainty, and trace loss. Native route and real guitar checks remain pending_user. Exploratory 2/4 Hz vibrato probes are not a vibrato grading contract.

Triplet/shuffle authoring retains actual onset/duration ticks (320 per eighth-note triplet slot; 640+320 for the initial shuffle pair). The 3:2 grouping affects notation only. Quarter-note metronome BPM/count-in, sample scheduling, shared host-time conversion and assessment algorithms are unchanged. Synthetic repeated clean notes at 44.1/48 kHz traverse analyzer → collector → matcher with all twelve triplet/eight shuffle attacks matched and no extras; this is not real-guitar evidence or an assessment of all swing styles. Dynamic accents and sustain length remain separate contracts.

Metronome-omission extension: the immutable exercise may identify omitted quarter-click onsets. `TransportPlan` caches them before rendering and skips only those scheduled clicks in preview/practice. The absolute audio clock, count-in, note targets, cursor, onset collection, matching and algorithm/calibration identities are unchanged. Source coordinates preserve omissions through seek/repeat. Recorded channel 2 is reconstructed from the same plan, including deliberate silence; channel 1 is untouched. Silence in the reference is not absent instrument evidence. New gapped AI requests use `file-coach-3`; historical ordinary/bend versions and digests remain valid. Real internal-pulse performance still needs user evidence, and audio cannot establish whether the player watched the visual cursor.

Meter/pulse extension: 3/4/4/4/5/4 BPM counts 960-tick quarters, 6/8/12/8 counts 1440-tick dotted quarters, and 7/8 counts 480-tick eighths. All event ticks remain PPQ 960. Transport converts absolute ticks with the frozen pulse; session/count-in durations, expected attacks, sustain/bend timing and duration capability use the same conversion. Grouped accents and authored omissions affect reference click sound only. Sample-rate/route compensation is still applied once, with no new capture or DSP clock. Count-in display now uses half-sample rounding consistent with the click schedule, fixing occasional previous-beat labels at rounded boundaries. Calibration probe event scheduling is unchanged. Old 3/4/4/4 timing, assessment parameters and canonical defaults remain intact; new signature/group information is frozen in each attempt and sent under coach prompt version 4 when applicable.

## Authored slide / legato phases

Optional `MusicalEvent.pitchTransition` uses the existing periodic pitch contour and bounded PracticeEvidenceCollector; it adds no capture pipeline or callback work. Both endpoint frets resolve in Domain. Preview integrates the frequency multiplier from the source onset, including seeks and loops; practice output contains no reference guitar tone.

Transition attempts use `mono-capability-4`, `monophonic-assessment-5`, `pitch-transition-assessment-1` and `pitch-transition-capability-1`. Ordinary attempts retain their previous parameter/capability versions; bend-only attempts retain assessment 4. New result fields are optional and absent fields remain absent in canonical encoding. History is decoded without rescoring. Feedback rules are `feedback-4`; the local agent request uses `file-coach-5` and explicit unscored transition observation IDs.

An initial attack contributes pitch/rhythm points as before. With moving-pitch notes, half of the pre-sustain score is the attack score and half is the mean per-note bend/transition score. Mixed bend/transition phrases weight each moving note equally. Any sustain component is then combined using the existing 80/20 rule. Extra-attack penalties use only scored observations. Unsupported or unknown phase evidence withholds aggregate grades; silence within otherwise reliable evidence remains a measured mismatch. Calibration is applied once to initial matching; phase windows align to the observed initial onset, with expected-onset fallback.

The transition envelope, guards and intermediate-fret rule are documented in CONTENT-AUTHORING.md. A one-fret slide has no intermediate-fret proof, and even a complete audible trajectory cannot prove the physical gesture. Hardware acceptance for guitar transients, weak targets, gain and Bluetooth routes remains open.

## Vibrato width/rate assessment, version 1

`vibrato-capability-1` uses the existing periodic pitch contour, with no new capture pipeline/callback work. A prepared 1024-segment cumulative waveform table per distinct depth supplies a continuous integrated reference phase; rendering shares tables and uses constant-time interpolation. Chunking, seek, loop and all six meters are tested independently of the synthetic input fixtures.

`vibrato-assessment-1` records base/modulation/returned phases and robust modulation statistics: 5th/95th percentile width, lower pitch, median cycle rate, slowest/fastest cycle rates, largest period deviation relative to the median, and number of measured periods. Hysteresis crossings use 20%/80% of the measured span. Silent/uncertain frames break period continuity. A known flat tone has no measured cycles and fails modulation; missing or uncertain contour is a separate signal state. Above 20% unknown in any phase withholds the vibrato score. Base/return coverage uses±35 cents; modulation requires lower pitch±20 cents, width±max(10 cents, 25%), each measured cycle's rate within ±20% target, and maximum period variation≤20%. Exact phase relative to the reference is ungraded. At least two complete measured intervals are required. Stable and modulation coverage are weighted by elapsed frame intervals.

The event's observed initial attack anchors all phases; the saved calibration offset is applied once to initial rhythm matching. Internal spectral flux remains archived but is excluded from extra-attack penalties during modulation through the end of the event. This cannot verify absence of repicking. `monophonic-assessment-6` and `mono-capability-5` apply only when selected events include vibrato. New optional result fields preserve older encoding/grades. Mixed moving-note results use the per-note mean before the existing50/50 attack/motion and80/20 sustain combination. `file-coach-6` carries explicit expected width/rate/ticks and separate unscored vibrato observation IDs, with strict response validation. Prompt text prohibits inferred gestures or a claim of listening merely from a supplied file path.

Independent harmonic PCM passed at 44.1/48kHz, G3/A5, 30/100 cents, 1/3 Hz and 0.4 s boundary plateaus. Wrong width/rate/base, flat pitch, healthy silence, noise and clipping are tested separately. Synthetic evidence does not establish real-guitar performance; hardware validation remains open.
