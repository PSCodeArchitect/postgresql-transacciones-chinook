-- 03_savepoint.sql
-- Objetivo: conservar dos detalles validos, deshacer solo el intento invalido,
-- agregar un detalle corregido y confirmar la factura.
-- Ejecutar en una sola conexion. Si el cliente se detiene al error de FK,
-- ejecute manualmente ROLLBACK TO SAVEPOINT y continue con el bloque posterior.
ROLLBACK;

CREATE TEMP TABLE IF NOT EXISTS practica_contexto (
    escenario text PRIMARY KEY,
    invoice_id bigint NOT NULL
) ON COMMIT PRESERVE ROWS;

DELETE FROM practica_contexto WHERE escenario = 'savepoint';

BEGIN;

WITH nuevo AS (
    INSERT INTO invoice (
        invoice_id, customer_id, invoice_date, billing_address, billing_city,
        billing_state, billing_country, billing_postal_code, total
    )
    SELECT
        (SELECT COALESCE(MAX(invoice_id), 0) + 1 FROM invoice),
        customer_id, CURRENT_TIMESTAMP, address, city, state,
        country, postal_code, 0.00
    FROM customer
    ORDER BY customer_id
    LIMIT 1
    RETURNING invoice_id
)
INSERT INTO practica_contexto (escenario, invoice_id)
SELECT 'savepoint', invoice_id
FROM nuevo;

INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
SELECT
    (SELECT COALESCE(MAX(invoice_line_id), 0) FROM invoice_line) + ROW_NUMBER() OVER () AS invoice_line_id,
    pc.invoice_id,
    t.track_id,
    t.unit_price,
    1
FROM practica_contexto pc
CROSS JOIN (
    SELECT track_id, unit_price
    FROM track
    ORDER BY track_id
    LIMIT 2
) t
WHERE pc.escenario = 'savepoint';

SAVEPOINT antes_detalle_riesgoso;


-- Intento fallido intencional que dispara la FK
INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
SELECT
    (SELECT COALESCE(MAX(invoice_line_id), 0) FROM invoice_line) + 1,
    invoice_id, -987654322, 0.99, 1
FROM practica_contexto
WHERE escenario = 'savepoint';

-- Recupera inmediatamente el estado desde el savepoint para limpiar el error
ROLLBACK TO SAVEPOINT antes_detalle_riesgoso;

-- Agrega el tercer detalle válido (corregido)
INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
SELECT
    (SELECT COALESCE(MAX(invoice_line_id), 0) FROM invoice_line) + 1 AS invoice_line_id,
    pc.invoice_id,
    t.track_id,
    t.unit_price,
    1
FROM practica_contexto pc
CROSS JOIN (
    SELECT track_id, unit_price
    FROM track
    ORDER BY track_id
    OFFSET 2 LIMIT 1
) t
WHERE pc.escenario = 'savepoint';

-- Recalcula el total
UPDATE invoice i
SET total = (
    SELECT COALESCE(SUM(il.unit_price * il.quantity), 0)::numeric(10,2)
    FROM invoice_line il
    WHERE il.invoice_id = i.invoice_id
)
FROM practica_contexto pc
WHERE pc.escenario = 'savepoint'
  AND i.invoice_id = pc.invoice_id;

-- Consulta de verificación (¡Toma aquí tu captura del ANTES!)
SELECT i.invoice_id,
       i.total AS total_factura,
       COUNT(il.invoice_line_id) AS cantidad_detalles,
       SUM(il.unit_price * il.quantity)::numeric(10,2) AS suma_detalles,
       i.total = SUM(il.unit_price * il.quantity)::numeric(10,2) AS total_coincide
FROM invoice i
JOIN practica_contexto pc ON pc.invoice_id = i.invoice_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
WHERE pc.escenario = 'savepoint'
GROUP BY i.invoice_id, i.total;


RELEASE SAVEPOINT antes_detalle_riesgoso;
COMMIT;

SELECT i.invoice_id,
       i.total,
       COUNT(il.invoice_line_id) AS detalles_finales,
       SUM(il.unit_price * il.quantity)::numeric(10,2) AS suma_detalles,
       i.total = SUM(il.unit_price * il.quantity)::numeric(10,2) AS total_coincide
FROM invoice i
JOIN practica_contexto pc ON pc.invoice_id = i.invoice_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
WHERE pc.escenario = 'savepoint'
GROUP BY i.invoice_id, i.total;