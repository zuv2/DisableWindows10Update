#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$TOTAL_STEPS = 5
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$script:LogFile = Join-Path $PSScriptRoot ("EnableWindowsUpdateV1_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param([string]$Level, [string]$Text)
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Text
    try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}
function Write-Step ([string]$Text, [int]$Step) {
    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor DarkCyan
    Write-Host "  [$Step/$TOTAL_STEPS] $Text" -ForegroundColor Cyan
    Write-Host ("=" * 64) -ForegroundColor DarkCyan
    Write-Log 'STEP' "[$Step/$TOTAL_STEPS] $Text"
}
function Write-OK ([string]$Text) {
    Write-Host "   [OK] $Text" -ForegroundColor Green
    Write-Log 'OK' $Text
}
function Write-WARN ([string]$Text) {
    Write-Host "   [경고] $Text" -ForegroundColor Yellow
    $script:warnings.Add($Text)
    Write-Log 'WARN' $Text
}
function Write-FAIL ([string]$Text) {
    Write-Host "   [실패] $Text" -ForegroundColor Red
    $script:failures.Add($Text)
    Write-Log 'FAIL' $Text
}
function Write-INFO ([string]$Text) {
    Write-Host "   [  ] $Text" -ForegroundColor DarkGray
    Write-Log 'INFO' $Text
}

function Remove-RegValueIfPresent {
    param([string]$Path,[string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $p = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $p) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
        return $true
    }
    return $false
}

# 관리자 확인
$principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '관리자 권한이 필요합니다. BAT 파일을 실행하면 UAC 승격을 시도합니다.' -ForegroundColor Red
    exit 1
}

try { Start-Transcript -Path $script:LogFile -Append -ErrorAction SilentlyContinue | Out-Null } catch {}
Write-Log 'START' "Enable V1 시작 / PS=$($PSVersionTable.PSVersion)"

Clear-Host
Write-Host ""
Write-Host '================================================================' -ForegroundColor Green
Write-Host '  Windows Update Enable V1' -ForegroundColor Green
Write-Host '  Disable V4.x의 가역적 설정만 복구' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host " 로그: $script:LogFile" -ForegroundColor DarkGray

# [1/5] Disable V4가 넣은 정책 값 제거
Write-Step 'Windows Update 차단 정책 제거' 1
$WUPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$AUPath = "$WUPath\AU"
$DOPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'

$values = @(
    @($WUPath,'WUServer'),
    @($WUPath,'WUStatusServer'),
    @($WUPath,'UpdateServiceUrlAlternate'),
    @($WUPath,'UseWUServer'),
    @($WUPath,'DoNotConnectToWindowsUpdateInternetLocations'),
    @($WUPath,'SetDisableUXWUAccess'),
    @($WUPath,'ExcludeWUDriversInQualityUpdate'),
    @($WUPath,'TargetReleaseVersion'),
    @($WUPath,'TargetReleaseVersionInfo'),
    @($AUPath,'NoAutoUpdate'),
    @($AUPath,'AUOptions'),
    @($AUPath,'NoAutoRebootWithLoggedOnUsers'),
    @($AUPath,'AlwaysAutoRebootAtScheduledTime'),
    @($DOPath,'DODownloadMode')
)
$removed = 0
foreach ($v in $values) {
    try {
        if (Remove-RegValueIfPresent -Path $v[0] -Name $v[1]) { $removed++ }
    } catch {
        Write-WARN "$($v[1]) 제거 실패: $($_.Exception.Message)"
    }
}
Write-OK "V4 차단 정책 값 $removed개 제거"

# [2/5] 서비스 시작 유형 복구
# Windows 빌드별 기본값이 조금씩 다를 수 있으므로 보호 서비스까지 '정확한 공장값'을 강제하지 않고,
# 업데이트가 동작 가능한 보수적인 시작 유형으로 되돌린다.
Write-Step 'Windows Update 관련 서비스 시작 유형 복구' 2
$serviceDefaults = @{
    'wuauserv'     = 3  # Manual
    'BITS'         = 3  # Manual
    'UsoSvc'       = 3  # Manual
    'WaaSMedicSvc' = 3  # Manual
    'DoSvc'        = 3  # Manual
    'uhssvc'       = 3  # Manual
}
foreach ($svc in $serviceDefaults.Keys) {
    $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (-not (Test-Path -LiteralPath $svcPath)) {
        Write-INFO "${svc}: 서비스 키 없음"
        continue
    }
    try {
        New-ItemProperty -LiteralPath $svcPath -Name 'Start' -Value $serviceDefaults[$svc] -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-OK "${svc}: Start=$($serviceDefaults[$svc]) (Manual)"
    } catch {
        Write-WARN "${svc}: 시작 유형 복구 실패: $($_.Exception.Message)"
    }
}

# 실제 업데이트 확인에 필요한 핵심 서비스만 시작 시도
foreach ($svc in @('BITS','wuauserv')) {
    try {
        Start-Service -Name $svc -ErrorAction Stop
        Write-OK "${svc}: 서비스 시작"
    } catch {
        Write-INFO "${svc}: 즉시 시작하지 못함/필요 시 Windows가 시작함 ($($_.Exception.Message))"
    }
}

# [3/5] V4가 만든 예방 파일만 제거
Write-Step 'UpdateAssistant / rempl 예방 파일 제거' 3
foreach ($item in @(
    @("$env:SystemRoot\UpdateAssistant",'UpdateAssistant'),
    @("$env:ProgramFiles\rempl",'rempl')
)) {
    $path = $item[0]; $label = $item[1]
    try {
        if ((Test-Path -LiteralPath $path -PathType Leaf)) {
            $obj = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if ($obj.IsReadOnly) { $obj.IsReadOnly = $false }
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            Write-OK "$label 예방 파일 제거"
        } elseif (Test-Path -LiteralPath $path -PathType Container) {
            Write-INFO "$label 경로는 현재 폴더임 - 건드리지 않음"
        } else {
            Write-INFO "$label 예방 파일 없음"
        }
    } catch {
        Write-WARN "$label 예방 파일 제거 실패: $($_.Exception.Message)"
    }
}

# [4/5] Disable V4 Aggressive가 넣었을 수 있는 hosts 블록만 제거
# 시스템 hosts의 다른 내용은 보존한다.
Write-Step 'V4 hosts 차단 블록 정리' 4
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$begin = '# ===== Windows Update Block v4 ====='
$end   = '# ===== End Windows Update Block v4 ====='
try {
    if (Test-Path -LiteralPath $hostsPath) {
        $raw = Get-Content -LiteralPath $hostsPath -Raw -ErrorAction Stop
        $pattern = '(?ms)^\s*' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end) + '\s*(?:\r?\n)?'
        if ([regex]::IsMatch($raw,$pattern)) {
            $new = [regex]::Replace($raw,$pattern,'')
            Set-Content -LiteralPath $hostsPath -Value $new -Encoding ASCII -NoNewline -ErrorAction Stop
            try { & "$env:SystemRoot\System32\ipconfig.exe" /flushdns 2>$null | Out-Null } catch {}
            Write-OK 'V4 hosts 차단 블록 제거'
        } else {
            Write-INFO 'V4 hosts 차단 블록 없음'
        }
    } else {
        Write-INFO 'hosts 파일 없음'
    }
} catch {
    Write-WARN "hosts 정리 실패: $($_.Exception.Message)"
}

# [5/5] 의도적으로 손대지 않는 영역 안내
Write-Step '복구 범위 확인' 5
Write-INFO '예약 작업은 강제로 재활성화하지 않음'
Write-INFO 'SoftwareDistribution 캐시는 복원 대상이 아님'
Write-INFO 'Aggressive 모드의 SYSTEM Deny ACL / WaaSMedicSvc.dll 변경은 자동 복구하지 않음'

# Aggressive 흔적이 보이면 경고만 한다.
$bak = "$env:SystemRoot\System32\WaaSMedicSvc.dll.bak_v4"
if (Test-Path -LiteralPath $bak) {
    Write-WARN 'WaaSMedicSvc.dll.bak_v4 발견: 이전 Aggressive 실행 흔적일 수 있음. 이 스크립트는 DLL을 자동 복원하지 않습니다.'
}

Write-Host ""
Write-Host '=========================== 결과 ===========================' -ForegroundColor Cyan
if ($failures.Count -eq 0) { Write-Host '치명적 실패 없음.' -ForegroundColor Green }
else {
    Write-Host "실패 $($failures.Count)개:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
}
if ($warnings.Count -gt 0) {
    Write-Host "경고 $($warnings.Count)개:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
Write-Host "로그 파일: $script:LogFile" -ForegroundColor Cyan
Write-Host 'Windows Update 설정 화면에서 업데이트 확인을 한 번 실행하면 됩니다.' -ForegroundColor DarkYellow

Write-Log 'END' "실패=$($failures.Count), 경고=$($warnings.Count)"
try { Stop-Transcript | Out-Null } catch {}
if (-not $NoPause) { Read-Host '엔터를 눌러 종료하세요' | Out-Null }
if ($failures.Count -gt 0) { exit 2 } else { exit 0 }
