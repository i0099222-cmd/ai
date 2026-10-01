# ATC Exemption Management - Fiori 앱 확장

BAS 에서 생성한 Fiori Elements V4 앱(List Report, 메인 = Exemption)에 넣는 파일만 둔다.
앱 전체는 BAS 프로젝트에 있다.

## 액션 후 목록 새로고침

Submit / Withdraw / Approve / Reject / Extend Validity 뒤에 목록을 다시 읽는다.

FE 는 bound 액션이 돌려준 행의 키가 원래 행과 같으면 그 행만 바꿔 끼우고 목록은 다시 읽지
않는다(`EditFlow._refreshListIfRequired`). 우리 액션은 모두 `result [1] $self` 라 키가 같다.
그래서 상태별 탭에서 Submit 해도 Draft 탭에 행이 남고 상태만 바뀐다.

### 넣는 법

1. `webapp/ext/controller/ListReportExt.controller.js` 를 앱의 같은 경로에 복사한다.
2. 파일 안의 `zatcexemption` 을 앱 ID(manifest 의 `sap.app.id`)로 바꾼다.
3. `manifest.json` 의 `sap.ui5` 아래에 추가한다.

```json
"extends": {
  "extensions": {
    "sap.ui.controllerExtensions": {
      "sap.fe.templates.ListReport.ListReportController": {
        "controllerName": "zatcexemption.ext.controller.ListReportExt"
      }
    }
  }
}
```

### 버전

- `onAfterActionExecution` 훅은 UI5 1.114 부터 있다. 시스템 UI5 버전은 런치패드에서
  사용자 메뉴 > About, 또는 브라우저 콘솔에서 `sap.ui.version` 으로 본다.
- 1.114 보다 낮으면 훅이 불리지 않는다. 오류는 나지 않고 지금처럼 새로고침만 안 된다.
- Object Page 에서 누른 액션은 이 확장과 무관하다. 목록으로 돌아오면 FE 가 다시 읽는다.
