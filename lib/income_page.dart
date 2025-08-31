import 'package:flutter/material.dart';
import 'sembast_helper.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  List<Map<String, dynamic>> _incomes = [];
  List<Map<String, dynamic>> _expenses = []; // To hold expense data
  final ScrollController _scrollController = ScrollController();
  String _selectedCurrencySymbol = '৳'; // Changed for BDT
  String _selectedCurrencyCode = 'BDT';
  String? _selectedFilterCurrency;
  double _totalExpense = 0.0;
  double _totalIncome = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCurrency();
    await _loadIncomes();
    await _loadExpenses(); // Also load expenses

  }

  void _calculateTotals() {
    double incomeTotal = 0.0;
    for (var income in _incomes) {
      if (income['currency'] == _selectedCurrencyCode) {
        incomeTotal += (income['amount'] as num).toDouble();
      }
    }

    double expenseTotal = 0.0;
    for (var expense in _expenses) {
      if (expense['currency'] == _selectedCurrencyCode) {
        expenseTotal += (expense['amount'] as num).toDouble();
      }
    }

    if (mounted) {
      setState(() {
        _totalIncome = incomeTotal;
        _totalExpense = expenseTotal;
      });
    }
  }

  Future<void> _loadCurrency() async {
    final currencyCode = await SembastHelper.instance
        .getSettings('currencyCode', defaultValue: 'BDT');
    final currency = CurrencyService().findByCode(currencyCode);
    if (mounted && currency != null) {
      setState(() {
        _selectedCurrencyCode = currency.code;
        _selectedCurrencySymbol = currency.symbol;
      });
    }
  }

  Future<void> _loadIncomes() async {
    final records = await SembastHelper.instance.getIncomes();
    if (mounted) {
      setState(() {
        _incomes = records
            .map((e) => {'id': e.key, ...e.value as Map<String, dynamic>})
            .toList()
            .reversed
            .toList();
        _calculateTotals();
      });
    }
  }

  Future<void> _loadExpenses() async {
    final records = await SembastHelper.instance.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = records
            .map((e) => {'id': e.key, ...e.value as Map<String, dynamic>})
            .toList()
            .reversed
            .toList();
        _calculateTotals();
      });
    }
  }


  Future<void> _showIncomeDialog({Map<String, dynamic>? income}) async {
    final amountController =
    TextEditingController(text: income?['amount']?.toStringAsFixed(2) ?? '');
    final noteController = TextEditingController(text: income?['note'] ?? '');
    DateTime selectedDate =
    income != null ? DateTime.parse(income['date']) : DateTime.now();

    Currency dialogCurrency =
        CurrencyService().findByCode(income?['currency'] ?? _selectedCurrencyCode) ??
            CurrencyService().findByCode('BDT')!;
    List<Currency> availableCurrencies = CurrencyService().getAll();
    String? selectedCurrencyCode = dialogCurrency.code;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sfbContext, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 10),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(income == null ? 'Add Income' : 'Edit Income'),
              if (income != null)
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Delete Income',
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    if (income['id'] != null) {
                      _confirmDelete(income['id'] as int);
                    }
                  },
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Amount',
                          border: UnderlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedCurrencyCode,
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setDialogState(() {
                            selectedCurrencyCode = newValue;
                            dialogCurrency =
                            CurrencyService().findByCode(newValue)!;
                          });
                        }
                      },
                      items: availableCurrencies
                          .map((currency) => DropdownMenuItem<String>(
                        value: currency.code,
                        child: Text(currency.symbol),
                      ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Date: '),
                    Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        if (!mounted) return;
                        final date = await showDatePicker(
                          context: sfbContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                final note = noteController.text.trim();
                if (amount != null) {
                  final data = {
                    'amount': double.parse(amount.toStringAsFixed(2)),
                    'note': note,
                    'date': selectedDate.toIso8601String(),
                    'currency': selectedCurrencyCode,
                  };
                  if (income == null) {
                    await SembastHelper.instance.addIncome(data);
                  } else {
                    await SembastHelper.instance
                        .updateIncome(income['id'], data);
                  }
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadIncomes(); // This will trigger a total recalculation

                  if (income == null) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                        Text('Please fill all required fields.')),
                  );
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete the income?'),
        actions: [
          TextButton(
            child: const Text(
              'Yes',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
          TextButton(
            child: const Text(
              'No',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SembastHelper.instance.deleteIncome(id);
      _loadIncomes(); // This will trigger a total recalculation

    }
  }

  Widget _buildCurrencyFilter() {
    final uniqueCurrencies = _incomes
        .map((e) => e['currency'] as String? ?? _selectedCurrencyCode)
        .toSet()
        .toList()
      ..sort();

    const maxDirectDisplay = 3;
    final displayCurrencies = uniqueCurrencies.take(maxDirectDisplay).toList();
    final otherCurrencies =
    uniqueCurrencies.skip(maxDirectDisplay).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterButton('All', null),
            ...displayCurrencies.map((currencyCode) {
              final currency = CurrencyService().findByCode(currencyCode);
              return _buildFilterButton(currency?.code ?? currencyCode, currencyCode);
            }),
            if (otherCurrencies.isNotEmpty)
              DropdownButton<String>(
                value: null,
                underline: Container(), // Hides the default underline
                hint: const Text('Others'),
                items: otherCurrencies.map((currencyCode) {
                  final currency = CurrencyService().findByCode(currencyCode);
                  return DropdownMenuItem<String>(
                    value: currencyCode,
                    child: Text(currency?.code ?? currencyCode),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFilterCurrency = newValue;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String text, String? currencyCode) {
    final bool isSelected = _selectedFilterCurrency == currencyCode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterCurrency = currencyCode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredIncomes = _selectedFilterCurrency == null
        ? _incomes
        : _incomes
        .where((e) => e['currency'] == _selectedFilterCurrency)
        .toList();

    final Map<String, Map<String, double>> dailyTotalsByCurrency = {};
    final Map<String, List<Map<String, dynamic>>> groupedIncomes = {};

    for (var income in filteredIncomes) {
      final dateString =
      DateFormat('yyyy-MM-dd').format(DateTime.parse(income['date']));
      final currencyCode = income['currency'] as String? ?? _selectedCurrencyCode;
      if (!groupedIncomes.containsKey(dateString)) {
        groupedIncomes[dateString] = [];
      }
      groupedIncomes[dateString]!.add(income);
      if (!dailyTotalsByCurrency.containsKey(dateString)) {
        dailyTotalsByCurrency[dateString] = {};
      }
      dailyTotalsByCurrency[dateString]![currencyCode] =
          (dailyTotalsByCurrency[dateString]![currencyCode] ?? 0) +
              (income['amount'] as num).toDouble();
    }

    final List<String> sortedDates = groupedIncomes.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Mama',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24.0,
            fontWeight: FontWeight.w800,),),

      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense:',
                            style: TextStyle(color: Colors.white, fontSize: 16.0),
                          ),
                          Text(
                            '$_selectedCurrencySymbol${_totalExpense.toStringAsFixed(2)}', // Corrected to 2 decimal places
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Income:',
                            style: TextStyle(color: Colors.white, fontSize: 16.0),
                          ),
                          Text(
                            '$_selectedCurrencySymbol${_totalIncome.toStringAsFixed(2)}', // Corrected to 2 decimal places
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_incomes.isNotEmpty) _buildCurrencyFilter(),
          Expanded(
            child: filteredIncomes.isEmpty
                ? Center(
                child: Text(
                    'No incomes found for ${_selectedFilterCurrency ?? "this filter"}'))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final List<Map<String, dynamic>> incomesForDate =
                groupedIncomes[date]!;
                final Map<String, double> totalsForDate =
                dailyTotalsByCurrency[date]!;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  elevation: 0.4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy')
                                  .format(DateTime.parse(date)),
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                totalsForDate.entries.map((entry) {
                                  final currencySymbol = CurrencyService()
                                      .findByCode(entry.key)
                                      ?.symbol ??
                                      '\$';
                                  return '$currencySymbol${entry.value.toStringAsFixed(2)}'; // Corrected to 2 decimal places
                                }).join(', '),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(height: 1, color: Colors.blueGrey.shade100),
                        ...incomesForDate.map((income) {
                          final double amount =
                          (income['amount'] as num).toDouble();
                          final String note = income['note'] as String? ?? '';
                          final String incomeCurrencyCode =
                              income['currency'] ?? _selectedCurrencyCode;
                          final Currency? incomeCurrency =
                          CurrencyService().findByCode(incomeCurrencyCode);
                          final String incomeCurrencySymbol =
                              incomeCurrency?.symbol ?? _selectedCurrencySymbol;

                          return GestureDetector(
                            onTap: () => _showIncomeDialog(income: income),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Income',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (note.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(
                                            note,
                                            style: TextStyle(
                                              fontSize: 14.0,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '+$incomeCurrencySymbol${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIncomeDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
