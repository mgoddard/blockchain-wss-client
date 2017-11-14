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
LOCATION('s3://s3-us-west-2.amazonaws.com/io.pivotal.dil.blockchain/BlockchainTxn config=/home/gpadmin/s3.conf')
FORMAT 'TEXT' (DELIMITER 'OFF' NULL '\N' ESCAPE '\');

