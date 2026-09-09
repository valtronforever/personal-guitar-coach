# 08 — Інтерактивний гітарний гриф

GitHub: [#8](https://github.com/valtronforever/personal-guitar-coach/issues/8)

Статус: `done`
Етап: MVP
Залежності: 03, 04, 06

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Показувати очікувані затиснуті позиції зрозуміло й відповідно до поточного строю.

## Робота

- SwiftUI/Canvas rendering шести струн, nut, 0–24 ладів із прокруткою/видимим діапазоном.
- Маркери окремих нот і форми акорду, open/muted, optional finger number, pitch name та octave.
- Selection, hover/focus description, right/left presentation без зміни domain numbering.
- Окремі стилі expected/selected/detected; detected pitch не прив'язувати до «доведеної» струни.
- Accessibility representation для Canvas та достатні hit targets.

## Критерії приймання

- Зовнішній вибір fingering/event одразу оновлює маркери.
- Open/muted відрізняються без кольору; кілька позицій акорду видно одночасно.
- Standard → Drop D змінює ноти шостої струни коректно.
- 24-й лад доступний на мінімальному розмірі вікна; mirrored mode не міняє MIDI.

## Перевірка

Музичні fixtures open strings, Em, scale fragment; візуально en/uk, dark/light, right/left, resize; keyboard focus і VoiceOver descriptions.

## Докази виконання

- `FretboardModel` / `FretboardView`: Canonical positions, six strings, nut, 0–24 frets, horizontal scrolling and jump control; expected circles, selected squares, open ○, muted ×, pitch/octave and optional fingers. Detected pitch is a separate label without string attribution.
- Native buttons provide 68×44 hit areas, hover descriptions, keyboard arrows and Space/Return selection, with localized accessible states. Mirroring changes only horizontal presentation.
- Lesson steps update external highlights and clear them for rests. Instrument Settings includes a collapsible live preview of the selected tuning.
- 42 core + 11 app tests pass; fixtures include Em, scale, mutes, all positions under Standard/Drop D and keyboard boundaries. Debug/Release builds, signature checks, project check and 156 en/uk keys pass.
- Native CUA: rest/full-bar selection; six simultaneous open markers; Standard → Drop D updates only string 6; English/dark and Ukrainian/light, both orientations, fret 24 at minimum main-window width, and keyboard activation verified. Original preferences restored.
- Local self-review and fixes: [08-review.md](../docs/reviews/08-review.md). Authored UI XCTest remains unexecuted locally (U07); final spoken VoiceOver/user walkthrough remains U05.
