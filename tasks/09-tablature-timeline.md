# 09 — Табулатура та послідовність нот

GitHub: [#9](https://github.com/valtronforever/personal-guitar-coach/issues/9)

Статус: `done`
Етап: MVP
Залежності: 03, 04

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Відображати послідовність нот на кшталт навчального табулатурного програвача.

## Робота

- Шість ліній: string1 зверху, string6 знизу; fret numbers, barlines, meter, rests і ритмічні значення.
- Четверті/восьмі/шістнадцяті, видимі duration/grouping; одночасні позиції для display-only акордів.
- Event hit testing, selection/range, scroll/zoom, auto-scroll transport cursor.
- API отримує canonical events і transport position; layout не використовує власну BPM clock.
- Accessibility description ноти/такту і keyboard event navigation.

## Критерії приймання

- Гама читається зліва направо; click повертає правильний stable event ID.
- Пауза займає правильний часовий інтервал; кілька нот в одному tick вирівняні.
- Курсор відповідає переданому tick незалежно від zoom.
- Довгі вправи не обрізають ноти; усі лади та такти можна переглянути.

## Перевірка

Fixtures 3/4, 4/4, змішані тривалості, паузи, scale, chord display; hit testing після scroll/zoom; два розміри вікна і обидві мови. Playback audio підключається в задачі 14.

## Докази виконання

- `TimelineModel` maps canonical ticks to bar-relative positions; `TablatureView` draws six numbered strings, fret numbers, bars, meter, rests, fractional durations and beat grouping. Held events retain their ID across barlines; display-only chords align all positions at one tick.
- Event/range selection, keyboard focus and Space/Return activation; 1×–2× zoom, horizontal scroll, 16-bar pages and direct bar navigation. External cursor ticks follow half-beat anchors without a UI playback clock.
- Integrated with the bundled lesson and a Debug-only fixture window for mixed 3/4 rhythm, a 20-bar 4/4 sequence, Em and muted strings. Selected tab events resolve the expected fretboard positions.
- 42 core + 18 app tests pass, including large-tick/page boundaries and cursor/hit geometry. Debug/Release builds, signatures, generated project, 185 en/uk keys and Swift 6 UI-source type checking pass.
- Native CUA verified range/keyboard selection, scroll/zoom, the last note of bar 20, 16↔17 focus transitions, 1×/2× cursor following, endpoint visibility, chords/mutes, and English/dark plus Ukrainian/light at minimum/larger sizes. System preferences restored.
- Local review: [09-review.md](../docs/reviews/09-review.md). UI XCTest source compilation is verified; local UI execution remains U07. Audio playback is task 14.
