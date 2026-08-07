/*
 * 템플릿 다운로드 (UI5 + TypeScript)
 *
 * 백엔드가 템플릿을 HTTP 서비스(ZCL_EXCEL_TEMPLATE_HTTP)로 노출하므로
 * 평범한 GET URL이다. 링크만 걸면 브라우저가 알아서 받는다.
 * 액션 호출도, CSRF 토큰도, base64 변환도 필요 없다.
 *
 * XML view에 버튼 연결:
 *   <Button text="템플릿 다운로드" press=".onDownloadTemplate" />
 */
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";

/** ADT의 HTTP Service 화면에 표시되는 URL로 바꿀 것. */
const TEMPLATE_URL = "/sap/bc/http/sap/z_excel_template";

const TEMPLATE_FILENAME = "Template.xlsx";

export function onDownloadTemplate(this: ExtensionAPI): void {
    const oLink: HTMLAnchorElement = document.createElement("a");

    oLink.href = TEMPLATE_URL;
    oLink.download = TEMPLATE_FILENAME;

    document.body.appendChild(oLink);
    oLink.click();
    document.body.removeChild(oLink);
}
