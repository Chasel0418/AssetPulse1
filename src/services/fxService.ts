const demoRates: Record<string, number> = {
  USD_TWD: 32.1,
  JPY_TWD: 0.21,
  HKD_TWD: 4.1,
  TWD_TWD: 1
};

export function convert(amount: number, from: 'TWD' | 'USD' | 'JPY' | 'HKD', to: 'TWD' | 'USD' | 'JPY' | 'HKD') {
  if (from === to) return amount;
  const twd = amount * (demoRates[`${from}_TWD`] ?? 1);
  if (to === 'TWD') return twd;
  return twd / (demoRates[`${to}_TWD`] ?? 1);
}
