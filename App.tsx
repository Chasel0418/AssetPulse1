import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { DashboardScreen } from './src/screens/DashboardScreen';
import { HoldingsScreen } from './src/screens/HoldingsScreen';
import { ImportScreen } from './src/screens/ImportScreen';

const Tab = createBottomTabNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <Tab.Navigator>
        <Tab.Screen name="總覽" component={DashboardScreen} />
        <Tab.Screen name="持倉" component={HoldingsScreen} />
        <Tab.Screen name="匯入" component={ImportScreen} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
