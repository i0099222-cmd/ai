@EndUserText.label: 'Pre-Register Target'
// ZD_AtcPreRegister 의 대상 행.
//   PCKG : ObjectName 에 패키지를 넣는다. ObjectType 은 보지 않는다.
//   OBJ  : ObjectType + ObjectName (TADIR R3TR). 패키지는 TADIR 에서 파생한다.
define abstract entity ZD_AtcPreRegisterTgt
{
  @EndUserText.label: 'Object Type'
  ObjectType   : trobjtype;

  @EndUserText.label: 'Object / Package Name'
  ObjectName   : sobj_name;

  _PreRegister : association to parent ZD_AtcPreRegister;
}
