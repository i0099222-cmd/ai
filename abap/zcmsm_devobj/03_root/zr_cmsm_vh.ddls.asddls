@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help (BO 루트)'
define root view entity ZR_CMSM_Vh
  as select from ZI_CMSM_Vh
  composition [0..*] of ZR_CMSM_VhSrc as _Src
{
  key VhUuid,
      VhId,
      VhName,
      VhImpl,
      SysId,
      SapModule,
      Description,
      OwnerId,
      ObjCreator,
      ReqId,
      @Semantics.largeObject: { mimeType: 'TestMimeType',
                                fileName: 'TestFileName',
                                contentDispositionPreference: #ATTACHMENT }
      TestFile,
      @Semantics.mimeType: true
      TestMimeType,
      TestFileName,
      TestBy,
      TestAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      _Src,
      _VhImpl,
      _Sys,
      _SapModule,
      _Owner,
      _Request,
      _TestBy
}
