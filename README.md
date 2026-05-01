# Flight Disruption Management System — Setup Guide

## Project Structure
```
flight_app/
├── backend/
│   ├── app.py              ← Flask REST API
│   ├── schema.sql          ← All DDL, DML, Triggers, Views, Procedures
│   └── requirements.txt
└── frontend/
    ├── templates/
    │   ├── index.html          ← Dashboard
    │   ├── flights.html        ← Flight Management (DDL/DML/JOIN)
    │   ├── disruptions.html    ← Disruption Filing (Triggers)
    │   ├── crew.html           ← Crew/Pilots (Triggers, Cursor)
    │   ├── bookings.html       ← Bookings & Passengers (Views)
    │   ├── fare.html           ← Fare Policy & Surge (Subqueries)
    │   ├── radar.html          ← Live Radar (JOIN)
    │   ├── normalization.html  ← 1NF→5NF showcase
    │   ├── concurrency.html    ← ACID, Savepoints, WAL
    │   └── analytics.html      ← Aggregates, SET ops, Charts
    └── static/
        ├── css/main.css
        └── js/main.js
```

---

## Step 1 — Install MySQL

Make sure MySQL 8.x is installed and running.

```bash
mysql -u root -p
```

---

## Step 2 — Create the Database

```bash
mysql -u root -p < backend/schema.sql
```

Or paste the contents of `schema.sql` into MySQL Workbench.

---

## Step 3 — Configure DB credentials

Edit the `DB_CONFIG` block in `backend/app.py`:

```python
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'YOUR_PASSWORD',
    'database': 'flight_disruption_db',
}
```

Or set environment variables:
```bash
export DB_HOST=localhost
export DB_USER=root
export DB_PASSWORD=your_password
export DB_NAME=flight_disruption_db
```

---

## Step 4 — Install Python dependencies

```bash
cd backend
pip install -r requirements.txt
```

---

## Step 5 — Run the app

```bash
cd backend
python app.py
```

Open in browser: **http://localhost:5000**

---

## DBMS Concepts Covered

| Concept | Where |
|---|---|
| DDL (CREATE TABLE, constraints) | schema.sql → all core tables |
| DML (INSERT, UPDATE, DELETE) | All pages → CRUD operations |
| JOINs (INNER, LEFT, multi-table) | /api/flights, /api/disruptions, /api/bookings |
| Views | delayed_flights, passenger_view, surge_view |
| Triggers (BEFORE/AFTER INSERT) | trg_prevent_fatigued_*, trg_update_duty_hours, trg_log_surge |
| Stored Procedures + Cursor | sp_scan_fatigue(), sp_scan_pilot_fatigue() |
| Normalization (UNF → 5NF + BCNF) | /normalization page |
| Aggregate Functions | /analytics — COUNT, SUM, MIN, MAX, AVG, GROUP BY |
| SET Operations | /analytics — UNION, INTERSECT, EXCEPT |
| Subqueries | /fare — above-avg surge; /analytics |
| Transaction Control (COMMIT/ROLLBACK) | /concurrency — all demos |
| Savepoints | /concurrency — savepoint demo |
| Isolation Levels (SERIALIZABLE) | /concurrency — transfer demo |
| Recovery (WAL simulation) | /concurrency — crash simulation |
| Constraints (PK, FK, CHECK, UNIQUE) | schema.sql — every table |

---

## Pages

| Page | URL | Key DBMS Feature |
|---|---|---|
| Dashboard | / | Stats overview |
| Flights | /flights | DDL/DML/JOIN, delayed_flights VIEW |
| Disruptions | /disruptions | TRIGGERS, cascade status update |
| Crew & Pilots | /crew | Safety triggers, CURSOR procedure |
| Bookings | /bookings | passenger_view VIEW, constraints |
| Fare & Surge | /fare | surge_view, subqueries, policy constraints |
| Live Radar | /radar | Multi-table JOIN, visual map |
| Normalization | /normalization | UNF/1NF/2NF/3NF/BCNF/4NF/5NF |
| Concurrency | /concurrency | ACID, SERIALIZABLE, SAVEPOINT, WAL |
| Analytics | /analytics | Aggregates, SET ops, subqueries, charts |
