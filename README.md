# ✈ Flight Disruption Management System (FDMS)

A full-stack web application for real-time airline disruption monitoring, crew safety management, and dynamic fare control. Built to handle the operational complexity of flight disruptions — from weather events and technical faults to crew fatigue and ATC holds — with automated decision support and live analytics.

---

## Overview

FDMS gives airline operations teams a single, unified interface to monitor flight status, file disruption events, manage crew assignments safely, enforce fare surge policies, and track recovery decisions — all backed by a relational data store with automated safety logic built directly into the data layer.

The system is designed around a core problem: **when a flight is disrupted, many things need to happen at once** — the flight status must change, prices must be controlled, fatigued crew must not be assigned, and management decisions must be recorded with full traceability. FDMS automates the routine parts and surfaces the critical information instantly.

---

## Features

### 🛫 Flight Operations
- Full CRUD management for flights across multiple airlines and airports
- Real-time status tracking: Scheduled, Delayed, Cancelled, Departed, Landed, Diverted
- Filter and search flights by status, route, or airline
- Automatic status updates triggered by disruption severity

### ⚡ Disruption Management
- File disruption events with type (Weather, Technical, Crew, ATC, Security) and severity (Low → Critical)
- Automated flight status propagation — High/Critical disruptions instantly mark flights as Delayed
- Automated price surge logging on disruption filing based on pre-configured fare policies
- Full management decision trail: who decided what, when, and for which disruption

### 👤 Crew & Pilot Safety
- Pilot and cabin crew roster with fatigue status tracking
- **Safety enforcement**: the system blocks assignment of any crew member or pilot marked as Fatigued — this cannot be bypassed through the UI
- Automated duty hour accumulation: every assignment updates cumulative hours and auto-flags fatigue when the 8-hour threshold is exceeded
- Batch fatigue scan: runs a row-by-row audit of all crew and flags violations in bulk
- Crew fatigue log with severity classification (Normal / Mild / Moderate / Severe)

### 🎫 Bookings & Passengers
- Passenger registry with booking history
- Booking management with base fare and total fare tracking
- Passenger summary view: total bookings, total spend, and all flights in one place
- Fare integrity enforcement: total fare cannot fall below base fare

### 💹 Fare & Surge Control
- Per-disruption-type fare policy configuration with price multiplier caps
- Real-time surge compliance view — flags any surge that exceeds the configured policy
- Price surge log with auto-insertion on disruption events
- Above-average surge detection using aggregate comparison

### 📡 Live Radar
- Positional data for active flights: latitude, longitude, altitude, speed
- Canvas-rendered map of active flight positions over India
- Auto-refreshes every 30 seconds

### 📊 Analytics
- Disruption frequency breakdown by type with active vs. resolved counts
- Flight performance by airline: total flights, delayed count, cancelled count
- Fare statistics per flight: minimum, maximum, and average fares
- Set-based safety analysis: identifies fatigued pilots still assigned (intersection), and those correctly grounded (difference)
- Above-average price surge detection

### 🔒 Data Integrity & Automation
- Automated safety triggers prevent unsafe crew assignments
- Automated audit logging for duty hours and fatigue events
- Fare surge auto-logging on disruption creation
- Transaction-safe operations with rollback on failure
- Savepoint support for partial operation recovery
- Full isolation level control for concurrent fare operations

### 🔣 Data Architecture Explorer
- Complete normalization progression from raw unnormalized form through 1NF, 2NF, 3NF, BCNF, 4NF, and 5NF
- Interactive explorer showing each normal form with live table data and plain-language explanations
- 32+ purpose-built tables covering operations, crew, fares, radar, and audit trails

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.x, Flask 3.0 |
| Database | MySQL 8.x |
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| DB Connector | mysql-connector-python |
| Rendering | HTML5 Canvas (radar map), dynamic DOM |
| Fonts | Google Fonts — Syne + Space Mono |

---

## Project Structure

```
flight_app/
├── backend/
│   ├── app.py              ← REST API — all routes and business logic
│   ├── schema.sql          ← Complete schema: tables, views, triggers,
│   │                           stored procedures, seed data
│   └── requirements.txt    ← Python dependencies
│
└── frontend/
    ├── templates/
    │   ├── index.html          ← Dashboard
    │   ├── flights.html        ← Flight management
    │   ├── disruptions.html    ← Disruption filing & decisions
    │   ├── crew.html           ← Crew/pilot management & fatigue
    │   ├── bookings.html       ← Bookings & passengers
    │   ├── fare.html           ← Fare policy & surge control
    │   ├── radar.html          ← Live positional radar
    │   ├── normalization.html  ← Data architecture explorer
    │   ├── concurrency.html    ← Transaction & recovery demos
    │   └── analytics.html      ← Operational analytics
    └── static/
        ├── css/main.css        ← Dark-theme design system
        └── js/main.js          ← Shared API client & UI utilities
```

---

## Installation & Setup

### Prerequisites
- Python 3.8 or higher
- MySQL 8.0 or higher
- pip

### Step 1 — Clone the repository

```bash
git clone https://github.com/your-username/flight-disruption-management.git
cd flight-disruption-management
```

### Step 2 — Set up the database

Open MySQL and run the schema file:

```bash
mysql -u root -p < backend/schema.sql
```

This creates the `flight_disruption_db` database, all tables, views, triggers, stored procedures, and loads seed data (5+ rows per table).

### Step 3 — Configure database credentials

Edit `backend/app.py` and update the `DB_CONFIG` block:

```python
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'YOUR_PASSWORD',
    'database': 'flight_disruption_db',
}
```

Or use environment variables:

```bash
export DB_HOST=localhost
export DB_USER=root
export DB_PASSWORD=your_password
export DB_NAME=flight_disruption_db
```

### Step 4 — Install Python dependencies

```bash
cd backend
pip install -r requirements.txt
```

### Step 5 — Run the application

```bash
python app.py
```

Open your browser at: **http://localhost:5000**

---

## API Reference

All endpoints return JSON. Base URL: `http://localhost:5000`

### Flights
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/flights` | All flights with airline and airport details |
| GET | `/api/flights/:id` | Single flight with radar data |
| POST | `/api/flights` | Add a new flight |
| PUT | `/api/flights/:id` | Update flight status |
| DELETE | `/api/flights/:id` | Delete a flight |
| GET | `/api/delayed-flights` | Query the delayed_flights view |

### Disruptions
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/disruptions` | All disruption events |
| POST | `/api/disruptions` | File a disruption (triggers fire automatically) |
| PUT | `/api/disruptions/:id` | Update resolution status |
| GET | `/api/decisions` | All management decisions |
| POST | `/api/decisions` | Record a management decision |

### Crew & Pilots
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/pilots` | All pilots with fatigue status |
| POST | `/api/pilots` | Add a pilot |
| GET | `/api/cabin-crew` | All cabin crew |
| POST | `/api/cabin-crew` | Add crew member |
| GET | `/api/crew-assignments` | All crew assignments |
| POST | `/api/crew-assignments` | Assign crew (triggers fire on INSERT) |
| GET | `/api/fatigue-log` | Crew fatigue log |
| GET | `/api/cursor/fatigue-scan` | Run batch fatigue audit |

### Bookings & Passengers
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/passengers` | All passengers |
| POST | `/api/passengers` | Add passenger |
| GET | `/api/bookings` | All bookings |
| POST | `/api/bookings` | Create a booking |
| GET | `/api/passenger-view` | Passenger summary view |

### Fare & Surge
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/fare-policies` | All fare policies |
| POST | `/api/fare-policies` | Add fare policy |
| GET | `/api/surge-log` | Price surge log |
| GET | `/api/surge-view` | Surge compliance view |

### Analytics
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/stats` | Dashboard summary counts |
| GET | `/api/analytics/disruptions-by-type` | Disruption frequency by type |
| GET | `/api/analytics/fare-stats` | MIN/MAX/AVG fare per flight |
| GET | `/api/analytics/flights-by-airline` | Flight counts per airline |
| GET | `/api/analytics/set-operations` | Crew safety set analysis |
| GET | `/api/analytics/above-avg-surge` | Above-average surge query |

### Concurrency & Recovery
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/concurrency/transfer` | SERIALIZABLE fare transfer |
| POST | `/api/concurrency/savepoint` | Savepoint demo |
| GET | `/api/cursor/fatigue-scan` | Cursor-based batch scan |
| POST | `/api/recovery/simulate` | WAL crash/recovery simulation |

### Normalization Explorer
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/normalization/:form` | Query any normalization table |

Supported `:form` values: `unf`, `1nf`, `2nf`, `3nf`, `bcnf`, `4nf_crew`, `4nf_pilot`, `5nf_crew`, `5nf_pilot`, `booking2nf`, `passenger2nf`, `airport3nf`, `pilot3nf`, `pilotbcnf`

---

## Automated Safety Logic

The following behaviours are built into the data layer and fire automatically regardless of how data enters the system:

| Trigger | Fires On | Behaviour |
|---|---|---|
| `trg_prevent_fatigued_pilot` | BEFORE INSERT — crew_assignment | Blocks assignment if pilot is Fatigued |
| `trg_prevent_fatigued_crew` | BEFORE INSERT — crew_assignment | Blocks assignment if crew is Fatigued |
| `trg_update_pilot_duty_hours` | AFTER INSERT — crew_assignment | Accumulates duty hours; flags fatigue above 8h |
| `trg_log_surge_on_disruption` | AFTER INSERT — disruption_event | Auto-inserts surge log entry based on fare policy |
| `trg_flight_status_on_disruption` | AFTER INSERT — disruption_event | Auto-delays flight on High or Critical severity |

Stored procedures `sp_scan_fatigue()` and `sp_scan_pilot_fatigue()` provide batch-mode equivalents using server-side cursors.

---

## Seed Data

The schema loads the following sample data on setup:

- 5 airlines (IndiGo, Air India, SpiceJet, Vistara, AirAsia India)
- 6 airports (Delhi, Mumbai, Bengaluru, Chennai, Hyderabad, Kolkata)
- 5 aircraft models
- 6 flights across domestic and international routes
- 6 pilots (mix of Active, Fatigued, On Leave statuses)
- 6 cabin crew members
- 6 disruption events covering all severity levels and types
- 6 management decisions
- 6 passengers with bookings
- Fare policies for all disruption types
- Normalization tables populated with equivalent data across all forms (UNF through 5NF)

---

## Design System

- Dark theme throughout — `#0a0c10` base background
- Color-coded severity: green (Low) → blue (Medium) → amber (High) → red (Critical)
- Monospace font (Space Mono) for IDs, numeric values, and code displays
- Sans-serif (Syne) for navigation and body content
- Responsive sidebar — collapses to icon-only on narrow viewports
- Live clock in IST on the dashboard header
- Toast notifications for all create, update, delete, and error operations

---

## Pages at a Glance

| URL | Module | Key Functionality |
|---|---|---|
| `/` | Dashboard | Live stats, active disruptions, fatigue alerts, surge summary |
| `/flights` | Flights | CRUD, status management, delayed view |
| `/disruptions` | Disruptions | File events, trigger chain, management decisions |
| `/crew` | Crew & Pilots | Assignments, safety blocks, cursor batch scan |
| `/bookings` | Bookings | Passenger registry, booking history, summary view |
| `/fare` | Fare & Surge | Policy config, surge compliance, subquery analysis |
| `/radar` | Live Radar | Canvas map, positional cards |
| `/normalization` | Architecture | UNF → 5NF interactive explorer |
| `/concurrency` | Transactions | SERIALIZABLE, savepoints, WAL simulation |
| `/analytics` | Analytics | Charts, aggregates, set analysis |

---

## License

MIT License. Free to use, modify, and distribute.

---

## Contributing

Pull requests welcome. For major changes, open an issue first to discuss what you would like to change.

---

*All airline names, flight numbers, and passenger data in the seed dataset are entirely fictional and used for demonstration purposes only.*
