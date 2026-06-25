import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/admin_config.dart';
import '../../data/models/product_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/admin_product_tile.dart';
import 'bulk_update_sheet.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestore = FirestoreService();
  final _messageController = TextEditingController();
  bool _isPublishing = false;
  bool _messagePrefilled = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showPriceUpdatedSnackBar(String name, double price) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name price updated to ${FormatUtils.price(price)} ✓'),
        backgroundColor: AppTheme.priceUpColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onPriceUpdated(
    ProductModel product,
    double oldPrice,
    double newPrice,
  ) async {
    _showPriceUpdatedSnackBar(product.nameEn, newPrice);

    final changePct = oldPrice == 0
        ? 0.0
        : ((newPrice - oldPrice) / oldPrice * 100).abs();
    if (changePct <= 5) return;

    final updatedBy = context.read<AuthService>().currentUser?.email ?? 'admin';

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send push notification?'),
        content: Text(
          'Price moved significantly (${changePct.toStringAsFixed(1)}%). '
          'Send push notification to all users?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (send != true || !mounted) return;

    try {
      await _firestore.queuePriceChangeNotification(
        productId: product.id,
        productName: product.nameEn,
        oldPrice: oldPrice,
        newPrice: newPrice,
        updatedBy: updatedBy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Push notification queued for all users ✓'),
          backgroundColor: AppTheme.priceUpColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to queue notification: $e'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
    }
  }

  Future<void> _publishMessage(String updatedBy) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a market message'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      await _firestore.publishMarketMessage(
        message: text,
        updatedBy: updatedBy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Market message published ✓'),
          backgroundColor: AppTheme.priceUpColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publish failed: $e'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _openBulkUpdate(String updatedBy, List<ProductModel> products) {
    if (products.isEmpty) return;

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: BulkUpdateSheet(
            products: products,
            firestore: _firestore,
            updatedBy: updatedBy,
          ),
        ),
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All prices updated ✓'),
            backgroundColor: AppTheme.priceUpColor,
          ),
        );
      }
    });
  }

  void _prefillMessage(AdminConfig? config) {
    if (_messagePrefilled || config == null) return;
    if (config.marketMessage.isNotEmpty) {
      _messageController.text = config.marketMessage;
      _messagePrefilled = true;
    }
  }

  String _formatLastUpdated(AdminConfig? config) {
    if (config?.lastUpdated == null) {
      return 'Last updated: not yet recorded';
    }
    final when = DateFormat('d MMMM yyyy, h:mm a').format(config!.lastUpdated!);
    final by = config.updatedBy.isNotEmpty ? config.updatedBy : 'admin';
    return 'Last updated: $when by $by';
  }

  @override
  Widget build(BuildContext context) {
    final updatedBy = context.read<AuthService>().currentUser?.email ?? 'admin';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Update Today\'s Prices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<ProductModel>>(
        stream: _firestore.productsStream(),
        builder: (context, snap) {
          final products = snap.data ?? [];
          return FloatingActionButton.extended(
            onPressed: products.isEmpty
                ? null
                : () => _openBulkUpdate(updatedBy, products),
            icon: const Icon(Icons.edit_note),
            label: const Text('Bulk Update'),
            backgroundColor: AppTheme.primaryColor,
          );
        },
      ),
      body: StreamBuilder<AdminConfig?>(
        stream: _firestore.adminConfigStream(),
        builder: (context, configSnap) {
          final config = configSnap.data;
          _prefillMessage(config);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  color: AppTheme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _formatLastUpdated(config),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.stableColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ProductModel>>(
                  stream: _firestore.productsStream(),
                  builder: (context, productsSnap) {
                    if (productsSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      );
                    }

                    if (productsSnap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: ${productsSnap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.priceDownColor,
                            ),
                          ),
                        ),
                      );
                    }

                    final products = productsSnap.data ?? [];

                    if (products.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products in Firestore.\nRun seedDatabase() first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.stableColor),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return AdminProductTile(
                          key: ValueKey(
                            '${product.id}_${product.currentPrice}',
                          ),
                          product: product,
                          firestore: _firestore,
                          updatedBy: updatedBy,
                          onPriceUpdated: _onPriceUpdated,
                        );
                      },
                    );
                  },
                ),
              ),
              _MarketMessageSection(
                controller: _messageController,
                isPublishing: _isPublishing,
                onPublish: () => _publishMessage(updatedBy),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarketMessageSection extends StatelessWidget {
  const _MarketMessageSection({
    required this.controller,
    required this.isPublishing,
    required this.onPublish,
  });

  final TextEditingController controller;
  final bool isPublishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Publish Market Message',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText:
                  'e.g. Heavy arrivals at Mangaluru APMC, pepper prices may fall',
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: isPublishing ? null : onPublish,
              child: isPublishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
    );
  }
}
