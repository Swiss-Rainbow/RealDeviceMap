CREATE TABLE IF NOT EXISTS `webhook` (
  `name` varchar(30) UNIQUE NOT NULL,
  `url` varchar(256) UNIQUE NOT NULL,
  `delay` double DEFAULT 5.0,
  `types` longtext,
  `data` longtext,
  `enabled` tinyint unsigned DEFAULT 1
);