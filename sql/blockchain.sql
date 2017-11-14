/*
 * DDL and maybe some queries for the blockchain data put into S3 storage by Gemfire.
 * The data is JSON formatted.
 *
 * 13 November 2017
 */

-- Prep. the database
CREATE OR REPLACE FUNCTION write_to_s3() RETURNS integer AS
   '$libdir/gps3ext.so', 's3_export' LANGUAGE C STABLE;

CREATE OR REPLACE FUNCTION read_from_s3() RETURNS integer AS
   '$libdir/gps3ext.so', 's3_import' LANGUAGE C STABLE;

CREATE PROTOCOL s3 (writefunc = write_to_s3, readfunc = read_from_s3);

/*
 * Basically, proceed with the steps outlined here:
 * https://gpdb.docs.pivotal.io/500/admin_guide/external/g-s3-protocol.html
 *
 * NOTE: the table definition below assumes /home/gpadmin/s3.conf is the location of the S3
 * configuration file, on each of the hosts, where s3.conf has the following format:
 *
[default]
secret = "SOME_KEY_WITH_LENGTH_40_CHARS"
accessid = "SOME_ID_WITH_LENGTH_20_CHARS"
threadnum = 3
chunksize = 67108864
 *
 */

DROP EXTERNAL TABLE IF EXISTS blockchain_txn_s3;
CREATE EXTERNAL TABLE blockchain_txn_s3
(
  txn JSON
)
-- All the data:
-- LOCATION('s3://s3-us-west-2.amazonaws.com/io.pivotal.dil.blockchain/BlockchainTxn config=/home/gpadmin/s3.conf')

-- Only the data for November 14, 2017:
LOCATION('s3://s3-us-west-2.amazonaws.com/io.pivotal.dil.blockchain/BlockchainTxn/20171114 config=/home/gpadmin/s3.conf')
--LOCATION('s3://s3-us-west-2.amazonaws.com/io.pivotal.dil.blockchain/BlockchainTxn/20171115 config=/home/gpadmin/s3.conf')
FORMAT 'TEXT' (DELIMITER 'OFF' NULL '\N' ESCAPE '\');

-- TODO: Use the above approach to build up an external partition setup

-- Below are some query examples based on the JSON capability

-- Convert the date to a timestamp with time zone
SELECT (txn->>'time_as_date')::TIMESTAMP WITH TIME ZONE FROM blockchain_txn_s3 LIMIT 10;

-- Try to get to the elements of the arrays
-- See https://stackoverflow.com/questions/22736742/query-for-array-elements-inside-json-type
SELECT txn->>'hash', JSON_ARRAY_ELEMENTS(txn->'inputs') FROM blockchain_txn_s3 LIMIT 5;

-- From Alastair Turner
/*
item_body | {"spent":true,"tx_index":301154438,"type":0,"addr":"1MLVLhwWyq6FjgeD9akgnPLHo4e4bTqpB4","value":1404965648,"n":0,"script":"76a914df121366c1c71a92110c5e19116549f8d267cf9d88ac","id":"1MLVLhwWyq6FjgeD9akgnPLHo4e4bTqpB4-301154438"}
*/
WITH inputs AS (
  SELECT txn->>'hash' AS hash, 'in'::varchar AS direction, json_array_elements(json_extract_path(txn, 'inputs'))->'prev_out' AS item_body
    FROM blockchain_txn_s3
),
outputs AS (
  SELECT txn->>'hash' AS hash, 'out'::varchar AS direction, json_array_elements(json_extract_path(txn, 'out')) AS item_body
    FROM blockchain_txn_s3
),
all_items AS (
    SELECT * FROM inputs
  UNION ALL
    SELECT * FROM outputs
)
SELECT
  -- NOTE: this would be the DDL for the blockchain_item table
  (item_body->>'id')::TEXT id -- This is synthetic: addr || '-' || tx_index (see the BlockchainItem class)
  , hash -- This is the FK to the parent BlockchainTxn
  , direction
  , (item_body->>'spent')::BOOLEAN spent
  , (item_body->>'tx_index') tx_index
  , (item_body->>'tx_index')::BIGINT tx_index
  , (item_body->>'type')::INT type
  , (item_body->>'addr') addr
  , (item_body->>'value')::BIGINT value
  , (item_body->>'n')::INT n
  , (item_body->>'script')::TEXT script
  FROM all_items LIMIT 5;


