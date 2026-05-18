CREATE TABLE IF NOT EXISTS character_items (
    character_id BIGINT NOT NULL,
    slot INT NOT NULL,
    item_type_id INT NOT NULL,
    count INT NOT NULL,
    PRIMARY KEY (character_id, slot),
    CONSTRAINT fk_character_items_character FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
