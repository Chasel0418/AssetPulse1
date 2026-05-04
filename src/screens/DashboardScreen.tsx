import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { usePortfolioStore } from '@/store/portfolioStore';
import { calcNetWorth } from '@/utils/netWorth';

export function DashboardScreen() {
  const { holdings, cash, liabilities, baseCurrency } = usePortfolioStore();
  const data = calcNetWorth(holdings, cash, liabilities, baseCurrency);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>資產脈動</Text>
      <Text>基準幣別：{baseCurrency}</Text>
      <Text>總資產：{data.assets.toFixed(2)}</Text>
      <Text>總負債：{data.liabilities.toFixed(2)}</Text>
      <Text style={styles.net}>淨值：{data.netWorth.toFixed(2)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20, gap: 8 },
  title: { fontSize: 22, fontWeight: '700' },
  net: { fontSize: 20, fontWeight: '700', marginTop: 10 }
});
