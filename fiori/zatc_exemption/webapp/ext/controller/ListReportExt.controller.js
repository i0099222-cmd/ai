sap.ui.define(["sap/ui/core/mvc/ControllerExtension"], function (ControllerExtension) {
	"use strict";

	// 상태를 바꾸는 액션. 끝나면 목록을 다시 읽는다.
	// FE 는 액션이 돌려준 행($self)만 바꿔 끼우고 탭 필터를 다시 적용하지 않는다.
	// 그래서 Submit 후에도 Draft 탭에 상태만 Pending 인 행이 남는다.
	// simulateImpact 는 데이터를 바꾸지 않으므로 넣지 않는다.
	var REFRESH_ACTIONS = /\.(submit|withdraw|approve|reject|extendValidity)(\(|$)/;

	return ControllerExtension.extend("zatcexemption.ext.controller.ListReportExt", {
		override: {
			editFlow: {
				// UI5 1.114 이상. actionName 은 "<네임스페이스>.submit" 형태다.
				onAfterActionExecution: function (actionName) {
					if (!REFRESH_ACTIONS.test(actionName)) {
						return;
					}
					var oExtensionAPI = this.base.getExtensionAPI();
					// 다중 뷰(탭): 지금 탭은 바로, 나머지 탭은 열 때 다시 읽고 건수도 갱신한다.
					// 이 메소드가 없는 버전이면 Go 버튼을 누른 것과 같은 refresh 로 대신한다.
					if (oExtensionAPI.setTabContentToBeRefreshedOnNextOpening) {
						oExtensionAPI.setTabContentToBeRefreshedOnNextOpening();
						oExtensionAPI.refreshTabsCount();
					} else {
						oExtensionAPI.refresh();
					}
				}
			}
		}
	});
});
