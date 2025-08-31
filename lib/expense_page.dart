import 'package:flutter/material.dart';
import 'sembast_helper.dart';
import 'package:intl/intl.dart';
import 'settings_page.dart';
import 'package:currency_picker/currency_picker.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _incomes = []; // To hold income data
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _categories = [];
  String _selectedCurrencySymbol = '৳'; // Changed for BDT
  String _selectedCurrencyCode = 'BDT';
  String? _selectedFilterCurrency; // Null for 'ALL'
  double _totalExpense = 0.0;
  double _totalIncome = 0.0; // Changed to be updatable

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCurrency();
    await _loadExpenses();
    await _loadIncomes(); // Also load incomes
    await _loadCategories();
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

  Future<void> _loadExpenses() async {
    final records = await SembastHelper.instance.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = records
            .map((e) => {'id': e.key, ...e.value})
            .toList()
            .reversed
            .toList();
        _calculateTotals();
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

  void _calculateTotals() {
    double expenseTotal = 0.0;
    for (var expense in _expenses) {
      if (expense['currency'] == _selectedCurrencyCode) {
        expenseTotal += (expense['amount'] as num).toDouble();
      }
    }

    double incomeTotal = 0.0;
    for (var income in _incomes) {
      if (income['currency'] == _selectedCurrencyCode) {
        incomeTotal += (income['amount'] as num).toDouble();
      }
    }

    if (mounted) {
      setState(() {
        _totalExpense = expenseTotal;
        _totalIncome = incomeTotal;
      });
    }
  }

  Future<void> _loadCategories() async {
    final categoriesFromDb = await SembastHelper.instance.getCategories();
    if (mounted) {
      setState(() {
        _categories = categoriesFromDb;
      });
    }
  }

// Add expense popup
  Future<void> _showExpenseDialog({Map<String, dynamic>? expense}) async {
    // Always load initial data at the start to get the latest categories
    await _loadInitialData();

    String? selectedCategory = expense?['category'];

    // This list will be used to build the DropdownButtonFormField items.
    // We re-create it every time the dialog is shown.
    List<Map<String, dynamic>> currentDialogCategories = List.from(_categories);
    final doesCategoryExist =
    _categories.any((category) => category['name'] == selectedCategory);
    if (selectedCategory != null && !doesCategoryExist) {
      currentDialogCategories.add({'name': selectedCategory});
    }
    if (expense == null && _categories.isNotEmpty) {
      selectedCategory = _categories.first['name'] as String?;
    }

    final amountController =
    TextEditingController(text: expense?['amount']?.toStringAsFixed(2) ?? '');
    final noteController = TextEditingController(text: expense?['note'] ?? '');
    DateTime selectedDate =
    expense != null ? DateTime.parse(expense['date']) : DateTime.now();

    Currency dialogCurrency =
        CurrencyService().findByCode(expense?['currency'] ?? _selectedCurrencyCode) ??
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
              Text(expense == null ? 'Add Expense' : 'Edit Expense'),
              if (expense != null)
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Delete Expense',
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    if (expense['id'] != null) {
                      _confirmDelete(expense['id'] as int);
                    }
                  },
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // This is the key part: The items are always built from the fresh list.
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: currentDialogCategories
                      .map((category) => DropdownMenuItem<String>(
                    value: category['name'] as String,
                    child: Text(category['name'] as String),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value);
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                  hint: currentDialogCategories.isEmpty
                      ? const Text("No categories")
                      : null,
                ),
                const SizedBox(height: 10),
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
                if (amount != null && selectedCategory != null) {
                  final data = {
                    'category': selectedCategory,
                    'amount': double.parse(amount.toStringAsFixed(2)),
                    'note': note,
                    'date': selectedDate.toIso8601String(),
                    'currency': selectedCurrencyCode,
                  };
                  if (expense == null) {
                    await SembastHelper.instance.addExpense(data);
                  } else {
                    await SembastHelper.instance
                        .updateExpense(expense['id'], data);
                  }
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadExpenses();
                  if (expense == null) {
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
                        Text('Please fill all required fields and select a category.')),
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
        content: const Text('Are you sure you want to delete the expanse?'),
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
      await SembastHelper.instance.deleteExpense(id);
      _loadExpenses();
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onCategoriesUpdated: () {
            _loadCategories();
            _loadExpenses();
          },
        ),
      ),
    );
    if (!mounted) return;
    await _loadCategories();
    await _loadCurrency();
    await _loadExpenses(); // Re-load expenses to reflect any changes
  }

  Widget _buildCurrencyFilter() {
    final uniqueCurrencies = _expenses
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
    // Filter expenses based on the selected currency
    final filteredExpenses = _selectedFilterCurrency == null
        ? _expenses
        : _expenses
        .where((e) => e['currency'] == _selectedFilterCurrency)
        .toList();

    final Map<String, Map<String, double>> dailyTotalsByCurrency = {};
    final Map<String, List<Map<String, dynamic>>> groupedExpenses = {};

    for (var expense in filteredExpenses) {
      final dateString =
      DateFormat('yyyy-MM-dd').format(DateTime.parse(expense['date']));
      final currencyCode = expense['currency'] as String? ?? _selectedCurrencyCode;
      if (!groupedExpenses.containsKey(dateString)) {
        groupedExpenses[dateString] = [];
      }
      groupedExpenses[dateString]!.add(expense);
      if (!dailyTotalsByCurrency.containsKey(dateString)) {
        dailyTotalsByCurrency[dateString] = {};
      }
      dailyTotalsByCurrency[dateString]![currencyCode] =
          (dailyTotalsByCurrency[dateString]![currencyCode] ?? 0) +
              (expense['amount'] as num).toDouble();
    }

    final List<String> sortedDates = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Mama',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24.0,
            fontWeight: FontWeight.w800,),),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 79, 8, 126),
              borderRadius: BorderRadius.circular(5.0),
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
                            '$_selectedCurrencySymbol${_totalExpense.toStringAsFixed(2)}',
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
                            '$_selectedCurrencySymbol${_totalIncome.toStringAsFixed(2)}',
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
          if (_expenses.isNotEmpty) _buildCurrencyFilter(),
          Expanded(
            child: filteredExpenses.isEmpty
                ? Center(
                child: Text(
                    'No expenses found for ${_selectedFilterCurrency ?? "this filter"}'))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final List<Map<String, dynamic>> expensesForDate =
                groupedExpenses[date]!;
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
                                  return '$currencySymbol${entry.value.toStringAsFixed(2)}';
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
                        ...expensesForDate.map((expense) {
                          final String originalCategory =
                              expense['category'] as String? ?? 'Unknown';
                          final bool categoryExists = _categories
                              .any((c) => c['name'] == originalCategory);
                          final String categoryToDisplay =
                          categoryExists ? originalCategory : 'Unknown';

                          final double amount =
                          (expense['amount'] as num).toDouble();
                          final String note = expense['note'] as String? ?? '';
                          final String expenseCurrencyCode =
                              expense['currency'] ?? _selectedCurrencyCode;
                          final Currency? expenseCurrency =
                          CurrencyService().findByCode(expenseCurrencyCode);
                          final String expenseCurrencySymbol =
                              expenseCurrency?.symbol ?? _selectedCurrencySymbol;

                          return GestureDetector(
                            onTap: () => _showExpenseDialog(expense: expense),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        categoryToDisplay,
                                        style: const TextStyle(
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
                                    '$expenseCurrencySymbol${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade700,
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
        onPressed: () => _showExpenseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
