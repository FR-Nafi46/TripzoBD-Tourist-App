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
      appBar: AppBar(title: const Text('Currency Converter')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _rates.containsKey(_fromCurrency)
                              ? _fromCurrency
                              : _rates.keys.first,
                          decoration: const InputDecoration(
                            labelText: 'From',
                            border: OutlineInputBorder(),
                          ),
                          items: _rates.keys
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _fromCurrency = v ?? _fromCurrency),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Swap button
                      IconButton(
                        onPressed: () => setState(() {
                          final temp = _fromCurrency;
                          _fromCurrency = _toCurrency;
                          _toCurrency   = temp;
                          _result = '';
                        }),
                        icon: const Icon(Icons.swap_horiz),
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _rates.containsKey(_toCurrency)
                              ? _toCurrency
                              : _rates.keys.first,
                          decoration: const InputDecoration(
                            labelText: 'To',
                            border: OutlineInputBorder(),
                          ),
                          items: _rates.keys
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _toCurrency = v ?? _toCurrency),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _convert,
                      child: const Text('Convert',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_result.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _result,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}