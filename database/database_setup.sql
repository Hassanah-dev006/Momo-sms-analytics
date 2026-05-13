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
 
 
-- =====================================================================
-- TABLE: transaction_categories
-- Purpose: Lookup table for transaction types: TRANSFER, AIRTIME,
--          CASHOUT, PAYMENT, DEPOSIT, etc. Populated once at load time.
-- =====================================================================
CREATE TABLE transaction_categories (
    category_id     INT             NOT NULL AUTO_INCREMENT
                                    COMMENT 'Surrogate primary key',
    category_code   VARCHAR(50)     NOT NULL
                                    COMMENT 'Stable code used by ETL: TRANSFER, AIRTIME, CASHOUT, etc.',
    display_name    VARCHAR(100)    NOT NULL
                                    COMMENT 'Human-readable name for dashboard display',
    description     TEXT            NULL
                                    COMMENT 'Optional longer description of the category',
 
    PRIMARY KEY (category_id),
    UNIQUE KEY uk_categories_code (category_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Lookup table classifying transactions by type';


CREATE TABLE transactions (
    transaction_id      BIGINT          NOT NULL AUTO_INCREMENT
                                        COMMENT 'Surrogate primary key',
    external_ref        VARCHAR(100)    NOT NULL
                                        COMMENT 'MoMo TxId from SMS; idempotency key for ETL',
    sender_id           INT             NULL
                                        COMMENT 'FK to users; NULL when no sender (e.g. airtime)',
    receiver_id         INT             NULL
                                        COMMENT 'FK to users; NULL when no receiver (e.g. cashout)',
    category_id         INT             NOT NULL
                                        COMMENT 'FK to transaction_categories',
    amount              DECIMAL(15,2)   NOT NULL
                                        COMMENT 'Transaction amount in RWF',
    fee                 DECIMAL(15,2)   NOT NULL DEFAULT 0.00
                                        COMMENT 'Transaction fee in RWF',
    balance_after       DECIMAL(15,2)   NULL
                                        COMMENT 'Account balance after transaction, if reported in SMS',
    transaction_date    DATETIME        NOT NULL
                                        COMMENT 'When the transaction occurred (from SMS body)',
    raw_message         TEXT            NULL
                                        COMMENT 'Original SMS text, retained for audit/debugging',
 
    PRIMARY KEY (transaction_id),
    UNIQUE KEY uk_transactions_external_ref (external_ref),
 
    CONSTRAINT fk_transactions_sender
        FOREIGN KEY (sender_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_receiver
        FOREIGN KEY (receiver_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_transactions_category
        FOREIGN KEY (category_id) REFERENCES transaction_categories(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
 
    CONSTRAINT chk_transactions_amount_nonneg
        CHECK (amount >= 0),
    CONSTRAINT chk_transactions_fee_nonneg
        CHECK (fee >= 0),
    CONSTRAINT chk_transactions_parties_differ
        CHECK (sender_id IS NULL OR receiver_id IS NULL OR sender_id <> receiver_id),
 
    INDEX idx_transactions_date (transaction_date),
    INDEX idx_transactions_category (category_id),
    INDEX idx_transactions_sender (sender_id),
    INDEX idx_transactions_receiver (receiver_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Core fact table: one row per parsed MoMo SMS transaction';
 



-- =====================================================================
-- TABLE: tags
-- Purpose: Analytical tags applied to transactions (high_value,
--          recurring, flagged, etc.). One side of the M:N relationship.
-- =====================================================================
CREATE TABLE tags (
    tag_id          INT             NOT NULL AUTO_INCREMENT
                                    COMMENT 'Surrogate primary key',
    tag_name        VARCHAR(50)     NOT NULL
                                    COMMENT 'Tag identifier: high_value, recurring, flagged, etc.',
    description     TEXT            NULL
                                    COMMENT 'Optional explanation of when this tag applies',
 
    PRIMARY KEY (tag_id),
    UNIQUE KEY uk_tags_name (tag_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Analytical tags applicable to transactions (M:N with transactions)';
 



 CREATE TABLE transaction_tags (
    transaction_id  BIGINT          NOT NULL
                                    COMMENT 'FK to transactions, part of composite PK',
    tag_id          INT             NOT NULL
                                    COMMENT 'FK to tags, part of composite PK',
    tagged_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    COMMENT 'When this tag was applied',
 
    PRIMARY KEY (transaction_id, tag_id),
 
    CONSTRAINT fk_txntags_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_txntags_tag
        FOREIGN KEY (tag_id) REFERENCES tags(tag_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
 
    INDEX idx_txntags_tag (tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Junction table resolving M:N between transactions and tags';


-- =====================================================================
-- TABLE: system_logs
-- Purpose: ETL operational logging. transaction_id is nullable because
--          some events are global (ETL start/stop, parse failures with
--          no associated transaction).
-- =====================================================================
CREATE TABLE system_logs (
    log_id          BIGINT          NOT NULL AUTO_INCREMENT
                                    COMMENT 'Surrogate primary key',
    log_level       ENUM('INFO','WARN','ERROR') NOT NULL
                                    COMMENT 'Severity level',
    event_type      VARCHAR(50)     NOT NULL
                                    COMMENT 'Event class: PARSE_SUCCESS, PARSE_FAIL, DUPLICATE_REF, etc.',
    transaction_id  BIGINT          NULL
                                    COMMENT 'FK to transactions if the event relates to one; else NULL',
    message         TEXT            NULL
                                    COMMENT 'Free-text log message',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    COMMENT 'Log timestamp',
 
    PRIMARY KEY (log_id),
 
    CONSTRAINT fk_logs_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
 
    INDEX idx_logs_level_date (log_level, created_at),
    INDEX idx_logs_event_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='ETL pipeline operational log';
 
 

