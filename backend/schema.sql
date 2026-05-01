-- ══════════════════════════════════════════════════════════════════════════════
-- DISRUPTION-AWARE FLIGHT MANAGEMENT SYSTEM
-- Full DDL + DML + Constraints + Views + Triggers + Cursors + Normalization
-- ══════════════════════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS flight_disruption_db;
USE flight_disruption_db;

-- ─────────────────────────────────────────────────────────────────────────────
-- DDL: CORE TABLES (with constraints)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE airline (
    airline_id      INT AUTO_INCREMENT PRIMARY KEY,
    airline_name    VARCHAR(100) NOT NULL UNIQUE,
    headquarters    VARCHAR(100),
    contact_no      VARCHAR(20) CHECK (contact_no REGEXP '^[0-9+\\-() ]{7,20}$')
);

CREATE TABLE airport (
    airport_id      INT AUTO_INCREMENT PRIMARY KEY,
    airport_name    VARCHAR(150) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    CONSTRAINT uq_airport UNIQUE (airport_name, city)
);

CREATE TABLE aircraft (
    aircraft_id      INT AUTO_INCREMENT PRIMARY KEY,
    model            VARCHAR(100) NOT NULL,
    capacity         INT NOT NULL CHECK (capacity > 0),
    manufacture_year INT CHECK (manufacture_year BETWEEN 1950 AND 2100)
);

CREATE TABLE flight (
    flight_id               INT AUTO_INCREMENT PRIMARY KEY,
    flight_number           VARCHAR(20) NOT NULL UNIQUE,
    flight_type             ENUM('Domestic','International') NOT NULL,
    scheduled_departure     DATETIME NOT NULL,
    scheduled_arrival       DATETIME NOT NULL,
    actual_departure        DATETIME,
    actual_arrival          DATETIME,
    flight_status           ENUM('Scheduled','Delayed','Cancelled','Departed','Landed','Diverted') DEFAULT 'Scheduled',
    airline_id              INT NOT NULL,
    source_airport_id       INT NOT NULL,
    destination_airport_id  INT NOT NULL,
    CONSTRAINT fk_fl_airline  FOREIGN KEY (airline_id) REFERENCES airline(airline_id) ON DELETE RESTRICT,
    CONSTRAINT fk_fl_src      FOREIGN KEY (source_airport_id) REFERENCES airport(airport_id),
    CONSTRAINT fk_fl_dst      FOREIGN KEY (destination_airport_id) REFERENCES airport(airport_id),
    CONSTRAINT chk_fl_times   CHECK (scheduled_arrival > scheduled_departure),
    CONSTRAINT chk_fl_airports CHECK (source_airport_id <> destination_airport_id)
);

CREATE TABLE flight_radar (
    radar_id          INT AUTO_INCREMENT PRIMARY KEY,
    latitude          DECIMAL(9,6) CHECK (latitude BETWEEN -90 AND 90),
    longitude         DECIMAL(9,6) CHECK (longitude BETWEEN -180 AND 180),
    altitude          INT CHECK (altitude >= 0),
    speed             INT CHECK (speed >= 0),
    last_updated_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    flight_id         INT NOT NULL UNIQUE,
    CONSTRAINT fk_radar_flight FOREIGN KEY (flight_id) REFERENCES flight(flight_id) ON DELETE CASCADE
);

CREATE TABLE pilot (
    pilot_id         INT AUTO_INCREMENT PRIMARY KEY,
    pilot_name       VARCHAR(100) NOT NULL,
    license_no       VARCHAR(50) NOT NULL UNIQUE,
    experience_years INT DEFAULT 0 CHECK (experience_years >= 0),
    fatigue_status   ENUM('Active','Fatigued','On Leave') DEFAULT 'Active',
    total_duty_hours DECIMAL(6,2) DEFAULT 0 CHECK (total_duty_hours >= 0)
);

CREATE TABLE cabin_crew (
    crew_id          INT AUTO_INCREMENT PRIMARY KEY,
    crew_name        VARCHAR(100) NOT NULL,
    experience_years INT DEFAULT 0 CHECK (experience_years >= 0),
    fatigue_status   ENUM('Active','Fatigued','On Leave') DEFAULT 'Active',
    total_duty_hours DECIMAL(6,2) DEFAULT 0 CHECK (total_duty_hours >= 0)
);

CREATE TABLE crew_assignment (
    assignment_id   INT AUTO_INCREMENT PRIMARY KEY,
    role            VARCHAR(50) NOT NULL,
    duty_start_time DATETIME NOT NULL,
    duty_end_time   DATETIME NOT NULL,
    duty_hours      DECIMAL(5,2) CHECK (duty_hours > 0 AND duty_hours <= 14),
    flight_id       INT NOT NULL,
    pilot_id        INT,
    crew_id         INT,
    CONSTRAINT fk_ca_flight FOREIGN KEY (flight_id) REFERENCES flight(flight_id),
    CONSTRAINT fk_ca_pilot  FOREIGN KEY (pilot_id)  REFERENCES pilot(pilot_id),
    CONSTRAINT fk_ca_crew   FOREIGN KEY (crew_id)   REFERENCES cabin_crew(crew_id),
    CONSTRAINT chk_ca_times CHECK (duty_end_time > duty_start_time),
    CONSTRAINT chk_ca_has_member CHECK (pilot_id IS NOT NULL OR crew_id IS NOT NULL)
);

CREATE TABLE disruption_event (
    disruption_id     INT AUTO_INCREMENT PRIMARY KEY,
    disruption_type   ENUM('Weather','Technical','Crew','ATC','Security','Other') NOT NULL,
    severity_level    ENUM('Low','Medium','High','Critical') NOT NULL,
    reported_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolution_status ENUM('Active','Resolved','Monitoring') DEFAULT 'Active',
    flight_id         INT NOT NULL,
    CONSTRAINT fk_de_flight FOREIGN KEY (flight_id) REFERENCES flight(flight_id)
);

CREATE TABLE management_decision (
    decision_id   INT AUTO_INCREMENT PRIMARY KEY,
    decision_taken VARCHAR(500) NOT NULL,
    decision_time  DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_by    VARCHAR(100) NOT NULL,
    disruption_id  INT NOT NULL,
    CONSTRAINT fk_md_disruption FOREIGN KEY (disruption_id) REFERENCES disruption_event(disruption_id)
);

CREATE TABLE fare_policy (
    policy_id           INT AUTO_INCREMENT PRIMARY KEY,
    disruption_type     ENUM('Weather','Technical','Crew','ATC','Security','Other') NOT NULL UNIQUE,
    max_price_multiplier DECIMAL(4,2) NOT NULL CHECK (max_price_multiplier >= 1.0 AND max_price_multiplier <= 5.0),
    applicable_duration INT NOT NULL COMMENT 'Duration in hours',
    CONSTRAINT chk_fp_duration CHECK (applicable_duration > 0)
);

CREATE TABLE passenger (
    passenger_id   INT AUTO_INCREMENT PRIMARY KEY,
    passenger_name VARCHAR(100) NOT NULL,
    contact_no     VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE booking (
    booking_id   INT AUTO_INCREMENT PRIMARY KEY,
    booking_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    base_fare    DECIMAL(10,2) NOT NULL CHECK (base_fare > 0),
    total_fare   DECIMAL(10,2) NOT NULL CHECK (total_fare >= base_fare),
    passenger_id INT NOT NULL,
    flight_id    INT NOT NULL,
    CONSTRAINT fk_bk_passenger FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id),
    CONSTRAINT fk_bk_flight    FOREIGN KEY (flight_id) REFERENCES flight(flight_id),
    CONSTRAINT uq_bk UNIQUE (passenger_id, flight_id)
);

CREATE TABLE price_surge_log (
    surge_id        INT AUTO_INCREMENT PRIMARY KEY,
    surge_percentage DECIMAL(5,2) NOT NULL CHECK (surge_percentage >= 0),
    surge_reason    VARCHAR(300),
    surge_time      DATETIME DEFAULT CURRENT_TIMESTAMP,
    flight_id       INT NOT NULL,
    CONSTRAINT fk_psl_flight FOREIGN KEY (flight_id) REFERENCES flight(flight_id)
);

CREATE TABLE crew_fatigue_log (
    fatigue_id    INT AUTO_INCREMENT PRIMARY KEY,
    fatigue_level ENUM('Normal','Mild','Moderate','Severe') NOT NULL,
    recorded_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    pilot_id      INT,
    crew_id       INT,
    flight_id     INT NOT NULL,
    CONSTRAINT fk_cfl_pilot  FOREIGN KEY (pilot_id)  REFERENCES pilot(pilot_id),
    CONSTRAINT fk_cfl_crew   FOREIGN KEY (crew_id)   REFERENCES cabin_crew(crew_id),
    CONSTRAINT fk_cfl_flight FOREIGN KEY (flight_id) REFERENCES flight(flight_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- NORMALIZATION TABLES (1NF → 5NF + BCNF)
-- ─────────────────────────────────────────────────────────────────────────────

-- UNF: Unnormalized (repeating groups)
CREATE TABLE flight_unnormalized (
    flight_id INT, flight_number VARCHAR(20),
    pilot_names TEXT,       -- "Alice, Bob" — violates 1NF
    crew_names TEXT,        -- "Carol, Dave, Eve" — violates 1NF
    source_city VARCHAR(100), dest_city VARCHAR(100),
    fare_classes TEXT       -- "Economy,Business" — violates 1NF
);

-- 1NF: Atomic values, no repeating groups
CREATE TABLE flight_1nf (
    flight_id INT, flight_number VARCHAR(20),
    pilot_name VARCHAR(100),    -- one pilot per row
    crew_name  VARCHAR(100),    -- one crew per row
    source_city VARCHAR(100), dest_city VARCHAR(100),
    fare_class VARCHAR(50)
);

-- 2NF: Remove partial dependencies (all non-key attrs fully dependent on PK)
CREATE TABLE flight_2nf (
    flight_id   INT,
    pilot_id    INT,
    crew_id     INT,
    fare_class  VARCHAR(50),
    PRIMARY KEY (flight_id, pilot_id, crew_id)
);

-- 3NF: Remove transitive dependencies
CREATE TABLE flight_3nf (
    flight_id   INT PRIMARY KEY,
    flight_number VARCHAR(20),
    flight_type ENUM('Domestic','International'),
    scheduled_departure DATETIME,
    airline_id  INT,
    source_airport_id INT,
    destination_airport_id INT
);

-- BCNF: Every determinant is a candidate key
CREATE TABLE flight_pilot_bcnf (
    assignment_id INT PRIMARY KEY,
    flight_id INT, pilot_id INT,
    license_no VARCHAR(50) UNIQUE,  -- license_no → pilot_id (was transitive in pilot table)
    role VARCHAR(50)
);

-- 4NF: Remove multi-valued dependencies
CREATE TABLE flight_crew_4nf (
    flight_id INT,
    crew_id   INT,
    PRIMARY KEY (flight_id, crew_id)
);

CREATE TABLE flight_pilot_4nf (
    flight_id INT,
    pilot_id  INT,
    PRIMARY KEY (flight_id, pilot_id)
);

-- 5NF: Remove join dependencies (decomposed to lossless joins)
CREATE TABLE flight_crew_5nf (
    flight_id INT, crew_id INT,
    PRIMARY KEY (flight_id, crew_id)
);

CREATE TABLE flight_pilot_5nf (
    flight_id INT, pilot_id INT,
    PRIMARY KEY (flight_id, pilot_id)
);

-- 2NF versions of booking and passenger
CREATE TABLE booking_2nf (
    booking_id INT PRIMARY KEY,
    booking_date DATE,
    base_fare DECIMAL(10,2),
    total_fare DECIMAL(10,2),
    passenger_id INT,
    flight_id INT
);

CREATE TABLE passenger_2nf (
    passenger_id INT PRIMARY KEY,
    passenger_name VARCHAR(100),
    contact_no VARCHAR(20)
);

-- 3NF versions
CREATE TABLE airport_3nf (
    airport_id INT PRIMARY KEY,
    airport_name VARCHAR(150),
    city VARCHAR(100),
    country VARCHAR(100)
);

CREATE TABLE pilot_3nf (
    pilot_id INT PRIMARY KEY,
    pilot_name VARCHAR(100),
    license_no VARCHAR(50),
    experience_years INT,
    fatigue_status VARCHAR(20),
    total_duty_hours DECIMAL(6,2)
);

CREATE TABLE pilot_bcnf (
    license_no VARCHAR(50) PRIMARY KEY,
    pilot_id INT UNIQUE,
    pilot_name VARCHAR(100),
    experience_years INT
);

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEWS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW delayed_flights AS
    SELECT f.flight_id, f.flight_number, f.flight_status,
           f.scheduled_departure, f.actual_departure,
           TIMESTAMPDIFF(MINUTE, f.scheduled_departure, f.actual_departure) AS delay_minutes,
           al.airline_name,
           src.city AS from_city, dst.city AS to_city
    FROM flight f
    JOIN airline al ON f.airline_id = al.airline_id
    JOIN airport src ON f.source_airport_id = src.airport_id
    JOIN airport dst ON f.destination_airport_id = dst.airport_id
    WHERE f.flight_status IN ('Delayed','Cancelled')
       OR f.actual_departure > f.scheduled_departure;

CREATE OR REPLACE VIEW passenger_view AS
    SELECT p.passenger_id, p.passenger_name, p.contact_no,
           COUNT(b.booking_id) AS total_bookings,
           SUM(b.total_fare) AS total_spent,
           GROUP_CONCAT(f.flight_number SEPARATOR ', ') AS flights_booked
    FROM passenger p
    LEFT JOIN booking b ON p.passenger_id = b.passenger_id
    LEFT JOIN flight f  ON b.flight_id = f.flight_id
    GROUP BY p.passenger_id, p.passenger_name, p.contact_no;

CREATE OR REPLACE VIEW surge_view AS
    SELECT psl.surge_id, f.flight_number, f.flight_status,
           psl.surge_percentage, psl.surge_reason, psl.surge_time,
           fp.max_price_multiplier,
           CASE WHEN (psl.surge_percentage/100) + 1 > fp.max_price_multiplier
                THEN 'POLICY VIOLATED'
                ELSE 'Within Policy'
           END AS policy_compliance
    FROM price_surge_log psl
    JOIN flight f ON psl.flight_id = f.flight_id
    LEFT JOIN disruption_event de ON de.flight_id = f.flight_id
    LEFT JOIN fare_policy fp ON fp.disruption_type = de.disruption_type;

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

DELIMITER $$

-- Trigger 1: Prevent fatigued pilot assignment
CREATE TRIGGER trg_prevent_fatigued_pilot
BEFORE INSERT ON crew_assignment
FOR EACH ROW
BEGIN
    DECLARE pilot_fatigue VARCHAR(20);
    IF NEW.pilot_id IS NOT NULL THEN
        SELECT fatigue_status INTO pilot_fatigue
        FROM pilot WHERE pilot_id = NEW.pilot_id;
        IF pilot_fatigue = 'Fatigued' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SAFETY BLOCK: Cannot assign fatigued pilot to flight.';
        END IF;
    END IF;
END$$

-- Trigger 2: Prevent fatigued cabin crew assignment
CREATE TRIGGER trg_prevent_fatigued_crew
BEFORE INSERT ON crew_assignment
FOR EACH ROW
BEGIN
    DECLARE crew_fatigue VARCHAR(20);
    IF NEW.crew_id IS NOT NULL THEN
        SELECT fatigue_status INTO crew_fatigue
        FROM cabin_crew WHERE crew_id = NEW.crew_id;
        IF crew_fatigue = 'Fatigued' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SAFETY BLOCK: Cannot assign fatigued cabin crew to flight.';
        END IF;
    END IF;
END$$

-- Trigger 3: Auto-update pilot total duty hours after assignment
CREATE TRIGGER trg_update_pilot_duty_hours
AFTER INSERT ON crew_assignment
FOR EACH ROW
BEGIN
    IF NEW.pilot_id IS NOT NULL THEN
        UPDATE pilot
        SET total_duty_hours = total_duty_hours + NEW.duty_hours
        WHERE pilot_id = NEW.pilot_id;
        -- Auto-flag as fatigued if over duty limit
        UPDATE pilot
        SET fatigue_status = 'Fatigued'
        WHERE pilot_id = NEW.pilot_id AND total_duty_hours > 8;
    END IF;
    IF NEW.crew_id IS NOT NULL THEN
        UPDATE cabin_crew
        SET total_duty_hours = total_duty_hours + NEW.duty_hours
        WHERE crew_id = NEW.crew_id;
        UPDATE cabin_crew
        SET fatigue_status = 'Fatigued'
        WHERE crew_id = NEW.crew_id AND total_duty_hours > 8;
    END IF;
END$$

-- Trigger 4: Log price surge automatically when disruption is filed
CREATE TRIGGER trg_log_surge_on_disruption
AFTER INSERT ON disruption_event
FOR EACH ROW
BEGIN
    DECLARE multiplier DECIMAL(4,2);
    SELECT max_price_multiplier INTO multiplier
    FROM fare_policy WHERE disruption_type = NEW.disruption_type;
    IF multiplier IS NOT NULL AND multiplier > 1.0 THEN
        INSERT INTO price_surge_log (surge_percentage, surge_reason, flight_id)
        VALUES ((multiplier - 1.0) * 100,
                CONCAT('Auto-surge: ', NEW.disruption_type, ' (', NEW.severity_level, ')'),
                NEW.flight_id);
    END IF;
END$$

-- Trigger 5: Update flight status to Delayed on new disruption
CREATE TRIGGER trg_flight_status_on_disruption
AFTER INSERT ON disruption_event
FOR EACH ROW
BEGIN
    IF NEW.severity_level IN ('High','Critical') THEN
        UPDATE flight SET flight_status = 'Delayed'
        WHERE flight_id = NEW.flight_id AND flight_status = 'Scheduled';
    END IF;
END$$

DELIMITER ;

-- ─────────────────────────────────────────────────────────────────────────────
-- STORED PROCEDURE with CURSOR (fatigue batch scan)
-- ─────────────────────────────────────────────────────────────────────────────

DELIMITER $$

CREATE PROCEDURE sp_scan_fatigue()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_crew_id INT;
    DECLARE v_duty_hours DECIMAL(6,2);
    DECLARE v_name VARCHAR(100);

    DECLARE cur_crew CURSOR FOR
        SELECT crew_id, crew_name, total_duty_hours FROM cabin_crew;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_crew;
    read_loop: LOOP
        FETCH cur_crew INTO v_crew_id, v_name, v_duty_hours;
        IF done THEN LEAVE read_loop; END IF;
        IF v_duty_hours > 8 THEN
            UPDATE cabin_crew SET fatigue_status='Fatigued' WHERE crew_id = v_crew_id;
            INSERT INTO crew_fatigue_log (fatigue_level, crew_id, flight_id)
            SELECT CASE
                     WHEN v_duty_hours > 12 THEN 'Severe'
                     WHEN v_duty_hours > 10 THEN 'Moderate'
                     ELSE 'Mild'
                   END,
                   v_crew_id,
                   flight_id
            FROM crew_assignment WHERE crew_id = v_crew_id ORDER BY duty_end_time DESC LIMIT 1;
        END IF;
    END LOOP;
    CLOSE cur_crew;
END$$

-- Stored procedure with cursor for pilot duty scan
CREATE PROCEDURE sp_scan_pilot_fatigue()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_pilot_id INT;
    DECLARE v_duty_hours DECIMAL(6,2);

    DECLARE cur_pilot CURSOR FOR
        SELECT pilot_id, total_duty_hours FROM pilot;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_pilot;
    scan_loop: LOOP
        FETCH cur_pilot INTO v_pilot_id, v_duty_hours;
        IF done THEN LEAVE scan_loop; END IF;
        IF v_duty_hours > 8 THEN
            UPDATE pilot SET fatigue_status='Fatigued' WHERE pilot_id = v_pilot_id;
        END IF;
    END LOOP;
    CLOSE cur_pilot;
END$$

DELIMITER ;

-- ─────────────────────────────────────────────────────────────────────────────
-- DML: SEED DATA (5+ rows per table)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO airline (airline_name, headquarters, contact_no) VALUES
('IndiGo', 'Gurugram, India', '+91-124-6612345'),
('Air India', 'New Delhi, India', '+91-11-24626000'),
('SpiceJet', 'Gurugram, India', '+91-987-6543210'),
('Vistara', 'Gurugram, India', '+91-11-71800909'),
('AirAsia India', 'Bengaluru, India', '+91-80-46626262');

INSERT INTO airport (airport_name, city, country) VALUES
('Indira Gandhi International Airport', 'New Delhi', 'India'),
('Chhatrapati Shivaji Maharaj International Airport', 'Mumbai', 'India'),
('Kempegowda International Airport', 'Bengaluru', 'India'),
('Chennai International Airport', 'Chennai', 'India'),
('Rajiv Gandhi International Airport', 'Hyderabad', 'India'),
('Netaji Subhas Chandra Bose International Airport', 'Kolkata', 'India');

INSERT INTO aircraft (model, capacity, manufacture_year) VALUES
('Airbus A320', 180, 2018),
('Boeing 737-800', 162, 2019),
('Airbus A321neo', 232, 2021),
('Boeing 777-300ER', 342, 2016),
('ATR 72-600', 70, 2020);

INSERT INTO flight (flight_number, flight_type, scheduled_departure, scheduled_arrival,
                    actual_departure, actual_arrival, flight_status,
                    airline_id, source_airport_id, destination_airport_id) VALUES
('6E-201', 'Domestic', '2025-06-01 06:00:00', '2025-06-01 08:30:00',
 '2025-06-01 06:45:00', '2025-06-01 09:20:00', 'Delayed', 1, 1, 2),
('AI-102', 'Domestic', '2025-06-01 09:00:00', '2025-06-01 11:45:00',
 '2025-06-01 09:00:00', '2025-06-01 11:45:00', 'Landed', 2, 1, 3),
('SG-305', 'Domestic', '2025-06-01 12:00:00', '2025-06-01 14:15:00',
 NULL, NULL, 'Cancelled', 3, 2, 4),
('UK-901', 'International', '2025-06-02 01:00:00', '2025-06-02 05:30:00',
 '2025-06-02 01:25:00', NULL, 'Departed', 4, 1, 5),
('I5-412', 'Domestic', '2025-06-02 08:00:00', '2025-06-02 10:20:00',
 NULL, NULL, 'Scheduled', 5, 3, 6),
('6E-750', 'Domestic', '2025-06-02 14:00:00', '2025-06-02 16:45:00',
 '2025-06-02 15:30:00', NULL, 'Delayed', 1, 4, 1);

INSERT INTO flight_radar (latitude, longitude, altitude, speed, flight_id) VALUES
(19.0896, 72.8656, 33000, 820, 1),
(12.9716, 77.5946, 35000, 840, 2),
(28.6139, 77.2090, 0, 0, 4),
(17.3850, 78.4867, 28000, 780, 6);

INSERT INTO pilot (pilot_name, license_no, experience_years, fatigue_status, total_duty_hours) VALUES
('Capt. Arjun Sharma', 'DGCA-PIL-001', 12, 'Active', 6.5),
('Capt. Priya Nair', 'DGCA-PIL-002', 8, 'Fatigued', 10.2),
('Capt. Rahul Mehta', 'DGCA-PIL-003', 15, 'Active', 4.0),
('F/O Kavitha Reddy', 'DGCA-FO-001', 3, 'Active', 5.5),
('F/O Sanjay Iyer', 'DGCA-FO-002', 5, 'Fatigued', 9.8),
('Capt. Meera Pillai', 'DGCA-PIL-004', 10, 'On Leave', 0.0);

INSERT INTO cabin_crew (crew_name, experience_years, fatigue_status, total_duty_hours) VALUES
('Sneha Kulkarni', 6, 'Active', 5.0),
('Ravi Teja', 4, 'Fatigued', 11.5),
('Ananya Singh', 7, 'Active', 3.5),
('Deepak Joshi', 3, 'Active', 6.0),
('Lakshmi Prasad', 9, 'Active', 4.5),
('Vikas Bhat', 5, 'Fatigued', 9.2);

INSERT INTO crew_assignment (role, duty_start_time, duty_end_time, duty_hours,
                              flight_id, pilot_id, crew_id) VALUES
('Captain', '2025-06-01 05:00:00', '2025-06-01 09:30:00', 4.5, 1, 1, NULL),
('Cabin Crew', '2025-06-01 05:30:00', '2025-06-01 09:30:00', 4.0, 1, NULL, 1),
('Captain', '2025-06-01 08:00:00', '2025-06-01 12:00:00', 4.0, 2, 3, NULL),
('First Officer', '2025-06-01 08:00:00', '2025-06-01 12:00:00', 4.0, 2, 4, NULL),
('Cabin Crew', '2025-06-01 08:30:00', '2025-06-01 12:00:00', 3.5, 2, NULL, 3),
('Captain', '2025-06-02 00:00:00', '2025-06-02 05:30:00', 5.5, 4, 1, NULL);

INSERT INTO disruption_event (disruption_type, severity_level, reported_time,
                               resolution_status, flight_id) VALUES
('Weather', 'High', '2025-06-01 05:30:00', 'Active', 1),
('Crew', 'Critical', '2025-06-01 10:00:00', 'Active', 3),
('Technical', 'Medium', '2025-06-01 11:00:00', 'Resolved', 2),
('ATC', 'Low', '2025-06-02 01:15:00', 'Monitoring', 4),
('Security', 'High', '2025-06-02 07:30:00', 'Active', 5),
('Weather', 'Critical', '2025-06-02 13:00:00', 'Active', 6);

INSERT INTO management_decision (decision_taken, decision_time, approved_by, disruption_id) VALUES
('Deploy alternate crew; reroute via Jaipur', '2025-06-01 06:00:00', 'Ops Director', 1),
('Cancel flight SG-305; rebook passengers on next available', '2025-06-01 11:00:00', 'CEO', 2),
('Cleared technical fault; flight resumed', '2025-06-01 11:30:00', 'Tech Chief', 3),
('Holding pattern applied; ATC clearance in 45 min', '2025-06-02 01:30:00', 'Ops Manager', 4),
('Passenger screening extended; delay accepted', '2025-06-02 08:00:00', 'Security Head', 5),
('Ground stop until weather clears; passenger meals arranged', '2025-06-02 14:00:00', 'Ops Director', 6);

INSERT INTO fare_policy (disruption_type, max_price_multiplier, applicable_duration) VALUES
('Weather', 1.20, 24),
('Technical', 1.10, 12),
('Crew', 1.15, 18),
('ATC', 1.05, 6),
('Security', 1.10, 12),
('Other', 1.25, 24);

INSERT INTO passenger (passenger_name, contact_no) VALUES
('Aditya Kumar', '+91-9876543210'),
('Bhavna Sharma', '+91-9123456789'),
('Chetan Patel', '+91-8012345678'),
('Divya Menon', '+91-7890123456'),
('Eshan Rao', '+91-9988776655'),
('Fatima Sheikh', '+91-9765432109');

INSERT INTO booking (booking_date, base_fare, total_fare, passenger_id, flight_id) VALUES
('2025-05-20', 3500.00, 4200.00, 1, 1),
('2025-05-21', 4000.00, 4800.00, 2, 1),
('2025-05-22', 5500.00, 6000.00, 3, 2),
('2025-05-23', 6000.00, 7500.00, 4, 4),
('2025-05-24', 3200.00, 3200.00, 5, 5),
('2025-05-25', 2800.00, 3360.00, 6, 6);

INSERT INTO price_surge_log (surge_percentage, surge_reason, surge_time, flight_id) VALUES
(20.00, 'Weather disruption — High severity', '2025-06-01 05:35:00', 1),
(15.00, 'Crew shortage — flight cancellation risk', '2025-06-01 10:05:00', 3),
(5.00, 'ATC hold — minor delay expected', '2025-06-02 01:20:00', 4),
(10.00, 'Security delay — extended screening', '2025-06-02 07:35:00', 5),
(20.00, 'Severe weather — Critical disruption', '2025-06-02 13:05:00', 6),
(8.00, 'Precautionary surge — weather forecast', '2025-06-01 04:00:00', 1);

INSERT INTO crew_fatigue_log (fatigue_level, recorded_time, pilot_id, crew_id, flight_id) VALUES
('Severe', '2025-06-01 09:00:00', 2, NULL, 1),
('Moderate', '2025-06-01 09:00:00', NULL, 2, 1),
('Mild', '2025-06-01 12:00:00', NULL, 6, 2),
('Normal', '2025-06-02 05:30:00', 1, NULL, 4),
('Severe', '2025-06-01 10:00:00', 5, NULL, 3),
('Mild', '2025-06-02 10:20:00', 4, NULL, 5);

-- ─────────────────────────────────────────────────────────────────────────────
-- NORMALIZATION SEED DATA
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO flight_unnormalized VALUES
(1, '6E-201', 'Arjun Sharma, Priya Nair', 'Sneha K, Ravi T, Ananya S', 'Delhi', 'Mumbai', 'Economy,Business'),
(2, 'AI-102', 'Rahul Mehta', 'Deepak J, Lakshmi P', 'Delhi', 'Bengaluru', 'Economy,Business,First'),
(3, 'SG-305', 'Kavitha Reddy', 'Vikas B', 'Mumbai', 'Chennai', 'Economy'),
(4, 'UK-901', 'Arjun Sharma, Sanjay Iyer', 'Sneha K, Ananya S, Lakshmi P', 'Delhi', 'Hyderabad', 'Economy,Business'),
(5, 'I5-412', 'Meera Pillai', 'Ravi T', 'Bengaluru', 'Kolkata', 'Economy');

INSERT INTO flight_1nf VALUES
(1,'6E-201','Arjun Sharma','Sneha K','Delhi','Mumbai','Economy'),
(1,'6E-201','Arjun Sharma','Ravi T','Delhi','Mumbai','Economy'),
(1,'6E-201','Priya Nair','Ananya S','Delhi','Mumbai','Business'),
(2,'AI-102','Rahul Mehta','Deepak J','Delhi','Bengaluru','Economy'),
(2,'AI-102','Rahul Mehta','Lakshmi P','Delhi','Bengaluru','Business'),
(3,'SG-305','Kavitha Reddy','Vikas B','Mumbai','Chennai','Economy');

INSERT INTO flight_2nf VALUES
(1,1,1,'Economy'),(1,1,3,'Economy'),(1,2,2,'Business'),
(2,3,4,'Economy'),(2,3,5,'Business'),(3,4,6,'Economy');

INSERT INTO flight_3nf VALUES
(1,'6E-201','Domestic','2025-06-01 06:00:00',1,1,2),
(2,'AI-102','Domestic','2025-06-01 09:00:00',2,1,3),
(3,'SG-305','Domestic','2025-06-01 12:00:00',3,2,4),
(4,'UK-901','International','2025-06-02 01:00:00',4,1,5),
(5,'I5-412','Domestic','2025-06-02 08:00:00',5,3,6);

INSERT INTO flight_pilot_bcnf VALUES
(1,1,1,'DGCA-PIL-001','Captain'),
(2,2,3,'DGCA-PIL-003','Captain'),
(3,2,4,'DGCA-FO-001','First Officer'),
(4,4,1,'DGCA-PIL-001','Captain'),
(5,5,3,'DGCA-PIL-003','Captain'),
(6,6,1,'DGCA-PIL-001','Captain');

INSERT INTO flight_crew_4nf VALUES (1,1),(1,2),(2,3),(2,4),(3,5),(4,3);
INSERT INTO flight_pilot_4nf VALUES (1,1),(1,2),(2,3),(2,4),(3,4),(4,1);
INSERT INTO flight_crew_5nf VALUES (1,1),(1,2),(2,3),(3,5),(4,3),(5,6);
INSERT INTO flight_pilot_5nf VALUES (1,1),(2,3),(2,4),(3,4),(4,1),(5,3);

INSERT INTO booking_2nf VALUES
(1,'2025-05-20',3500,4200,1,1),(2,'2025-05-21',4000,4800,2,1),
(3,'2025-05-22',5500,6000,3,2),(4,'2025-05-23',6000,7500,4,4),
(5,'2025-05-24',3200,3200,5,5),(6,'2025-05-25',2800,3360,6,6);

INSERT INTO passenger_2nf VALUES
(1,'Aditya Kumar','+91-9876543210'),
(2,'Bhavna Sharma','+91-9123456789'),
(3,'Chetan Patel','+91-8012345678'),
(4,'Divya Menon','+91-7890123456'),
(5,'Eshan Rao','+91-9988776655'),
(6,'Fatima Sheikh','+91-9765432109');

INSERT INTO airport_3nf VALUES
(1,'Indira Gandhi International Airport','New Delhi','India'),
(2,'Chhatrapati Shivaji Maharaj Intl Airport','Mumbai','India'),
(3,'Kempegowda International Airport','Bengaluru','India'),
(4,'Chennai International Airport','Chennai','India'),
(5,'Rajiv Gandhi International Airport','Hyderabad','India'),
(6,'Netaji Subhas Chandra Bose Intl Airport','Kolkata','India');

INSERT INTO pilot_3nf VALUES
(1,'Capt. Arjun Sharma','DGCA-PIL-001',12,'Active',6.5),
(2,'Capt. Priya Nair','DGCA-PIL-002',8,'Fatigued',10.2),
(3,'Capt. Rahul Mehta','DGCA-PIL-003',15,'Active',4.0),
(4,'F/O Kavitha Reddy','DGCA-FO-001',3,'Active',5.5),
(5,'F/O Sanjay Iyer','DGCA-FO-002',5,'Fatigued',9.8),
(6,'Capt. Meera Pillai','DGCA-PIL-004',10,'On Leave',0.0);

INSERT INTO pilot_bcnf VALUES
('DGCA-PIL-001',1,'Capt. Arjun Sharma',12),
('DGCA-PIL-002',2,'Capt. Priya Nair',8),
('DGCA-PIL-003',3,'Capt. Rahul Mehta',15),
('DGCA-FO-001',4,'F/O Kavitha Reddy',3),
('DGCA-FO-002',5,'F/O Sanjay Iyer',5),
('DGCA-PIL-004',6,'Capt. Meera Pillai',10);
