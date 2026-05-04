import React from 'react';
import { View, Text, FlatList } from 'react-native';
import { usePortfolioStore } from '@/store/portfolioStore';

export function HoldingsScreen() {
  const holdings = usePortfolioStore((s) => s.holdings);

  return (
    <View style={{ flex: 1, padding: 20 }}>
      <FlatList
        data={holdings}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={<Text>尚無持倉，請至「匯入」頁面新增。</Text>}
        renderItem={({ item }) => (
          <View style={{ marginBottom: 12 }}>
            <Text>{item.symbol} - {item.name}</Text>
            <Text>{item.quantity} 股 @ {item.avgCost} {item.currency}</Text>
          </View>
        )}
      />
    </View>
  );
}
