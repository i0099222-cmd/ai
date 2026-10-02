@EndUserText.label: 'Pre-Register Package'
// ZD_AtcPreRegister 의 패키지 행.
define abstract entity ZD_AtcPreRegisterPkg
{
  @EndUserText.label: 'Package'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcPackageVH', element: 'Devclass' }
  }]
  Devclass     : devclass;

  _PreRegister : association to parent ZD_AtcPreRegister;
}
