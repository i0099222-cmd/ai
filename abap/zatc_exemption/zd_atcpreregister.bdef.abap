// preRegister 의 deep parameter. 헤더 1행 + 대상 여러 행.
abstract;
strict ( 2 );
with hierarchy;

define behavior for ZD_AtcPreRegister alias PreRegister
{
  association _Targets;
}

define behavior for ZD_AtcPreRegisterTgt alias Target
{
}
