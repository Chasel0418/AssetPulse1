export type Market = 'US' | 'TW' | 'JP' | 'HK';

export interface Holding {
  id: string;
  broker: string;
  market: Market;
  symbol: string;
  name: string;
  quantity: number;
  avgCost: number;
  currency: 'TWD' | 'USD' | 'JPY' | 'HKD';
  lastPrice?: number;
}

export interface CashBalance {
  currency: 'TWD' | 'USD' | 'JPY' | 'HKD';
  amount: number;
  bank: string;
}

export interface Liability {
  id: string;
  name: string;
  currency: 'TWD' | 'USD' | 'JPY' | 'HKD';
  amount: number;
}
