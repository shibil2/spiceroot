import 'models/product_model.dart';

class MarketInfo {
  const MarketInfo({required this.markets, required this.arrival});

  final List<String> markets;
  final String arrival;
}

final Map<String, MarketInfo> marketInfoByProductId = {
  'arecanut': const MarketInfo(
    markets: ['Kasaragod APMC', 'Kanhangad Market', 'Payyannur'],
    arrival: '~240 tonnes today',
  ),
  'black_pepper': const MarketInfo(
    markets: ['Sulthan Bathery APMC', 'Kalpetta Spices Hub', 'Mananthavady'],
    arrival: '~85 tonnes today',
  ),
  'cardamom': const MarketInfo(
    markets: ['Kattappana APMC', 'Idukki Cardamom Board', 'Thodupuzha'],
    arrival: '~62 tonnes today',
  ),
  'rubber_rss4': const MarketInfo(
    markets: ['Kottayam Rubber Board', 'Pala Market', 'Changanassery'],
    arrival: '~520 tonnes today',
  ),
  'coconut': const MarketInfo(
    markets: ['Thrissur APMC', 'Guruvayur Market', 'Kodungallur'],
    arrival: '~18,000 nuts today',
  ),
  'ginger_dry': const MarketInfo(
    markets: ['Sulthan Bathery APMC', 'Kalpetta', 'Mananthavady'],
    arrival: '~45 tonnes today',
  ),
  'coffee_robusta': const MarketInfo(
    markets: ['Sulthan Bathery APMC', 'Kalpetta Coffee Hub', 'Mananthavady'],
    arrival: '~120 tonnes today',
  ),
  'nutmeg': const MarketInfo(
    markets: ['Kozhikode Spices Market', 'Feroke APMC', 'Vadakara'],
    arrival: '~28 tonnes today',
  ),
  'cloves': const MarketInfo(
    markets: ['Thrissur APMC', 'Irinjalakuda Market', 'Kodungallur'],
    arrival: '~35 tonnes today',
  ),
  'turmeric': const MarketInfo(
    markets: ['Ernakulam APMC', 'Aluva Market', 'Perumbavoor'],
    arrival: '~95 tonnes today',
  ),
};

MarketInfo marketInfoFor(ProductModel product) {
  return marketInfoByProductId[product.id] ??
      MarketInfo(
        markets: ['${product.district} APMC', 'Kerala State Market'],
        arrival: '~50 tonnes today',
      );
}
