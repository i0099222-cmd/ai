"! 예시: 파일 업로드 BO(부모)의 behavior implementation.
"!
"! 흐름:
"!   1. 사용자가 Fiori 화면에서 파일을 올린다 (@Semantics.largeObject 스트림)
"!   2. Filename이 바뀌므로 determination이 발동한다
"!   3. determination이 uploadCsvData 액션을 실행한다
"!   4. 액션이 CSV를 파싱해 EML로 자식 엔티티에 넣는다
"!
"! 버튼도, UI5 코드도, 액션 경로 맞추기도 필요 없다.
"!
"! ── behavior definition에 필요한 정의 ──────────────────────────────
"!
"!   managed implementation in class zbp_i_file unique;
"!   strict ( 2 );
"!   with draft;
"!
"!   define behavior for zi_file alias File
"!   persistent table zfile_table
"!   lock master
"!   total etag end_user
"!   draft table zfile_tabled
"!   {
"!     create; update; delete;
"!
"!     action ( features : instance ) uploadCsvData result [1] $self;
"!
"!     association _data { create; with draft; }
"!
"!     " 파일이 올라오면(=Filename이 바뀌면) 알아서 실행된다
"!     determination fields on modify { field Filename; }
"!
"!     draft action Edit;
"!     draft action Activate;
"!     draft action Discard;
"!     draft action Resume;
"!     draft determine action Prepare;
"!   }
"!
"! ── CDS 뷰에서 파일을 스트림으로 노출하는 부분 ──────────────────────
"!
"!   @Semantics.largeObject:
"!   { mimeType: 'MimeType',
"!     fileName: 'Filename',
"!     acceptableMimeTypes: [ 'text/csv' ],
"!     contentDispositionPreference: #INLINE }
"!   _file.attachment  as Attachment,
"!
"!   @Semantics.mimeType: true
"!   _file.mimetype    as MimeType,
"!   _file.filename    as Filename,
CLASS lhc_file DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS fields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR file~fields.

    METHODS uploadcsvdata FOR MODIFY
      IMPORTING keys FOR ACTION file~uploadcsvdata RESULT result.

ENDCLASS.


CLASS lhc_file IMPLEMENTATION.

  METHOD fields.

    " draft 인스턴스일 때만 처리한다. 활성 인스턴스에서 돌리면
    " 저장 때마다 같은 파일이 다시 파싱된다.
    IF keys[ 1 ]-%is_draft = '01'.

      MODIFY ENTITIES OF zi_file IN LOCAL MODE
        ENTITY file
        EXECUTE uploadcsvdata
        FROM CORRESPONDING #( keys ).

    ENDIF.

  ENDMETHOD.


  METHOD uploadcsvdata.

    READ ENTITIES OF zi_file IN LOCAL MODE
      ENTITY file
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file).

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_file) = lt_file[ 1 ].

    " ── CSV 파싱 ────────────────────────────────────────────────────
    "    대상 구조가 정해져 있으므로 컬럼 순서대로 채워진다.
    DATA lt_data TYPE STANDARD TABLE OF zdata_table.

    NEW zcl_excel_table_migrator( )->parse(
      EXPORTING iv_file_content = ls_file-attachment
      CHANGING  ct_data         = lt_data ).

    " ── 기존 자식 데이터 삭제 ───────────────────────────────────────
    "    같은 파일을 다시 올렸을 때 중복이 쌓이지 않게 한다.
    READ ENTITIES OF zi_file IN LOCAL MODE
      ENTITY file
        BY \_data
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing).

    IF lt_existing IS NOT INITIAL.
      MODIFY ENTITIES OF zi_file IN LOCAL MODE
        ENTITY data
        DELETE FROM VALUE #( FOR ls_existing IN lt_existing
                             ( %is_draft = ls_existing-%is_draft
                               %key      = ls_existing-%key ) ).
    ENDIF.

    " ── 자식 엔티티에 생성 ──────────────────────────────────────────
    "    EML이라 RAP LUW 안에서 처리된다. COMMIT WORK도, 별도 세션도 필요 없다.
    MODIFY ENTITIES OF zi_file IN LOCAL MODE
      ENTITY file
        CREATE BY \_data
        AUTO FILL CID
        FIELDS ( end_user )
        WITH VALUE #( ( %is_draft = ls_file-%is_draft
                        %tky      = ls_file-%tky
                        %target   = VALUE #( FOR ls_data IN lt_data
                                             ( %is_draft = ls_file-%is_draft
                                               %data     = CORRESPONDING #( ls_data ) ) ) ) )
      REPORTED DATA(lt_reported)
      FAILED   DATA(lt_failed).

    " 자식 생성 실패는 그대로 올려보내야 사용자가 원인을 본다.
    reported = CORRESPONDING #( DEEP lt_reported ).
    failed   = CORRESPONDING #( DEEP lt_failed ).

    APPEND VALUE #( %tky = ls_file-%tky ) TO mapped-file.

    APPEND VALUE #( %tky = ls_file-%tky
                    %msg = new_message_with_text(
                             severity = if_abap_behv_message=>severity-success
                             text     = |{ lines( lt_data ) }건을 읽었습니다| ) )
           TO reported-file.

    result = VALUE #( ( %tky = ls_file-%tky %param = ls_file ) ).

  ENDMETHOD.

ENDCLASS.
