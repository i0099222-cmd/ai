"! ZCL_ATC_CHECK_NAMING 의 Local Types (ADT 의 Local Types 탭 / CCIMP).
"!
"! get_meta_data( ) 가 돌려줄 메타데이터 객체다. SAP 이 주는 클래스가 아니라
"! 체크를 만드는 쪽이 IF_CI_ATC_CHECK_META_DATA 를 구현해 직접 만든다
"! (CL_CI_ATC_CHECK_EXAMPLE 도 자기 로컬 타입에 같은 이름으로 들고 있다).
"!
"! 예제는 생성자로 체크 파라미터를 받는다. 파라미터에 따라 활성 finding 코드가
"! 달라지기 때문이다. 우리는 파라미터를 쓰지 않으므로(규칙은 ZTATCNAMING 에
"! 있다) 생성자가 없다.
CLASS lcl_meta_data DEFINITION
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ci_atc_check_meta_data.

ENDCLASS.


CLASS lcl_meta_data IMPLEMENTATION.

  METHOD if_ci_atc_check_meta_data~get_description.

    " 체크 변형과 ATC Problems 뷰에 뜨는 이름. 시스템 언어가 EN 이라 영어다.
    description = 'Naming conventions (customer rules)'.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_check_object_types.

    " 다룰 오브젝트 타입을 규칙 테이블에서 정한다. 이렇게 두면 새 타입의
    " 규칙을 넣을 때 행만 추가하면 되고 이 코드는 그대로다. 등록하지 않은
    " 타입에는 ATC 가 이 체크를 부르지 않으므로 헛도는 호출도 없다.
    SELECT DISTINCT objtype FROM ztatcnaming
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_objtype).

    " 🔴 반환 테이블이 단순 타입 테이블이 아니라 구조체 테이블이면
    "   ( CONV #( ls-objtype ) ) 를 ( objtype = ls-objtype ) 형태로 바꾼다.
    check_object_types = VALUE #( FOR ls IN lt_objtype
                                  ( CONV #( ls-objtype ) ) ).

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_finding_code_infos.

    " finding 코드마다 심각도와 메시지 텍스트를 여기서 한 번 정한다.
    " ty_finding 에는 심각도 필드가 없으므로, 규칙의 priority 를 건별로
    " 반영하려면 코드를 심각도만큼 나누는 수밖에 없다.
    "
    " 텍스트가 전부 '&1' 인 것은 실수가 아니다. 규칙마다 문장이 다르므로
    " 코드에 고정 문장을 걸 수 없고, run( ) 이 규칙의 msgtext 를 param_1 로
    " 넘겨 그 자리를 채운다.
    "
    " 🔴 필드 이름 확인 필요. code / severity / text 순으로 썼는데
    "   text 가 message 나 description 일 수 있다.
    finding_code_infos = VALUE #(
      ( code     = zcl_atc_check_naming=>finding_codes-error
        severity = if_ci_atc_check=>finding_severities-error
        text     = '&1' )
      ( code     = zcl_atc_check_naming=>finding_codes-warning
        severity = if_ci_atc_check=>finding_severities-warning
        text     = '&1' )
      ( code     = zcl_atc_check_naming=>finding_codes-note
        severity = if_ci_atc_check=>finding_severities-note
        text     = '&1' ) ).

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_attributes.

    " 체크 파라미터를 쓰지 않는다.
    "
    " SAP 예제는 이름 패턴을 체크 변형의 파라미터로 둔다. 그러면 규칙을 바꿀
    " 때마다 변형을 고쳐 이송해야 하고 개발자가 아니면 손댈 수 없다. 규칙을
    " ZTATCNAMING 에 둔 이유가 그것이므로 여기는 비운다.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_quickfix_code_infos.

    " 퀵픽스 없음. 이름을 바꾸는 것은 참조를 전부 따라가야 하는 일이라
    " 자동으로 고칠 수 있는 종류의 위반이 아니다.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~is_remote_enabled.

    " 원격(중앙 체크 시스템) 실행을 허용한다. 이 체크가 보는 것은 프레임워크가
    " 넘겨주는 오브젝트 이름과 우리 규칙 테이블뿐이고, 검사 대상 시스템의
    " 데이터를 읽지 않는다.
    "
    " 전제: 규칙 테이블 ZTATCNAMING 은 "체크가 도는 쪽" 에 있어야 한다.
    " 중앙 체크 시스템을 쓴다면 거기에도 테이블과 규칙 행이 있어야 한다.
    is_remote_enabled = abap_true.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~uses_checksums.

    " 체크섬을 쓰지 않는다. 체크섬은 소스가 바뀌어도 같은 위반을 같은 것으로
    " 알아보게 하는 장치인데, 우리 finding 은 소스의 한 줄이 아니라 오브젝트
    " 이름에 붙는다. 이름이 바뀌면 그건 다른 위반이거나 해소된 것이다.
    uses_checksums = abap_false.

  ENDMETHOD.

ENDCLASS.
