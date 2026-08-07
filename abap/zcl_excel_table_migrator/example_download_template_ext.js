/*
 * 템플릿 다운로드용 Fiori Elements 컨트롤러 확장 (OData V4 기준)
 *
 * RAP 액션이 파일 내용을 돌려줘도 Fiori Elements가 알아서 저장해주진 않는다.
 * 응답에서 내용을 꺼내 Blob으로 만들고 브라우저 다운로드를 띄우는 건 프론트 몫이라
 * 이 확장이 필요하다.
 *
 * 붙이는 순서:
 *   1) 이 파일을 앱의 webapp/ext/controller/ 아래에 둔다.
 *   2) manifest.json의 sap.ui5 > extends > extensions에 controllerExtension으로 등록.
 *   3) 같은 manifest에서 List Report 툴바에 커스텀 액션 버튼을 추가하고,
 *      press 핸들러를 아래 onDownloadTemplate에 연결한다.
 *
 *   "sap.ui5": {
 *     "extends": {
 *       "extensions": {
 *         "sap.ui.controllerExtensions": {
 *           "sap.fe.templates.ListReport.ListReportController": {
 *             "controllerName": "your.app.ext.controller.ListReportExt"
 *           }
 *         }
 *       }
 *     },
 *     "routing": {
 *       "targets": {
 *         "ExcelUploadList": {
 *           "options": {
 *             "settings": {
 *               "controlConfiguration": {
 *                 "@com.sap.vocabularies.UI.v1.LineItem": {
 *                   "actions": {
 *                     "downloadTemplate": {
 *                       "press": "your.app.ext.controller.ListReportExt.onDownloadTemplate",
 *                       "visible": true,
 *                       "text": "템플릿 다운로드"
 *                     }
 *                   }
 *                 }
 *               }
 *             }
 *           }
 *         }
 *       }
 *     }
 *   }
 */
sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/m/MessageBox"
], function (ControllerExtension, MessageBox) {
    "use strict";

    return ControllerExtension.extend("your.app.ext.controller.ListReportExt", {

        onDownloadTemplate: async function () {
            const oModel = this.base.getView().getModel();

            // RAP의 static action은 OData V4에서 엔티티 "컬렉션"에 바인딩된 액션으로 노출된다.
            // 경로의 네임스페이스는 서비스마다 다르므로 실제 값으로 바꿔야 한다.
            // /IWFND/GW_CLIENT 나 브라우저 네트워크 탭에서 $metadata를 열어
            // downloadTemplate의 정규화된 이름을 확인할 것.
            const sActionPath =
                "/ExcelUpload/com.sap.gateway.srvd.z_excel_upload.v0001.downloadTemplate(...)";

            const oAction = oModel.bindContext(sActionPath);

            try {
                await oAction.execute();

                const oResult = oAction.getBoundContext().getObject();
                this._saveFile(oResult.FileContent, oResult.FileName, oResult.MimeType);

            } catch (oError) {
                MessageBox.error(oError.message || "템플릿 다운로드에 실패했습니다.");
            }
        },

        /*
         * xstring은 JSON 응답에서 base64 문자열로 넘어온다.
         * 바이트 배열로 되돌린 뒤 Blob으로 감싸 다운로드를 트리거한다.
         */
        _saveFile: function (sBase64Content, sFileName, sMimeType) {
            const aBytes = Uint8Array.from(
                atob(sBase64Content),
                (sChar) => sChar.charCodeAt(0)
            );

            const oBlob = new Blob([aBytes], { type: sMimeType });
            const sObjectUrl = URL.createObjectURL(oBlob);

            const oLink = document.createElement("a");
            oLink.href = sObjectUrl;
            oLink.download = sFileName;
            oLink.click();

            URL.revokeObjectURL(sObjectUrl);
        }
    });
});
