#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Aggressive,
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$TOTAL_STEPS = 8
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$script:LogFile = Join-Path $PSScriptRoot ("DisableWindowsUpdateV4_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

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

function Set-RegValue {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Value,
        [Parameter(Mandatory=$true)][ValidateSet('String','ExpandString','Binary','DWord','MultiString','QWord')][string]$Type
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
}

function Get-AdminsSidString { return 'S-1-5-32-544' }
function Get-AdminsIdentity {
    return (New-Object System.Security.Principal.SecurityIdentifier -ArgumentList (Get-AdminsSidString))
}

# 관리자 확인
$principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList ([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "관리자 권한이 필요합니다. BAT 파일을 실행하면 UAC 승격을 시도합니다." -ForegroundColor Red
    exit 1
}

try { Start-Transcript -Path $script:LogFile -Append -ErrorAction SilentlyContinue | Out-Null } catch {}
Write-Log 'START' "V4 시작 / Aggressive=$Aggressive / PS=$($PSVersionTable.PSVersion)"

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Windows Update 차단 스크립트 V4                      ║" -ForegroundColor Green
Write-Host "║       오류 로깅 + SID 처리 + 표준/강경 모드 분리           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host (" 모드: {0}" -f $(if ($Aggressive) { '강경(Aggressive)' } else { '표준(Standard)' })) -ForegroundColor Yellow
Write-Host " 로그: $script:LogFile" -ForegroundColor DarkGray

# [1/8] 정책
Write-Step "Windows Update 정책 및 WSUS 루프백 설정" 1
$WUPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$AUPath = "$WUPath\AU"
$DOPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'

$policies = @(
    @($WUPath,'WUServer','http://0.0.0.0','String'),
    @($WUPath,'WUStatusServer','http://0.0.0.0','String'),
    @($WUPath,'UpdateServiceUrlAlternate','http://0.0.0.0','String'),
    @($WUPath,'UseWUServer',1,'DWord'),
    @($WUPath,'DoNotConnectToWindowsUpdateInternetLocations',1,'DWord'),
    @($WUPath,'SetDisableUXWUAccess',1,'DWord'),
    @($WUPath,'ExcludeWUDriversInQualityUpdate',1,'DWord'),
    @($AUPath,'NoAutoUpdate',1,'DWord'),
    @($AUPath,'AUOptions',1,'DWord'),
    @($AUPath,'NoAutoRebootWithLoggedOnUsers',1,'DWord'),
    @($AUPath,'AlwaysAutoRebootAtScheduledTime',0,'DWord'),
    @($DOPath,'DODownloadMode',0,'DWord')
)
$policyFail = 0
foreach ($p in $policies) {
    try { Set-RegValue -Path $p[0] -Name $p[1] -Value $p[2] -Type $p[3] }
    catch { $policyFail++; Write-FAIL "$($p[1]): $($_.Exception.Message)" }
}
if ($policyFail -eq 0) { Write-OK '정책 값 적용 완료' }

# [2/8] 버전 고정
Write-Step '현재 Windows 버전 고정 (TargetReleaseVersion)' 2
try {
    $ntKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $version = if ($ntKey.DisplayVersion) { [string]$ntKey.DisplayVersion } else { [string]$ntKey.ReleaseId }
    Set-RegValue -Path $WUPath -Name 'TargetReleaseVersion' -Value 1 -Type DWord
    if ($version) {
        Set-RegValue -Path $WUPath -Name 'TargetReleaseVersionInfo' -Value $version -Type String
        Write-OK "현재 릴리스 [$version] 고정 정책 적용"
    } else { Write-WARN '현재 Windows 릴리스 문자열을 확인하지 못함' }
} catch { Write-FAIL "버전 고정: $($_.Exception.Message)" }

# [3/8] WaaSMedicSvc
Write-Step 'WaaSMedicSvc 처리' 3
$medicRegNative = 'SYSTEM\CurrentControlSet\Services\WaaSMedicSvc'
$medicRegPS = "HKLM:\$medicRegNative"
if (-not (Test-Path $medicRegPS)) {
    Write-INFO 'WaaSMedicSvc 레지스트리 키 없음'
} else {
    try {
        Set-RegValue -Path $medicRegPS -Name 'Start' -Value 4 -Type DWord
        Write-OK 'WaaSMedicSvc Start=4 설정 시도 완료'
    } catch { Write-WARN "WaaSMedicSvc Start=4 거부: $($_.Exception.Message)" }

    if ($Aggressive) {
        Write-INFO '강경 모드: WaaSMedicSvc 키 ACL 변경 시도'
        $keyOwn=$null; $keyPerm=$null; $keyFinal=$null
        try {
            $adminsSid = Get-AdminsIdentity
            $systemSid = New-Object System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-18'
            $keyOwn = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                $medicRegNative,
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if (-not $keyOwn) { throw 'TakeOwnership 권한으로 레지스트리 키를 열 수 없음' }
            $aclOwn = $keyOwn.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
            $aclOwn.SetOwner($adminsSid)
            $keyOwn.SetAccessControl($aclOwn)
            $keyOwn.Close(); $keyOwn=$null
            Write-OK 'WaaSMedicSvc 키 소유권을 Administrators SID로 변경'

            $full = [System.Security.AccessControl.RegistryRights]::FullControl
            $noneI = [System.Security.AccessControl.InheritanceFlags]::None
            $noneP = [System.Security.AccessControl.PropagationFlags]::None
            $allow = [System.Security.AccessControl.AccessControlType]::Allow
            $deny = [System.Security.AccessControl.AccessControlType]::Deny

            $keyPerm = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                $medicRegNative,
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if (-not $keyPerm) { throw 'ChangePermissions 권한으로 레지스트리 키를 열 수 없음' }
            $acl = $keyPerm.GetAccessControl()
            $allowRule = New-Object System.Security.AccessControl.RegistryAccessRule -ArgumentList @($adminsSid,$full,$noneI,$noneP,$allow)
            $acl.AddAccessRule($allowRule)
            $keyPerm.SetAccessControl($acl)
            $keyPerm.Close(); $keyPerm=$null

            Set-RegValue -Path $medicRegPS -Name 'Start' -Value 4 -Type DWord

            $keyFinal = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                $medicRegNative,
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if (-not $keyFinal) { throw '최종 ACL 설정을 위해 키를 열 수 없음' }
            $aclFinal = $keyFinal.GetAccessControl()
            $denyRule = New-Object System.Security.AccessControl.RegistryAccessRule -ArgumentList @($systemSid,$full,$noneI,$noneP,$deny)
            $aclFinal.AddAccessRule($denyRule)
            $keyFinal.SetAccessControl($aclFinal)
            $keyFinal.Close(); $keyFinal=$null
            Write-OK '강경 모드: SYSTEM Deny ACL 적용 완료'
        } catch {
            Write-WARN "강경 ACL 처리 실패(계속 진행): $($_.Exception.Message)"
        } finally {
            foreach ($k in @($keyOwn,$keyPerm,$keyFinal)) { if ($k) { try { $k.Close() } catch {} } }
        }
    } else {
        Write-INFO '표준 모드: SYSTEM Deny ACL은 건드리지 않음'
    }
}

# [4/8] DLL
Write-Step 'WaaSMedicSvc.dll 처리' 4
$medicDll = "$env:SystemRoot\System32\WaaSMedicSvc.dll"
$medicDllBak = "$env:SystemRoot\System32\WaaSMedicSvc.dll.bak_v4"
if (-not $Aggressive) {
    Write-INFO '표준 모드: 보호된 시스템 DLL은 변경하지 않음'
} elseif (-not (Test-Path $medicDll)) {
    if (Test-Path $medicDllBak) { Write-OK 'WaaSMedicSvc.dll이 이미 .bak_v4로 변경되어 있음' }
    else { Write-INFO 'WaaSMedicSvc.dll 없음' }
} else {
    try {
        $take = Start-Process "$env:SystemRoot\System32\takeown.exe" -ArgumentList @('/f',$medicDll) -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($take.ExitCode -ne 0) { Write-WARN "takeown 종료 코드 $($take.ExitCode)" }
        $sidArg = '*S-1-5-32-544:F'
        $ic = Start-Process "$env:SystemRoot\System32\icacls.exe" -ArgumentList @($medicDll,'/grant',$sidArg) -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($ic.ExitCode -ne 0) { Write-WARN "icacls 종료 코드 $($ic.ExitCode)" }
        if (-not (Test-Path $medicDllBak)) {
            Rename-Item -LiteralPath $medicDll -NewName 'WaaSMedicSvc.dll.bak_v4' -Force -ErrorAction Stop
            Write-OK 'WaaSMedicSvc.dll -> .bak_v4 변경 완료'
        } else { Write-WARN '.bak_v4가 이미 존재하여 이름 변경 생략' }
    } catch {
        Write-WARN "실시간 DLL 변경 실패. 재부팅 예약 시도: $($_.Exception.Message)"
        try {
            $pfro='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            $existing=(Get-ItemProperty -Path $pfro -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations
            $src='\??\'+$medicDll
            $dst='\??\'+$medicDllBak
            $combined=@(@($existing) + @($src,$dst)) | Where-Object { $null -ne $_ -and $_ -ne '' }
            Set-RegValue -Path $pfro -Name 'PendingFileRenameOperations' -Value $combined -Type MultiString
            Write-OK 'DLL 이름 변경을 재부팅 시점으로 예약'
        } catch { Write-FAIL "DLL 변경 예약 실패: $($_.Exception.Message)" }
    }
}

# [5/8] 서비스
Write-Step '업데이트 관련 서비스 비활성화' 5
$servicesToDisable = @('wuauserv','UsoSvc','WaaSMedicSvc','DoSvc','BITS','uhssvc')
foreach ($svc in $servicesToDisable) {
    try { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } catch {}
    $svcPath="HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
    if (Test-Path $svcPath) {
        try { Set-RegValue -Path $svcPath -Name 'Start' -Value 4 -Type DWord; Write-OK "$svc Start=4 설정" }
        catch { Write-WARN "$svc Start=4 실패: $($_.Exception.Message)" }
    } else { Write-INFO "${svc}: 서비스 키 없음" }
}

function Invoke-FolderVaccination {
    param([string]$Path,[string]$Label)
    if (Test-Path $Path -PathType Container) {
        try { & "$env:SystemRoot\System32\takeown.exe" /f $Path /r /d y 2>$null | Out-Null } catch {}
        try { & "$env:SystemRoot\System32\icacls.exe" $Path /grant '*S-1-5-32-544:F' /t 2>$null | Out-Null } catch {}
        try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop } catch { Write-WARN "$Label 기존 폴더 삭제 실패: $($_.Exception.Message)" }
    }
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType File -Force -ErrorAction Stop | Out-Null
            (Get-Item -LiteralPath $Path -Force).IsReadOnly=$true
            Write-OK "$Label 예방 파일 생성"
        } catch { Write-WARN "$Label 예방 파일 생성 실패: $($_.Exception.Message)" }
    } else { Write-INFO "$Label 경로가 이미 존재함" }
}
Invoke-FolderVaccination "$env:SystemRoot\UpdateAssistant" 'UpdateAssistant'
Invoke-FolderVaccination "$env:ProgramFiles\rempl" 'rempl'

# [6/8] 예약 작업
Write-Step '업데이트 관련 예약 작업 비활성화' 6
$taskPaths=@('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\','\Microsoft\Windows\WaaSMedic\')
$taskOK=0; $taskWarn=0
foreach ($tp in $taskPaths) {
    $tasks=Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue
    foreach ($t in @($tasks)) {
        if (-not $t) { continue }
        try {
            if ($t.State -eq 'Running') { Stop-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue }
            Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null
            $taskOK++
        } catch { $taskWarn++; Write-WARN "예약 작업 거부: $tp$($t.TaskName)" }
    }
}
Write-OK "예약 작업: $taskOK개 비활성화, $taskWarn개 거부"

# [7/8] 네트워크 차단
Write-Step 'Windows Update 네트워크 차단' 7
if (-not $Aggressive) {
    Write-INFO '표준 모드: IP/hosts 차단은 적용하지 않음'
} else {
    $ruleName='WU-Block-v4-Outbound'
    try { Remove-NetFirewallRule -DisplayName 'WU-Block-v4*' -ErrorAction SilentlyContinue | Out-Null } catch {}
    # 고정 IP 목록은 시간이 지나면 부정확해질 수 있으므로 V4에서는 V3 목록을 그대로 재사용하지 않음.
    Write-WARN 'V4는 광범위한 Microsoft IP 대역 차단을 생략함 (다른 Microsoft 서비스 오차단 방지)'

    $hostsPath="$env:SystemRoot\System32\drivers\etc\hosts"
    $begin='# ===== Windows Update Block v4 ====='
    $end='# ===== End Windows Update Block v4 ====='
    $domains=@(
        'windowsupdate.microsoft.com','update.microsoft.com','download.windowsupdate.com',
        'wustat.windows.com','ntservicepack.microsoft.com','fe3.delivery.mp.microsoft.com',
        'tlu.dl.delivery.mp.microsoft.com','fg.download.windowsupdate.com','au.download.windowsupdate.com'
    )
    try {
        $raw=if (Test-Path $hostsPath) { Get-Content -LiteralPath $hostsPath -Raw -ErrorAction Stop } else { '' }
        if ($raw -notlike "*$begin*") {
            $lines=@('',$begin) + ($domains | ForEach-Object { "0.0.0.0 $_" }) + @($end,'')
            Add-Content -LiteralPath $hostsPath -Value ($lines -join "`r`n") -Encoding ASCII -ErrorAction Stop
            Write-OK "hosts에 $($domains.Count)개 Update 도메인 차단 추가"
        } else { Write-OK 'hosts V4 차단 블록이 이미 존재함' }
        & "$env:SystemRoot\System32\ipconfig.exe" /flushdns 2>$null | Out-Null
    } catch { Write-FAIL "hosts 수정 실패: $($_.Exception.Message)" }
}

# [8/8] 캐시
Write-Step 'SoftwareDistribution 다운로드 캐시 정리' 8
$sdDownload="$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $sdDownload) {
    try {
        $items=Get-ChildItem -LiteralPath $sdDownload -Force -ErrorAction SilentlyContinue
        $count=(@($items) | Measure-Object).Count
        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "다운로드 캐시 정리 완료 (상위 항목 $count개)"
    } catch { Write-WARN "캐시 정리 일부 실패: $($_.Exception.Message)" }
} else { Write-INFO 'SoftwareDistribution\\Download 없음' }

try {
    $shutdownProc=Start-Process "$env:SystemRoot\System32\shutdown.exe" -ArgumentList '/a' -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
    if ($shutdownProc -and $shutdownProc.ExitCode -eq 0) { Write-OK '예약된 자동 종료/재부팅 요청 취소' }
} catch {}

Write-Host ""
Write-Host "=========================== 결과 ===========================" -ForegroundColor Cyan
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
if ($Aggressive) { Write-Host '강경 모드 변경사항은 재부팅 후 완전히 반영될 수 있습니다.' -ForegroundColor Yellow }
else { Write-Host '표준 모드는 보호된 시스템 DLL/SYSTEM Deny ACL을 변경하지 않습니다.' -ForegroundColor DarkYellow }

Write-Log 'END' "실패=$($failures.Count), 경고=$($warnings.Count)"
try { Stop-Transcript | Out-Null } catch {}
if (-not $NoPause) { Read-Host '엔터를 눌러 종료하세요' | Out-Null }
if ($failures.Count -gt 0) { exit 2 } else { exit 0 }
