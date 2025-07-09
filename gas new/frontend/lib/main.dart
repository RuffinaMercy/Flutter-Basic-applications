import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Make sure this IP address matches your computer's network IP.
const String apiBaseUrl = 'http://192.168.56.1:5001';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/admin/dashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}

// ===========================================================================
// == LOGIN PAGE
// ===========================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _empNameController = TextEditingController();
  final _empIdController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _employeeLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_name': _empNameController.text,
          'emp_id': _empIdController.text,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final employeeData = jsonDecode(response.body);
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: employeeData,
        );
      } else {
        _showError(jsonDecode(response.body)['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      _showError('Connection failed. Is the server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adminLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': _adminPasswordController.text}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        _showError(jsonDecode(response.body)['error'] ?? 'Incorrect password');
      }
    } catch (e) {
      _showError('Connection failed. Is the server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Employee Login',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _empNameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _empIdController,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _employeeLogin,
                child: const Text('Login'),
              ),
              const Divider(height: 40),
              const Text(
                'Admin Login',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _adminPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _adminLogin,
                child: const Text('Login as Admin'),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// == EMPLOYEE DASHBOARD
// ===========================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _custIdController = TextEditingController();
  final _gasPriceController = TextEditingController();
  final _expenseCategoryController = TextEditingController();
  final _expensePriceController = TextEditingController();

  Map<String, dynamic>? employee;
  bool _isLoading = false;

  // FEATURE: State for live expense tracking
  final List<Map<String, dynamic>> _currentExpenses = [];
  double _totalExpenseSum = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    employee =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // FEATURE: Confirmation dialog for delivery
  Future<void> _confirmAndSubmitDelivery() async {
    final custId = _custIdController.text;
    final gasPrice = double.tryParse(_gasPriceController.text);

    if (custId.isEmpty || gasPrice == null) {
      _showError("Please fill out both Customer ID and Gas Price.");
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Confirm Delivery"),
            content: Text(
              "Log delivery for Customer ID: $custId with Gas Price: \$${gasPrice.toStringAsFixed(2)}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      _submitDelivery(custId, gasPrice);
    }
  }

  Future<void> _submitDelivery(String custId, double gasPrice) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/delivery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_name': employee?['name'],
          'emp_id': employee?['id'],
          'cust_id': custId,
          'gas_price': gasPrice,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        _showStatus(jsonDecode(response.body)['message']);
        _custIdController.clear();
        _gasPriceController.clear();
      } else {
        _showError("Failed to log delivery.");
      }
    } catch (e) {
      _showError("Invalid input or connection error.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitExpense() async {
    final category = _expenseCategoryController.text;
    final price = double.tryParse(_expensePriceController.text);
    if (category.isEmpty || price == null) {
      _showError("Please fill out both Category and Price.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/expense'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_name': employee?['name'],
          'emp_id': employee?['id'],
          'expense_category': category,
          'expense_price': price,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        _showStatus(jsonDecode(response.body)['message']);

        // FEATURE: Update live expense list and sum
        setState(() {
          _currentExpenses.add({'category': category, 'price': price});
          _totalExpenseSum = _currentExpenses.fold(
            0.0,
            (sum, item) => sum + (item['price'] as double),
          );
        });

        _expenseCategoryController.clear();
        _expensePriceController.clear();
      } else {
        _showError("Failed to log expense.");
      }
    } catch (e) {
      _showError("Invalid input or connection error.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await http.post(
      Uri.parse('$apiBaseUrl/api/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emp_name': employee?['name'],
        'emp_id': employee?['id'],
      }),
    );
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    if (employee == null) {
      return const Scaffold(
        body: Center(child: Text("Error: No employee data.")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome ${employee!['name']} (${employee!['id']})"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Customer Delivery',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _custIdController,
                      decoration: const InputDecoration(
                        labelText: 'Customer ID',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _gasPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Gas Price'),
                    ),
                    const SizedBox(height: 16),
                    // FEATURE: Call confirmation dialog instead of direct submit
                    ElevatedButton(
                      onPressed: _isLoading ? null : _confirmAndSubmitDelivery,
                      child: const Text('Submit Delivery'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Expense Entry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _expenseCategoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _expensePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitExpense,
                      child: const Text('Submit Expense'),
                    ),
                  ],
                ),
              ),
            ),
            // FEATURE: Live expense table and sum display
            if (_currentExpenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Card(
                  child: Column(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Price'), numeric: true),
                        ],
                        rows: _currentExpenses
                            .map(
                              (expense) => DataRow(
                                cells: [
                                  DataCell(Text(expense['category'])),
                                  DataCell(
                                    Text(
                                      '\$${(expense['price'] as double).toStringAsFixed(2)}',
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Expenses:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '\$${_totalExpenseSum.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ... The Admin section code is correct and does not need changes ...
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const ReportsView(), const AdminSettingsPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Admin Dashboard" : "Admin Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});
  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setStateIfMounted(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/dashboard'),
      );
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _data = jsonDecode(response.body);
          });
        } else {
          setState(() => _error = "Failed to load dashboard data.");
        }
      }
    } catch (e) {
      setStateIfMounted(() => _error = "Connection error.");
    } finally {
      setStateIfMounted(() => _isLoading = false);
    }
  }

  void setStateIfMounted(void Function() f) {
    if (mounted) setState(f);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final logs = _data['logs'] as List? ?? [];
    final deliveries = _data['deliveries'] as List? ?? [];
    final expenses = _data['expenses'] as List? ?? [];
    final summary = _data['summary'] as Map? ?? {};

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTableCard(
            'Employee Sessions',
            ['ID', 'Name', 'ID', 'Event', 'Time'],
            logs.map<List<String>>((log) {
              final timestamp = log['timestamp'] != null
                  ? DateTime.tryParse(log['timestamp'])
                  : null;
              return [
                (log['log_id'] ?? 'N/A').toString(),
                (log['employeeName'] ?? 'N/A').toString(),
                (log['employeeId'] ?? 'N/A').toString(),
                (log['eventType'] ?? 'N/A').toString(),
                timestamp != null
                    ? DateFormat.yMd().add_jm().format(timestamp)
                    : 'N/A',
              ];
            }).toList(),
          ),
          _buildTableCard(
            'Deliveries',
            ['Date', 'Name', 'ID', 'Cust ID', 'Gas Price'],
            deliveries.map<List<String>>((d) {
              return [
                (d['date'] ?? 'N/A').toString(),
                (d['emp_name'] ?? 'N/A').toString(),
                (d['emp_id'] ?? 'N/A').toString(),
                (d['cust_id'] ?? 'N/A').toString(),
                (d['gas_price'] ?? 0.0).toStringAsFixed(2),
              ];
            }).toList(),
          ),
          _buildTableCard(
            'Expenses',
            ['Date', 'Name', 'ID', 'Category', 'Price'],
            expenses.map<List<String>>((e) {
              return [
                (e['date'] ?? 'N/A').toString(),
                (e['emp_name'] ?? 'N/A').toString(),
                (e['emp_id'] ?? 'N/A').toString(),
                (e['expense_category'] ?? 'N/A').toString(),
                (e['expense_price'] ?? 0.0).toStringAsFixed(2),
              ];
            }).toList(),
          ),
          _buildTableCard(
            'Final Report',
            ['Date', 'Emp ID', 'Name', 'Total Gas', 'Total Expenses', 'Net'],
            summary.entries.map<List<String>>((entry) {
              final parts = entry.key.split('|');
              final data = entry.value as Map;
              final num gas = data['gas'] ?? 0.0;
              final num expense = data['expense'] ?? 0.0;
              final num net = gas - expense;
              return [
                parts.isNotEmpty ? parts[0] : 'N/A',
                parts.length > 1 ? parts[1] : 'N/A',
                parts.length > 2 ? parts[2] : 'N/A',
                gas.toStringAsFixed(2),
                expense.toStringAsFixed(2),
                net.toStringAsFixed(2),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: headers
                  .map(
                    (h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row.map((cell) => DataCell(Text(cell))).toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  List<dynamic> _employees = [];
  final _empNameController = TextEditingController();
  final _empIdController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/employees'),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _employees = jsonDecode(response.body));
      }
    } catch (e) {
      _showStatus("Could not fetch employees.", isError: true);
    }
  }

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _addEmployee() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/admin/employees'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_name': _empNameController.text,
          'emp_id': _empIdController.text,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        _showStatus(jsonDecode(response.body)['message']);
        _empNameController.clear();
        _empIdController.clear();
        _fetchEmployees();
      } else {
        _showStatus("Failed to add employee.", isError: true);
      }
    } catch (e) {
      _showStatus("Connection error.", isError: true);
    }
  }

  Future<void> _deleteAllEmployees() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete All Employees?"),
            content: const Text("This action cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "DELETE",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/admin/employees/delete_all'),
        );
        if (response.statusCode == 200 && mounted) {
          _showStatus(jsonDecode(response.body)['message']);
          _fetchEmployees();
        }
      } catch (e) {
        _showStatus("Connection error.", isError: true);
      }
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showStatus("Passwords do not match.", isError: true);
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showStatus("Password must be at least 6 characters.", isError: true);
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/admin/password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'new_password': _newPasswordController.text}),
      );
      if (response.statusCode == 200 && mounted) {
        _showStatus(jsonDecode(response.body)['message']);
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _showStatus("Failed to update password.", isError: true);
      }
    } catch (e) {
      _showStatus("Connection error.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Employee Management",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _empNameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _empIdController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addEmployee,
                  child: const Text("Add Employee"),
                ),
                const Divider(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _deleteAllEmployees,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                    child: const Text("Delete All Employees"),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Current Employees:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (var emp in _employees)
                  ListTile(
                    title: Text(emp['name'] ?? 'N/A'),
                    subtitle: Text(emp['id'] ?? 'N/A'),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Change Admin Password",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _updatePassword,
                  child: const Text("Update Password"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
