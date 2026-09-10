# 19 — Початковий двомовний курс

GitHub: [#19](https://github.com/valtronforever/personal-guitar-coach/issues/19)

Статус: `pending_user`
Етап: MVP
Залежності: 07, 10, 18

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Поставити корисний комплект уроків із практикою, а не лише технічну демонстрацію.

## Робота

- Підготувати шість оригінальних уроків зі списку PRODUCT.md, повністю en/uk.
- Для кожного: навчальна мета, передумови, короткі пояснення, клікабельні кроки, правильні позиції, practice exercise, стартовий/рекомендований темп.
- Гами перевірити за назвами нот та аплікатурою; ритмічні вправи містять rests і repeated notes.
- Em пояснює акордову форму, практика оцінює арпеджіо; simultaneous chord scoring не обіцяти.
- Вправи обмежити підтвердженою pitch/tempo/duration матрицею; fixedTuning показати явно.

## Критерії приймання

- Усі шість уроків завершують цикл текст → крок → гриф/tab → practice → result/retry.
- Кожен step reference валідний, жодна locale не відсутня.
- Тексти зрозумілі початківцю; кожна вправа тренує заявлену навичку.
- Контент власний або з дозволеним походженням, без копіювання каталогу Songsterr.

## Перевірка

Content validator для всього bundle, ручна перевірка musical pitches/fingerings/timing, проходження шести вправ через deterministic fixtures і вибіркове живе виконання; візуально обидві мови.

## Докази виконання

Додано п’ять нових уроків і розширено вступ: 6 уроків en/uk, 29 кроків, 6 single-note practice exercises та 1 display-only Em chord. Усі pitches, positions, ticks, rests, tempi та prerequisites звірено; [опис курсу](../docs/STARTER-COURSE.md) містить музичну перевірку та походження. Вступний lesson підвищено до 2 без зміни exercise version 1 або історичних scores.

Content validator: 6 bilingual lessons / 0 issues, також для packaged Debug/Release resources; 19 JSON files у кожному bundle збігаються із source. Core: 128 tests / 26 suites passed (один hardware opt-in probe skipped). App: 52 tests / 16 suites passed. Deterministic fixtures покривають 24 perfect/all-missed event cases та повний software handoff шести уроків до result/save/retry. 492 UI keys, generated project, UI-test sources і diff check passed; локальні Debug/Release ad-hoc builds passed.

[Local review](../docs/reviews/19-review.md) записує знайдені проблеми, виправлення й межі. Після merge `pending_user`: native bilingual layout/VoiceOver, beginner walkthrough і живе виконання відкриті в U05/U07/U10 [фінальної перевірки](../docs/USER-VALIDATION.md), після всіх 22 задач. Computer-use pipe досі недоступний; UI/source fixtures не називаються живою грою.
