import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/price_data.dart';
import '../data/models/price_alert_model.dart';
import '../providers/alerts_provider.dart';
import '../providers/price_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(settings.showMalayalam ? 'Alerts | അലേർട്ട്' : 'Alerts'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _showCreateSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer2<AlertsProvider, PriceProvider>(
        builder: (context, alerts, prices, _) {
          if (!alerts.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (alerts.alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  settings.showMalayalam
                      ? 'No price alerts yet.\nTap + to create one.'
                      : 'No price alerts yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.stableColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: alerts.alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final alert = alerts.alerts[index];
              final product = prices.productById(alert.productId);
              final name = product?.nameEn ?? alert.productId;
              final ml = settings.showMalayalam && product != null
                  ? ' (${product.nameMl})'
                  : '';

              return Card(
                color: AppTheme.cardColor,
                child: ListTile(
                  title: Text('$name$ml'),
                  subtitle: Text(
                    '${FormatUtils.price(alert.targetPrice)} · '
                    '${alert.alertAbove ? 'Above target ↑' : 'Below target ↓'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.priceDownColor,
                    ),
                    onPressed: () => alerts.removeAlert(alert.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => const _CreateAlertSheet(),
    );
  }
}

class _CreateAlertSheet extends StatefulWidget {
  const _CreateAlertSheet();

  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  String? _productId;
  final _priceController = TextEditingController();
  bool _alertAbove = true;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New price alert',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Product',
              border: OutlineInputBorder(),
            ),
            initialValue: _productId,
            items: keralaProducts
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.nameEn} (${p.nameMl})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _productId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target price (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alert when price goes ABOVE target'),
            subtitle: Text(
              _alertAbove ? 'Above target' : 'Below target',
              style: const TextStyle(fontSize: 12),
            ),
            value: _alertAbove,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (v) => setState(() => _alertAbove = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: _save,
            child: const Text('Save alert'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final id = _productId;
    final price = double.tryParse(_priceController.text.trim());
    if (id == null || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product and valid price')),
      );
      return;
    }

    final alert = PriceAlertModel(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      productId: id,
      targetPrice: price,
      alertAbove: _alertAbove,
    );

    await context.read<AlertsProvider>().addAlert(alert);
    if (mounted) Navigator.pop(context);
  }
}
