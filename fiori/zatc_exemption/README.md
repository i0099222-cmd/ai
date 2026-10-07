# ATC Exemption Management - Fiori 앱 확장

BAS 에서 생성한 Fiori Elements V4 앱(List Report, 메인 = Exemption)에 넣는 파일만 둔다.
앱 전체는 BAS 프로젝트에 있다.

## 액션 후 목록 새로고침

Submit / Withdraw / Approve / Reject / Extend Validity 뒤에 목록을 다시 읽는다.

FE 는 bound 액션이 돌려준 행의 키가 원래 행과 같으면 그 행만 바꿔 끼우고 목록은 다시 읽지
않는다(`EditFlow._refreshListIfRequired`). 우리 액션은 모두 `result [1] $self` 라 키가 같다.
그래서 상태별 탭에서 Submit 해도 Draft 탭에 행이 남고 상태만 바뀐다.

### 넣는 법

1. `webapp/ext/controller/ListReportExt.controller.ts` 를 앱의 같은 경로에 복사한다.
2. 파일 안의 `@namespace zatcexemption.ext.controller` 의 `zatcexemption` 을 앱 ID(manifest 의 `sap.app.id`)로 바꾼다.
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

- 앱이 TypeScript 프로젝트(BAS 에서 TypeScript 로 생성)여야 한다. 빌드가 `.ts` 를
  `.js` 로 변환하므로 manifest 의 `controllerName` 은 그대로다.

### 버전

- `onAfterActionExecution` 훅은 UI5 1.114 부터 있다. 시스템 UI5 버전은 런치패드에서
  사용자 메뉴 > About, 또는 브라우저 콘솔에서 `sap.ui.version` 으로 본다.
- 1.114 보다 낮으면 훅이 불리지 않는다. 오류는 나지 않고 지금처럼 새로고침만 안 된다.
- Object Page 에서 누른 액션은 이 확장과 무관하다. 목록으로 돌아오면 FE 가 다시 읽는다.

## 목록의 상태별 탭

DDLX(`ZP_AtcExemption`)에 탭 4개가 `SelectionPresentationVariant` 로 정의돼 있다
(`#Draft` / `#Pending` / `#Approved` / `#Rejected`). manifest 가 이 한정자를 참조해야 탭이 생긴다.
List Report 의 `options.settings` 에 넣는다.

```json
"views": {
  "paths": [
    { "key": "draft",    "annotationPath": "com.sap.vocabularies.UI.v1.SelectionPresentationVariant#Draft" },
    { "key": "pending",  "annotationPath": "com.sap.vocabularies.UI.v1.SelectionPresentationVariant#Pending" },
    { "key": "approved", "annotationPath": "com.sap.vocabularies.UI.v1.SelectionPresentationVariant#Approved" },
    { "key": "rejected", "annotationPath": "com.sap.vocabularies.UI.v1.SelectionPresentationVariant#Rejected" }
  ],
  "showCounts": true
}
```

## 액션 버튼 묶기 (신청자 / 승인자)

DDLX 에 낱개로 정의된 액션을 manifest 에서 메뉴 버튼 두 개로 묶는다. `<ns>` 는 서비스
네임스페이스다(`$metadata` 의 `Schema Namespace`, 예 `com.sap.gateway.srvd.zui_atcexemption.v0001`).

목록 - List Report `options.settings`:

```json
"controlConfiguration": {
  "@com.sap.vocabularies.UI.v1.LineItem": {
    "actions": {
      "RequesterMenu": { "text": "Requester",
        "menu": [ "DataFieldForAction::<ns>.submit", "DataFieldForAction::<ns>.withdraw" ] },
      "ApproverMenu":  { "text": "Approver",
        "menu": [ "DataFieldForAction::<ns>.approve", "DataFieldForAction::<ns>.reject" ] }
    }
  }
}
```

요청서 헤더 - Object Page `options.settings`:

```json
"content": {
  "header": {
    "actions": {
      "RequesterMenu": { "text": "Requester",
        "menu": [ "DataFieldForAction::<ns>.submit", "DataFieldForAction::<ns>.withdraw",
                  "DataFieldForAction::<ns>.extendValidity" ] },
      "ApproverMenu":  { "text": "Approver",
        "menu": [ "DataFieldForAction::<ns>.approve", "DataFieldForAction::<ns>.reject",
                  "DataFieldForAction::<ns>.simulateImpact" ] }
    }
  }
}
```

메뉴 안의 항목은 instance features 대로 활성/비활성된다. 메뉴 버튼 자체는 늘 보인다.

## 요청서 화면 (Object Page)

요청서 한 건에 대상을 여러 줄 넣는다. 별도 확장 없이 FE 기본 기능으로 동작한다.

- 위: Title / Check Variant / Check Class, 사유와 유효기간
- 아래 **Targets** 표: 초안에서 줄을 추가하고 칸에 바로 입력한다. 한 줄 = 표준 예외 1건.
  - Package 만 넣으면 패키지 대상, Object Name 까지 넣으면 오브젝트 대상(Check Message Code 필수)
  - Object Name 값 도움: 위반이 있는 오브젝트. 고르면 Object Type / Package / Check Message Code 가 같이 채워진다
  - Package 값 도움: 위반이 있는 패키지. 두 번째 목록(All Customer Packages)에서 위반 없는 패키지도 고를 수 있다
  - 값 도움은 요청서의 Check Class 로 걸러진다. Check Class 를 먼저 넣는다

## 예전 Pre-Register 버튼 / 위반 조회 앱 제거

요청서 구조로 바뀌면서 둘 다 없어졌다. 대상 여러 개는 Targets 표에 넣고, 위반은 값 도움에서 고른다.

- `manifest.json` 에 넣었던 `controlConfiguration` 의 `preRegister` 액션을 지운다(남아 있으면 버튼이
  없는 메소드를 불러 오류가 난다).
- 위반 조회 앱(메인 = Finding)과 그 타일은 지운다. 서비스에 `Finding` / `FindingPackage` 가 더 이상 없다.
