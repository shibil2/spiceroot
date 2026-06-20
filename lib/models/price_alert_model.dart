class PriceAlertModel {
  const PriceAlertModel({
    required this.id,
    required this.productId,
    required this.targetPrice,
    required this.alertAbove,
  });

  final String id;
  final String productId;
  final double targetPrice;
  final bool alertAbove;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'targetPrice': targetPrice,
        'alertAbove': alertAbove,
      };

  factory PriceAlertModel.fromJson(Map<String, dynamic> json) {
    return PriceAlertModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      targetPrice: (json['targetPrice'] as num).toDouble(),
      alertAbove: json['alertAbove'] as bool? ?? true,
    );
  }
}
