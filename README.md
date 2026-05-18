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

#### 3. Tasa Incidencial de Devoluciones por Tienda Físicas
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
- **Qué representa en términos de negocio:** PMuestra qué porcentaje del catálogo total de productos depende de cada proveedor. Un proveedor con el 40% del catálogo representa un riesgo logístico alto: si falla, casi la mitad de los productos se ve afectada.
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