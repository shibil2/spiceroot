import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class AdminProductTile extends StatefulWidget {
  const AdminProductTile({
    super.key,
    required this.product,
    required this.firestore,
    required this.onPriceUpdated,
    this.updatedBy,
  });

  final ProductModel product;
  final FirestoreService firestore;
  final void Function(ProductModel product, double oldPrice, double newPrice)
      onPriceUpdated;
  final String? updatedBy;

  @override
  State<AdminProductTile> createState() => _AdminProductTileState();
}

class _AdminProductTileState extends State<AdminProductTile> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _priceController;

  ProductModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: _formatInput(product.currentPrice),
    );
  }

  @override
  void didUpdateWidget(AdminProductTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.product.currentPrice != product.currentPrice) {
      _priceController.text = _formatInput(product.currentPrice);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _formatInput(double price) {
    if (price == price.roundToDouble()) return price.toInt().toString();
    return price.toString();
  }

  void _startEdit() {
    _priceController.text = _formatInput(product.currentPrice);
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    _priceController.text = _formatInput(product.currentPrice);
    setState(() => _isEditing = false);
  }

  Future<void> _save() async {
    final newPrice = double.tryParse(_priceController.text.trim());
    if (newPrice == null || newPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid price'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final oldPrice = product.currentPrice;
    try {
      await widget.firestore.updatePrice(
        product.id,
        newPrice,
        updatedBy: widget.updatedBy,
      );
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      widget.onPriceUpdated(product, oldPrice, newPrice);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.priceDownColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameEn,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    product.nameMl,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.stableColor,
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing) ...[
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '₹',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _isSaving ? null : _save(),
                ),
              ),
              const SizedBox(width: 4),
              _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: AppTheme.priceUpColor,
                      ),
                      tooltip: 'Save',
                      onPressed: _save,
                    ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _isSaving ? null : _cancelEdit,
              ),
            ] else ...[
              Text(
                FormatUtils.price(product.currentPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: AppTheme.primaryColor,
                tooltip: 'Edit price',
                onPressed: _startEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
