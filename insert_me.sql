CREATE TABLE IF NOT EXISTS `matkez_ownablecarwash` (
    `wash_id` VARCHAR(100) NOT NULL,
    `owner` TEXT DEFAULT NULL,
    `workers` TEXT DEFAULT '[]',
    `data` TEXT DEFAULT NULL,
    `price` TEXT DEFAULT '99999',
    `washPrice` TEXT DEFAULT '15',
    `label` TEXT DEFAULT 'Car Wash',
    `water` VARCHAR(20) DEFAULT '100',
    `orders` TEXT DEFAULT '[]',
    PRIMARY KEY (`wash_id`)
);