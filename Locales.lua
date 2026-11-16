local addonName, ns = ...

local clientLocale = GetLocale()
local locale = Sintezza_Theme.GetLocale and Sintezza_Theme:GetLocale() or clientLocale
local russian = locale == "ruRU"
local clientMatches = (russian and clientLocale == "ruRU")
    or (not russian and (clientLocale == "enUS" or clientLocale == "enGB"))

local function GameText(key, english, russianText)
    return (clientMatches and _G[key]) or (russian and russianText or english)
end

local L = {
    ADDON_TITLE = "Sintezza Loot",

    -- Roll choices
    ROLL_NEED = GameText("NEED", "Need", "Нужно"),
    ROLL_GREED = GameText("GREED", "Greed", "Не откажусь"),
    ROLL_DISENCHANT = GameText("ROLL_DISENCHANT", "Disenchant", "Распылить"),
    ROLL_PASS = GameText("PASS", "Pass", "Отказаться"),
    ROLL_PENDING = "",

    -- Table Headers
    HEADER_RANK = "#",
    HEADER_NAME = "Player",
    HEADER_CHOICE = "Choice",
    HEADER_ROLL = "Roll",
    ITEM_FALLBACK = "Item",

    WINNER_ALL_PASSED = "Everyone passed",

    FOOTER_SUMMARY = "Answered: %d/%d (%d pending)",
    FOOTER_COMPLETE = "Roll complete (%d/%d answered)",

    -- Tooltips and menus
    MENU_WHISPER = GameText("WHISPER", "Whisper", "Шепот"),
    MENU_INSPECT = GameText("INSPECT", "Inspect", "Осмотреть"),
    MENU_INVITE = GameText("INVITE", "Invite", "Пригласить"),
    MENU_CANCEL = GameText("CANCEL", "Cancel", "Отмена"),
    TOOLTIP_CLOSE_ITEM = "Hide this roll",
    TOOLTIP_PLAYER_CLICK = "Right-click — player menu\nShift+left-click — whisper",

    -- Settings
    SETTINGS_AUTO_OPEN = "Open on a new roll",
    SETTINGS_SHOW_ROLE = "Show role icons",
    SETTINGS_AUTO_SWITCH = "Switch Active Item on Hover",
    SETTINGS_AUTO_SWITCH_DESC = "Uses the item under the cursor in the Blizzard Group Loot window.",
    SETTINGS_CHOICE_DISPLAY = "Player choices",
    SETTINGS_CHOICE_ICONS = "Icons only",
    SETTINGS_CHOICE_TEXT = "Text Only",
    SETTINGS_CHOICE_BOTH = "Icons & Text",
    SETTINGS_ANCHOR_SIDE = "Window Anchor Position",
    SETTINGS_ANCHOR_RIGHT = "Right of group loot",
    SETTINGS_ANCHOR_LEFT = "Left of Group Loot",
    SETTINGS_ANCHOR_FREE = "Free position",
    SETTINGS_MOVE_BTN = "Move Window",
    EDIT_MODE_LABEL = "Sintezza Loot\nDrag to Move",
    EDIT_MODE_LOCK_BTN = "Lock Window",

    -- Chat & Slash Messages
    SLASH_HELP_HEADER = "|cff00ccffSintezza Loot|r commands:",
    SLASH_HELP_TEST = "  |cffffd100/sloot test|r - Simulate a single contested item roll",
    SLASH_HELP_TESTMULTI = "  |cffffd100/sloot testmulti|r - Simulate 4 simultaneous contested item rolls",
    SLASH_HELP_TESTRAID = "  |cffffd100/sloot testraid|r - Simulate a 40-player raid item roll",
    SLASH_HELP_STOP = "  |cffffd100/sloot stop|r - Clear active simulated rolls",
    SLASH_HELP_SHOW = "  |cffffd100/sloot show|r - Show the tracker window",
    SLASH_HELP_MOVE = "  |cffffd100/sloot move|r - Toggle positioning mode",
    SLASH_HELP_LOCK = "  |cffffd100/sloot lock|r / |cffffd100/sloot unlock|r - Lock or unlock the tracker position",
    SLASH_HELP_CONFIG = "  |cffffd100/sloot config|r - Open Sintezza Loot settings",
    MSG_SIM_STARTED = "Started simulated loot roll (%d item(s)).",
    MSG_SIM_STOPPED = "Cleared simulated loot rolls.",
    MSG_POS_RESET = "Window position reset to default.",
}

if russian then
    L.ITEM_FALLBACK = "Предмет"
    L.HEADER_NAME = "Игрок"
    L.ROLL_PENDING = ""
    L.HEADER_CHOICE = "Выбор"
    L.HEADER_ROLL = "Бросок"
    L.WINNER_ALL_PASSED = "Все отказались"
    L.FOOTER_SUMMARY = "Ответили: %d/%d (ожидается: %d)"
    L.FOOTER_COMPLETE = "Розыгрыш завершен (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Скрыть розыгрыш"
    L.TOOLTIP_PLAYER_CLICK = "ПКМ — меню игрока\nShift+ЛКМ — шепот"
    L.SETTINGS_AUTO_OPEN = "Открывать при новом розыгрыше"
    L.SETTINGS_SHOW_ROLE = "Показывать иконки ролей"
    L.SETTINGS_AUTO_SWITCH = "Переключать предмет при наведении"
    L.SETTINGS_AUTO_SWITCH_DESC = "Берет предмет под курсором из окна групповой добычи Blizzard."
    L.SETTINGS_CHOICE_DISPLAY = "Выбор игроков"
    L.SETTINGS_CHOICE_ICONS = "Только иконки"
    L.SETTINGS_CHOICE_TEXT = "Только текст"
    L.SETTINGS_CHOICE_BOTH = "Иконки и текст"
    L.SETTINGS_ANCHOR_SIDE = "Положение окна"
    L.SETTINGS_ANCHOR_RIGHT = "Справа от окна добычи"
    L.SETTINGS_ANCHOR_LEFT = "Слева от окна добычи"
    L.SETTINGS_ANCHOR_FREE = "Свободная позиция"
    L.SETTINGS_MOVE_BTN = "Переместить окно"
    L.EDIT_MODE_LABEL = "Sintezza Loot\nПеретащи окно"
    L.EDIT_MODE_LOCK_BTN = "Закрепить"
    L.SLASH_HELP_HEADER = "Команды |cff00ccffSintezza Loot|r:"
    L.SLASH_HELP_TEST = "  |cffffd100/sloot test|r - Тест розыгрыша 1 предмета"
    L.SLASH_HELP_TESTMULTI = "  |cffffd100/sloot testmulti|r - Тест розыгрыша 4 предметов"
    L.SLASH_HELP_TESTRAID = "  |cffffd100/sloot testraid|r - Тест рейдового розыгрыша (40 чел.)"
    L.SLASH_HELP_STOP = "  |cffffd100/sloot stop|r - Остановить симуляцию"
    L.SLASH_HELP_SHOW = "  |cffffd100/sloot show|r - Показать окно"
    L.SLASH_HELP_MOVE = "  |cffffd100/sloot move|r - Режим перемещения окна"
    L.SLASH_HELP_LOCK = "  |cffffd100/sloot lock|r / |cffffd100/sloot unlock|r - Закрепить или открепить окно бросков"
    L.SLASH_HELP_CONFIG = "  |cffffd100/sloot config|r - Открыть настройки"
    L.MSG_SIM_STARTED = "Запущена симуляция розыгрыша (%d предм.)."
    L.MSG_SIM_STOPPED = "Симуляция розыгрыша остановлена."
    L.MSG_POS_RESET = "Позиция окна сброшена по умолчанию."

end

L.TRACKER_CONFLICT = russian and "Обнаружен конфликт с аддоном «%s»: оба аддона показывают групповые розыгрыши добычи."
    or "Conflict with %s: both addons display group loot rolls."
L.SETTINGS_TRACKER = russian and "Трекер" or "Tracker"
L.SETTINGS_TRACKER_BEHAVIOR = russian and "Поведение трекера" or "Tracker behavior"
L.SETTINGS_SHOW_TRACKER = russian and "Показывать трекер" or "Show the tracker"
L.SETTINGS_HISTORY_RECORDS = russian and "Трекер скрыт. История продолжает записываться." or "Tracker hidden. History is still recorded."
L.SETTINGS_CLOSE_ENABLED = russian and "Закрывать после последнего розыгрыша" or "Close after the last roll"
L.SETTINGS_CLOSE_DELAY = russian and "Задержка закрытия" or "Close delay"
L.SETTINGS_SECONDS = russian and " с" or " s"
L.SETTINGS_NORMAL_TIMER = russian and "Показывать таймер бросков" or "Show the roll timer"
L.SETTINGS_WIN_HEADING = russian and "Уведомление о выигрыше" or "Win notification"
L.SETTINGS_WIN_LABEL = russian and "Показывать" or "Show"
L.SETTINGS_WIN_BOTH = russian and "Sintezza и Blizzard" or "Sintezza and Blizzard"
L.SETTINGS_WIN_OFF = russian and "Выключено" or "Off"
L.SETTINGS_PARTICIPANTS = russian and "Участники и вывод" or "Participants and display"
L.SETTINGS_SHOW_PASS = russian and "Показывать отказавшихся" or "Show players who passed"
L.SETTINGS_SHOW_PENDING = russian and "Показывать ожидающих" or "Show players who have not rolled"
L.SETTINGS_SHOW = russian and "Развернуть" or "Expand"
L.SETTINGS_HIDE = russian and "Свернуть" or "Collapse"
L.SETTINGS_CONFLICTS = russian and "Конфликт аддонов" or "Add-on conflicts"
L.SETTINGS_CONFLICT_LOADED = russian and "Загружен %s. Оба аддона показывают окно групповых розыгрышей."
    or "%s is loaded. Both add-ons display a group roll window."
L.SETTINGS_CONFLICT_NONE = russian and "Известные конфликтующие аддоны не загружены." or "No known conflicting add-on is loaded."
L.SETTINGS_PREVIEW = russian and "Предпросмотр" or "Preview"
L.SETTINGS_WINDOW_HEADER = russian and "Окно и миникарта" or "Window and minimap"
L.SETTINGS_HISTORY_WINDOWS = russian and "Настройки и история" or "Settings and history"
L.DATA_TITLE = russian and "Данные" or "Data"
L.DATA_ROLLS = russian and "Групповые розыгрыши" or "Group rolls"
L.DATA_ARCHIVED = russian and "Архивные забеги" or "Archived runs"
L.DATA_TRANSFER = russian and "Экспорт и импорт CSV" or "Export and import CSV"
L.DATA_MAINTENANCE = russian and "Обслуживание" or "Maintenance"
L.DATA_MANAGE = russian and "Управление данными" or "Manage data"
L.DATA_ALL = russian and "Все записи" or "All records"
L.DATA_INVALID = russian and "В CSV есть некорректная запись истории добычи." or "The CSV contains an invalid loot history record."
L.DATA_LIMIT = russian and "Импорт превысит лимит истории. Выбери CSV с меньшим числом записей."
    or "Import would exceed the history limit. Use a CSV with fewer records."
L.DATA_MEMORY_NOTE = russian and "Замер включает код, интерфейс и данные аддона. Очистка «Моей добычи» удаляет выигранные записи и из забегов."
    or "Memory includes addon code, interface, and data. Clearing My loot also removes those won rolls from Runs."
L.SETTINGS_ROLL_HEADER = russian and "Окно розыгрыша" or "Roll window"
L.SETTINGS_MOVE_BTN = russian and "Переместить розыгрыш" or "Move roll window"
L.SETTINGS_TEST_HEADER = russian and "Тестовый розыгрыш" or "Test roll"
L.TEST_ITEMS = russian and "Предметы" or "Items"
L.TEST_PLAYERS = russian and "Участники" or "Players"
L.TEST_ITEM_FALLBACK = russian and "Предмет №%d" or "Item #%d"
L.TEST_SELF_NAME = russian and "Твой персонаж" or "Your character"
L.TEST_MEMBER_NAME = russian and "Игрок %02d" or "Player %02d"
L.TEST_ROLL_FLOW = russian and "Ход розыгрыша" or "Roll outcome"
L.TEST_ROLL_FLOW_HELP = russian
    and "Выбирает исход для теста в обычном окне розыгрыша. Тестовые броски не попадают в историю."
    or "Selects an outcome to preview in the regular roll window. Test rolls do not enter history."
L.TEST_TIMEOUT = russian and "Ждем до конца таймера" or "Wait for the timer to expire"
L.TEST_SELF_WIN = russian and "Твоя победа" or "You win"
L.TEST_OTHER_WIN = russian and "Победа другого игрока" or "Another player wins"
L.TEST_ALL_PASS = russian and "Все отказываются" or "Everyone passes"
L.TEST_START = russian and "Запустить тест" or "Run test"
L.TEST_STOP = russian and "Остановить тест" or "Stop test"
L.FOOTER_ANSWERS = russian and "Ответили %d из %d" or "%d of %d responded"
L.FOOTER_TIME_LEFT = russian and "До конца  %d:%02d" or "Time left  %d:%02d"
L.FOOTER_AWAITING_RESULT = russian and "Ожидаем итог розыгрыша" or "Waiting for roll result"
L.CHOICE_WAITING = russian and "Ожидает" or "Pending"
L.COMMAND_ERROR = russian and "Ошибка команды" or "Command error"
L.SIMULATION_ERROR = russian and "Ошибка симуляции" or "Simulation error"
L.OPEN_SETTINGS = russian and "Открыть настройки" or "Open settings"
L.INIT_ERROR = russian and "|cffff4444Ошибка загрузки %s|r · %s" or "|cffff4444Failed to load %s|r · %s"
ns.L = L

L.SLASH_HELP_HISTORY = russian and "  /sloot history — история добычи" or "  /sloot history — loot history"
L.HISTORY_TITLE = russian and "История добычи" or "Loot history"
L.HISTORY_EMPTY = russian and "Нет завершенных розыгрышей." or "No completed rolls."
L.HISTORY_SETTINGS = russian and "Настройки" or "Settings"
L.HISTORY_BACK = russian and "К истории" or "Back to history"
L.HISTORY_SEARCH = russian and "Ник, предмет или инстанс" or "Player, item, or instance"
L.HISTORY_CLEAR = russian and "Очистить" or "Clear"
L.HISTORY_EXPAND = russian and "Броски" or "Rolls"
L.HISTORY_COLLAPSE = russian and "Свернуть" or "Collapse"
L.HISTORY_NO_MATCH = russian and "Совпадений нет" or "No matches"
L.HISTORY_CURRENT = russian and "Текущий забег" or "Current run"
L.HISTORY_RUNS = russian and "Забеги" or "Runs"
L.HISTORY_PERSONAL = russian and "Моя добыча" or "My loot"
L.HISTORY_PERSONAL_EMPTY = russian and "Выигранной добычи пока нет." or "No loot won yet."
L.HISTORY_WON_ATTEMPT = russian and "С %d-го броска" or "Won on roll %d"
L.HISTORY_ARCHIVE = russian and "Архив" or "Archive"
L.HISTORY_PAUSED = russian and "Временно снаружи" or "Temporarily outside"
L.HISTORY_SINCE = russian and "с %s" or "since %s"
L.HISTORY_OUTSIDE = russian and "Вне забегов" or "Outside runs"
L.HISTORY_LEGACY = russian and "Забег неизвестен" or "Unknown run"
L.HISTORY_ROLL_ONE = russian and "ролл" or "roll"
L.HISTORY_ROLL_FEW = russian and "ролла" or nil
L.HISTORY_ROLL_MANY = russian and "роллов" or "rolls"
L.HISTORY_PLAYER = russian and "Игрок" or "Player"
L.HISTORY_CHOICE = russian and "Выбор" or "Choice"
L.HISTORY_SCORE = russian and "Бросок" or "Roll"
L.HISTORY_SELF = russian and "Ты" or "You"
L.HISTORY_WINNER_TAG = russian and "Победитель" or "Winner"
L.HISTORY_OFF_SPEC = russian and "Нужно (другая специализация)" or "Need (off spec)"
L.HISTORY_TRANSMOG = russian and "Трансмогрификация" or "Transmog"
L.HISTORY_UNKNOWN = russian and "Нет данных" or "Unknown"
L.ROSTER_UNKNOWN_PLAYER = russian and "Неизвестный игрок" or "Unknown player"
L.HISTORY_NO_ROLL = russian and "Без ответа" or "No response"
L.HISTORY_WINNER = russian and "Победитель: %s" or "Winner: %s"
L.HISTORY_YOU_WON = russian and "Твоя добыча" or "You won"
