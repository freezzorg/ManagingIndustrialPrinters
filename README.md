![](https://github.com/freezzorg/ManagingIndustrialPrinters/blob/master/assets/icon/favicon.png)
# Managing Industrial Printers (mip)

### _Android-приложение управления базой промышленных принтеров сервиса PrintComm_
> Проект создан при помощи ~~смекалки и деатомайзера 7-й серии~~ ChatGPT, Grok, Windsurf.
 
## Структура проекта
```markdown
Managing Industrial Printers
├── pubspec.yaml                        # Файл конфигурации проекта
├── analysis_options.yaml               # Файл настроек анализа кода
├── devtools_options.yaml               # Файл настроек devtools
├── mip.iml                             # Файл проекта в IntelliJ IDEA
├── README.md                           # Описание проекта
├── lib/                                # Корень проекта
│   ├── main.dart                       # Запуск приложения и маршруты
│   ├── models/                         # Модели данных
│   │   └── printer.dart                # Модель принтера + enum
│   ├── providers/                      # Провайдеры данных
│   │   └── theme_provider.dart         # Провайдер темы
│   ├── services/                       # Сервисы
│   │   └── api_service.dart            # HTTP-запросы к серверу PrintComm
│   └── screens/                        # Экраны приложения
│       ├── scanner_screen.dart         # Сканирование QR-кодов и логика привязки
│       ├── manual_entry_screen.dart    # Ручное управление данными принтера
│       ├── printer_list_screen.dart    # Просмотр и редактирование принтеров
│       └── settings_screen.dart        # Настройки приложения
└── assets/                             # Иконки приложения
    ├── app_icon_foreground.png         # Иконка приложения
    └── app_icon_background.png         # Фон приложения
```
- Приложение управляет базой промышленных принтеров с помощью QR-кодов на andriod-устройствах.
  - На ТСД (терминал сбора данных) с помощью аппаратного сканера;
  - На обычных смартфонах с помощью камеры .
- Позволяет:
  - Выводить список принтеров;
  - Добавлять принтер в базу;
  - Удалять принтеры из базы;
  - Редактировать данные принтера.