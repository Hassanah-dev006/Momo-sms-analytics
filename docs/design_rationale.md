DESIGN RATIONALE
The database schema for the MoMo SMS data processing system establishes the transactions
table as the primary record, which receives support from the users, transaction_categories,
system_logs, tags, and transaction_tags tables to improve data structure and system security
and record system activities. The design establishes accurate data representation of the actual
MoMo SMS system through its design, which enables future system expansion and database
normalization and analytical efficiency and reporting efficiency. The first major design
decision was to move customer information out of the transactions table and into the users
table. The system needs an identity verification process which allows users to complete
multiple transactions without repeating their personal information. The sender_id and
receiver_id fields in the transactions table function as foreign keys that link to the users table.
Some activities in MoMo require users to purchase airtime or balance their account or pay
service fees without needing a second user, which is why the fields become nullable. The
business process requires actual null values because they represent valid operational
functions in business activities whereas phantom records need to be created for operational
practices. The second critical choice was the handling of financial data. The system stores all
monetary amounts as DECIMAL(15,2) because floating-point arithmetic leads to precision
loss during calculations. Financial systems require absolute accuracy because they need to
ensure that all financial balances and totals match exact cent amounts. The system uses a
UNIQUE constraint with the transaction reference code to prevent the ETL pipeline from
creating multiple transaction records when it processes the same XML file, which establishes
essential data importability control.
The design process reached its third crucial decision when the team used the transaction_tags
junction table to define how transactions relate to tags in a many-to-many connection. A
single transaction can carry multiple tags such as "high-value" and "recurring" and
"flagged-for-review" which apply to multiple transactions. The user-category M:N
relationship did not meet our needs because each transaction in the source data belongs to one
specific category which creates a true 1:M relationship. The tags relationship exists for
analytical purposes because it enables dashboard queries which filter data based on tag
combinations.
The database maintains data integrity through its CHECK (amount >= 0) system which
requires essential fields to have NOT NULL values and enforces foreign key connections
between all tables that relate to each other. The rules establish system entry restrictions which
stop invalid records from entering the system without regard to application-layer operations.
The dashboard uses indexes on transaction_date and category_id to support its common
access modes which include time-windowed aggregation and category-level breakdowns. The
system_logs table stores ETL provenance data through its foreign key to transactions which
allows it to capture both transaction-related and pipeline-related activities.
