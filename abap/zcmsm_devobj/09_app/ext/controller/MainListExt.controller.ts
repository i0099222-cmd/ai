import ControllerExtension from "sap/ui/core/mvc/ControllerExtension";
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";
import Context from "sap/ui/model/odata/v4/Context";

/*
  리스트 리포트(MainList) 컨트롤러 확장
  - 통합 조회 탭에서 행을 누르면 통합 조회 전용 상세(DevObjectObjectPage) 대신, 그 행의 원래 탭 상세 화면으로 보낸다
      To-Be·As-Is → 매핑 상세 / VH → Value Help 상세 / SB → OData 서비스 상세 / TD → 기술부채 상세
  - 다른 탭(요청·매핑 …)의 행은 원래대로
  - 위치: webapp/ext/controller/MainListExt.controller.ts
    manifest: sap.ui5.extends.extensions.sap.ui.controllerExtensions 에 등록 (09_app/manifest.routing.sample.json)
*/

type NavTarget = { route: string; key: string };

// 등록 구분 → 이동할 상세 화면(route 이름 = manifest routing.routes 의 name)과 그 엔터티의 키 필드
//   등록 구분 값은 TOBE/ASIS(이 저장소) 또는 TB/AI(시스템에서 바꾼 이름) 둘 다 받는다
const NAV_TARGETS: Record<string, NavTarget> = {
	TOBE: { route: "MappingObjectPage", key: "MapUuid" },
	ASIS: { route: "MappingObjectPage", key: "MapUuid" },
	TB: { route: "MappingObjectPage", key: "MapUuid" },
	AI: { route: "MappingObjectPage", key: "MapUuid" },
	VH: { route: "ValueHelpObjectPage", key: "VhUuid" },
	SB: { route: "ODataServiceObjectPage", key: "SbUuid" },
	TD: { route: "TechDebtObjectPage", key: "DebtUuid" }
};

/**
 * @namespace <앱 ID>.ext.controller
 * @controller
 */
export default class MainListExt extends ControllerExtension<ExtensionAPI> {
	static overrides = {
		routing: {
			/**
			 * 행을 눌러 상세로 갈 때마다 불린다. true 를 돌려주면 기본 이동을 막는다
			 */
			onBeforeNavigation(this: MainListExt, navigationInfo?: { bindingContext?: Context }): boolean {
				const context = navigationInfo?.bindingContext;
				if (!context || !context.getPath().startsWith("/DevObject")) {
					return false; // 통합 조회 행이 아니면 원래대로
				}

				const tab = (context.getProperty("RefTab") ?? context.getProperty("SourceTab")) as string | undefined;
				const target = tab ? NAV_TARGETS[tab] : undefined;
				if (!target) {
					return false; // 모르는 구분이면 통합 조회 상세로
				}

				// 원래 탭 상세: 활성(저장된) 버전으로 연다. 키 = <키 필드>=<GUID>,IsActiveEntity=true
				const uuid = context.getProperty("SourceUuid") as string;
				void this.base.getExtensionAPI().routing.navigateToRoute(target.route, {
					key: `${target.key}=${uuid},IsActiveEntity=true`
				});
				return true;
			}
		}
	};
}
