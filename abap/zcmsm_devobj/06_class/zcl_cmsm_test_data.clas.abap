"! 개발 오브젝트 통합관리 · 테스트 데이터 (ADT에서 F9로 실행)
"!
"! - 탭마다 5건 (요청은 상태 R/I/C/J/X 하나씩 + 이력, VH는 데이터 소스 포함)
"! - 표시 번호에 'T'를 붙여(RQ-T001 …) 번호 범위로 채번되는 실제 번호(RQ-0001 …)와 안 겹친다
"! - 다시 실행하면 이전 테스트 데이터('T' 번호)를 지우고 새로 넣는다
"! - 사람 필드(요청자·담당자·업무담당자)는 전부 실행한 사용자 → 바로 접수·완료·반려 테스트 가능
"! - 시스템 ID(ECD/S4D)는 없으면 넣고 있으면 덮어쓴다
CLASS zcl_cmsm_test_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.

    DATA mv_user TYPE c LENGTH 12.
    DATA mv_ts   TYPE timestampl.

    METHODS delete_old.

    METHODS fill_sysid
      RETURNING VALUE(rv_count) TYPE i.

    METHODS fill_request
      RETURNING VALUE(rv_count) TYPE i
      RAISING   cx_uuid_error.

    METHODS fill_mapping
      RETURNING VALUE(rv_count) TYPE i
      RAISING   cx_uuid_error.

    METHODS fill_value_help
      RETURNING VALUE(rv_count) TYPE i
      RAISING   cx_uuid_error.

    METHODS fill_odata_service
      RETURNING VALUE(rv_count) TYPE i
      RAISING   cx_uuid_error.

    METHODS fill_tech_debt
      RETURNING VALUE(rv_count) TYPE i
      RAISING   cx_uuid_error.

    METHODS uuid
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16
      RAISING   cx_uuid_error.

ENDCLASS.


CLASS zcl_cmsm_test_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    mv_user = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD mv_ts.

    TRY.
        delete_old( ).

        out->write( |시스템 ID    { fill_sysid( ) }건| ).
        out->write( |요청         { fill_request( ) }건 (+ 이력)| ).
        out->write( |매핑         { fill_mapping( ) }건| ).
        out->write( |Value Help   { fill_value_help( ) }건 (+ 데이터 소스)| ).
        out->write( |OData 서비스 { fill_odata_service( ) }건| ).
        out->write( |기술부채     { fill_tech_debt( ) }건| ).

        COMMIT WORK.
        out->write( |완료. 사람 필드는 { mv_user }로 넣었습니다.| ).

      CATCH cx_uuid_error INTO DATA(lx_uuid).
        ROLLBACK WORK.
        out->write( |UUID 생성 실패: { lx_uuid->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.


  METHOD delete_old.

    " 자식 먼저
    DELETE FROM ztcmsm00180 WHERE requuid IN ( SELECT requuid FROM ztcmsm00170 WHERE reqid LIKE 'RQ-T%' ).
    DELETE FROM ztcmsm00170 WHERE reqid LIKE 'RQ-T%'.
    DELETE FROM ztcmsm00190 WHERE mapid LIKE 'MP-T%'.
    DELETE FROM ztcmsm00210 WHERE vhuuid IN ( SELECT vhuuid FROM ztcmsm00200 WHERE vhid LIKE 'VH-T%' ).
    DELETE FROM ztcmsm00200 WHERE vhid LIKE 'VH-T%'.
    DELETE FROM ztcmsm00220 WHERE sbid LIKE 'SB-T%'.
    DELETE FROM ztcmsm00230 WHERE debtid LIKE 'TD-T%'.

  ENDMETHOD.


  METHOD fill_sysid.

    DATA lt_sysid TYPE STANDARD TABLE OF ztcmsm00240 WITH EMPTY KEY.

    lt_sysid = VALUE #( ( sysid = 'ECD' description = 'ECC 개발' )
                        ( sysid = 'S4D' description = 'S/4 개발' ) ).

    MODIFY ztcmsm00240 FROM TABLE @lt_sysid.
    rv_count = lines( lt_sysid ).

  ENDMETHOD.


  METHOD fill_request.

    DATA lt_req  TYPE STANDARD TABLE OF ztcmsm00170 WITH EMPTY KEY.
    DATA lt_hist TYPE STANDARD TABLE OF ztcmsm00180 WITH EMPTY KEY.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    lt_req = VALUE #(
      ( requuid     = uuid( )
        reqid       = 'RQ-T001'
        sapmodule   = 'SD'
        reqstatus   = 'R'
        title       = '거래처 Value Help 신규 요청'
        reqtext     = `수주 화면에서 거래처를 검색할 VH가 필요합니다. 영업조직 기준으로 걸러지면 좋겠습니다.` )
      ( requuid     = uuid( )
        reqid       = 'RQ-T002'
        sapmodule   = 'MM'
        reqstatus   = 'I'
        title       = '자재 조회 OData 서비스 개발'
        reqtext     = `자재 기본정보와 플랜트 데이터를 조회하는 OData V4 서비스를 요청드립니다.`
        procresult  = `ZUI_MM_MATERIAL_O4 개발 중. 플랜트 데이터 연결 남음.` )
      ( requuid     = uuid( )
        reqid       = 'RQ-T003'
        sapmodule   = 'FI'
        reqstatus   = 'C'
        title       = '전표 일괄 전기 프로그램 To-Be 전환'
        reqtext     = `ECC Z_FI_POST_DOCUMENT를 S/4에서 쓸 수 있게 전환해 주세요.`
        procresult  = `ZCL_FI_POST_DOCUMENT로 전환하고 매핑 등록 완료.`
        relno       = 'MP-T001'
        donedate    = lv_today )
      ( requuid     = uuid( )
        reqid       = 'RQ-T004'
        sapmodule   = 'CO'
        reqstatus   = 'J'
        title       = '원가센터 Value Help 추가'
        reqtext     = `원가센터를 회사코드 기준으로 고르는 VH가 필요합니다.`
        closereason = '표준 I_CostCenterVH로 대체할 수 있어 반려합니다.' )
      ( requuid     = uuid( )
        reqid       = 'RQ-T005'
        sapmodule   = 'PP'
        reqstatus   = 'X'
        title       = '생산오더 확정 RFC 검토'
        reqtext     = `MES에서 호출할 생산오더 확정 RFC 검토 부탁드립니다.`
        closereason = '요구사항이 바뀌어 취소합니다.' ) ).

    " 사람·관리 필드
    MODIFY lt_req FROM VALUE ztcmsm00170( assignee           = mv_user
                                          createdby          = mv_user
                                          createdat          = mv_ts
                                          lastchangedby      = mv_user
                                          lastchangedat      = mv_ts
                                          locallastchangedat = mv_ts )
           TRANSPORTING assignee createdby createdat lastchangedby lastchangedat locallastchangedat
           WHERE requuid IS NOT INITIAL.

    " 이력: 생성 1줄 + 상태가 바뀐 건은 상태 변경 1줄
    LOOP AT lt_req INTO DATA(ls_req).

      APPEND VALUE #( histuuid  = uuid( )
                      requuid   = ls_req-requuid
                      histkind  = 'C'
                      fieldname = '제목'
                      newvalue  = ls_req-title ) TO lt_hist.

      IF ls_req-reqstatus <> 'R'.
        APPEND VALUE #( histuuid  = uuid( )
                        requuid   = ls_req-requuid
                        histkind  = 'S'
                        fieldname = '상태'
                        oldvalue  = COND #( WHEN ls_req-reqstatus = 'C' THEN '진행 중' ELSE '요청' )
                        newvalue  = SWITCH #( ls_req-reqstatus
                                              WHEN 'I' THEN '진행 중'
                                              WHEN 'C' THEN '완료'
                                              WHEN 'J' THEN '반려'
                                              WHEN 'X' THEN '취소' )
                        histnote  = ls_req-closereason ) TO lt_hist.
      ENDIF.

    ENDLOOP.

    MODIFY lt_hist FROM VALUE ztcmsm00180( changedby          = mv_user
                                           changedat          = mv_ts
                                           locallastchangedat = mv_ts )
           TRANSPORTING changedby changedat locallastchangedat
           WHERE histuuid IS NOT INITIAL.

    INSERT ztcmsm00170 FROM TABLE @lt_req.
    INSERT ztcmsm00180 FROM TABLE @lt_hist.
    rv_count = lines( lt_req ).

  ENDMETHOD.


  METHOD fill_mapping.

    DATA lt_map TYPE STANDARD TABLE OF ztcmsm00190 WITH EMPTY KEY.

    lt_map = VALUE #(
      " 매핑 · FM → 클래스
      ( mapuuid      = uuid( )
        mapid        = 'MP-T001'
        mapkind      = 'M'
        sapmodule    = 'FI'
        srcsysid     = 'ECD'
        asistype     = 'FM'
        asisname     = 'Z_FI_POST_DOCUMENT'
        tgtsysid     = 'S4D'
        tobetype     = 'CLASS'
        tobename     = 'ZCL_FI_POST_DOCUMENT'
        description  = '전표 일괄 전기 로직 클래스 전환'
        objcreator   = '내부 개발팀'
        reqid        = 'RQ-T003' )
      " 매핑 · T-code → T-code (Fiori)
      ( mapuuid      = uuid( )
        mapid        = 'MP-T002'
        mapkind      = 'M'
        sapmodule    = 'FI'
        srcsysid     = 'ECD'
        asistype     = 'TCODE'
        asisname     = 'ZFI001'
        tgtsysid     = 'S4D'
        tobetype     = 'TCODE'
        tobename     = 'ZFI001'
        uikind       = 'F'
        fioriappid   = 'zfi.posting.manage'
        semobjaction = 'ZFIPosting-manage'
        description  = '전표 전기 화면 Fiori 전환'
        objcreator   = '외부 개발사 A' )
      " 매핑 · RFC → RAP 액션
      ( mapuuid      = uuid( )
        mapid        = 'MP-T003'
        mapkind      = 'M'
        sapmodule    = 'SD'
        srcsysid     = 'ECD'
        asistype     = 'RFC'
        asisname     = 'Z_SD_ORDER_CREATE'
        tgtsysid     = 'S4D'
        tobetype     = 'ACTION'
        tobename     = 'ZR_SD_SALESORDER.CREATEORDER'
        description  = '수주 생성 RFC를 RAP 액션으로 전환'
        objcreator   = '내부 개발팀' )
      " 신규 · BO
      ( mapuuid      = uuid( )
        mapid        = 'MP-T004'
        mapkind      = 'N'
        sapmodule    = 'MM'
        tgtsysid     = 'S4D'
        tobetype     = 'BO'
        tobename     = 'ZR_MM_PURCHASEREQ'
        description  = '구매요청 BO 신규 개발'
        objcreator   = '외부 개발사 A' )
      " 매핑 · T-code → T-code (React)
      ( mapuuid      = uuid( )
        mapid        = 'MP-T005'
        mapkind      = 'M'
        sapmodule    = 'PP'
        srcsysid     = 'ECD'
        asistype     = 'TCODE'
        asisname     = 'ZPP010'
        tgtsysid     = 'S4D'
        tobetype     = 'TCODE'
        tobename     = 'ZPP010'
        uikind       = 'R'
        reactapp     = 'pp-production-board'
        uiuri        = `https://react.example.com/pp/board`
        description  = '생산 현황판 React 전환'
        objcreator   = '외부 개발사 B' ) ).

    MODIFY lt_map FROM VALUE ztcmsm00190( ownerid            = mv_user
                                          createdby          = mv_user
                                          createdat          = mv_ts
                                          lastchangedby      = mv_user
                                          lastchangedat      = mv_ts
                                          locallastchangedat = mv_ts )
           TRANSPORTING ownerid createdby createdat lastchangedby lastchangedat locallastchangedat
           WHERE mapuuid IS NOT INITIAL.

    INSERT ztcmsm00190 FROM TABLE @lt_map.
    rv_count = lines( lt_map ).

  ENDMETHOD.


  METHOD fill_value_help.

    DATA lt_vh  TYPE STANDARD TABLE OF ztcmsm00200 WITH EMPTY KEY.
    DATA lt_src TYPE STANDARD TABLE OF ztcmsm00210 WITH EMPTY KEY.

    " 시스템에 실제로 있는 VH만 등록할 수 있어서(validateVhName) 이 프로그램의 VH 뷰를 쓴다
    lt_vh = VALUE #(
      ( vhuuid = uuid( ) vhid = 'VH-T001' vhname = 'ZI_CMSM_MODULEVH'    vhimpl = 'C' sapmodule = 'CM'
        description = '모듈 (도메인 고정값)'           objcreator = '내부 개발팀'  reqid = 'RQ-T001' )
      ( vhuuid = uuid( ) vhid = 'VH-T002' vhname = 'ZI_CMSM_REQSTATUSVH' vhimpl = 'C' sapmodule = 'CM'
        description = '요청 상태 (도메인 고정값)'      objcreator = '내부 개발팀' )
      ( vhuuid = uuid( ) vhid = 'VH-T003' vhname = 'ZI_CMSM_USERVH'      vhimpl = 'C' sapmodule = 'CM'
        description = '사용자 (비즈니스 사용자)'       objcreator = '내부 개발팀' )
      ( vhuuid = uuid( ) vhid = 'VH-T004' vhname = 'ZI_CMSM_SYSID'       vhimpl = 'C' sapmodule = 'CM'
        description = '시스템 ID (설정 테이블)'        objcreator = '내부 개발팀' )
      ( vhuuid = uuid( ) vhid = 'VH-T005' vhname = 'ZI_CMSM_ASISTYPEVH'  vhimpl = 'C' sapmodule = 'CM'
        description = 'As-Is 오브젝트 유형 (매핑 탭)'  objcreator = '내부 개발팀' ) ).

    MODIFY lt_vh FROM VALUE ztcmsm00200( sysid              = 'S4D'
                                         ownerid            = mv_user
                                         createdby          = mv_user
                                         createdat          = mv_ts
                                         lastchangedby      = mv_user
                                         lastchangedat      = mv_ts
                                         locallastchangedat = mv_ts )
           TRANSPORTING sysid ownerid createdby createdat lastchangedby lastchangedat locallastchangedat
           WHERE vhuuid IS NOT INITIAL.

    " 데이터 소스 (C = CDS, T = Table, D = Domain)
    lt_src = VALUE #(
      ( srcuuid = uuid( ) vhuuid = lt_vh[ vhid = 'VH-T001' ]-vhuuid srckind = 'D' srcname = 'ZDO_DM_MODULE' )
      ( srcuuid = uuid( ) vhuuid = lt_vh[ vhid = 'VH-T002' ]-vhuuid srckind = 'D' srcname = 'ZDO_DM_REQ_STATUS' )
      ( srcuuid = uuid( ) vhuuid = lt_vh[ vhid = 'VH-T003' ]-vhuuid srckind = 'C' srcname = 'I_BUSINESSUSERBASIC' )
      ( srcuuid = uuid( ) vhuuid = lt_vh[ vhid = 'VH-T004' ]-vhuuid srckind = 'T' srcname = 'ZTCMSM00240' )
      ( srcuuid = uuid( ) vhuuid = lt_vh[ vhid = 'VH-T005' ]-vhuuid srckind = 'C' srcname = 'ZI_CMSM_OBJTYPEVH' ) ).

    MODIFY lt_src FROM VALUE ztcmsm00210( locallastchangedat = mv_ts )
           TRANSPORTING locallastchangedat
           WHERE srcuuid IS NOT INITIAL.

    INSERT ztcmsm00200 FROM TABLE @lt_vh.
    INSERT ztcmsm00210 FROM TABLE @lt_src.
    rv_count = lines( lt_vh ).

  ENDMETHOD.


  METHOD fill_odata_service.

    DATA lt_sb TYPE STANDARD TABLE OF ztcmsm00220 WITH EMPTY KEY.

    lt_sb = VALUE #(
      ( sbuuid = uuid( ) sbid = 'SB-T001' srvbname = 'ZUI_SD_SALESORDER_O4' sapmodule = 'SD'
        description = '수주 관리 (Fiori UI, V4)'            objcreator = '내부 개발팀' )
      ( sbuuid = uuid( ) sbid = 'SB-T002' srvbname = 'ZUI_MM_MATERIAL_O4'   sapmodule = 'MM'
        description = '자재 조회 (Fiori UI, V4)'            objcreator = '외부 개발사 A'  reqid = 'RQ-T002' )
      ( sbuuid = uuid( ) sbid = 'SB-T003' srvbname = 'ZAPI_FI_JOURNAL_O4'   sapmodule = 'FI'
        description = '전표 조회 Web API (V4)'              objcreator = '내부 개발팀' )
      ( sbuuid = uuid( ) sbid = 'SB-T004' srvbname = 'ZUI_CO_COSTCENTER_O2' sapmodule = 'CO'
        description = '원가센터 보고서 (Fiori UI, V2)'      objcreator = '외부 개발사 B' )
      ( sbuuid = uuid( ) sbid = 'SB-T005' srvbname = 'ZUI_CMSM_DEVOBJ_O4'   sapmodule = 'CM'
        description = '개발 오브젝트 통합관리 (이 프로그램)' objcreator = '내부 개발팀' ) ).

    " 시스템에 없는 서비스 바인딩은 저장 검증(validateSrvbName)에서 막히므로
    " 실제로 있는 Z 서비스 바인딩이 있으면 앞에서부터 그 이름으로 바꾼다
    SELECT abapobject FROM i_custabapobjdirectoryentry
      WHERE abapobjecttype = 'SRVB'
        AND abapobject     LIKE 'Z%'
      ORDER BY abapobject
      INTO TABLE @DATA(lt_real)
      UP TO 5 ROWS.

    LOOP AT lt_real INTO DATA(ls_real).
      DATA(lv_idx) = sy-tabix.
      lt_sb[ lv_idx ]-srvbname    = ls_real-abapobject.
      lt_sb[ lv_idx ]-description = |시스템의 실제 서비스 바인딩 (테스트)|.
    ENDLOOP.

    MODIFY lt_sb FROM VALUE ztcmsm00220( sysid              = 'S4D'
                                         ownerid            = mv_user
                                         createdby          = mv_user
                                         createdat          = mv_ts
                                         lastchangedby      = mv_user
                                         lastchangedat      = mv_ts
                                         locallastchangedat = mv_ts )
           TRANSPORTING sysid ownerid createdby createdat lastchangedby lastchangedat locallastchangedat
           WHERE sbuuid IS NOT INITIAL.

    INSERT ztcmsm00220 FROM TABLE @lt_sb.
    rv_count = lines( lt_sb ).

  ENDMETHOD.


  METHOD fill_tech_debt.

    DATA lt_debt TYPE STANDARD TABLE OF ztcmsm00230 WITH EMPTY KEY.

    " Debt Level C = 비released 사용 / D = 표준 수정·금지
    " 개선상태 T 개선대상 / P 개선중 / C 개선완료 / E 예외등록
    lt_debt = VALUE #(
      ( debtuuid = uuid( ) debtid = 'TD-T01' sapmodule = 'SD' devid = 'SD-I-001'
        objtype  = 'CLASS'  devobj = 'ZCL_SD_ORDER_WRAPPER'      wraptype = 'W'
        stdtype  = 'FM'     stdname = 'BAPI_SALESORDER_CREATEFROMDAT2'
        debtlevel = 'C' improvestatus = 'T'
        debtdesc   = '비released BAPI를 래퍼 클래스에서 호출'
        debtreason = 'released API(I_SalesOrderTP) 전환 전까지 래퍼로 격리' )
      ( debtuuid = uuid( ) debtid = 'TD-T02' sapmodule = 'FI' devid = 'FI-R-003'
        objtype  = 'CLASS'  devobj = 'ZCL_FI_POST_DOCUMENT'      wraptype = 'D'
        stdtype  = 'TABLE'  stdname = 'BSEG'
        debtlevel = 'C' improvestatus = 'P'
        debtdesc   = 'BSEG 직접 조회'
        debtreason = 'I_JournalEntryItem으로 전환 진행 중' )
      ( debtuuid = uuid( ) debtid = 'TD-T03' sapmodule = 'MM' devid = 'MM-E-002'
        objtype  = 'ACTION' devobj = 'ZR_MM_PURCHASEREQ.RELEASE' wraptype = 'D'
        stdtype  = 'FM'     stdname = 'BAPI_REQUISITION_RELEASE'
        debtlevel = 'C' improvestatus = 'T'
        debtdesc   = '구매요청 승인 BAPI 직접 호출'
        debtreason = 'released 대체 API 확인 필요' )
      ( debtuuid = uuid( ) debtid = 'TD-T04' sapmodule = 'SD' devid = 'SD-E-005'
        objtype  = 'CLASS'  devobj = 'ZCL_SD_USEREXIT_HANDLER'   wraptype = 'D'
        stdtype  = 'ETC'    stdname = 'MV45AFZZ'
        debtlevel = 'D' improvestatus = 'E'
        debtdesc   = '판매오더 User Exit 수정'
        debtreason = '대체 BAdI 없음. PMO 예외 승인' )
      ( debtuuid = uuid( ) debtid = 'TD-T05' sapmodule = 'CO' devid = 'CO-R-002'
        objtype  = 'CDS'    devobj = 'ZI_CO_COSTREPORT'          wraptype = 'D'
        stdtype  = 'TABLE'  stdname = 'COEP'
        debtlevel = 'C' improvestatus = 'C'
        debtdesc   = 'COEP 직접 조회'
        debtreason = 'I_ActualPlanJournalEntryItem으로 전환 완료' ) ).

    MODIFY lt_debt FROM VALUE ztcmsm00230( sysid              = 'S4D'
                                           bizowner           = mv_user
                                           createdby          = mv_user
                                           createdat          = mv_ts
                                           lastchangedby      = mv_user
                                           lastchangedat      = mv_ts
                                           locallastchangedat = mv_ts )
           TRANSPORTING sysid bizowner createdby createdat lastchangedby lastchangedat locallastchangedat
           WHERE debtuuid IS NOT INITIAL.

    INSERT ztcmsm00230 FROM TABLE @lt_debt.
    rv_count = lines( lt_debt ).

  ENDMETHOD.


  METHOD uuid.
    rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
  ENDMETHOD.

ENDCLASS.
