<# :
@echo off
chcp 65001 >nul
set "TC_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:TC_SELF,[Text.Encoding]::UTF8))"
exit /b
:: ============================================================
::  PLAYSIN TWEAK CHECK · by playsin333
::  Бесплатный твик-чекер с открытым кодом:
::  https://github.com/playsin333/windows-tweak-checker
::  Ничего не меняет в системе: только смотрит и пишет отчёт.
::  YouTube: youtube.com/@playsin333
::  Telegram: t.me/playsin333bio
:: ============================================================
#>
# =====================================================================
#  Показывает, оптимизировали ли уже Windows, и оценивает каждую
#  изменённую настройку: польза, плацебо, спорно, вред или опасно.
#  Плюс следы оптимизаторов (бэкапы, точки восстановления, папки, программы).
#  Ничего не пишет ни в реестр, ни в службы, ни в файлы, кроме отчёта
#  на рабочем столе. Верхние строки запускают этот же файл через PowerShell.
# =====================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# @brand-begin
$BR = @{
    Title   = 'PLAYSIN TWEAK CHECK · by playsin333'
    Author  = 'Автор: playsin333 · t.me/playsin333bio'
    Seller  = 'Хочешь купить оптимизацию под ключ: funpay.com/users/21612506'
    Contact = 'Связаться со мной: t.me/playsin333bio'
    Social  = 'YouTube @playsin333 · tiktok.com/@playsin333'
    Repo    = 'Код и новые версии: github.com/playsin333/windows-tweak-checker'
}
# @brand-end

$TcVersion  = '2.0'
$Desktop    = [Environment]::GetFolderPath('Desktop')
if (-not $Desktop) { $Desktop = $env:USERPROFILE }
$ReportPath = Join-Path $Desktop ('Твик-чекер ' + (Get-Date -Format 'dd.MM.yyyy HH-mm') + '.txt')
$Utf8Bom    = New-Object System.Text.UTF8Encoding($true)
$GuidRx     = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$NetClass   = 'HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'

# Имена файлов, папок, задач и точек восстановления, по которым видно оптимизатор
$TraceRx = 'boost|optimi[sz]|оптимиз|tweak|твик|debloat|дебло|\bfps\b|фпс|input.?lag|инпут|latency|playsin|\bhone\b|atlas.?os|atlasmodules|revi.?os|revision.?tool|ameliorat|ghost.?spectre|kernel.?os|winutil|titus|shutup|timer.?res|\bislc\b|standby.?list|bitsum|lasso|mem.?reduct|tiny1[01]|superlite|razer.?cortex|systemcare|auslogics|glary|nvidia.?profile.?inspector|\.nip$|\.pow$'
# Установленные программы-оптимизаторы
$ProgRx = 'process lasso|razer cortex|advanced systemcare|game booster|winoptimizer|boostspeed|glary utilities|\bhone\b|game fire|winaero tweaker|ultimate windows tweaker|tweakpower|timer ?resolution|intelligent standby|mem ?reduct|shutup ?10|playsin|оптимиз'
# Процессы, которые держат такие программы
$ProcRx = '^(processlasso|processgovernor|islc|intelligent standby list cleaner.*|timerresolution|settimerresolution|memreduct|hone|razercortex|gamebooster)$'
# Сборки Windows с вырезанным и подкрученным
$BuildRx = 'atlas|revi.?os|ghost|spectre|tiny1[01]|kernel.?os|\bxos\b|x-?lite|superlite|\blite\b|ameliorat|game.?edition|gaming.?edition|optimi[sz]|оптимиз|сборк|boost'

# ---------------------------------------------------------------------
#  Общие функции: только чтение
# ---------------------------------------------------------------------
function Split-RegPath([string]$Path) {
    $i = $Path.IndexOf('\')
    $hive = $Path.Substring(0, $i).ToUpper()
    switch ($hive) {
        'HKLM'  { [Microsoft.Win32.RegistryHive]::LocalMachine }
        'HKCU'  { [Microsoft.Win32.RegistryHive]::CurrentUser }
        default { throw ('Неизвестный раздел реестра: ' + $hive) }
    }
    $Path.Substring($i + 1)
}

function Open-RegBase($Hive) {
    [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, [Microsoft.Win32.RegistryView]::Registry64)
}

function Get-RegValue([string]$Path, [string]$Name) {
    $h, $sub = Split-RegPath $Path
    $base = Open-RegBase $h
    try {
        $k = $base.OpenSubKey($sub)
        if ($null -eq $k) { return $null }
        try {
            if ($k.GetValueNames() -notcontains $Name) { return $null }
            return [pscustomobject]@{
                Kind  = $k.GetValueKind($Name).ToString()
                Value = $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        } finally { $k.Close() }
    } finally { $base.Close() }
}

function Get-RegSubKeys([string]$Path) {
    $h, $sub = Split-RegPath $Path
    $base = Open-RegBase $h
    try {
        $k = $base.OpenSubKey($sub)
        if ($null -eq $k) { return }
        try { return $k.GetSubKeyNames() } finally { $k.Close() }
    } finally { $base.Close() }
}

function Test-RegKey([string]$Path) {
    $h, $sub = Split-RegPath $Path
    $base = Open-RegBase $h
    try {
        $k = $base.OpenSubKey($sub)
        if ($null -eq $k) { return $false }
        $k.Close()
        return $true
    } finally { $base.Close() }
}

# Значение реестра строкой для сравнения: DWord без знака, Binary в hex, MultiString через перевод строки
function Format-RegData([string]$Kind, $Value) {
    if ($null -eq $Value) { return '' }
    switch ($Kind) {
        'DWord' { $v = [int64]$Value; if ($v -lt 0) { $v += 4294967296 }; return [string]$v }
        'Binary' { return ((@($Value) | ForEach-Object { ([byte]$_).ToString('X2') }) -join '') }
        'MultiString' { return ((@($Value) | ForEach-Object { [string]$_ }) -join "`n") }
        default { return [string]$Value }
    }
}

function Get-RegText([string]$Path, [string]$Name) {
    $v = $null
    try { $v = Get-RegValue $Path $Name } catch {}
    if ($null -eq $v) { return $null }
    return (Format-RegData $v.Kind $v.Value)
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Native([string]$Exe, [string[]]$ArgList) {
    $ErrorActionPreference = 'Continue'
    $out = & $Exe @ArgList 2>&1 | ForEach-Object { [string]$_ }
    [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (ConvertFrom-Json ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8))) } catch { return $null }
}

function Clear-Keys {
    try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch {}
}

function Wait-Key([string]$Text = '  Нажми любую клавишу, чтобы закрыть окно...') {
    # TC_NOWAIT: запуск без человека у экрана, например автотест
    if ($env:TC_NOWAIT) { return }
    Write-Host ''
    Write-Host $Text -ForegroundColor DarkGray
    Clear-Keys
    try { [void][Console]::ReadKey($true) } catch { Start-Sleep -Seconds 5 }
}

function Set-ConsoleLook {
    try { $Host.UI.RawUI.WindowTitle = $BR.Title } catch {}
    try {
        $raw = $Host.UI.RawUI
        if ($raw.WindowSize.Width -lt 110) {
            $buf = $raw.BufferSize
            if ($buf.Width -lt 112) { $buf.Width = 112; $raw.BufferSize = $buf }
            $win = $raw.WindowSize
            $win.Width = [Math]::Min(112, $raw.MaxPhysicalWindowSize.Width)
            $raw.WindowSize = $win
        }
    } catch {}
}

function Format-Date($D) {
    if ($null -eq $D) { return '?' }
    try { return ([datetime]$D).ToString('dd.MM.yyyy HH:mm') } catch { return [string]$D }
}

# ---------------------------------------------------------------------
#  Отчёт. В консоли только ход проверки, в файле всё: оценки, причины, сток
# ---------------------------------------------------------------------
$Items = New-Object System.Collections.ArrayList
$Sections = New-Object System.Collections.ArrayList
$Report = New-Object System.Collections.ArrayList
$script:Cat = ''

# Оценка изменённой настройки. Rank задаёт порядок в отчёте: сначала самое важное
$VD = @{
    Danger  = @{ Tag = 'ОПАСНО';  Name = 'опасно';  Color = 'Magenta';     Rank = 0 }
    Bad     = @{ Tag = 'ВРЕД';    Name = 'вред';    Color = 'Red';         Rank = 1 }
    Mixed   = @{ Tag = 'СПОРНО';  Name = 'спорно';  Color = 'Yellow';      Rank = 2 }
    Placebo = @{ Tag = 'ПЛАЦЕБО'; Name = 'плацебо'; Color = 'DarkCyan';    Rank = 3 }
    Good    = @{ Tag = 'ПОЛЬЗА';  Name = 'польза';  Color = 'Green';       Rank = 4 }
    Trace   = @{ Tag = 'СЛЕД';    Name = 'следы';   Color = 'DarkMagenta'; Rank = 5 }
    Error   = @{ Tag = 'ОШИБ';    Name = 'ошибка';  Color = 'Red';         Rank = 6 }
    Info    = @{ Tag = 'ИНФО';    Name = 'инфо';    Color = 'DarkGray';    Rank = 7 }
}
$VerdictOrder = @('Danger', 'Bad', 'Mixed', 'Placebo', 'Good')
$TraceSection = 'Следы оптимизаторов'

# В консоль и в отчёт
function Out-Line([string]$Text, [string]$Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
    [void]$Report.Add($Text)
}

# Только в отчёт
function Out-Rep([string]$Text) {
    [void]$Report.Add($Text)
}

# Строка из цветных кусков через точку: @(@(текст, цвет), ...)
function Write-Parts($Parts) {
    $first = $true
    foreach ($p in $Parts) {
        if (-not $first) { Write-Host ' · ' -NoNewline -ForegroundColor DarkGray }
        Write-Host $p[0] -NoNewline -ForegroundColor $p[1]
        $first = $false
    }
    Write-Host ''
}

# В консоли у раздела только счётчики, сами пункты в отчёте
function Close-Section {
    if (-not $script:Cat) { return }
    $mine = @($Items | Where-Object { $_.Cat -eq $script:Cat })
    $parts = @()
    foreach ($v in @('Danger', 'Bad', 'Mixed', 'Placebo', 'Good', 'Trace', 'Error')) {
        $n = @($mine | Where-Object { $_.Changed -and $_.Verdict -eq $v }).Count
        if ($n -gt 0) { $parts += , @(($VD[$v].Name + ' ' + $n), $VD[$v].Color) }
    }
    $stock = @($mine | Where-Object { -not $_.Changed -and $_.Verdict -ne 'Info' }).Count
    if ($stock -gt 0) { $parts += , @(('в стоке ' + $stock), 'DarkGray') }
    if ($parts.Count -eq 0) { $parts += , @('ничего не нашёл', 'DarkGray') }
    Write-Parts $parts
    $script:Cat = ''
}

function Section([string]$Title) {
    Close-Section
    $script:Cat = $Title
    [void]$Sections.Add($Title)
    Write-Host (('  » ' + $Title).PadRight(32)) -NoNewline -ForegroundColor Cyan
}

# Kind: Tweak = делается только через реестр, команды или скрипты
#       Setting = можно поменять руками в Параметрах или Панели управления
#       по Kind считается вывод «оптимизировали ли систему», в отчёте его не видно
# Verdict: оценка, если значение изменено (Danger, Bad, Mixed, Placebo, Good)
# Why: почему такая оценка, одной строкой
function Add-Check([string]$Kind, [string]$Verdict, [string]$Title, [bool]$Changed, [string]$Detail = '', [string]$Why = '') {
    [void]$Items.Add([pscustomobject]@{ Idx = $Items.Count; Cat = $script:Cat; Kind = $Kind; Verdict = $Verdict; Title = $Title; Changed = $Changed; Detail = $Detail; Why = $Why })
}

# Для сведения, в итог не идёт
function Add-Info([string]$Title, [string]$Detail) {
    Add-Check Info Info $Title $false $Detail
}

function Add-Trace([string]$Text) {
    Add-Check Trace Trace $Text $true
}

# Группа значений реестра. Spec: 'Путь|Имя|сток', стоковых значений может быть несколько через «/».
# Значения нет = сток: так Windows ведёт себя по умолчанию
function Test-RegGroup([string]$Kind, [string]$Verdict, [string]$Title, [string[]]$Specs, [string]$Why) {
    $diff = @()
    foreach ($s in $Specs) {
        $p = $s.Split('|')
        $now = Get-RegText $p[0] $p[1]
        if ($null -eq $now) { continue }
        $stock = @($p[2].Split('/') | Where-Object { $_ -ne '' })
        if ($stock -contains $now) { continue }
        $shown = Format-Shown $now
        if ($Specs.Count -eq 1) {
            $was = 'значения нет'
            if ($stock.Count -gt 0) { $was = Format-Shown $stock[0] }
            $diff += ($shown + ' (сток: ' + $was + ')')
        } else { $diff += ($p[1] + ' = ' + $shown) }
    }
    $detail = ''
    if ($diff.Count -gt 0) {
        $detail = ($diff | Select-Object -First 3) -join ', '
        if ($diff.Count -gt 3) { $detail += ' и ещё ' + ($diff.Count - 3) }
        if ($Specs.Count -gt 1) { $detail = 'изменено ' + $diff.Count + ' из ' + $Specs.Count + ' (' + $detail + ')' }
    }
    Add-Check $Kind $Verdict $Title ($diff.Count -gt 0) $detail $Why
}

# Большие числа в hex, как их показывает regedit
function Format-Shown([string]$V) {
    if ($V -match '^\d{6,10}$' -and [int64]$V -le 4294967295) { return ('0x' + ([int64]$V).ToString('x8')) }
    return ($V -replace "`n", '; ')
}

# ---------------------------------------------------------------------
#  О компьютере
# ---------------------------------------------------------------------
function Get-SystemInfo {
    $cv = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int](Get-RegText $cv 'CurrentBuildNumber')
    $ubr = Get-RegText $cv 'UBR'
    $isWin11 = $build -ge 22000
    $edition = [string](Get-RegText $cv 'ProductName')
    if ($isWin11) { $edition = $edition -replace 'Windows 10', 'Windows 11' }
    $dv = Get-RegText $cv 'DisplayVersion'
    if ($null -eq $dv) { $dv = Get-RegText $cv 'ReleaseId' }
    $name = $edition
    if ($dv) { $name += ' ' + $dv }
    $name += ' (сборка ' + $build + @{ $true = '.' + $ubr; $false = '' }[[bool]$ubr] + ')'

    $installed = $null
    $it = Get-RegText $cv 'InstallDate'
    if ($it) { $installed = [DateTimeOffset]::FromUnixTimeSeconds([int64]$it).LocalDateTime }

    $os = $null; $cs = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch {}
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch {}
    $cpu = ''
    try { $cpu = ([string](@(Get-CimInstance Win32_Processor -ErrorAction Stop) | Select-Object -First 1).Name).Trim() } catch {}
    $gpu = ''
    try { $gpu = (@(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { [string]$_.PNPDeviceID -match '^PCI\\' } | ForEach-Object { [string]$_.Name }) -join ' + ') } catch {}

    $chassis = @()
    try { $chassis = @(Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop | ForEach-Object { $_.ChassisTypes }) } catch {}
    $isLaptop = @(@(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) | Where-Object { $chassis -contains $_ }).Count -gt 0

    return @{
        Build = $build; IsWin11 = $isWin11; Name = $name; Installed = $installed
        EditionId = [string](Get-RegText $cv 'EditionID')
        Boot = @{ $true = $os.LastBootUpTime; $false = $null }[[bool]$os]
        RamGB = @{ $true = [math]::Round($cs.TotalPhysicalMemory / 1GB); $false = 0 }[[bool]$cs]
        PcName = $env:COMPUTERNAME; Cpu = $cpu; Gpu = $gpu; IsLaptop = $isLaptop
    }
}


function Show-Head($Sys, [bool]$Admin) {
    Clear-Host
    Out-Line ''
    Out-Line ('  ' + $BR.Title + ' · версия ' + $TcVersion) 'Cyan'
    Out-Line ('  ' + $BR.Author) 'Cyan'
    Out-Line '  Ничего не меняет в системе: только смотрит и пишет отчёт на рабочий стол.' 'DarkGray'
    Out-Line ''
    Out-Line ('  Проверка:  ' + (Get-Date -Format 'dd.MM.yyyy HH:mm:ss')) 'White'
    Out-Line ('  Компьютер: ' + $Sys.PcName + @{ $true = ' · ноутбук'; $false = '' }[$Sys.IsLaptop]) 'White'
    Out-Line ('  Windows:   ' + $Sys.Name) 'White'
    Out-Line ('  Установлена или крупно обновлена: ' + (Format-Date $Sys.Installed) + ' · включён с ' + (Format-Date $Sys.Boot)) 'White'
    Out-Line ('  Железо:    ' + $Sys.Cpu + ' · ' + $Sys.Gpu + ' · ' + $Sys.RamGB + ' ГБ') 'White'
    if ($Admin) { Out-Line '  Права администратора есть: проверяю всё.' 'DarkGray' }
    else { Out-Line '  Без прав администратора: загрузчик, сжатие памяти, точки восстановления и исключения Defender пропущу.' 'Yellow' }
    Out-Rep ''
    Out-Rep '  Как читать отчёт:'
    Out-Rep '  [ПОЛЬЗА]  реально даёт производительность или снижает задержку'
    Out-Rep '  [ПЛАЦЕБО] ничего не меняет или эффект на уровне погрешности'
    Out-Rep '  [СПОРНО]  на одном железе и в одних играх помогает, в других мешает'
    Out-Rep '  [ВРЕД]    вредно для производительности: система от этого медленнее или нестабильнее'
    Out-Rep '  [ОПАСНО]  вредно для безопасности: на скорость почти не влияет, но открывает систему вирусам'
    Out-Rep '  [СЛЕД]    след оптимизатора: бэкап, точка восстановления, папка, программа'
    Out-Rep '  [СТОК]    как в чистой Windows'
    Out-Rep '  Оценку получает только то, что изменено. Под каждым пунктом написано, почему у него такая оценка.'
}

# ---------------------------------------------------------------------
#  Проверки
# ---------------------------------------------------------------------
$MM   = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$ADV  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$CDM  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$MEM  = 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
$IFEO = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'

function Test-System($Sys, [bool]$Admin) {
    Section 'Система'
    Test-RegGroup Tweak Mixed 'Приоритет активной программы (Win32PrioritySeparation)' @('HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl|Win32PrioritySeparation|2/24') `
        'Меняет, как процессор делит время между активной программой и фоном. В одних играх чуть плавнее, в других хуже, замеры расходятся.'
    Test-RegGroup Tweak Placebo 'Планировщик игр MMCSS (SystemResponsiveness и Tasks\Games)' @(
        "$MM|SystemResponsiveness|20",
        "$MM\Tasks\Games|GPU Priority|8",
        "$MM\Tasks\Games|Priority|2",
        "$MM\Tasks\Games|Scheduling Category|Medium",
        "$MM\Tasks\Games|SFIO Priority|Normal"
    ) 'MMCSS работает для звука и видео, игры в Tasks\Games почти не регистрируются. SystemResponsiveness ниже 10 Windows всё равно считает за 10.'
    $prio = @()
    foreach ($exe in @(Get-RegSubKeys $IFEO)) {
        if ($null -ne (Get-RegText ($IFEO + '\' + $exe + '\PerfOptions') 'CpuPriorityClass')) { $prio += $exe }
    }
    Add-Check Tweak Mixed 'Приоритет процессов через IFEO (CpuPriorityClass)' ($prio.Count -gt 0) @{ $true = ('' + $prio.Count + ': ' + (($prio | Select-Object -First 5) -join ', ')); $false = '' }[$prio.Count -gt 0] `
        'Высокий приоритет игре иногда помогает на слабом процессоре, но отнимает время у звука, ввода и драйверов: отсюда хрипы и подлагивания.'
    Test-RegGroup Tweak Placebo 'Мгновенные меню и автозагрузка без задержки' @(
        'HKCU\Control Panel\Desktop|MenuShowDelay|400',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize|StartupDelayInMSec|',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize|WaitForIdleState|'
    ) 'На игры не влияет: меню просто открываются без задержки, а программы автозагрузки стартуют сразу.'
    Test-RegGroup Tweak Bad 'Принудительное закрытие программ и служб при выключении' @(
        'HKCU\Control Panel\Desktop|AutoEndTasks|0',
        'HKLM\SYSTEM\CurrentControlSet\Control|WaitToKillServiceTimeout|5000'
    ) 'Программы и службы убиваются, не успев сохраниться: можно потерять несохранённое или получить битые настройки. Быстрее работать от этого ничего не станет.'
    Test-RegGroup Tweak Placebo 'Короткие тайм-ауты зависших программ' @(
        'HKCU\Control Panel\Desktop|HungAppTimeout|5000',
        'HKCU\Control Panel\Desktop|WaitToKillAppTimeout|20000',
        'HKCU\Control Panel\Desktop|LowLevelHooksTimeout|5000'
    ) 'Только быстрее предлагает закрыть зависшую программу, на скорость работы не влияет.'
    $ptWhy = 'Троттлинг касается только фоновых программ, игру в активном окне Windows и так не ограничивает.'
    if ($Sys.IsLaptop) {
        Test-RegGroup Tweak Mixed 'Power Throttling выкл' @('HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling|PowerThrottlingOff|0') ($ptWhy + ' А на ноутбуке фон начинает быстрее сажать батарею и греть корпус.')
    } else {
        Test-RegGroup Tweak Placebo 'Power Throttling выкл' @('HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling|PowerThrottlingOff|0') $ptWhy
    }
    Test-RegGroup Tweak Placebo 'Группировка svchost (SvcHostSplitThresholdInKB)' @('HKLM\SYSTEM\CurrentControlSet\Control|SvcHostSplitThresholdInKB|3670016') `
        'Службы просто собираются в меньшее число процессов. Экономия памяти копеечная, на FPS и задержку не влияет.'
    Test-RegGroup Tweak Bad 'Большой системный кэш (LargeSystemCache)' @("$MEM|LargeSystemCache|0") `
        'Это режим для серверов: кэш файлов забирает память у программ и игр.'
    Test-RegGroup Tweak Bad 'Очистка файла подкачки при выключении (ClearPageFileAtShutdown)' @("$MEM|ClearPageFileAtShutdown|0") `
        'При каждом выключении стирается весь файл подкачки, выключение тянется в разы дольше. Для скорости пользы нет.'
    Test-RegGroup Tweak Placebo 'Ядро без подкачки (DisablePagingExecutive)' @("$MEM|DisablePagingExecutive|0") `
        'Ядро и драйверы и так почти не уходят в подкачку, разницы в играх нет.'
    Test-RegGroup Tweak Placebo 'Prefetch и Superfetch выкл' @(
        "$MEM\PrefetchParameters|EnablePrefetcher|3",
        "$MEM\PrefetchParameters|EnableSuperfetch|3"
    ) 'Прироста в играх нет, а программы и игры могут запускаться дольше, особенно с HDD.'
    # 0x80000002 и 0x80000003 управляет система, 1 и 0x80000000 остались после старых версий Windows
    Test-RegGroup Tweak Placebo 'NTFS: отметки доступа и короткие имена 8.3' @(
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsDisableLastAccessUpdate|2147483648/2147483650/2147483651/0/1',
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsDisable8dot3NameCreation|2',
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsMemoryUsage|0/1'
    ) 'Новые Windows и так не пишут лишнего на диск, на SSD и в играх разницы не видно.'
    Test-RegGroup Tweak Mixed 'Таймер (GlobalTimerResolutionRequests)' @('HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel|GlobalTimerResolutionRequests|0') `
        'На Windows 11 возвращает общий таймер для всех программ. Смысл есть только вместе с программой таймера, эффект на задержку маленький, а расход энергии выше.'
    Test-RegGroup Tweak Placebo 'Очередь ввода мыши и клавиатуры (DataQueueSize)' @(
        'HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters|MouseDataQueueSize|100',
        'HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters|KeyboardDataQueueSize|100'
    ) 'Размер очереди на задержку ввода не влияет: она почти всегда пустая. Слишком маленькая очередь может терять движения мыши.'
    if ($Sys.IsWin11) {
        Add-Check Tweak Placebo 'Старое меню правой кнопки (Win11)' (Test-RegKey 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32') '' `
            'На скорость не влияет, это дело вкуса.'
    }
    if ($Admin) {
        try {
            $mm = Get-MMAgent -ErrorAction Stop
            $off = @()
            if (-not $mm.MemoryCompression) { $off += 'сжатие памяти' }
            if (-not $mm.PageCombining) { $off += 'объединение страниц' }
            $d = @{ $true = ('выкл: ' + ($off -join ', ')); $false = '' }[$off.Count -gt 0]
            if ((-not $mm.MemoryCompression) -and $Sys.RamGB -le 8) {
                Add-Check Tweak Bad 'Менеджер памяти (MMAgent)' $true $d 'При 8 ГБ и меньше сжатие как раз спасает от подкачки на диск. Без него, когда память кончается, начинаются фризы.'
            } else {
                Add-Check Tweak Placebo 'Менеджер памяти (MMAgent)' ($off.Count -gt 0) $d 'При таком объёме памяти сжатие почти не включается, разницы нет.'
            }
        } catch {}
    }
    $pf = Get-RegText $MEM 'PagingFiles'
    $pfStock = ($null -eq $pf) -or ($pf -match '^(\?|[A-Za-z]):\\pagefile\.sys( 0 0)?$')
    $pfNone = [string]::IsNullOrWhiteSpace($pf) -and ($null -ne $pf)
    $pfDetail = @{ $true = ('задан вручную: ' + @{ $true = 'нет файла'; $false = ($pf -replace "`n", '; ') }[$pfNone]); $false = '' }[-not $pfStock]
    if ($pfNone) {
        Add-Check Setting Bad 'Файл подкачки' $true $pfDetail 'Без файла подкачки игры и браузер вылетают, когда кончается память, даже если её много. Быстрее от этого ничего не станет.'
    } else {
        Add-Check Setting Placebo 'Файл подкачки' (-not $pfStock) $pfDetail 'Размер вручную на скорость не влияет, системный выбор работает не хуже.'
    }
    Test-RegGroup Setting Placebo 'Визуальные эффекты и прозрачность' @(
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects|VisualFXSetting|0/1',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize|EnableTransparency|1',
        "$ADV|TaskbarAnimations|1",
        'HKCU\Software\Microsoft\Windows\DWM|EnableAeroPeek|1'
    ) 'Анимации окон рисует видеокарта, на современном ПК прироста в играх нет.'
    Test-RegGroup Setting Good 'Залипание клавиш и повтор клавиатуры' @(
        'HKCU\Control Panel\Accessibility\StickyKeys|Flags|510',
        'HKCU\Control Panel\Keyboard|KeyboardDelay|1'
    ) 'Окно залипания не выскочит посреди игры от пяти нажатий Shift, а повтор клавиш срабатывает быстрее.'
    Test-RegGroup Setting Good 'Акселерация мыши выкл' @('HKCU\Control Panel\Mouse|MouseSpeed|1') `
        'Прицел зависит только от того, насколько сдвинул мышь, а не от скорости движения. Проще набить мышечную память.'
}

function Test-Video($Sys) {
    Section 'Видеокарта и игры'
    Test-RegGroup Tweak Good 'Game DVR выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR|AllowGameDVR|1') `
        'Фоновая запись игр выключена совсем, она отнимает ресурсы видеокарты и диска.'
    Test-RegGroup Tweak Mixed 'Оптимизация во весь экран (FSO) выкл для всех игр' @(
        'HKCU\System\GameConfigStore|GameDVR_HonorUserFSEBehaviorMode|0',
        'HKCU\System\GameConfigStore|GameDVR_DXGIHonorFSEWindowsCompatible|0',
        'HKCU\System\GameConfigStore|GameDVR_EFSEFeatureFlags|0'
    ) 'На новых Windows FSO обычно не хуже настоящего полноэкранного режима. Отключение помогает в части старых DX9 и DX11 игр, в других даёт минус.'
    $gd = 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    $tdrSpecs = @("$gd|TdrDelay|", "$gd|TdrLevel|", "$gd|TdrDdiDelay|")
    if ((Get-RegText $gd 'TdrLevel') -eq '0') {
        Test-RegGroup Tweak Bad 'Задержки драйвера видеокарты (TdrDelay, TdrLevel)' $tdrSpecs `
            'TdrLevel 0 выключает восстановление драйвера: если он зависнет, Windows не перезапустит его, а зависнет целиком.'
    } else {
        Test-RegGroup Tweak Mixed 'Задержки драйвера видеокарты (TdrDelay, TdrLevel)' $tdrSpecs `
            'Долгое ожидание драйвера нужно для тяжёлого рендера и нейросетей. В играх зависание просто дольше висит, прежде чем драйвер перезапустится.'
    }
    Test-RegGroup Setting Good 'Фоновая запись Game Bar выкл' @('HKCU\System\GameConfigStore|GameDVR_Enabled|1') `
        'Запись последних минут игры больше не нагружает видеокарту и диск.'
    Test-RegGroup Setting Mixed 'Игровой режим Windows выкл' @('HKCU\Software\Microsoft\GameBar|AutoGameModeEnabled|1') `
        'На свежих Windows игровой режим чаще помогает или не мешает, но в отдельных играх с ним бывают статтеры.'
    $dx = Get-RegText 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings'
    $swap = ($dx -match 'SwapEffectUpgradeEnable=1')
    Add-Check Setting Good 'Оптимизация оконных игр' $swap @{ $true = 'вкл'; $false = '' }[$swap] `
        'Оконные DX10 и DX11 игры выводят кадры по-новому: ниже задержка и работает VRR (G-Sync, FreeSync).'
    # HAGS и MSI mode драйверы часто включают сами, поэтому только для сведения
    $hags = Get-RegText $gd 'HwSchMode'
    Add-Info 'Аппаратное планирование GPU (HAGS)' @{ $true = 'вкл'; $false = 'выкл или по умолчанию' }[$hags -eq '2']
    $msi = @()
    try {
        foreach ($v in @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { [string]$_.PNPDeviceID -match '^PCI\\' })) {
            $mk = 'HKLM\SYSTEM\CurrentControlSet\Enum\' + $v.PNPDeviceID + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
            $msi += ([string]$v.Name + ' ' + @{ $true = 'вкл'; $false = 'выкл' }[(Get-RegText $mk 'MSISupported') -eq '1'])
        }
    } catch {}
    if ($msi.Count -gt 0) { Add-Info 'MSI mode видеокарты' ($msi -join ', ') }
}

function Test-Power($Sys, [bool]$Admin) {
    Section 'Питание и загрузчик'
    $std = @{
        '381b4222-f694-41f0-9685-ff5bb260df2e' = 'Balanced'
        '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' = 'High'
        'a1841308-3541-4fab-bc81-f71556f20b4a' = 'Saver'
        'e9a42b02-d5df-448d-aa00-03f14749eb61' = 'Ultimate'
        'ded574b5-45a0-4f42-8737-46345c09c238' = 'Ultimate'
    }
    $r = Invoke-Native 'powercfg.exe' @('/list')
    $schemes = @()
    foreach ($l in ($r.Out -split "`n")) {
        if ($l -match ('(' + $GuidRx + ')\s*\((.*)\)\s*(\*)?')) {
            $schemes += [pscustomobject]@{ Guid = $Matches[1].ToLower(); Name = $Matches[2].Trim(); Active = [bool]$Matches[3] }
        }
    }
    $act = $schemes | Where-Object { $_.Active } | Select-Object -First 1
    if ($act) {
        $kind = $std[$act.Guid]
        $name = '«' + $act.Name + '»'
        $fast = 'Процессор не сбрасывает частоту и не усыпляет ядра, меньше просадок и задержек.'
        if ($kind -eq 'Balanced') { Add-Check Tweak Good 'Схема питания' $false $name }
        elseif ($kind -eq 'Saver') { Add-Check Setting Bad 'Схема питания' $true $name 'Экономия режет частоты процессора, FPS ниже.' }
        else {
            $k = @{ $true = 'Setting'; $false = 'Tweak' }[$kind -eq 'High']
            if ($kind -eq 'Ultimate') { $name += ' (максимальная, включается только командой)' }
            if ($kind) {
                if ($Sys.IsLaptop) { Add-Check $k Mixed 'Схема питания' $true $name ($fast + ' Но ноутбук сильнее греется и быстрее садится.') }
                else { Add-Check $k Good 'Схема питания' $true $name $fast }
            } else {
                Add-Check Tweak Mixed 'Схема питания' $true ($name + ' (своя схема, не из Windows)') 'Чужая схема: что в ней подкручено, без разбора не понять. Бывают и полезные, и сломанные.'
            }
        }
    }
    foreach ($s in @($schemes | Where-Object { -not $_.Active -and -not $std.ContainsKey($_.Guid) })) {
        Add-Trace ('Своя схема питания «' + $s.Name + '» (не включена)')
    }
    $hib = Get-RegText 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
    $hibOff = ($hib -eq '0') -and -not (Test-Path -LiteralPath ($env:SystemDrive + '\hiberfil.sys'))
    Add-Check Tweak Placebo 'Гибернация выкл (powercfg /h off)' $hibOff '' 'Освобождает место на диске, на скорость не влияет. Заодно выключает быстрый запуск.'
    Test-RegGroup Setting Good 'Быстрый запуск Windows выкл' @('HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power|HiberbootEnabled|1') `
        'Каждое включение идёт с чистого листа, без сохранённого состояния драйверов: меньше странных глюков после включения.'

    if (-not $Admin) { Add-Info 'Загрузчик (bcdedit)' 'нужны права администратора'; return }
    $b = Invoke-Native 'bcdedit.exe' @('/enum', '{current}')
    if ($b.Code -ne 0) { Add-Info 'Загрузчик (bcdedit)' 'не прочитался'; return }
    $bcd = @{}
    foreach ($l in ($b.Out -split "`n")) { if ($l -match '^(\w+)\s+(\S.*)$') { $bcd[$Matches[1].ToLower()] = $Matches[2].Trim() } }
    $boot = @(
        @('disabledynamictick', 'Dynamic tick выкл', '^(Yes|Да)', 'Mixed', 'Таймер тикает без пауз: иногда кадры ровнее, но растёт расход энергии, замеры расходятся.'),
        @('useplatformclock', 'Принудительный HPET (useplatformclock)', '.', 'Bad', 'HPET медленнее обычного таймера процессора: чаще ниже FPS и выше задержка.'),
        @('useplatformtick', 'Платформенный таймер (useplatformtick)', '^(Yes|Да)', 'Placebo', 'На современных процессорах разницы нет.'),
        @('tscsyncpolicy', 'Синхронизация TSC (tscsyncpolicy)', '.', 'Placebo', 'Windows сама выбирает правильную синхронизацию, ручная настройка ничего не даёт.'),
        @('hypervisorlaunchtype', 'Гипервизор выкл', '^(Off|Выкл)', 'Mixed', 'Даёт несколько процентов FPS, но выключает изоляцию ядра (VBS), WSL и песочницу.'),
        @('x2apicpolicy', 'x2APIC (x2apicpolicy)', '.', 'Placebo', 'На игры не влияет.'),
        @('nx', 'Защита DEP выкл', '^AlwaysOff', 'Danger', 'Выключена защита памяти от запуска кода. Через это вирусам гораздо проще захватить систему.')
    )
    foreach ($it in $boot) {
        $v = $bcd[$it[0]]
        $hit = ($null -ne $v) -and ($v -match $it[2])
        Add-Check Tweak $it[3] ('Загрузчик: ' + $it[1]) $hit @{ $true = ($it[0] + ' ' + $v); $false = '' }[$hit] $it[4]
    }
}

function Test-Network($Sys) {
    Section 'Сеть'
    Test-RegGroup Tweak Placebo 'Ограничение сети при звуке (NetworkThrottlingIndex)' @("$MM|NetworkThrottlingIndex|10") `
        'Ограничение включается только при проигрывании звука и на скоростях, до которых игровой трафик не доходит.'
    Test-RegGroup Tweak Good 'Раздача обновлений другим ПК выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization|DODownloadMode|') `
        'Windows больше не раздаёт обновления чужим компьютерам и не занимает этим канал.'
    Test-RegGroup Tweak Placebo 'Резерв полосы QoS (NonBestEffortLimit)' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched|NonBestEffortLimit|') `
        'Миф про «Windows забирает 20% интернета»: резерв действует только для программ с QoS, остальным канал доступен целиком.'
    $tcp = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    Test-RegGroup Tweak Placebo 'Параметры TCP/IP' @(
        "$tcp|DefaultTTL|", "$tcp|Tcp1323Opts|", "$tcp|TcpMaxDupAcks|", "$tcp|MaxUserPort|",
        "$tcp|TcpTimedWaitDelay|", "$tcp|SackOpts|", "$tcp|TcpNoDelay|", "$tcp|TcpAckFrequency|", "$tcp|MaxConnectionsPerServer|"
    ) 'На пинг в играх не влияет. Часть этих значений осталась со времён Windows XP, а неудачные даже режут скорость скачивания.'
    $nagle = 0
    foreach ($i in @(Get-RegSubKeys ($tcp + '\Interfaces'))) {
        $p = $tcp + '\Interfaces\' + $i
        if ($null -ne (Get-RegText $p 'TcpAckFrequency') -or $null -ne (Get-RegText $p 'TCPNoDelay') -or $null -ne (Get-RegText $p 'TcpDelAckTicks')) { $nagle++ }
    }
    Add-Check Tweak Placebo 'Алгоритм Нейгла выкл (TcpAckFrequency, TCPNoDelay)' ($nagle -gt 0) @{ $true = ('на ' + $nagle + ' интерфейсах'); $false = '' }[$nagle -gt 0] `
        'Почти все онлайн-игры работают по UDP, а Нейгл касается только TCP. Помогает разве что в старых играх на TCP.'
    try {
        $ts = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop | Select-Object -First 1
        $at = [string]$ts.AutoTuningLevelLocal
        if ($at) {
            if ($at -match 'Disabled|Restricted') { Add-Check Tweak Bad 'Автонастройка окна TCP' ($at -ne 'Normal') $at 'Скорость скачивания может упасть в разы. На пинг это не влияет.' }
            else { Add-Check Tweak Mixed 'Автонастройка окна TCP' ($at -ne 'Normal') @{ $true = $at; $false = '' }[$at -ne 'Normal'] 'Нестандартный режим, эффект зависит от сети и провайдера.' }
        }
    } catch {}
    # Сток драйвера сетевой лежит рядом: Ndi\params\<параметр>\default
    $nicKeys = @('*InterruptModeration', 'ITR', '*FlowControl', '*EEE', 'EEE', 'EEELinkAdvertisement', 'AdvancedEEE', 'EnableGreenEthernet', 'GreenEthernet', 'GigaLite', 'PowerSavingMode', 'ULPMode', '*SelectiveSuspend', 'EnablePowerManagement', 'AutoPowerSaveModeEnabled', '*LsoV2IPv4', '*LsoV2IPv6', '*RSS', '*NumRssQueues', '*ReceiveBuffers', '*TransmitBuffers', '*TCPChecksumOffloadIPv4', '*UDPChecksumOffloadIPv4', '*PMARPOffload', '*PMNSOffload', '*WakeOnMagicPacket', '*WakeOnPattern', 'WakeOnLink', '*PriorityVLANTag', '*JumboPacket')
    $adapters = @()
    try { $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop) } catch {}
    foreach ($a in $adapters) {
        $key = $null
        foreach ($n in @(Get-RegSubKeys $NetClass)) {
            if ($n -notmatch '^\d{4}$') { continue }
            $id = Get-RegText ($NetClass + '\' + $n) 'NetCfgInstanceId'
            if ($id -and $id.Trim('{}') -ieq ([string]$a.InterfaceGuid).Trim('{}')) { $key = $NetClass + '\' + $n; break }
        }
        if (-not $key) { continue }
        $diff = @()
        foreach ($k in $nicKeys) {
            $now = Get-RegText $key $k
            if ($null -eq $now) { continue }
            $def = Get-RegText ($key + '\Ndi\params\' + $k) 'default'
            if ($null -eq $def -or $def -eq $now) { continue }
            $diff += ($k.TrimStart('*') + ' ' + $def + '>' + $now)
        }
        $d = ''
        if ($diff.Count -gt 0) { $d = 'изменено ' + $diff.Count + ': ' + (($diff | Select-Object -First 4) -join ', ') + @{ $true = ' и др.'; $false = '' }[$diff.Count -gt 4] }
        Add-Check Tweak Mixed ('Драйвер сетевой ' + [string]$a.InterfaceDescription) ($diff.Count -gt 0) $d `
            'Отключение энергосбережения сетевой обычно безвредно. Выключение сглаживания прерываний и offload может снизить задержку, но грузит процессор. Зависит от карты.'
    }
}

function Test-Privacy($Sys) {
    Section 'Телеметрия, реклама, Bing'
    $pol = 'HKLM\SOFTWARE\Policies\Microsoft\Windows'
    $privacy = 'На скорость почти не влияет, это про приватность.'
    Test-RegGroup Tweak Placebo 'Телеметрия и история активности выкл политиками' @(
        "$pol\DataCollection|AllowTelemetry|",
        "$pol\DataCollection|DoNotShowFeedbackNotifications|",
        "$pol\AppCompat|AITEnable|",
        "$pol\AppCompat|DisableInventory|",
        "$pol\System|PublishUserActivities|",
        "$pol\System|UploadUserActivities|",
        "$pol\System|EnableActivityFeed|",
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting|Disabled|',
        'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting|Disabled|0',
        'HKCU\Software\Microsoft\Siuf\Rules|NumberOfSIUFInPeriod|'
    ) $privacy
    Test-RegGroup Tweak Placebo 'Bing и веб-подсказки в поиске выкл' @(
        'HKCU\Software\Policies\Microsoft\Windows\Explorer|DisableSearchBoxSuggestions|',
        "$pol\Windows Search|DisableWebSearch|",
        "$pol\Windows Search|ConnectedSearchUseWeb|",
        "$pol\Windows Search|AllowCortana|"
    ) 'На игры не влияет, зато поиск в Пуске не лезет в интернет и не показывает мусор.'
    if ($Sys.IsWin11) {
        Test-RegGroup Tweak Good 'Виджеты, Copilot, Recall выкл политиками' @(
            'HKLM\SOFTWARE\Policies\Microsoft\Dsh|AllowNewsAndInterests|',
            'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot|TurnOffWindowsCopilot|',
            "$pol\WindowsCopilot|TurnOffWindowsCopilot|",
            'HKCU\Software\Policies\Microsoft\Windows\WindowsAI|DisableAIDataAnalysis|',
            "$pol\WindowsAI|DisableAIDataAnalysis|"
        ) 'Виджеты и Recall работают в фоне и едят память, процессор и диск. Без них фоновой нагрузки меньше.'
    } else {
        Test-RegGroup Tweak Good '«Новости и интересы» выкл политикой' @("$pol\Windows Feeds|EnableFeeds|") `
            'Лента новостей на панели задач работает в фоне и ест память. Без неё фоновой нагрузки меньше.'
    }
    $edge = 'HKLM\SOFTWARE\Policies\Microsoft\Edge'
    $chrome = 'HKLM\SOFTWARE\Policies\Google\Chrome'
    $browser = @("$edge|StartupBoostEnabled|1", "$edge|BackgroundModeEnabled|1", "$edge|SleepingTabsEnabled|1", "$chrome|HighEfficiencyModeEnabled|", "$chrome|BackgroundModeEnabled|1")
    if ((Get-RegText $edge 'SleepingTabsEnabled') -eq '0' -or (Get-RegText $chrome 'HighEfficiencyModeEnabled') -eq '0') {
        Test-RegGroup Tweak Mixed 'Edge и Chrome: фон, предзапуск, сон вкладок политиками' $browser `
            'Фоновой работы браузера меньше, но сон вкладок выключен, и открытые вкладки едят больше памяти.'
    } else {
        Test-RegGroup Tweak Good 'Edge и Chrome: фон, предзапуск, сон вкладок политиками' $browser `
            'Браузер не висит в фоне после закрытия и не стартует вместе с Windows: меньше фоновой нагрузки.'
    }
    Test-RegGroup Setting Placebo 'Реклама, советы и предложения Windows' @(
        'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo|Enabled|1',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo|DisabledByGroupPolicy|',
        "$CDM|SilentInstalledAppsEnabled|1",
        "$CDM|SystemPaneSuggestionsEnabled|1",
        "$CDM|SoftLandingEnabled|1",
        "$CDM|SubscribedContent-338388Enabled|1",
        "$CDM|SubscribedContent-338389Enabled|1",
        "$CDM|SubscribedContent-353694Enabled|1",
        "$CDM|SubscribedContent-353696Enabled|1",
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy|TailoredExperiencesWithDiagnosticDataEnabled|1'
    ) 'На скорость не влияет, просто меньше рекламы и навязанных приложений.'
    Test-RegGroup Setting Placebo 'Фоновые приложения выкл' @('HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications|GlobalUserDisabled|0') `
        'Приложения из магазина в фоне и так почти ничего не делают, в играх разницы нет.'

    $tasks = @(
        '\Microsoft\Windows\Application Experience\|Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\|ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\|MareBackup',
        '\Microsoft\Windows\Application Experience\|StartupAppTask',
        '\Microsoft\Windows\Application Experience\|PcaPatchDbTask',
        '\Microsoft\Windows\Customer Experience Improvement Program\|Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\|UsbCeip',
        '\Microsoft\Windows\Autochk\|Proxy',
        '\Microsoft\Windows\DiskDiagnostic\|Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\|DmClient',
        '\Microsoft\Windows\Feedback\Siuf\|DmClientOnScenarioDownload',
        '\Microsoft\Windows\Windows Error Reporting\|QueueReporting',
        '\Microsoft\Windows\Maps\|MapsUpdateTask',
        '\Microsoft\Windows\Maps\|MapsToastTask',
        '\Microsoft\Windows\CloudExperienceHost\|CreateObjectTask',
        '\Microsoft\Windows\Power Efficiency Diagnostics\|AnalyzeSystem',
        '\Microsoft\Windows\NetTrace\|GatherNetworkInfo',
        '\Microsoft\Windows\Device Information\|Device'
    )
    $off = @(); $all = 0
    foreach ($t in $tasks) {
        $p = $t.Split('|')
        $task = $null
        try { $task = Get-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -ErrorAction Stop } catch {}
        if (-not $task) { continue }
        $all++
        if ([string]$task.State -eq 'Disabled') { $off += $p[1] }
    }
    # Одну-две задачи Windows иногда выключает сама, поэтому от двух
    if ($all -gt 0) {
        Add-Check Tweak Placebo 'Задачи телеметрии в планировщике' ($off.Count -ge 2) @{ $true = ('выкл ' + $off.Count + ' из ' + $all + ': ' + (($off | Select-Object -First 4) -join ', ')); $false = '' }[$off.Count -ge 2] `
            'Эти задачи запускаются редко и ненадолго, обычно когда компьютер простаивает. На игры не влияют.'
    }
}

function Test-Services {
    Section 'Службы'
    # Только службы, которые в чистой Windows не отключены
    $names = @(
        'DiagTrack', 'dmwappushservice', 'WerSvc', 'PcaSvc', 'DPS', 'WdiServiceHost', 'WdiSystemHost', 'diagnosticshub.standardcollector.service',
        'MapsBroker', 'lfsvc', 'RetailDemo', 'WMPNetworkSvc', 'TrkWks', 'Fax', 'Spooler', 'PrintNotify',
        'bthserv', 'BTAGService', 'BthAvctpSvc', 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',
        'TermService', 'UmRdpService', 'SessionEnv', 'WbioSrvc', 'SCardSvr', 'ScDeviceEnum', 'SCPolicySvc',
        'WSearch', 'SysMain', 'Themes', 'iphlpsvc', 'lmhosts', 'SSDPSRV', 'upnphost', 'PhoneSvc', 'wisvc', 'WpcMonSvc', 'RmSvc',
        'HvHost', 'vmickvpexchange', 'vmicguestinterface', 'vmicshutdown', 'vmicheartbeat', 'vmicvmsession', 'vmicrdv', 'vmictimesync', 'vmicvss',
        'wuauserv', 'UsoSvc', 'BITS', 'DoSvc', 'WaaSMedicSvc', 'WinDefend', 'SecurityHealthService', 'wscsvc', 'mpssvc', 'EventLog', 'Schedule'
    )
    # Оценка отключения. Кого нет в списке: плацебо
    $upd = 'Без неё не приходят обновления, в том числе исправления дыр в безопасности.'
    $sec = 'Центр безопасности перестаёт следить за защитой и не предупредит, что она выключена.'
    $xbox = 'Перестают работать игры из Xbox и Game Pass и облачные сохранения. На FPS не влияет.'
    $svc = @{
        wuauserv              = @('Danger', $upd)
        UsoSvc                = @('Danger', $upd)
        WaaSMedicSvc          = @('Danger', 'Эта служба чинит обновления. Без неё Windows не восстановит их сама, если что-то сломается.')
        BITS                  = @('Danger', 'Без неё обновления Windows и базы Defender не скачиваются.')
        WinDefend             = @('Danger', 'Антивирус выключен, вирусы ничто не остановит.')
        SecurityHealthService = @('Danger', $sec)
        wscsvc                = @('Danger', $sec)
        mpssvc                = @('Danger', 'Брандмауэр выключен: компьютер открыт для атак из сети.')
        EventLog              = @('Bad', 'Без журнала событий ломается часть служб и программ, а причину сбоя потом не найти.')
        Schedule              = @('Bad', 'Без планировщика ломаются обслуживание системы, обновления и многие программы.')
        WSearch               = @('Mixed', 'Поиск в Пуске и проводнике становится медленным, зато диск не индексируется в фоне. На HDD это заметно, на SSD почти нет.')
        SysMain               = @('Mixed', 'На HDD без неё программы дольше запускаются, на SSD разницы почти нет.')
        XblAuthManager        = @('Mixed', $xbox)
        XblGameSave           = @('Mixed', $xbox)
        XboxNetApiSvc         = @('Mixed', $xbox)
        XboxGipSvc            = @('Mixed', 'Перестают работать проводные геймпады и аксессуары Xbox. На FPS не влияет.')
        DiagTrack             = @('Placebo', 'Телеметрия работает в фоне, но нагрузка от неё почти незаметна. Это скорее про приватность.')
    }
    foreach ($n in $names) {
        $st = Get-RegText ('HKLM\SYSTEM\CurrentControlSet\Services\' + $n) 'Start'
        if ($null -eq $st) { continue }
        $dn = $n
        try { $dn = [string](Get-Service -Name $n -ErrorAction Stop).DisplayName + ' (' + $n + ')' } catch {}
        $off = ($st -eq '4')
        $v = $svc[$n]
        if (-not $v) { $v = @('Placebo', 'Служба почти не нагружает систему, отключение прироста не даёт, а связанная с ней функция перестаёт работать.') }
        Add-Check Tweak $v[0] $dn $off @{ $true = 'отключена'; $false = '' }[$off] $v[1]
    }
}

function Test-Security($Sys, [bool]$Admin) {
    Section 'Защита и обновления'
    Test-RegGroup Tweak Danger 'Контроль учётных записей (UAC) выкл' @('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|EnableLUA|1') `
        'Любая программа сразу получает права администратора, без вопроса. Вирусу больше ничего не мешает.'
    Test-RegGroup Tweak Mixed 'VBS выкл через реестр' @('HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard|EnableVirtualizationBasedSecurity|1') `
        'Даёт несколько процентов FPS, но снимает изоляцию ядра, одну из защит от вирусов.'
    Test-RegGroup Tweak Danger 'Защита Spectre и Meltdown изменена' @(
        "$MEM|FeatureSettingsOverride|",
        "$MEM|FeatureSettingsOverrideMask|"
    ) 'Сняты заплатки от уязвимостей процессора. На старых процессорах это даёт немного скорости, но вредоносный код может читать чужую память, например пароли.'
    $def = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
    Test-RegGroup Tweak Danger 'Defender выкл политиками' @(
        "$def|DisableAntiSpyware|0",
        "$def|DisableAntiVirus|0",
        "$def\Real-Time Protection|DisableRealtimeMonitoring|0",
        "$def\Real-Time Protection|DisableBehaviorMonitoring|0",
        "$def\Spynet|SpynetReporting|1/2",
        "$def\Spynet|SubmitSamplesConsent|0/1/3"
    ) 'Антивирус выключен или ослаблен: вирусы ничто не остановит.'
    Test-RegGroup Tweak Danger 'SmartScreen выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\System|EnableSmartScreen|1') `
        'Windows больше не предупреждает об опасных скачанных файлах и программах.'
    try {
        $mp = Get-MpPreference -ErrorAction Stop
        $cpu = [int]$mp.ScanAvgCPULoadFactor
        Add-Check Tweak Placebo 'Defender: нагрузка проверки на процессор' ($cpu -ne 50) @{ $true = ('' + $cpu + '% (сток 50%)'); $false = '' }[$cpu -ne 50] `
            'Касается только плановой проверки, а она идёт, когда компьютер простаивает. В играх разницы нет.'
        if ($Admin) {
            $ex = @(@($mp.ExclusionPath) + @($mp.ExclusionProcess) | Where-Object { $_ })
            $wide = @($ex | Where-Object { [string]$_ -match '^[A-Za-z]:\\?$|^[A-Za-z]:\\(Windows|Users|Program Files( \(x86\))?|ProgramData)\\?$|\\System32\\?$|^%\w+%\\?$' })
            $d = @{ $true = ('' + $ex.Count + ': ' + (($ex | Select-Object -First 3) -join '; ')); $false = '' }[$ex.Count -gt 0]
            if ($wide.Count -gt 0) {
                Add-Check Setting Danger 'Исключения Defender' $true $d ('Из проверки исключён целый диск или системная папка (' + (($wide | Select-Object -First 2) -join '; ') + '). Вирус там Defender не увидит.')
            } else {
                Add-Check Setting Mixed 'Исключения Defender' ($ex.Count -gt 0) $d 'Исключение папок с играми ускоряет загрузки, но всё, что лежит в этих папках, Defender не проверяет.'
            }
        }
    } catch { Add-Info 'Defender' 'не активен (стоит другой антивирус или Defender вырезан)' }
    $vbs = $null
    try { $vbs = [int](Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop).VirtualizationBasedSecurityStatus } catch {}
    if ($null -ne $vbs) { Add-Info 'VBS (изоляция ядра) сейчас' @{ $true = 'работает'; $false = 'не работает' }[$vbs -eq 2] }

    $wu = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $wuSpecs = @(
        "$wu\AU|NoAutoUpdate|",
        "$wu\AU|AUOptions|",
        "$wu\AU|NoAutoRebootWithLoggedOnUsers|",
        "$wu|DisableWindowsUpdateAccess|",
        "$wu|SetDisableUXWUAccess|",
        "$wu|DeferFeatureUpdates|",
        "$wu|TargetReleaseVersion|",
        "$wu|ExcludeWUDriversInQualityUpdate|"
    )
    $wuBlock = ((Get-RegText "$wu\AU" 'NoAutoUpdate') -eq '1') -or ((Get-RegText "$wu\AU" 'AUOptions') -eq '1') -or ((Get-RegText $wu 'DisableWindowsUpdateAccess') -eq '1') -or ((Get-RegText $wu 'SetDisableUXWUAccess') -eq '1')
    if ($wuBlock) {
        Test-RegGroup Tweak Danger 'Обновления Windows ограничены политиками' $wuSpecs `
            'Обновления заблокированы: исправления дыр в безопасности не приходят, и они остаются открытыми.'
    } else {
        Test-RegGroup Tweak Mixed 'Обновления Windows ограничены политиками' $wuSpecs `
            'Обновления отложены или ограничены: меньше сюрпризов после обновлений, но и исправления приходят позже.'
    }
    $till = Get-RegText 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime'
    $paused = $false
    $d = ''
    if ($till) {
        try {
            $t = [datetime]::Parse($till, [Globalization.CultureInfo]::InvariantCulture)
            $paused = ($t.ToUniversalTime() -gt (Get-Date).ToUniversalTime())
            if ($paused) { $d = 'до ' + (Format-Date $t) }
        } catch {}
    }
    Add-Check Setting Mixed 'Обновления на паузе' $paused $d 'Ненадолго это нормально, но пока пауза идёт, исправления безопасности не приходят.'
}

function Test-Apps($Sys) {
    Section 'Приложения'
    if ($Sys.EditionId -match 'EnterpriseS|IoT|Server') { Add-Info 'Встроенные приложения' ('редакция ' + $Sys.EditionId + ', магазина и приложений в ней нет и так'); return }
    $std = @('Microsoft.WindowsStore', 'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'Microsoft.XboxGamingOverlay', 'Microsoft.GetHelp', 'Microsoft.BingWeather', 'Microsoft.WindowsAlarms', 'Microsoft.WindowsCamera', 'Microsoft.WindowsFeedbackHub', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.ScreenSketch', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsSoundRecorder', 'Microsoft.ZuneMusic', 'Microsoft.DesktopAppInstaller')
    $have = @()
    try { $have = @(Get-AppxPackage -ErrorAction Stop | ForEach-Object { [string]$_.Name }) } catch { Add-Info 'Встроенные приложения' 'список не прочитался'; return }
    $gone = @($std | Where-Object { $have -notcontains $_ } | ForEach-Object { $_ -replace '^Microsoft\.', '' })
    # Пару приложений люди удаляют сами, массовое удаление делают скрипты
    $kind = @{ $true = 'Tweak'; $false = 'Setting' }[$gone.Count -ge 5]
    Add-Check $kind Placebo 'Удалены встроенные приложения' ($gone.Count -ge 3) @{ $true = ('' + $gone.Count + ' из ' + $std.Count + ': ' + (($gone | Select-Object -First 6) -join ', ') + @{ $true = ' и др.'; $false = '' }[$gone.Count -gt 6]); $false = '' }[$gone.Count -ge 3] `
        'Эти приложения и так не работали в фоне, на скорость удаление не влияет. Места освободилось немного.'
    if ($have -notcontains 'Microsoft.WindowsStore') { Add-Check Tweak Bad 'Microsoft Store удалён' $true '' 'Не поставить приложения и игры из магазина, часть игр Xbox не запустится, а вернуть магазин непросто.' }
    $edge = @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'), (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')) | Where-Object { Test-Path -LiteralPath $_ }
    Add-Check Tweak Placebo 'Microsoft Edge удалён' (@($edge).Count -eq 0) '' 'Пока Edge не открыт, он ничего не ест, так что на скорость не влияет. Зато часть ссылок из Windows может перестать открываться.'
}

# ---------------------------------------------------------------------
#  Следы оптимизаторов
# ---------------------------------------------------------------------
function Find-Traces($Sys, [bool]$Admin) {
    Section $TraceSection
    $selfName = Split-Path -Leaf $env:TC_SELF
    # Папка, где лежит сам чекер, тоже не след
    $ownRoots = @(Split-Path -Parent $env:TC_SELF)

    # Свои паки: в state.json видно, когда запускали и был ли откат
    foreach ($tag in @('PLAYSIN333', 'PRIVATE')) {
        $root = Join-Path $env:SystemDrive $tag
        $st = Read-Json (Join-Path $root 'state.json')
        if (-not $st) { continue }
        $ownRoots += $root
        $runs = @($st.Runs | Where-Object { $_ })
        $t = ([string]$st.Product + ' ' + [string]$st.Version + ' в ' + $root + ': первый запуск ' + (Format-Date $st.Created) + ', запусков ' + $runs.Count)
        if ($st.RolledBack) { $t += ', откат сделан ' + (Format-Date $st.RolledBackAt) } else { $t += ', отката не было' }
        Add-Trace $t
    }

    # Папки и файлы по имени: корень диска, рабочий стол, загрузки, документы, программы
    $places = @(
        @(($env:SystemDrive + '\'), 1), @($Desktop, 2), @([Environment]::GetFolderPath('CommonDesktopDirectory'), 1),
        @((Join-Path $env:USERPROFILE 'Downloads'), 2), @([Environment]::GetFolderPath('MyDocuments'), 1),
        @($env:ProgramData, 1), @($env:ProgramFiles, 1), @(${env:ProgramFiles(x86)}, 1),
        @($env:LOCALAPPDATA, 1), @((Join-Path $env:LOCALAPPDATA 'Programs'), 1), @($env:APPDATA, 1)
    )
    $found = New-Object System.Collections.ArrayList
    $regs = New-Object System.Collections.ArrayList
    $seen = @{}
    $queue = New-Object System.Collections.Queue
    foreach ($p in $places) { if ($p[0] -and (Test-Path -LiteralPath $p[0])) { $queue.Enqueue(@($p[0], [int]$p[1])) } }
    while ($queue.Count -gt 0) {
        $q = $queue.Dequeue()
        foreach ($i in @(Get-ChildItem -LiteralPath $q[0] -Force -ErrorAction SilentlyContinue)) {
            $full = $i.FullName
            if ($seen.ContainsKey($full)) { continue }
            $seen[$full] = $true
            if ($i.Name -eq $selfName -or $i.Name -like 'Твик-чекер*' -or $ownRoots -contains $full) { continue }
            if ($i.Name -match $TraceRx) { [void]$found.Add($i); continue }
            if (-not $i.PSIsContainer -and $i.Extension -ieq '.reg') { [void]$regs.Add($i); continue }
            if ($i.PSIsContainer -and $q[1] -gt 1 -and -not ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $queue.Enqueue(@($full, $q[1] - 1)) }
        }
    }
    foreach ($i in @($found | Select-Object -First 15)) {
        Add-Trace (@{ $true = 'Папка '; $false = 'Файл ' }[[bool]$i.PSIsContainer] + $i.FullName + ' (' + (Format-Date $i.LastWriteTime) + ')')
    }
    if ($found.Count -gt 15) { Add-Trace ('И ещё ' + ($found.Count - 15) + ' файлов и папок с такими именами') }
    if ($regs.Count -gt 0) {
        Add-Trace ('Файлы .reg (твики реестра): ' + $regs.Count + ': ' + ((@($regs | Select-Object -First 5) | ForEach-Object { $_.Name }) -join ', '))
    }

    # Установленные программы-оптимизаторы
    $progs = @()
    foreach ($u in @('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall')) {
        foreach ($k in @(Get-RegSubKeys $u)) {
            $n = Get-RegText ($u + '\' + $k) 'DisplayName'
            if ($n -and $n -match $ProgRx -and $progs -notcontains $n) { $progs += $n }
        }
    }
    foreach ($n in $progs) { Add-Trace ('Установлена программа: ' + $n) }
    $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match $ProcRx } | ForEach-Object { $_.ProcessName } | Select-Object -Unique)
    foreach ($n in $procs) { Add-Trace ('Запущено: ' + $n) }

    # Задачи планировщика не от Microsoft
    try {
        foreach ($t in @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
            $act = (@($t.Actions) | ForEach-Object { [string]$_.Execute + ' ' + [string]$_.Arguments }) -join ' '
            if (($t.TaskName + ' ' + $t.TaskPath + ' ' + $act) -match $TraceRx) { Add-Trace ('Задача планировщика: ' + $t.TaskPath + $t.TaskName) }
        }
    } catch {}

    # Ярлыки откатов и игровых режимов на рабочем столе
    foreach ($l in @(Get-ChildItem -LiteralPath $Desktop -Filter '*.lnk' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'откат|rollback|restore|revert|игровой режим|game mode' -and $_.Name -notmatch $TraceRx })) {
        Add-Trace ('Ярлык на рабочем столе: ' + $l.Name)
    }

    # Точки восстановления
    if ($Admin) {
        try {
            $rps = @(Get-ComputerRestorePoint -ErrorAction Stop)
            foreach ($rp in $rps) {
                if ([string]$rp.Description -match $TraceRx) {
                    Add-Trace ('Точка восстановления «' + $rp.Description + '» от ' + (Format-Date $rp.ConvertToDateTime($rp.CreationTime)))
                }
            }
            if ($rps.Count -eq 0) { Add-Info 'Точки восстановления' 'нет ни одной' }
        } catch { Add-Info 'Точки восстановления' 'не прочитались (восстановление системы выключено?)' }
    }

    # Сборки Windows: подписывают себя в сведениях о производителе и владельце
    $oem = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
    $cv = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    foreach ($s in @("$oem|Manufacturer", "$oem|Model", "$oem|SupportURL", "$oem|SupportProvider", "$cv|RegisteredOrganization", "$cv|RegisteredOwner", "$cv|EditionID")) {
        $p = $s.Split('|')
        $v = Get-RegText $p[0] $p[1]
        if ($v -and $v -match $BuildRx) { Add-Trace ('Похоже на сборку Windows: ' + $p[1] + ' = ' + $v) }
    }

    # hosts: блокировка телеметрии и рекламы списком
    try {
        $hosts = @(Get-Content -LiteralPath (Join-Path $env:SystemRoot 'System32\drivers\etc\hosts') -ErrorAction Stop | Where-Object { $_ -match '^\s*[^#\s]' -and $_ -notmatch '\blocalhost\b' })
        if ($hosts.Count -ge 10) { Add-Trace ('В файле hosts ' + $hosts.Count + ' записей (блокировка телеметрии или рекламы)') }
    } catch {}

}

# ---------------------------------------------------------------------
#  Итог и отчёт
# ---------------------------------------------------------------------
function Get-Rank($Item) {
    return $VD[$Item.Verdict].Rank
}

function Write-Summary {
    $hit = @($Items | Where-Object { $_.Changed -and $VerdictOrder -contains $_.Verdict })
    $traces = @($Items | Where-Object { $_.Verdict -eq 'Trace' })
    $n = @{}
    foreach ($v in $VerdictOrder) { $n[$v] = @($hit | Where-Object { $_.Verdict -eq $v }).Count }

    Out-Rep ''
    Out-Rep '===================================================================='
    Out-Rep '  ИТОГ'
    Out-Rep ('  Опасно: ' + $n.Danger + ' · Вред: ' + $n.Bad + ' · Спорно: ' + $n.Mixed + ' · Плацебо: ' + $n.Placebo + ' · Польза: ' + $n.Good + ' · Следов оптимизаторов: ' + $traces.Count)
    if ($hit.Count -eq 0) {
        Out-Rep ''
        Out-Rep '  Изменённых настроек нет: всё как в чистой Windows.'
    }
    $heads = @{
        Danger  = 'ОПАСНО. Это дыра в защите: через эти настройки вирусам проще попасть в систему. Их стоит закрыть.'
        Bad     = 'ВРЕД. Из-за этого система работает медленнее или нестабильнее:'
        Mixed   = 'СПОРНО. Результат зависит от железа и игр:'
        Placebo = 'ПЛАЦЕБО. На скорость не влияет:'
        Good    = 'ПОЛЬЗА. Это реально работает:'
    }
    foreach ($v in $VerdictOrder) {
        $list = @($hit | Where-Object { $_.Verdict -eq $v } | Sort-Object -Property Idx)
        if ($list.Count -eq 0) { continue }
        Out-Rep ''
        Out-Rep ('  ' + $heads[$v])
        foreach ($i in $list) { Out-Rep ('    - ' + $i.Title + ' (' + $i.Cat + ')') }
    }

    # Оптимизировали ли систему: считаем только то, что руками в Параметрах не сделать
    $tw = @($hit | Where-Object { $_.Kind -eq 'Tweak' })
    Out-Rep ''
    if ($tw.Count -eq 0 -and $traces.Count -eq 0) {
        Out-Rep '  Вывод: систему не оптимизировали, твиков и следов оптимизаторов нет.'
    } elseif ($tw.Count -le 3 -and $traces.Count -eq 0) {
        Out-Rep '  Вывод: почти чистая система, пара точечных правок. На оптимизацию не похоже.'
    } elseif ($tw.Count -le 3) {
        Out-Rep '  Вывод: твиков почти нет, но оптимизаторы на этом ПК были.'
        Out-Rep '  Скорее всего, их откатили, не доделали или настройки вернуло обновление Windows.'
    } else {
        $byCat = @($tw | Group-Object -Property Cat | Sort-Object -Property Count -Descending | ForEach-Object { $_.Name + ' ' + $_.Count })
        Out-Rep ('  Вывод: систему уже оптимизировали, твиков через реестр и скрипты: ' + $tw.Count + '.')
        Out-Rep ('  Где: ' + ($byCat -join ' · '))
    }
    if ($hit.Count -gt 0) {
        Out-Rep ''
        Out-Rep '  Что с этим делать, решай сам. Почему у каждого пункта такая оценка, написано ниже по разделам.'
    }
    Out-Rep '===================================================================='
    return @{ N = $n; Traces = $traces.Count }
}

function Write-Sections {
    foreach ($sec in $Sections) {
        Out-Rep ''
        Out-Rep ('--- ' + $sec + ' ---')
        $mine = @($Items | Where-Object { $_.Cat -eq $sec })
        $hit = @($mine | Where-Object { $_.Changed } | Sort-Object -Property @{ Expression = { Get-Rank $_ } }, Idx)
        $rest = @($mine | Where-Object { -not $_.Changed } | Sort-Object -Property @{ Expression = { $_.Verdict -ne 'Info' } }, Idx)
        if (@($hit | Where-Object { $_.Verdict -ne 'Info' }).Count -eq 0) {
            if ($sec -eq $TraceSection) { Out-Rep '   Следов оптимизаторов не нашёл.' }
            else { Out-Rep '   Изменений нет, всё как в чистой Windows.' }
        }
        foreach ($i in @($hit + $rest)) {
            if ($i.Changed) { $tag = $VD[$i.Verdict].Tag }
            elseif ($i.Verdict -eq 'Info') { $tag = 'ИНФО' }
            else { $tag = 'СТОК' }
            $t = '   ' + ('[' + $tag + ']').PadRight(10) + $i.Title
            if ($i.Detail) { $t += ': ' + $i.Detail }
            Out-Rep $t
            if ($i.Changed -and $i.Why) { Out-Rep ((' ' * 13) + $i.Why) }
        }
    }
}

function Show-Banner([string[]]$Lines, [string]$Color) {
    $w = 0
    foreach ($l in $Lines) { if ($l.Length -gt $w) { $w = $l.Length } }
    $w += 4
    Write-Host ''
    Write-Host ('  ╔' + ('═' * $w) + '╗') -ForegroundColor $Color
    foreach ($l in $Lines) { Write-Host ('  ║  ' + $l.PadRight($w - 2) + '║') -ForegroundColor $Color }
    Write-Host ('  ╚' + ('═' * $w) + '╝') -ForegroundColor $Color
}

function Main {
    $admin = Test-Admin
    if (-not $admin) {
        # С правами видно загрузчик и точки восстановления. Отказался: проверяем что можно
        try { Start-Process -FilePath $env:TC_SELF -Verb RunAs -ErrorAction Stop; return } catch {}
    }
    Set-ConsoleLook
    $sys = Get-SystemInfo
    Show-Head $sys $admin
    Write-Host ''
    Write-Host '  Проверяю, это займёт до минуты...' -ForegroundColor DarkGray
    Write-Host ''

    foreach ($step in @(
        { Test-System $sys $admin },
        { Test-Video $sys },
        { Test-Power $sys $admin },
        { Test-Network $sys },
        { Test-Privacy $sys },
        { Test-Services },
        { Test-Security $sys $admin },
        { Test-Apps $sys },
        { Find-Traces $sys $admin }
    )) {
        try { & $step } catch { Add-Check Error Error 'Проверка прервалась' $true ($_.Exception.Message + ' (проверяю дальше)') }
    }
    Close-Section
    $sum = Write-Summary
    Write-Sections

    Out-Rep ''
    Out-Rep '--------------------------------------------------------------------'
    Out-Rep ('  ' + $BR.Seller)
    Out-Rep ('  ' + $BR.Contact)
    Out-Rep ('  ' + $BR.Social)
    Out-Rep ('  ' + $BR.Repo)

    Write-Host ''
    $parts = @()
    foreach ($v in $VerdictOrder) { $parts += , @(($VD[$v].Name + ' ' + $sum.N[$v]), @{ $true = $VD[$v].Color; $false = 'DarkGray' }[$sum.N[$v] -gt 0]) }
    $parts += , @(('следов ' + $sum.Traces), @{ $true = $VD.Trace.Color; $false = 'DarkGray' }[$sum.Traces -gt 0])
    Write-Host '  Итог: ' -NoNewline -ForegroundColor White
    Write-Parts $parts
    if ($sum.N.Danger -gt 0) {
        Write-Host '  Есть опасные настройки: это дыра в защите, её стоит закрыть. Что именно, написано в отчёте.' -ForegroundColor Magenta
    }

    $saved = $false
    try {
        [IO.File]::WriteAllText($ReportPath, (($Report.ToArray() + '') -join "`r`n"), $Utf8Bom)
        $saved = $true
    } catch { Write-Host ('  Отчёт не сохранился: ' + $_.Exception.Message) -ForegroundColor Red }
    if ($saved) {
        Show-Banner @('ИТОГ И ПОЛНЫЙ РАЗБОР ЛЕЖАТ НА РАБОЧЕМ СТОЛЕ', ('Файл: ' + (Split-Path -Leaf $ReportPath)), 'Сейчас открою его в блокноте.') 'Green'
        if (-not $env:TC_NOWAIT) { try { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $ReportPath + '"') } catch {} }
    }
    Write-Host ''
    Write-Host ('  ' + $BR.Author) -ForegroundColor DarkGray
    Wait-Key
}

try { Main }
catch {
    Write-Host ('  Ошибка: ' + $_.Exception.Message) -ForegroundColor Red
    Wait-Key
}
