# План реалізації

22 задачі: **20 для MVP**, **2 для наступного етапу**. Реалізація триває; актуальні статуси наведено в таблиці. Кожен файл містить мету, роботу, критерії приймання, перевірки та місце для доказів виконання.

Англомовні issues створено в [GitHub Project — Backlog](https://github.com/users/valtronforever/projects/4/views/1). Кожна задача реалізується в окремій гілці через перевірки, local review, PR і merge.

## Порядок роботи

1. **Основа й технічний ризик:** 01 → 02. Спочатку довести capture з реального USB-інтерфейсу та вибрати аудіобекенд.
2. **Навчальний інтерфейс:** 03–10 за залежностями. Результат — двомовний урок із клікабельними кроками, грифом та табулатурою.
3. **Аудіоінструменти:** 11–15. Результат — device/channel setup, детектор, тюнер, точний метроном і калібрування.
4. **Практика та користь:** 16–19. Результат — повна спроба, чесна оцінка, поради, історія і шість уроків.
5. **Готовність MVP:** 20. Реальна hardware-перевірка та локальна release-збірка.
6. **Розширення після MVP:** 21–22. Дослідження акордів і прототип стандартної нотації.

Номер — ідентифікатор, не жорсткий календар. Наприклад, після 01 завдання 03/04 не залежать від hardware evidence 02, а 11 можна почати після 02/04/05, не чекаючи всього навчального UI. Це залежності робіт, а не інструкція автоматично запускати додаткових агентів.

## Задачі

| ID | Задача | Залежності | Етап | Статус | GitHub |
| --- | --- | --- | --- | --- | --- |
| 01 | [Основа нативного macOS-проєкту](01-project-scaffold.md) | — | MVP | `pending_user` | [#1](https://github.com/valtronforever/personal-guitar-coach/issues/1) |
| 02 | [Аудіопрототип і вибір бекенда](02-audio-feasibility.md) | 01 | MVP | `todo` | [#2](https://github.com/valtronforever/personal-guitar-coach/issues/2) |
| 03 | [Музична модель і час вправ](03-music-domain.md) | 01 | MVP | `todo` | [#3](https://github.com/valtronforever/personal-guitar-coach/issues/3) |
| 04 | [Навігація, дизайн і двомовність](04-app-shell-localization.md) | 01 | MVP | `todo` | [#4](https://github.com/valtronforever/personal-guitar-coach/issues/4) |
| 05 | [Локальні налаштування та історія](05-local-persistence.md) | 03, 04 | MVP | `todo` | [#5](https://github.com/valtronforever/personal-guitar-coach/issues/5) |
| 06 | [Профіль гітари та вибір строю](06-tuning-settings.md) | 03, 04, 05 | MVP | `todo` | [#6](https://github.com/valtronforever/personal-guitar-coach/issues/6) |
| 07 | [Формат уроків і вправ](07-lesson-content-contract.md) | 03 | MVP | `todo` | [#7](https://github.com/valtronforever/personal-guitar-coach/issues/7) |
| 08 | [Інтерактивний гітарний гриф](08-interactive-fretboard.md) | 03, 04, 06 | MVP | `todo` | [#8](https://github.com/valtronforever/personal-guitar-coach/issues/8) |
| 09 | [Табулатура та послідовність нот](09-tablature-timeline.md) | 03, 04 | MVP | `todo` | [#9](https://github.com/valtronforever/personal-guitar-coach/issues/9) |
| 10 | [Каталог уроків і синхронізація кроків](10-lesson-reader.md) | 05, 07, 08, 09 | MVP | `todo` | [#10](https://github.com/valtronforever/personal-guitar-coach/issues/10) |
| 11 | [Налаштування пристроїв і стабільний аудіовхід](11-audio-devices-capture.md) | 02, 04, 05 | MVP | `todo` | [#11](https://github.com/valtronforever/personal-guitar-coach/issues/11) |
| 12 | [Розпізнавання висоти й атак нот](12-pitch-onset-analysis.md) | 03, 11 | MVP | `todo` | [#12](https://github.com/valtronforever/personal-guitar-coach/issues/12) |
| 13 | [Тюнер поточного строю](13-guitar-tuner.md) | 06, 12 | MVP | `todo` | [#13](https://github.com/valtronforever/personal-guitar-coach/issues/13) |
| 14 | [Метроном, transport і прослуховування](14-metronome-playback.md) | 03, 09, 10, 11 | MVP | `todo` | [#14](https://github.com/valtronforever/personal-guitar-coach/issues/14) |
| 15 | [Калібрування затримки та спільний час](15-latency-calibration.md) | 11, 12, 14 | MVP | `todo` | [#15](https://github.com/valtronforever/personal-guitar-coach/issues/15) |
| 16 | [Повний цикл практики](16-practice-session.md) | 06, 10, 13, 14, 15 | MVP | `todo` | [#16](https://github.com/valtronforever/personal-guitar-coach/issues/16) |
| 17 | [Оцінювання висоти та ритму](17-assessment-engine.md) | 03, 12, 15, 16 | MVP | `todo` | [#17](https://github.com/valtronforever/personal-guitar-coach/issues/17) |
| 18 | [Результати, рекомендації й прогрес](18-feedback-progress.md) | 05, 10, 17 | MVP | `todo` | [#18](https://github.com/valtronforever/personal-guitar-coach/issues/18) |
| 19 | [Початковий двомовний курс](19-starter-course.md) | 07, 10, 18 | MVP | `todo` | [#19](https://github.com/valtronforever/personal-guitar-coach/issues/19) |
| 20 | [Перевірка MVP та локальна release-збірка](20-mvp-validation-release.md) | 01–19 | MVP | `todo` | [#20](https://github.com/valtronforever/personal-guitar-coach/issues/20) |
| 21 | [Дослідження оцінювання акордів](21-polyphonic-chords.md) | 20 | Після MVP | `todo` | [#21](https://github.com/valtronforever/personal-guitar-coach/issues/21) |
| 22 | [Нотний стан і розширена нотація](22-staff-advanced-notation.md) | 20 | Після MVP | `todo` | [#22](https://github.com/valtronforever/personal-guitar-coach/issues/22) |

## Контрольні результати

| Результат | Умова |
| --- | --- |
| Нативна основа | 01: .app запускається, shared scheme і build/test-команди відтворюються |
| Доведений аудіошлях | 02: справжній instrument input + click output, ADR та hardware matrix |
| Урок працює | 03–10: вибір текстового кроку синхронізує правильні маркери й табулатуру в en/uk |
| Інструменти готові | 11–15: канал, тюнер, клік і clock mapping перевірені, uncertainty відома |
| Навчальний цикл працює | 16–19: гра → score/evidence → порада → повтор → історія |
| MVP перевірено | 20: автоматизовані й апаратні перевірки завершено, release artifact відтворюється |

## Покриття початкового запиту

| Вимога | Задачі |
| --- | --- |
| Нативний macOS-додаток | 01, 04, 20 |
| Текстові уроки та практика до них | 07, 10, 16, 19 |
| Клік по кроку → позиції на грифі | 03, 08, 10 |
| Послідовність нот на кшталт Songsterr | 03, 09, 14; звичайний нотний стан — 22 |
| Реальний аудіоінтерфейс і налаштування входу | 02, 11 |
| Вибір строю для показу й аналізу | 03, 06, 08, 12, 16 |
| Тюнер | 12, 13 |
| Метроном, аналіз і точний ритм | 12, 14, 15, 16 |
| Оцінка та рекомендації | 17, 18 |
| Англійська та українська | 04 і критерії кожної користувацької задачі, 19, 20 |
| Оцінка одночасних акордів як розширення | 21; у MVP лише показ акордів і практика арпеджіо |

## Статуси та завершення

- `todo` — не розпочато.
- `in_progress` — реалізація триває.
- `pending_user` — код змерджено; тільки залежні від користувача перевірки відкладено до фінального кроку, не блокуючи наступні задачі.
- `blocked` — записано конкретну зовнішню перешкоду та що потрібно для продовження.
- `done` — усі критерії приймання й потрібні перевірки мають evidence.

Оновлювати статус і тут, і в окремому файлі. Якщо потрібен фізичний інтерфейс, а перевірено лише fixture, задача не `done`. У кожному implementation-звіті вказувати фактичну перевірку, а не просто «тести передбачені».

Оцінки у днях навмисно не зафіксовано до аудіопрототипу: маршрути пристроїв, точність pitch/onset і калібрування визначають складність критичної частини. Після 02 уточнити обсяг аудіозадач за evidence.

## Параметри для уточнення під час відповідних задач

- 01: встановлений Xcode, цільові Mac/архітектури та мінімальна версія ОС.
- 02: модель доступного інтерфейсу, input channel, вихід навушників, доступність loopback.
- 12/15: підтверджені pitch/tempo/latency capability limits.
- 19: складність і навчальна послідовність після пробного проходження початкових уроків.
- 20: спосіб зовнішнього розповсюдження, якщо він буде потрібен. План уже дозволяє локальну розробку без цього рішення.
