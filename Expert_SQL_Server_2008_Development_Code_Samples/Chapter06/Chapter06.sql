/**
 * Expert SQL Server 2008 (Apress)
 * Alastair Aitchison
 *
 * Chapter 6 : Encryption
 */

-- Create a new database for these examples
CREATE DATABASE ExpertSqlEncryption;
GO
USE ExpertSqlEncryption;
GO

-- Create a DMK
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '-=+I_aM-tH3-DMK_P45sW0rd+=-';
GO

/*
 * Hashing
 */

-- Hash a supplied text string
SELECT HASHBYTES('SHA1', 'The quick brown fox jumped over the lazy dog');
GO

-- Similar inputs do not have similar hashes
SELECT HASHBYTES('SHA1', 'The quick brown fox jumped over the lazy dogs');
GO

/*
 * Symmetric Encryption
 */

-- Create a symmetric key
CREATE SYMMETRIC KEY SymKey1
WITH ALGORITHM = AES_256
ENCRYPTION BY PASSWORD = '5yMm3tr1c_K3Y_P@$$w0rd!';
GO

-- Create a symmetric key from specified parameters
CREATE SYMMETRIC KEY StaticKey
WITH
  KEY_SOURCE = '#K3y_50urc£#',
  IDENTITY_VALUE = '-=1d3nt1ty_VA1uE!=-',
  ALGORITHM = TRIPLE_DES
ENCRYPTION BY PASSWORD = 'P@55w0rD';
GO

-- Open the key
OPEN SYMMETRIC KEY SymKey1
DECRYPTION BY PASSWORD = '5yMm3tr1c_K3Y_P@$$w0rd!';

-- Declare the cleartext to be encrypted
DECLARE @Secret nvarchar(255) = 'This is my secret message';

-- Encrypt the message
SELECT  ENCRYPTBYKEY(KEY_GUID(N'SymKey1'), @secret);
 
-- Close the key again
CLOSE SYMMETRIC KEY SymKey1;
GO

/*
 * Symmetric Decryption
 */
 
-- Open the key
OPEN SYMMETRIC KEY SymKey1
DECRYPTION BY PASSWORD = '5yMm3tr1c_K3Y_P@$$w0rd!';

DECLARE @Secret nvarchar(255) = 'This is my secret message';
DECLARE @Encrypted varbinary(max);

SET @Encrypted = ENCRYPTBYKEY(KEY_GUID(N'SymKey1'),@secret);

SELECT CAST(DECRYPTBYKEY(@Encrypted) AS nvarchar(255));
  
CLOSE SYMMETRIC KEY SymKey1;
GO

-- Symmetric Encryption using a password
SELECT ENCRYPTBYPASSPHRASE('PassPhrase', 'My Other Secret Message');
GO

-- Symmetric Decryption using a password
SELECT CAST(DECRYPTBYPASSPHRASE('PassPhrase', 
0x010000007A65B54B1797E637F3F018C4100468B115CB5B88BEA1A7C36432B0B93B8F616AC8D3BA7307D5005E) AS varchar(32));
GO


/*
 * Asymmetric Key Encryption
 */
CREATE ASYMMETRIC KEY AsymKey1
WITH Algorithm = RSA_1024;
GO

DECLARE @Secret nvarchar(255) = 'This is my secret message';
DECLARE @Encrypted varbinary(max);

SET @Encrypted = ENCRYPTBYASYMKEY(ASYMKEY_ID(N'AsymKey1'), @Secret);
GO

/*
 * Asymmetric Key Decryption
 */
DECLARE @Secret nvarchar(255) = 'This is my secret message';
DECLARE @Encrypted varbinary(max);

SET @Encrypted = ENCRYPTBYASYMKEY(ASYMKEY_ID(N'AsymKey1'), @secret);

SELECT
  CAST(DECRYPTBYASYMKEY(ASYMKEY_ID(N'AsymKey1'), @Encrypted) AS nvarchar(255));
GO


/*
 * Transparent Data Encryption
 */
-- Create the server certificate
USE MASTER;
GO
CREATE CERTIFICATE TDE_Cert
WITH SUBJECT = 'Certificate for TDE Encryption';
GO

-- Create the DEK
USE ExpertSqlEncryption;
GO
CREATE DATABASE ENCRYPTION  KEY
WITH ALGORITHM  = AES_128
ENCRYPTION BY SERVER CERTIFICATE TDE_Cert;
GO

-- Turn TDE on
ALTER DATABASE ExpertSqlEncryption
SET ENCRYPTION ON;
GO

-- Examine Encryption status
SELECT
  DB_NAME(database_id) AS database_name,
  CASE encryption_state
    WHEN 0 THEN 'Unencrypted (No database encryption key present)'
    WHEN 1 THEN 'Unencrypted'
    WHEN 2 THEN 'Encryption in Progress'
    WHEN 3 THEN 'Encrypted'
    WHEN 4 THEN 'Key Change in Progress'
    WHEN 5 THEN 'Decryption in Progress'
    END AS encryption_state,
    key_algorithm,
    key_length
 FROM sys.dm_database_encryption_keys;
GO

-- Disable TDE
ALTER DATABASE ExpertSqlEncryption
SET ENCRYPTION OFF;
GO


/*
 * Creating a Hybrid Encryption Model
 */
CREATE USER FinanceUser WITHOUT LOGIN;
CREATE USER MarketingUser WITHOUT LOGIN;
GO

CREATE CERTIFICATE FinanceCertificate
  AUTHORIZATION FinanceUser
  ENCRYPTION BY PASSWORD = '#F1n4nc3_P455w()rD#'
  WITH SUBJECT = 'Certificate for Finance',
  EXPIRY_DATE = '20101031';

CREATE CERTIFICATE MarketingCertificate
  AUTHORIZATION MarketingUser
  ENCRYPTION BY PASSWORD = '-+M@Rket1ng-P@s5w0rD!+-'
  WITH SUBJECT = 'Certificate for Marketing',
  EXPIRY_DATE = '20101105';
GO

CREATE TABLE Confidential (
  EncryptedData varbinary(255)
  );
  GO

GRANT SELECT, INSERT ON Confidential TO FinanceUser, MarketingUser;
GO

-- Create a symmetric key protected by the first certificate
CREATE SYMMETRIC KEY SharedSymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE FinanceCertificate;
GO

-- Then OPEN and ALTER the key to add encryption by the second certificate
OPEN SYMMETRIC KEY SharedSymKey
DECRYPTION BY CERTIFICATE FinanceCertificate
WITH PASSWORD = '#F1n4nc3_P455w()rD#';

ALTER SYMMETRIC KEY SharedSymKey
ADD ENCRYPTION BY CERTIFICATE MarketingCertificate;

CLOSE SYMMETRIC KEY SharedSymKey;
GO

GRANT VIEW DEFINITION ON SYMMETRIC KEY::SharedSymKey TO FinanceUser
GRANT VIEW DEFINITION ON SYMMETRIC KEY::SharedSymKey TO MarketingUser
GO

-- Insert some shared confidential data
EXECUTE AS USER = 'FinanceUser';

OPEN SYMMETRIC KEY SharedSymKey
DECRYPTION BY CERTIFICATE FinanceCertificate
WITH PASSWORD = '#F1n4nc3_P455w()rD#';

INSERT INTO Confidential
SELECT ENCRYPTBYKEY(KEY_GUID(N'SharedSymKey'), N'This is shared information 
accessible to finance and marketing');

CLOSE SYMMETRIC KEY SharedSymKey;

REVERT;
GO

-- Read the confidnetial shared data
EXECUTE AS USER = 'MarketingUser';

SELECT
  CAST(
    DECRYPTBYKEYAUTOCERT(
      CERT_ID(N'MarketingCertificate'),
      N'-+M@Rket1ng-P@s5w0rD!+-',
      EncryptedData)
  AS nvarchar(255))
FROM Confidential;

REVERT ;
GO

-- Create new key just for finance
CREATE SYMMETRIC KEY FinanceSymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE FinanceCertificate;
GO

GRANT VIEW DEFINITION ON SYMMETRIC KEY::FinanceSymKey TO FinanceUser
GO

-- Insert some encrypted finance information
EXECUTE AS USER = 'FinanceUser';

OPEN SYMMETRIC KEY FinanceSymKey
DECRYPTION BY CERTIFICATE FinanceCertificate
WITH PASSWORD = '#F1n4nc3_P455w()rD#';

INSERT INTO Confidential
SELECT ENCRYPTBYKEY(
  KEY_GUID(N'FinanceSymKey'),
  N'This information is only accessible to finance');

CLOSE SYMMETRIC KEY FinanceSymKey;
REVERT;
GO

-- Finance user decryption
EXECUTE AS USER = 'FinanceUser';

SELECT 
  CAST(
    DECRYPTBYKEYAUTOCERT(
      CERT_ID(N'FinanceCertificate'),
      N'#F1n4nc3_P455w()rD#',
      EncryptedData
      ) AS nvarchar(255))
FROM Confidential;

REVERT;
GO

-- Marketing User decryption
EXECUTE AS USER = 'MarketingUser';

SELECT
  CAST(
    DECRYPTBYKEYAUTOCERT(
      CERT_ID(N'MarketingCertificate'),
      N'-+M@Rket1ng-P@s5w0rD!+-',
      EncryptedData) AS nvarchar(255))
FROM Confidential;

REVERT;
GO


/*
 * Designing performant queries against encrypted data
 */
-- Create some sample data
CREATE TABLE CreditCards (
  CreditCardID int IDENTITY(1,1) NOT NULL,
  CreditCardNumber_Plain nvarchar(32)
  );
GO

WITH RandomCreditCards AS (
  SELECT
    CAST(9E+15 * RAND(CHECKSUM(NEWID())) + 1E+15 AS bigint) AS CardNumber
)
INSERT INTO CreditCards (CreditCardNumber_Plain)
  SELECT TOP 100000
    CardNumber
  FROM
    RandomCreditCards,
    MASTER..spt_values a,
    MASTER..spt_values b
  UNION ALL SELECT
    '4005550000000019' AS CardNumber;
GO

-- Create a new certificate
CREATE CERTIFICATE CreditCard_Cert
  ENCRYPTION BY PASSWORD = '#Ch0o53_@_5Tr0nG_P455w0rD#'
  WITH SUBJECT = 'Secure Certificate for Credit Card Information',
  EXPIRY_DATE = '20101031';
GO

-- Create a symmetric key protected by the certificate
CREATE SYMMETRIC KEY CreditCard_SymKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE CreditCard_Cert;
GO

-- Add a new column to the table with symmetric encrypted credit card numbers
ALTER TABLE CreditCards ADD CreditCardNumber_Sym varbinary(100);
GO

OPEN SYMMETRIC KEY CreditCard_SymKey
  DECRYPTION BY CERTIFICATE CreditCard_Cert
  WITH PASSWORD = '#Ch0o53_@_5Tr0nG_P455w0rD#';

UPDATE CreditCards
  SET CreditCardNumber_Sym =   
  ENCRYPTBYKEY(KEY_GUID('CreditCard_SymKey'),CreditCardNumber_Plain);

CLOSE SYMMETRIC KEY CreditCard_SymKey;
GO

-- Create a new index on the encrypted column
CREATE NONCLUSTERED INDEX idxCreditCardNumber_Sym
  ON CreditCards (CreditCardNumber_Sym);
GO

-- Try searching for a value in the encrypted column
DECLARE @CreditCardNumberToSearch nvarchar(32) = '4005550000000019';

SELECT * FROM CreditCards
WHERE DECRYPTBYKEYAUTOCERT(
  CERT_ID('CreditCard_Cert'),
  N'#Ch0o53_@_5Tr0nG_P455w0rD#',
  CreditCardNumber_Sym) = @CreditCardNumberToSearch;
GO

-- Examine the performance
SELECT
  st.text,
  CAST(qs.total_worker_time AS decimal(18,9)) / qs.execution_count / 1000 AS Avg_CPU_Time_ms,
  qs.total_logical_reads
 FROM
  sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
 WHERE
  st.text LIKE '%CreditCardNumberToSearch%';

/*
 * Equality matching using HMAC
 */
  
 -- Create the GenerateHMAC SQLCLR function
 -- Note: You can omit this step by automatically creating the assembly
 -- and function by clicking 'Deploy' from Visual Studio
CREATE ASSEMBLY [Chapter06_Main]  
FROM 'C:\ExpertSqlServer2008\Chapter06_Main\bin\Debug\Chapter06_Main.dll'  
WITH PERMISSION_SET = SAFE;
GO
-- Register the HMAC function
CREATE FUNCTION [dbo].[GenerateHMAC](
  @Algorithm [nvarchar](4000),
  @PlainText [varbinary](max),
  @Key [varbinary](max)
  )
RETURNS [varbinary](max)
AS EXTERNAL NAME [Chapter06_Main].[Chapter06_Main.UserDefinedFunctions].[GenerateHMAC]
GO
 
 -- Create an asymmetric key to protect the HMAC salt
CREATE ASYMMETRIC KEY HMACASymKey
  WITH ALGORITHM = RSA_1024
  ENCRYPTION BY PASSWORD = N'4n0th3r_5tr0ng_K4y!';
GO

-- Store the salt value
CREATE TABLE HMACKeys (
  HMACKeyID int PRIMARY KEY,
  HMACKey varbinary(255)
);
GO

INSERT INTO HMACKeys
SELECT
  1,
  ENCRYPTBYASYMKEY(ASYMKEY_ID(N'HMACASymKey'), N'-->Th15_i5_Th3_HMAC_kEy!');
GO

-- Add a column to the table to store the HMAC
ALTER TABLE CreditCards
ADD CreditCardNumber_HMAC varbinary(255);
GO

-- Retrieve the HMAC salt value from the MACKeys table
DECLARE @salt varbinary(255);
SET @salt = (
  SELECT DECRYPTBYASYMKEY(
      ASYMKEY_ID('HMACASymKey'),
      HMACKey,
      N'4n0th3r_5tr0ng_K4y!'
    )
FROM HMACKeys
WHERE HMACKeyID = 1);

-- Update the HMAC value using the salt
UPDATE CreditCards
SET CreditCardNumber_HMAC = (
  SELECT dbo.GenerateHMAC(
    'SHA256',
    CAST(CreditCardNumber_Plain AS varbinary(max)),
     @salt
  )
);
GO

-- Create a new index on the HMAC Column
CREATE NONCLUSTERED INDEX idxCreditCardNumberHMAC
ON CreditCards (CreditCardNumber_HMAC)
INCLUDE (CreditCardNumber_Sym);
GO

-- Select a credit card to search for
DECLARE @CreditCardNumberToSearch nvarchar(32) = '4005550000000019';

-- Retrieve the secret salt value
DECLARE @salt varbinary(255);
SET @salt = (
  SELECT DECRYPTBYASYMKEY(
      ASYMKEY_ID('HMACASymKey'),
      MACKey,
      N'4n0th3r_5tr0ng_K4y!'
    )
FROM MACKeys);

-- Generate the HMAC of the credit card to search for
DECLARE @HMACToSearch varbinary(255);
SET @HMACToSearch = dbo.GenerateHMAC(
  'SHA256',
  CAST(@CreditCardNumberToSearch AS varbinary(max)),
  @salt);

-- Retrieve the matching row from the CreditCards table
SELECT
CAST(DECRYPTBYKEYAUTOCERT(CERT_ID('CreditCard_Cert'), N'#Ch0o53_@_5Tr0nG_P455w0rD#', CreditCardNumber_Sym) AS nvarchar(32)) AS CreditCardNumber_Decrypted
 FROM CreditCards 
WHERE CreditCardNumber_HMAC = @HMACToSearch
AND 
CAST(DECRYPTBYKEYAUTOCERT(CERT_ID('CreditCard_Cert'), N'#Ch0o53_@_5Tr0nG_P455w0rD#', CreditCardNumber_Sym) AS nvarchar(32)) = @CreditCardNumberToSearch;
GO


/*
 * Wildcard matching using HMAC
 */
CREATE ASYMMETRIC KEY HMACSubStringASymKey
  WITH ALGORITHM = RSA_1024
  ENCRYPTION BY PASSWORD = N'~Y3T_an0+h3r_5tR()ng_K4y~';
GO

INSERT INTO HMACKeys
SELECT
  2,
  ENCRYPTBYASYMKEY(
    ASYMKEY_ID(N'HMACSubStringASymKey'),
    N'->Th15_i$_Th3_HMAC_Sub5Tr1ng_k3y');
GO

ALTER TABLE CreditCards
ADD CreditCardNumber_Last4HMAC varbinary(255);
GO

-- Retrieve the HMAC salt value from the MACKeys table
DECLARE @salt varbinary(255);
SET @salt = (
  SELECT DECRYPTBYASYMKEY(
      ASYMKEY_ID('HMACSubStringASymKey'),
      HMACKey,
      N'~Y3T_an0+h3r_5tR()ng_K4y~'
    )
FROM HMACKeys
WHERE HMACKeyID = 2);

-- Update the Last4HMAC value using the salt
UPDATE CreditCards
SET CreditCardNumber_Last4HMAC = (SELECT dbo.GenerateHMAC(
  'SHA256',
  CAST(RIGHT(CreditCardNumber_Plain, 4) AS varbinary(max)), @salt));
GO

-- Create an index to support wildcard searches
CREATE NONCLUSTERED INDEX idxCreditCardNumberLast4HMAC
ON CreditCards (CreditCardNumber_Last4HMAC)
INCLUDE (CreditCardNumber_Sym);
GO

-- Select the last 4 digits of the credit card to search for
DECLARE @CreditCardLast4ToSearch nchar(4) = '0019';

-- Retrieve the secret salt value
DECLARE @salt varbinary(255);
SET @salt = (
  SELECT DECRYPTBYASYMKEY(
      ASYMKEY_ID('HMACSubStringASymKey'),
      HMACKey,
      N'~Y3T_an0+h3r_5tR()ng_K4y~'
    )
FROM HMACKeys
WHERE HMACKeyID = 2);

-- Generate the HMAC of the last 4 digits to search for
DECLARE @HMACToSearch varbinary(255);
SET @HMACToSearch = dbo.GenerateHMAC(
  'SHA256',
  CAST(@CreditCardLast4ToSearch AS varbinary(max)),
  @salt);

-- Retrieve the matching row from the CreditCards table
SELECT
   CAST(
     DECRYPTBYKEYAUTOCERT(
       CERT_ID('CreditCard_Cert'),
       N'#Ch0o53_@_5Tr0nG_P455w0rD#',
       CreditCardNumber_Sym)
   AS nvarchar(32)) AS CreditCardNumber_Decrypted
FROM
  CreditCards 
WHERE
  CreditCardNumber_Last4HMAC = @HMACToSearch
  AND
  CAST(
    DECRYPTBYKEYAUTOCERT(
      CERT_ID('CreditCard_Cert'),
      N'#Ch0o53_@_5Tr0nG_P455w0rD#',
      CreditCardNumber_Sym)
  AS nvarchar(32)) LIKE '%' + @CreditCardLast4ToSearch;
GO