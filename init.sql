-- ============================================
-- Call of Duty Achievement Tracker
-- MySQL Initialization Script
-- ============================================

-- 1. Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS cod_tracker
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE cod_tracker;

-- 2. Create the achievements table
--    Column names match server.js exactly: map (not map_mode), createdAt (not created_at)
CREATE TABLE IF NOT EXISTS achievements (
  id         INT            AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(255)   NOT NULL,
  map        VARCHAR(255)   DEFAULT NULL,
  kills      INT            DEFAULT 0,
  notes      TEXT           DEFAULT NULL,
  createdAt  TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Seed with sample Call of Duty achievement data
INSERT INTO achievements (title, map, kills, notes) VALUES
  (
    'Tactical Nuke Unlocked',
    'Rust — Free-For-All',
    30,
    'First nuke of the season! 30-kill streak without dying. Used MP5 + Ghost perk setup.'
  ),
  (
    '100 Headshots — Gold Camo',
    'Shipment — Hardpoint',
    147,
    'Grinded gold camo for the M4A1. Shipment 24/7 playlist made it way faster.'
  ),
  (
    'Ace Clutch — Search & Destroy',
    'Crash — Search & Destroy',
    6,
    '1v6 ace clutch in ranked play. Defused the bomb with 0.3 seconds left on the timer.'
  );

-- Verify the seed data
SELECT '✅  Database "cod_tracker" initialized with 3 sample achievements.' AS status;
SELECT * FROM achievements ORDER BY createdAt DESC;
