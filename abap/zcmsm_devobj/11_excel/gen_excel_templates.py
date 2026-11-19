"""탭별 엑셀 업로드 템플릿 5개 생성 (요청 / 매핑 / Value Help / OData 서비스 / 기술부채)

시트 구성 (모든 파일 공통)
  업로드    1행 = 컬럼명(필수 * · 색), 2행 = 필드명(업로드 프로그램이 칸을 찾는 키), 3행부터 데이터
  작성 안내 작성 방법, 색 범례, 칸 설명(필수·형식·규칙·예시), 자동으로 채워지는 값
  코드값    드롭다운 목록 원본 (도메인 고정값)
"""
import sys, pathlib
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.comments import Comment
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.utils import get_column_letter

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

FONT = 'Arial'
DATA_ROWS = 500                     # 3행 ~ 502행
FIRST, LAST = 3, 3 + DATA_ROWS - 1

FILL_REQ  = PatternFill('solid', fgColor='FFF2CC')   # 필수
FILL_COND = PatternFill('solid', fgColor='FCE4D6')   # 조건부 필수
FILL_OPT  = PatternFill('solid', fgColor='EDEDED')   # 선택
FILL_KEY  = PatternFill('solid', fgColor='F7F7F7')   # 2행 필드명
FILL_HEAD = PatternFill('solid', fgColor='DDEBF7')   # 안내 표 머리글
thin = Side(style='thin', color='BFBFBF')
BORDER = Border(left=thin, right=thin, top=thin, bottom=thin)

def f(size=10, bold=False, color='000000', italic=False):
    return Font(name=FONT, size=size, bold=bold, color=color, italic=italic)

# ---------------------------------------------------------------- 코드값 (딕셔너리 1차 도메인 고정값)
CODES = {
    'MODULE':     ('모듈 (ZDO_DM_MODULE)', [('FI', 'FI'), ('CO', 'CO'), ('SD', 'SD'), ('MM', 'MM'), ('PP', 'PP'), ('CM', '공통')]),
    'MAP_KIND':   ('매핑 구분 (ZDO_DM_MAP_KIND)', [('M', '매핑'), ('N', '신규')]),
    'ASIS_TYPE':  ('As-Is 유형', [('RFC', 'RFC'), ('FM', 'Function Module'), ('PROXY', 'Proxy'), ('TABLE', 'Table'),
                                 ('TCODE', 'T-code'), ('CLASS', 'Class'), ('CDS', 'CDS')]),
    'TOBE_TYPE':  ('To-Be 유형 (VH·SRVB 제외)', [('RFC', 'RFC'), ('FM', 'Function Module'), ('PROXY', 'Proxy'), ('TABLE', 'Table'),
                                 ('TCODE', 'T-code'), ('CLASS', 'Class'), ('BO', 'BO'), ('ACTION', 'Action'), ('CDS', 'CDS')]),
    'OBJ_TYPE':   ('오브젝트 유형 (ZDO_DM_OBJ_TYPE)', [('RFC', 'RFC'), ('FM', 'Function Module'), ('PROXY', 'Proxy'), ('TABLE', 'Table'),
                                 ('TCODE', 'T-code'), ('CLASS', 'Class'), ('BO', 'BO'), ('ACTION', 'Action'), ('CDS', 'CDS'),
                                 ('VH', 'Value Help'), ('SRVB', 'Service Binding')]),
    'UI_KIND':    ('UI 종류 (ZDO_DM_UI_KIND)', [('F', 'Fiori'), ('W', 'WebGUI'), ('R', 'React')]),
    'WRAP_TYPE':  ('래핑 여부 (ZDO_DM_WRAP_TYPE)', [('W', '래퍼'), ('D', '직접 사용')]),
    'DEBT_LEVEL': ('Debt Level (ZDO_DM_DEBT_LEVEL)', [('C', 'C · 비released 사용'), ('D', 'D · 표준 수정·금지 오브젝트')]),
    'IMPROVE':    ('개선상태 (ZDO_DM_IMPROVE)', [('T', '개선대상'), ('P', '개선중'), ('C', '개선완료'), ('E', '예외등록')]),
    'DEBT_CAT':   ('부채 구분 (ZDO_DM_DEBT_CAT)', [('TAB', '미릴리즈 테이블 조회'), ('TABW', '표준 테이블 직접 변경'), ('CDS', '미릴리즈 CDS'),
                                 ('FM', '미릴리즈 함수 모듈 (BAPI 외)'), ('BAPI', 'BAPI 호출'), ('CLAS', '미릴리즈 클래스·인터페이스'),
                                 ('BDC', 'BDC (CALL TRANSACTION·배치 인풋)'), ('EXIT', 'User Exit·암시적 확장'),
                                 ('MOD', '표준 수정 (Modification)'), ('ETC', '기타')]),
}

def codes_text(key):
    return ' / '.join(f'{c} {t}' for c, t in CODES[key][1])

# ---------------------------------------------------------------- 탭 정의
# 컬럼: (컬럼명, 필드명, 필수 'Y'|'C'|'', 형식, 규칙·설명, 예시, 코드키|None, 최대 길이|None)
TABS = [
  dict(
    file='ZCMSM_업로드_1_요청.xlsx', tab='요청', entity='Request (ZR_CMSM_Req)',
    cols=[
      ('제목', 'Title', 'Y', '텍스트 120자', '요청 제목', '거래처 Value Help 신규 요청', None, 120),
      ('요청 내용', 'ReqText', '', '텍스트 (길이 제한 없음)', '자세한 요청 내용. 셀 안 줄바꿈은 Alt+Enter', '수주 화면에서 거래처를 검색할 VH가 필요합니다. 영업조직 기준으로 걸러지면 좋겠습니다.', None, None),
      ('모듈', 'SapModule', 'Y', '코드', codes_text('MODULE'), 'SD', 'MODULE', None),
      ('담당자', 'Assignee', 'Y', '사용자 ID 12자', '처리할 사람의 사용자 ID. 등록되면 이 사람에게 요청 메일이 간다', 'DEV01', None, 12),
    ],
    auto=['요청번호 (RQ-nnnn) — 저장할 때 번호 범위로 채번',
          '상태 = 요청(R). 진행·완료·반려·취소는 화면의 버튼으로만 바뀐다',
          '요청자·요청 일시 = 업로드한 사람·시각',
          '처리 내용·관련 등록번호·완료일·사유 — 담당자가 화면에서 입력'],
    notes=['한 줄 = 요청 한 건. 줄마다 담당자에게 요청 메일이 한 통씩 간다',
           '변경 이력에 생성(C) 한 줄이 남는다'],
  ),
  dict(
    file='ZCMSM_업로드_2_매핑.xlsx', tab='As-Is/To-Be 매핑', entity='Mapping (ZR_CMSM_Map)',
    cols=[
      ('구분', 'MapKind', 'Y', '코드', codes_text('MAP_KIND') + '. 신규면 As-Is 세 칸은 비운다', 'M', 'MAP_KIND', None),
      ('소스 시스템', 'SrcSysId', 'C', '시스템 ID 8자', '구분 = M이면 필수. As-Is가 있던 시스템 (시스템 ID 설정 테이블 값)', 'ECD', None, 8),
      ('As-Is 유형', 'AsisType', 'C', '코드', '구분 = M이면 필수. ' + codes_text('ASIS_TYPE'), 'FM', 'ASIS_TYPE', None),
      ('As-Is 오브젝트', 'AsisName', 'C', '대문자 80자', '구분 = M이면 필수. ECC 쪽 오브젝트 이름', 'Z_FI_POST_DOCUMENT', None, 80),
      ('타겟 시스템', 'TgtSysId', '', '시스템 ID 8자', 'To-Be를 만든 시스템', 'S4D', None, 8),
      ('To-Be 유형', 'TobeType', 'Y', '코드', codes_text('TOBE_TYPE') + '. VH·Service Binding은 각자 탭에 올린다', 'CLASS', 'TOBE_TYPE', None),
      ('To-Be 오브젝트', 'TobeName', 'Y', '대문자 80자', 'S/4 쪽 오브젝트 이름. Action은 BO.ACTION 형태', 'ZCL_FI_POST_DOCUMENT', None, 80),
      ('UI 종류', 'UiKind', 'C', '코드', 'To-Be 유형 = TCODE면 필수, 아니면 비운다. ' + codes_text('UI_KIND'), '', 'UI_KIND', None),
      ('Fiori 앱 ID', 'FioriAppId', '', '텍스트 120자', 'UI 종류 = F일 때만', '', None, 120),
      ('Semantic Object-Action', 'SemObjAction', 'C', '텍스트 120자', 'UI 종류 = F면 필수. 예: ZFIPosting-manage', '', None, 120),
      ('React 앱 이름', 'ReactApp', 'C', '텍스트 120자', 'UI 종류 = R이면 필수', '', None, 120),
      ('URI', 'UiUri', 'C', '텍스트 1333자', 'UI 종류 = R이면 필수, F·W면 선택', '', None, 1333),
      ('모듈', 'SapModule', 'Y', '코드', codes_text('MODULE'), 'FI', 'MODULE', None),
      ('설명', 'Description', '', '텍스트 120자', '매핑 설명', '전표 일괄 전기 로직 클래스 전환', None, 120),
      ('담당자', 'OwnerId', '', '사용자 ID 12자', '비우면 업로드한 사람', 'DEV01', None, 12),
      ('오브젝트 생성자', 'ObjCreator', '', '텍스트 40자', '만든 사람·회사 (외부 개발사도 가능, 자유 입력)', '내부 개발팀', None, 40),
      ('요청번호', 'ReqId', '', 'RQ-nnnn', '관련 요청이 있으면', 'RQ-0003', None, 10),
    ],
    auto=['등록번호 (MP-nnnn) — 저장할 때 채번', '등록자·등록 일시 = 업로드한 사람·시각'],
    notes=['한 줄 = 매핑 한 건 (As-Is 하나 → To-Be 하나)',
           '구분·소스 시스템·As-Is·To-Be가 모두 같은 매핑이 이미 있으면 그 줄은 에러',
           'To-Be 유형이 TCODE가 아니면 UI 칸(UI 종류·앱 ID·Semantic Object-Action·React 앱·URI)은 비운다'],
  ),
  dict(
    file='ZCMSM_업로드_3_ValueHelp.xlsx', tab='Value Help', entity='ValueHelp (ZR_CMSM_Vh)',
    cols=[
      ('VH 이름', 'VhName', 'Y', '대문자 80자', '시스템에 있는 Z…_VH_… CDS 또는 Search Help 이름. 없는 이름은 에러 (개발·활성화 후 등록)', 'ZI_SD_CUSTOMER_VH_01', None, 80),
      ('시스템 ID', 'SysId', '', '시스템 ID 8자', 'VH가 있는 시스템', 'S4D', None, 8),
      ('모듈', 'SapModule', 'Y', '코드', codes_text('MODULE'), 'SD', 'MODULE', None),
      ('설명', 'Description', '', '텍스트 120자', 'VH 설명', '거래처 (영업조직 기준)', None, 120),
      ('담당자', 'OwnerId', '', '사용자 ID 12자', '비우면 업로드한 사람', 'DEV01', None, 12),
      ('오브젝트 생성자', 'ObjCreator', '', '텍스트 40자', '만든 사람·회사 (자유 입력)', '내부 개발팀', None, 40),
      ('요청번호', 'ReqId', '', 'RQ-nnnn', '관련 요청이 있으면', 'RQ-0001', None, 10),
    ],
    auto=['등록번호 (VH-nnnn) — 저장할 때 채번', '구현 방식 (CDS / Search Help) — VH 이름으로 자동 판별',
          '데이터 소스 — 상세 화면에서 VH 정의를 읽어 자동 표시', '테스트 파일 — 화면에서 올린다 (엑셀로는 안 받음)',
          '등록자·등록 일시 = 업로드한 사람·시각'],
    notes=['한 줄 = VH 한 건', '같은 시스템 ID·같은 VH 이름이 이미 있으면 그 줄은 에러'],
  ),
  dict(
    file='ZCMSM_업로드_4_OData서비스.xlsx', tab='OData 서비스', entity='ODataService (ZR_CMSM_Sb)',
    cols=[
      ('Service Binding', 'SrvbName', 'Y', '대문자 80자', '시스템에 있는 Z로 시작하는 서비스 바인딩 이름. 없는 이름은 에러', 'ZUI_SD_SALESORDER_O4', None, 80),
      ('시스템 ID', 'SysId', '', '시스템 ID 8자', '서비스가 있는 시스템', 'S4D', None, 8),
      ('모듈', 'SapModule', 'Y', '코드', codes_text('MODULE'), 'SD', 'MODULE', None),
      ('설명', 'Description', '', '텍스트 120자', '서비스 설명', '수주 관리 (Fiori UI, V4)', None, 120),
      ('담당자', 'OwnerId', '', '사용자 ID 12자', '비우면 업로드한 사람', 'DEV01', None, 12),
      ('오브젝트 생성자', 'ObjCreator', '', '텍스트 40자', '만든 사람·회사 (자유 입력)', '내부 개발팀', None, 40),
      ('요청번호', 'ReqId', '', 'RQ-nnnn', '관련 요청이 있으면', '', None, 10),
    ],
    auto=['등록번호 (SB-nnnn) — 저장할 때 채번', '테스트 파일 — 화면에서 올린다 (엑셀로는 안 받음)',
          '등록자·등록 일시 = 업로드한 사람·시각'],
    notes=['한 줄 = 서비스 바인딩 한 건', '같은 시스템 ID·같은 Service Binding이 이미 있으면 그 줄은 에러'],
  ),
  dict(
    file='ZCMSM_업로드_5_기술부채.xlsx', tab='기술부채', entity='TechDebt (ZR_CMSM_Debt)',
    cols=[
      ('모듈', 'SapModule', 'Y', '코드', codes_text('MODULE'), 'SD', 'MODULE', None),
      ('개발 ID', 'DevId', '', '텍스트 20자', '설계서의 개발 ID', 'SD-I-001', None, 20),
      ('오브젝트 유형', 'ObjType', 'Y', '코드', codes_text('OBJ_TYPE'), 'CLASS', 'OBJ_TYPE', None),
      ('개발 오브젝트', 'DevObj', 'Y', '대문자 80자', '부채가 있는 우리 개발 오브젝트. Action은 BO.ACTION. 시스템에 없으면 에러 (FM·RFC·PROXY는 확인 안 함)', 'ZCL_SD_SALESORDER_API', None, 80),
      ('래핑 여부', 'WrapType', 'C', '코드', 'Debt Level = C면 필수, D면 비운다. ' + codes_text('WRAP_TYPE'), 'W', 'WRAP_TYPE', None),
      ('시스템 ID', 'SysId', '', '시스템 ID 8자', '개발 오브젝트가 있는 시스템', 'S4D', None, 8),
      ('부채 구분', 'DebtCat', '', '코드', '부채 구분 필드를 테이블에 추가한 뒤 사용 (그 전엔 비워 둔다). ' + codes_text('DEBT_CAT'), 'BAPI', 'DEBT_CAT', None),
      ('비released 사용 내역', 'DebtDesc', 'Y', '텍스트 1333자', '쓰고 있는 비released 오브젝트와 쓰는 방식. 여러 개면 쉼표나 줄바꿈(Alt+Enter)으로', 'BAPI_SALESORDER_CREATEFROMDAT2(FM) 래퍼 클래스에서 호출', None, 1333),
      ('Debt Level', 'DebtLevel', 'Y', '코드', codes_text('DEBT_LEVEL'), 'C', 'DEBT_LEVEL', None),
      ('개선상태', 'ImproveStatus', '', '코드', '비우면 T(개선대상). ' + codes_text('IMPROVE'), 'T', 'IMPROVE', None),
      ('판단 사유·개선 계획', 'DebtReason', 'C', '텍스트 1333자', '개선상태 = E(예외등록)면 필수', 'released API(I_SalesOrderTP) 전환 전까지 래퍼로 격리', None, 1333),
      ('업무담당자', 'BizOwner', '', '사용자 ID 12자', '업무 쪽 담당자의 사용자 ID', 'BIZ01', None, 12),
    ],
    auto=['ID (TD-nnn) — 저장할 때 채번', '등록자·등록 일시 = 업로드한 사람·시각'],
    notes=['한 줄 = 개발 오브젝트 하나의 부채. 같은 유형·같은 개발 오브젝트가 이미 있으면 그 줄은 에러 (기존 건의 사용 내역에 추가)',
           'Debt Level을 D로 두면 래핑 여부는 저장할 때 비워진다'],
  ),
]

REQ_TEXT = {'Y': '필수', 'C': '조건부', '': '선택'}
REQ_FILL = {'Y': FILL_REQ, 'C': FILL_COND, '': FILL_OPT}

def build(tab):
    wb = Workbook()
    ws = wb.active
    ws.title = '업로드'
    guide = wb.create_sheet('작성 안내')
    codes = wb.create_sheet('코드값')

    # ---------------- 코드값 시트: 쓰는 코드만 블록으로 (코드 | 내역), 블록 사이 한 칸
    used = []
    for c in tab['cols']:
        if c[6] and c[6] not in used:
            used.append(c[6])
    codes['A1'] = '드롭다운 목록 원본 — 시스템 도메인 고정값과 같아야 합니다. 도메인이 바뀌면 여기 값도 바꾸세요 (목록 길이가 바뀌면 업로드 시트의 데이터 유효성 범위도 같이).'
    codes['A1'].font = f(9, color='595959', italic=True)
    ranges = {}
    col = 1
    for key in used:
        title, items = CODES[key]
        c1, c2 = get_column_letter(col), get_column_letter(col + 1)
        codes[f'{c1}2'] = title
        codes[f'{c1}2'].font = f(10, bold=True)
        codes.merge_cells(f'{c1}2:{c2}2')
        codes[f'{c1}3'], codes[f'{c2}3'] = '코드', '내역'
        for cell in (codes[f'{c1}3'], codes[f'{c2}3']):
            cell.font = f(10, bold=True); cell.fill = FILL_HEAD; cell.border = BORDER
        for i, (code, text) in enumerate(items):
            r = 4 + i
            codes[f'{c1}{r}'], codes[f'{c2}{r}'] = code, text
            for cell in (codes[f'{c1}{r}'], codes[f'{c2}{r}']):
                cell.font = f(10); cell.border = BORDER
            codes[f'{c1}{r}'].number_format = '@'
        ranges[key] = f"'코드값'!${c1}$4:${c1}${3 + len(items)}"
        codes.column_dimensions[c1].width = 10
        codes.column_dimensions[c2].width = max(14, max(len(t) for _, t in items) * 1.6 + 2)
        codes.column_dimensions[get_column_letter(col + 2)].width = 3
        col += 3

    # ---------------- 업로드 시트
    for i, (label, field, req, fmt, rule, ex, code, maxlen) in enumerate(tab['cols'], start=1):
        L = get_column_letter(i)
        h = ws.cell(row=1, column=i, value=label + (' *' if req == 'Y' else (' (*)' if req == 'C' else '')))
        h.font = f(10, bold=True); h.fill = REQ_FILL[req]; h.border = BORDER
        h.alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
        tip = f'[{REQ_TEXT[req]}] {fmt}\n{rule}' + (f'\n예: {ex}' if ex else '')
        h.comment = Comment(tip, '템플릿'); h.comment.width = 320; h.comment.height = 140
        k = ws.cell(row=2, column=i, value=field)
        k.font = f(9, color='7F7F7F'); k.fill = FILL_KEY; k.border = BORDER
        k.alignment = Alignment(horizontal='center')
        # 데이터 칸: 텍스트 서식 (코드·번호가 숫자·날짜로 바뀌지 않게)
        for r in range(FIRST, LAST + 1):
            c = ws.cell(row=r, column=i)
            c.number_format = '@'
            c.font = f(10)
            if maxlen and maxlen >= 1000:
                c.alignment = Alignment(wrap_text=True, vertical='top')
        width = 12
        if maxlen:
            width = 14 if maxlen <= 12 else (30 if maxlen <= 80 else 44)
        if code:
            width = 12
        width = max(width, len(label) * 1.9 + 4)
        ws.column_dimensions[L].width = min(width, 48)
        rng = f'{L}{FIRST}:{L}{LAST}'
        if code:
            dv = DataValidation(type='list', formula1=ranges[code], allow_blank=True, showDropDown=False)
            dv.error = '목록에 있는 코드만 넣을 수 있어요. 코드값 시트를 보세요.'
            dv.errorTitle = '코드 확인'
            dv.prompt = codes_text(code)[:250]
            dv.promptTitle = label
        elif maxlen:
            dv = DataValidation(type='textLength', operator='lessThanOrEqual', formula1=str(maxlen), allow_blank=True)
            dv.error = f'{maxlen}자까지 넣을 수 있어요.'
            dv.errorTitle = '길이 초과'
            dv.prompt = rule[:250]
            dv.promptTitle = label
        else:
            dv = DataValidation(type='textLength', operator='greaterThanOrEqual', formula1='0', allow_blank=True)
            dv.prompt = rule[:250]
            dv.promptTitle = label
        dv.showErrorMessage = True
        dv.showInputMessage = True
        ws.add_data_validation(dv)
        dv.add(rng)
    ws.row_dimensions[1].height = 32
    ws.freeze_panes = 'A3'
    ws['A2'].comment = Comment('2행은 업로드 프로그램이 칸을 찾는 필드명이에요. 지우거나 바꾸지 마세요. 칸 순서는 바꿔도 됩니다.', '템플릿')
    ws.sheet_view.zoomScale = 100

    # ---------------- 작성 안내 시트
    g = guide
    for col_letter, w in zip('ABCDEF', (24, 16, 10, 18, 64, 44)):
        g.column_dimensions[col_letter].width = w
    g['A1'] = f"{tab['tab']} 엑셀 업로드 템플릿"
    g['A1'].font = f(14, bold=True)
    g['A2'] = f"대상: {tab['entity']}  ·  '업로드' 시트를 채워서 {tab['tab']} 탭의 엑셀 업로드로 올립니다."
    g['A2'].font = f(10, color='595959')

    r = 4
    g.cell(row=r, column=1, value='작성 방법').font = f(11, bold=True); r += 1
    steps = ["'업로드' 시트 3행부터 한 줄에 한 건씩 적습니다.",
             '1행 색으로 필수 여부를 봅니다 (아래 범례). 머리글에 마우스를 올리면 칸 설명이 보입니다.',
             '2행(회색 필드명)은 지우거나 바꾸지 않습니다. 업로드 프로그램이 이 이름으로 칸을 찾습니다.',
             '코드 칸은 셀을 누르면 나오는 목록에서 고릅니다. 코드 뜻은 코드값 시트에 있습니다.',
             '등록번호·등록자·일시처럼 저장할 때 채워지는 값은 칸이 없습니다 (아래 목록).',
             f'한 번에 {DATA_ROWS}건까지 넣을 수 있게 서식을 걸어 두었습니다.']
    for i, s in enumerate(steps, 1):
        g.cell(row=r, column=1, value=f'{i}. {s}').font = f(10); r += 1

    r += 1
    g.cell(row=r, column=1, value='색 범례').font = f(11, bold=True); r += 1
    for fill, name, desc in ((FILL_REQ, '필수 *', '꼭 채웁니다'),
                             (FILL_COND, '조건부 (*)', '다른 칸 값에 따라 필수 — 칸 설명의 규칙을 봅니다'),
                             (FILL_OPT, '선택', '비워도 됩니다'),
                             (FILL_KEY, '필드명 (2행)', '수정 금지')):
        a = g.cell(row=r, column=1, value=name); a.fill = fill; a.border = BORDER; a.font = f(10, bold=True)
        g.cell(row=r, column=2, value=desc).font = f(10)
        r += 1

    r += 1
    g.cell(row=r, column=1, value='칸 설명 (예시 열 = 한 건을 채운 예)').font = f(11, bold=True); r += 1
    for i, hname in enumerate(('컬럼', '필드명', '필수', '형식', '규칙·설명', '예시'), start=1):
        c = g.cell(row=r, column=i, value=hname)
        c.font = f(10, bold=True); c.fill = FILL_HEAD; c.border = BORDER
        c.alignment = Alignment(horizontal='center', vertical='center')
    r += 1
    for (label, field, req, fmt, rule, ex, code, maxlen) in tab['cols']:
        vals = (label, field, REQ_TEXT[req], fmt, rule, ex)
        for i, v in enumerate(vals, start=1):
            c = g.cell(row=r, column=i, value=v)
            c.font = f(10, bold=(i == 1)); c.border = BORDER
            c.alignment = Alignment(vertical='top', wrap_text=True)
            c.number_format = '@'
        g.cell(row=r, column=1).fill = REQ_FILL[req]
        r += 1

    r += 1
    g.cell(row=r, column=1, value='저장할 때 자동으로 채워지는 값 (엑셀에 칸 없음)').font = f(11, bold=True); r += 1
    for s in tab['auto']:
        g.cell(row=r, column=1, value='· ' + s).font = f(10); r += 1

    r += 1
    g.cell(row=r, column=1, value='알아 둘 것').font = f(11, bold=True); r += 1
    for s in tab['notes'] + ['에러가 난 줄은 저장되지 않고, 화면에 줄 번호와 이유가 나옵니다 (업로드 기능 구현 기준).']:
        g.cell(row=r, column=1, value='· ' + s).font = f(10); r += 1

    g.sheet_view.showGridLines = False
    wb.active = 0
    path = OUT / tab['file']
    wb.save(path)
    return path

for t in TABS:
    print(build(t))
