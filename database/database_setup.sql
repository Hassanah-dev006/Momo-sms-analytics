DROP TABLE IF EXISTS system_logs;
DROP TABLE IF EXISTS transaction_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS transaction_categories;
DROP TABLE IF EXISTS users;


-- =====================================================================
-- TABLE: users
-- Purpose: Parties involved in MoMo transactions (senders / receivers).
--          Identified by phone number, the natural key from SMS data.
--          display_name is nullable because SMS often gives only a number.
-- =====================================================================
CREATE TABLE users (
    user_id         INT             NOT NULL AUTO_INCREMENT
                                    COMMENT 'Surrogate primary key',
    phone_number    VARCHAR(20)     NOT NULL
                                    COMMENT 'E.164-style phone number, e.g. +250788123456',
    display_name    VARCHAR(100)    NULL
                                    COMMENT 'Display name from SMS if available; often null',
    first_seen_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    COMMENT 'Timestamp when this user was first observed in the data',
    is_business     TINYINT(1)      NOT NULL DEFAULT 0
                                    COMMENT 'Flag: 1 if business/merchant account, 0 if personal',
 
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_users_phone (phone_number),
    INDEX idx_users_business (is_business)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Transaction parties (senders and receivers) extracted from MoMo SMS';
 
 
