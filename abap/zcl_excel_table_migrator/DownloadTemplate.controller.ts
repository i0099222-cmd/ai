/*
 * 템플릿 다운로드 (UI5 + TypeScript)
 *
 * RAP static action(downloadTemplate)을 호출해서 받은 xlsx를 다운로드시킨다.
 * 액션은 POST라 <a href>로 바로 받을 수 없어서, 호출 -> 응답에서 내용 꺼내기
 * -> Blob으로 감싸기까지 하고 마지막에 <a download>로 넘긴다.
 *
 * XML view에 버튼 연결:
 *   <Button text="템플릿 다운로드" press=".onDownloadTemplate" />
 */
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";
import MessageBox from "sap/m/MessageBox";

/*
 * ★ 아래 두 상수는 예시 값이다. 실제 값으로 바꾸지 않으면 요청이 404로 튕기고
 *   ABAP 브레이크포인트에도 걸리지 않는다.
 *
 *   SERVICE_URL : 앱에서 아무 OData 요청이나 하나 잡아 Network 탭에서 확인.
 *                 (또는 manifest.json > sap.app > dataSources > mainService > uri)
 *   ACTION_PATH : <SERVICE_URL>/$metadata 를 열어 downloadTemplate 을 검색.
 *                 "/<EntitySet이름>/<Schema Namespace>.downloadTemplate" 형태로 조합.
 */
const SERVICE_URL = "/sap/opu/odata4/sap/z_excel_upload/srvd/sap/z_excel_upload/0001";
const ACTION_PATH = "/ExcelUpload/com.sap.gateway.srvd.z_excel_upload.v0001.downloadTemplate";

/** downloadTemplate 액션이 돌려주는 구조 (ZI_TemplateFile) */
interface TemplateFile {
    FileName: string;
    MimeType: string;
    /** xstring은 JSON 응답에서 base64 문자열로 넘어온다 */
    FileContent: string;
}

export async function onDownloadTemplate(this: ExtensionAPI): Promise<void> {
    // 실패를 조용히 넘기면 "버튼을 눌러도 아무 일도 안 일어나는" 상태가 된다.
    // 어디서 끊겼는지 보이도록 전부 잡아서 띄운다.
    try {
        const sUrl = SERVICE_URL + ACTION_PATH;
        console.log("[DownloadTemplate] POST", sUrl);

        const sToken = await fetchCsrfToken();
        if (!sToken) {
            throw new Error(`CSRF 토큰을 받지 못했습니다. SERVICE_URL이 맞는지 확인하세요: ${SERVICE_URL}`);
        }

        const oResponse = await fetch(sUrl, {
            method: "POST",
            headers: {
                "X-CSRF-Token": sToken,
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            body: "{}"
        });

        console.log("[DownloadTemplate] status", oResponse.status);

        if (!oResponse.ok) {
            // 404면 ACTION_PATH가 틀린 것, 405면 액션이 아닌 경로를 부른 것.
            const sBody = await oResponse.text();
            throw new Error(`HTTP ${oResponse.status} - ${sUrl}\n${sBody.slice(0, 500)}`);
        }

        // 액션 결과는 응답 본문에 그대로 오거나 value로 한 겹 감싸여 온다.
        const oBody = await oResponse.json() as TemplateFile & { value?: TemplateFile };
        const oFile = oBody.value ?? oBody;

        if (!oFile?.FileContent) {
            throw new Error(`응답에 FileContent가 없습니다: ${JSON.stringify(oBody).slice(0, 500)}`);
        }

        saveFile(oFile);

    } catch (oError: unknown) {
        const sMessage = oError instanceof Error ? oError.message : String(oError);
        console.error("[DownloadTemplate]", oError);
        MessageBox.error(sMessage);
    }
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
