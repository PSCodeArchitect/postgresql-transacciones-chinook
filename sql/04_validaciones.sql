-- 04_validaciones.sql
-- Objetivo: verificar version, sesion, aislamiento, nombres y datos existentes.
-- Resultado esperado: PostgreSQL 18; tablas/columnas requeridas disponibles;
-- al menos un cliente y tres canciones.
SELECT pg_backend_pid() AS pid_sesion, current_user, current_database();
BEGIN;

-- Inserta la factura de práctica
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
SELECT invoice_id FROM nuevo; -- (Anota este ID o guárdalo para consultarlo)

-- Inserta los detalles y calcula el total...


SELECT * FROM invoice ORDER BY invoice_id DESC LIMIT 3;





COMMIT;

SELECT * FROM invoice ORDER BY invoice_id DESC LIMIT 3;