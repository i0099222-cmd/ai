@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Check Message Code Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #C,
  sizeCategory: #M,
  dataClass: #MIXED
}
@Search.searchable: true
// 대상 줄의 Check Message Code 값 도움. 모든 체크(표준·네이밍)의 메시지 코드를 체크 클래스와
// 메시지 제목과 함께 한 줄씩 보여 준다. 줄에 체크 클래스가 있으면 그 체크의 코드만 나온다.
//
// ATC 결과(ZI_AtcFinding)에서 만든다. 그래서 최근 실행 결과에 한 번이라도 나온 코드만 있다.
// 아직 위반이 난 적 없는 코드로 미리 신청하려면 코드를 직접 입력한다.
// 예전에는 네이밍 규칙 테이블(ZTATCNAMING)에서 만들어 네이밍 체크 코드만 나왔다.
define view entity ZI_AtcCheckCodeVH
  as select from ZI_AtcFinding
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Class'
  key CheckClass,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Message Code'
  key CheckCode,

      // 같은 코드라도 결과마다 제목이 조금 다를 수 있어 하나만 고른다.
      @EndUserText.label: 'Message'
      max( MessageText ) as MessageText
}
group by CheckClass,
         CheckCode
