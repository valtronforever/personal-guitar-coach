# 18 — Результати, рекомендації й прогрес

GitHub: [#18](https://github.com/valtronforever/personal-guitar-coach/issues/18)

Статус: `pending_user`
Етап: MVP
Залежності: 05, 10, 17

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Перетворити виміри на зрозумілий наступний крок навчання.

## Робота

- Results view: overall за доступності, pitch/rhythm, validity/confidence, per-event annotations у табулатурі.
- 1–3 rule-based recommendations із evidence counts, тактами, рекомендованим темпом і deep link у repeat fragment.
- Separate signal/setup advice від performance advice; localized parameterized templates.
- Збереження і відновлення історії спроб, last/best для сумісних умов.
- Порівняння з урахуванням versions/BPM/tuning/range; прочитання уроку окремо від practice outcome.

## Критерії приймання

- Кожна рекомендація має відтворюваний зв'язок із конкретними спостереженнями.
- Немає тверджень про «неправильний палець» або фактично зіграну струну.
- Uncalibrated/interrupted/insufficient signal показують причину без оманливого overall.
- Retry suggestion відкриває правильний фрагмент і темп; мова історії перемикається без втрати даних.

## Перевірка

Rule fixtures з мінімальною evidence, result → retry flow, persistence reload, en/uk числівники й довгі тексти, incomparable attempts, accessibility без color-only markers.

## Докази виконання

Реалізовано `FeedbackEngine` / `PracticeComparison`, shared native `ResultDetailView`, annotations у TAB, detail history, immutable archived retry та безпечне відновлення строю. Поради містять 1–3 пріоритетні дії з конкретними counts/event/attack references, тактами й BPM. Правила, пороги, архівна семантика й межі — [ADR 005](../docs/decisions/005-feedback-progress.md).

Core: 125 tests / 25 suites passed (один opt-in hardware probe skipped); App: 51 tests / 15 suites passed; focused review regressions 6 FeedbackTests + 4 ResultFlowTests passed. 492 UI keys en/uk, project consistency і UI-test source compilation passed. Native Debug/Release build evidence та знайдені/виправлені проблеми — [review](../docs/reviews/18-review.md).

Після merge software ready; `pending_user` лишає відкритими native UI/VoiceOver/layout та фізичний practice → feedback walkthrough. Computer-use channel не відновився (pipe closed), тому visual success не заявляється. Див. U05/U07/U10 у [фінальній перевірці](../docs/USER-VALIDATION.md).
