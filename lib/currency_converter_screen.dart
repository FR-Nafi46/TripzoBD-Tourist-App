import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amountController = TextEditingController();
  String _fromCurrency = 'USD';
  String _toCurrency   = 'BDT';
  String _result       = '';
  Map<String, double> _rates = {};
  bool _loading = true;

  // App Palette Configuration
  final Color _primaryColor = const Color(0xFF0B2B26);       // Dark Teal
  final Color _secondaryColor = const Color(0xFF8EB69B);     // Soft Sage Green
  final Color _bgBackground = const Color(0xFFF2F0FA);       // White Lilac

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(
        await Supabase.instance.client.from('currency_rates').select(),
      );
      final map = <String, double>{};
      for (final row in rows) {
        map[row['currency'] as String] = (row['rate_to_bdt'] as num).toDouble();
      }
      setState(() {
        _rates = map;
        _loading = false;
      });
    } catch (e) {
      // Fallback to hardcoded rates if Supabase fails
      setState(() {
        _rates = {
          'USD': 110.0,
          'EUR': 120.0,
          'GBP': 140.0,
          'INR':   1.32,
          'SAR':  29.30,
          'BDT':   1.0,
        };
        _loading = false;
      });
    }
  }

  void _convert() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() => _result = 'Enter a valid amount');
      return;
    }
    final inBDT     = amount * (_rates[_fromCurrency] ?? 1.0);
    final converted = inBDT  / (_rates[_toCurrency]   ?? 1.0);
    setState(() {
      _result =
      '$amount $_fromCurrency = ${converted.toStringAsFixed(2)} $_toCurrency';
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: const Text(
          'Currency Converter',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Core Interaction Card Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONVERT CURRENCY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input Textfield
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.payments_outlined, color: _secondaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selection dropdown options row
                  Row(
                    children: [
                      // "From" Currency Dropdown Selector
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _rates.containsKey(_fromCurrency)
                              ? _fromCurrency
                              : _rates.keys.first,
                          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'From',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _primaryColor),
                            ),
                          ),
                          items: _rates.keys
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _fromCurrency = v ?? _fromCurrency),
                        ),
                      ),

                      // Middle Swap Interaction Button Wrapper
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _secondaryColor.withOpacity(0.15),
                          child: IconButton(
                            onPressed: () => setState(() {
                              final temp = _fromCurrency;
                              _fromCurrency = _toCurrency;
                              _toCurrency   = temp;
                              _result = '';
                            }),
                            icon: const Icon(Icons.swap_horiz),
                            color: _primaryColor,
                            iconSize: 22,
                          ),
                        ),
                      ),

                      // "To" Currency Dropdown Selector
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _rates.containsKey(_toCurrency)
                              ? _toCurrency
                              : _rates.keys.first,
                          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'To',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _primaryColor),
                            ),
                          ),
                          items: _rates.keys
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _toCurrency = v ?? _toCurrency),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Execution conversion action button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _convert,
                      child: const Text(
                        'Convert Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Unified Result UI Showcase Container
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: _secondaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'CONVERSION RESULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _result,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}