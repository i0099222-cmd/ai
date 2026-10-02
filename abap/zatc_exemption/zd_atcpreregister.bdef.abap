// preRegisterPackages 의 deep parameter. 헤더 1행 + 패키지 여러 행.
abstract;
strict ( 2 );
with hierarchy;

define behavior for ZD_AtcPreRegister alias PreRegister
{
  association _Packages;
}

define behavior for ZD_AtcPreRegisterPkg alias Package
{
}
