SELECT pg_backend_pid() AS pid_sesion_A;

CREATE TEMP TABLE IF NOT EXISTS practica_contexto (
    escenario text PRIMARY KEY,
    invoice_id bigint NOT NULL
) ON COMMIT PRESERVE ROWS;

DELETE FROM practica_contexto WHERE escenario = 'rollback_total';

-- Verifica antes que la referencia negativa elegida no exista en track.
SELECT NOT EXISTS (
    SELECT 1 FROM track WHERE track_id = -987654321
) AS referencia_invalida_no_existe;

-- Inicia una venta nueva.
BEGIN;

-- Crea una cabecera nueva calculando el invoice_id explícitamente.
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
SELECT 'rollback_total', invoice_id
FROM nuevo;

-- Inserta un detalle valido con una cancion existente (calculando invoice_line_id).
INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
SELECT 
    (SELECT COALESCE(MAX(invoice_line_id), 0) FROM invoice_line) + 1 AS invoice_line_id,
    pc.invoice_id, 
    t.track_id, 
    t.unit_price, 
    1
FROM practica_contexto pc
CROSS JOIN (
    SELECT track_id, unit_price FROM track ORDER BY track_id LIMIT 1
) t
WHERE pc.escenario = 'rollback_total';



-- ERROR INTENCIONAL: el track_id no existe y debe violar la FK.
INSERT INTO invoice_line (invoice_line_id, invoice_id, track_id, unit_price, quantity)
SELECT 
    (SELECT COALESCE(MAX(invoice_line_id), 0) FROM invoice_line) + 1,
    invoice_id, -987654321, 0.99, 1
FROM practica_contexto
WHERE escenario = 'rollback_total';

-- BLOQUE DE RECUPERACION: limpia la transacción abortada.
ROLLBACK;

-- Verificación final: la cabecera y los detalles ya no existen.
SELECT pc.invoice_id AS factura_revertida,
       EXISTS (SELECT 1 FROM invoice i WHERE i.invoice_id = pc.invoice_id)
           AS cabecera_sigue_existiendo,
       EXISTS (SELECT 1 FROM invoice_line il WHERE il.invoice_id = pc.invoice_id)
           AS detalles_siguen_existiendo
FROM practica_contexto pc
WHERE pc.escenario = 'rollback_total';  