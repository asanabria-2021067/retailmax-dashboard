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
## Tab 1 — Inventario y Disponibilidad (Ángel y Vernel)

### Indicadores SQL (Asignación: Ángel Sanabria)

Una vez dentro de Metabase, se configurarán los siguientes 3 indicadores (1, 2 y 3) usando **SQL Nativo**.

#### 1. Evolución de Ingresos Mensuales por Canal
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

#### 2. Top 5 Productos por Ganancia Bruta
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

#### 3. Tasa Incidencial de Devoluciones por Tiendas Físicas
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

### Indicadores SQL (Asignación: Vernel Josue)

Una vez dentro de Metabase, se configurarán los siguientes 3 indicadores (4, 5 y 6) usando **SQL Nativo**.

#### 4. Productos con Stock Crítico por Tienda
- **Qué representa:** Muestra los productos cuyo stock actual está por debajo o igual al stock mínimo definido para cada tienda. Incluye la tienda, región, producto, categoría, stock actual, stock mínimo, unidades faltantes y fecha de última reposición.
- **Por qué es importante:** Permite identificar rápidamente qué productos necesitan reposición urgente para evitar quiebres de inventario. Este indicador ayuda al área de operaciones y logística a priorizar abastecimiento por tienda y producto.
- **Visualización sugerida:** **Tabla detallada**. Es la visualización más adecuada porque este indicador requiere ver información específica por tienda y producto, no solo una métrica agregada.
- **Query SQL:**
```sql
SELECT
    t.nombre              AS tienda,
    t.region,
    pr.nombre             AS producto,
    c.nombre              AS categoria,
    i.stock_actual,
    i.stock_minimo,
    (i.stock_minimo - i.stock_actual) AS unidades_faltantes,
    i.ultima_reposicion
FROM inventario i
JOIN tienda    t  ON i.id_tienda   = t.id_tienda
JOIN producto  pr ON i.id_producto = pr.id_producto
JOIN categoria c  ON pr.id_categoria = c.id_categoria
WHERE i.stock_actual <= i.stock_minimo
ORDER BY unidades_faltantes DESC, t.nombre;
```

#### 5. Cobertura de Inventario por Categoría (días)
- **Qué representa:** Calcula cuántos días podría durar el stock disponible por categoría, tomando como base el stock total actual y el promedio de unidades vendidas por día.
- **Por qué es importante:** Ayuda a detectar categorías con riesgo de agotarse pronto y categorías con inventario excesivo. Es útil para planificar reposiciones, redistribuir inventario y mejorar la disponibilidad de productos.
- **Visualización sugerida:** **Tabla o gráfico de barras horizontales**. La tabla permite revisar los valores exactos de stock, ventas promedio y cobertura; el gráfico de barras facilita comparar rápidamente qué categorías tienen menor o mayor cobertura.
- **Query SQL:**
```sql
WITH ventas_por_dia AS (
    SELECT
        pr.id_categoria,
        SUM(dp.cantidad)::NUMERIC
            / NULLIF((MAX(p.fecha) - MIN(p.fecha)), 0) AS unidades_por_dia
    FROM detalle_pedido dp
    JOIN pedido   p  ON dp.id_pedido   = p.id_pedido
    JOIN producto pr ON dp.id_producto = pr.id_producto
    WHERE p.estado = 'completado'
    GROUP BY pr.id_categoria
),
stock_por_categoria AS (
    SELECT
        pr.id_categoria,
        SUM(i.stock_actual) AS stock_total
    FROM inventario i
    JOIN producto pr ON i.id_producto = pr.id_producto
    GROUP BY pr.id_categoria
)
SELECT
    c.nombre                                       AS categoria,
    c.departamento,
    sc.stock_total,
    ROUND(COALESCE(vd.unidades_por_dia, 0), 2)     AS ventas_diarias_promedio,
    CASE
        WHEN COALESCE(vd.unidades_por_dia, 0) = 0 THEN NULL
        ELSE ROUND(sc.stock_total / vd.unidades_por_dia, 0)
    END                                            AS cobertura_dias
FROM categoria c
JOIN stock_por_categoria sc ON c.id_categoria = sc.id_categoria
LEFT JOIN ventas_por_dia vd  ON c.id_categoria = vd.id_categoria
ORDER BY cobertura_dias ASC NULLS LAST;
```

#### 6. Índice de Quiebres de Stock por Tienda (%)
- **Qué representa:** Muestra el porcentaje de productos sin stock disponible en cada tienda. Calcula cuántos productos tienen stock actual igual a cero en relación con el total de productos registrados por tienda.
- **Por qué es importante:** Permite evaluar qué tiendas presentan más problemas de disponibilidad. Un porcentaje alto indica riesgo operativo, pérdida potencial de ventas y necesidad de revisar procesos de reposición o abastecimiento.
- **Visualización sugerida:** **Gráfico de barras o tabla ordenada**. El gráfico de barras permite comparar rápidamente el índice de quiebre entre tiendas; la tabla permite ver el total de productos y cuántos están en quiebre.
- **Query SQL:**
```sql
SELECT
    t.nombre                                                             AS tienda,
    t.region,
    COUNT(*)                                                             AS total_productos,
    SUM(CASE WHEN i.stock_actual = 0 THEN 1 ELSE 0 END)                 AS productos_en_quiebre,
    ROUND(
        SUM(CASE WHEN i.stock_actual = 0 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 2)                                                                 AS indice_quiebre_porcentaje
FROM inventario i
JOIN tienda t ON i.id_tienda = t.id_tienda
GROUP BY t.id_tienda, t.nombre, t.region
ORDER BY indice_quiebre_porcentaje DESC;
```

## Tab 2 — Proveedores y Abastecimiento (Dereck y Alejandro)

### Indicadores SQL (Asignación: Alejandro Jerez)

#### 10. Margen Bruto Promedio por Proveedor
- **Qué representa en términos de negocio:** Para cada proveedor, muestra cuántos productos activos tiene en el catálogo y cuál es el margen bruto promedio de esos productos, calculado como la diferencia porcentual entre el precio de venta y el precio de costo.
- **Por qué es importante para el área:** Operaciones necesita saber no solo qué proveedores surten más, sino cuáles surten productos rentables. Un proveedor con muchos productos pero márgenes bajos puede estar ocupando espacio en el catálogo sin contribuir realmente a la rentabilidad. Esto orienta las negociaciones de precio con proveedores.
- **Visualización usada y justificación:** Gráfico de barras verticales con el eje X siendo el proveedor y el eje Y el margen promedio porcentual. Permite comparar de un vistazo qué proveedores aportan productos más rentables.
- **Query SQL:**

```sql
SELECT
    pv.nombre                                       AS proveedor,
    pv.pais,
    pv.calificacion,
    COUNT(pr.id_producto)                           AS total_productos,
    ROUND(
        AVG(
            ((pr.precio_venta - pr.precio_costo) 
            / pr.precio_costo) * 100
        ), 2
    )                                               AS margen_promedio_porcentaje
FROM proveedor pv
JOIN producto pr ON pv.id_proveedor = pr.id_proveedor
GROUP BY pv.id_proveedor, pv.nombre, pv.pais, pv.calificacion
ORDER BY margen_promedio_porcentaje DESC;
```

#### 11. Ranking de Proveedores por Volumen Entregado y Calificación
- **Qué representa en términos de negocio:** Cruza la calificación registrada de cada proveedor con el volumen real de unidades que sus productos han generado en ventas completadas. Permite ver si los proveedores mejor calificados son también los que más mueven.
- **Por qué es importante para el área:** Logística gestiona la relación con proveedores. Un proveedor con calificación alta pero volumen bajo puede estar siendo subutilizado; uno con volumen alto pero calificación baja es un riesgo operativo (entregas tardías, productos defectuosos). Este indicador orienta negociaciones y decisiones de compra.
- **Visualización usada y justificación:** Gráfico de dispersión con el eje X = calificación del proveedor y el eje Y = unidades vendidas. Cada punto es un proveedor. Permite identificar visualmente los cuatro cuadrantes (bueno/malo × alto/bajo volumen). Si Metabase no tiene scatter nativo en tu versión, usar una tabla ordenada por calificación DESC.
- **Query SQL:**

```sql
SELECT
    pv.nombre                           AS proveedor,
    pv.pais,
    pv.calificacion,
    pv.tiempo_entrega_dias,
    COUNT(DISTINCT pr.id_producto)      AS productos_activos,
    SUM(dp.cantidad)                    AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario
        * (1 - dp.descuento / 100.0))   AS ingresos_generados
FROM proveedor pv
JOIN producto    pr ON pv.id_proveedor = pr.id_proveedor
JOIN detalle_pedido dp ON pr.id_producto  = dp.id_producto
JOIN pedido       p  ON dp.id_pedido     = p.id_pedido
WHERE p.estado = 'completado'
GROUP BY pv.id_proveedor, pv.nombre, pv.pais, pv.calificacion, pv.tiempo_entrega_dias
ORDER BY pv.calificacion DESC, unidades_vendidas DESC;
```

#### 12. Concentración del Catálogo por Proveedor
- **Qué representa en términos de negocio:** Muestra qué porcentaje del catálogo total de productos depende de cada proveedor. Un proveedor con el 40% del catálogo representa un riesgo logístico alto: si falla, casi la mitad de los productos se ve afectada.
- **Por qué es importante para el área:** Es un indicador de riesgo de abastecimiento. Logística debe identificar si hay una dependencia excesiva en pocos proveedores y diversificar. También sirve para priorizar qué relaciones con proveedores son estratégicamente críticas y cuáles son prescindibles.
- **Visualización usada y justificación:** Gráfico de pie, porque el objetivo es mostrar proporciones del total. Cada tajada es un proveedor y se ve de inmediato si alguno domina el catálogo desproporcionadamente.
- **Query SQL:**

```sql
WITH total_productos AS (
    SELECT COUNT(*) AS total
    FROM producto
)
SELECT
    pv.nombre                                           AS proveedor,
    pv.pais,
    COUNT(pr.id_producto)                               AS productos_propios,
    tp.total                                            AS total_catalogo,
    ROUND(
        COUNT(pr.id_producto)::NUMERIC / tp.total * 100
    , 2)                                                AS porcentaje_dependencia
FROM proveedor pv
JOIN producto pr     ON pv.id_proveedor = pr.id_proveedor
CROSS JOIN total_productos tp
GROUP BY pv.id_proveedor, pv.nombre, pv.pais, tp.total
ORDER BY porcentaje_dependencia DESC;
```