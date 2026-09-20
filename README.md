# Windows Update Control

Windows 10에서 Windows Update 자동 동작을 제어하기 위한 PowerShell/BAT 스크립트입니다.

> **주의:** 시스템 업데이트를 비활성화하면 보안 업데이트와 안정성 수정이 적용되지 않을 수 있습니다. 필요한 경우 `EnableWindowsUpdate.bat`으로 다시 활성화한 뒤 업데이트를 적용하세요.

## 파일

- `DisableWindowsUpdate.bat` — 관리자 권한 승격 후 비활성화 스크립트를 실행합니다.
- `DisableWindowsUpdate.ps1` — Windows Update 관련 정책/서비스 설정을 변경합니다.
- `EnableWindowsUpdate.bat` — 관리자 권한 승격 후 복구 스크립트를 실행합니다.
- `EnableWindowsUpdate.ps1` — Disable 스크립트가 변경한 가역적인 설정을 복구합니다.

## 사용법

1. 저장소를 내려받거나 ZIP을 풉니다.
2. Windows Update를 막으려면 `DisableWindowsUpdate.bat`을 실행합니다.
3. 기본적으로 **Standard** 모드를 사용합니다.
4. 다시 활성화하려면 `EnableWindowsUpdate.bat`을 실행합니다.
5. 활성화 후 재부팅하고 Windows Update에서 업데이트 확인을 실행하는 것을 권장합니다.

## Disable 모드

### Standard

일반적인 사용을 위한 모드입니다. Windows Update 관련 정책과 서비스 시작 설정을 변경하고 다운로드 캐시를 정리합니다. 시스템 DLL 이름 변경이나 SYSTEM Deny ACL 같은 보호 구성요소 변경은 수행하지 않습니다.

### Aggressive

보호된 ACL 및 시스템 DLL 변경까지 시도합니다. Windows servicing, SFC/DISM 또는 이후 업데이트 복구에 영향을 줄 수 있으므로 필요성을 이해하는 경우에만 사용하세요.

## Enable의 복구 범위

`EnableWindowsUpdate.ps1`은 의도적으로 완전한 "공장 초기값 복원" 도구가 아닙니다. Disable 스크립트의 가역적인 변경만 보수적으로 되돌립니다.

복구하는 항목:

- Disable 스크립트가 설정한 Windows Update 정책 값
- 주요 Windows Update 관련 서비스의 시작 유형
- Disable 스크립트가 만든 예방용 파일
- 스크립트 전용 hosts 차단 블록이 존재하는 경우 해당 블록

자동 복구하지 않는 항목:

- 존재하지 않았던 예약 작업을 새로 만들거나 강제로 활성화
- 삭제된 `SoftwareDistribution` 캐시 복원
- Aggressive 모드에서 변경된 보호 ACL의 임의 복구
- Aggressive 모드에서 이름을 변경한 시스템 DLL의 자동 복원

## 로그

실행 시 스크립트와 같은 폴더에 타임스탬프가 포함된 `.log` 파일이 생성됩니다. 오류가 발생하면 해당 로그를 먼저 확인하세요.

## 요구 사항

- Windows 10
- Windows PowerShell 5.1 이상
- 관리자 권한

## License

MIT License. 자세한 내용은 `LICENSE`를 참조하세요.


## 배포/실행 관련

- BAT 런처는 `cmd.exe` 코드 페이지 문제를 피하기 위해 ASCII로 유지합니다.
- BAT는 현재 작업 폴더에 의존하지 않고 `%~dp0` 기준의 절대 경로로 PowerShell 스크립트를 실행합니다.
- PowerShell 스크립트는 Windows PowerShell 5.1에서 한글 문자열이 깨지지 않도록 UTF-8 BOM으로 저장되어 있습니다.
- `DisableWindowsUpdate.bat`과 `DisableWindowsUpdate.ps1`, 또는 `EnableWindowsUpdate.bat`과 `EnableWindowsUpdate.ps1`은 각각 같은 폴더에 있어야 합니다.


## 동작 범위와 복구 모델

### Standard / Aggressive

`Standard`는 시스템의 다른 기능에 대한 부작용을 줄이는 쪽을 우선합니다. 특히 BITS(Background Intelligent Transfer Service)는 Windows Update 전용 서비스가 아니므로 Standard에서는 비활성화하지 않습니다.

`Aggressive`는 더 강한 차단을 원하는 경우에만 사용합니다. BITS 비활성화, 보호된 WaaSMedicSvc 관련 ACL 변경, 시스템 DLL 처리처럼 영향 범위가 큰 작업이 포함될 수 있습니다.

WaaSMedicSvc는 Windows가 보호/복구하는 구성요소이므로 Standard에서의 비활성화는 best-effort입니다. 재부팅이나 Windows 자체 복구 과정에서 다시 활성화될 수 있습니다.

### Enable은 스냅샷 복원이 아닙니다

`EnableWindowsUpdate`는 Disable 실행 직전의 시스템 상태를 저장해 두었다가 그대로 되돌리는 도구가 아닙니다. Windows Update가 다시 동작할 수 있도록 이 프로젝트가 변경한 가역적인 정책/서비스 설정을 보수적으로 재활성화합니다.

따라서 다음 작업은 의도적으로 하지 않습니다.

- 기존 예약 작업 상태를 추측하여 강제로 활성화
- 삭제된 SoftwareDistribution 캐시 복원
- 사용자가 원래 지정했던 서비스 시작 유형을 추측하여 완전 복원
- Aggressive 모드에서 변경된 보호 ACL/DLL을 불확실한 상태에서 자동 복원

BITS는 Windows Update 외의 Windows 기능 및 응용 프로그램에서도 사용할 수 있습니다. Aggressive 모드에서 BITS를 비활성화하면 Microsoft Store 등을 포함한 다른 다운로드 기능에 영향을 줄 수 있습니다.

---

# ⚠️ DISCLAIMER, WARNING, AND LIMITATION OF LIABILITY

## READ THIS ENTIRE SECTION BEFORE USING THIS SOFTWARE

This project modifies operating-system configuration related to Windows Update and, depending on the selected mode and version of the scripts, may modify Windows services, service startup configuration, registry values, Windows Update policies, scheduled tasks, filesystem permissions, access control lists (ACLs), update-related files or directories, network-related configuration, and other components used by Microsoft Windows servicing and update infrastructure.

These are not cosmetic changes.

They may affect the ability of Windows to download, install, repair, recover, or service operating-system components.

By downloading, copying, modifying, executing, redistributing, or otherwise using any part of this project, you acknowledge that you understand these risks and accept full responsibility for the consequences of doing so.


## NO WARRANTY

THIS SOFTWARE IS PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE AUTHORS, COPYRIGHT HOLDERS, CONTRIBUTORS, MAINTAINERS, AND DISTRIBUTORS OF THIS PROJECT DISCLAIM ALL WARRANTIES, INCLUDING, WITHOUT LIMITATION:

- WARRANTIES OF MERCHANTABILITY;
- WARRANTIES OF FITNESS FOR A PARTICULAR PURPOSE;
- WARRANTIES OF NON-INFRINGEMENT;
- WARRANTIES OF ACCURACY;
- WARRANTIES OF RELIABILITY;
- WARRANTIES OF AVAILABILITY;
- WARRANTIES OF COMPATIBILITY;
- WARRANTIES THAT THE SOFTWARE WILL OPERATE WITHOUT INTERRUPTION;
- WARRANTIES THAT THE SOFTWARE WILL PRODUCE ANY PARTICULAR RESULT;
- WARRANTIES THAT CHANGES MADE BY THE SOFTWARE CAN BE COMPLETELY REVERSED;
- WARRANTIES THAT MICROSOFT WINDOWS WILL CONTINUE TO BEHAVE IN THE SAME WAY AFTER AN UPDATE, SERVICING-STACK CHANGE, POLICY CHANGE, OR OTHER OPERATING-SYSTEM MODIFICATION.

There is no guarantee that this software will work on your computer, on your edition of Windows, on your Windows build, or on any future or past version of Windows.

There is no guarantee that a script which works today will continue to work after Microsoft changes Windows Update, the servicing stack, service permissions, registry behavior, security policies, protected services, scheduled tasks, or any other Windows component.


## THIS PROJECT IS NOT AFFILIATED WITH MICROSOFT

This project is an independent third-party project.

It is not developed, published, sponsored, endorsed, approved, supported, or certified by Microsoft Corporation.

"Microsoft", "Windows", "Windows Update", and other Microsoft product names and trademarks belong to their respective owners.

Nothing in this repository should be interpreted as an official Microsoft procedure, recommendation, workaround, support tool, or configuration.


## DISABLING WINDOWS UPDATE HAS SECURITY CONSEQUENCES

The purpose of this project includes disabling or restricting components of Windows Update.

Doing so may prevent or delay the installation of security updates.

Security updates may contain fixes for vulnerabilities that could otherwise permit:

- remote code execution;
- privilege escalation;
- information disclosure;
- authentication bypass;
- security-feature bypass;
- malware infection;
- ransomware infection;
- credential theft;
- data theft;
- unauthorized system access;
- denial of service;
- compromise of applications or operating-system components.

If Windows Update is disabled, your computer may remain vulnerable to publicly known and actively exploited security vulnerabilities.

The fact that a computer appears to operate normally does not mean that it is secure.

You are solely responsible for determining whether disabling Windows Update is appropriate for your threat model, environment, workload, and security requirements.


## OTHER SOFTWARE MAY BE AFFECTED

Some Windows components used by Windows Update are shared with other operating-system features and applications.

For example, Background Intelligent Transfer Service (BITS) is not exclusively a Windows Update component.

Disabling shared services or modifying related system configuration may interfere with functionality including, but not limited to:

- Microsoft Store;
- application installation;
- application updates;
- driver installation;
- driver updates;
- Microsoft Defender components;
- Windows servicing;
- optional Windows features;
- language packs;
- Microsoft applications;
- third-party applications using Windows services;
- enterprise-management software;
- recovery operations;
- repair operations.

The exact consequences depend on the Windows version, edition, build, configuration, installed software, and subsequent changes made to the system.


## STANDARD MODE DOES NOT MEAN RISK-FREE

Where this project distinguishes between "Standard" and "Aggressive" modes, the term "Standard" is a relative description only.

It does NOT mean:

- safe;
- risk-free;
- officially supported;
- recommended by Microsoft;
- guaranteed to be reversible;
- suitable for production systems;
- suitable for enterprise systems;
- suitable for critical systems.

Standard mode is intended to avoid some of the more invasive techniques available in Aggressive mode.

It still changes operating-system configuration and may cause unintended behavior.


## AGGRESSIVE MODE WARNING

Aggressive mode is intentionally more invasive.

Depending on the version of this project, Aggressive mode may attempt operations involving protected Windows services, ACLs, system files, service configuration, update infrastructure, BITS, or other Windows servicing components.

Such modifications can have consequences beyond merely preventing Windows Update from running.

Possible consequences include, but are not limited to:

- Windows Update malfunction;
- Windows servicing malfunction;
- failed cumulative updates;
- failed feature updates;
- failed security updates;
- Microsoft Store malfunction;
- failed driver installation;
- failed system repair;
- SFC or DISM complications;
- unexpected service behavior;
- incorrect filesystem permissions;
- incorrect registry permissions;
- inability of Windows to restore protected components;
- update loops;
- servicing loops;
- boot-time repair activity;
- operating-system instability;
- loss of functionality;
- the need for manual repair;
- the need for an in-place Windows repair installation;
- the need to restore a backup;
- the need to reinstall Windows.

DO NOT USE AGGRESSIVE MODE UNLESS YOU UNDERSTAND WHAT THE SCRIPT DOES AND ARE PREPARED TO RECOVER THE SYSTEM MANUALLY.


## WINDOWS MAY UNDO THESE CHANGES

Windows contains multiple mechanisms intended to maintain, repair, and service Windows Update and related components.

Windows may restore services, registry values, scheduled tasks, permissions, files, policies, or other configuration modified by this project.

Therefore:

DISABLING AN UPDATE COMPONENT ONCE DOES NOT GUARANTEE THAT IT WILL REMAIN DISABLED.

A future Windows update, servicing-stack update, repair operation, administrative policy, system restore, component repair, or other operating-system action may partially or completely reverse changes made by this project.

Conversely, changes made by this project may also interfere with Microsoft's attempts to restore those components.

No permanent behavior is guaranteed.


## ENABLE IS NOT A COMPLETE SYSTEM RESTORE

The included Enable script is intended to make reasonable, conservative changes that allow Windows Update to operate again.

IT IS NOT A SNAPSHOT-BASED RESTORATION SYSTEM.

The project does not necessarily record every relevant piece of system state before making changes.

Consequently, the Enable script cannot guarantee restoration of the exact configuration that existed before the Disable script was executed.

In particular, it may be impossible to determine automatically:

- the previous startup type of every service;
- whether a scheduled task was previously enabled or disabled;
- whether a registry value existed before execution;
- the exact previous permissions of a protected object;
- whether another program modified the same setting;
- whether Windows itself modified the setting after execution;
- whether a system file changed as a result of servicing;
- whether another update-management tool was installed;
- whether Group Policy controls the same setting.

For this reason, the Enable script deliberately avoids attempting certain speculative restorations.

A restoration that merely guesses the previous state can be more dangerous than leaving an uncertain setting unchanged.


## AGGRESSIVE CHANGES MAY REQUIRE MANUAL RECOVERY

Changes performed by Aggressive mode may not be automatically reversible by the Enable script.

If Aggressive mode modifies a protected Windows component, ACL, system file, service permission, or other protected resource, manual recovery may be required.

The fact that this repository contains an Enable script MUST NOT be interpreted as a guarantee that every action performed by Disable or Aggressive mode has an automatic inverse operation.


## NO GUARANTEE OF IDEMPOTENCE

Repeatedly executing these scripts is not guaranteed to produce exactly the same state as executing them once.

System state can change between executions.

Windows itself, another administrator, another script, security software, Group Policy, servicing operations, scheduled tasks, or third-party applications may modify the same resources.

Do not assume that repeated execution is harmless merely because a previous execution succeeded.


## BACK UP YOUR SYSTEM

Before using this software, you should maintain an appropriate recovery strategy.

Depending on the importance of the computer and its data, this may include:

- backups of important files;
- a tested system-image backup;
- Windows installation or recovery media;
- BitLocker recovery information, where applicable;
- copies of important configuration;
- knowledge of how to enter Windows Recovery Environment;
- knowledge of how to perform an in-place repair installation;
- access to another computer if recovery media must be created.

A backup that has never been tested should not automatically be assumed to be recoverable.


## DO NOT USE ON CRITICAL SYSTEMS WITHOUT INDEPENDENT VALIDATION

This project should not be blindly deployed to systems where failure could cause significant harm.

Examples include:

- production servers;
- business-critical workstations;
- medical systems;
- industrial-control systems;
- infrastructure systems;
- point-of-sale systems;
- unattended remote systems;
- systems containing irreplaceable data;
- systems for which downtime would create substantial financial loss;
- systems subject to regulatory or organizational patch-management requirements.

If you choose to use this software in such an environment, independent testing, validation, change management, recovery planning, and security review are your responsibility.


## ENTERPRISE AND MANAGED ENVIRONMENTS

This project is not a substitute for proper enterprise update management.

Computers managed through technologies such as Group Policy, MDM, Microsoft Intune, Windows Update for Business, WSUS, domain policies, endpoint-management platforms, or organizational security policies may behave differently.

Organizational policy may also override changes made by these scripts.

Do not use this project to circumvent organizational controls on a computer that you are not authorized to administer.


## ADMINISTRATOR PRIVILEGES ARE POWERFUL

These scripts may request or require Administrator privileges.

Administrator privileges allow software to make system-wide changes.

The presence of a UAC elevation prompt does not mean that an operation is safe.

It means that the requested operation has sufficient privilege to potentially make significant changes to the operating system.

Review the source code before granting administrative privileges.


## REVIEW THE SOURCE CODE

This project is distributed as source code so that its behavior can be inspected.

You are strongly encouraged to read the scripts before executing them.

Do not execute a script merely because:

- it was downloaded from GitHub;
- another person recommended it;
- it has stars;
- it worked on another computer;
- antivirus software did not detect it;
- a previous version worked;
- the README says that it should work.

Source availability enables review; it does not replace review.


## FORKS, MODIFICATIONS, AND THIRD-PARTY DISTRIBUTIONS

The maintainers of this repository cannot control modified copies, forks, mirrors, reposts, archives, unofficial releases, or third-party distributions of this software.

If you obtained these scripts from somewhere other than the repository you intended to trust, verify their contents before execution.

A modified version may behave differently from the version described by this documentation.


## ANTIVIRUS AND SECURITY SOFTWARE

Scripts that modify Windows services, system configuration, update mechanisms, permissions, or protected resources may be detected or blocked by antivirus, endpoint-security, application-control, or EDR software.

A detection does not automatically prove that the software is malicious.

Likewise, the absence of a detection does not prove that the software is safe.

You are responsible for evaluating security-software alerts in the context of your environment.


## WINDOWS VERSION AND BUILD DIFFERENCES

Windows behavior differs between:

- Windows editions;
- Windows 10 releases;
- Windows 11 releases;
- servicing-stack versions;
- cumulative-update levels;
- consumer and enterprise configurations;
- managed and unmanaged devices;
- localized versions of Windows.

A registry key, service, scheduled task, file, permission, or behavior present on one system may be absent or different on another.

The scripts may therefore skip operations, produce warnings, fail partially, or behave differently across systems.


## PARTIAL SUCCESS IS POSSIBLE

These scripts perform multiple independent operations.

One operation succeeding does not imply that all operations succeeded.

Likewise, one operation failing does not necessarily mean that no changes were made.

If execution is interrupted, terminated, blocked, or fails partway through, the computer may be left in a partially modified state.

READ THE OUTPUT AND LOG FILES.

Do not assume that an error at the end of execution means that earlier operations were automatically rolled back.

This project does not provide transactional rollback of Windows system configuration.


## LOGS ARE DIAGNOSTIC, NOT PROOF OF SYSTEM STATE

Where the software creates log files, those logs describe operations attempted or observed by the script.

They do not constitute a complete audit of Windows.

A successful log entry does not guarantee that Windows will preserve that state after the script exits.

A failed log entry does not necessarily mean that Windows is unusable.

The actual system state is authoritative.


## NO SECURITY GUARANTEE

This software is not a security product.

Disabling Windows Update should not be treated as a security hardening technique.

Although reducing automatic system changes may be desirable in some specialized environments, preventing security patches from being installed can substantially increase security risk.

The maintainers make no claim that using this project makes a computer more secure.


## NO PRIVACY GUARANTEE

This project is not a comprehensive Windows privacy tool.

Disabling Windows Update does not necessarily disable telemetry, network communication, Microsoft services, diagnostics, cloud features, application updates, or other operating-system communication.

Do not infer privacy guarantees from update-related behavior.


## USE AT YOUR OWN RISK

Ultimately, you control the computer on which you execute this software.

You decide whether the benefits of modifying Windows Update behavior outweigh the risks.

BY USING THIS SOFTWARE, YOU ACCEPT RESPONSIBILITY FOR:

- the decision to execute it;
- the mode you select;
- the configuration of the computer;
- any resulting security exposure;
- any resulting loss of functionality;
- troubleshooting;
- recovery;
- backups;
- restoration;
- data loss;
- downtime;
- compatibility problems;
- software problems;
- update problems;
- servicing problems;
- any other direct or indirect consequence of its use.


## LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL THE AUTHORS, COPYRIGHT HOLDERS, CONTRIBUTORS, MAINTAINERS, OR DISTRIBUTORS OF THIS PROJECT BE LIABLE FOR ANY CLAIM, DAMAGES, LOSS, COST, OR OTHER LIABILITY ARISING FROM, OUT OF, OR IN CONNECTION WITH THIS SOFTWARE OR ITS USE.

THIS INCLUDES, WITHOUT LIMITATION:

- DIRECT DAMAGES;
- INDIRECT DAMAGES;
- INCIDENTAL DAMAGES;
- SPECIAL DAMAGES;
- EXEMPLARY DAMAGES;
- CONSEQUENTIAL DAMAGES;
- LOSS OF DATA;
- LOSS OF PROFITS;
- LOSS OF REVENUE;
- LOSS OF BUSINESS;
- LOSS OF PRODUCTIVITY;
- LOSS OF USE;
- LOSS OF AVAILABILITY;
- SYSTEM DOWNTIME;
- SECURITY INCIDENTS;
- MALWARE INFECTIONS;
- RANSOMWARE INFECTIONS;
- FAILED UPDATES;
- FAILED RECOVERY;
- OPERATING-SYSTEM CORRUPTION;
- APPLICATION FAILURE;
- HARDWARE OR DRIVER COMPATIBILITY PROBLEMS;
- COSTS OF REPAIR;
- COSTS OF RECOVERY;
- COSTS OF REINSTALLATION;
- COSTS OF PROFESSIONAL SUPPORT.

THIS LIMITATION APPLIES WHETHER THE ALLEGED LIABILITY ARISES IN CONTRACT, TORT, NEGLIGENCE, STRICT LIABILITY, WARRANTY, STATUTE, OR ANY OTHER THEORY OF LIABILITY, EVEN IF THE POSSIBILITY OF SUCH DAMAGE WAS KNOWN OR COULD HAVE BEEN FORESEEN.


## YOU ARE THE SYSTEM ADMINISTRATOR

This project gives you tools.

It does not make decisions for you.

If you execute these scripts with administrative privileges, you are acting as the administrator of that system and accepting the consequences of the configuration changes you authorize.

If you do not understand a command, do not execute it until you understand what it does.


## FINAL WARNING

If you need a computer that "just works" with Microsoft's supported Windows Update configuration, do not use this project.

If you require guaranteed reversibility, do not use this project.

If you cannot tolerate downtime, do not use this project without a tested recovery plan.

If you cannot reinstall or repair Windows if necessary, do not use Aggressive mode.

If losing access to the computer would cause serious harm, test this software somewhere else first.

And if you choose to use it anyway:

**BACK UP YOUR DATA.**

**READ THE SOURCE.**

**START WITH STANDARD MODE.**

**KEEP RECOVERY MEDIA AVAILABLE.**

**UNDERSTAND THAT ENABLE IS NOT A TIME MACHINE.**

**ASSUME THAT WINDOWS MAY CHANGE ITS BEHAVIOR AT ANY TIME.**

**USE AT YOUR OWN RISK.**
