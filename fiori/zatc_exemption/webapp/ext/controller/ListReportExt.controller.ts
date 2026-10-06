import ControllerExtension from "sap/ui/core/mvc/ControllerExtension";
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";
import Context from "sap/ui/model/odata/v4/Context";
import ODataListBinding from "sap/ui/model/odata/v4/ODataListBinding";
import JSONModel from "sap/ui/model/json/JSONModel";
import Filter from "sap/ui/model/Filter";
import FilterOperator from "sap/ui/model/FilterOperator";
import Dialog from "sap/m/Dialog";
import SelectDialog from "sap/m/SelectDialog";
import StandardListItem from "sap/m/StandardListItem";
import Button from "sap/m/Button";
import Label from "sap/m/Label";
import Input from "sap/m/Input";
import TextArea from "sap/m/TextArea";
import DatePicker from "sap/m/DatePicker";
import Table from "sap/m/Table";
import Column from "sap/m/Column";
import ColumnListItem from "sap/m/ColumnListItem";
import Text from "sap/m/Text";
import Toolbar from "sap/m/Toolbar";
import ToolbarSpacer from "sap/m/ToolbarSpacer";
import Title from "sap/m/Title";
import SimpleForm from "sap/ui/layout/form/SimpleForm";

// 상태를 바꾸는 액션. 끝나면 목록을 다시 읽는다.
// FE 는 액션이 돌려준 행($self)만 바꿔 끼우고 탭 필터를 다시 적용하지 않는다.
// 그래서 Submit 후에도 Draft 탭에 상태만 Pending 인 행이 남는다.
// preRegister 는 새 초안을 만들므로 목록을 다시 읽어야 보인다.
// simulateImpact 는 데이터를 바꾸지 않으므로 넣지 않는다.
const REFRESH_ACTIONS = /\.(submit|withdraw|approve|reject|extendValidity|preRegister)(\(|$)/;

/**
 * @namespace zatcexemption.ext.controller
 * @controller
 */
export default class ListReportExt extends ControllerExtension {
	// @sapui5/types 에는 base 가 없다. FE 가 붙여 주는 컨트롤러의 모양만 선언한다.
	declare base: {
		getExtensionAPI(): ExtensionAPI;
		editFlow: { invokeAction(name: string, parameters: object): Promise<unknown> };
	};

	static overrides = {
		editFlow: {
			// UI5 1.114 이상. actionName 은 "<네임스페이스>.submit" 형태다.
			onAfterActionExecution(this: ListReportExt, actionName: string): void {
				if (!REFRESH_ACTIONS.test(actionName)) {
					return;
				}
				const extensionAPI = this.base.getExtensionAPI();
				// 다중 뷰(탭): 지금 탭은 바로, 나머지 탭은 열 때 다시 읽고 건수도 갱신한다.
				// 이 메소드가 없는 버전이면 Go 버튼을 누른 것과 같은 refresh 로 대신한다.
				if (typeof extensionAPI.setTabContentToBeRefreshedOnNextOpening === "function") {
					extensionAPI.setTabContentToBeRefreshedOnNextOpening();
					extensionAPI.refreshTabsCount();
				} else {
					void extensionAPI.refresh();
				}
			}
		}
	};

	// [Pre-Register] 버튼. manifest 의 custom action 이 이 메소드를 부른다.
	// FE 의 기본 입력창은 deep parameter(대상 여러 행)를 그리지 못해서 입력창을 직접 띄운다.
	// 확인을 누르면 백엔드의 같은 static 액션 preRegister 를 부른다.
	//
	// 대상 표의 한 행 = 신청서 1건. Object Name 이 비면 패키지 신청, 있으면 오브젝트 신청.
	// 이름에는 * 를 쓸 수 있다(예: ZSD*, ZCL_CM*). 범위 판정은 백엔드가 행마다 한다.
	onPreRegister(): void {
		const emptyRow = () => ({ Devclass: "", ObjectType: "", ObjectName: "", CheckCode: "" });
		const rows = new JSONModel({ targets: [emptyRow(), emptyRow(), emptyRow()] });

		const variant = new Input({ width: "100%", showValueHelp: true });
		const checkClass = new Input({ width: "100%", showValueHelp: true, placeholder: "Filled from the variant if it has one check" });
		// 변형과 체크 클래스는 짝 목록(CheckClassVH)에서 고른다. 어느 쪽에서 골라도 둘 다 채운다.
		const pickVariant = () =>
			this.openValueHelp("Check Variant", "/CheckClassVH", "CheckVariant", "CheckClass", (picked) => {
				variant.setValue(picked.getProperty("CheckVariant") as string);
				checkClass.setValue(picked.getProperty("CheckClass") as string);
			});
		variant.attachValueHelpRequest(pickVariant);
		checkClass.attachValueHelpRequest(pickVariant);

		const reason = new Input({ width: "100%", showValueHelp: true });
		reason.attachValueHelpRequest(() =>
			this.openValueHelp("Reason Code", "/ReasonVH", "ReasonCode", "", (picked) => reason.setValue(picked.getProperty("ReasonCode") as string))
		);
		const justification = new TextArea({ width: "100%", rows: 3 });
		const validTo = new DatePicker({ width: "100%", valueFormat: "yyyy-MM-dd" });

		// 표 안의 입력칸은 템플릿을 행마다 복제한 것이다. 핸들러가 템플릿 변수(input)를 잡으면
		// 화면에 없는 템플릿에 값이 들어가므로, 눌린 칸(event source)의 행 경로로 모델에 쓴다.
		// 행 모델의 필드명이 VH 의 키와 같다(Devclass, CheckCode).
		const cellValueHelp = (input: Input, title: string, path: string, key: string, description: string) => {
			input.attachValueHelpRequest((event: { getSource(): unknown }) => {
				const row = (event.getSource() as Input).getBindingContext()!.getPath();
				this.openValueHelp(title, path, key, description, (picked) => rows.setProperty(`${row}/${key}`, picked.getProperty(key)));
			});
			return input;
		};

		const targets = new Table({
			mode: "Delete",
			headerToolbar: new Toolbar({
				content: [
					new Title({ text: "Targets" }),
					new ToolbarSpacer(),
					new Button({
						icon: "sap-icon://add",
						text: "Add Row",
						press: () => rows.setProperty("/targets", [...(rows.getProperty("/targets") as object[]), emptyRow()])
					})
				]
			}),
			columns: [
				new Column({ header: new Text({ text: "Package" }) }),
				new Column({ header: new Text({ text: "Object Type" }), width: "7rem" }),
				new Column({ header: new Text({ text: "Object Name" }) }),
				new Column({ header: new Text({ text: "Check Message Code" }) })
			],
			items: {
				path: "/targets",
				template: new ColumnListItem({
					cells: [
						cellValueHelp(new Input({ value: "{Devclass}", showValueHelp: true }), "Package", "/PackageVH", "Devclass", "ParentPackage"),
						new Input({ value: "{ObjectType}", maxLength: 4, placeholder: "CLAS" }),
						new Input({ value: "{ObjectName}", placeholder: "Empty = package" }),
						cellValueHelp(new Input({ value: "{CheckCode}", showValueHelp: true }), "Check Message Code", "/CheckCodeVH", "CheckCode", "RuleText")
					]
				})
			},
			delete: (event: { getParameter(name: string): unknown }) => {
				const path = (event.getParameter("listItem") as ColumnListItem).getBindingContext()!.getPath();
				const list = rows.getProperty("/targets") as object[];
				list.splice(Number(path.split("/").pop()), 1);
				rows.setProperty("/targets", list);
			}
		});
		targets.setModel(rows);

		const dialog: Dialog = new Dialog({
			title: "Pre-Register",
			contentWidth: "48rem",
			content: [
				new SimpleForm({
					editable: true,
					content: [
						new Label({ text: "Check Variant", required: true }), variant,
						new Label({ text: "Check Class" }), checkClass,
						new Label({ text: "Reason Code" }), reason,
						new Label({ text: "Justification" }), justification,
						new Label({ text: "Valid To", required: true }), validTo
					]
				}),
				targets
			],
			beginButton: new Button({
				text: "OK",
				type: "Emphasized",
				press: async () => {
					type Row = { Devclass: string; ObjectType: string; ObjectName: string; CheckCode: string };
					const filled = (rows.getProperty("/targets") as Row[])
						.filter((row: Row) => row.Devclass || row.ObjectName)
						.map((row: Row) => ({
							Devclass: row.Devclass.toUpperCase(),
							ObjectType: row.ObjectType.toUpperCase(),
							ObjectName: row.ObjectName.toUpperCase(),
							CheckCode: row.CheckCode.toUpperCase()
						}));
					dialog.close();
					await this.invokePreRegister({
						CheckVariant: variant.getValue().toUpperCase(),
						CheckClass: checkClass.getValue().toUpperCase(),
						ReasonCode: reason.getValue().toUpperCase(),
						ReasonText: justification.getValue(),
						ValidTo: validTo.getValue(),
						_Targets: filled
					});
				}
			}),
			endButton: new Button({ text: "Cancel", press: () => dialog.close() }),
			afterClose: () => dialog.destroy()
		});
		dialog.open();
	}

	// 값 도움 목록. 서비스에 노출된 VH 엔티티셋을 그대로 읽는다(검색은 키 포함 검색).
	private openValueHelp(title: string, path: string, key: string, description: string, onPick: (picked: Context) => void): void {
		const model = this.base.getExtensionAPI().getModel() as ODataModel;
		const help: SelectDialog = new SelectDialog({
			title: title,
			items: {
				path: path,
				template: new StandardListItem({ title: `{${key}}`, description: description ? `{${description}}` : "" })
			},
			search: (event: { getParameter(name: string): unknown }) => {
				const value = String(event.getParameter("value") ?? "").toUpperCase();
				(help.getBinding("items") as ODataListBinding | undefined)?.filter(
					value ? [new Filter(key, FilterOperator.Contains, value)] : []
				);
			},
			confirm: (event: { getParameter(name: string): unknown }) => {
				const item = event.getParameter("selectedItem") as StandardListItem | undefined;
				const picked = item?.getBindingContext() as Context | undefined;
				if (picked) {
					onPick(picked);
				}
			},
			cancel: () => help.destroy()
		});
		help.setModel(model);
		help.attachConfirm(() => help.destroy());
		help.open("");
	}

	private async invokePreRegister(parameters: Record<string, unknown>): Promise<void> {
		const model = this.base.getExtensionAPI().getModel() as ODataModel;
		// 액션 이름 앞의 네임스페이스는 서비스마다 다르다. 메타데이터의 컨테이너 이름에서 얻는다.
		const container = model.getMetaModel().getObject("/$EntityContainer") as string;
		const namespace = container.substring(0, container.lastIndexOf("."));
		// static 액션은 엔티티셋 컬렉션에 묶인다. 그 컬렉션의 헤더 컨텍스트로 부른다.
		const collection = model.bindList("/Exemption").getHeaderContext();

		// editFlow 로 부르면 메시지 표시·바쁨 표시·onAfterActionExecution(새로고침)을 FE 가 해 준다.
		await this.base.editFlow.invokeAction(`${namespace}.preRegister`, {
			model: model,
			contexts: collection,
			skipParameterDialog: true,
			parameterValues: Object.keys(parameters).map((name) => ({ name: name, value: parameters[name] }))
		});
	}
}
