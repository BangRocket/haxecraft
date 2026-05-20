-- mobiles: replaces `characters`. Primary key is the serial (in mobile range,
-- 1..0x3FFFFFFF). For existing rows the previous auto-increment id is
-- preserved as the serial — they already fit the mobile range.
CREATE TABLE IF NOT EXISTS mobiles (
    serial      BIGINT PRIMARY KEY,
    account_id  BIGINT NULL,
    name        VARCHAR(64) NOT NULL,
    zone_id     INT NOT NULL DEFAULT 1,
    tile_x      INT NOT NULL,
    tile_y      INT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP NULL,
    UNIQUE KEY uq_mobiles_account (account_id),
    UNIQUE KEY uq_mobiles_name    (name),
    CONSTRAINT fk_mobiles_account
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- items: replaces `character_items` and absorbs ground items + world objects.
-- parent_serial NULL means "in the world"; non-NULL means "carried by mobile
-- parent_serial in slot N".
CREATE TABLE IF NOT EXISTS items (
    serial         BIGINT PRIMARY KEY,
    item_type_id   INT NOT NULL,
    count          INT NOT NULL,
    parent_serial  BIGINT NULL,
    zone_id        INT NULL,
    tile_x         INT NULL,
    tile_y         INT NULL,
    slot           INT NULL,
    INDEX idx_items_parent (parent_serial),
    INDEX idx_items_world  (zone_id, tile_x, tile_y),
    CONSTRAINT fk_items_parent
      FOREIGN KEY (parent_serial) REFERENCES mobiles(serial) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- serial_counters: single-row table holding the next free mobile/item id.
CREATE TABLE IF NOT EXISTS serial_counters (
    id           TINYINT PRIMARY KEY,
    mobile_next  BIGINT NOT NULL,
    item_next    BIGINT NOT NULL
);

-- Data migration: copy from old tables if they still exist. Wrapped in a
-- procedure so the migration script remains idempotent across re-runs
-- (apply-migrations.sh re-pipes every file every invocation).
DROP PROCEDURE IF EXISTS apply_0005;
DELIMITER //
CREATE PROCEDURE apply_0005()
BEGIN
  DECLARE has_chars INT;
  SELECT COUNT(*) INTO has_chars
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters';
  IF has_chars > 0 THEN
    INSERT INTO mobiles (serial, account_id, name, zone_id, tile_x, tile_y, created_at, last_login)
    SELECT id, account_id, name, zone_id, tile_x, tile_y, created_at, last_login
    FROM characters;

    SET @s := 1073741823;  -- 0x40000000 - 1; pre-increment yields 0x40000000 first
    INSERT INTO items (serial, item_type_id, count, parent_serial, slot)
    SELECT @s := @s + 1, item_type_id, count, character_id, slot
    FROM character_items ORDER BY character_id, slot;

    DROP TABLE character_items;
    DROP TABLE characters;
  END IF;
END //
DELIMITER ;
CALL apply_0005();
DROP PROCEDURE apply_0005;

-- Seed the counter row (idempotent). On a fresh DB this lands (1, 0x40000000);
-- on a populated DB the counters reflect the just-migrated max ids.
INSERT INTO serial_counters (id, mobile_next, item_next)
SELECT
  1,
  COALESCE((SELECT MAX(serial) FROM mobiles), 0) + 1,
  COALESCE((SELECT MAX(serial) FROM items), 1073741823) + 1
WHERE NOT EXISTS (SELECT 1 FROM serial_counters WHERE id = 1);
