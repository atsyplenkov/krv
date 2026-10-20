part of 'main.dart';

class Project44 {
  static const version = '4.6';
  static const releaseVersion = '4.6.0';
  static const build = '14';
  static const email = 'olegegkas@gmail.com';
  static const repository = 'https://github.com/olegegka/krv';
  static const issues = '$repository/issues';
  static const doi = '';
  static const donation = '';
  static String get name => appLanguage == 'en'
      ? 'Water Discharge Calculator'
      : 'Калькулятор расходов воды';
  static String get author =>
      appLanguage == 'en' ? 'Oleg Loshkov' : 'Олег Лошков';
  static String get citation => citation45(iso: appLanguage == 'en');
}

String citation45({required bool iso, DateTime? date}) {
  final now = date ?? DateTime.now();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (iso) {
    return 'LOSHKOV, O. D., 2026. Water Discharge Calculator [mobile application]. Version 4.6. Electronic data. GitHub. Available from: ${Project44.repository} [Accessed ${now.day} ${months[now.month - 1]} ${now.year}]';
  }
  return 'О. Д. Лошков. Калькулятор расходов воды : [Электронный ресурс] : мобильное приложение / разработчик О. Д. Лошков. – Версия 4.6. – Электрон. дан. – [Б. м.] : GitHub, 2026. – URL: ${Project44.repository} (дата обращения: ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}).';
}

Future<void> openExternal44(BuildContext context, String url) async {
  try {
    await const MethodChannel(
      'krv.app/actions',
    ).invokeMethod<void>('openUrl', url);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      showSnack(context, tr('Ссылка скопирована. Откройте её в браузере.'));
    }
  }
}

String aboutText45(String key) =>
    (appLanguage == 'en' ? aboutEnglish45 : aboutRussian45)[key]!;
String privacy44(bool en) => (en ? aboutEnglish45 : aboutRussian45)['privacy']!;
String terms44(bool en) => (en ? aboutEnglish45 : aboutRussian45)['terms']!;

class AboutScreen44 extends StatelessWidget {
  const AboutScreen44({super.key});
  @override
  Widget build(BuildContext context) {
    void page(String title, String body, {List<Widget> actions = const []}) =>
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(tr(title))),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SelectableText(body),
                  const SizedBox(height: 16),
                  ...actions,
                ],
              ),
            ),
          ),
        );
    Widget link(String label, String url) => TextButton.icon(
      onPressed: () => openExternal44(context, url),
      icon: const Icon(Icons.open_in_new),
      label: Text(tr(label)),
    );
    Widget row(String title, IconData icon, VoidCallback tap) => ListTile(
      leading: Icon(icon),
      title: Text(tr(title)),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    );
    final email = link('Написать автору', 'mailto:${Project44.email}');
    final repo = link('Открыть код на GitHub', Project44.repository);
    final issue = link('Создать Issue', '${Project44.issues}/new/choose');
    return Scaffold(
      appBar: AppBar(title: Text(tr('О приложении'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 112,
              height: 112,
            ),
          ),
          Text(
            Project44.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${tr('Версия')} ${Project44.version} · ${tr('Сборка')} ${Project44.build}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(aboutText45('intro')),
          const SizedBox(height: 16),
          Text(tr('Проект'), style: Theme.of(context).textTheme.titleMedium),
          row(
            'Исходный код',
            Icons.code,
            () => page('Исходный код', aboutText45('source'), actions: [repo]),
          ),
          row(
            'Методическая основа',
            Icons.menu_book,
            () => page('Методическая основа', aboutText45('method')),
          ),
          row(
            'Обратная связь',
            Icons.feedback_outlined,
            () => page(
              'Обратная связь',
              aboutText45('feedback'),
              actions: [issue, email],
            ),
          ),
          row(
            'Цитировать КРВ',
            Icons.format_quote,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CitationScreen45()),
            ),
          ),
          row(
            'Поддержать проект',
            Icons.favorite_outline,
            () => page(
              'Поддержать проект',
              aboutText45('support'),
              actions: [email],
            ),
          ),
          const Divider(),
          Text(
            tr('Правовая информация'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          row(
            'Лицензия Apache 2.0',
            Icons.description_outlined,
            () => page(
              'Лицензия Apache 2.0',
              appLanguage == 'en'
                  ? '© 2025–2026 Oleg Loshkov\n\nApache License 2.0 permits use, modification and distribution, including commercial use, subject to its terms. The software is provided without warranties. The full licence is included in the app and is available offline.'
                  : '© 2025–2026 Олег Лошков\n\nApache License 2.0 разрешает использование, изменение и распространение, в том числе коммерческое, при соблюдении её условий. Программа предоставляется без гарантий. Полный текст лицензии включён в приложение и доступен без интернета.',
              actions: [
                TextButton(
                  onPressed: () async {
                    final license = await rootBundle.loadString(
                      'assets/legal/LICENSE',
                    );
                    if (context.mounted) page('Лицензия Apache 2.0', license);
                  },
                  child: Text(tr('Полная версия')),
                ),
              ],
            ),
          ),
          row(
            'Политика конфиденциальности',
            Icons.privacy_tip_outlined,
            () => page(
              'Политика конфиденциальности',
              aboutText45('privacy'),
              actions: [email, repo],
            ),
          ),
          row(
            'Условия использования',
            Icons.info_outline,
            () => page(
              'Условия использования',
              aboutText45('terms'),
              actions: [issue, email],
            ),
          ),
          row(
            'Лицензии стороннего ПО',
            Icons.account_tree_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LicensesScreen45()),
            ),
          ),
          const SizedBox(height: 16),
          Text('© 2025–2026 ${Project44.author}', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class CitationScreen45 extends StatefulWidget {
  const CitationScreen45({super.key});
  @override
  State<CitationScreen45> createState() => _CitationScreen45State();
}

class _CitationScreen45State extends State<CitationScreen45>
    with WidgetsBindingObserver {
  Timer? midnight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    schedule();
  }

  void schedule() {
    midnight?.cancel();
    final now = DateTime.now();
    midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (mounted) {
          setState(() {});
          schedule();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      schedule();
    }
  }

  @override
  void dispose() {
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Цитировать КРВ'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          appLanguage == 'en'
              ? 'If WDC was used in scientific research, the author would appreciate a citation.'
              : 'Если КРВ использовался в научных исследованиях, автор будет признателен за цитирование.',
        ),
        for (final iso in [if (appLanguage != 'en') false, true]) ...[
          const SizedBox(height: 20),
          Text(
            iso ? 'ISO 690' : 'ГОСТ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SelectableText(
            citation45(iso: iso),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: citation45(iso: iso)),
              );
              if (context.mounted) {
                setState(() {});
                showSnack(context, tr('Скопировано'));
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(tr('Скопировать')),
          ),
        ],
      ],
    ),
  );
}

// Only byte-identical notice texts are coalesced; every associated package is retained.
Future<Map<String, List<String>>> collectLicenses45() async {
  final notices = <String, Set<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    final body = entry.paragraphs
        .map((p) => '${p.indent > 0 ? '  ' * p.indent : ''}${p.text}')
        .join('\n\n');
    notices.putIfAbsent(body, () => <String>{}).addAll(entry.packages);
  }
  return {for (final e in notices.entries) e.key: e.value.toList()..sort()};
}

// Flutter groups notices by package and displays long texts on a separate page.
// Avoid placing an unbounded SelectableText inside an expanding scrolling row.
class LicensesScreen45 extends StatelessWidget {
  const LicensesScreen45({super.key});

  @override
  Widget build(BuildContext context) => LicensePage(
    applicationName: Project44.name,
    applicationVersion: Project44.version,
    applicationLegalese: '© 2025–2026 Oleg Loshkov',
  );
}

const aboutRussian45 = <String, String>{
  "intro":
      "«Калькулятор расходов воды» (КРВ) – приложение для ввода, обработки и сохранения данных гидрометрических измерений и расчёта расходов воды.\n\nПриложение навайбкожено в 2025—2026 гг. Олегом Лошковым, студентом кафедры гидрологии суши географического факультета Московского государственного университета имени М. В. Ломоносова.\n\nМетодическую основу расчётной части составляют «Методические Указания. Расход воды на реках и каналах. Методика выполнения измерений методом «скорость – площадь» МИ 1759-87» и «Руководство по гидрологической практике, ВМО № 168, 6 редакция».\n\nКРВ развивается как открытое программное обеспечение. Исходный код проекта публикуется в открытом доступе и может свободно использоваться, изменяться и распространяться в соответствии с условиями лицензии Apache License 2.0.\n\nАвтор заинтересован в развитии приложения и открыт для предложений по сотрудничеству, научному и практическому применению КРВ, спонсорской поддержке и другим инициативам.",
  "source":
      "«Калькулятор расходов воды» является проектом с открытым исходным кодом.\n\nОн доступен в официальном репозитории проекта на GitHub. Его можно изучать, использовать в собственных проектах, изменять, распространять и создавать на его основе производные работы, в том числе для коммерческого использования, при соблюдении условий лицензии Apache License 2.0.",
  "feedback":
      "КРВ развивается как открытый проект, и обратная связь помогает сделать приложение точнее, удобнее и полезнее для гидрологических исследований и полевых работ.\n\nМожно сообщить о:\n\nобнаруженной ошибке;\n\nнекорректном или неожиданном результате расчёта;\n\nпроблеме интерфейса;\n\nпредложении новой функции;\n\nпредложении по улучшению расчётной методики;\n\nошибке или неточности в документации;\n\nдругих проблемах и предложениях.\n\nДля технических вопросов и предложений предпочтительно использовать GitHub Issues – так обсуждение остаётся доступным другим пользователям и разработчикам.\n\nЕсли вопрос содержит данные, которые пользователь не хочет публиковать открыто, можно связаться с автором по электронной почте olegegkas@gmail.com.",
  "support":
      "КРВ распространяется бесплатно и не имеет платных функций.\n\nПоддержать развитие проекта можно даже обратной связью, но автор открыт для сотрудничества и спонсорской поддержки. Среди важных дел, требующих финансирования – доступность приложения в AppStore. По всем вопросам поддержки можете связаться с автором по почте olegegkas@gmail.com:",
  "method":
      "В основу расчётной части приложения легли:\n\nМетодические Указания. Расход воды на реках и каналах. Методика выполнения измерений методом «скорость – площадь» МИ 1759-87.\n\nРуководство по гидрологической практике, ВМО № 168, 6 редакция.\n\nПри этом приложение оставляет пользователю свободу. Например, можно изменять весовые коэффициенты, назначаемые скоростям течения на разных глубинах на скоростной вертикали при расчёте средней скорости на ней на трёх уровнях: на уровне всего приложения (для всех новых измерений), на уровне одного измерения расхода воды (для всех скоростных вертикалей в этом измерении) и для каждой скоростной вертикали.\n\nПомимо этого, существуют некоторые авторские дополнения — например, возможность выбора способа достраивания берегов при повышении уровня воды между промерными работами и измерением скоростей.",
  "privacy":
      "Политика конфиденциальности\n\nПоследнее обновление: 17.10.2026\n\nКРВ не требует регистрации. Данные измерений, комментарии, фотографии и результаты расчётов хранятся и обрабатываются на устройстве пользователя. У приложения нет сервера, рекламы и аналитики, разработчик не получает доступ к данным измерений пользователей.\n\nСведения о местоположении запрашиваются в момент определения координат створа, в том числе, при создании нового измерения, если в настройках включено автоматическое получение координат. Фоновое отслеживание не выполняется. Разрешения и системные службы геолокации управляются операционной системой.\n\nДоступ к камере и выбранным фотографиям предоставляется только по инициативе пользователя. Копии снимков хранятся вместе с измерением. Экспортируемые фотографии могут содержать метаданные, включая координаты, если соответствующие настройки включены в телефоне пользователя.\n\nФункция импорта измерений читает только выбранный пользователем файл. Экспортируемые файлы .csv, .pdf и .krv могут включать координаты, комментарии и другие данные измерения; .pdf и .krv также могут включать фотографии. Получателя и способ передачи выбирает пользователь. Дальнейшая обработка регулируется правилами выбранного приложения или сервиса.\n\nAndroid или производитель устройства может выполнять резервное копирование и перенос данных согласно настройкам устройства и учётной записи. КРВ не управляет этим процессом, разработчик не имеет доступа к таким копиям. Для важных измерений пользователь может сохранять собственные архивы .krv.\n\nУдаление измерения удаляет его копии в хранилище приложения, экспортированные и уже отправленные файлы, исходные фотографии и внешние резервные копии не удаляются. Очистка хранилища или удаление приложения удаляет локальные данные с учётом механизмов системного резервного копирования и восстановления.\n\nОткрытие GitHub, почты и ссылок поддержки использует внешние приложения или сайты. Они могут обрабатывать сетевые данные и сведения об учётной записи. Информация, которую пользователь отправляет автору, используется для ответа на обращение. Публичные Issues в GitHub доступны другим пользователям.\n\nПри изменении способа обработки данных политика будет обновлена.\n\nКонтакт с автором – olegegkas@gmail.com.",
  "terms":
      "КРВ – инструмент ввода, обработки и расчёта данных гидрометрических наблюдений. Приложение не заменяет профессиональную оценку, требования применяемых методик и инструкции к оборудованию.\n\nРезультаты зависят от качества и полноты наблюдений, состояния оборудования, выбранных формул и коэффициентов. Пользователь проверяет исходные данные и пригодность метода. Перед использованием в исследованиях, инженерных решениях и официальной отчётности проверяйте результаты.\n\nПрограмма предоставляется под Apache License 2.0 без гарантий в пределах, допускаемых применимым законодательством. Действуют положения этой лицензии о гарантиях и ответственности; настоящие условия не отменяют обязательные права, установленные законом. Разработчик стремится исправлять ошибки, но не гарантирует их полного отсутствия и совместимости со всеми устройствами.\n\nРешение о пригодности результатов для конкретной задачи принимает пользователь. О возможных ошибках расчёта и интерфейса сообщайте через GitHub Issues или по почте olegegkas@gmail.com.",
};

const aboutEnglish45 = <String, String>{
  "intro":
      "Water Discharge Calculator (WDC) is an application for recording, processing and storing hydrometric measurement data and calculating water discharge.\n\nThe app was vibe-coded in 2025–2026 by Oleg Loshkov, a student in the Department of Land Hydrology, Faculty of Geography, Lomonosov Moscow State University.\n\nThe calculations are based on “Guidelines. Water discharge in rivers and canals. Measurement procedure using the velocity–area method”, MI 1759-87, and the “Guide to Hydrological Practices”, WMO-No. 168, sixth edition.\n\nWDC is being developed as open-source software. The project source code is publicly available and may be freely used, modified and distributed under the terms of the Apache License 2.0.\n\nThe author is interested in developing the app further and welcomes proposals for cooperation, scientific and practical applications of WDC, sponsorship and other initiatives.",
  "source":
      "Water Discharge Calculator is an open-source project.\n\nIts source code is available in the official project repository on GitHub. You may study it, use it in your own projects, modify and redistribute it, and create derivative works, including for commercial use, subject to the terms of the Apache License 2.0.",
  "feedback":
      "WDC is being developed as an open project. Feedback helps make the app more accurate, convenient and useful for hydrological research and fieldwork.\n\nYou can report:\n• a bug;\n• an incorrect or unexpected calculation result;\n• a user interface problem;\n• a suggestion for a new feature;\n• a proposed improvement to a calculation method;\n• an error or inaccuracy in the documentation;\n• other problems or suggestions.\n\nGitHub Issues is the preferred channel for technical questions and suggestions, so that discussions remain available to other users and developers.\n\nIf your enquiry contains information you do not wish to make public, you can contact the author by email at olegegkas@gmail.com.",
  "support":
      "WDC is free and has no paid features.\n\nEven providing feedback helps support the project. The author also welcomes cooperation and sponsorship. Making the app available on the App Store is one of the important tasks that require funding. For any enquiries about supporting the project, please contact the author at olegegkas@gmail.com:",
  "method":
      "The app’s calculations are based on:\n\nGuidelines. Water discharge in rivers and canals. Measurement procedure using the velocity–area method. MI 1759-87.\n\nGuide to Hydrological Practices, WMO-No. 168, sixth edition.\n\nThe app also gives users flexibility. For example, the weights assigned to velocities measured at different depths when calculating the mean velocity in a vertical can be changed at three levels: for the whole app (all new measurements), for a single discharge measurement (all velocity verticals in that measurement), or for an individual velocity vertical.\n\nThere are also additions developed by the author, such as choosing how to extend the bank profile when the water level rises between depth and velocity measurements.",
  "privacy":
      "Privacy Policy\n\nLast updated: 17 October 2026\n\nWDC does not require registration. Measurement data, comments, photographs and calculation results are stored and processed on the user’s device. The app has no server, advertising or analytics, and the developer has no access to users’ measurement data.\n\nLocation information is requested when determining the coordinates of the measurement cross section, including when creating a new measurement if automatic location retrieval is enabled in Settings. There is no background tracking. Location permissions and system location services are managed by the operating system.\n\nThe camera and selected photographs are accessed only at the user’s request. Copies of photographs are stored with the measurement. Exported photographs may contain metadata, including coordinates, if the corresponding settings are enabled on the user’s phone.\n\nThe measurement import feature reads only the file selected by the user. Exported .csv, .pdf and .krv files may contain coordinates, comments and other measurement data; .pdf and .krv files may also contain photographs. The user chooses the recipient and how to share the files. Subsequent processing is governed by the policies of the chosen app or service.\n\nAndroid or the device manufacturer may back up and transfer data according to the device and account settings. WDC does not control this process, and the developer has no access to these backups. Users can keep their own .krv archives of important measurements.\n\nDeleting a measurement removes its copies from the app’s storage. Exported files, files already shared, original photographs and external backups are not deleted. Clearing the app’s storage or uninstalling the app removes local data, subject to the system’s backup and restore mechanisms.\n\nOpening GitHub, email and support links uses external apps or websites. These may process network and account information. Information sent to the author is used to respond to the enquiry. Public GitHub Issues are visible to other users.\n\nThis policy will be updated if the way data is processed changes.\n\nContact the author at olegegkas@gmail.com.",
  "terms":
      "WDC is a tool for recording, processing and calculating hydrometric observation data. The app does not replace professional judgement, the requirements of applicable measurement procedures or equipment instructions.\n\nResults depend on the quality and completeness of observations, the condition of the equipment, and the chosen formulas and coefficients. Users must check the input data and the suitability of the method. Verify results before using them in research, engineering decisions or official reporting.\n\nThe software is provided under the Apache License 2.0, without warranties to the extent permitted by applicable law. The licence provisions on warranties and liability apply; these terms do not override mandatory legal rights. The developer aims to correct errors but cannot guarantee that the software is error-free or compatible with every device.\n\nUsers decide whether the results are suitable for their particular task. Please report suspected calculation or interface errors through GitHub Issues or by email at olegegkas@gmail.com.",
};
