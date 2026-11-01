-- 01_venta_exitosa.sql
-- Objetivo: crear una factura con tres detalles, calcular el total y confirmar.
-- IMPORTANTE: ejecutar todo en la misma conexion A.
-- Para la prueba de visibilidad, ejecute las sentencias hasta el bloque
-- "PAUSA PARA SESION B", consulte desde B y SOLO DESPUES ejecute COMMIT.

-- Identifica la sesion A y configura READ COMMITTED.
ROLLBACK;

SELECT pg_backend_pid() AS pid_sesion_A, current_database() AS base_actual;
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Tabla temporal para conservar el id devuelto por INSERT durante esta sesion.
CREATE TEMP TABLE IF NOT EXISTS practica_contexto (
    escenario text PRIMARY KEY,
    invoice_id bigint NOT NULL
) ON COMMIT PRESERVE ROWS;

DELETE FROM practica_contexto WHERE escenario = 'venta_exitosa';

-- Comienza la operacion atomica.
BEGIN;

-- Crea una factura nueva calculando el invoice_id explícitamente.
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
SELECT 'venta_exitosa', invoice_id
FROM nuevo;

-- Muestra el identificador recuperado con RETURNING.
SELECT escenario, invoice_id
FROM practica_contexto
WHERE escenario = 'venta_exitosa';

-- Inserta tres canciones calculando el invoice_line_id explícitamente.
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
    LIMIT 3
) AS t
WHERE pc.escenario = 'venta_exitosa';

-- Calcula el total desde los detalles; no se escribe un total supuesto.
UPDATE invoice i
SET total = (
    SELECT COALESCE(SUM(il.unit_price * il.quantity), 0)::numeric(10,2)
    FROM invoice_line il
    WHERE il.invoice_id = i.invoice_id
)
FROM practica_contexto pc
WHERE pc.escenario = 'venta_exitosa'
AND i.invoice_id = pc.invoice_id;

-- Comprueba cantidad de detalles y coincidencia exacta del total antes de confirmar.
SELECT i.invoice_id,
    i.total AS total_factura,
    COUNT(il.invoice_line_id) AS cantidad_detalles,
    COALESCE(SUM(il.unit_price * il.quantity), 0)::numeric(10,2) AS suma_detalles,
    i.total = COALESCE(SUM(il.unit_price * il.quantity), 0)::numeric(10,2) AS total_coincide
FROM invoice i
JOIN practica_contexto pc ON pc.invoice_id = i.invoice_id
LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id
WHERE pc.escenario = 'venta_exitosa'
GROUP BY i.invoice_id, i.total;

-- PAUSA PARA SESION B:
-- Sin confirmar todavia, copie el invoice_id anterior y consulte en B:
-- SELECT * FROM invoice WHERE invoice_id = <id_obtenido>;
-- SELECT * FROM invoice_line WHERE invoice_id = <id_obtenido>;
-- Resultado esperado en B: cero filas porque A aun no ha hecho COMMIT.

-- Confirma la factura y todos sus detalles como una sola operacion.
COMMIT;

-- Verifica nuevamente en A que la factura confirmada tiene tres detalles.
SELECT i.invoice_id,
        i.total,
        COUNT(il.invoice_line_id) AS cantidad_detalles,
        SUM(il.unit_price * il.quantity)::numeric(10,2) AS suma_detalles
FROM invoice i
JOIN practica_contexto pc ON pc.invoice_id = i.invoice_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
WHERE pc.escenario = 'venta_exitosa'
GROUP BY i.invoice_id, i.total;
-- Resultado esperado: cantidad_detalles >= 3 y total = suma_detalles.
