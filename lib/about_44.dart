part of 'main.dart';

class Project44 {
  static const version = '4.4.0';
  static const build = '11';
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
  static String get citation =>
      '$author. $name. ${tr('Версия')} $version. 2026. ${doi.isEmpty ? repository : 'https://doi.org/$doi'}';
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

class AboutScreen44 extends StatelessWidget {
  const AboutScreen44({super.key});
  @override
  Widget build(BuildContext context) {
    final en = appLanguage == 'en';
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
    final intro = en
        ? 'Water Discharge Calculator (WDC) is an application for recording, processing and storing hydrometric measurements and calculating water discharge.\n\nDeveloped in 2025–2026 by Oleg Loshkov, a student of the Department of Land Hydrology, Faculty of Geography, Lomonosov Moscow State University.\n\nThe methodological basis includes MI 1759-87 and the WMO Guide to Hydrological Practices, WMO-No. 168, sixth edition.\n\nThis app was vibe-coded with the help of an AI assistant.\n\nWDC is open-source software licensed under Apache License 2.0. The author welcomes scientific and professional cooperation, commercial proposals, sponsorship and other initiatives.'
        : '«Калькулятор расходов воды» (КРВ) — приложение для ввода, обработки и сохранения данных гидрометрических измерений и расчёта расхода воды.\n\nРазработано в 2025–2026 гг. Олегом Лошковым, студентом кафедры гидрологии суши географического факультета Московского государственного университета имени М. В. Ломоносова.\n\nМетодическая основа — МИ 1759-87 и Руководство по гидрологической практике ВМО № 168, шестая редакция.\n\nПриложение навайбкожено с помощью ИИ-ассистента.\n\nКРВ — открытое программное обеспечение под лицензией Apache License 2.0. Автор открыт для научного и профессионального сотрудничества, коммерческих предложений, спонсорской поддержки и других инициатив.';
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
          Text(intro),
          const SizedBox(height: 16),
          Text(tr('Проект'), style: Theme.of(context).textTheme.titleMedium),
          row(
            'Исходный код',
            Icons.code,
            () => page(
              'Исходный код',
              en
                  ? 'The source code is available in the official GitHub repository. You may study, use, modify and redistribute it, including commercially, subject to Apache License 2.0.'
                  : 'Исходный код доступен в официальном репозитории GitHub. Его можно изучать, использовать, изменять и распространять, в том числе коммерчески, при соблюдении Apache License 2.0.',
              actions: [link('Открыть GitHub', Project44.repository)],
            ),
          ),
          row(
            'Обратная связь',
            Icons.feedback_outlined,
            () => page(
              'Обратная связь',
              en
                  ? 'Report interface errors, unexpected calculation results, methodological concerns or feature suggestions through GitHub Issues. Include the app version, steps to reproduce and expected result. Issues are public after the repository is published: do not attach confidential measurements, coordinates or photos. For private enquiries, contact the author by email.'
                  : 'Сообщайте об ошибках интерфейса, неожиданных результатах расчёта, методических вопросах и предложениях через GitHub Issues. Укажите версию, действия для воспроизведения и ожидаемый результат. После публикации репозитория обсуждения общедоступны: не прикладывайте конфиденциальные измерения, координаты и фотографии. Для личных вопросов напишите автору.',
              actions: [
                link('Создать Issue', '${Project44.issues}/new/choose'),
                link('Написать автору', 'mailto:${Project44.email}'),
                const SelectableText(Project44.email),
              ],
            ),
          ),
          row(
            'Цитировать КРВ',
            Icons.format_quote,
            () => page(
              'Цитировать КРВ',
              (en
                      ? 'If WDC contributed to your research, please cite the version used. Citation is a request, not an additional licence condition.\n\n'
                      : 'Если КРВ использовался в исследовании, автор будет признателен за цитирование использованной версии. Это просьба, а не дополнительное условие лицензии.\n\n') +
                  Project44.citation,
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: Project44.citation),
                    );
                    if (context.mounted) showSnack(context, tr('Скопировано'));
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(tr('Скопировать')),
                ),
                if (Project44.doi.isNotEmpty)
                  link('Открыть DOI', 'https://doi.org/${Project44.doi}'),
              ],
            ),
          ),
          row(
            'Поддержать проект',
            Icons.favorite_outline,
            () => page(
              'Поддержать проект',
              en
                  ? 'WDC is free to use. You can support development with feedback, test cases, documentation, translations or code contributions. The author welcomes cooperation and sponsorship. Contact the author to discuss support. Voluntary support does not unlock extra features or grant additional software rights.'
                  : 'КРВ распространяется бесплатно. Поддержать развитие можно обратной связью, контрольными примерами, документацией, переводами и исправлениями кода. Автор открыт для сотрудничества и спонсорской поддержки. Для обсуждения поддержки свяжитесь с автором. Добровольная поддержка не открывает дополнительные функции и не предоставляет дополнительных прав на программу.',
              actions: [
                if (Project44.donation.isNotEmpty)
                  link('Поддержать проект', Project44.donation),
                link('Написать автору', 'mailto:${Project44.email}'),
              ],
            ),
          ),
          const Divider(),
          Text(
            tr('Информация'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          row(
            'Методическая основа',
            Icons.menu_book,
            () => page(
              'Методическая основа',
              en
                  ? 'MI 1759-87: discharge measurements in rivers and canals using the velocity–area method.\n\nWorld Meteorological Organization. Guide to Hydrological Practices. WMO-No. 168. Sixth edition.\n\nThe application implements and automates selected procedures; it does not implement every case in these publications. Check the selected velocity formula, bank coefficients and suitability of the cross section. Multi-channel sections are not supported. Bank extrapolation is an assumption outside the surveyed profile.'
                  : 'МИ 1759-87: измерение расхода воды в реках и каналах методом «скорость — площадь».\n\nВсемирная метеорологическая организация. Руководство по гидрологической практике. ВМО № 168. Шестое издание.\n\nПриложение реализует и автоматизирует отдельные процедуры, а не все случаи из этих источников. Проверяйте выбранные формулы скоростей, береговые коэффициенты и пригодность створа. Расчёт нескольких рукавов не поддерживается. Экстраполяция берегов является предположением за пределами измеренного профиля.',
            ),
          ),
          row(
            'История версий',
            Icons.history,
            () => page(
              'История версий',
              en
                  ? '4.4\nLight and dark themes; separate About screen and legal documents; bed type and ice thickness entry; ice profile; water-level geometry and bank extrapolation; protection against invalid dry velocity verticals; improved exports and depth-edit confirmation.\n\n4.3\nImproved sounding entry, depth hints, result tables and language switching.\n\n4.2\nMeasurement transfer using .krv archives.'
                  : '4.4\nСветлая и тёмная темы; отдельный экран «О приложении» и документы; ввод типа дна и толщины льда; график льда; пересчёт геометрии при изменении уровня и экстраполяция берегов; защита от осушенных скоростных вертикалей; улучшения экспорта и подтверждение изменения глубин.\n\n4.3\nУлучшены ввод промеров, подсказки глубин, таблицы результатов и переключение языка.\n\n4.2\nПеренос измерений через архивы .krv.',
              actions: [
                link(
                  'Полная история изменений',
                  '${Project44.repository}/blob/main/CHANGELOG.md',
                ),
              ],
            ),
          ),
          const Divider(),
          Text(
            tr('Правовая информация'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          row('Лицензия Apache 2.0', Icons.description_outlined, () async {
            final license = await rootBundle.loadString('assets/legal/LICENSE');
            if (context.mounted) {
              page(
                'Лицензия Apache 2.0',
                '© 2025–2026 Oleg Loshkov (Олег Лошков)\n\n$license',
              );
            }
          }),
          row(
            'Политика конфиденциальности',
            Icons.privacy_tip_outlined,
            () => page('Политика конфиденциальности', privacy44(en)),
          ),
          row(
            'Условия использования',
            Icons.info_outline,
            () => page('Условия использования', terms44(en)),
          ),
          row(
            'Лицензии стороннего ПО',
            Icons.account_tree_outlined,
            () => showLicensePage(
              context: context,
              applicationName: Project44.name,
              applicationVersion: Project44.version,
              applicationLegalese: '© 2025–2026 Oleg Loshkov',
            ),
          ),
          const SizedBox(height: 16),
          Text('© 2025–2026 ${Project44.author}', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String privacy44(bool en) => en
    ? '''Privacy Policy
Updated: 8 October 2026

WDC does not require an account. Measurement data, comments, coordinates, photos and calculations are stored and processed on your device. The app has no developer-operated server, advertising, analytics or automatic crash-reporting service. The developer does not automatically receive your measurement data.

Location is requested when you use coordinate retrieval, including when creating a measurement with automatic location enabled in Settings. There is no background tracking. Location permissions and system location services are controlled by your operating system.

Camera and photo selection are used at your request to attach photos. Attached copies and captions are stored with the measurement. Exported photos may contain original metadata, including location recorded by the camera.

Import reads a file you select. CSV, PDF and .krv exports may contain coordinates, comments and other measurement data; .krv and PDF can include photos. You choose whether and where to share files. Recipient apps and services handle them under their own policies.

Android or the device manufacturer may back up or transfer app data according to your device and account settings. WDC does not operate this service; the developer has no access to those backups. Keep your own .krv copies of important measurements.

Deleting measurements removes their stored app copies; exported files, files already shared, source photos and external backups are not deleted. Clearing app storage or uninstalling removes local app data, subject to system backup and restore behaviour.

Opening GitHub, email or a support link uses an external app or website. Those services may process network and account information. Information you send to the author is used to respond to your enquiry. Public Issues are visible to other users.

This policy will be updated if data handling changes. Contact: ${Project44.email}
Official repository: ${Project44.repository}'''
    : '''Политика конфиденциальности
Обновлено: 8 октября 2026 г.

КРВ не требует регистрации. Данные измерений, комментарии, координаты, фотографии и результаты расчётов хранятся и обрабатываются на вашем устройстве. В приложении нет сервера разработчика, рекламы, аналитики и автоматической отправки отчётов о сбоях. Разработчик не получает данные измерений автоматически.

Местоположение запрашивается при использовании определения координат, в том числе при создании измерения, если в настройках включено автоматическое получение координат. Фоновое отслеживание не выполняется. Разрешения и системные службы геолокации управляются операционной системой.

Камера и выбор фотографий используются по вашему действию для прикрепления снимков. Копии снимков и подписи хранятся вместе с измерением. Экспортируемые фотографии могут содержать исходные метаданные, включая координаты, записанные камерой.

Импорт читает выбранный вами файл. Экспорт CSV, PDF и .krv может включать координаты, комментарии и другие данные измерения; .krv и PDF также могут включать фотографии. Получателя и способ передачи выбираете вы. Дальнейшая обработка регулируется правилами выбранного приложения или сервиса.

Android или производитель устройства может выполнять резервное копирование и перенос данных согласно настройкам устройства и учётной записи. КРВ не управляет этим сервисом, разработчик не имеет доступа к таким копиям. Для важных измерений сохраняйте собственные архивы .krv.

Удаление измерения удаляет его копии в хранилище приложения. Экспортированные и уже отправленные файлы, исходные фотографии и внешние резервные копии не удаляются. Очистка хранилища или удаление приложения удаляет локальные данные с учётом механизмов системного резервного копирования и восстановления.

Открытие GitHub, почты и ссылок поддержки использует внешние приложения или сайты. Они могут обрабатывать сетевые данные и сведения об учётной записи. Информация, которую вы отправляете автору, используется для ответа на обращение. Публичные Issues доступны другим пользователям.

При изменении обработки данных политика будет обновлена. Контакт: ${Project44.email}
Официальный репозиторий: ${Project44.repository}''';

String terms44(bool en) => en
    ? '''Terms of Use

WDC is a tool for recording, processing and calculating hydrometric measurements. It does not replace professional judgement, applicable measurement procedures or equipment instructions.

Results depend on the quality and completeness of observations, equipment condition, selected formula and coefficients. Users must check inputs and the suitability of the method. Verify results before using them in research, engineering or official reporting. Extrapolated banks are estimates, not field observations. Multi-channel discharge calculation is not supported.

The software is provided under Apache License 2.0, without warranties to the extent permitted by applicable law. Its warranty and liability provisions apply; these terms do not override mandatory legal rights. The developer seeks to correct defects but cannot guarantee absence of errors or compatibility with every device.

Users decide whether results are suitable for their task. Report suspected calculation or interface errors via GitHub Issues or ${Project44.email}.'''
    : '''Условия использования

КРВ — инструмент ввода, обработки и расчёта данных гидрометрических измерений. Приложение не заменяет профессиональную оценку, требования применяемых методик и инструкции к оборудованию.

Результаты зависят от качества и полноты наблюдений, состояния оборудования, выбранных формул и коэффициентов. Пользователь проверяет исходные данные и пригодность метода. Перед использованием в исследованиях, инженерных решениях и официальной отчётности проверяйте результаты. Достроенные берега являются расчётным предположением, а не полевыми наблюдениями. Расчёт расхода для нескольких рукавов не поддерживается.

Программа предоставляется под Apache License 2.0 без гарантий в пределах, допускаемых применимым законодательством. Действуют положения этой лицензии о гарантиях и ответственности; настоящие условия не отменяют обязательные права, установленные законом. Разработчик стремится исправлять ошибки, но не гарантирует их полного отсутствия и совместимости со всеми устройствами.

Решение о пригодности результатов для конкретной задачи принимает пользователь. О возможных ошибках расчёта и интерфейса сообщайте через GitHub Issues или ${Project44.email}.''';
