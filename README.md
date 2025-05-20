# Managing Industrial Printers (mip)
> Android-приложение управления базой промышленных принтеров сервиса PrintComm.
> Проект создан при помощи ~~смекалки и деатомайзера 7-й серии~~ Windsurf и ChatGPT.

## Структура проекта
```markdown
Managing Industrial Printers
├── pubspec.yaml                        # Файл конфигурации проекта
├── analysis_options.yaml               # Файл настроек анализа кода
├── devtools_options.yaml                   # Файл настроек devtools
├── README.md                           # Описание проекта
├── lib/                                # Корень проекта
│   ├── main.dart                       # Запуск приложения и маршруты
│   ├── theme_provider.dart             # Провайдер темы
│   ├── models/                         # Модели данных
│   │   └── printer.dart                # Модель принтера + enum
│   ├── providers/                      # Провайдеры данных
│   │   └── theme_provider.dart         # Темы приложения
│   ├── services/                       # Сервисы
│   │   └── api_service.dart            # HTTP-запросы к серверу PrintComm
│   └── screens/                        # Экраны приложения
│       ├── main_screen.dart            # Стартовая точка
│       ├── scanner_screen.dart         # Сканирование QR-кодов и логика привязки
│       ├── manual_entry_screen.dart    # Ручной ввод данных принтера (редактирование данных принтера и добавление принтера)
│       └── printer_list_screen.dart    # Просмотр и редактирование принтеров
├── assets/                             # Иконки приложения
│   ├── app_icon_foreground.png         # Иконка приложения
│   └── app_icon_background.png         # Фон приложения

