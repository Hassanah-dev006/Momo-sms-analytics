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
 
 
-- =====================================================================
-- SAMPLE DATA (DML)
-- Inserted in FK dependency order: parents before children.
-- All amounts in RWF. Phone numbers follow Rwandan +250 format.
-- =====================================================================
 
-- ----- users (8 rows; mix of personal and business) -----
INSERT INTO users (phone_number, display_name, first_seen_at, is_business) VALUES
('+250788111001', 'Panom Kot',          '2026-04-01 08:12:00', 0),
('+250788222002', 'Aline Uwase',         '2026-04-02 14:33:00', 0),
('+250788333003', 'Patrick Nshuti',      '2026-04-03 10:05:00', 0),
('+250788444004', 'MTN Rwanda Airtime',  '2026-04-01 00:00:00', 1),
('+250788555005', 'Kigali Heights Mart', '2026-04-04 16:20:00', 1),
('+250788666006', 'Chantal Ingabire',    '2026-04-05 09:47:00', 0),
('+250788777007', 'Eric Habimana',       '2026-04-06 11:15:00', 0),
('+250788888008', NULL,                  '2026-04-07 18:02:00', 0);


-- ----- transaction_categories (6 rows; real MoMo transaction types) -----
INSERT INTO transaction_categories (category_code, display_name, description) VALUES
('TRANSFER',  'Person-to-Person Transfer', 'MoMo transfer between two individual accounts'),
('AIRTIME',   'Airtime Purchase',          'Direct airtime top-up to a phone number'),
('CASHOUT',   'Cash Withdrawal',           'Withdrawal at an agent or ATM'),
('PAYMENT',   'Merchant Payment',          'Payment to a registered business/merchant'),
('DEPOSIT',   'Cash Deposit',              'Cash deposited at an agent location'),
('BILL_PAY',  'Bill Payment',              'Utility or service bill payment (EUCL, water, etc.)');



-- ----- tags (5 rows) -----
INSERT INTO tags (tag_name, description) VALUES
('high_value',  'Transaction amount >= 100,000 RWF'),
('recurring',   'Recurring pattern detected (same parties, regular interval)'),
('flagged',     'Manually flagged for review'),
('weekend',     'Transaction occurred on Saturday or Sunday'),
('after_hours', 'Transaction occurred between 22:00 and 06:00');


-- ----- transactions (10 rows; varied categories, amounts, dates) -----
INSERT INTO transactions
    (external_ref, sender_id, receiver_id, category_id, amount, fee, balance_after, transaction_date, raw_message)
VALUES
('TXN20260401001', 1,    2,    1, 5000.00,    100.00,  45000.00,  '2026-04-01 09:15:00',
    'You have transferred 5,000 RWF to Aline Uwase (250788222002). Fee: 100 RWF. New balance: 45,000 RWF. TxId: TXN20260401001'),
('TXN20260402002', 2,    NULL, 2, 1000.00,    0.00,    44000.00,  '2026-04-02 14:30:00',
    'You bought 1,000 RWF airtime for 250788222002. New balance: 44,000 RWF. TxId: TXN20260402002'),
('TXN20260403003', 3,    5,    4, 25000.00,   250.00,  74750.00,  '2026-04-03 16:42:00',
    'Payment of 25,000 RWF to Kigali Heights Mart confirmed. Fee: 250 RWF. New balance: 74,750 RWF. TxId: TXN20260403003'),
('TXN20260404004', NULL, 1,    5, 50000.00,   0.00,    95000.00,  '2026-04-04 11:00:00',
    'You have received a deposit of 50,000 RWF at Agent 4023. New balance: 95,000 RWF. TxId: TXN20260404004'),
('TXN20260405005', 1,    NULL, 3, 20000.00,   400.00,  74600.00,  '2026-04-05 18:25:00',
    'You have withdrawn 20,000 RWF at Agent 1187. Fee: 400 RWF. New balance: 74,600 RWF. TxId: TXN20260405005'),
('TXN20260406006', 6,    5,    4, 150000.00,  1500.00, 200000.00, '2026-04-06 13:10:00',
    'Payment of 150,000 RWF to Kigali Heights Mart confirmed. Fee: 1,500 RWF. New balance: 200,000 RWF. TxId: TXN20260406006'),
('TXN20260411007', 7,    3,    1, 3000.00,    50.00,   12000.00,  '2026-04-11 10:00:00',
    'You have transferred 3,000 RWF to Patrick Nshuti. Fee: 50 RWF. New balance: 12,000 RWF. TxId: TXN20260411007'),
('TXN20260412008', 8,    NULL, 6, 8500.00,    100.00,  21400.00,  '2026-04-12 09:30:00',
    'Bill payment of 8,500 RWF to EUCL successful. Fee: 100 RWF. New balance: 21,400 RWF. TxId: TXN20260412008'),
('TXN20260418009', 2,    7,    1, 7000.00,    100.00,  37000.00,  '2026-04-18 20:45:00',
    'You have transferred 7,000 RWF to Eric Habimana. Fee: 100 RWF. New balance: 37,000 RWF. TxId: TXN20260418009'),
('TXN20260425010', 6,    5,    4, 175000.00,  1750.00, 25000.00,  '2026-04-25 23:50:00',
    'Payment of 175,000 RWF to Kigali Heights Mart confirmed. Fee: 1,750 RWF. New balance: 25,000 RWF. TxId: TXN20260425010');
 



INSERT INTO transaction_tags (transaction_id, tag_id, tagged_at) VALUES
(6,  1, '2026-04-06 13:10:05'),  -- high_value
(6,  2, '2026-04-25 23:51:00'),  -- recurring (detected after TXN010 confirmed pattern)
(10, 1, '2026-04-25 23:50:05'),  -- high_value
(10, 2, '2026-04-25 23:51:00'),  -- recurring
(10, 5, '2026-04-25 23:50:05'),  -- after_hours
(9,  4, '2026-04-18 20:45:05'),  -- weekend
(4,  3, '2026-04-04 12:00:00'),  -- flagged
(1,  2, '2026-04-11 10:00:10'),  -- recurring
(7,  2, '2026-04-11 10:00:10'),  -- recurring
(8,  4, '2026-04-12 09:30:05'),  -- weekend
(3,  3, '2026-04-03 17:00:00');  -- flagged (large merchant payment from new user)


-- ----- system_logs (8 rows; mix of INFO/WARN/ERROR, mix of global and transaction-linked) -----
INSERT INTO system_logs (log_level, event_type, transaction_id, message, created_at) VALUES
('INFO',  'ETL_START',       NULL, 'ETL batch started: source=momo.xml',                      '2026-04-01 06:00:00'),
('INFO',  'PARSE_SUCCESS',   1,    'Successfully parsed TRANSFER transaction',                 '2026-04-01 09:15:01'),
('INFO',  'PARSE_SUCCESS',   2,    'Successfully parsed AIRTIME transaction',                  '2026-04-02 14:30:01'),
('WARN',  'MISSING_BALANCE', 3,    'balance_after missing in SMS body; left NULL',             '2026-04-03 16:42:02'),
('ERROR', 'PARSE_FAIL',      NULL, 'Could not parse SMS body: malformed timestamp at line 247','2026-04-04 10:30:00'),
('WARN',  'DUPLICATE_REF',   NULL, 'Skipped duplicate external_ref=TXN20260401001 during re-run','2026-04-05 02:00:00'),
('INFO',  'TAG_APPLIED',     10,   'Auto-tagged transaction as high_value and after_hours',    '2026-04-25 23:50:06'),
('INFO',  'ETL_COMPLETE',    NULL, 'ETL batch complete: 10 parsed, 1 failed, 1 duplicate skipped','2026-04-25 23:55:00');



-- =====================================================================
-- VERIFICATION QUERIES (CRUD + ANALYTICAL)
-- Run these after the inserts above. Capture output as screenshots for
-- the design document. Each query is labeled with what it demonstrates.
-- =====================================================================
 
-- --- Q1 (READ + JOIN): All transactions with sender, receiver, category resolved ---
SELECT
    t.transaction_id,
    t.external_ref,
    s.phone_number  AS sender_phone,
    r.phone_number  AS receiver_phone,
    c.display_name  AS category,
    t.amount,
    t.transaction_date
FROM transactions t
LEFT JOIN users s                   ON t.sender_id   = s.user_id
LEFT JOIN users r                   ON t.receiver_id = r.user_id
INNER JOIN transaction_categories c ON t.category_id = c.category_id
ORDER BY t.transaction_date;


-- --- Q2 (ANALYTICAL): Total volume and transaction count per category ---
SELECT
    c.display_name         AS category,
    COUNT(*)               AS txn_count,
    SUM(t.amount)          AS total_volume_rwf,
    ROUND(AVG(t.amount),2) AS avg_amount_rwf
FROM transactions t
JOIN transaction_categories c ON t.category_id = c.category_id
GROUP BY c.category_id, c.display_name
ORDER BY total_volume_rwf DESC;