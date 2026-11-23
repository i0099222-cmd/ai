/*
  리스트 리포트(MainList) 컨트롤러 확장
  - 통합 조회 탭에서 행을 누르면 통합 조회 전용 상세(DevObjectObjectPage) 대신, 그 행의 원래 탭 상세 화면으로 보낸다
      To-Be·As-Is → 매핑 상세 / VH → Value Help 상세 / SB → OData 서비스 상세 / TD → 기술부채 상세
  - 다른 탭(요청·매핑 …)의 행은 원래대로
  - 위치: webapp/ext/controller/MainListExt.controller.js
    manifest: sap.ui5.extends.extensions.sap.ui.controllerExtensions 에 등록 (09_app/manifest.routing.sample.json)
*/
sap.ui.define(["sap/ui/core/mvc/ControllerExtension"], function (ControllerExtension) {
	"use strict";

	// 등록 구분 → 이동할 상세 화면(route 이름)과 그 엔터티의 키 필드
	//   등록 구분 값은 TOBE/ASIS(이 저장소) 또는 TB/AI(시스템에서 바꾼 이름) 둘 다 받는다
	var mTarget = {
		TOBE: { route: "MappingObjectPage", key: "MapUuid" },
		ASIS: { route: "MappingObjectPage", key: "MapUuid" },
		TB:   { route: "MappingObjectPage", key: "MapUuid" },
		AI:   { route: "MappingObjectPage", key: "MapUuid" },
		VH:   { route: "ValueHelpObjectPage", key: "VhUuid" },
		SB:   { route: "ODataServiceObjectPage", key: "SbUuid" },
		TD:   { route: "TechDebtObjectPage", key: "DebtUuid" }
	};

	return ControllerExtension.extend("<앱 ID>.ext.controller.MainListExt", {
		override: {
			routing: {
				// 행을 눌러 상세로 갈 때마다 불린다. true 를 돌려주면 기본 이동을 막는다
				onBeforeNavigation: function (oNavigationInfo) {
					var oContext = oNavigationInfo && oNavigationInfo.bindingContext;
					if (!oContext || oContext.getPath().indexOf("/DevObject") !== 0) {
						return false;                       // 통합 조회 행이 아니면 원래대로
					}
					var sTab = oContext.getProperty("RefTab") || oContext.getProperty("SourceTab");
					var oTarget = mTarget[sTab];
					if (!oTarget) {
						return false;                       // 모르는 구분이면 통합 조회 상세로
					}
					// 원래 탭 상세: 활성(저장된) 버전으로 연다. 키 = <키 필드>=<GUID>,IsActiveEntity=true
					this.base.getExtensionAPI().routing.navigateToRoute(oTarget.route, {
						key: oTarget.key + "=" + oContext.getProperty("SourceUuid") + ",IsActiveEntity=true"
					});
					return true;
				}
			}
		}
	});
});
