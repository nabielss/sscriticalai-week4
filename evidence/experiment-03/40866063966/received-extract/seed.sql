DROP TABLE IF EXISTS invoices CASCADE;
CREATE TABLE invoices (
  id integer PRIMARY KEY,
  country text,
  amount numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO invoices (id, country, amount, created_at)
SELECT g,
       CASE g % 3 WHEN 0 THEN 'DE' WHEN 1 THEN 'ID' ELSE 'US' END,
       (g % 100000)::numeric / 100,
       timestamptz '2020-01-01 00:00:00+00' + g * interval '1 second'
FROM generate_series(1, 100000) AS g;
