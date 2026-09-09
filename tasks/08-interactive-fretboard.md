# 08 — Інтерактивний гітарний гриф

GitHub: [#8](https://github.com/valtronforever/personal-guitar-coach/issues/8)

Статус: `todo`
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

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.
