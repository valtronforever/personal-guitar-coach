# 22 — Нотний стан і розширена нотація

GitHub: [#22](https://github.com/valtronforever/personal-guitar-coach/issues/22)

Статус: `todo`
Етап: Після MVP
Залежності: 20

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Розширити показ музики після стабільного навчального циклу з табулатурою.

## Робота

- Підготувати окремий notation ADR: стандартний staff, ключ, тональність, enharmonic spelling, rhythmic beaming.
- Врахувати гітарну нотацію на октаву вище реального звучання; domain MIDI залишається sounding pitch.
- Спланувати ties, tuplets, tempo changes та позначення технік (bend/slide/hammer-on/pull-off) із schema versioning.
- Визначити, які техніки лише показуються, а які потребують нового аналізатора й критеріїв.
- Підготувати обмежений staff prototype, синхронізований із тими самими event IDs і табулатурою.

## Критерії приймання

- Prototype не дублює musical timeline і не змінює висоту аудіо через written-octave presentation.
- Є перевірений приклад гам із правильними accidental/duration і синхронним selection.
- Unsupported assessment techniques явно позначені.
- Складено окремі implementation tasks для затвердженого розширення; імпорт сторонніх форматів не додано автоматично.

## Перевірка

Sounding E2 → правильна гітарна written note, key/accidental fixtures, event selection parity, layout і accessibility в en/uk.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

