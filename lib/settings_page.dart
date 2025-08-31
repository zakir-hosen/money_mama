import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import 'sembast_helper.dart';

// Category Settings Page old
// now setting page
class SettingsPage extends StatefulWidget {
  final VoidCallback onCategoriesUpdated;
  const SettingsPage({super.key, required this.onCategoriesUpdated});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _sembastHelper = SembastHelper.instance;
  List<Map<String, dynamic>> _categories = [];
  String _selectedCurrencyCode = 'USD';
  String _selectedCurrencySymbol = '\$';
  List<String> _favoriteCurrencyCodes = ['USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadCurrency();
    await _loadFavoriteCurrencies();
  }

  Future<void> _loadCategories() async {
    final categories = await _sembastHelper.getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  Future<void> _loadCurrency() async {
    final currencyCode = await SembastHelper.instance.getSettings('currencyCode', defaultValue: 'USD');
    final currency = CurrencyService().findByCode(currencyCode);
    if (mounted && currency != null) {
      setState(() {
        _selectedCurrencyCode = currency.code;
        _selectedCurrencySymbol = currency.symbol;
      });
    }
  }

  Future<void> _loadFavoriteCurrencies() async {
    // Get the favorite currencies from the database.
    // Sembast stores arrays, so we need to cast to List<String>.
    final favoriteCurrencies = await _sembastHelper.getSettings('favoriteCurrencies', defaultValue: ['USD', 'EUR', 'GBP']);
    if (mounted) {
      setState(() {
        _favoriteCurrencyCodes = List<String>.from(favoriteCurrencies);
      });
    }
  }

  Future<void> _addCategoryDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await _sembastHelper.addCategory({'name': nameController.text});
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        );
      },
    );
    if (result == true) {
      await _loadCategories();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);

    setState(() {});

    await _sembastHelper.updateCategoryOrders(_categories);
  }

  void _showCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      onSelect: (Currency currency) async {
        await _sembastHelper.saveSettings('currencyCode', currency.code);
        await _loadCurrency();
      },
      // Now, the favorite list is dynamic!
      favorite: _favoriteCurrencyCodes,
    );
  }

  // New method to manage the favorite currencies from a dialog
  void _showManageFavoritesDialog() {
    List<Currency> allCurrencies = CurrencyService().getAll();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (sfbContext, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Favorites'),
              content: SingleChildScrollView(
                child: Column(
                  children: allCurrencies.map((currency) {
                    final isFavorite = _favoriteCurrencyCodes.contains(currency.code);
                    return CheckboxListTile(
                      title: Text('${currency.name} (${currency.symbol})'),
                      value: isFavorite,
                      onChanged: (bool? newValue) {
                        setDialogState(() {
                          if (newValue == true) {
                            _favoriteCurrencyCodes.add(currency.code);
                          } else {
                            _favoriteCurrencyCodes.remove(currency.code);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    // Save the new list of favorites to the database
                    await _sembastHelper.saveSettings('favoriteCurrencies', _favoriteCurrencyCodes);
                    await _loadFavoriteCurrencies(); // Refresh the state
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // New method to handle category deletion with a confirmation dialog
  Future<void> _confirmDeleteCategory(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure you want to delete this category? All expenses associated with this category will remain, but the category name will show as "Unknown".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _sembastHelper.deleteCategory(id);
      await _loadCategories();
      widget.onCategoriesUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          // Currency Settings
          ListTile(
            title: const Text('Default Currency'),
            subtitle: Text('$_selectedCurrencySymbol ($_selectedCurrencyCode)'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showCurrencyPicker,
          ),
          ListTile(
            title: const Text('Manage Favorite Currencies'),
            subtitle: Text(_favoriteCurrencyCodes.join(', ')),
            trailing: const Icon(Icons.edit),
            onTap: _showManageFavoritesDialog,
          ),
          const Divider(),
          // Category Settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () => _addCategoryDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _categories.isEmpty
                ? const Center(child: Text('No categories yet. Add one!'))
                : ReorderableListView(
              onReorder: _onReorder,
              children: _categories.map((category) {
                return Card(
                  key: ValueKey(category['id']),
                  margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  child: ListTile(
                    title: Text(category['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteCategory(category['id']),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
