# 03 — Музична модель і час вправ

GitHub: [#3](https://github.com/valtronforever/personal-guitar-coach/issues/3)

Статус: `todo`
Етап: MVP
Залежності: 01

Контекст: [правила](../AGENTS.md), [продукт](../docs/PRODUCT.md), [архітектура](../docs/ARCHITECTURE.md), [аудіоконтракт](../docs/AUDIO-AND-ASSESSMENT.md).

## Мета

Одна однозначна музична модель для грифа, табулатури, тюнера та оцінювання.

## Робота

- Реалізувати типи з ARCHITECTURE.md: Pitch, TuningProfile, FretPosition, Fingering, MusicalEvent, Exercise.
- Визначити stringNumber 1…6, fret 0…24, muted, pitch spelling та sounding MIDI.
- Реалізувати frequency/MIDI/cents conversions з reference A4, resolver позицій у конкретному snapshot строю.
- Час: PPQ 960, ticks, duration, rests, 3/4 і 4/4, сталий BPM; валідатор event ordering та assessment mode.
- Визначити fixedTuning/followsInstrument; simultaneous chord events дозволити для показу, відхиляти для monophonic assessment.

## Критерії приймання

- Standard string 6 fret 0 = E2/MIDI40, fret12 = E3/MIDI52; string1 fret0 = E4/MIDI64.
- Drop D змінює шосту струну без зміни інших; profile reference A4 узгоджено впливає на частоти.
- Muted не має pitch; rest не створює цільової атаки.
- Domain компілюється й тестується без SwiftUI/аудіопристрою.

## Перевірка

Граничні струни/лади, неправильні профілі, MIDI↔Hz і cents, alternative A4, ticks↔seconds, rests, акорди, tuning policy та заборона невалідних exercise durations.

## Докази виконання

Заповнюється під час реалізації: змінені компоненти, фактичні команди/перевірки та результати, hardware evidence за потреби, відкриті обмеження. Наразі реалізацію не розпочато.

