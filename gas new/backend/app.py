import sqlite3
import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime

# --- App Setup ---
app = Flask(__name__)
CORS(app)
DATABASE = 'tracker.db'

# --- Database Setup ---
def get_db_connection():
    conn = sqlite3.connect(DATABASE, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    if os.path.exists(DATABASE):
        return
    print("Creating new database...")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE employees (id TEXT PRIMARY KEY, name TEXT NOT NULL)')
    cursor.execute('CREATE TABLE admin_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
    cursor.execute('''CREATE TABLE logs (log_id INTEGER PRIMARY KEY AUTOINCREMENT, employeeName TEXT, employeeId TEXT, eventType TEXT, timestamp TEXT NOT NULL)''')
    cursor.execute('''CREATE TABLE deliveries (delivery_id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, emp_name TEXT, emp_id TEXT, cust_id TEXT, gas_price REAL)''')
    cursor.execute('''CREATE TABLE expenses (expense_id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, emp_name TEXT, emp_id TEXT, expense_category TEXT, expense_price REAL)''')
    cursor.execute("INSERT INTO employees (id, name) VALUES (?, ?)", ('EMP001', 'John Doe'))
    cursor.execute("INSERT INTO admin_settings (key, value) VALUES (?, ?)", ('password', 'admin123'))
    conn.commit()
    conn.close()
    print("Database initialized. Default Admin Password: admin123")
    print("Default Employee: John Doe (ID: EMP001)")

# --- API Endpoints ---
@app.route('/')
def index():
    return "<h1>Expense Tracker API is Running</h1>"

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    emp_name = data.get('emp_name', '').strip()
    emp_id = data.get('emp_id', '').strip().upper() # Standardize ID to uppercase
    conn = get_db_connection()
    # FIX: Use LOWER() for case-insensitive name matching.
    employee = conn.execute("SELECT * FROM employees WHERE LOWER(name) = LOWER(?) AND id = ?", 
                            (emp_name, emp_id)).fetchone()
    if employee:
        conn.execute("INSERT INTO logs (employeeName, employeeId, eventType, timestamp) VALUES (?, ?, ?, ?)",
                     (employee['name'], employee['id'], 'login', datetime.now().isoformat()))
        conn.commit()
        conn.close()
        return jsonify(dict(employee))
    else:
        conn.close()
        return jsonify({"error": "Invalid credentials"}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    data = request.json
    conn = get_db_connection()
    conn.execute("INSERT INTO logs (employeeName, employeeId, eventType, timestamp) VALUES (?, ?, ?, ?)",
                 (data.get('emp_name'), data.get('emp_id'), 'logout', datetime.now().isoformat()))
    conn.commit()
    conn.close()
    return jsonify({"message": "Logout logged"})

@app.route('/api/admin/login', methods=['POST'])
def admin_login():
    password = request.json.get('password')
    conn = get_db_connection()
    admin_data = conn.execute("SELECT value FROM admin_settings WHERE key = 'password'").fetchone()
    conn.close()
    if admin_data and password == admin_data['value']:
        return jsonify({"success": True})
    else:
        return jsonify({"error": "Incorrect password"}), 401

@app.route('/api/delivery', methods=['POST'])
def add_delivery():
    data = request.json
    conn = get_db_connection()
    conn.execute("INSERT INTO deliveries (date, emp_name, emp_id, cust_id, gas_price) VALUES (?, ?, ?, ?, ?)",
                 (datetime.now().strftime('%d-%m-%Y'), data['emp_name'], data['emp_id'], data['cust_id'], data['gas_price']))
    conn.commit()
    conn.close()
    return jsonify({"message": "Delivery logged."})

@app.route('/api/expense', methods=['POST'])
def add_expense():
    data = request.json
    conn = get_db_connection()
    conn.execute("INSERT INTO expenses (date, emp_name, emp_id, expense_category, expense_price) VALUES (?, ?, ?, ?, ?)",
                 (datetime.now().strftime('%d-%m-%Y'), data['emp_name'], data['emp_id'], data['expense_category'], data['expense_price']))
    conn.commit()
    conn.close()
    return jsonify({"message": "Expense logged."})

@app.route('/api/admin/dashboard', methods=['GET'])
def get_admin_dashboard_data():
    conn = get_db_connection()
    logs = [dict(row) for row in conn.execute("SELECT * FROM logs ORDER BY timestamp DESC").fetchall()]
    deliveries = [dict(row) for row in conn.execute("SELECT * FROM deliveries ORDER BY date DESC").fetchall()]
    expenses = [dict(row) for row in conn.execute("SELECT * FROM expenses ORDER BY date DESC").fetchall()]
    summary = {}
    for d in deliveries:
        key = (d['date'], d['emp_id'], d['emp_name'])
        summary.setdefault(key, {'gas': 0, 'expense': 0})
        summary[key]['gas'] += d['gas_price']
    for e in expenses:
        key = (e['date'], e['emp_id'], e['emp_name'])
        summary.setdefault(key, {'gas': 0, 'expense': 0})
        summary[key]['expense'] += e['expense_price']
    string_key_summary = {f"{k[0]}|{k[1]}|{k[2]}": v for k, v in summary.items()}
    conn.close()
    return jsonify({"logs": logs, "deliveries": deliveries, "expenses": expenses, "summary": string_key_summary})

@app.route('/api/admin/employees', methods=['GET', 'POST'])
def manage_employees():
    conn = get_db_connection()
    if request.method == 'GET':
        employees = [dict(row) for row in conn.execute("SELECT * FROM employees").fetchall()]
        conn.close()
        return jsonify(employees)
    if request.method == 'POST':
        data = request.json
        conn.execute("INSERT INTO employees (name, id) VALUES (?, ?)", (data['emp_name'], data['emp_id']))
        conn.commit()
        conn.close()
        return jsonify({"message": "Employee added."})

@app.route('/api/admin/employees/delete_all', methods=['POST'])
def delete_all_employees():
    conn = get_db_connection()
    conn.execute("DELETE FROM employees")
    conn.commit()
    conn.close()
    return jsonify({"message": "All employees deleted."})

@app.route('/api/admin/password', methods=['POST'])
def change_admin_password():
    data = request.json
    # FIX: Corrected typo from new__password to new_password
    new_password = data.get('new_password')
    if not new_password or len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters."}), 400
    conn = get_db_connection()
    conn.execute("UPDATE admin_settings SET value = ? WHERE key = 'password'", (new_password,))
    conn.commit()
    conn.close()
    return jsonify({"message": "Admin password updated."})

# --- Main Execution ---
if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5001, debug=True)