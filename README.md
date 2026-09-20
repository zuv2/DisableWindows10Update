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
