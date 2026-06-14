-- PressPilot MySQL initialization
-- Creates all Ghost databases on first container start
-- This file runs automatically via docker-entrypoint-initdb.d

CREATE DATABASE IF NOT EXISTS ghost_mostlyprompt CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ghost_fellowcoder CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ghost_aimovi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON ghost_mostlyprompt.* TO 'ghost'@'%';
GRANT ALL PRIVILEGES ON ghost_fellowcoder.* TO 'ghost'@'%';
GRANT ALL PRIVILEGES ON ghost_aimovi.* TO 'ghost'@'%';

FLUSH PRIVILEGES;
