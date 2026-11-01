# Chinook: transacciones atomicas en PostgreSQL 18

Proyecto de practica para demostrar `COMMIT`, `ROLLBACK`, `SAVEPOINT`, claves foraneas y visibilidad entre dos sesiones usando una copia local de Chinook.


## 1. Requisitos

- PostgreSQL 18.
- Una base de datos local dedicada para esta practica.
- Variante oficial `Chinook_PostgreSql_SerialPKs.sql` del repositorio:
  https://github.com/lerocha/chinook-database
- Cliente `psql`, pgAdmin o DBeaver.
- Dos conexiones independientes (A y B) para la prueba de visibilidad.

## 2. Preparacion segura

1. Descargue el archivo `Chinook_PostgreSql_SerialPKs.sql` desde el repositorio oficial.
2. Revise el script antes de ejecutarlo. La variante puede incluir ordenes para eliminar/crear una base y una metaorden `\\connect`; no la ejecute sobre una base con datos que necesite conservar.
3. Cree una base vacia dedicada, por ejemplo `chinook_practica_tx`.
4. Importe el archivo oficial en esa base siguiendo las instrucciones del repositorio y de su cliente. Si el archivo contiene `\\connect`, ejecútelo con `psql` desde una terminal y ajuste previamente la base destino, o prepare una copia revisada del script para importar solo el esquema/datos en la base dedicada.
5. Confirme la version con:
   ```sql
   SELECT version();
   SHOW server_version;
   ```
6. Ejecute primero las consultas de inspeccion de `sql/04_validaciones.sql`.

No se incluye una copia de la base de datos ni se modifica el archivo oficial.

## 3. Suposiciones de nombres

Los scripts utilizan estas columnas:

- `customer(customer_id)`
- `track(track_id, unit_price)`
- `invoice(invoice_id, customer_id, invoice_date, billing_address, billing_city, billing_state, billing_country, billing_postal_code, total)`
- `invoice_line(invoice_line_id, invoice_id, track_id, unit_price, quantity)`

La consigna describe los nombres de tabla en minusculas y con guion bajo. Algunas distribuciones de Chinook para PostgreSQL conservan nombres entrecomillados como `"Customer"`, `"Invoice"` e `"InvoiceLine"`. Si su importacion tiene esos nombres, adapte los identificadores de los scripts a los nombres reales **antes** de ejecutar. PostgreSQL distingue mayusculas/minusculas en identificadores entrecomillados.

## 4. Orden de ejecucion

Ejecute cada escenario en su propia sesion A, en la misma base de practica:

1. `sql/04_validaciones.sql` — inspeccion previa y consultas de apoyo.
2. `sql/01_venta_exitosa.sql` — venta confirmada.
3. `sql/02_rollback_total.sql` — error de FK y reversión completa.
4. `sql/03_savepoint.sql` — recuperacion parcial.

Los escenarios 2 y 3 tambien pueden ejecutarse por separado. Cada uno crea una factura nueva y utiliza claves generadas por PostgreSQL; no usa `MAX(id)+1`.

## 5. Como ejecutar los scripts

### Opcion A: psql

Conecte la sesion A a la base de practica:

```bash
psql -h localhost -p "puerto" -U postgres -d chinook_practica_tx
```

Ejecute un archivo:

```sql
\i 'C:/ruta/Chinook_Transacciones_Atomicas/sql/04_validaciones.sql'
```

En `psql`, configure `ON_ERROR_STOP` como se indica en cada archivo. Para los escenarios que provocan un error intencional, el cliente debe continuar para ejecutar el bloque de recuperacion. Si su cliente se detiene al primer error, siga el procedimiento manual descrito en cada archivo: ejecute el bloque de recuperacion despues del error, sin cerrar la conexion.

### Opcion B: pgAdmin / DBeaver

Abra una ventana SQL conectada a la base de practica. Ejecute las sentencias en el orden indicado, preferiblemente por bloques. Los scripts usan SQL PostgreSQL estandar y tablas temporales de sesion; mantenga la misma conexion durante cada escenario. Si el editor detiene la ejecucion al encontrar el error intencional, seleccione y ejecute despues el bloque `ROLLBACK` o `ROLLBACK TO SAVEPOINT` correspondiente.

## 6. Autocommit y dos sesiones

- **Sesion A:** abra una conexion y ejecute la transaccion.
- **Sesion B:** abra otra conexion independiente a la misma base.
- Compruebe que `pg_backend_pid()` es diferente en A y B.
- Para la demostracion de visibilidad use `READ COMMITTED`.
- Configure autocommit desactivado si su cliente lo permite. Aun asi, los scripts abren transacciones explicitas con `BEGIN` y terminan con `COMMIT` o `ROLLBACK`.
- En la venta exitosa, ejecute A hasta la consulta previa a `COMMIT`, deje la transaccion abierta y consulte desde B. B no debe ver la factura pendiente. Luego ejecute `COMMIT` en A y repita la consulta desde B.

## 7. Valores y parametros

=No se requieren identificadores manuales de clientes ni canciones. Los scripts seleccionan registros existentes mediante `ORDER BY ... LIMIT`. La referencia invalida se genera usando un entero negativo poco probable y se verifica que no exista antes de intentar insertarla.

Si la consulta previa detecta menos de tres canciones, revise que la importacion de Chinook haya finalizado correctamente.

## 8. Resultado esperado por escenario

| Escenario | Resultado esperado |
|---|---|
| Venta exitosa | Una factura nueva, al menos tres detalles, total igual a la suma de `unit_price * quantity`, COMMIT exitoso. |
| Rollback total | Se produce una violacion real de FK; tras `ROLLBACK` no existe factura ni detalle de esa venta. |
| Savepoint | Los dos detalles anteriores al punto se conservan; el detalle invalido se revierte; se agrega un tercer detalle valido y se confirma. |
| Visibilidad | B no ve la factura antes del COMMIT de A y si la ve despues. |
