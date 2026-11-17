# Changelog

## 1.5.0

- The loot history window shows the version beside the title.
- Tracker, preview and history settings sit directly on the page under shared headings.

- Window and minimap settings use the page background.

- A finished run remains available for trash loot until you leave. Re-entering starts a new run; delayed rolls keep their original run.
- Unfinished runs survive returns of any duration. Successful resets start a new run; failed resets and unavailable API data do not.
- Changed saved-instance IDs and validated boss-progress regressions can separate runs. Late evidence moves only the current visit's rolls and boss kills, including after a UI reload.
- Completion no longer assumes the last boss listed in the journal is the final boss. Where a complete boss list is available, all listed encounters must be confirmed killed.
- Added `/sloot newrun` to start a separate history run when the client cannot distinguish visits. This command does not reset the instance.

- Runs enter the archive only after a recorded roll. Older empty runs are removed on load, and CSV import skips runs without rolls.
- Returning to the same dungeon after a wipe or a temporary exit continues the run. Target NPC GUIDs no longer split runs; confirmed resets, instance changes, and new challenges start a new run.
- Loot history uses expandable list rows with the shared Theme arrow, without separate expand buttons.
- A subtle outline marks your character in the participant list, replacing the "You" tag for both wins and losses.

- Left-clicking the minimap icon opens or closes the window.

- Connected window scale, opacity, and layer to the shared Theme settings. The WoW AddOns settings launcher uses the shared Theme helper.

- Updated the project logo and in-game addon icon.

- Aligned the item name and icon above the decorative border in the roll tracker.

### По-русски

- В истории добычи версия отображается рядом с названием.
- Настройки розыгрышей, предпросмотра и истории размещены на фоне страницы под общими заголовками.

- Настройки окна и миникарты размещены прямо на фоне страницы.

- После завершения забега добыча с треша остается в нем до выхода. Повторный вход начинает новый забег; поздние результаты роллов сохраняют прежнюю привязку.
- Незавершенный забег продолжается после возвращения любой длительности. Успешный сброс начинает новый; ошибка сброса и недоступные данные API его не разделяют.
- Изменение ID сохранения и подтвержденный откат прогресса боссов помогают разделять забеги. Если данные пришли поздно, переносятся только роллы и убийства боссов текущего входа, в том числе после перезагрузки интерфейса.
- Последний босс в списке журнала больше не считается автоматически финальным. При доступном полном списке завершение подтверждается убийством всех перечисленных боссов.
- Добавлена команда `/sloot newrun` для нового забега в истории, когда клиент не позволяет отличить входы. Сам инстанс команда не сбрасывает.

- Забег сохраняется в истории после первого записанного ролла. Старые пустые забеги удаляются при загрузке, а импорт CSV пропускает забеги без роллов.
- Возврат в то же подземелье после вайпа или временного выхода продолжает забег. GUID выбранного NPC больше не разделяет забеги; подтвержденный сброс, смена инстанса и новое испытание начинают новый забег.
- Добыча оформлена раскрывающимися строками списка с общей стрелкой Theme, без отдельных кнопок раскрытия.
- Свой персонаж отмечен сдержанной рамкой вместо подписи «Ты», независимо от результата розыгрыша.

- ЛКМ по значку у миникарты открывает или закрывает окно.

- Масштаб, непрозрачность и слой окон подключены к общим настройкам Theme. Страница в меню модификаций использует общую реализацию Theme.

- Обновлены логотип проекта и игровая иконка аддона.

- Название и значок предмета в окне розыгрыша подняты над декоративной окантовкой.

## 1.4.4

- Localized test roll participants, item placeholders, and the unknown player label.

### По-русски

- Переведены имена тестовых участников, подписи до загрузки предметов и подпись неизвестного игрока.

## 1.4.3

- Added themed hints for hovering items in the Blizzard roll window and for test roll outcomes.

### По-русски

- Добавлены подсказки темы для выбора предмета наведением и исходов тестового розыгрыша.

## 1.4.2

First public release baseline for WoW Forever 1.60.1.

- Configurable group and raid roll tracker with participant choices and results.
- Searchable run archive, class-colored winners, and personal loot history with series counts.
- CSV import and export, record counts, and maintenance controls.
- Optional Sintezza and Blizzard win banners. Simulation commands for group and raid previews.
- Shared Sintezza Theme with English and Russian interface.

### По-русски

- Настраиваемый трекер групповых и рейдовых розыгрышей с выбором участников и результатами.
- Поиск по архиву заходов, цвета классов победителей и история личной добычи со счетчиком серий.
- Импорт и экспорт CSV, счетчики записей и обслуживание данных.
- Настройки плашек победы и команды предпросмотра для группы и рейда.
