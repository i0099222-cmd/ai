/*
 * 템플릿 다운로드 컨트롤러 (UI5 + TypeScript, OData V4 기준)
 *
 * RAP 액션이 파일 내용을 돌려줘도 화면에서는 아무 일도 일어나지 않는다.
 * 응답에 담겨온 내용을 Blob으로 만들어 브라우저 다운로드를 띄우는 것까지가
 * 프론트 몫이라 이 핸들러가 필요하다.
 *
 * XML view에 버튼 연결:
 *   <Button text="템플릿 다운로드" press=".onDownloadTemplate" />
 */
import Controller from "sap/ui/core/mvc/Controller";
import MessageBox from "sap/m/MessageBox";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";

/** downloadTemplate 액션이 돌려주는 구조 (ZI_TemplateFile) */
interface TemplateFile {
    FileName: string;
    MimeType: string;
    /** xstring은 JSON 응답에서 base64 문자열로 넘어온다 */
    FileContent: string;
}

/**
 * RAP의 static action은 OData V4에서 엔티티 컬렉션에 바인딩된 액션으로 노출된다.
 * 네임스페이스는 서비스마다 다르므로 $metadata에서 downloadTemplate의
 * 정규화된 이름을 확인해 실제 값으로 바꿀 것. 이게 틀리면 여전히 아무 일도 안 일어난다.
 */
const ACTION_PATH =
    "/ExcelUpload/com.sap.gateway.srvd.z_excel_upload.v0001.downloadTemplate(...)";

export default class DownloadTemplate extends Controller {

    // onInit에서 채운다. strictPropertyInitialization 대응으로 definite assignment 사용.
    private oModel!: ODataModel;

    public onInit(): void {
        this.oModel = this.getOwnerComponent()?.getModel() as ODataModel;
    }

    public async onDownloadTemplate(): Promise<void> {
        try {
            const oFile = await this.fetchTemplate();

            if (oFile === undefined) {
                MessageBox.error("템플릿 내용이 비어 있습니다.");
            } else {
                this.saveFile(oFile);
            }

        } catch (oError: unknown) {
            const sMessage = oError instanceof Error
                ? oError.message
                : "템플릿 다운로드에 실패했습니다.";
            MessageBox.error(sMessage);
        }
    }

    /**
     * 액션을 호출해 템플릿 파일을 가져온다.
     * 내용이 없으면 undefined - 반환 타입에 undefined를 포함시켜야
     * 모든 경로가 명시적으로 값을 돌려주게 된다.
     */
    private async fetchTemplate(): Promise<TemplateFile | undefined> {
        const oAction = this.oModel.bindContext(ACTION_PATH);
        await oAction.execute();

        const oResult = oAction.getBoundContext()?.getObject() as TemplateFile | undefined;

        return oResult?.FileContent ? oResult : undefined;
    }

    /** base64 -> 바이트 배열 -> Blob -> 다운로드 트리거 */
    private saveFile(oFile: TemplateFile): void {
        const aBytes = Uint8Array.from(
            atob(oFile.FileContent),
            (sChar: string): number => sChar.charCodeAt(0)
        );

        const oBlob = new Blob([aBytes], { type: oFile.MimeType });
        const sObjectUrl = URL.createObjectURL(oBlob);

        const oLink = document.createElement("a");
        oLink.href = sObjectUrl;
        oLink.download = oFile.FileName;
        oLink.click();

        URL.revokeObjectURL(sObjectUrl);
    }
}
