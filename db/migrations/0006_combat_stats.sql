-- Extend mobiles with combat stats + HP. All new columns default to 50,
-- giving every existing mobile a fresh 50/50/50/50/50 baseline.
-- Idempotent via INFORMATION_SCHEMA check.

DROP PROCEDURE IF EXISTS apply_0006;
DELIMITER //
CREATE PROCEDURE apply_0006()
BEGIN
  DECLARE has_str INT;
  SELECT COUNT(*) INTO has_str
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mobiles' AND COLUMN_NAME = 'str';
  IF has_str = 0 THEN
    ALTER TABLE mobiles
      ADD COLUMN str    INT NOT NULL DEFAULT 50,
      ADD COLUMN dex    INT NOT NULL DEFAULT 50,
      ADD COLUMN intel  INT NOT NULL DEFAULT 50,
      ADD COLUMN hp     INT NOT NULL DEFAULT 50,
      ADD COLUMN max_hp INT NOT NULL DEFAULT 50;
  END IF;
END //
DELIMITER ;
CALL apply_0006();
DROP PROCEDURE apply_0006;
