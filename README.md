<p align="center">
  <img src="assets/banner.png" alt="PLAYSIN TWEAK CHECK — твик-чекер для Windows 10 и 11" width="100%">
</p>

<p align="center">
  <a href="https://github.com/playsin333/windows-tweak-checker/releases/latest"><img src="https://img.shields.io/github/v/release/playsin333/windows-tweak-checker?style=for-the-badge&color=22d3ee&label=%D0%B2%D0%B5%D1%80%D1%81%D0%B8%D1%8F" alt="Версия"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge" alt="Windows 10 и 11">
  <img src="https://img.shields.io/badge/%D1%80%D0%B5%D0%B6%D0%B8%D0%BC-%D1%82%D0%BE%D0%BB%D1%8C%D0%BA%D0%BE%20%D1%87%D1%82%D0%B5%D0%BD%D0%B8%D0%B5-4ade80?style=for-the-badge" alt="Только чтение">
  <a href="https://github.com/playsin333/windows-tweak-checker/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/playsin333/windows-tweak-checker/test.yml?style=for-the-badge&label=%D1%82%D0%B5%D1%81%D1%82%20%D0%BD%D0%B0%20Windows" alt="Тест на Windows"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/playsin333/windows-tweak-checker?style=for-the-badge&color=6b7280&label=%D0%BB%D0%B8%D1%86%D0%B5%D0%BD%D0%B7%D0%B8%D1%8F" alt="Лицензия MIT"></a>
</p>

<h3 align="center">Проверь, оптимизировали ли уже твою Windows.<br>За минуту, без установки и ничего не меняя.</h3>

<p align="center">
  <a href="https://github.com/playsin333/windows-tweak-checker/releases/latest/download/PLAYSIN-TWEAK-CHECK.zip"><img src="https://img.shields.io/badge/%E2%AC%87%20%D0%A1%D0%BA%D0%B0%D1%87%D0%B0%D1%82%D1%8C-PLAYSIN%20TWEAK%20CHECK-22d3ee?style=for-the-badge&labelColor=07090d" alt="Скачать" height="42"></a>
</p>

---

Твик-паки, «бустеры FPS», батники с YouTube, оптимизаторы вроде Process Lasso или Razer Cortex, сборки Windows «для игр». После них в системе остаются изменённые значения реестра, отключённые службы, свои схемы питания и бэкапы. Снаружи этого не видно, а PLAYSIN TWEAK CHECK находит всё это и честно оценивает каждую изменённую настройку: даёт ли она реальную пользу, ничего не делает, зависит от железа, тормозит систему или открывает дыру в защите.

На чистой Windows чекер ничего не найдёт. На оптимизированной покажет, что именно поменяли, где и что из этого работает, а что нет.

## Как это выглядит

<p align="center">
  <img src="assets/demo.png" alt="Пример отчёта твик-чекера" width="860">
</p>

## Как запустить

1. Скачай [**PLAYSIN-TWEAK-CHECK.zip**](https://github.com/playsin333/windows-tweak-checker/releases/latest/download/PLAYSIN-TWEAK-CHECK.zip) и распакуй.
2. Запусти `PLAYSIN TWEAK CHECK.bat` двойным кликом.
3. Windows спросит права администратора, нажми «Да». С ними видно загрузчик, точки восстановления и исключения Defender. Если нажать «Нет», проверка всё равно пройдёт, только без этих пунктов.
4. Через минуту отчёт ляжет на рабочий стол файлом `Твик-чекер <дата>.txt` и сам откроется в блокноте. В нём итог и разбор каждого пункта с объяснением.

> [!TIP]
> Если SmartScreen пишет «Windows защитила ваш компьютер», нажми «Подробнее», потом «Выполнить в любом случае». Так Windows реагирует на любой батник из интернета без цифровой подписи. Код открыт, его можно прочитать прямо здесь перед запуском.

## Как читать результат

Каждая изменённая настройка получает оценку, а под ней одной строкой написано, почему.

| Метка | Что значит |
|:--|:--|
| ![ПОЛЬЗА](https://img.shields.io/badge/%D0%9F%D0%9E%D0%9B%D0%AC%D0%97%D0%90-4ade80?style=flat-square) | Реально даёт производительность или снижает задержку |
| ![ПЛАЦЕБО](https://img.shields.io/badge/%D0%9F%D0%9B%D0%90%D0%A6%D0%95%D0%91%D0%9E-38bdf8?style=flat-square) | Ничего не меняет или эффект на уровне погрешности. Обычно твики из времён Windows XP |
| ![СПОРНО](https://img.shields.io/badge/%D0%A1%D0%9F%D0%9E%D0%A0%D0%9D%D0%9E-facc15?style=flat-square) | На одном железе и в одних играх помогает, в других мешает |
| ![ВРЕД](https://img.shields.io/badge/%D0%92%D0%A0%D0%95%D0%94-ef4444?style=flat-square) | Вредно для производительности: система от этого медленнее или нестабильнее |
| ![ОПАСНО](https://img.shields.io/badge/%D0%9E%D0%9F%D0%90%D0%A1%D0%9D%D0%9E-d946ef?style=flat-square) | Вредно для безопасности: на скорость почти не влияет, но открывает систему вирусам и атакам |
| ![СЛЕД](https://img.shields.io/badge/%D0%A1%D0%9B%D0%95%D0%94-a78bfa?style=flat-square) | След оптимизатора: бэкап, точка восстановления, папка, `.reg`-файл, программа, задача в планировщике |
| ![СТОК](https://img.shields.io/badge/%D0%A1%D0%A2%D0%9E%D0%9A-6b7280?style=flat-square) | Как в чистой Windows |

В консоли идёт только ход проверки и счётчики по разделам. Всё остальное в отчёте: сверху итог со списком опасного, вредного, спорного, плацебо и пользы, ниже разбор по разделам. Советов, что включить, чекер не даёт: он показывает, что у тебя есть, а решаешь ты сам. Исключение одно: если нашлось опасное, он прямо скажет, что это дыра и её стоит закрыть.

Ещё в итоге есть вывод, оптимизировали ли систему: **нет**, **почти чистая** (1–3 точечные правки), **твиков почти нет, но оптимизаторы были** (откатили или не доделали) и **систему уже оптимизировали**, с разбивкой, где именно.

## Что проверяется

| Раздел | Что смотрит |
|:--|:--|
| **Система** | Win32PrioritySeparation, MMCSS и Tasks\Games, приоритеты через IFEO, MenuShowDelay, Power Throttling, svchost, LargeSystemCache и Prefetch, NTFS, GlobalTimerResolutionRequests, очередь мыши и клавиатуры, сжатие памяти, файл подкачки |
| **Видеокарта и игры** | Game DVR, оптимизация во весь экран (FSO), TdrDelay, игровой режим, HAGS и MSI mode для сведения |
| **Питание и загрузчик** | схема питания, свои и импортированные схемы, гибернация, быстрый запуск, `bcdedit`: dynamic tick, HPET, tscsyncpolicy, гипервизор, DEP |
| **Сеть** | NetworkThrottlingIndex, Nagle, параметры TCP/IP, автонастройка окна TCP, QoS, настройки драйвера сетевой карты в сравнении со стоком самого драйвера |
| **Телеметрия и реклама** | политики телеметрии, Bing в поиске, Copilot, Recall, виджеты, политики Edge и Chrome, задачи телеметрии в планировщике |
| **Службы** | около 60 служб, которые любят отключать: телеметрия, Xbox, печать, Bluetooth, Hyper-V, SysMain, поиск и отдельно опасные (обновления, Defender) |
| **Защита и обновления** | UAC, VBS, Spectre и Meltdown, Defender и его политики, SmartScreen, политики и пауза обновлений |
| **Приложения** | массовое удаление встроенных приложений, Microsoft Store, Edge |
| **Следы** | бэкапы паков, папки и файлы оптимизаторов, `.reg`, `.nip` и `.pow` файлы, установленные и запущенные программы, задачи планировщика, точки восстановления, ярлыки откатов, сборки Windows, файл hosts |

Полный список со стоковыми значениями лежит в [docs/CHECKS.md](docs/CHECKS.md).

## Почему ему можно доверять

- **Только чтение.** В коде нет ни одной записи в реестр, службы или задачи. Единственный файл, который создаётся, это отчёт на рабочем столе.
- **Без установки и интернета.** Один `.bat`, внутри обычный PowerShell, ничего не скачивает и никуда не отправляет.
- **Открытый код.** Всё в одном файле: [`PLAYSIN TWEAK CHECK.bat`](PLAYSIN%20TWEAK%20CHECK.bat).
- **Проверяется на настоящей Windows.** Каждое изменение автоматически прогоняется на Windows в [GitHub Actions](https://github.com/playsin333/windows-tweak-checker/actions).

## Вопросы

<details>
<summary><b>На моей чистой Windows нашлось 1–2 твика. Это ошибка?</b></summary>
<br>
Не обязательно. Производители ноутбуков и некоторые программы меняют пару значений сами, а сборки Windows немного отличаются друг от друга. Поэтому 1–3 правки чекер считает «почти чистой системой». Если уверен, что систему никто не трогал, а чекер нашёл твик, <a href="https://github.com/playsin333/windows-tweak-checker/issues/new?template=false-positive.yml">напиши об этом</a>, поправлю сток.
</details>

<details>
<summary><b>Почему мой твик помечен как плацебо?</b></summary>
<br>
Плацебо значит, что на современной Windows этот твик не даёт измеримого прироста: он остался со времён старых систем или влияет на то, что игры не используют. Почему именно, написано в отчёте под самим пунктом. Где результат реально зависит от железа, стоит «спорно», а не «плацебо». Если у тебя есть замеры, где твик даёт разницу, <a href="https://github.com/playsin333/windows-tweak-checker/issues/new?template=new-check.yml">пришли их</a>, пересмотрю оценку.
</details>

<details>
<summary><b>Чекер может что-то сломать?</b></summary>
<br>
Нет. Он только читает. Можно запускать сколько угодно раз, на любом ПК.
</details>

<details>
<summary><b>Зачем права администратора?</b></summary>
<br>
Без них Windows не даёт прочитать загрузчик (<code>bcdedit</code>), точки восстановления, исключения Defender и настройки менеджера памяти. Остальное проверяется и без прав.
</details>

<details>
<summary><b>Работает на Windows 7 или 8.1?</b></summary>
<br>
Нет, только Windows 10 и 11. На старых версиях другие стоковые значения, и проверка врала бы.
</details>

<details>
<summary><b>Нашёл оптимизатор, который чекер не видит</b></summary>
<br>
<a href="https://github.com/playsin333/windows-tweak-checker/issues/new?template=new-check.yml">Предложи проверку</a>: название оптимизатора, что он меняет и какие следы оставляет.
</details>

## Автор

Сделал **playsin333**: оптимизирую Windows под игры и снимаю про это.

[![YouTube](https://img.shields.io/badge/YouTube-@playsin333-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtube.com/@playsin333)
[![TikTok](https://img.shields.io/badge/TikTok-@playsin333-000000?style=for-the-badge&logo=tiktok&logoColor=white)](https://tiktok.com/@playsin333)
[![Telegram](https://img.shields.io/badge/Telegram-playsin333bio-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/playsin333bio)
[![FunPay](https://img.shields.io/badge/FunPay-%D0%BE%D0%BF%D1%82%D0%B8%D0%BC%D0%B8%D0%B7%D0%B0%D1%86%D0%B8%D1%8F%20%D0%BF%D0%BE%D0%B4%20%D0%BA%D0%BB%D1%8E%D1%87-f59e0b?style=for-the-badge)](https://funpay.com/users/21612506/)

Если чекер пригодился, поставь ⭐, так его найдут другие.

<sub>Распространяется по лицензии [MIT](LICENSE).</sub>

<sub>#оптимизация_windows #твики #твик_чекер #fps #инпут_лаг #input_lag #windows_tweaks #windows_optimization #fps_boost #gaming #windows10 #windows11 #debloat #telemetry #powershell #batch #regedit #process_lasso #timer_resolution #msi_mode #mmcss #game_mode #optimization_checker #tweak_checker</sub>
