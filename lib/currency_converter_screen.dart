import 'package:flutter/material.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _fromCurrency = 'USD';
  String _toCurrency = 'BDT';
  String _result = '';

  // Simple hardcoded rates for demonstration (replace with API/database later)
  final Map<String, double> _rates = {
    'USD': 110.0,
    'EUR': 120.0,
    'BDT': 1.0,
  };

  void _convert() {
    double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() => _result = 'Enter valid amount');
      return;
    }
    double usdValue = amount / (_rates[_fromCurrency] ?? 1);
    double converted = usdValue * (_rates[_toCurrency] ?? 1);
    setState(() {
      _result = '$amount $_fromCurrency = ${converted.toStringAsFixed(2)} $_toCurrency';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _fromCurrency,
                    decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
                    items: _rates.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _fromCurrency = val ?? _fromCurrency),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _toCurrency,
                    decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
                    items: _rates.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _toCurrency = val ?? _toCurrency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _convert, child: const Text('Convert')),
            const SizedBox(height: 20),
            Text(_result, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}