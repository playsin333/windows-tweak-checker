# Что проверяет PLAYSIN TWEAK CHECK

Здесь все проверки и стоковые значения, с которыми идёт сравнение. Если значения в реестре нет, это считается стоком: так Windows ведёт себя по умолчанию.

**Твик** значит, что так можно сделать только через реестр, команду или скрипт. **Ручн** значит, что это меняется в Параметрах или Панели управления. **Инфо** показывается для сведения и в итог не идёт.

Сокращения путей: `MM` = `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`, `MEM` = `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`, `CDM` = `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`.

## Система

| Вид | Проверка | Где | Сток |
|:--|:--|:--|:--|
| Твик | Приоритет активной программы | `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation` | 2 или 24 |
| Твик | Планировщик игр MMCSS | `MM\SystemResponsiveness`, `MM\Tasks\Games`: GPU Priority, Priority, Scheduling Category, SFIO Priority | 20, 8, 2, Medium, Normal |
| Твик | Приоритет процессов через IFEO | `Image File Execution Options\*\PerfOptions\CpuPriorityClass` | нет ни у одной программы |
| Твик | Мгновенные меню и автозагрузка | `HKCU\Control Panel\Desktop\MenuShowDelay`, `Explorer\Serialize\StartupDelayInMSec`, `WaitForIdleState` | 400, нет, нет |
| Твик | Быстрое закрытие зависших программ | `AutoEndTasks`, `HungAppTimeout`, `WaitToKillAppTimeout`, `LowLevelHooksTimeout`, `WaitToKillServiceTimeout` | 0, 5000, 20000, 5000, 5000 |
| Твик | Power Throttling | `Control\Power\PowerThrottling\PowerThrottlingOff` | 0 |
| Твик | Группировка svchost | `Control\SvcHostSplitThresholdInKB` | 3670016 |
| Твик | Память | `MEM`: LargeSystemCache, DisablePagingExecutive, ClearPageFileAtShutdown, PrefetchParameters\EnablePrefetcher, EnableSuperfetch | 0, 0, 0, 3, 3 |
| Твик | NTFS | `Control\FileSystem`: NtfsDisableLastAccessUpdate, NtfsDisable8dot3NameCreation, NtfsMemoryUsage | под управлением системы, 2, 0 или 1 |
| Твик | Таймер | `Session Manager\kernel\GlobalTimerResolutionRequests` | 0 |
| Твик | Очередь ввода | `mouclass\Parameters\MouseDataQueueSize`, `kbdclass\Parameters\KeyboardDataQueueSize` | 100, 100 |
| Твик | Старое меню правой кнопки (Win11) | `HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32` | раздела нет |
| Твик | Менеджер памяти (с правами) | `Get-MMAgent`: MemoryCompression, PageCombining | вкл, вкл |
| Ручн | Файл подкачки | `MEM\PagingFiles` | по выбору системы |
| Ручн | Визуальные эффекты и прозрачность | VisualFXSetting, EnableTransparency, TaskbarAnimations, EnableAeroPeek | 0 или 1, 1, 1, 1 |
| Ручн | Залипание клавиш и повтор клавиатуры | `StickyKeys\Flags`, `Keyboard\KeyboardDelay` | 510, 1 |
| Ручн | Акселерация мыши | `HKCU\Control Panel\Mouse\MouseSpeed` | 1 |

## Видеокарта и игры

| Вид | Проверка | Где | Сток |
|:--|:--|:--|:--|
| Твик | Game DVR выкл политикой | `Policies\Microsoft\Windows\GameDVR\AllowGameDVR` | нет |
| Твик | FSO выкл для всех игр | `HKCU\System\GameConfigStore`: GameDVR_HonorUserFSEBehaviorMode, GameDVR_DXGIHonorFSEWindowsCompatible, GameDVR_EFSEFeatureFlags | 0, 0, 0 |
| Твик | Задержки драйвера видеокарты | `Control\GraphicsDrivers`: TdrDelay, TdrLevel, TdrDdiDelay | нет |
| Ручн | Фоновая запись Game Bar | `GameConfigStore\GameDVR_Enabled` | 1 |
| Ручн | Игровой режим | `HKCU\Software\Microsoft\GameBar\AutoGameModeEnabled` | 1 |
| Ручн | Оптимизация оконных игр | `DirectX\UserGpuPreferences\DirectXUserGlobalSettings` | без SwapEffectUpgradeEnable=1 |
| Инфо | HAGS и MSI mode | `GraphicsDrivers\HwSchMode`, `MSISupported` | драйверы часто включают сами |

## Питание и загрузчик

| Вид | Проверка | Сток |
|:--|:--|:--|
| Твик / Ручн | Схема питания | «Сбалансированная». Высокая производительность и экономия = Ручн, максимальная и свои схемы = Твик |
| След | Свои схемы питания, кроме активной | только схемы Windows |
| Твик | Гибернация выкл (`powercfg /h off`) | включена |
| Ручн | Быстрый запуск | `HiberbootEnabled` = 1 |
| Твик | `bcdedit` (с правами): disabledynamictick, useplatformclock, useplatformtick, tscsyncpolicy, hypervisorlaunchtype Off, x2apicpolicy, nx AlwaysOff | не заданы |

## Сеть

| Вид | Проверка | Сток |
|:--|:--|:--|
| Твик | `MM\NetworkThrottlingIndex` | 10 |
| Твик | Политика `DeliveryOptimization\DODownloadMode` | нет |
| Твик | Политика `Psched\NonBestEffortLimit` | нет |
| Твик | `Tcpip\Parameters`: DefaultTTL, Tcp1323Opts, TcpMaxDupAcks, MaxUserPort, TcpTimedWaitDelay, SackOpts, TcpNoDelay, TcpAckFrequency, MaxConnectionsPerServer | нет |
| Твик | Nagle: TcpAckFrequency, TCPNoDelay, TcpDelAckTicks на интерфейсах | нет |
| Твик | Автонастройка окна TCP (`Get-NetTCPSetting`) | Normal |
| Твик | Настройки драйвера каждой сетевой карты: InterruptModeration, ITR, FlowControl, EEE и Green Ethernet, энергосбережение, LSO, RSS, буферы, offload, Wake on LAN, Jumbo | значение `default` из `Ndi\params` самого драйвера |

## Телеметрия, реклама, Bing

| Вид | Проверка | Сток |
|:--|:--|:--|
| Твик | Политики телеметрии: AllowTelemetry, DoNotShowFeedbackNotifications, AITEnable, DisableInventory, история активности, Windows Error Reporting, NumberOfSIUFInPeriod | нет |
| Твик | Политики поиска: DisableSearchBoxSuggestions, DisableWebSearch, ConnectedSearchUseWeb, AllowCortana | нет |
| Твик | Win11: виджеты, Copilot, Recall политиками. Win10: «Новости и интересы» | нет |
| Твик | Политики Edge и Chrome: StartupBoost, BackgroundMode, SleepingTabs, HighEfficiencyMode | нет |
| Твик | Задачи телеметрии: 18 задач Application Experience, CEIP, Autochk, DiskDiagnostic, Feedback, WER, Maps, CloudExperienceHost, Power Efficiency, NetTrace, Device Information | выключено меньше двух |
| Ручн | Реклама и предложения: рекламный ID, `CDM` (SilentInstalledApps, SystemPaneSuggestions, SoftLanding, SubscribedContent-*), персонализированный опыт | 1 |
| Ручн | Фоновые приложения: GlobalUserDisabled | 0 |

## Службы

Твик, если служба отключена (Start = 4). В чистой Windows ни одна из них не отключена.

DiagTrack, dmwappushservice, WerSvc, PcaSvc, DPS, WdiServiceHost, WdiSystemHost, diagnosticshub.standardcollector.service, MapsBroker, lfsvc, RetailDemo, WMPNetworkSvc, TrkWks, Fax, Spooler, PrintNotify, bthserv, BTAGService, BthAvctpSvc, XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, TermService, UmRdpService, SessionEnv, WbioSrvc, SCardSvr, ScDeviceEnum, SCPolicySvc, WSearch, SysMain, Themes, iphlpsvc, lmhosts, SSDPSRV, upnphost, PhoneSvc, wisvc, WpcMonSvc, RmSvc, DoSvc, HvHost, vmic* (9 служб Hyper-V).

Отдельно помечаются опасные: wuauserv, UsoSvc, BITS, WaaSMedicSvc, WinDefend, SecurityHealthService, wscsvc, mpssvc, EventLog, Schedule. Без них ломаются обновления или защита.

## Защита и обновления

| Вид | Проверка | Сток |
|:--|:--|:--|
| Твик | UAC: `EnableLUA` | 1 |
| Твик | VBS через реестр: `DeviceGuard\EnableVirtualizationBasedSecurity` | нет или 1 |
| Твик | Spectre и Meltdown: FeatureSettingsOverride, FeatureSettingsOverrideMask | нет |
| Твик | Defender политиками: DisableAntiSpyware, DisableAntiVirus, DisableRealtimeMonitoring, DisableBehaviorMonitoring, SpynetReporting, SubmitSamplesConsent | нет |
| Твик | SmartScreen политикой | нет |
| Твик | Defender: ScanAvgCPULoadFactor | 50 |
| Ручн | Исключения Defender (с правами) | нет |
| Твик | Политики обновлений: NoAutoUpdate, AUOptions, NoAutoRebootWithLoggedOnUsers, DisableWindowsUpdateAccess, SetDisableUXWUAccess, DeferFeatureUpdates, TargetReleaseVersion, ExcludeWUDriversInQualityUpdate | нет |
| Ручн | Обновления на паузе | не на паузе |
| Инфо | Работает ли VBS сейчас | |

## Приложения

| Вид | Проверка | Сток |
|:--|:--|:--|
| Ручн / Твик | Удалены встроенные приложения из 15 стандартных (Store, Калькулятор, Фото, Game Bar, Погода, Будильник, Камера, Центр отзывов, Solitaire, Ножницы, Записки, Звукозапись, Медиаплеер, App Installer, Справка) | удалено меньше трёх. От пяти считается твиком |
| Твик | Microsoft Store удалён | на месте |
| Твик | Microsoft Edge удалён | на месте |

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
