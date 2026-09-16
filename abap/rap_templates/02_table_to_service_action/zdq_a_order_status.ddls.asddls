@EndUserText.label: 'Case2: 주문상태 변경 액션 파라미터'
define abstract entity ZDQ_A_ORDER_STATUS
{
      @EndUserText.label: '주문상태 (01:작성중 02:릴리즈 03:종결)'
      OrderStatus : abap.char(2);
}
