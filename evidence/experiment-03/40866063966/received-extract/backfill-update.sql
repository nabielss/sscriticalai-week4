\timing on
UPDATE invoices
SET currency = CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END;
