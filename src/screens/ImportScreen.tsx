import React from 'react';
import { View, Text, Button, Alert } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { parseBrokerScreenshot } from '@/services/importService';
import { usePortfolioStore } from '@/store/portfolioStore';

export function ImportScreen() {
  const setHoldings = usePortfolioStore((s) => s.setHoldings);

  const handleImport = async () => {
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 1
    });

    if (res.canceled || !res.assets[0]?.uri) return;
    const holdings = await parseBrokerScreenshot(res.assets[0].uri);
    setHoldings(holdings);
    Alert.alert('匯入成功', `已匯入 ${holdings.length} 筆持倉`);
  };

  return (
    <View style={{ flex: 1, padding: 20, gap: 12 }}>
      <Text>匯入券商截圖（Firstrade / IB / 國泰等）</Text>
      <Button title="選擇截圖並匯入" onPress={handleImport} />
    </View>
  );
}
