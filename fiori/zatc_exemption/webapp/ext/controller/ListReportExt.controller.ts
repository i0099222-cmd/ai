import ControllerExtension from "sap/ui/core/mvc/ControllerExtension";
import ExtensionAPI from "sap/fe/templates/ListReport/ExtensionAPI";
import ODataModel from "sap/ui/model/odata/v4/ODataModel";
import Dialog from "sap/m/Dialog";
import Button from "sap/m/Button";
import Label from "sap/m/Label";
import Input from "sap/m/Input";
import MultiInput from "sap/m/MultiInput";
import Token from "sap/m/Token";
import TextArea from "sap/m/TextArea";
import DatePicker from "sap/m/DatePicker";
import SimpleForm from "sap/ui/layout/form/SimpleForm";
import SegmentedButton from "sap/m/SegmentedButton";
import SegmentedButtonItem from "sap/m/SegmentedButtonItem";
import Table from "sap/m/Table";
import Column from "sap/m/Column";
import ColumnListItem from "sap/m/ColumnListItem";
import Text from "sap/m/Text";
import VBox from "sap/m/VBox";
import JSONModel from "sap/ui/model/json/JSONModel";

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
	onPreRegister(): void {
		// 패키지: 엔터를 치면 토큰이 된다. 한 토큰 = 패키지 하나, * 허용(예: ZSD*).
		// 오브젝트: 행마다 유형 + 이름. 이름에 * 허용(예: ZCL_CM*).
		const rows = new JSONModel({ objects: [{ ObjectType: "CLAS", ObjectName: "" }] });

		const scope = new SegmentedButton({
			selectedKey: "PCKG",
			items: [new SegmentedButtonItem({ key: "PCKG", text: "Package" }), new SegmentedButtonItem({ key: "OBJ", text: "Object" })]
		});
		const variant = new Input({ width: "100%" });
		const checkClass = new Input({ width: "100%", placeholder: "Filled from the variant if it has one check" });
		const checkCodeLabel = new Label({ text: "Check Message Code", required: true, visible: false });
		const checkCode = new Input({ width: "100%", visible: false });

		const packages = new MultiInput({ width: "100%", showValueHelp: false, placeholder: "ZCM_ATC, ZSD* ... (Enter)" });
		packages.addValidator((args: { text: string }) => new Token({ key: args.text.toUpperCase(), text: args.text.toUpperCase() }));

		const objects = new Table({
			mode: "Delete",
			visible: false,
			columns: [new Column({ header: new Text({ text: "Object Type" }), width: "8rem" }), new Column({ header: new Text({ text: "Object Name" }) })],
			items: {
				path: "/objects",
				template: new ColumnListItem({
					cells: [new Input({ value: "{ObjectType}", maxLength: 4 }), new Input({ value: "{ObjectName}" })]
				})
			},
			delete: (event: { getParameter(name: string): unknown }) => {
				const path = (event.getParameter("listItem") as ColumnListItem).getBindingContext()!.getPath();
				const list = rows.getProperty("/objects") as object[];
				list.splice(Number(path.split("/").pop()), 1);
				rows.setProperty("/objects", list);
			}
		});
		objects.setModel(rows);
		const addRow = new Button({
			text: "Add Object",
			visible: false,
			press: () => rows.setProperty("/objects", [...(rows.getProperty("/objects") as object[]), { ObjectType: "CLAS", ObjectName: "" }])
		});

		const targetsLabel = new Label({ text: "Packages", required: true });
		scope.attachSelectionChange(() => {
			const isObject = scope.getSelectedKey() === "OBJ";
			targetsLabel.setText(isObject ? "Objects" : "Packages");
			packages.setVisible(!isObject);
			objects.setVisible(isObject);
			addRow.setVisible(isObject);
			checkCodeLabel.setVisible(isObject);
			checkCode.setVisible(isObject);
		});

		const reason = new Input({ width: "100%" });
		const justification = new TextArea({ width: "100%", rows: 3 });
		const validTo = new DatePicker({ width: "100%", valueFormat: "yyyy-MM-dd" });

		const dialog: Dialog = new Dialog({
			title: "Pre-Register",
			contentWidth: "36rem",
			content: [
				new SimpleForm({
					editable: true,
					content: [
						new Label({ text: "Object Scope" }), scope,
						new Label({ text: "Check Variant", required: true }), variant,
						new Label({ text: "Check Class" }), checkClass,
						checkCodeLabel, checkCode,
						targetsLabel, new VBox({ items: [packages, objects, addRow] }),
						new Label({ text: "Reason Code" }), reason,
						new Label({ text: "Justification" }), justification,
						new Label({ text: "Valid To", required: true }), validTo
					]
				})
			],
			beginButton: new Button({
				text: "OK",
				type: "Emphasized",
				press: async () => {
					const isObject = scope.getSelectedKey() === "OBJ";
					const targets = isObject
						? (rows.getProperty("/objects") as { ObjectType: string; ObjectName: string }[])
								.filter((row: { ObjectType: string; ObjectName: string }) => row.ObjectName)
								.map((row: { ObjectType: string; ObjectName: string }) => ({ ObjectType: row.ObjectType.toUpperCase(), ObjectName: row.ObjectName.toUpperCase() }))
						: packages.getTokens().map((token: Token) => ({ ObjectType: "DEVC", ObjectName: token.getKey() }));
					dialog.close();
					await this.invokePreRegister({
						ScopeType: scope.getSelectedKey(),
						CheckVariant: variant.getValue().toUpperCase(),
						CheckClass: checkClass.getValue().toUpperCase(),
						CheckCode: isObject ? checkCode.getValue().toUpperCase() : "",
						ReasonCode: reason.getValue().toUpperCase(),
						ReasonText: justification.getValue(),
						ValidTo: validTo.getValue(),
						_Targets: targets
					});
				}
			}),
			endButton: new Button({ text: "Cancel", press: () => dialog.close() }),
			afterClose: () => dialog.destroy()
		});
		dialog.open();
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
