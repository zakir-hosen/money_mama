import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class SembastHelper {
  // Singleton pattern
  SembastHelper._privateConstructor();
  static final SembastHelper instance = SembastHelper._privateConstructor();

  // Stores
  final _expenseStore = intMapStoreFactory.store('expenses');
  final _incomeStore = intMapStoreFactory.store('incomes');
  final _categoryStore = stringMapStoreFactory.store('categories');
  final _settingsStore = stringMapStoreFactory.store('settings');

  // Database
  final DatabaseFactory _dbFactory = getDatabaseFactorySqflite(sqflite.databaseFactory);
  Database? _db;

  // Initialize database - FIXED: corrected syntax errors
  Future<Database> get database async {
    if (_db != null) return _db!;

    // Using getApplicationDocumentsDirectory() ensures internal storage
    final dir = await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    final dbPath = join(dir.path, 'my_expense.db');

    _db = await _dbFactory.openDatabase(dbPath); // FIXED: removed asterisks
    return _db!;
  }

  // ====================
  // Expense Methods
  // ====================
  Future<int> addExpense(Map<String, dynamic> data) async {
    final db = await database;
    if (!data.containsKey('date')) {
      data['date'] = DateTime.now().toIso8601String();
    }
    await _updateTotal('totalExpense', (data['amount'] as num).toDouble(), add: true);
    return await _expenseStore.add(db, data);
  }

  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getExpenses() async {
    final db = await database;
    return await _expenseStore.find(db,
        finder: Finder(sortOrders: [
          SortOrder('date', false), // latest first
        ]));
  }

  Future<int> updateExpense(int key, Map<String, dynamic> data) async {
    final db = await database;
    final oldData = await _expenseStore.record(key).get(db);
    if (oldData != null) {
      final oldAmount = (oldData['amount'] as num).toDouble();
      await _updateTotal('totalExpense', -oldAmount, add: true);
    }
    await _updateTotal('totalExpense', (data['amount'] as num).toDouble(), add: true);
    await _expenseStore.record(key).update(db, data);
    return key;
  }

  Future<int> deleteExpense(int key) async {
    final db = await database;
    final data = await _expenseStore.record(key).get(db);
    if (data != null) {
      await _updateTotal('totalExpense', -(data['amount'] as num).toDouble(), add: true);
    }
    await _expenseStore.record(key).delete(db);
    return key;
  }

  // ====================
  // Income Methods
  // ====================
  Future<int> addIncome(Map<String, dynamic> data) async {
    final db = await database;
    if (!data.containsKey('date')) {
      data['date'] = DateTime.now().toIso8601String();
    }
    await _updateTotal('totalIncome', (data['amount'] as num).toDouble(), add: true);
    return await _incomeStore.add(db, data);
  }

  Future<List<RecordSnapshot<int, Map<String, dynamic>>>> getIncomes() async {
    final db = await database;
    return await _incomeStore.find(db,
        finder: Finder(sortOrders: [
          SortOrder('date', false), // latest first
        ]));
  }

  Future<int> updateIncome(int key, Map<String, dynamic> data) async {
    final db = await database;
    final oldData = await _incomeStore.record(key).get(db);
    if (oldData != null) {
      final oldAmount = (oldData['amount'] as num).toDouble();
      await _updateTotal('totalIncome', -oldAmount, add: true);
    }
    await _updateTotal('totalIncome', (data['amount'] as num).toDouble(), add: true);
    await _incomeStore.record(key).update(db, data);
    return key;
  }

  Future<int> deleteIncome(int key) async {
    final db = await database;
    final data = await _incomeStore.record(key).get(db);
    if (data != null) {
      await _updateTotal('totalIncome', -(data['amount'] as num).toDouble(), add: true);
    }
    await _incomeStore.record(key).delete(db);
    return key;
  }

  // ====================
  // Category Methods
  // ====================
  Future<String> addCategory(Map<String, dynamic> data) async {
    final db = await database;
    if (!data.containsKey('order')) {
      final categories = await getCategories();
      int newOrder = 0;
      if (categories.isNotEmpty) {
        newOrder = (categories.map((c) => c['order'] as int? ?? 0).reduce((a, b) => a > b ? a : b)) + 1;
      }
      data['order'] = newOrder;
    }
    return await _categoryStore.add(db, data);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final finder = Finder(sortOrders: [SortOrder('order', true)]);
    final records = await _categoryStore.find(db, finder: finder);
    return records.map((r) => {'id': r.key, ...r.value}).toList();
  }

  Future<String> updateCategory(String key, Map<String, dynamic> dataToUpdate) async { // FIXED: changed return type and parameter type
    final db = await database;
    await _categoryStore.record(key).update(db, dataToUpdate);
    return key;
  }

  Future<void> updateCategoryOrders(List<Map<String, dynamic>> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        if (category['id'] != null) {
          await _categoryStore.record(category['id'] as String).update(txn, {'order': i});
        }
      }
    });
  }

  Future<String> deleteCategory(String key) async { // FIXED: changed return type and parameter type
    final db = await database;
    await _categoryStore.record(key).delete(db);
    return key;
  }

  // ====================
  // Settings Methods
  // ====================
  Future<void> saveSettings(String key, dynamic value) async {
    final db = await database;
    await _settingsStore.record(key).put(db, {'value': value});
  }

  Future<dynamic> getSettings(String key, {dynamic defaultValue}) async {
    final db = await database;
    final record = await _settingsStore.record(key).get(db);
    return record?['value'] ?? defaultValue;
  }

  // ====================
  // Total Balances
  // ====================
  Future<void> _updateTotal(String key, double amount, {bool add = true}) async {
    final db = await database;
    final currentTotal = await getSettings(key, defaultValue: 0.0);
    double newTotal = currentTotal as double;
    if (add) {
      newTotal += amount;
    } else {
      newTotal = amount;
    }
    await saveSettings(key, newTotal);
  }

  // ====================
  // Additional Helper Methods
  // ====================

  // Get database file path for debugging
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'my_expense.db');
  }

  // Close database connection
  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // Clear all data (useful for testing or reset functionality)
  Future<void> clearAllData() async {
    final db = await database;
    await _expenseStore.delete(db);
    await _incomeStore.delete(db);
    await _categoryStore.delete(db);
    await _settingsStore.delete(db);
  }
}