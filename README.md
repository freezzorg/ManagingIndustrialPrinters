# Managing Industrial Printers (mip)
> Android-приложение управления базой промышленных принтеров сервиса PrintComm.
> Проект создан при помощи ~~смекалки и деатомайзера 7-й серии~~ Windsurf.

## Структура проекта

lib/
├── main.dart                       # Запуск приложения и маршруты
├── models/
│   └── printer.dart                # Модель принтера + enum
├── services/
│   └── api_service.dart            # HTTP-запросы к серверу PrintComm
└── screens/
    ├── main_screen.dart            # Стартовая точка
    ├── scanner_screen.dart         # Сканирование QR-кодов и логика привязки
    ├── manual_entry_screen.dart    # Ручной ввод данных принтера
    └── printer_list_screen.dart    # Просмотр и редактирование принтеров