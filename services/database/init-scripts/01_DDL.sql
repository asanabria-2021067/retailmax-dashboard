-- =============================================================
-- RetailMax -- Base de datos de laboratorio
-- CC3008 Base de Datos 1 | Universidad del Valle de Guatemala
-- =============================================================

-- Eliminar tablas si existen (orden inverso a FK)
DROP TABLE IF EXISTS campana_cliente   CASCADE;
DROP TABLE IF EXISTS campana           CASCADE;
DROP TABLE IF EXISTS devolucion        CASCADE;
DROP TABLE IF EXISTS inventario        CASCADE;
DROP TABLE IF EXISTS pago              CASCADE;
DROP TABLE IF EXISTS detalle_pedido    CASCADE;
DROP TABLE IF EXISTS pedido            CASCADE;
DROP TABLE IF EXISTS producto          CASCADE;
DROP TABLE IF EXISTS proveedor         CASCADE;
DROP TABLE IF EXISTS categoria         CASCADE;
DROP TABLE IF EXISTS empleado          CASCADE;
DROP TABLE IF EXISTS cliente           CASCADE;
DROP TABLE IF EXISTS tienda            CASCADE;

-- =============================================================
-- TIENDA
-- =============================================================
CREATE TABLE tienda (
    id_tienda       SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    ciudad          VARCHAR(100)    NOT NULL,
    region          VARCHAR(50)     NOT NULL,
    fecha_apertura  DATE            NOT NULL
);

-- =============================================================
-- CLIENTE
-- =============================================================
CREATE TABLE cliente (
    id_cliente      SERIAL          PRIMARY KEY,
    nombre          VARCHAR(150)    NOT NULL,
    segmento        VARCHAR(20)     NOT NULL
                        CHECK (segmento IN ('VIP', 'regular', 'nuevo')),
    ciudad          VARCHAR(100)    NOT NULL,
    fecha_registro  DATE            NOT NULL
);

-- =============================================================
-- EMPLEADO
-- =============================================================
CREATE TABLE empleado (
    id_empleado         SERIAL          PRIMARY KEY,
    nombre              VARCHAR(150)    NOT NULL,
    puesto              VARCHAR(100)    NOT NULL,
    id_tienda           INT             NOT NULL
                            REFERENCES tienda (id_tienda),
    salario             NUMERIC(10,2)   NOT NULL
                            CHECK (salario > 0),
    fecha_contratacion  DATE            NOT NULL,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);

-- =============================================================
-- CATEGORIA
-- =============================================================
CREATE TABLE categoria (
    id_categoria    SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    departamento    VARCHAR(100)    NOT NULL
);

-- =============================================================
-- PROVEEDOR
-- =============================================================
CREATE TABLE proveedor (
    id_proveedor            SERIAL          PRIMARY KEY,
    nombre                  VARCHAR(150)    NOT NULL,
    pais                    VARCHAR(100)    NOT NULL,
    tiempo_entrega_dias     INT             NOT NULL
                                CHECK (tiempo_entrega_dias > 0),
    calificacion            NUMERIC(3,1)    NOT NULL
                                CHECK (calificacion BETWEEN 1.0 AND 5.0)
);

-- =============================================================
-- PRODUCTO
-- =============================================================
CREATE TABLE producto (
    id_producto     SERIAL          PRIMARY KEY,
    nombre          VARCHAR(150)    NOT NULL,
    id_categoria    INT             NOT NULL
                        REFERENCES categoria (id_categoria),
    id_proveedor    INT             NOT NULL
                        REFERENCES proveedor (id_proveedor),
    precio_costo    NUMERIC(10,2)   NOT NULL
                        CHECK (precio_costo > 0),
    precio_venta    NUMERIC(10,2)   NOT NULL
                        CHECK (precio_venta > 0)
);

-- =============================================================
-- PEDIDO
-- =============================================================
CREATE TABLE pedido (
    id_pedido       SERIAL          PRIMARY KEY,
    id_cliente      INT             NOT NULL
                        REFERENCES cliente (id_cliente),
    id_empleado     INT             NOT NULL
                        REFERENCES empleado (id_empleado),
    id_tienda       INT             NOT NULL
                        REFERENCES tienda (id_tienda),
    fecha           DATE            NOT NULL,
    estado          VARCHAR(20)     NOT NULL
                        CHECK (estado IN ('pendiente', 'completado', 'cancelado', 'devuelto')),
    canal           VARCHAR(20)     NOT NULL
                        CHECK (canal IN ('tienda', 'online'))
);

-- =============================================================
-- DETALLE_PEDIDO
-- =============================================================
CREATE TABLE detalle_pedido (
    id_detalle      SERIAL          PRIMARY KEY,
    id_pedido       INT             NOT NULL
                        REFERENCES pedido (id_pedido),
    id_producto     INT             NOT NULL
                        REFERENCES producto (id_producto),
    cantidad        INT             NOT NULL
                        CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2)   NOT NULL
                        CHECK (precio_unitario > 0),
    descuento       NUMERIC(5,2)    NOT NULL DEFAULT 0.00
                        CHECK (descuento BETWEEN 0 AND 100)
);

-- =============================================================
-- PAGO
-- =============================================================
CREATE TABLE pago (
    id_pago     SERIAL          PRIMARY KEY,
    id_pedido   INT             NOT NULL
                    REFERENCES pedido (id_pedido),
    metodo      VARCHAR(20)     NOT NULL
                    CHECK (metodo IN ('efectivo', 'tarjeta', 'transferencia')),
    monto       NUMERIC(10,2)   NOT NULL
                    CHECK (monto > 0),
    fecha       DATE            NOT NULL
);

-- =============================================================
-- INVENTARIO
-- =============================================================
CREATE TABLE inventario (
    id_producto         INT             NOT NULL
                            REFERENCES producto (id_producto),
    id_tienda           INT             NOT NULL
                            REFERENCES tienda (id_tienda),
    stock_actual        INT             NOT NULL
                            CHECK (stock_actual >= 0),
    stock_minimo        INT             NOT NULL
                            CHECK (stock_minimo >= 0),
    ultima_reposicion   DATE,
    PRIMARY KEY (id_producto, id_tienda)
);

-- =============================================================
-- DEVOLUCION
-- =============================================================
CREATE TABLE devolucion (
    id_devolucion   SERIAL          PRIMARY KEY,
    id_pedido       INT             NOT NULL
                        REFERENCES pedido (id_pedido),
    id_producto     INT             NOT NULL
                        REFERENCES producto (id_producto),
    fecha           DATE            NOT NULL,
    motivo          VARCHAR(50)     NOT NULL
                        CHECK (motivo IN (
                            'producto defectuoso',
                            'producto incorrecto',
                            'no cumple expectativas',
                            'dano en transporte',
                            'otro'
                        )),
    monto_reembolso NUMERIC(10,2)   NOT NULL
                        CHECK (monto_reembolso > 0)
);

-- =============================================================
-- CAMPANA
-- =============================================================
CREATE TABLE campana (
    id_campana      SERIAL          PRIMARY KEY,
    nombre          VARCHAR(150)    NOT NULL,
    tipo            VARCHAR(50)     NOT NULL
                        CHECK (tipo IN ('email', 'redes sociales', 'SMS', 'descuento directo')),
    fecha_inicio    DATE            NOT NULL,
    fecha_fin       DATE            NOT NULL,
    presupuesto     NUMERIC(12,2)   NOT NULL
                        CHECK (presupuesto > 0),
    canal           VARCHAR(20)     NOT NULL
                        CHECK (canal IN ('tienda', 'online', 'ambos')),
    CHECK (fecha_fin >= fecha_inicio)
);

-- =============================================================
-- CAMPANA_CLIENTE
-- =============================================================
CREATE TABLE campana_cliente (
    id_campana  INT         NOT NULL
                    REFERENCES campana (id_campana),
    id_cliente  INT         NOT NULL
                    REFERENCES cliente (id_cliente),
    respondio   BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_campana, id_cliente)
);

-- =============================================================
-- ÍNDICES para columnas frecuentemente consultadas
-- =============================================================
CREATE INDEX idx_pedido_fecha        ON pedido (fecha);
CREATE INDEX idx_pedido_id_cliente   ON pedido (id_cliente);
CREATE INDEX idx_pedido_id_tienda    ON pedido (id_tienda);
CREATE INDEX idx_pedido_canal        ON pedido (canal);
CREATE INDEX idx_detalle_id_pedido   ON detalle_pedido (id_pedido);
CREATE INDEX idx_detalle_id_producto ON detalle_pedido (id_producto);
CREATE INDEX idx_empleado_id_tienda  ON empleado (id_tienda);
CREATE INDEX idx_producto_id_cat     ON producto (id_categoria);
CREATE INDEX idx_producto_id_prov    ON producto (id_proveedor);
CREATE INDEX idx_devolucion_fecha    ON devolucion (fecha);
CREATE INDEX idx_campana_fechas      ON campana (fecha_inicio, fecha_fin);
