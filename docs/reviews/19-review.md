# Task 19 — локальний review

Review виконав той самий агент, що підготував курс; незалежний викладацький або native візуальний review не заявляється. Обсяг: усі en/uk тексти, pitches/fingerings, timing, step references, tuning/capability, course → result/retry та version semantics.

## Знайдені проблеми й виправлення

1. Початкова перевірка прирівнювала список маркерів грифа до всіх повторних подій. Гриф правильно показує одну позицію для повтореної ноти, але TAB/scoring повинні зберігати кожну атаку. Тест виправлено: множина позицій + точна послідовність event IDs; жодні повторні ноти не видалені з музичної моделі.
2. Англійська підказка для пентатоніки називала першу позицію на струні «first-fret position at fret 5», що могло заплутати після уроку ладу 1. Переписано однозначно: кожна струна починається з ладу 5. Українські назви гам локалізовано повністю, залишивши A–G для pitch names.
3. Назви acoustic source options у вступі не збігалися з фактичним UI. Тексти звірено з обома String Catalog translations і виправлено.
4. Розширення вступу без зміни lesson version могло б лишити новий матеріал позначеним прочитаним. Lesson підвищено до 2, translations оновлено разом; exercise лишився 1, бо ноти/час/стрій не змінювалися. Regression перевіряє старий bookmark/readVersion і нову версію.
5. Перевірено верхню межу пентатоніки: повна позиція йде до C5, а не лише до A4. Обидва тексти називають C5 та повернення без повтору верхньої ноти. C major натомість є рівно C3–C4 і назад.
6. Em shape і practice розділені явно: шість simultaneous positions існують лише у display-only exercise; practice містить одинадцять окремих атак. Обидві мови пояснюють зупинку попередньої струни, відсутність chord grading та межі duration detection.

## Музична перевірка

Незалежні очікувані MIDI arrays у `StarterCourseTests` звірено з розв’язаними нотами кожної вправи. Для rhythm окремо задано attack ticks `[0, 1920, 2880, 3840, 4320, 5280, 5760, 6720]` та rest ticks `[960, 4800, 6240, 7200]`. Em перевіряє frets 0–2–2–0–0–0 у порядку струн 6→1, класи E/G/B, suggested fingers 5→2 / 4→3 та заборону display-only practice handoff. Усі вправи fixed Standard/A4 440; minimum/default/maximum BPM проходять чинну capability matrix. Діапазон нот E2–C5; найкоротша дозволена в курсі нота 300 ms.

Тексти описують prerequisites, мету, стартовий і наступний необов’язковий темп, конкретні струни/лади/такти та інтерпретацію результату. Оригінальний навчальний набір: 6 уроків, 29 кроків, 6 practice exercises + 1 display chord, 67 expected attacks + 9 rests. Джерела та повна таблиця — [STARTER-COURSE.md](../STARTER-COURSE.md).

## Докази

- `ValidateLessonContent Resources/Lessons`: **6 bilingual lessons, 0 issues**.
- `StarterCourseTests`: **3 tests passed**, включно з 24 deterministic event cases (6 exercises × 2 rates × perfect/all-missed), +50 ms known residual, valid 100/0 та recommendation references. Це event fixtures, не синтезований PCM і не жива гітара.
- `StarterCourseFlowTests`: **1 test passed**, 0.031 s: actual six lesson files → every step → fretboard/TAB models → idle practice request → synthetic pitch-only evidence → real temporary repository → localized history → fragment retry. Capture не запускається.
- App regression: **52 tests / 16 suites passed**, 10.741 s.
- Core regression: **128 tests / 26 suites passed**, 49.800 s; один opt-in hardware probe skipped.
- Local Debug/Release ad-hoc `.app` builds — passed. В обох bundles **19 lesson JSON files** byte-for-byte відповідають source; content validator приймає кожен packaged course: 6 lessons / 0 issues.
- Project consistency, 492 en/uk UI keys, UI-test source compilation і `git diff --check` — passed.

## Відкрито

U05/U07: native читання довгих en/uk текстів на мінімальному вікні, light/dark, keyboard/VoiceOver, зручність для початківця та реальна аплікатура. U02/U04/U10: жива електрогітара з інтерфейсом і вибірково акустика/п’єзо, повний результат/повтор. Computer-use pipe лишається недоступним; тестування state/JSON не замінює native UI. Усе, що потребує користувача, відкладено після всіх 22 задач згідно з його вказівкою. Після merge — `pending_user`, issue відкритий, Project `In review`. Розповсюдження не виконується.
