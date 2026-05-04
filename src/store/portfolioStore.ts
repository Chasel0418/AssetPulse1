import { create } from 'zustand';
import type { CashBalance, Holding, Liability } from '@/types/asset';

interface PortfolioState {
  baseCurrency: 'TWD' | 'USD' | 'JPY' | 'HKD';
  holdings: Holding[];
  cash: CashBalance[];
  liabilities: Liability[];
  setHoldings: (items: Holding[]) => void;
}

export const usePortfolioStore = create<PortfolioState>((set) => ({
  baseCurrency: 'TWD',
  holdings: [],
  cash: [],
  liabilities: [],
  setHoldings: (items) => set({ holdings: items })
}));
