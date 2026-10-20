part of 'main.dart';

String get appLanguage {
  final selected = AppSettings.current.language;
  if (selected != 'system') return selected == 'en' ? 'en' : 'ru';
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    if (locale.languageCode == 'ru' || locale.languageCode == 'en') {
      return locale.languageCode;
    }
  }
  return 'ru';
}

String tr(String source) {
  if (appLanguage != 'en') return source;
  final direct = english44[source] ?? english[source];
  if (direct != null) return direct;
  for (final base in [drySpeedWarning, invalidSlopeWarning]) {
    if (source.startsWith('$base\n')) {
      final detail = source
          .substring(base.length + 1)
          .replaceAll('Расстояния:', 'Distances:')
          .replaceAll('ЛБ', 'LB')
          .replaceAll('ПБ', 'RB')
          .replaceAll(' м', ' m');
      return '${english44[base]}\n$detail';
    }
  }
  return source;
}

String bankLabel(String? bank) => bank == null
    ? ''
    : appLanguage == 'en'
    ? (bank == 'ЛБ'
          ? 'LB'
          : bank == 'ПБ'
          ? 'RB'
          : bank)
    : bank;

const english = <String, String>{
  'По расходу воды': 'By discharge',
  'Точное совпадение проекта': 'Exact project match',
  'Опционально': 'Optional',
  'В метрах': 'In metres',
  'В сантиметрах': 'In centimetres',
  'Уровень воды на начало промеров, м': 'Water level at start of sounding, m',
  'Уровень воды на конец промеров, м': 'Water level at end of sounding, m',
  'Вернуть по умолчанию для приложения': 'Restore application defaults',
  'Вернуть по умолчанию для данного расчёта':
      'Restore defaults for this discharge measurement',
  'Вернуть по умолчанию для всех вертикалей в данном расчёте':
      'Use the common defaults for verticals in this discharge measurement',
  icePerimeterHelp46:
      'The ice cover is included in the calculation of the wetted perimeter.',
  'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться по умолчанию во всех новых измерениях расхода воды.':
      'The coefficient set selected here for calculating the mean velocity in a vertical will be used by default in all new discharge measurements.',
  'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться для всех скоростных вертикалей в данном измерении расхода воды, кроме вертикалей с индивидуальным методом.':
      'The coefficient set selected here for calculating the mean velocity in a vertical will apply to all velocity verticals in this discharge measurement, except those with an individually assigned method.',
  'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться только для данной скоростной вертикали в данном измерении расхода воды.':
      'The coefficient set selected here for calculating the mean velocity in a vertical will apply only to this velocity vertical in this discharge measurement.',

  'вместо продолжения склона': 'instead of extending the slope',
  "Импортировать файл .krv": "Import a .krv file",
  "Полная версия": "Full text",
  "Открыть код на GitHub": "View source on GitHub",
  "Предупреждение": "Warning",
  "Расход не определён": "Discharge not determined",
  "Повторить": "Retry",

  "Импорт измерений": "Import measurements",
  "Экспорт выбранных в .krv": "Export selected to .krv",
  "Создаём архив…": "Creating archive\u2026",
  "Архив измерений КРВ": "Water discharge measurement archive",
  "Не удалось создать или отправить архив.":
      "Could not create or share the archive.",
  "Выберите файл с расширением .krv.": "Select a .krv file.",
  "Архив слишком большой. Выберите меньше измерений.":
      "The archive is too large. Select fewer measurements.",
  "Проверяем архив…": "Checking archive\u2026",
  "Добавляем измерения…": "Adding measurements\u2026",
  "Добавлено измерений": "Measurements added",
  "Импорт не выполнен. Исходные измерения сохранены.":
      "Import did not complete. Existing measurements have been retained.",
  "Новых измерений": "New measurements",
  "Уже имеются без изменений": "Already present, unchanged",
  "Отличающихся версий": "Different versions",
  "Фотографий к добавлению": "Photos to add",
  "Добавить измерения": "Add measurements",
  "Совпадающие записи будут пропущены. Отличающиеся версии добавятся отдельными копиями. Существующие измерения и настройки приложения не изменятся.":
      "Identical records will be skipped. Different versions will be added as separate copies. Existing measurements and application settings will remain unchanged.",
  "Импортированная копия": "Imported copy",
  "Файл повреждён или не является архивом КРВ.":
      "The file is damaged or is not a KRV archive.",
  "Архив создан более новой версией. Обновите приложение.":
      "The archive requires a newer version. Update the application.",
  "Не найдена фотография измерения. Экспорт отменён.":
      "A measurement photo is missing. Export was cancelled.",
  'Режим подсказок:': 'Hint mode:',
  "Получать координаты при создании нового измерения":
      "Acquire coordinates when creating a new measurement",
  "Метод расчёта Uср": "Umean calculation method",
  "Набор коэффициентов": "Coefficient set",
  "Вернуть настройки по умолчанию": "Restore defaults",
  "Выбрать метод расчёта": "Choose a calculation method",
  "Метод": "Method",
  "Нажмите на коэффициент k для его изменения":
      "Tap a coefficient k to edit it",
  "по 6 точкам": "6-point method",
  "по 5 точкам": "5-point method",
  "по 3 точкам": "3-point method",
  "по 2 точкам": "2-point method",
  "по точке на 0.6h": "1 point at 0.6h",
  "по точке на 0.2h": "1 point at 0.2h",
  "по точке на 0.5h": "1 point at 0.5h",
  "по точке на пов-ти": "1 point at surface",
  "Справка": "Help",
  "Таблица расчёта расхода воды": "Discharge calculation table",
  "Ледовые явл. / раст.": "Ice / vegetation",
  "Выбранный здесь набор коэффициентов будет использоваться по умолчанию для всех новых создаваемых измерений.":
      "The selected coefficient set will be used by default for all new measurements.",
  "Выбранный здесь набор коэффициентов будет использоваться для всех скоростных вертикалей в данном измерении расхода воды, кроме вертикалей с индивидуальным методом.":
      "The selected coefficient set will apply to all velocity verticals in this discharge measurement, except those with an individual method.",
  "Выбранный здесь набор коэффициентов будет использоваться для данной скоростной вертикали в данном измерении расхода воды.":
      "The selected coefficient set will apply to this velocity vertical in this discharge measurement.",
  aboutText:
      'This app was vibe-coded by Oleg Loshkov, a student at the Department of Land Hydrology, Faculty of Geography, Lomonosov Moscow State University, in 2025-26.\n\nMethodological basis:\n- Guidelines MI 1759-87;\n- WMO Guide to Hydrological Practices No. 168, sixth edition\n\nFeedback, support and collaboration:',
  coefficientsIntro:
      'The tables below contain weighting coefficients for point velocities measured at different depths, used to calculate the mean velocity in a vertical. You can use the predefined coefficient sets or specify your own.',
  coefficientsLimits:
      'Coefficients must be greater than zero, no greater than 1000, and have no more than 3 decimal places.',
  specialRules:
      'Ice conditions / aquatic vegetation use a separate coefficient table below the normal table. Under these conditions, the app selects the first available method from top to bottom in that table only. If the available point measurements are insufficient for these methods, the mean velocity in the vertical cannot be calculated; the app does not fall back to normal-condition methods.',
  specialExample:
      'Under ice conditions or in the presence of aquatic vegetation, the mean velocity in a vertical is calculated using special-condition methods. For example, with velocities at 0.2h, 0.6h and 0.8h, the calculation uses the pair at 0.2h and 0.8h. If there is insufficient data for a special-condition method, the mean velocity in the vertical cannot be calculated.',
  iceDepthHelp:
      'Depths entered under ice cover are treated as effective water depths, excluding ice thickness.',

  "Исправьте некорректные значения скорости": "Correct invalid velocity values",
  "Некорректное число": "Invalid number",
  "Горизонт": "Measurement depth",
  "Коэффициент": "Coefficient",
  "Настройки": "Settings",
  "v4.6": "v4.6",
  "Калькулятор Расходов Воды": "Water Discharge Calculator",
  "Калькулятор расходов воды 4.6": "Water Discharge Calculator 4.6",
  "Калькулятор расходов воды · 4.6": "Water Discharge Calculator · 4.6",
  "Язык": "Language",
  "Как в системе": "System default",
  "Автоматически получать координаты": "Get coordinates automatically",
  "Метод расчёта по умолчанию": "Default calculation method",
  "Эти настройки применяются только к новым измерениям. Существующие измерения сохраняют свои методы.":
      "These settings apply only to new measurements. Existing measurements retain their methods.",
  "Не удалось сохранить настройки": "Could not save settings",
  "Средняя скорость на вертикали": "Mean velocity in the vertical",
  "Выйти без сохранения?": "Leave without saving?",
  "Изменения настроек будут отменены.":
      "Changes to settings will be discarded.",
  "Используется метод измерения": "Using the measurement method",
  "Прежний алгоритм сохранён. Результаты старого измерения не изменены.":
      "The legacy algorithm is retained. The previous measurement results remain unchanged.",
  "Выбрать метод версии 4.0": "Choose a version 4.0 method",
  "Набор формул": "Formula set",
  "Приоритет: первая доступная схема сверху вниз. Незаполненное поле отличается от нулевой скорости.":
      "Priority: the first available method from top to bottom. An empty field is different from zero velocity.",
  "Обычные условия": "Normal conditions",
  "Ледовые явления / растительность": "Ice conditions / aquatic vegetation",
  "Нажмите коэффициент для изменения: больше 0, не больше 1000, до 3 знаков после запятой. Для одной точки делитель равен 1.":
      "Tap a coefficient to edit it: greater than 0, at most 1000, up to 3 decimal places. The divisor for a single point is 1.",
  "Коэффициенты этого набора доступны только для просмотра.":
      "The coefficients in this set are read-only.",
  "Вернуть метод измерения": "Use the measurement method",
  "Индивидуальный метод": "Individual method",
  "Метод измерения": "Measurement method",
  "Метод расчёта измерения": "Measurement calculation method",
  "Схема": "Method",
  "Делитель": "Divisor",
  "Применить": "Apply",
  "0 < коэффициент ≤ 1000; до 3 десятичных знаков":
      "0 < coefficient ≤ 1000; up to 3 decimal places",
  "Недопустимый коэффициент. Сохранено предыдущее значение.":
      "Invalid coefficient. The previous value has been retained.",
  "ВМО № 168": "WMO No. 168",
  "МИ 1759-87": "MI 1759-87",
  "Комбинированный": "Combined",
  "Пользовательский I": "Custom I",
  "Пользовательский II": "Custom II",
  "Пользовательский III": "Custom III",
  "Прежний алгоритм": "Legacy algorithm",
  "6 точек": "6 points",
  "5 точек": "5 points",
  "3 точки": "3 points",
  "2 точки": "2 points",
  "Поверхность": "Surface",
  "Ледостав": "Ice cover",
  "Ледостав включён для всего створа.":
      "Ice cover is enabled for the whole cross-section.",
  "Глубина — рабочая глубина безо льда. Лёд увеличивает смоченный периметр на ширину створа.":
      "Enter effective water depth, excluding ice. Ice adds the cross-section width to the wetted perimeter.",
  "Рабочая глубина": "Effective water depth",
  "Расстояние от дна": "Height above bed",
  "Глубина от поверхности": "Depth below surface",
  "Скоростная вертикаль": "Velocity vertical",
  "Скорости": "Velocities",
  "Ввести": "Enter",
  "Uпов": "Usur",
  "Uдно": "Ubed",
  "Uср": "Umean",
  "м": "m",
  "см": "cm",
  "м/с": "m/s",
  "м²": "m²",
  "м³/с": "m³/s",
  "н/д": "N/A",
  "Да": "Yes",
  "Нет": "No",
  "Отмена": "Cancel",
  "Закрыть": "Close",
  "Добавить": "Add",
  "Назад": "Back",
  "Сохранить": "Save",
  "Сохранение": "Save",
  "Сохраняем измерение…": "Saving measurement…",
  "Сохранить и выйти в главное меню?": "Save and return to the main screen?",
  "Выход": "Exit",
  "Редактирование": "Editing",
  "Редактировать измерение": "Edit measurement",
  "Войти в режим редактирования?": "Enter edit mode?",
  "Выйти на главный экран (все введённые данные сохранятся)?":
      "Return to the main screen (all entered data will be saved)?",
  "Вернуться на экран «Промерные работы»?\nВведённые данные будут сохранены.":
      "Return to the Sounding screen?\nEntered data will be saved.",
  "Вернуться на экран «Измерение скоростей течения»?\nРасчёт расхода потребуется выполнить заново.\nВведённый комментарий сохранится.":
      "Return to the Velocity measurement screen?\nDischarge will need to be recalculated.\nYour comment will be saved.",
  "Без названия реки": "Unnamed river",
  "Без названия створа": "Unnamed cross-section",
  "Без_названия": "Untitled",
  "Название реки": "River name",
  "Название створа": "Cross-section name",
  "Начать новое измерение": "Start a new measurement",
  "Промерные работы": "Sounding",
  "Измерение скоростей": "Velocity measurement",
  "Расход воды": "Water discharge",
  "Расход воды, м3/с": "Discharge, m3/s",
  "Комментарии": "Comments",
  "Комментарий": "Comment",
  "не указан": "not specified",
  "не указано": "not specified",
  "не указаны": "not specified",
  "не начаты": "not started",
  "\nНезавершённое измерение": "\nUnfinished measurement",
  "Поиск": "Search",
  "🔎 Поиск": "🔎 Search",
  "Изменить поиск": "Edit search",
  "Сбросить поиск": "Reset search",
  "По дате": "By date",
  "По названию реки": "By river name",
  "По названию створа": "By cross-section name",
  "Точное совпадение реки": "Exact river name",
  "Точное совпадение створа": "Exact cross-section name",
  "Дата с": "Date from",
  "по": "to",
  "дд.мм.гггг": "dd.mm.yyyy",
  "Дата указана в неверном формате": "Invalid date format",
  "Измерения отсутствуют": "No measurements",
  "Измерения не найдены,\nизмените настройки поиска":
      "No measurements found.\nChange the search criteria.",
  "Снять выделение": "Clear selection",
  "Выбрать всё": "Select all",
  "Удаление": "Delete",
  "Удалить безвозвратно выделенные измерения?":
      "Permanently delete the selected measurements?",
  "Удалить промерную вертикаль?\nУдалятся и все измеренные на ней скорости.":
      "Delete the sounding vertical?\nAll velocities measured on it will also be deleted.",
  "Удалить скоростную вертикаль?\nУдалятся все измеренные на ней скорости, результаты промерных работ сохранятся.":
      "Delete the velocity vertical?\nAll velocities measured on it will be deleted. Sounding data will be retained.",
  "Рекомендуется не менее 20 промерных вертикалей":
      "At least 20 sounding verticals are recommended",
  "Режим ввода": "Input units",
  "Значение в метрах": "Value in metres",
  "Значение в сантиметрах": "Value in centimetres",
  "Укажите начальный берег:": "Select the starting bank:",
  "Добавьте промерные вертикали:": "Add sounding verticals:",
  "Расст., м": "Distance, m",
  "Расст.\nм": "Distance\nm",
  "Глуб., м": "Depth, m",
  "Глуб.\nм": "Depth\nm",
  "Глуб.ср, м": "Mean depth, m",
  "Глуб₁, м": "Depth 1, m",
  "Глуб₂, м": "Depth 2, m",
  "Глуб.1, м": "Depth 1, m",
  "Глуб.2, м": "Depth 2, m",
  "Тип дна": "Bed material",
  "Берег": "Bank",
  "Таблица промерных вертикалей": "Sounding verticals",
  "Таблица скоростных вертикалей": "Velocity verticals",
  "Нажмите на значение глубины, чтобы его изменить☝️":
      "Tap a depth value to edit it ☝️",
  "Перемещайте таблицу в стороны👉": "Scroll the table horizontally 👉",
  "Выполнять обратный ход промеров необязательно. Расчёт средних глубин на вертикалях произойдёт автоматически при переходе к измерению скоростей.":
      "A return sounding survey is optional. Mean depths will be calculated automatically when proceeding to velocity measurements.",
  "Перейти к измерению скоростей": "Proceed to velocity measurements",
  "Введите уровень воды на начало измерения скоростей":
      "Enter the water level at the start of velocity measurements",
  "Введите лопастной диаметр вертушки":
      "Enter the current-meter rotor diameter",
  "Лопастной диаметр вертушки, см": "Current-meter rotor diameter, cm",
  "Диаметр в сантиметрах, например 5": "Diameter in centimetres, e.g. 5",
  "Диаметр не задан": "Diameter not set",
  "Чтобы добавить промерную вертикаль в список скоростных, выберите её и нажмите ниже кнопку «Добавить». ЛБ и ПБ выбрать нельзя.":
      "To add a sounding vertical to the velocity list, select it and tap Add below. Banks cannot be selected.",
  "Выберите промерные вертикали для добавления":
      "Select sounding verticals to add",
  "Скоростные вертикали пока не добавлены": "No velocity verticals added yet",
  "Режим подсказок": "Instrument position",
  "Расст. от дна": "Above bed",
  "Глуб.": "Depth",
  "Подсказка": "Hint",
  "См. таблицу выше": "See the table above",
  "Коэффициент для ЛБ": "Left-bank coefficient",
  "Коэффициент для ПБ": "Right-bank coefficient",
  "Коэффициент для скоростей на прибрежных вертикалях":
      "Edge-section velocity coefficient",
  "Мёртвое пространство": "Dead-water zone",
  "Пологий берег с нулевой глубиной на урезе; вблизи границы скопления неподвижной шуги":
      "Sloping bank with zero depth at the water edge; near stationary frazil ice accumulation",
  "Обрывистый берег или неровная стенка (бут, неотёсанный камень)":
      "Steep bank or rough wall (rubble or uncut stone)",
  "Гладкая бетонная или сплошь обшитая досками стенка; течение воды поверх льда":
      "Smooth concrete or timber-lined wall; water flowing over ice",
  "Рассчитать расход воды": "Calculate discharge",
  "Не все поля заполнены": "Complete all required fields",
  "Не все обязательные поля заполнены": "Complete all required fields",
  "Не все скоростные вертикали заполнены":
      "Not all velocity verticals have sufficient data",
  "Добавьте хотя бы одну скоростную вертикаль":
      "Add at least one velocity vertical",
  "Есть промерные вертикали без глубины":
      "Some sounding verticals have no depth",
  "Есть промерные вертикали на одном расстоянии":
      "Some sounding verticals have the same distance",
  "На введённом расстоянии уже есть промерная вертикаль":
      "A sounding vertical already exists at this distance",
  "ЛБ и ПБ находятся не по берегам":
      "The left and right banks must be the outermost verticals",
  "Широта, °": "Latitude, °",
  "Долгота, °": "Longitude, °",
  "Получаем координаты…": "Getting coordinates…",
  "Координаты не получены. Их можно ввести вручную или обновить позже":
      "Coordinates unavailable. Enter them manually or retry later.",
  "Нет разрешения на геолокацию": "Location permission not granted",
  "Скопировать координаты": "Copy coordinates",
  "Координаты скопированы": "Coordinates copied",
  "Не удалось создать измерение": "Could not create measurement",
  "Не удалось сохранить измерение. Попробуйте ещё раз.":
      "Could not save measurement. Please try again.",
  "Не удалось экспортировать измерение": "Could not export measurement",
  "Не удалось создать PDF. Проверьте, что все фотографии доступны и на устройстве есть свободное место.":
      "Could not create PDF. Check that all photos are available and there is free storage space.",
  "CSV расчёта расхода воды": "Water discharge CSV",
  "CSV-файлы расчёта расхода воды": "Water discharge CSV files",
  "PDF-отчёт": "PDF report",
  "PDF-отчёт расчёта расхода воды": "Water discharge PDF report",
  "PDF-отчёты расчёта расхода воды": "Water discharge PDF reports",
  "Поделиться CSV": "Share CSV",
  "Экспорт PDF": "Export PDF",
  "Экспорт выбранных в PDF": "Export selected to PDF",
  "Создаём CSV…": "Creating CSV…",
  "Создаём PDF…": "Creating PDF…",
  "Недостаточно данных для графика": "Insufficient data for the chart",
  "Обозначения": "Legend",
  "B – Ширина водного сечения": "B – Cross-section width",
  "ω – Площадь поперечного сечения": "ω – Cross-sectional area",
  "hср – Средняя глубина": "hmean – Mean depth",
  "hmax – Максимальная глубина": "hmax – Maximum depth",
  "χ – Смоченный периметр": "χ – Wetted perimeter",
  "R – Гидравлический радиус": "R – Hydraulic radius",
  "Uпоп – средняя скорость на поперечном сечении":
      "Ucross – Cross-sectional mean velocity",
  "Предупреждения": "Warnings",
  "После поправки уровня часть глубин стала меньше нуля и была принята равной 0. Проверьте изменение уровня воды и форму береговой зоны.":
      "After water-level correction, some depths became negative and were set to 0. Check the water-level change and bank geometry.",
  "Краевые отсеки имеют частичные расходы, превышающие 30% от частичных расходов основной зоны живого сечения [прибрежные скоростные вертикали выбраны слишком далеко от берега].":
      "Edge-section discharges exceed 30% of the main flow-section discharges [the outer velocity verticals may be too far from the banks].",
  "Часовой пояс (UTC)": "Time zone (UTC)",
  "UTC: не сохранён (старая запись)": "UTC: not recorded (legacy record)",
  "Дата и время создания файла": "Creation date and time",
  "Начало промерных работ": "Sounding start",
  "Конец промерных работ": "Sounding end",
  "Начало измерения скоростей": "Velocity measurement start",
  "Конец измерения скоростей": "Velocity measurement end",
  "Уровень воды на начало промерных работ": "Water level at sounding start",
  "Уровень воды на конец промерных работ": "Water level at sounding end",
  "Уровень воды на начало измерения скоростей течения":
      "Water level at velocity measurement start",
  "Уровень воды на конец измерения скоростей течения":
      "Water level at velocity measurement end",
  "Средний уровень воды во время промерных работ, м":
      "Mean water level during sounding, m",
  "Средний уровень воды во время измерения скоростей, м":
      "Mean water level during velocity measurements, m",
  "Средний уровень во время промеров, м": "Mean water level during sounding, m",
  "Средний уровень во время измерения скоростей, м":
      "Mean water level during velocity measurements, m",
  "Поправка уровня воды, м": "Water-level correction, m",
  "Поправка уровня, м": "Water-level correction, m",
  "Ширина водного сечения, м": "Cross-section width, m",
  "Площадь водного сечения потока, м2": "Cross-sectional area, m2",
  "Средняя скорость потока, м/с": "Mean flow velocity, m/s",
  "Смоченный периметр между промерными вертикалями, м":
      "Wetted perimeter between sounding verticals, m",
  "Смоченный периметр, м": "Wetted perimeter, m",
  "Средняя глубина, м": "Mean depth, m",
  "Максимальная глубина, м": "Maximum depth, m",
  "Гидравлический радиус, м": "Hydraulic radius, m",
  "Береговой коэффициент (ЛБ)": "Left-bank coefficient",
  "Береговой коэффициент (ПБ)": "Right-bank coefficient",
  "Коэффициент ЛБ": "Left-bank coefficient",
  "Коэффициент ПБ": "Right-bank coefficient",
  "Расстояние от постоянного начала, м": "Distance from reference point, m",
  "Глубина на вертикали (1 измерение), м":
      "Depth at vertical (first sounding), m",
  "Глубина на вертикали (2 измерение), м":
      "Depth at vertical (second sounding), m",
  "Глубина на вертикали (средняя), м": "Mean depth at vertical, m",
  "Глубина на вертикали (средняя) с поправкой, м":
      "Corrected mean depth at vertical, m",
  "Дата и время 1 промера": "First sounding date and time",
  "Дата и время 2 промера": "Second sounding date and time",
  "Площадь водного сечения между промерными вертикалями, м2":
      "Area between sounding verticals, m2",
  "Площадь водного сечения между промерными вертикалями с поправкой, м2":
      "Corrected area between sounding verticals, m2",
  "Площадь отсеков водного сечения, м2": "Subsection areas, m2",
  "Площадь отсека, м²": "Subsection area, m²",
  "Частичный расход воды, м3/с": "Subsection discharge, m3/s",
  "Частичный расход, м³/с": "Subsection discharge, m³/s",
  "Время измерения": "Measurement time",
  "Источник метода": "Method source",
  "Код формулы": "Formula ID",
  "Формула": "Formula",
  "Особые условия": "Special conditions",
  "Применённые формулы": "Applied formulas",
  "Вертикали": "Verticals",
  "Ведомость расчёта расхода воды": "Water discharge measurement report",
  "Характеристики створа": "Cross-section characteristics",
  "B — Ширина водного сечения, м": "B — Cross-section width, m",
  "ω — Площадь поперечного сечения, м²": "ω — Cross-sectional area, m²",
  "hср — Средняя глубина, м": "hmean — Mean depth, m",
  "hmax — Максимальная глубина, м": "hmax — Maximum depth, m",
  "χ — Смоченный периметр, м": "χ — Wetted perimeter, m",
  "R — Гидравлический радиус, м": "R — Hydraulic radius, m",
  "Uпоп — средняя скорость на поперечном сечении, м/с":
      "Ucross — Cross-sectional mean velocity, m/s",
  "Добавить из галереи": "Add from gallery",
  "Сделать фото": "Take photo",
  "Фотографии не добавлены": "No photos added",
  "Нажмите на фото, чтобы увеличить": "Tap a photo to enlarge",
  "Закрыть фотографию": "Close photo",
  "Не удалось добавить фото. Проверьте доступ к камере или галерее.":
      "Could not add photo. Check camera or gallery access.",
  "Не удалось восстановить фото после закрытия камеры":
      "Could not recover photo after closing the camera",
  "Не удалось сохранить комментарий": "Could not save caption",
  "Не удалось удалить фотографию. Попробуйте ещё раз.":
      "Could not delete photo. Please try again.",
  "Некорректное имя фотографии": "Invalid photo filename",
  "Подпись к фотографии": "Photo caption",
  "Удаление фото": "Delete photo",
  "Удалить фото": "Delete photo",
  "Удалить фотографию из измерения?": "Remove this photo from the measurement?",
  "Фотография недоступна": "Photo unavailable",
  "Можно добавить не более 10 фотографий": "You can add up to 10 photos",
  "Скопировать почту": "Copy email",
  "Почта скопирована": "Email copied",
  "Приложение Олега Лошкова, студента кафедры гидрологии суши географического факультета МГУ имени М. В. Ломоносова. Разработка: 2025/26 и 2026/27 учебные годы. Методическая основа: МИ 1759-87 и ВМО № 168. Отзывы и предложения о поддержке:":
      "Created by Oleg Loshkov, a student at the Department of Hydrology, Faculty of Geography, Lomonosov Moscow State University. Developed in the 2025/26 and 2026/27 academic years. Based on MI 1759-87 and WMO No. 168. Feedback and sponsorship enquiries:",
  "Уровень воды на начало промерных работ, м":
      "Water level at sounding start, m",
  "Уровень воды на конец промерных работ, м": "Water level at sounding end, m",
  "Уровень воды на начало измерения скоростей течения, м":
      "Water level at velocity measurement start, m",
  "Уровень воды на конец измерения скоростей течения, м":
      "Water level at velocity measurement end, m",
  "Uпов, м/с": "Usur, m/s",
  "Дата и время измерения Uпов": "Date and time of Usur",
  "U_пов, м/с": "U_surface, m/s",
  "Дата и время измерения U_пов": "Date and time of U_surface",
  "Uдно, м/с": "Ubed, m/s",
  "Дата и время измерения Uдно": "Date and time of Ubed",
  "U_дно, м/с": "U_bed, m/s",
  "Дата и время измерения U_дно": "Date and time of U_bed",
  "Uср, м/с": "Umean, m/s",
  "Дата и время измерения Uср": "Date and time of Umean",
  "U_ср, м/с": "U_mean, m/s",
  "Дата и время измерения U_ср": "Date and time of U_mean",
  "U0.15h, м/с": "U0.15h, m/s",
  "Дата и время измерения U0.15h": "Date and time of U0.15h",
  "U_0.15h, м/с": "U_0.15h, m/s",
  "Дата и время измерения U_0.15h": "Date and time of U_0.15h",
  "U0.2h, м/с": "U0.2h, m/s",
  "Дата и время измерения U0.2h": "Date and time of U0.2h",
  "U_0.2h, м/с": "U_0.2h, m/s",
  "Дата и время измерения U_0.2h": "Date and time of U_0.2h",
  "U0.4h, м/с": "U0.4h, m/s",
  "Дата и время измерения U0.4h": "Date and time of U0.4h",
  "U_0.4h, м/с": "U_0.4h, m/s",
  "Дата и время измерения U_0.4h": "Date and time of U_0.4h",
  "U0.5h, м/с": "U0.5h, m/s",
  "Дата и время измерения U0.5h": "Date and time of U0.5h",
  "U_0.5h, м/с": "U_0.5h, m/s",
  "Дата и время измерения U_0.5h": "Date and time of U_0.5h",
  "U0.6h, м/с": "U0.6h, m/s",
  "Дата и время измерения U0.6h": "Date and time of U0.6h",
  "U_0.6h, м/с": "U_0.6h, m/s",
  "Дата и время измерения U_0.6h": "Date and time of U_0.6h",
  "U0.8h, м/с": "U0.8h, m/s",
  "Дата и время измерения U0.8h": "Date and time of U0.8h",
  "U_0.8h, м/с": "U_0.8h, m/s",
  "Дата и время измерения U_0.8h": "Date and time of U_0.8h",
  "U0.85h, м/с": "U0.85h, m/s",
  "Дата и время измерения U0.85h": "Date and time of U0.85h",
  "U_0.85h, м/с": "U_0.85h, m/s",
  "Дата и время измерения U_0.85h": "Date and time of U_0.85h",
  "Фотографии": "Photos",
  "Листайте фото свайпом": "Swipe to browse photos",
  "Фотография": "Photo",
  "Координаты": "Coordinates",
  "Выбрано": "Selected",
  "Расстояние": "Distance",
  "Дата и время начала промерных работ": "Sounding start date and time",
  "Укажите второй берег": "Select the second bank",
  "Указать второй берег": "Set the second bank",
  "Расст.": "Distance",
  "Глуб₁.": "Depth 1",
  "Глуб₂.": "Depth 2",
  "Глубина 1": "Depth 1",
  "Глубина 2": "Depth 2",
  "Рекомендуемое минимальное число скоростных вертикалей":
      "Recommended minimum number of velocity verticals",
  "Уровень воды во время промерных работ": "Water level during sounding",
  "Уровень воды во время измерения скоростей":
      "Water level during velocity measurements",
  "Изменение уровня": "Water-level change",
  "Лопастной диаметр вертушки": "Current-meter rotor diameter",
  "ср": "mean",
  "поп": "cross",
};
