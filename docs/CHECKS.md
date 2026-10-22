# Что проверяет PLAYSIN TWEAK CHECK

Здесь все проверки, стоковые значения, с которыми идёт сравнение, и оценка, которую получает настройка, если она изменена. Если значения в реестре нет, это считается стоком: так Windows ведёт себя по умолчанию.

**Оценки:** **Польза** реально даёт производительность или снижает задержку. **Плацебо** ничего не меняет или эффект на уровне погрешности. **Спорно** зависит от железа и игр. **Вред** делает систему медленнее или нестабильнее. **Опасно** вредит безопасности: на скорость почти не влияет, но открывает систему вирусам. **Инфо** показывается для сведения и оценки не получает.

Внутри чекер ещё делит проверки на твики (только через реестр, команду или скрипт) и ручные настройки (есть в Параметрах). В отчёте этого не видно, но по твикам считается вывод, оптимизировали ли систему.

Сокращения путей: `MM` = `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`, `MEM` = `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`, `CDM` = `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`.

## Система

| Оценка | Проверка | Где | Сток |
|:--|:--|:--|:--|
| Спорно | Приоритет активной программы | `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation` | 2 или 24 |
| Плацебо | Планировщик игр MMCSS | `MM\SystemResponsiveness`, `MM\Tasks\Games`: GPU Priority, Priority, Scheduling Category, SFIO Priority | 20, 8, 2, Medium, Normal |
| Спорно | Приоритет процессов через IFEO | `Image File Execution Options\*\PerfOptions\CpuPriorityClass` | нет ни у одной программы |
| Плацебо | Мгновенные меню и автозагрузка | `HKCU\Control Panel\Desktop\MenuShowDelay`, `Explorer\Serialize\StartupDelayInMSec`, `WaitForIdleState` | 400, нет, нет |
| Вред | Принудительное закрытие при выключении | `AutoEndTasks`, `WaitToKillServiceTimeout` | 0, 5000 |
| Плацебо | Короткие тайм-ауты зависших программ | `HungAppTimeout`, `WaitToKillAppTimeout`, `LowLevelHooksTimeout` | 5000, 20000, 5000 |
| Плацебо, на ноутбуке спорно | Power Throttling | `Control\Power\PowerThrottling\PowerThrottlingOff` | 0 |
| Плацебо | Группировка svchost | `Control\SvcHostSplitThresholdInKB` | 3670016 |
| Вред | Большой системный кэш | `MEM\LargeSystemCache` | 0 |
| Вред | Очистка подкачки при выключении | `MEM\ClearPageFileAtShutdown` | 0 |
| Плацебо | Ядро без подкачки | `MEM\DisablePagingExecutive` | 0 |
| Плацебо | Prefetch и Superfetch | `MEM\PrefetchParameters`: EnablePrefetcher, EnableSuperfetch | 3, 3 |
| Плацебо | NTFS | `Control\FileSystem`: NtfsDisableLastAccessUpdate, NtfsDisable8dot3NameCreation, NtfsMemoryUsage | под управлением системы, 2, 0 или 1 |
| Спорно | Таймер | `Session Manager\kernel\GlobalTimerResolutionRequests` | 0 |
| Плацебо | Очередь ввода | `mouclass\Parameters\MouseDataQueueSize`, `kbdclass\Parameters\KeyboardDataQueueSize` | 100, 100 |
| Плацебо | Старое меню правой кнопки (Win11) | `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` | раздела нет |
| Вред при 8 ГБ и меньше, иначе плацебо | Менеджер памяти (с правами) | `Get-MMAgent`: MemoryCompression, PageCombining | вкл, вкл |
| Вред, если подкачки нет, иначе плацебо | Файл подкачки | `MEM\PagingFiles` | по выбору системы |
| Плацебо | Визуальные эффекты и прозрачность | VisualFXSetting, EnableTransparency, TaskbarAnimations, EnableAeroPeek | 0 или 1, 1, 1, 1 |
| Польза | Залипание клавиш и повтор клавиатуры | `StickyKeys\Flags`, `Keyboard\KeyboardDelay` | 510, 1 |
| Польза | Акселерация мыши выкл | `HKCU\Control Panel\Mouse\MouseSpeed` | 1 |

## Видеокарта и игры

| Оценка | Проверка | Где | Сток |
|:--|:--|:--|:--|
| Польза | Game DVR выкл политикой | `Policies\Microsoft\Windows\GameDVR\AllowGameDVR` | нет |
| Спорно | FSO выкл для всех игр | `HKCU\System\GameConfigStore`: GameDVR_HonorUserFSEBehaviorMode, GameDVR_DXGIHonorFSEWindowsCompatible, GameDVR_EFSEFeatureFlags | 0, 0, 0 |
| Вред при TdrLevel 0, иначе спорно | Задержки драйвера видеокарты | `Control\GraphicsDrivers`: TdrDelay, TdrLevel, TdrDdiDelay | нет |
| Польза | Фоновая запись Game Bar выкл | `GameConfigStore\GameDVR_Enabled` | 1 |
| Спорно | Игровой режим выкл | `HKCU\Software\Microsoft\GameBar\AutoGameModeEnabled` | 1 |
| Польза | Оптимизация оконных игр | `DirectX\UserGpuPreferences\DirectXUserGlobalSettings` | без SwapEffectUpgradeEnable=1 |
| Инфо | HAGS и MSI mode | `GraphicsDrivers\HwSchMode`, `MSISupported` | драйверы часто включают сами |

## Питание и загрузчик

| Оценка | Проверка | Сток |
|:--|:--|:--|
| Высокая и максимальная: польза, на ноутбуке спорно. Экономия: вред. Своя схема: спорно | Схема питания | «Сбалансированная» |
| След | Свои схемы питания, кроме активной | только схемы Windows |
| Плацебо | Гибернация выкл (`powercfg /h off`) | включена |
| Польза | Быстрый запуск выкл | `HiberbootEnabled` = 1 |
| Спорно | `bcdedit` disabledynamictick | не задан |
| Вред | `bcdedit` useplatformclock (принудительный HPET) | не задан |
| Плацебо | `bcdedit` useplatformtick, tscsyncpolicy, x2apicpolicy | не заданы |
| Спорно | `bcdedit` hypervisorlaunchtype Off | не задан |
| Опасно | `bcdedit` nx AlwaysOff (DEP выкл) | не задан |

## Сеть

| Оценка | Проверка | Сток |
|:--|:--|:--|
| Плацебо | `MM\NetworkThrottlingIndex` | 10 |
| Польза | Политика `DeliveryOptimization\DODownloadMode` | нет |
| Плацебо | Политика `Psched\NonBestEffortLimit` | нет |
| Плацебо | `Tcpip\Parameters`: DefaultTTL, Tcp1323Opts, TcpMaxDupAcks, MaxUserPort, TcpTimedWaitDelay, SackOpts, TcpNoDelay, TcpAckFrequency, MaxConnectionsPerServer | нет |
| Плацебо | Nagle: TcpAckFrequency, TCPNoDelay, TcpDelAckTicks на интерфейсах | нет |
| Вред при Disabled и Restricted, иначе спорно | Автонастройка окна TCP (`Get-NetTCPSetting`) | Normal |
| Спорно | Настройки драйвера каждой сетевой карты: InterruptModeration, ITR, FlowControl, EEE и Green Ethernet, энергосбережение, LSO, RSS, буферы, offload, Wake on LAN, Jumbo | значение `default` из `Ndi\params` самого драйвера |

## Телеметрия, реклама, Bing

| Оценка | Проверка | Сток |
|:--|:--|:--|
| Плацебо | Политики телеметрии: AllowTelemetry, DoNotShowFeedbackNotifications, AITEnable, DisableInventory, история активности, Windows Error Reporting, NumberOfSIUFInPeriod | нет |
| Плацебо | Политики поиска: DisableSearchBoxSuggestions, DisableWebSearch, ConnectedSearchUseWeb, AllowCortana | нет |
| Польза | Win11: виджеты, Copilot, Recall политиками. Win10: «Новости и интересы» | нет |
| Польза, спорно если выключен сон вкладок | Политики Edge и Chrome: StartupBoost, BackgroundMode, SleepingTabs, HighEfficiencyMode | нет или 1 |
| Плацебо | Задачи телеметрии: 18 задач Application Experience, CEIP, Autochk, DiskDiagnostic, Feedback, WER, Maps, CloudExperienceHost, Power Efficiency, NetTrace, Device Information | выключено меньше двух |
| Плацебо | Реклама и предложения: рекламный ID, `CDM` (SilentInstalledApps, SystemPaneSuggestions, SoftLanding, SubscribedContent-*), персонализированный опыт | 1 |
| Плацебо | Фоновые приложения: GlobalUserDisabled | 0 |

## Службы

Считается изменением, если служба отключена (Start = 4). В чистой Windows ни одна из них не отключена.

**Опасно:** wuauserv, UsoSvc, BITS, WaaSMedicSvc (без них не приходят обновления безопасности), WinDefend, SecurityHealthService, wscsvc (защита), mpssvc (брандмауэр).

**Вред:** EventLog, Schedule. Без них ломаются другие службы, обслуживание и программы.

**Спорно:** WSearch, SysMain (зависит от HDD или SSD), XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc (ломаются игры Xbox и геймпады).

**Плацебо:** все остальные. DiagTrack, dmwappushservice, WerSvc, PcaSvc, DPS, WdiServiceHost, WdiSystemHost, diagnosticshub.standardcollector.service, MapsBroker, lfsvc, RetailDemo, WMPNetworkSvc, TrkWks, Fax, Spooler, PrintNotify, bthserv, BTAGService, BthAvctpSvc, TermService, UmRdpService, SessionEnv, WbioSrvc, SCardSvr, ScDeviceEnum, SCPolicySvc, Themes, iphlpsvc, lmhosts, SSDPSRV, upnphost, PhoneSvc, wisvc, WpcMonSvc, RmSvc, DoSvc, HvHost, vmic* (9 служб Hyper-V).

## Защита и обновления

| Оценка | Проверка | Сток |
|:--|:--|:--|
| Опасно | UAC: `EnableLUA` | 1 |
| Спорно | VBS через реестр: `DeviceGuard\EnableVirtualizationBasedSecurity` | нет или 1 |
| Опасно | Spectre и Meltdown: FeatureSettingsOverride, FeatureSettingsOverrideMask | нет |
| Опасно | Defender политиками: DisableAntiSpyware, DisableAntiVirus, DisableRealtimeMonitoring, DisableBehaviorMonitoring, SpynetReporting, SubmitSamplesConsent | нет, 0 или значения, которые оставляют защиту включённой |
| Опасно | SmartScreen политикой: `EnableSmartScreen` | нет или 1 |
| Плацебо | Defender: ScanAvgCPULoadFactor | 50 |
| Опасно, если исключён диск или системная папка, иначе спорно | Исключения Defender (с правами) | нет |
| Опасно, если обновления заблокированы, иначе спорно | Политики обновлений: NoAutoUpdate, AUOptions, NoAutoRebootWithLoggedOnUsers, DisableWindowsUpdateAccess, SetDisableUXWUAccess, DeferFeatureUpdates, TargetReleaseVersion, ExcludeWUDriversInQualityUpdate | нет |
| Спорно | Обновления на паузе | не на паузе |
| Инфо | Работает ли VBS сейчас | |

## Приложения

| Оценка | Проверка | Сток |
|:--|:--|:--|
| Плацебо | Удалены встроенные приложения из 15 стандартных (Store, Калькулятор, Фото, Game Bar, Погода, Будильник, Камера, Центр отзывов, Solitaire, Ножницы, Записки, Звукозапись, Медиаплеер, App Installer, Справка) | удалено меньше трёх. От пяти считается твиком |
| Вред | Microsoft Store удалён | на месте |
| Плацебо | Microsoft Edge удалён | на месте |

Редакции LTSC, IoT и Server пропускаются: в них этих приложений нет изначально.

## Следы оптимизаторов

- Бэкапы паков PLAYSIN (`C:\PLAYSIN333`, `C:\PRIVATE`): дата первого запуска, число запусков, был ли откат.
- Файлы и папки с говорящими именами (boost, optimize, tweak, твик, debloat, fps, input lag, latency, timer resolution, ISLC, Process Lasso, Bitsum, Atlas, ReviOS, Ghost Spectre, tiny11, winutil, ShutUp10 и другие) в корне диска, на рабочем столе, в загрузках, документах, Program Files, ProgramData и AppData.
- Файлы `.reg`, `.nip` (профили NVIDIA Profile Inspector) и `.pow` (схемы питания).
- Установленные программы-оптимизаторы и запущенные процессы (Process Lasso, ISLC, TimerResolution, Mem Reduct, Razer Cortex и другие).
- Задачи планировщика не от Microsoft с такими именами или командами.
- Ярлыки откатов и игровых режимов на рабочем столе.
- Точки восстановления с говорящими названиями (с правами).
- Сборки Windows, подписанные в сведениях о производителе или владельце.
- Файл hosts с 10 и больше записями (блокировка телеметрии или рекламы).
