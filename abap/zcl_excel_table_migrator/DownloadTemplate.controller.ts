/*
 * 템플릿 다운로드 (UI5 + TypeScript)
 *
 * RAP static action(downloadTemplate)을 호출해서 받은 xlsx를 다운로드시킨다.
 * 액션은 POST라 <a href>로 바로 받을 수 없어서, 호출 -> 응답에서 내용 꺼내기
 * -> Blob으로 감싸기까지 하고 마지막에 <a download>로 넘긴다.
 *
 * 엔티티에 attachment(스트림) 필드를 만들 필요는 없다.
 *
 * XML view에 버튼 연결:
 *   <Button text="템플릿 다운로드" press=".onDownloadTemplate" />
 */
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";

/** 서비스 루트 URL. 실제 서비스 바인딩 경로로 바꿀 것. */
const SERVICE_URL = "/sap/opu/odata4/sap/z_excel_upload/srvd/sap/z_excel_upload/0001";

/**
 * static action은 엔티티 컬렉션에 바인딩된 액션으로 노출된다.
 * 네임스페이스는 서비스마다 다르므로 $metadata에서 downloadTemplate의
 * 정규화된 이름을 확인해 실제 값으로 바꿀 것.
 */
const ACTION_PATH = "/ExcelUpload/com.sap.gateway.srvd.z_excel_upload.v0001.downloadTemplate";

/** downloadTemplate 액션이 돌려주는 구조 (ZI_TemplateFile) */
interface TemplateFile {
    FileName: string;
    MimeType: string;
    /** xstring은 JSON 응답에서 base64 문자열로 넘어온다 */
    FileContent: string;
}

export async function onDownloadTemplate(this: ExtensionAPI): Promise<void> {
    const sToken = await fetchCsrfToken();

    const oResponse = await fetch(SERVICE_URL + ACTION_PATH, {
        method: "POST",
        headers: {
            "X-CSRF-Token": sToken,
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        body: "{}"
    });

    if (!oResponse.ok) {
        throw new Error(`템플릿 다운로드 실패 (HTTP ${oResponse.status})`);
    }

    // 액션 결과는 응답 본문에 그대로 오거나 value로 한 겹 감싸여 온다.
    const oBody = await oResponse.json() as TemplateFile & { value?: TemplateFile };
    const oFile = oBody.value ?? oBody;

    saveFile(oFile);
}

/** SAP 게이트웨이는 POST에 CSRF 토큰을 요구한다. */
async function fetchCsrfToken(): Promise<string> {
    const oResponse = await fetch(SERVICE_URL + "/", {
        method: "HEAD",
        headers: { "X-CSRF-Token": "Fetch" }
    });

    return oResponse.headers.get("X-CSRF-Token") ?? "";
}

/** base64 -> 바이트 배열 -> Blob -> 다운로드 트리거 */
function saveFile(oFile: TemplateFile): void {
    const aBytes = Uint8Array.from(
        atob(oFile.FileContent),
        (sChar: string): number => sChar.charCodeAt(0)
    );

    const oBlob = new Blob([aBytes], { type: oFile.MimeType });
    const sObjectUrl = URL.createObjectURL(oBlob);

    const oLink: HTMLAnchorElement = document.createElement("a");
    oLink.href = sObjectUrl;
    oLink.download = oFile.FileName;

    document.body.appendChild(oLink);
    oLink.click();
    document.body.removeChild(oLink);

    URL.revokeObjectURL(sObjectUrl);
}
