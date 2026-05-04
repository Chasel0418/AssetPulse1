import type { Holding } from '@/types/asset';

/**
 * 券商截圖匯入（MVP）
 * 實務上流程：圖片前處理 -> OCR -> Broker 模板解析 -> 欄位標準化
 */
export async function parseBrokerScreenshot(_: string): Promise<Holding[]> {
  // TODO: 串接 OCR SDK/API
  return [
    {
      id: 'demo-1',
      broker: 'Firstrade',
      market: 'US',
      symbol: 'AAPL',
      name: 'Apple Inc.',
      quantity: 10,
      avgCost: 180,
      currency: 'USD',
      lastPrice: 192.5
    }
  ];
}
