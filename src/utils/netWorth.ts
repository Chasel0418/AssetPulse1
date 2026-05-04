import { convert } from '@/services/fxService';
import type { CashBalance, Holding, Liability } from '@/types/asset';

export function calcNetWorth(
  holdings: Holding[],
  cash: CashBalance[],
  liabilities: Liability[],
  base: 'TWD' | 'USD' | 'JPY' | 'HKD'
) {
  const holdingValue = holdings.reduce((sum, h) => {
    const value = (h.lastPrice ?? h.avgCost) * h.quantity;
    return sum + convert(value, h.currency, base);
  }, 0);

  const cashValue = cash.reduce((sum, c) => sum + convert(c.amount, c.currency, base), 0);
  const debtValue = liabilities.reduce((sum, l) => sum + convert(l.amount, l.currency, base), 0);

  return {
    assets: holdingValue + cashValue,
    liabilities: debtValue,
    netWorth: holdingValue + cashValue - debtValue
  };
}
