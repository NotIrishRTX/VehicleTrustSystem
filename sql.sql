CREATE TABLE IF NOT EXISTS `vehicletrustsystem` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `discord` varchar(50) DEFAULT NULL,
    `steam` varchar(50) DEFAULT NULL,
    `license` varchar(50) DEFAULT NULL,
    `spawncode` varchar(50) NOT NULL,
    `owner` tinyint(1) NOT NULL DEFAULT 0,
    `allowed` tinyint(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    INDEX `idx_discord` (`discord`),
    INDEX `idx_steam` (`steam`),
    INDEX `idx_license` (`license`),
    INDEX `idx_spawncode` (`spawncode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
