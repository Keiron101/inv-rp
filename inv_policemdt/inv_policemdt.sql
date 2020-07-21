USE `essentialmode`;

CREATE TABLE `records` (
	`recordid` INT(11) NOT NULL AUTO_INCREMENT,
	`issuer` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_bin',
	`player` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_bin',
	`type` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_bin',
	`notes` TEXT NULL COLLATE 'utf8mb4_bin',

	PRIMARY KEY (`recordid`),
	INDEX `index_records_player_type` (`player`, `type`),
	INDEX `index_records_type` (`type`),
	INDEX `index_records_player` (`player`)
)
COLLATE='utf8mb4_bin'
;