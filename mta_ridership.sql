/*
	MTA Daily Ridership: Data Quality and Analysis
    Author: Paromita Talukder
    Data Source: MTA Daily Ridership Data from data.ny.gov
					(downloaded September 9, 2026, covers 2020-03-01 to 2025-01-09)
	Tools: MySQL 9, MySQL Workbench
    
    What the script does:
						1. Renames and converts raw input data into a clean table 
                        2. Runs quality checks (duplicates, missing values, NULLS, zeros)
                        3. Flags Staten Island Railway zero-ridership weekends (likely no service; see README)
                        4. Builds a holiday lookup table and labels each day as weekday, weekend, or holiday
                        5. Analyzes subway ridership by day of week, day-type, and month
                        
    Run order: top to bottom, after importing CSV (see Step 1)
*/

/* 
	Step 1: Import
    Imported the CSV with Workbench Table Data Import Wizard as table 'ridership_raw' with
    every column set to TEXT. The raw file stores dates as MM/DD/YYYY, counts with commas,
    and percentages with "%" sign. Importing as TEXT keeps original values intact for cleaning.
    Verified: 1,776 rows, matching the 1,776 days from 2020-03-01 to 2025-01-09
*/

-- NOTE: All averages cover the full period, 2020-03-01 to 2025-01-09, including the 2020 lockdown

CREATE DATABASE mta_project;
USE mta_project;

ALTER TABLE ridership_raw
	RENAME COLUMN `Date` TO ride_date,
    RENAME COLUMN `Subways: Total Estimated Ridership` TO subway_ridership,
    RENAME COLUMN `Subways: % of Comparable Pre-Pandemic Day` TO subway_pct,
    RENAME COLUMN `Buses: Total Estimated Ridership` TO bus_ridership,
    RENAME COLUMN `Buses: % of Comparable Pre-Pandemic Day` TO bus_pct,
	RENAME COLUMN `LIRR: Total Estimated Ridership` TO lirr_ridership,
    RENAME COLUMN `LIRR: % of Comparable Pre-Pandemic Day` TO lirr_pct,
    RENAME COLUMN `Metro-North: Total Estimated Ridership` TO metro_north_ridership,
	RENAME COLUMN `Metro-North: % of Comparable Pre-Pandemic Day` TO metro_north_pct,
    RENAME COLUMN `Access-A-Ride: Total Scheduled Trips` TO access_a_ride_trips,
    RENAME COLUMN `Access-A-Ride: % of Comparable Pre-Pandemic Day` TO access_a_ride_pct,
    RENAME COLUMN `Bridges and Tunnels: Total Traffic` TO bridges_tunnels_traffic,
    RENAME COLUMN `Bridges and Tunnels: % of Comparable Pre-Pandemic Day` TO bridges_tunnels_pct,
    RENAME COLUMN `Staten Island Railway: Total Estimated Ridership` TO sir_ridership,
    RENAME COLUMN `Staten Island Railway: % of Comparable Pre-Pandemic Day` TO sir_pct;
    
SELECT COUNT(*)
FROM ridership_raw;

SELECT *
FROM ridership_raw
WHERE ride_date = '01/09/2025';

-- Check: confirm no percent values have decimals before converting to whole numbers
-- Result: 0, so CAST AS UNSIGNED loses no data
SELECT COUNT(*) AS pct_values_with_decimals
FROM ridership_raw
WHERE subway_pct LIKE '%.%'
   OR bus_pct LIKE '%.%'
   OR lirr_pct LIKE '%.%'
   OR metro_north_pct LIKE '%.%'
   OR access_a_ride_pct LIKE '%.%'
   OR bridges_tunnels_pct LIKE '%.%'
   OR sir_pct LIKE '%.%';

CREATE TABLE ridership_clean AS
SELECT
  STR_TO_DATE(ride_date, '%m/%d/%Y') AS ride_date,
  CAST(REPLACE(subway_ridership, ',', '') AS UNSIGNED) AS subway_ridership,
  CAST(REPLACE(subway_pct, '%', '') AS UNSIGNED) AS subway_pct,
  CAST(REPLACE(bus_ridership, ',', '') AS UNSIGNED) AS bus_ridership,
  CAST(REPLACE(bus_pct, '%', '') AS UNSIGNED) AS bus_pct,
  CAST(REPLACE(lirr_ridership, ',', '') AS UNSIGNED) AS lirr_ridership,
  CAST(REPLACE(lirr_pct, '%', '') AS UNSIGNED) AS lirr_pct,
  CAST(REPLACE(metro_north_ridership, ',', '') AS UNSIGNED) AS metro_north_ridership,
  CAST(REPLACE(metro_north_pct, '%', '') AS UNSIGNED) AS metro_north_pct,
  CAST(REPLACE(access_a_ride_trips, ',', '') AS UNSIGNED) AS access_a_ride_trips,
  CAST(REPLACE(access_a_ride_pct, '%', '') AS UNSIGNED) AS access_a_ride_pct,
  CAST(REPLACE(bridges_tunnels_traffic, ',', '') AS UNSIGNED) AS bridges_tunnels_traffic,
  CAST(REPLACE(bridges_tunnels_pct, '%', '') AS UNSIGNED) AS bridges_tunnels_pct,
  CAST(REPLACE(sir_ridership, ',', '') AS UNSIGNED) AS sir_ridership,
  CAST(REPLACE(sir_pct, '%', '') AS UNSIGNED) AS sir_pct
FROM ridership_raw;

DESCRIBE ridership_clean;

SELECT min(ride_date) AS first_date, max(ride_date) AS last_date
FROM ridership_clean;

SELECT min(subway_ridership) AS Minimum_Ridership, max(subway_ridership) AS Maximum_Ridership
FROM ridership_clean;

-- Result: quietest 2020-04-12 (198,399, Easter Sunday during lockdown)
SELECT *
FROM ridership_clean
ORDER BY subway_ridership ASC
LIMIT 5;

-- Result: busiest day 2020-03-04 (5,498,809, one week before shutdowns)
SELECT *
FROM ridership_clean
ORDER BY subway_ridership DESC
LIMIT 5;

-- quality check #1: checking duplicate dates
SELECT ride_date, COUNT(*)
FROM ridership_clean
GROUP BY ride_date
HAVING COUNT(*) > 1;

-- quality check #2: checking missing data
SELECT COUNT(DISTINCT ride_date)
FROM ridership_clean; 
SELECT DATEDIFF(MAX(ride_date), MIN(ride_date)) + 1 AS calendar_days
FROM ridership_clean;

-- quality check #3: missing + zero values
SELECT 
	SUM(subway_ridership IS NULL) AS subway_nulls,
    SUM(subway_ridership = 0) AS subway_zeros,
    SUM(bus_ridership IS NULL) AS bus_nulls,
	SUM(bus_ridership = 0) AS bus_zeros,
    SUM(lirr_ridership IS NULL) AS lirr_nulls,
	SUM(lirr_ridership = 0) AS lirr_zeros,
    SUM(metro_north_ridership IS NULL) AS metro_north_nulls,
	SUM(metro_north_ridership = 0) AS metro_north_zeros,
    SUM(access_a_ride_trips IS NULL) AS access_a_ride_nulls,
	SUM(access_a_ride_trips = 0) AS access_a_ride_zeros,
    SUM(bridges_tunnels_traffic IS NULL) AS bridges_tunnels_nulls,
	SUM(bridges_tunnels_traffic = 0) AS bridges_tunnels_zeros,
    SUM(sir_ridership IS NULL) AS sir_nulls,
	SUM(sir_ridership = 0) AS sir_zeros
FROM ridership_clean;

-- quality check #4: check zeros in sir_ridership + sir_pct
SELECT ride_date, DAYNAME(ride_date) AS day_of_week, sir_ridership, sir_pct
FROM ridership_clean
WHERE sir_ridership = 0 OR sir_pct = 0;

SELECT ride_date, DAYNAME(ride_date) AS day_of_week, sir_ridership, sir_pct
FROM ridership_clean
WHERE sir_ridership = 0
ORDER BY ride_date;

SELECT DAYNAME(ride_date) AS day_of_week, COUNT(*) AS zero_days
FROM ridership_clean
WHERE sir_ridership = 0
GROUP BY DAYNAME(ride_date);

-- flag for sir_ridership = 0 days
SELECT ride_date, sir_ridership,
CASE
	WHEN sir_ridership = 0 THEN 'no_service'
    ELSE 'ok'
END AS sir_flag
FROM ridership_clean
ORDER BY ride_date;

SELECT
  CASE
    WHEN sir_ridership = 0 THEN 'no_service'
    ELSE 'ok'
  END AS sir_flag,
  COUNT(*) AS days
FROM ridership_clean
GROUP BY sir_flag;

ALTER TABLE ridership_clean
	ADD COLUMN sir_flag VARCHAR(20);

SET SQL_SAFE_UPDATES = 0;
UPDATE ridership_clean
SET sir_flag = CASE
	WHEN sir_ridership = 0 THEN 'no_service'
    ELSE 'ok'
END;
SET SQL_SAFE_UPDATES = 1;


-- Create holiday table
CREATE TABLE holidays (
	holiday_date DATE PRIMARY KEY,
    holiday_name VARCHAR(50)
);

-- 2020 holidays
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2020-05-25','Memorial Day'),
    ('2020-07-04','Independence Day'),
    ('2020-09-07','Labor Day'),
    ('2020-11-26','Thanksgiving'),
    ('2020-12-25','Christmas');
    
-- 2021 holidays
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2021-01-01','New Years'),
    ('2021-05-31','Memorial Day'),
    ('2021-07-04','Independence Day'),
    ('2021-09-06','Labor Day'),
    ('2021-11-25','Thanksgiving'),
    ('2021-12-25','Christmas');
    
-- 2022 holidays
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2022-01-01','New Years'),
    ('2022-05-30','Memorial Day'),
    ('2022-07-04','Independence Day'),
    ('2022-09-05','Labor Day'),
    ('2022-11-24','Thanksgiving'),
    ('2022-12-25','Christmas');
    
-- 2023 holidays
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2023-01-01','New Years'),
    ('2023-05-29','Memorial Day'),
    ('2023-07-04','Independence Day'),
    ('2023-09-04','Labor Day'),
    ('2023-11-23','Thanksgiving'),
    ('2023-12-25','Christmas');
    
-- 2024 holidays
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2024-01-01','New Years'),
    ('2024-05-27','Memorial Day'),
    ('2024-07-04','Independence Day'),
    ('2024-09-02','Labor Day'),
    ('2024-11-28','Thanksgiving'),
    ('2024-12-25','Christmas');

-- 2025 holidays (capped to 1 day in 2025)
INSERT INTO holidays (holiday_date, holiday_name) VALUES
	('2025-01-01','New Years');
    
-- Label each day as weekday, weekend, or holiday
-- holiday is checked first, so holidays falling on weekends count as holidays
ALTER TABLE ridership_clean
  ADD COLUMN day_type VARCHAR(10);

SET SQL_SAFE_UPDATES = 0;
UPDATE ridership_clean r
LEFT JOIN holidays h
  ON r.ride_date = h.holiday_date
SET r.day_type = CASE
    WHEN h.holiday_date IS NOT NULL THEN 'holiday'
    WHEN DAYOFWEEK(r.ride_date) IN (1, 7) THEN 'weekend'
    ELSE 'weekday'
  END;
SET SQL_SAFE_UPDATES = 1;

-- Analysis part 1: which days are busiest
-- Result: Wednesday busiest (~3.01M avg), Sunday lowest (~1.51M); Tue-Thu peak, Mon and Fri lower
SELECT DAYNAME(ride_date) AS day_of_week, DAYOFWEEK(ride_date) AS day_num, ROUND(AVG(subway_ridership)) AS avg_subway
FROM ridership_clean
GROUP BY DAYNAME(ride_date), DAYOFWEEK(ride_date)
ORDER BY DAYOFWEEK(ride_date);


-- Analysis part 2: weekday vs. weekend vs. holiday
-- Result: weekdays ~2.90M avg (1,245 days); weekends ~1.71M (501 days, ~41% lower); holidays ~1.36M (30 days, ~53% lower)
SELECT r.ride_date, DAYNAME(r.ride_date), r.subway_ridership, h.holiday_name
FROM ridership_clean r
LEFT JOIN holidays h
ON r.ride_date = h.holiday_date
WHERE h.holiday_name IS NOT NULL
ORDER BY r.ride_date;

SELECT COUNT(*)
FROM ridership_clean r
LEFT JOIN holidays h
ON r.ride_date = h.holiday_date
WHERE h.holiday_name IS NOT NULL;

SELECT day_type,
       COUNT(*) AS days,
       ROUND(AVG(subway_ridership)) AS avg_subway
FROM ridership_clean
GROUP BY day_type;


-- Analysis part 3: monthly trend
-- Result: low of ~391K/day in Apr 2020, high of ~3.66M/day in Oct 2024 (~9x); steady recovery with dips each winter and summer

-- Monthly average, all months
SELECT DATE_FORMAT(ride_date, '%Y-%m') AS month, ROUND(AVG(subway_ridership)) AS avg_subway
FROM ridership_clean
GROUP BY month
ORDER BY month;

-- Lowest month
SELECT DATE_FORMAT(ride_date, '%Y-%m') AS month, ROUND(AVG(subway_ridership)) AS avg_subway
FROM ridership_clean
GROUP BY month
ORDER BY avg_subway ASC
LIMIT 1;

-- Highest month
SELECT DATE_FORMAT(ride_date, '%Y-%m') AS month, ROUND(AVG(subway_ridership)) AS avg_subway
FROM ridership_clean
GROUP BY month
ORDER BY avg_subway DESC
LIMIT 1;








    