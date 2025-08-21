![](https://github.com/freezzorg/ManagingIndustrialPrinters/blob/master/assets/icon/favicon.png)
# Managing Industrial Printers (mip)

### _Android-приложение управления базой промышленных принтеров сервиса PrintComm_
> Проект создан при помощи ~~смекалки и деатомайзера 7-й серии~~ нейросетей.
 
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
## Информация о проекте
- Приложение управляет базой промышленных принтеров с помощью QR-кодов на andriod-устройствах.
  - На ТСД (терминал сбора данных) с помощью аппаратного сканера;
  - На обычных смартфонах с помощью камеры.
- Позволяет:
  - Выводить список принтеров;
  - Добавлять принтер в базу;
  - Удалять принтеры из базы;
  - Редактировать данные принтера.
- Работа приложения протестирована на:
  - ТСД Zebra MC33;
  - ТСД Urovo RT40;
  - Смартфоне Motorola G84.

## Настройка профилей ТСД
- ТСД Zebra MC33 (DataWedge):
  - Настройка профилей:
    - Название профиля: `MIP`
    - Associated apps: `kz.kcep.mip.MainActivity`
    - Barcode input:
      - Enabled: `Yes`
      - Scanner selected: `Auto (2D Barcode Imager)`
    - Intent output:
      - Enabled: `Yes`
      - Intent action: `kz.kcep.mip.SCAN_EVENT`
      - Intent delivery: `Broadcast intent`
- ТСД Urovo RT40 (ScanWedge):
  - Настройка профилей:
    - Название профиля: `MIP`
    - Associated apps: `kz.kcep.mip.MainActivity`
    - Barcode input:
      - Enabled: `Yes`
    - Вывод со сканера:
      - Включить: `Yes`
    - Режим ввода:
      - Режим вывода: `Intent`
      - Intent action: `android.intent.ACTION_DECODE_DATA`
      - Intent string extra: `barcode_string`
      - Intent raw extra: `barcode`
      - Intent delivery: `Broadcast`
