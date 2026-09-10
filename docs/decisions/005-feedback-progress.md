# ADR 005 — Рекомендації та порівняння прогресу

Статус: реалізовано в задачі 18; native UI / реальна гра потребують фінальної U05/U07/U10.

## Незмінні виміри

`FeedbackEngine` у Learning читає `AssessedPractice`; не запускає DSP або повторне оцінювання. `feedback-1` — версія поточних детермінованих правил порад. Вона відображається окремо від збереженої версії scoring. Поради формуються під час читання з архівних вимірів, не видаються за збережений історичний текст порад. Переклади не входять у дані спроби.

Кожна `PracticeRecommendation` містить source attempt UUID, stable kind/action, expected event IDs / observed attack IDs, чисельник і знаменник evidence, цілі такти та BPM. Для setup посиланням є той самий immutable attempt: clipping count, uncertain event/extra count, stop reason або calibration capability. Немає висновків щодо фактично зіграної струни, пальця, руки, тривалості утримання чи причини відхилення.

## Пороги та вибір

| Правило | Мінімальна evidence / дія |
| --- | --- |
| Перевантаження / поганий сигнал | `insufficientSignal` дає тільки setup advice. Clipping intervals мають пріоритет; інакше uncertain counts / відсутній preflight signal. |
| Переривання | Partial дає тільки причину й setup, або нову спробу для pause/cancel/зміни керування. Часткові виміри не стають performance advice. |
| Калібрування | `uncalibrated` починає список із route calibration advice; pitch advice може йти далі. Timing advice недоступна. |
| Ранні / пізні атаки | ≥3 reliable matched errors за межами saved rhythm tolerance; один напрямок становить ≥75% timing errors вибраного фрагмента. |
| Пропуски | ≥2 unmatched expected notes, які не позначені uncertain, за придатної спроби. |
| Повторна помилка висоти | ≥2 reliable attacks для тієї самої цільової частоти з абсолютним відхиленням ≥50 cents. |
| Перевірка тюнером | ≥3 різні target frequencies з 20…<50 cents deviation; один знак становить ≥75% таких відхилень фрагмента. Причину не стверджуємо. |
| Паузи | ≥2 reliable extras, прив’язані до явних rests. Рахуємо атаки, а не тривалість звуку. |
| Нейтральний повтор | Якщо немає достатньої закономірності, пропонуємо повтор без твердження про опанування. |

Розглядаються всі допустимі вікна 1–4 цілих тактів у вибраній спробі: хоча б одна очікувана нота, без розрізання події на межі. Вибір: найбільша кількість evidence; за рівності — найраніший початок, потім найкоротший кінець. Для однакової кількості pitch groups — стабільний порядок event IDs. Нейтральний повтор завжди зберігає весь вихідний range для порівнюваності. Setup / перезапуск partial також зберігає весь range.

Пріоритет: setup/calibration → early → late → missed → repeated pitch → tuner → rests. Максимум три поради; tuner kind з’являється не більше одного разу (за кількох окремих протилежних тенденцій спочатку перевіряється від’ємний знак). Пороги застосовуються до конкретного вибраного вікна, а не до прихованого глобального знаменника. У UI можна розгорнути перелік усіх referenced events і перейти до їхніх вимірів.

Для повтору через помилку `max(minimumBPM, floor(currentBPM × 0.85 / 5) × 5)`. На мінімальному темпі не обіцяємо «повільніше». Нейтральний повтор і restart зберігають поточні BPM і range: зміна темпу не повинна заважати збиранню порівнюваних спроб.

## Історія та порівняння

Історія читає вже наявний versioned session envelope 2 / detailed assessment 1. Старі summary-only records показують початкові бали з поясненням відсутності per-event evidence, recommendations і comparison. Schema не змінюється. Очищення практики не змінює статус читання уроку.

`PracticeComparison` вимагає рівності full exercise, tuning profile (включно з ID/revision/A4), source, BPM, range, count-in, audio route, calibration profile, capability/analysis/scoring versions і rhythm capability/tolerance. Орієнтація грифа і мова не впливають. Це свідомо консервативне порівняння: нове калібрування або перейменований профіль починають іншу групу.

Overall порівнюється лише між `valid`, pitch-only — між `uncalibrated` з тими самими умовами. Insufficient / interrupted не мають ranking. Previous — остання раніша спроба з іншою UUID; best — максимальний збережений бал у сумісній групі (включно з поточною), без rerating. Ties стабільні за датою та UUID. За відсутності ранішої сумісної спроби UI пояснює, чому порівняння не показано.

## UI та повтор

Результат показує frozen conditions, eligibility/reason, summary, recommendations, read-only TAB annotations і виміри вибраної події. Позначки мають різні SF Symbols, легенду та accessibility hint; колір не є єдиним носієм значення. `Matched` означає зіставлену атаку, а не ідеальну гру. Pitch marker починається від 15 cents (scoring formula залишається 50); early/late потребують valid rhythm і saved tolerance. Partial не отримує missing/pitch/timing performance flags. Непозначені події поза range не оцінювалися. Деталі можуть показати кілька вимірів, навіть коли TAB має один пріоритетний символ.

History називає урок поточною мовою лише за збігом archived lesson ID/version; інакше показує Saved exercise та точну версію в detail. View result зупиняє automatic repeat перед відкриттям. Retry передає повний збережений Exercise, lesson reference, range/BPM і tuning; нова selection UUID скидає підтвердження строю навіть для повторного натискання тієї самої поради. Відкриття не запускає capture або метроном. Перед новою спробою перевіряються актуальні DSP limits.

Вибрані фізичні pitches/A4 мають збігтися з archived target до capture. Вправа `followsInstrument` не переписується у fixed з тією самою версією: нова retry configuration явно використовує archived target profile, поточні source/orientation. Відновлення строю вибирає вже наявний профіль з цими pitches або створює копію з новим ID/revision 1; старіші snapshots не перезаписують новіші custom revisions. Тюнер із результату явно спочатку вибирає saved tuning; помилка збереження не веде до тюнера з неправильним строєм. Після фізичного налаштування все одно потрібне звичайне підтвердження та preflight.

## Перевірки та межі

`FeedbackTests`: threshold negatives/positives, direction fraction, minimum BPM, precise references/counts, setup-only partial, deterministic cap, compatibility and immutable versions. `ResultFlowTests`: result→retry snapshot/range/BPM, fresh selection, tuning mismatch before capture, non-destructive archived A4 restore, persistence reload, bilingual title resolution and annotation validity. Core/App regression suites, String Catalog validation, UI-test source compilation та Debug/Release builds — software evidence. Вони не закривають фізичні U02/U03/U04/U10 чи native VoiceOver / layout U07.
