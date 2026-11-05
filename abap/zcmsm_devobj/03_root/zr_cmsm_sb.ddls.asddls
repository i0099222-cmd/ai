@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData 서비스 (BO 루트)'
define root view entity ZR_CMSM_Sb
  as select from ZI_CMSM_Sb
{
  key SbUuid,
      SbId,
      SrvbName,
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

      _Sys,
      _SapModule,
      _Owner,
      _Request,
      _TestBy
}
