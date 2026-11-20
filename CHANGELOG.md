# Changelog

## 1.6.2

- Enable the Sintezza skin for Blizzard's group roll popup by default on new profiles. Existing on and off settings are preserved.

## 1.6.1

- Give the optional Sintezza skin priority over EllesmereUI for Blizzard's group roll popup after a UI reload, without changing the saved EllesmereUI style.
- Use Sintezza Theme's shared background, fonts, item outline, smaller roll symbols, and countdown bar in the group roll popup. The skin requires Sintezza Theme 1.5.1 or later.
- Keep expired or undated loot-history entries out of the tracker, remember dismissed history rolls across UI reloads, and save confirmed results that arrive after a roll closes.
- Give the item tabs one quality outline and mark the selected tab with a short underline.

## 1.6.0

- Make the Sintezza skin for Blizzard's group roll popup opt-in, including for profiles with the previous enabled default.
- Use a single quality-colored outline on item icons in the history, tracker, and Sintezza win banner.
- Compact the settings buttons, show participant and conflict settings directly, and preview the selected win notifications below their selector.
- Style Blizzard's group roll popups with Sintezza colors and fonts and a flat countdown bar. Keep the item's quality-colored name and icon border.
- Open settings in a separate window with top tabs and keep data management in the Data tab.
- Add optional Sintezza Perf developer measurements for loot history and rolls.
- Avoid repeated roster reads when starting a roll and reuse the selected roll's evaluation during multi-item tracker refreshes.
- Keep the history version beside its title and recognize reset messages using the current client's observed instance name.
- Resolve the Drowned City from its matching quest title when the instance journal has no entry; remember instance names observed in each client locale.
- History resolves item and instance names in the current client language when client data is available. New boss sources retain a journal identifier where available; older names without one remain as recorded.

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

## 1.4.4

- Localized test roll participants, item placeholders, and the unknown player label.

## 1.4.3

- Added themed hints for hovering items in the Blizzard roll window and for test roll outcomes.

## 1.4.2

First public release baseline for WoW Forever 1.60.1.

- Configurable group and raid roll tracker with participant choices and results.
- Searchable run archive, class-colored winners, and personal loot history with series counts.
- CSV import and export, record counts, and maintenance controls.
- Optional Sintezza and Blizzard win banners. Simulation commands for group and raid previews.
- Shared Sintezza Theme with English and Russian interface.
