# Участие / Contributing

Сообщайте об ошибках через Issues. Для существенных изменений сначала опишите задачу.
Изменения направляйте отдельной веткой и Pull Request в main. Автоматического слияния нет.
Пожалуйста, обсуждайте предложения уважительно и по существу.

Use a branch and a pull request targeting main. Describe the problem, the change and validation.
Discuss substantial changes in an issue first. Keep discussions respectful and constructive.

## Воспроизводимая проверка / Reproducible checks

Проверенная среда: Flutter 3.41.6, Dart 3.11.4. Установите эту версию Flutter.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
```

Коммитьте pubspec.lock. Обновляйте зависимости отдельно от изменений алгоритма.
Не включайте секреты, APK, личные полевые данные и результаты тестов в исходники.

## Научные расчёты / Scientific calculations

Для изменения расчётов укажите методический источник, единицы, область применимости,
входные значения и независимо вычисленный ожидаемый ответ. Тест не должен получать
эталон вызовом проверяемого алгоритма. Укажите допустимую погрешность и округление.
Сохраняйте исходные наблюдения и явно проверяйте совместимость старых записей.

For numerical changes, provide a methodological reference, units, assumptions and
an independently derived expected result with justified tolerance. Test old records.
AI-generated suggestions require the same checks and maintainer review as other changes.

Предоставляя вклад, вы соглашаетесь распространять его по лицензии Apache-2.0 проекта.
By contributing, you agree to license your contribution under this project's Apache-2.0 license.
