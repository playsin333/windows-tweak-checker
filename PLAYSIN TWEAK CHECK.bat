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
::  Telegram: t.me/playsinoptimization
:: ============================================================
#>
# =====================================================================
#  Показывает, оптимизировали ли уже Windows: какие твики применены,
#  какие настройки отличаются от стока, какие остались следы
#  оптимизаторов (бэкапы, точки восстановления, папки, программы).
#  Ничего не пишет ни в реестр, ни в службы, ни в файлы, кроме отчёта
#  на рабочем столе. Верхние строки запускают этот же файл через PowerShell.
# =====================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# @brand-begin
$BR = @{
    Title  = 'PLAYSIN TWEAK CHECK · by playsin333'
    Seller = 'Оптимизация под ключ: playsin333 на FunPay · funpay.com/users/21612506'
    Social = 'YouTube @playsin333 · tiktok.com/@playsin333 · t.me/playsinoptimization'
    Repo   = 'Код и новые версии: github.com/playsin333/windows-tweak-checker'
}
# @brand-end

$TcVersion  = '1.0'
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
#  Отчёт. В консоли изменённое, в файле всё, включая сток
# ---------------------------------------------------------------------
$Checks = New-Object System.Collections.ArrayList
$Traces = New-Object System.Collections.ArrayList
$Report = New-Object System.Collections.ArrayList
$script:Cat = ''
$script:CatStock = 0
$script:CatAll = 0

function Out-Line([string]$Text, [string]$Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
    [void]$Report.Add($Text)
}

function Close-Section {
    if ($script:CatAll -gt 0 -and $script:CatStock -gt 0) {
        Write-Host ('   [СТОК] в стоке ' + $script:CatStock + ' из ' + $script:CatAll + ' (полный список в отчёте)') -ForegroundColor DarkGray
    }
    $script:CatStock = 0
    $script:CatAll = 0
}

function Section([string]$Title) {
    Close-Section
    $script:Cat = $Title
    Write-Host ''
    Write-Host ('  » ' + $Title) -ForegroundColor Cyan
    [void]$Report.Add('')
    [void]$Report.Add('--- ' + $Title + ' ---')
}

# Kind: Tweak = делается только через реестр, команды или скрипты
#       Setting = можно поменять руками в Параметрах или Панели управления
#       Info = для сведения, в итог не идёт
function Add-Check([string]$Kind, [string]$Title, [bool]$Changed, [string]$Detail) {
    [void]$Checks.Add([pscustomobject]@{ Cat = $script:Cat; Kind = $Kind; Title = $Title; Changed = $Changed; Detail = $Detail })
    $t = $Title
    if ($Detail) { $t += ': ' + $Detail }
    if ($Kind -eq 'Info') { Out-Line ('   [ИНФО] ' + $t) 'DarkCyan'; return }
    $script:CatAll++
    if (-not $Changed) {
        $script:CatStock++
        [void]$Report.Add('   [СТОК] ' + $t)
        return
    }
    if ($Kind -eq 'Tweak') { Out-Line ('   [ТВИК] ' + $t) 'Yellow' }
    else { Out-Line ('   [РУЧН] ' + $t) 'DarkYellow' }
}

function Add-Trace([string]$Text) {
    [void]$Traces.Add($Text)
    Out-Line ('   [СЛЕД] ' + $Text) 'Magenta'
}

# Группа значений реестра. Spec: 'Путь|Имя|сток', стоковых значений может быть несколько через «/».
# Значения нет = сток: так Windows ведёт себя по умолчанию
function Test-RegGroup([string]$Kind, [string]$Title, [string[]]$Specs) {
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
    Add-Check $Kind $Title ($diff.Count -gt 0) $detail
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
    Out-Line '  Ничего не меняет в системе: только смотрит и пишет отчёт на рабочий стол.' 'DarkGray'
    Out-Line ''
    Out-Line ('  Проверка:  ' + (Get-Date -Format 'dd.MM.yyyy HH:mm:ss')) 'White'
    Out-Line ('  Компьютер: ' + $Sys.PcName + @{ $true = ' · ноутбук'; $false = '' }[$Sys.IsLaptop]) 'White'
    Out-Line ('  Windows:   ' + $Sys.Name) 'White'
    Out-Line ('  Установлена или крупно обновлена: ' + (Format-Date $Sys.Installed) + ' · включён с ' + (Format-Date $Sys.Boot)) 'White'
    Out-Line ('  Железо:    ' + $Sys.Cpu + ' · ' + $Sys.Gpu + ' · ' + $Sys.RamGB + ' ГБ') 'White'
    if ($Admin) { Out-Line '  Права администратора есть: проверяю всё.' 'DarkGray' }
    else { Out-Line '  Без прав администратора: загрузчик, сжатие памяти, точки восстановления и исключения Defender пропущу.' 'Yellow' }
    Out-Line ''
    Out-Line '  [ТВИК] изменено через реестр, команды или скрипт: руками в Параметрах так не сделать' 'Yellow'
    Out-Line '  [РУЧН] отличается от стока, но это можно поменять в Параметрах Windows' 'DarkYellow'
    Out-Line '  [СЛЕД] след оптимизатора: бэкап, точка восстановления, папка, программа' 'Magenta'
    Out-Line '  [СТОК] как в чистой Windows (в консоли только счётчик, список в отчёте)' 'DarkGray'
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
    Test-RegGroup Tweak 'Приоритет активной программы (Win32PrioritySeparation)' @('HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl|Win32PrioritySeparation|2/24')
    Test-RegGroup Tweak 'Планировщик игр MMCSS (SystemResponsiveness и Tasks\Games)' @(
        "$MM|SystemResponsiveness|20",
        "$MM\Tasks\Games|GPU Priority|8",
        "$MM\Tasks\Games|Priority|2",
        "$MM\Tasks\Games|Scheduling Category|Medium",
        "$MM\Tasks\Games|SFIO Priority|Normal"
    )
    $prio = @()
    foreach ($exe in @(Get-RegSubKeys $IFEO)) {
        if ($null -ne (Get-RegText ($IFEO + '\' + $exe + '\PerfOptions') 'CpuPriorityClass')) { $prio += $exe }
    }
    Add-Check Tweak 'Приоритет процессов через IFEO (CpuPriorityClass)' ($prio.Count -gt 0) @{ $true = ('' + $prio.Count + ': ' + (($prio | Select-Object -First 5) -join ', ')); $false = '' }[$prio.Count -gt 0]
    Test-RegGroup Tweak 'Мгновенные меню и автозагрузка без задержки' @(
        'HKCU\Control Panel\Desktop|MenuShowDelay|400',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize|StartupDelayInMSec|',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize|WaitForIdleState|'
    )
    Test-RegGroup Tweak 'Быстрое закрытие зависших программ и служб' @(
        'HKCU\Control Panel\Desktop|AutoEndTasks|0',
        'HKCU\Control Panel\Desktop|HungAppTimeout|5000',
        'HKCU\Control Panel\Desktop|WaitToKillAppTimeout|20000',
        'HKCU\Control Panel\Desktop|LowLevelHooksTimeout|5000',
        'HKLM\SYSTEM\CurrentControlSet\Control|WaitToKillServiceTimeout|5000'
    )
    Test-RegGroup Tweak 'Power Throttling выкл' @('HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling|PowerThrottlingOff|0')
    Test-RegGroup Tweak 'Группировка svchost (SvcHostSplitThresholdInKB)' @('HKLM\SYSTEM\CurrentControlSet\Control|SvcHostSplitThresholdInKB|3670016')
    Test-RegGroup Tweak 'Память: LargeSystemCache, DisablePagingExecutive, Prefetch' @(
        "$MEM|LargeSystemCache|0",
        "$MEM|DisablePagingExecutive|0",
        "$MEM|ClearPageFileAtShutdown|0",
        "$MEM\PrefetchParameters|EnablePrefetcher|3",
        "$MEM\PrefetchParameters|EnableSuperfetch|3"
    )
    # 0x80000002 и 0x80000003 управляет система, 1 и 0x80000000 остались после старых версий Windows
    Test-RegGroup Tweak 'NTFS: отметки доступа и короткие имена 8.3' @(
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsDisableLastAccessUpdate|2147483648/2147483650/2147483651/0/1',
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsDisable8dot3NameCreation|2',
        'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem|NtfsMemoryUsage|0/1'
    )
    Test-RegGroup Tweak 'Таймер (GlobalTimerResolutionRequests)' @('HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel|GlobalTimerResolutionRequests|0')
    Test-RegGroup Tweak 'Очередь ввода мыши и клавиатуры (DataQueueSize)' @(
        'HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters|MouseDataQueueSize|100',
        'HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters|KeyboardDataQueueSize|100'
    )
    if ($Sys.IsWin11) {
        Add-Check Tweak 'Старое меню правой кнопки (Win11)' (Test-RegKey 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32') ''
    }
    if ($Admin) {
        try {
            $mm = Get-MMAgent -ErrorAction Stop
            $off = @()
            if (-not $mm.MemoryCompression) { $off += 'сжатие памяти' }
            if (-not $mm.PageCombining) { $off += 'объединение страниц' }
            Add-Check Tweak 'Менеджер памяти (MMAgent)' ($off.Count -gt 0) @{ $true = ('выкл: ' + ($off -join ', ')); $false = '' }[$off.Count -gt 0]
        } catch {}
    }
    $pf = Get-RegText $MEM 'PagingFiles'
    $pfStock = ($null -eq $pf) -or ($pf -match '^(\?|[A-Za-z]):\\pagefile\.sys( 0 0)?$')
    Add-Check Setting 'Файл подкачки' (-not $pfStock) @{ $true = ('задан вручную: ' + @{ $true = 'нет файла'; $false = ($pf -replace "`n", '; ') }[[string]::IsNullOrWhiteSpace($pf)]); $false = '' }[-not $pfStock]
    Test-RegGroup Setting 'Визуальные эффекты и прозрачность' @(
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects|VisualFXSetting|0/1',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize|EnableTransparency|1',
        "$ADV|TaskbarAnimations|1",
        'HKCU\Software\Microsoft\Windows\DWM|EnableAeroPeek|1'
    )
    Test-RegGroup Setting 'Залипание клавиш и повтор клавиатуры' @(
        'HKCU\Control Panel\Accessibility\StickyKeys|Flags|510',
        'HKCU\Control Panel\Keyboard|KeyboardDelay|1'
    )
    Test-RegGroup Setting 'Акселерация мыши' @('HKCU\Control Panel\Mouse|MouseSpeed|1')
}

function Test-Video($Sys) {
    Section 'Видеокарта и игры'
    Test-RegGroup Tweak 'Game DVR выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR|AllowGameDVR|1')
    Test-RegGroup Tweak 'Оптимизация во весь экран (FSO) выкл для всех игр' @(
        'HKCU\System\GameConfigStore|GameDVR_HonorUserFSEBehaviorMode|0',
        'HKCU\System\GameConfigStore|GameDVR_DXGIHonorFSEWindowsCompatible|0',
        'HKCU\System\GameConfigStore|GameDVR_EFSEFeatureFlags|0'
    )
    Test-RegGroup Tweak 'Задержки драйвера видеокарты (TdrDelay, TdrLevel)' @(
        'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers|TdrDelay|',
        'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers|TdrLevel|',
        'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers|TdrDdiDelay|'
    )
    Test-RegGroup Setting 'Фоновая запись Game Bar' @('HKCU\System\GameConfigStore|GameDVR_Enabled|1')
    Test-RegGroup Setting 'Игровой режим Windows' @('HKCU\Software\Microsoft\GameBar|AutoGameModeEnabled|1')
    $dx = Get-RegText 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings'
    $swap = ($dx -match 'SwapEffectUpgradeEnable=1')
    Add-Check Setting 'Оптимизация оконных игр' $swap @{ $true = 'вкл'; $false = '' }[$swap]
    # HAGS и MSI mode драйверы часто включают сами, поэтому только для сведения
    $hags = Get-RegText 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    Add-Check Info 'Аппаратное планирование GPU (HAGS)' $false @{ $true = 'вкл'; $false = 'выкл или по умолчанию' }[$hags -eq '2']
    $msi = @()
    try {
        foreach ($v in @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { [string]$_.PNPDeviceID -match '^PCI\\' })) {
            $mk = 'HKLM\SYSTEM\CurrentControlSet\Enum\' + $v.PNPDeviceID + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
            $msi += ([string]$v.Name + ' ' + @{ $true = 'вкл'; $false = 'выкл' }[(Get-RegText $mk 'MSISupported') -eq '1'])
        }
    } catch {}
    if ($msi.Count -gt 0) { Add-Check Info 'MSI mode видеокарты' $false ($msi -join ', ') }
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
        if ($kind -eq 'Balanced') { Add-Check Tweak 'Схема питания' $false ('«' + $act.Name + '»') }
        elseif ($kind -eq 'High' -or $kind -eq 'Saver') { Add-Check Setting 'Схема питания' $true ('«' + $act.Name + '»') }
        else { Add-Check Tweak 'Схема питания' $true ('«' + $act.Name + '»' + @{ $true = ' (максимальная, включается только командой)'; $false = ' (своя схема, не из Windows)' }[$kind -eq 'Ultimate']) }
    }
    foreach ($s in @($schemes | Where-Object { -not $_.Active -and -not $std.ContainsKey($_.Guid) })) {
        Add-Trace ('Своя схема питания «' + $s.Name + '» (не включена)')
    }
    $hib = Get-RegText 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
    $hibOff = ($hib -eq '0') -and -not (Test-Path -LiteralPath ($env:SystemDrive + '\hiberfil.sys'))
    Add-Check Tweak 'Гибернация выкл (powercfg /h off)' $hibOff ''
    Test-RegGroup Setting 'Быстрый запуск Windows' @('HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power|HiberbootEnabled|1')

    if (-not $Admin) { Add-Check Info 'Загрузчик (bcdedit)' $false 'нужны права администратора'; return }
    $b = Invoke-Native 'bcdedit.exe' @('/enum', '{current}')
    if ($b.Code -ne 0) { Add-Check Info 'Загрузчик (bcdedit)' $false 'не прочитался'; return }
    $bcd = @{}
    foreach ($l in ($b.Out -split "`n")) { if ($l -match '^(\w+)\s+(\S.*)$') { $bcd[$Matches[1].ToLower()] = $Matches[2].Trim() } }
    $items = @(
        @('disabledynamictick', 'Dynamic tick выкл', '^(Yes|Да)'),
        @('useplatformclock', 'Принудительный HPET (useplatformclock)', '.'),
        @('useplatformtick', 'Платформенный таймер (useplatformtick)', '^(Yes|Да)'),
        @('tscsyncpolicy', 'Синхронизация TSC (tscsyncpolicy)', '.'),
        @('hypervisorlaunchtype', 'Гипервизор выкл', '^(Off|Выкл)'),
        @('x2apicpolicy', 'x2APIC (x2apicpolicy)', '.'),
        @('nx', 'Защита DEP выкл', '^AlwaysOff')
    )
    foreach ($it in $items) {
        $v = $bcd[$it[0]]
        $hit = ($null -ne $v) -and ($v -match $it[2])
        Add-Check Tweak ('Загрузчик: ' + $it[1]) $hit @{ $true = ($it[0] + ' ' + $v); $false = '' }[$hit]
    }
}

function Test-Network {
    Section 'Сеть'
    Test-RegGroup Tweak 'Ограничение сети при звуке (NetworkThrottlingIndex)' @("$MM|NetworkThrottlingIndex|10")
    Test-RegGroup Tweak 'Раздача обновлений другим ПК выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization|DODownloadMode|')
    Test-RegGroup Tweak 'Резерв полосы QoS (NonBestEffortLimit)' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched|NonBestEffortLimit|')
    $tcp = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    Test-RegGroup Tweak 'Параметры TCP/IP' @(
        "$tcp|DefaultTTL|", "$tcp|Tcp1323Opts|", "$tcp|TcpMaxDupAcks|", "$tcp|MaxUserPort|",
        "$tcp|TcpTimedWaitDelay|", "$tcp|SackOpts|", "$tcp|TcpNoDelay|", "$tcp|TcpAckFrequency|", "$tcp|MaxConnectionsPerServer|"
    )
    $nagle = 0
    foreach ($i in @(Get-RegSubKeys ($tcp + '\Interfaces'))) {
        $p = $tcp + '\Interfaces\' + $i
        if ($null -ne (Get-RegText $p 'TcpAckFrequency') -or $null -ne (Get-RegText $p 'TCPNoDelay') -or $null -ne (Get-RegText $p 'TcpDelAckTicks')) { $nagle++ }
    }
    Add-Check Tweak 'Алгоритм Нейгла выкл (TcpAckFrequency, TCPNoDelay)' ($nagle -gt 0) @{ $true = ('на ' + $nagle + ' интерфейсах'); $false = '' }[$nagle -gt 0]
    try {
        $ts = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop | Select-Object -First 1
        $at = [string]$ts.AutoTuningLevelLocal
        if ($at) { Add-Check Tweak 'Автонастройка окна TCP' ($at -ne 'Normal') @{ $true = $at; $false = '' }[$at -ne 'Normal'] }
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
        Add-Check Tweak ('Драйвер сетевой ' + [string]$a.InterfaceDescription) ($diff.Count -gt 0) $d
    }
}

function Test-Privacy($Sys) {
    Section 'Телеметрия, реклама, Bing'
    $pol = 'HKLM\SOFTWARE\Policies\Microsoft\Windows'
    Test-RegGroup Tweak 'Телеметрия и история активности выкл политиками' @(
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
    )
    Test-RegGroup Tweak 'Bing и веб-подсказки в поиске выкл' @(
        'HKCU\Software\Policies\Microsoft\Windows\Explorer|DisableSearchBoxSuggestions|',
        "$pol\Windows Search|DisableWebSearch|",
        "$pol\Windows Search|ConnectedSearchUseWeb|",
        "$pol\Windows Search|AllowCortana|"
    )
    if ($Sys.IsWin11) {
        Test-RegGroup Tweak 'Виджеты, Copilot, Recall выкл политиками' @(
            'HKLM\SOFTWARE\Policies\Microsoft\Dsh|AllowNewsAndInterests|',
            'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot|TurnOffWindowsCopilot|',
            "$pol\WindowsCopilot|TurnOffWindowsCopilot|",
            'HKCU\Software\Policies\Microsoft\Windows\WindowsAI|DisableAIDataAnalysis|',
            "$pol\WindowsAI|DisableAIDataAnalysis|"
        )
    } else {
        Test-RegGroup Tweak '«Новости и интересы» выкл политикой' @("$pol\Windows Feeds|EnableFeeds|")
    }
    Test-RegGroup Tweak 'Edge и Chrome: фон, предзапуск, сон вкладок политиками' @(
        'HKLM\SOFTWARE\Policies\Microsoft\Edge|StartupBoostEnabled|',
        'HKLM\SOFTWARE\Policies\Microsoft\Edge|BackgroundModeEnabled|',
        'HKLM\SOFTWARE\Policies\Microsoft\Edge|SleepingTabsEnabled|',
        'HKLM\SOFTWARE\Policies\Google\Chrome|HighEfficiencyModeEnabled|',
        'HKLM\SOFTWARE\Policies\Google\Chrome|BackgroundModeEnabled|'
    )
    Test-RegGroup Setting 'Реклама, советы и предложения Windows' @(
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
    )
    Test-RegGroup Setting 'Фоновые приложения' @('HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications|GlobalUserDisabled|0')

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
        Add-Check Tweak 'Задачи телеметрии в планировщике' ($off.Count -ge 2) @{ $true = ('выкл ' + $off.Count + ' из ' + $all + ': ' + (($off | Select-Object -First 4) -join ', ')); $false = '' }[$off.Count -ge 2]
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
    $danger = @('wuauserv', 'UsoSvc', 'BITS', 'WaaSMedicSvc', 'WinDefend', 'SecurityHealthService', 'wscsvc', 'mpssvc', 'EventLog', 'Schedule')
    foreach ($n in $names) {
        $st = Get-RegText ('HKLM\SYSTEM\CurrentControlSet\Services\' + $n) 'Start'
        if ($null -eq $st) { continue }
        $dn = $n
        try { $dn = [string](Get-Service -Name $n -ErrorAction Stop).DisplayName + ' (' + $n + ')' } catch {}
        $off = ($st -eq '4')
        $d = ''
        if ($off) { $d = 'отключена'; if ($danger -contains $n) { $d += ', это ломает обновления или защиту Windows' } }
        Add-Check Tweak $dn $off $d
    }
}

function Test-Security($Sys, [bool]$Admin) {
    Section 'Защита и обновления'
    Test-RegGroup Tweak 'Контроль учётных записей (UAC) выкл' @('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System|EnableLUA|1')
    Test-RegGroup Tweak 'VBS выкл через реестр' @('HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard|EnableVirtualizationBasedSecurity|1')
    Test-RegGroup Tweak 'Защита Spectre и Meltdown изменена' @(
        "$MEM|FeatureSettingsOverride|",
        "$MEM|FeatureSettingsOverrideMask|"
    )
    Test-RegGroup Tweak 'Defender выкл политиками' @(
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender|DisableAntiSpyware|',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender|DisableAntiVirus|',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection|DisableRealtimeMonitoring|',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection|DisableBehaviorMonitoring|',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet|SpynetReporting|',
        'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet|SubmitSamplesConsent|'
    )
    Test-RegGroup Tweak 'SmartScreen выкл политикой' @('HKLM\SOFTWARE\Policies\Microsoft\Windows\System|EnableSmartScreen|')
    try {
        $mp = Get-MpPreference -ErrorAction Stop
        $cpu = [int]$mp.ScanAvgCPULoadFactor
        Add-Check Tweak 'Defender: нагрузка проверки на процессор' ($cpu -ne 50) @{ $true = ('' + $cpu + '% (сток 50%)'); $false = '' }[$cpu -ne 50]
        if ($Admin) {
            $ex = @(@($mp.ExclusionPath) + @($mp.ExclusionProcess) | Where-Object { $_ })
            Add-Check Setting 'Исключения Defender' ($ex.Count -gt 0) @{ $true = ('' + $ex.Count + ': ' + (($ex | Select-Object -First 3) -join '; ')); $false = '' }[$ex.Count -gt 0]
        }
    } catch { Add-Check Info 'Defender' $false 'не активен (стоит другой антивирус или Defender вырезан)' }
    $vbs = $null
    try { $vbs = [int](Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop).VirtualizationBasedSecurityStatus } catch {}
    if ($null -ne $vbs) { Add-Check Info 'VBS (изоляция ядра) сейчас' $false @{ $true = 'работает'; $false = 'не работает' }[$vbs -eq 2] }

    $wu = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    Test-RegGroup Tweak 'Обновления Windows ограничены политиками' @(
        "$wu\AU|NoAutoUpdate|",
        "$wu\AU|AUOptions|",
        "$wu\AU|NoAutoRebootWithLoggedOnUsers|",
        "$wu|DisableWindowsUpdateAccess|",
        "$wu|SetDisableUXWUAccess|",
        "$wu|DeferFeatureUpdates|",
        "$wu|TargetReleaseVersion|",
        "$wu|ExcludeWUDriversInQualityUpdate|"
    )
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
    Add-Check Setting 'Обновления на паузе' $paused $d
}

function Test-Apps($Sys) {
    Section 'Приложения'
    if ($Sys.EditionId -match 'EnterpriseS|IoT|Server') { Add-Check Info 'Встроенные приложения' $false ('редакция ' + $Sys.EditionId + ', магазина и приложений в ней нет и так'); return }
    $std = @('Microsoft.WindowsStore', 'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'Microsoft.XboxGamingOverlay', 'Microsoft.GetHelp', 'Microsoft.BingWeather', 'Microsoft.WindowsAlarms', 'Microsoft.WindowsCamera', 'Microsoft.WindowsFeedbackHub', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.ScreenSketch', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsSoundRecorder', 'Microsoft.ZuneMusic', 'Microsoft.DesktopAppInstaller')
    $have = @()
    try { $have = @(Get-AppxPackage -ErrorAction Stop | ForEach-Object { [string]$_.Name }) } catch { Add-Check Info 'Встроенные приложения' $false 'список не прочитался'; return }
    $gone = @($std | Where-Object { $have -notcontains $_ } | ForEach-Object { $_ -replace '^Microsoft\.', '' })
    # Пару приложений люди удаляют сами, массовое удаление делают скрипты
    $kind = @{ $true = 'Tweak'; $false = 'Setting' }[$gone.Count -ge 5]
    Add-Check $kind 'Удалены встроенные приложения' ($gone.Count -ge 3) @{ $true = ('' + $gone.Count + ' из ' + $std.Count + ': ' + (($gone | Select-Object -First 6) -join ', ') + @{ $true = ' и др.'; $false = '' }[$gone.Count -gt 6]); $false = '' }[$gone.Count -ge 3]
    if ($have -notcontains 'Microsoft.WindowsStore') { Add-Check Tweak 'Microsoft Store удалён' $true '' }
    $edge = @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'), (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')) | Where-Object { Test-Path -LiteralPath $_ }
    Add-Check Tweak 'Microsoft Edge удалён' (@($edge).Count -eq 0) ''
}

# ---------------------------------------------------------------------
#  Следы оптимизаторов
# ---------------------------------------------------------------------
function Find-Traces($Sys, [bool]$Admin) {
    Section 'Следы оптимизаторов'
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
            if ($rps.Count -eq 0) { Add-Check Info 'Точки восстановления' $false 'нет ни одной' }
        } catch { Add-Check Info 'Точки восстановления' $false 'не прочитались (восстановление системы выключено?)' }
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

    if ($Traces.Count -eq 0) { Out-Line '   Следов оптимизаторов не нашёл.' 'DarkGray' }
}

# ---------------------------------------------------------------------
#  Итог
# ---------------------------------------------------------------------
function Show-Summary {
    Close-Section
    $tw = @($Checks | Where-Object { $_.Kind -eq 'Tweak' })
    $twOn = @($tw | Where-Object { $_.Changed })
    $se = @($Checks | Where-Object { $_.Kind -eq 'Setting' })
    $seOn = @($se | Where-Object { $_.Changed })
    $pct = 0
    if ($tw.Count -gt 0) { $pct = [int][math]::Round(100 * $twOn.Count / $tw.Count) }

    Out-Line ''
    Out-Line '===================================================================='
    Out-Line ('  ТВИКОВ НАЙДЕНО: ' + $twOn.Count + ' из ' + $tw.Count + ' проверенных (' + $pct + '%)') @{ $true = 'Green'; $false = 'Yellow' }[$twOn.Count -eq 0]
    Out-Line ('  Ручных настроек не как в стоке: ' + $seOn.Count + ' из ' + $se.Count) 'White'
    Out-Line ('  Следов оптимизаторов: ' + $Traces.Count) @{ $true = 'Green'; $false = 'Magenta' }[$Traces.Count -eq 0]
    Out-Line ''
    if ($twOn.Count -eq 0 -and $Traces.Count -eq 0) {
        Out-Line '  Вывод: чистая система, твиков и следов оптимизаторов нет.' 'Green'
    } elseif ($twOn.Count -le 3 -and $Traces.Count -eq 0) {
        Out-Line '  Вывод: почти чистая система, пара точечных правок. На оптимизацию не похоже.' 'Green'
    } elseif ($twOn.Count -le 3) {
        Out-Line '  Вывод: твиков почти нет, но оптимизаторы на этом ПК были.' 'Yellow'
        Out-Line '  Скорее всего, их откатили, не доделали или настройки вернуло обновление Windows.' 'DarkGray'
    } else {
        Out-Line '  Вывод: систему уже оптимизировали.' 'Yellow'
        $byCat = @($twOn | Group-Object -Property Cat | Sort-Object -Property Count -Descending | ForEach-Object { $_.Name + ' ' + $_.Count })
        if ($byCat.Count -gt 0) { Out-Line ('  Где: ' + ($byCat -join ' · ')) 'Yellow' }
        Out-Line '  Часть прироста от оптимизации уже получена, повторная даст меньше, чем на чистой Windows.' 'DarkGray'
    }
    Out-Line '===================================================================='
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

    foreach ($step in @(
        { Test-System $sys $admin },
        { Test-Video $sys },
        { Test-Power $sys $admin },
        { Test-Network },
        { Test-Privacy $sys },
        { Test-Services },
        { Test-Security $sys $admin },
        { Test-Apps $sys },
        { Find-Traces $sys $admin }
    )) {
        try { & $step } catch { Out-Line ('   [ОШИБ] ' + $_.Exception.Message + ' (проверяю дальше)') 'Red' }
    }
    Show-Summary

    Out-Line ''
    Out-Line ('  ' + $BR.Seller) 'DarkGray'
    Out-Line ('  ' + $BR.Social) 'DarkGray'
    Out-Line ('  ' + $BR.Repo) 'DarkGray'
    try {
        [IO.File]::WriteAllText($ReportPath, (($Report.ToArray() + '') -join "`r`n"), $Utf8Bom)
        Write-Host ''
        Write-Host ('  Отчёт сохранён: ' + $ReportPath) -ForegroundColor Green
    } catch { Write-Host ('  Отчёт не сохранился: ' + $_.Exception.Message) -ForegroundColor Red }
    Wait-Key
}

try { Main }
catch {
    Write-Host ('  Ошибка: ' + $_.Exception.Message) -ForegroundColor Red
    Wait-Key
}
