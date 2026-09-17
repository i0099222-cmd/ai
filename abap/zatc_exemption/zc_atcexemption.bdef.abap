projection;
strict ( 2 );
use draft;

define behavior for ZC_AtcExemption alias Exemption
{
  use create;
  use update;
  use delete;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;

  use action submit;
  use action withdraw;
  use action approve;
  use action reject;
  use action revoke;
  use action extendValidity;
  use action simulateImpact;

  use action createFromFinding;

  use association _Item { create; with draft; }
  use association _Log  { with draft; }
}

define behavior for ZC_AtcExemptionItem alias ExemptionItem
{
  use update;
  use delete;

  use association _Exemption { with draft; }
}

define behavior for ZC_AtcExemptionLog alias ExemptionLog
{
  use association _Exemption { with draft; }
}
