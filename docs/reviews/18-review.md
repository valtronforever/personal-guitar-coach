# Task 18 — локальний review

Review виконав той самий агент, що реалізував зміни. Це не незалежна перевірка. Обсяг: рекомендації, evidence links, comparison eligibility, native results/history/TAB, retry/tuning restoration, persistence та en/uk.

## Знайдені проблеми та виправлення

1. Початковий нейтральний повтор знижував BPM і скорочував range, тому наступна спроба не була б порівнюваною. Для нейтральної поради/restart збережено BPM і весь range; зниження застосовується тільки до повтору через виміряну помилку. Regression перевіряє нейтральний восьмитактовий випадок.
2. Пошук тільки чотиритактових вікон міг відкинути придатний коротший фрагмент через held event на межі. Перебираються всі легальні 1–4 такти без розрізання подій; counts і посилання обчислюються всередині конкретного вікна.
3. Окремі протилежні тенденції висоти могли дати два однакові recommendation IDs у SwiftUI ForEach. Tuner recommendation тепер не дублюється; порядок детермінований.
4. Перехід до тюнера з історії міг залишити поточний інший стрій. Кнопка явно спочатку вибирає archived pitches/A4; failure залишається видимим і не відкриває тюнер із неправильним профілем. Профіль відновлюється без перезапису новішої custom revision; це перевірено через реальний тимчасовий JSON repository.
5. Підготовлений/cached retry request міг повторно використати selection UUID при поверненні з практики. Кожне натискання створює fresh selection, скидає фізичне підтвердження та automatic repeat, зберігаючи exercise/range/BPM. Тест проходить два послідовні вибори та mismatch до capture.
6. Одночасне закриття result sheet і відкриття audio sheet створювало ризик конфлікту презентацій. Audio setup ставиться в pending state і відкривається через onDismiss. Native перевірка переходу включена в U07; source compilation не є її заміною.
7. Подія-пауза поза assessed range могла показати нуль observed attacks, хоча вона взагалі не оцінювалася. Тепер unassessed залишається окремим станом. Partial не отримує missing/pitch/timing performance markers.
8. Рекомендації й перевірка retry links для великого archive могли виконуватися під час body rendering. Підготовка винесена в detached task; скасований view не публікує стару відповідь.
9. Тест старого summary спочатку не передавав archived range, і валідатор коректно відхиляв невідповідний denominator. Fixture виправлено; product validator не послаблювався. Compiler помилки test harness (явні repository arguments / throwing expression) також виправлено.

## Перевірки

- Core regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/GuitarCoachCore` — **125 tests / 25 suites**, 48.903 s, один opt-in hardware test пропущено. DSP не змінювався; recorded assessment baseline лишився 18 graded / 14 uncertain extras із 32 onset-annotated clips.
- App regression: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` — **51 tests / 15 suites**, 10.565 s. Це state/repository/synthetic coordinator tests, не UI execution і не реальний guitar capture.
- Після review: focused `FeedbackTests` — **6 passed**, 0.013 s; `ResultFlowTests` — **4 passed**, 0.015 s. Пороги, протилежні/недостатні evidence, exact refs, minimum BPM, setup-only partial, version/route/calibration/source comparisons, archived A4, repeated retry і language-neutral history покриті.
- `python3 Scripts/generate_project.py --check` — passed; new App files включені в native target.
- `python3 Scripts/check_localizations.py` — **492 keys**, обидві мови та placeholders passed. Count templates використовують стійкі назви показників, не склеюють відмінювані речення.
- `python3 Scripts/check_ui_sources.py` — passed. Existing synthetic-results UI test також перевіряє новий detail screen; фактичне виконання потребує U07.
- `python3 Scripts/build_local.py --configuration debug` — локальна ad-hoc `.app` зібрана.
- `python3 Scripts/build_local.py --configuration release` — passed, 16.59 s, локальна ad-hoc `.app`.
- Фінальні project/localization/UI-source checks повторно passed; `git diff --check` — passed.

## Відкриті перевірки

Нативний computer-use знову повернув `Sky Computer Use native pipe closed before response` під час reconnect; наявність running process не доводить правильність нового UI. Layout/wrapping en/uk/light/dark, VoiceOver/keyboard, sheet handoff і user walkthrough лишаються U05/U07. Реальна гра з оцінками та рекомендаціями — U02/U03/U04/U10 після всіх 22 задач, як погоджено користувачем. Мікрофонний permission flow не запускався й не обходився. Після merge статус `pending_user`, issue відкритий, Project `In review`.

CI [34428325160](https://github.com/valtronforever/personal-guitar-coach/actions/runs/34428325160) пройшов на `3e2b06d`; PR #40 змерджено як `5c8284d`.
