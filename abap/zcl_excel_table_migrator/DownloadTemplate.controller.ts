/*
 * 템플릿 다운로드 (UI5 + TypeScript)
 *
 * 백엔드가 템플릿을 스트림(첨부) 엔드포인트로 노출하고 있다는 전제.
 * 그 URL을 <a download>로 바로 걸어주면 브라우저가 알아서 받아온다.
 * 액션 호출 -> base64 -> Blob 변환이 필요 없다.
 *
 * XML view에 버튼 연결:
 *   <Button text="템플릿 다운로드" press=".onDownloadTemplate" />
 */
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";

/**
 * 템플릿 스트림 URL.
 * 서비스 바인딩 이름과 엔티티/필드 경로에 맞춰 실제 값으로 바꿀 것.
 */
const TEMPLATE_URL = "/sap/opu/odata4/sap/zcm.........../attachment";

const TEMPLATE_FILENAME = "Template.xlsx";

export function onDownloadTemplate(this: ExtensionAPI): void {
    const oLink: HTMLAnchorElement = document.createElement("a");

    oLink.href = TEMPLATE_URL;
    oLink.download = TEMPLATE_FILENAME;

    document.body.appendChild(oLink);
    oLink.click();
    document.body.removeChild(oLink);
}
