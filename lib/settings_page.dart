import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import 'sembast_helper.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onCategoriesUpdated;
  const SettingsPage({super.key, required this.onCategoriesUpdated});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _sembastHelper = SembastHelper.instance;
  List<Map<String, dynamic>> _categories = [];
  String _selectedCurrencyCode = 'BDT'; // FIXED: Changed default to match your app
  String _selectedCurrencySymbol = '৳';
  List<String> _favoriteCurrencyCodes = ['BDT', 'USD', 'EUR']; // FIXED: Added BDT as default

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
    try {
      final categories = await _sembastHelper.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final currencyCode = await SembastHelper.instance
          .getSettings('currencyCode', defaultValue: 'BDT');
      final currency = CurrencyService().findByCode(currencyCode);
      if (mounted && currency != null) {
        setState(() {
          _selectedCurrencyCode = currency.code;
          _selectedCurrencySymbol = currency.symbol;
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }

  Future<void> _loadFavoriteCurrencies() async {
    try {
      final favoriteCurrencies = await _sembastHelper.getSettings(
          'favoriteCurrencies',
          defaultValue: ['BDT', 'USD', 'EUR']); // FIXED: Added BDT
      if (mounted) {
        setState(() {
          _favoriteCurrencyCodes = List<String>.from(favoriteCurrencies);
        });
      }
    } catch (e) {
      debugPrint('Error loading favorite currencies: $e');
    }
  }

  Future<void> _addCategoryDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'Enter category name',
                ),
                textCapitalization: TextCapitalization.words, // ADDED: Auto capitalize
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  // FIXED: Check for duplicate categories
                  final isDuplicate = _categories.any((cat) =>
                  (cat['name'] as String).toLowerCase() == name.toLowerCase());

                  if (isDuplicate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category already exists!')),
                    );
                    return;
                  }

                  try {
                    await _sembastHelper.addCategory({'name': name});
                    Navigator.of(dialogContext).pop(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding category: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                }
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _loadCategories();
      widget.onCategoriesUpdated(); // Notify parent
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Create a copy of the list for reordering
    final reorderedCategories = List<Map<String, dynamic>>.from(_categories);
    final category = reorderedCategories.removeAt(oldIndex);
    reorderedCategories.insert(newIndex, category);

    setState(() {
      _categories = reorderedCategories;
    });

    try {
      await _sembastHelper.updateCategoryOrders(_categories);
      widget.onCategoriesUpdated(); // Notify parent of changes
    } catch (e) {
      debugPrint('Error reordering categories: $e');
      // Revert the UI change if database update fails
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering categories: $e')),
        );
      }
    }
  }

  void _showCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      onSelect: (Currency currency) async {
        try {
          await _sembastHelper.saveSettings('currencyCode', currency.code);
          await _loadCurrency();
          widget.onCategoriesUpdated(); // ADDED: Notify parent to refresh
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving currency: $e')),
            );
          }
        }
      },
      favorite: _favoriteCurrencyCodes,
    );
  }

  void _showManageFavoritesDialog() {
    List<Currency> allCurrencies = CurrencyService().getAll();
    // Create a working copy of favorites for the dialog
    List<String> workingFavorites = List<String>.from(_favoriteCurrencyCodes);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sfbContext, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Favorite Currencies'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, // ADDED: Fixed height for better UX
                child: SingleChildScrollView(
                  child: Column(
                    children: allCurrencies.map((currency) {
                      final isFavorite = workingFavorites.contains(currency.code);
                      return CheckboxListTile(
                        title: Text('${currency.name}'),
                        subtitle: Text('${currency.code} (${currency.symbol})'),
                        value: isFavorite,
                        dense: true, // ADDED: More compact display
                        onChanged: (bool? newValue) {
                          setDialogState(() {
                            if (newValue == true) {
                              if (!workingFavorites.contains(currency.code)) {
                                workingFavorites.add(currency.code);
                              }
                            } else {
                              workingFavorites.remove(currency.code);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    try {
                      await _sembastHelper.saveSettings('favoriteCurrencies', workingFavorites);
                      await _loadFavoriteCurrencies();
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving favorites: $e')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // FIXED: Handle category deletion with proper type conversion
  Future<void> _confirmDeleteCategory(dynamic categoryId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
            'Are you sure you want to delete this category?\n\n'
                'All expenses with this category will show as "Unknown" but the expense data will remain intact.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // FIXED: Convert to String since categories use string keys
        final keyToDelete = categoryId is String ? categoryId : categoryId.toString();
        await _sembastHelper.deleteCategory(keyToDelete);
        await _loadCategories();
        widget.onCategoriesUpdated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting category: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  // ADDED: Method to edit category name
  Future<void> _editCategoryDialog(Map<String, dynamic> category) async {
    final TextEditingController nameController =
    TextEditingController(text: category['name']);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'Enter new category name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != category['name']) {
                  // Check for duplicates
                  final isDuplicate = _categories.any((cat) =>
                  cat['id'] != category['id'] &&
                      (cat['name'] as String).toLowerCase() == newName.toLowerCase());

                  if (isDuplicate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category name already exists!')),
                    );
                    return;
                  }

                  try {
                    await _sembastHelper.updateCategory(
                        category['id'], {'name': newName});
                    Navigator.of(dialogContext).pop(true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating category: $e')),
                    );
                  }
                } else if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a category name')),
                  );
                } else {
                  Navigator.of(dialogContext).pop(false);
                }
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _loadCategories();
      widget.onCategoriesUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Currency Settings Section
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Currency Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Default Currency'),
                  subtitle: Text('$_selectedCurrencySymbol ($_selectedCurrencyCode)'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showCurrencyPicker,
                ),
                ListTile(
                  title: const Text('Manage Favorite Currencies'),
                  subtitle: Text(
                    _favoriteCurrencyCodes.join(', '),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: _showManageFavoritesDialog,
                ),
              ],
            ),
          ),

          // Categories Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expense Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () => _addCategoryDialog(context),
                        tooltip: 'Add Category',
                      ),
                    ],
                  ),
                ),

                // Categories List
                SizedBox(
                  height: 300, // FIXED: Give explicit height for ReorderableListView
                  child: _categories.isEmpty
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No categories yet\nTap + to add your first category',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ReorderableListView.builder(
                    itemCount: _categories.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return Card(
                        key: ValueKey(category['id']), // FIXED: Use proper key
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        elevation: 0.5,
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle, color: Colors.grey),
                          title: Text(
                            category['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _editCategoryDialog(category),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _confirmDeleteCategory(category['id']),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ADDED: App Info Section
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Money Mama v1.0',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}