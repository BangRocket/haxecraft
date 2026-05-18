CREATE TABLE IF NOT EXISTS zone_tile_overrides (
    zone_id INT NOT NULL DEFAULT 1,
    x INT NOT NULL,
    y INT NOT NULL,
    tile_type INT NOT NULL,
    data INT NOT NULL DEFAULT 0,
    PRIMARY KEY (zone_id, x, y)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
