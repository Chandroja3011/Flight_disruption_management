from flask import Flask, jsonify, request, render_template
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import os
from datetime import datetime

app = Flask(__name__, template_folder='../frontend/templates', static_folder='../frontend/static')
CORS(app)

# ── DB CONFIG ──────────────────────────────────────────────────────────────────
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'root123',
    'database': 'flight_disruption_db',
}

def get_db():
    conn = mysql.connector.connect(**DB_CONFIG)
    return conn

def query(sql, params=None, fetchone=False, commit=False):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(sql, params or ())
        if commit:
            conn.commit()
            return cursor.rowcount
        result = cursor.fetchone() if fetchone else cursor.fetchall()
        return result
    except Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()

# ── SERVE FRONTEND ─────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/<page>')
def page(page):
    try:
        return render_template(f'{page}.html')
    except:
        return render_template('index.html')

# ════════════════════════════════════════════════════════════════════════════════
# DASHBOARD STATS
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/stats')
def stats():
    return jsonify({
        'total_flights': query("SELECT COUNT(*) AS c FROM flight", fetchone=True)['c'],
        'active_disruptions': query("SELECT COUNT(*) AS c FROM disruption_event WHERE resolution_status='Active'", fetchone=True)['c'],
        'fatigued_pilots': query("SELECT COUNT(*) AS c FROM pilot WHERE fatigue_status='Fatigued'", fetchone=True)['c'],
        'delayed_flights': query("SELECT COUNT(*) AS c FROM flight WHERE flight_status='Delayed'", fetchone=True)['c'],
        'total_passengers': query("SELECT COUNT(*) AS c FROM passenger", fetchone=True)['c'],
        'total_bookings': query("SELECT COUNT(*) AS c FROM booking", fetchone=True)['c'],
    })

# ════════════════════════════════════════════════════════════════════════════════
# FLIGHTS (DDL/DML + JOINS + VIEWS)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/flights')
def get_flights():
    # JOIN across flight, airline, airport (source & dest) — demonstrates JOIN
    sql = """
        SELECT f.flight_id, f.flight_number, f.flight_type, f.flight_status,
               f.scheduled_departure, f.scheduled_arrival,
               f.actual_departure, f.actual_arrival,
               al.airline_name,
               src.airport_name AS source_airport, src.city AS source_city,
               dst.airport_name AS dest_airport, dst.city AS dest_city
        FROM flight f
        JOIN airline al ON f.airline_id = al.airline_id
        JOIN airport src ON f.source_airport_id = src.airport_id
        JOIN airport dst ON f.destination_airport_id = dst.airport_id
        ORDER BY f.scheduled_departure DESC
    """
    return jsonify(query(sql))

@app.route('/api/flights/<int:fid>')
def get_flight(fid):
    sql = """
        SELECT f.*, al.airline_name,
               src.airport_name AS source_airport,
               dst.airport_name AS dest_airport,
               fr.latitude, fr.longitude, fr.altitude, fr.speed
        FROM flight f
        JOIN airline al ON f.airline_id = al.airline_id
        JOIN airport src ON f.source_airport_id = src.airport_id
        JOIN airport dst ON f.destination_airport_id = dst.airport_id
        LEFT JOIN flight_radar fr ON fr.flight_id = f.flight_id
        WHERE f.flight_id = %s
    """
    return jsonify(query(sql, (fid,), fetchone=True))

@app.route('/api/flights', methods=['POST'])
def add_flight():
    d = request.json
    sql = """INSERT INTO flight
             (flight_number, flight_type, scheduled_departure, scheduled_arrival,
              flight_status, airline_id, source_airport_id, destination_airport_id)
             VALUES (%s,%s,%s,%s,%s,%s,%s,%s)"""
    try:
        query(sql, (d['flight_number'], d['flight_type'], d['scheduled_departure'],
                    d['scheduled_arrival'], d['flight_status'], d['airline_id'],
                    d['source_airport_id'], d['destination_airport_id']), commit=True)
        return jsonify({'success': True, 'message': 'Flight added successfully'})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/flights/<int:fid>', methods=['PUT'])
def update_flight(fid):
    d = request.json
    sql = "UPDATE flight SET flight_status=%s WHERE flight_id=%s"
    query(sql, (d['flight_status'], fid), commit=True)
    return jsonify({'success': True})

@app.route('/api/flights/<int:fid>', methods=['DELETE'])
def delete_flight(fid):
    query("DELETE FROM flight WHERE flight_id=%s", (fid,), commit=True)
    return jsonify({'success': True})

# ── DELAYED FLIGHTS VIEW ───────────────────────────────────────────────────────
@app.route('/api/delayed-flights')
def delayed_flights():
    # Uses the delayed_flights VIEW
    return jsonify(query("SELECT * FROM delayed_flights"))

# ════════════════════════════════════════════════════════════════════════════════
# DISRUPTIONS (core of the system)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/disruptions')
def get_disruptions():
    sql = """
        SELECT d.*, f.flight_number, f.flight_status,
               al.airline_name,
               src.city AS from_city, dst.city AS to_city
        FROM disruption_event d
        JOIN flight f ON d.flight_id = f.flight_id
        JOIN airline al ON f.airline_id = al.airline_id
        JOIN airport src ON f.source_airport_id = src.airport_id
        JOIN airport dst ON f.destination_airport_id = dst.airport_id
        ORDER BY d.reported_time DESC
    """
    return jsonify(query(sql))

@app.route('/api/disruptions', methods=['POST'])
def add_disruption():
    d = request.json
    sql = """INSERT INTO disruption_event
             (disruption_type, severity_level, reported_time, resolution_status, flight_id)
             VALUES (%s,%s,%s,%s,%s)"""
    try:
        query(sql, (d['disruption_type'], d['severity_level'],
                    d.get('reported_time', datetime.now()), d['resolution_status'],
                    d['flight_id']), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/disruptions/<int:did>', methods=['PUT'])
def update_disruption(did):
    d = request.json
    query("UPDATE disruption_event SET resolution_status=%s WHERE disruption_id=%s",
          (d['resolution_status'], did), commit=True)
    return jsonify({'success': True})

# ── MANAGEMENT DECISIONS ──────────────────────────────────────────────────────
@app.route('/api/decisions')
def get_decisions():
    sql = """
        SELECT md.*, de.disruption_type, de.severity_level,
               f.flight_number
        FROM management_decision md
        JOIN disruption_event de ON md.disruption_id = de.disruption_id
        JOIN flight f ON de.flight_id = f.flight_id
        ORDER BY md.decision_time DESC
    """
    return jsonify(query(sql))

@app.route('/api/decisions', methods=['POST'])
def add_decision():
    d = request.json
    sql = """INSERT INTO management_decision
             (decision_taken, decision_time, approved_by, disruption_id)
             VALUES (%s,%s,%s,%s)"""
    query(sql, (d['decision_taken'], d.get('decision_time', datetime.now()),
                d['approved_by'], d['disruption_id']), commit=True)
    return jsonify({'success': True})

# ════════════════════════════════════════════════════════════════════════════════
# CREW MANAGEMENT (Triggers + Constraints)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/pilots')
def get_pilots():
    return jsonify(query("SELECT * FROM pilot ORDER BY pilot_name"))

@app.route('/api/pilots', methods=['POST'])
def add_pilot():
    d = request.json
    sql = """INSERT INTO pilot (pilot_name, license_no, experience_years, fatigue_status, total_duty_hours)
             VALUES (%s,%s,%s,%s,%s)"""
    try:
        query(sql, (d['pilot_name'], d['license_no'], d['experience_years'],
                    d.get('fatigue_status', 'Active'), d.get('total_duty_hours', 0)), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/cabin-crew')
def get_crew():
    return jsonify(query("SELECT * FROM cabin_crew ORDER BY crew_name"))

@app.route('/api/cabin-crew', methods=['POST'])
def add_crew():
    d = request.json
    sql = """INSERT INTO cabin_crew (crew_name, experience_years, fatigue_status, total_duty_hours)
             VALUES (%s,%s,%s,%s)"""
    try:
        query(sql, (d['crew_name'], d['experience_years'],
                    d.get('fatigue_status', 'Active'), d.get('total_duty_hours', 0)), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/crew-assignments')
def get_assignments():
    sql = """
        SELECT ca.*, f.flight_number,
               p.pilot_name, p.fatigue_status AS pilot_fatigue,
               c.crew_name, c.fatigue_status AS crew_fatigue
        FROM crew_assignment ca
        JOIN flight f ON ca.flight_id = f.flight_id
        LEFT JOIN pilot p ON ca.pilot_id = p.pilot_id
        LEFT JOIN cabin_crew c ON ca.crew_id = c.crew_id
        ORDER BY ca.duty_start_time DESC
    """
    return jsonify(query(sql))

@app.route('/api/crew-assignments', methods=['POST'])
def assign_crew():
    d = request.json
    # Check fatigue before assigning (TRIGGER logic replicated in backend too)
    if d.get('pilot_id'):
        p = query("SELECT fatigue_status FROM pilot WHERE pilot_id=%s",
                  (d['pilot_id'],), fetchone=True)
        if p and p['fatigue_status'] == 'Fatigued':
            return jsonify({'success': False,
                            'error': 'Cannot assign fatigued pilot. TRIGGER: trg_prevent_fatigued_pilot'}), 400
    if d.get('crew_id'):
        c = query("SELECT fatigue_status FROM cabin_crew WHERE crew_id=%s",
                  (d['crew_id'],), fetchone=True)
        if c and c['fatigue_status'] == 'Fatigued':
            return jsonify({'success': False,
                            'error': 'Cannot assign fatigued crew member. TRIGGER: trg_prevent_fatigued_crew'}), 400

    sql = """INSERT INTO crew_assignment
             (role, duty_start_time, duty_end_time, duty_hours, flight_id, pilot_id, crew_id)
             VALUES (%s,%s,%s,%s,%s,%s,%s)"""
    try:
        query(sql, (d['role'], d['duty_start_time'], d['duty_end_time'],
                    d['duty_hours'], d['flight_id'],
                    d.get('pilot_id'), d.get('crew_id')), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

# ── FATIGUE LOG ───────────────────────────────────────────────────────────────
@app.route('/api/fatigue-log')
def fatigue_log():
    sql = """
        SELECT cfl.*, p.pilot_name, c.crew_name, f.flight_number
        FROM crew_fatigue_log cfl
        LEFT JOIN pilot p ON cfl.pilot_id = p.pilot_id
        LEFT JOIN cabin_crew c ON cfl.crew_id = c.crew_id
        LEFT JOIN flight f ON cfl.flight_id = f.flight_id
        ORDER BY cfl.recorded_time DESC
    """
    return jsonify(query(sql))

# ════════════════════════════════════════════════════════════════════════════════
# FARE & PRICING (Surge prevention)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/fare-policies')
def fare_policies():
    return jsonify(query("SELECT * FROM fare_policy"))

@app.route('/api/fare-policies', methods=['POST'])
def add_fare_policy():
    d = request.json
    sql = """INSERT INTO fare_policy (disruption_type, max_price_multiplier, applicable_duration)
             VALUES (%s,%s,%s)"""
    query(sql, (d['disruption_type'], d['max_price_multiplier'], d['applicable_duration']), commit=True)
    return jsonify({'success': True})

@app.route('/api/surge-log')
def surge_log():
    sql = """
        SELECT psl.*, f.flight_number
        FROM price_surge_log psl
        JOIN flight f ON psl.flight_id = f.flight_id
        ORDER BY psl.surge_time DESC
    """
    return jsonify(query(sql))

@app.route('/api/surge-view')
def surge_view():
    # Uses the surge_view VIEW
    return jsonify(query("SELECT * FROM surge_view"))

# ════════════════════════════════════════════════════════════════════════════════
# PASSENGERS & BOOKINGS
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/passengers')
def get_passengers():
    return jsonify(query("SELECT * FROM passenger ORDER BY passenger_name"))

@app.route('/api/passengers', methods=['POST'])
def add_passenger():
    d = request.json
    sql = "INSERT INTO passenger (passenger_name, contact_no) VALUES (%s,%s)"
    try:
        query(sql, (d['passenger_name'], d['contact_no']), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

@app.route('/api/bookings')
def get_bookings():
    sql = """
        SELECT b.*, p.passenger_name, p.contact_no,
               f.flight_number, f.flight_status,
               src.city AS from_city, dst.city AS to_city
        FROM booking b
        JOIN passenger p ON b.passenger_id = p.passenger_id
        JOIN flight f ON b.flight_id = f.flight_id
        JOIN airport src ON f.source_airport_id = src.airport_id
        JOIN airport dst ON f.destination_airport_id = dst.airport_id
        ORDER BY b.booking_date DESC
    """
    return jsonify(query(sql))

@app.route('/api/bookings', methods=['POST'])
def add_booking():
    d = request.json
    sql = """INSERT INTO booking (booking_date, base_fare, total_fare, passenger_id, flight_id)
             VALUES (%s,%s,%s,%s,%s)"""
    try:
        query(sql, (d.get('booking_date', datetime.now().date()),
                    d['base_fare'], d['total_fare'],
                    d['passenger_id'], d['flight_id']), commit=True)
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 400

# ── PASSENGER VIEW ────────────────────────────────────────────────────────────
@app.route('/api/passenger-view')
def passenger_view():
    return jsonify(query("SELECT * FROM passenger_view"))

# ════════════════════════════════════════════════════════════════════════════════
# AIRPORTS & AIRLINES (reference data)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/airports')
def get_airports():
    return jsonify(query("SELECT * FROM airport ORDER BY city"))

@app.route('/api/airlines')
def get_airlines():
    return jsonify(query("SELECT * FROM airline ORDER BY airline_name"))

@app.route('/api/aircraft')
def get_aircraft():
    return jsonify(query("SELECT * FROM aircraft ORDER BY model"))

# ════════════════════════════════════════════════════════════════════════════════
# RADAR
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/radar')
def get_radar():
    sql = """
        SELECT fr.*, f.flight_number, f.flight_status,
               al.airline_name, src.city AS from_city, dst.city AS to_city
        FROM flight_radar fr
        JOIN flight f ON fr.flight_id = f.flight_id
        JOIN airline al ON f.airline_id = al.airline_id
        JOIN airport src ON f.source_airport_id = src.airport_id
        JOIN airport dst ON f.destination_airport_id = dst.airport_id
    """
    return jsonify(query(sql))

# ════════════════════════════════════════════════════════════════════════════════
# NORMALISATION TABLES (read-only views for academic showcase)
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/normalization/<form>')
def normalization(form):
    table_map = {
        'unf':   'flight_unnormalized',
        '1nf':   'flight_1nf',
        '2nf':   'flight_2nf',
        '3nf':   'flight_3nf',
        '4nf_crew': 'flight_crew_4nf',
        '5nf_crew': 'flight_crew_5nf',
        '4nf_pilot': 'flight_pilot_4nf',
        '5nf_pilot': 'flight_pilot_5nf',
        'bcnf':  'flight_pilot_bcnf',
        'booking2nf': 'booking_2nf',
        'passenger2nf': 'passenger_2nf',
        'airport3nf': 'airport_3nf',
        'pilot3nf': 'pilot_3nf',
        'pilotbcnf': 'pilot_bcnf',
    }
    tbl = table_map.get(form)
    if not tbl:
        return jsonify({'error': 'Unknown normalization form'}), 404
    return jsonify(query(f"SELECT * FROM {tbl} LIMIT 20"))

# ════════════════════════════════════════════════════════════════════════════════
# CONCURRENCY CONTROL DEMO — Transaction isolation levels
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/concurrency/transfer', methods=['POST'])
def concurrency_transfer():
    """
    Demonstrates ACID transaction: transfer booking fare between two records.
    Uses SERIALIZABLE isolation to prevent dirty reads.
    """
    d = request.json
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        conn.start_transaction()

        cursor.execute("SELECT total_fare FROM booking WHERE booking_id=%s FOR UPDATE",
                       (d['from_booking_id'],))
        src = cursor.fetchone()
        if not src:
            raise ValueError("Source booking not found")
        if src['total_fare'] < d['amount']:
            raise ValueError("Insufficient fare balance")

        cursor.execute("UPDATE booking SET total_fare = total_fare - %s WHERE booking_id=%s",
                       (d['amount'], d['from_booking_id']))
        cursor.execute("UPDATE booking SET total_fare = total_fare + %s WHERE booking_id=%s",
                       (d['amount'], d['to_booking_id']))
        conn.commit()
        return jsonify({'success': True, 'message': 'Transaction committed (SERIALIZABLE)'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'error': str(e), 'message': 'Transaction rolled back'}), 400
    finally:
        cursor.close()
        conn.close()

@app.route('/api/concurrency/savepoint', methods=['POST'])
def savepoint_demo():
    """Demonstrates SAVEPOINT and partial rollback (recovery mechanism)."""
    d = request.json
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()
        cursor.execute("UPDATE flight SET flight_status=%s WHERE flight_id=%s",
                       (d['status1'], d['flight_id1']))
        cursor.execute("SAVEPOINT sp1")

        cursor.execute("UPDATE flight SET flight_status=%s WHERE flight_id=%s",
                       (d['status2'], d['flight_id2']))

        if d.get('rollback_to_savepoint'):
            cursor.execute("ROLLBACK TO SAVEPOINT sp1")
            conn.commit()
            return jsonify({'success': True,
                            'message': f'Rolled back to SAVEPOINT sp1. Only flight {d["flight_id1"]} updated.'})
        conn.commit()
        return jsonify({'success': True, 'message': 'Both updates committed.'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 400
    finally:
        cursor.close()
        conn.close()

# ════════════════════════════════════════════════════════════════════════════════
# CURSOR DEMO — server-side row-by-row processing
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/cursor/fatigue-scan')
def cursor_fatigue_scan():
    """
    Simulates a stored-cursor-style scan: iterates all crew,
    flags those over 8h duty, logs them. Demonstrates cursor logic.
    """
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    flagged = []
    try:
        cursor.execute("SELECT crew_id, crew_name, total_duty_hours, fatigue_status FROM cabin_crew")
        rows = cursor.fetchall()
        for row in rows:
            if row['total_duty_hours'] > 8 and row['fatigue_status'] != 'Fatigued':
                cursor.execute("UPDATE cabin_crew SET fatigue_status='Fatigued' WHERE crew_id=%s",
                               (row['crew_id'],))
                flagged.append({'crew_name': row['crew_name'],
                                'duty_hours': row['total_duty_hours'],
                                'action': 'Marked Fatigued'})
        conn.commit()
        return jsonify({'success': True, 'flagged': flagged,
                        'message': f'{len(flagged)} crew members updated via cursor scan'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 400
    finally:
        cursor.close()
        conn.close()

# ════════════════════════════════════════════════════════════════════════════════
# AGGREGATE / SET QUERIES
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/analytics/disruptions-by-type')
def disruptions_by_type():
    sql = """SELECT disruption_type, COUNT(*) AS count,
                    SUM(CASE WHEN resolution_status='Active' THEN 1 ELSE 0 END) AS active
             FROM disruption_event GROUP BY disruption_type"""
    return jsonify(query(sql))

@app.route('/api/analytics/fare-stats')
def fare_stats():
    sql = """SELECT f.flight_number,
                    MIN(b.total_fare) AS min_fare,
                    MAX(b.total_fare) AS max_fare,
                    AVG(b.total_fare) AS avg_fare,
                    COUNT(b.booking_id) AS bookings
             FROM booking b JOIN flight f ON b.flight_id=f.flight_id
             GROUP BY f.flight_id, f.flight_number"""
    return jsonify(query(sql))

@app.route('/api/analytics/flights-by-airline')
def flights_by_airline():
    sql = """SELECT al.airline_name,
                    COUNT(f.flight_id) AS total_flights,
                    SUM(CASE WHEN f.flight_status='Delayed' THEN 1 ELSE 0 END) AS delayed,
                    SUM(CASE WHEN f.flight_status='Cancelled' THEN 1 ELSE 0 END) AS cancelled
             FROM flight f JOIN airline al ON f.airline_id=al.airline_id
             GROUP BY al.airline_id, al.airline_name"""
    return jsonify(query(sql))

# SET operations demo
@app.route('/api/analytics/set-operations')
def set_operations():
    """UNION, INTERSECT (simulated), EXCEPT (simulated)"""
    fatigued_pilots = {r['pilot_id'] for r in query(
        "SELECT pilot_id FROM pilot WHERE fatigue_status='Fatigued'")}
    assigned_pilots = {r['pilot_id'] for r in query(
        "SELECT DISTINCT pilot_id FROM crew_assignment WHERE pilot_id IS NOT NULL")}

    fatigued_and_assigned = fatigued_pilots & assigned_pilots   # INTERSECT
    fatigued_not_assigned = fatigued_pilots - assigned_pilots   # EXCEPT

    return jsonify({
        'fatigued_pilots': list(fatigued_pilots),
        'assigned_pilots': list(assigned_pilots),
        'fatigued_AND_assigned_INTERSECT': list(fatigued_and_assigned),
        'fatigued_NOT_assigned_EXCEPT': list(fatigued_not_assigned),
    })

# Subquery demo
@app.route('/api/analytics/above-avg-surge')
def above_avg_surge():
    sql = """
        SELECT psl.surge_id, f.flight_number, psl.surge_percentage, psl.surge_reason
        FROM price_surge_log psl
        JOIN flight f ON psl.flight_id = f.flight_id
        WHERE psl.surge_percentage > (SELECT AVG(surge_percentage) FROM price_surge_log)
        ORDER BY psl.surge_percentage DESC
    """
    return jsonify(query(sql))

# ════════════════════════════════════════════════════════════════════════════════
# RECOVERY / UNDO LOG DEMO
# ════════════════════════════════════════════════════════════════════════════════
@app.route('/api/recovery/simulate', methods=['POST'])
def recovery_simulate():
    """
    Simulates a crash+recovery scenario:
    1. Begin transaction
    2. Write-ahead log concept — show before/after states
    3. Intentionally fail, then rollback
    """
    d = request.json
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    log = []
    try:
        conn.start_transaction()
        cursor.execute("SELECT flight_status FROM flight WHERE flight_id=%s", (d['flight_id'],))
        before = cursor.fetchone()
        log.append({'step': 'WRITE-AHEAD LOG', 'before': before['flight_status'],
                    'after': d['new_status'], 'flight_id': d['flight_id']})

        cursor.execute("UPDATE flight SET flight_status=%s WHERE flight_id=%s",
                       (d['new_status'], d['flight_id']))
        log.append({'step': 'UPDATE APPLIED (dirty write, not committed)'})

        if d.get('simulate_crash'):
            conn.rollback()
            log.append({'step': 'CRASH SIMULATED — ROLLBACK executed',
                        'recovered_to': before['flight_status']})
            return jsonify({'success': True, 'log': log,
                            'message': 'Recovery: data rolled back to last committed state'})

        conn.commit()
        log.append({'step': 'COMMIT — REDO log flushed'})
        return jsonify({'success': True, 'log': log})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'error': str(e), 'log': log}), 400
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    app.run(debug=True, port=5000)
