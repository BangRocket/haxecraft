-- Emergency rollback for migration 0005. Re-creates `characters` +
-- `character_items` from `mobiles` + `items`. NOT part of the normal
-- migration sequence (filename intentionally lacks the leading number);
-- apply manually only if 0005 needs to be undone:
--   docker compose exec -T mysql mysql ... < db/migrations/0005_entities_rollback.sql
CREATE TABLE IF NOT EXISTS characters (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE,
    name VARCHAR(64) NOT NULL UNIQUE,
    zone_id INT NOT NULL DEFAULT 1,
    tile_x INT NOT NULL DEFAULT 512,
    tile_y INT NOT NULL DEFAULT 512,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    CONSTRAINT fk_characters_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    INDEX idx_characters_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_items (
    character_id BIGINT NOT NULL,
    slot INT NOT NULL,
    item_type_id INT NOT NULL,
    count INT NOT NULL,
    PRIMARY KEY (character_id, slot),
    CONSTRAINT fk_character_items_character FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO characters (id, account_id, name, zone_id, tile_x, tile_y, created_at, last_login)
SELECT serial, account_id, name, zone_id, tile_x, tile_y, created_at, last_login
FROM mobiles WHERE account_id IS NOT NULL;

INSERT INTO character_items (character_id, slot, item_type_id, count)
SELECT parent_serial, slot, item_type_id, count
FROM items WHERE parent_serial IS NOT NULL;

DROP TABLE serial_counters;
DROP TABLE items;
DROP TABLE mobiles;
