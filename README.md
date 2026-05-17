# RetailMax Analytics Environment

Este repositorio contiene la arquitectura y el ambiente Docker para la base de datos y plataforma analítica de RetailMax, con un enfoque *zero-touch* en la inicialización.

## Arquitectura (Monorepo)
- `services/database/init-scripts/`: Scripts DDL y DATA (se inyectan automáticamente a PostgreSQL al inicializar el contenedor por primera vez).
- `services/metabase-setup/`: Contenedor efímero con un script que configura automáticamente a Metabase vía API para evitar pasos de configuración manuales.
- `docker-compose.yml`: Orquestador principal que levanta Postgres, Metabase y el Setup Automático.

## Instrucciones de Uso

1. Levanta el ambiente ejecutando:
   ```bash
   docker compose up -d --build
   ```
2. El proceso levantará PostgreSQL, cargará toda la data, arrancará Metabase y ejecutará el setup automático para enlazar la base de datos y crear el usuario administrador.
3. Ingresa a **http://localhost:3000**.
4. **Credenciales de calificación:**
   - **Correo:** `calificar@uvg.edu.gt`
   - **Clave:** `secret123+`

---

## Indicadores SQL (Asignación: Ángel Sanabria)

Una vez dentro de Metabase, se configurarán los siguientes 3 indicadores (1, 2 y 3) usando **SQL Nativo**.

### 1. Evolución de Ingresos Mensuales por Canal
- **Qué representa:** El total monetario de ventas efectivas (descontando el porcentaje de descuento de cada producto) agrupado por mes y separado por compras en tienda física vs. online.
- **Por qué es importante:** Permite evaluar el crecimiento financiero de la empresa en el tiempo y observar qué canal está impulsando más las ventas o requiere estrategias de marketing.
- **Visualización sugerida:** **Gráfico de Líneas con series (Canal)**. El eje X será el tiempo (mes) y el eje Y los ingresos, ideal para ver y comparar tendencias temporales.
- **Query SQL:**
```sql
SELECT 
    DATE_TRUNC('month', p.fecha) AS mes,
    p.canal,
    SUM(dp.cantidad * dp.precio_unitario * (1 - (dp.descuento / 100.0))) AS ingresos_totales
FROM pedido p
JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.estado IN ('completado', 'pendiente')
GROUP BY DATE_TRUNC('month', p.fecha), p.canal
ORDER BY mes ASC, p.canal;
```

### 2. Top 5 Productos por Ganancia Bruta
- **Qué representa:** Identifica los 5 productos específicos que más ganancia monetaria neta han generado, restando su costo al proveedor de su precio de venta, y multiplicándolo por la cantidad vendida.
- **Por qué es importante:** Ayuda al equipo de compras e inventario a priorizar el stock de estos productos clave, ya que son los verdaderos motores de rentabilidad para RetailMax (el volumen de ventas sin evaluar márgenes puede ser engañoso).
- **Visualización sugerida:** **Gráfico de Barras Horizontales**. Excelente para rankings, permite leer los nombres largos de los productos fácilmente de izquierda a derecha.
- **Query SQL:**
```sql
SELECT 
    pr.nombre AS producto,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.cantidad * (pr.precio_venta - pr.precio_costo)) AS ganancia_bruta
FROM detalle_pedido dp
JOIN pedido p ON dp.id_pedido = p.id_pedido
JOIN producto pr ON dp.id_producto = pr.id_producto
WHERE p.estado = 'completado'
GROUP BY pr.id_producto, pr.nombre
ORDER BY ganancia_bruta DESC
LIMIT 5;
```

### 3. Tasa Incidencial de Devoluciones por Tienda Físicas
- **Qué representa:** El porcentaje de pedidos realizados en tiendas físicas que resultaron en una o más devoluciones (por producto defectuoso, mala manipulación, etc).
- **Por qué es importante:** Identifica posibles problemas operativos locales en ciertas regiones. Ayuda a focalizar inspecciones, entrenamientos para el staff de esa tienda específica o detectar problemas en la cadena de suministro local.
- **Visualización sugerida:** **Tabla o Gráfico de Barras**. Una tabla con formato condicional (barra de progreso) permite detectar rápidamente en la columna de porcentaje cuáles son las tiendas con problemas.
- **Query SQL:**
```sql
WITH pedidos_por_tienda AS (
    SELECT id_tienda, COUNT(DISTINCT id_pedido) AS total_pedidos
    FROM pedido
    WHERE canal = 'tienda'
    GROUP BY id_tienda
),
devoluciones_por_tienda AS (
    SELECT p.id_tienda, COUNT(DISTINCT d.id_devolucion) AS total_devoluciones
    FROM devolucion d
    JOIN pedido p ON d.id_pedido = p.id_pedido
    WHERE p.canal = 'tienda'
    GROUP BY p.id_tienda
)
SELECT 
    t.nombre AS tienda,
    COALESCE(pt.total_pedidos, 0) AS total_pedidos,
    COALESCE(dt.total_devoluciones, 0) AS total_devoluciones,
    ROUND((COALESCE(dt.total_devoluciones, 0)::NUMERIC / NULLIF(pt.total_pedidos, 0)) * 100, 2) AS tasa_devolucion_porcentaje
FROM tienda t
LEFT JOIN pedidos_por_tienda pt ON t.id_tienda = pt.id_tienda
LEFT JOIN devoluciones_por_tienda dt ON t.id_tienda = dt.id_tienda
ORDER BY tasa_devolucion_porcentaje DESC;
```
