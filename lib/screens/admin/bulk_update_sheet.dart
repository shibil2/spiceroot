import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/product_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class BulkUpdateSheet extends StatefulWidget {
  const BulkUpdateSheet({
    super.key,
    required this.products,
    required this.firestore,
    required this.updatedBy,
  });

  final List<ProductModel> products;
  final FirestoreService firestore;
  final String updatedBy;

  @override
  State<BulkUpdateSheet> createState() => _BulkUpdateSheetState();
}

class _BulkUpdateSheetState extends State<BulkUpdateSheet> {
  late final Map<String, TextEditingController> _controllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final p in widget.products)
        p.id: TextEditingController(
          text: p.currentPrice == p.currentPrice.roundToDouble()
              ? p.currentPrice.toInt().toString()
              : p.currentPrice.toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    final updates = <String, double>{};
    for (final p in widget.products) {
      final v = double.tryParse(_controllers[p.id]!.text.trim());
      if (v == null || v <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid price for ${p.nameEn}'),
            backgroundColor: AppTheme.priceDownColor,
          ),
        );
        return;
      }
      updates[p.id] = v;
    }

    setState(() => _isSaving = true);
    try {
      await widget.firestore.batchUpdatePrices(
        updates,
        updatedBy: widget.updatedBy,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch update failed: $e'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bulk Update Prices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = widget.products[index];
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.nameEn,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controllers[p.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '₹',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: _isSaving ? null : _saveAll,
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save All',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
