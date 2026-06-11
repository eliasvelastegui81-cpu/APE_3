-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Servidor: localhost:3306
-- Tiempo de generación: 04-06-2026 a las 13:17:47
-- Versión del servidor: 11.8.6-MariaDB-0+deb13u1 from Debian
-- Versión de PHP: 8.4.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `Vivero`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_AuditoriaVentasEmpleados` ()   BEGIN
    SELECT 
        e.cedula_PK,
        e.Nombre AS nombre_empleado,
        COUNT(p.Numero_pedido) AS pedidos_gestionados
    FROM PEDIDO p
    RIGHT JOIN EMPLEADOS e ON p.cedula_empleado = e.cedula_PK
    GROUP BY e.cedula_PK, e.Nombre
    ORDER BY pedidos_gestionados DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_HistorialAsignacionesZonas` ()   BEGIN
    SELECT 
        v.ciudad,
        z.Nombre_Zona,
        e.Nombre AS nombre_empleado,
        a.fecha_i AS fecha_inicio,
        a.fecha_f AS fecha_fin
    FROM VIVERO v
    INNER JOIN ZONA z ON v.cod_vivero = z.cod_vivero
    INNER JOIN ASIGNADO a ON z.cod_zona = a.cod_zona
    INNER JOIN EMPLEADOS e ON a.cedula_PK = e.cedula_PK
    ORDER BY a.fecha_i DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_InventarioActivoZonas` ()   BEGIN
    SELECT 
        p.Cod_producto,
        p.nombre_producto,
        u.cod_zona,
        u.stock
    FROM PRODUCTO p
    INNER JOIN UBICA u ON p.Cod_producto = u.Cod_producto
    ORDER BY u.stock DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_LocalizacionBotnicaInventario` ()   BEGIN
    SELECT 
        v.ciudad,
        z.Nombre_Zona,
        p.nombre_producto,
        u.stock
    FROM VIVERO v
    INNER JOIN ZONA z ON v.cod_vivero = z.cod_vivero
    INNER JOIN UBICA u ON z.cod_zona = u.cod_zona
    INNER JOIN PRODUCTO p ON u.Cod_producto = p.Cod_producto
    INNER JOIN PLANTA pl ON p.Cod_producto = pl.Cod_producto;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_ReporteActividadVIP` ()   BEGIN
    SELECT 
        c.cedulacli,
        c.nombre,
        COUNT(p.Numero_pedido) AS total_pedidos_hechos,
        COALESCE(SUM(p.Valor_envio), 0) AS total_invertido_envios
    FROM CUENTA_VIP c
    LEFT JOIN PEDIDO p ON c.cedulacli = p.ci_vip
    GROUP BY c.cedulacli, c.nombre
    ORDER BY total_pedidos_hechos DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `spcm_TrazabilidadCompletaPedidos` ()   BEGIN
    SELECT 
        p.Numero_pedido,
        p.Fecha,
        v.ciudad AS ciudad_vivero,
        e.Nombre AS nombre_empleado,
        c.nombre AS nombre_cliente
    FROM PEDIDO p
    INNER JOIN VIVERO v ON p.cod_vivero = v.cod_vivero
    INNER JOIN EMPLEADOS e ON p.cedula_empleado = e.cedula_PK
    INNER JOIN CUENTA_VIP c ON p.ci_vip = c.cedulacli;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `sp_AlertasStockBajoPorTipo` ()   BEGIN
    SELECT 
        p.Cod_producto,
        p.nombre_producto,
        p.tipo_producto,
        SUM(COALESCE(u.stock, 0)) AS stock_total_viveros,
        promedios.promedio_stock_categoria
    FROM PRODUCTO p
    LEFT JOIN UBICA u ON p.Cod_producto = u.Cod_producto
    INNER JOIN (
        SELECT p2.tipo_producto, AVG(sub.stock_prod) AS promedio_stock_categoria
        FROM PRODUCTO p2
        INNER JOIN (
            SELECT Cod_producto, SUM(stock) AS stock_prod 
            FROM UBICA 
            GROUP BY Cod_producto
        ) sub ON p2.Cod_producto = sub.Cod_producto
        GROUP BY p2.tipo_producto
    ) promedios ON p.tipo_producto = promedios.tipo_producto
    GROUP BY p.Cod_producto, p.nombre_producto, p.tipo_producto, promedios.promedio_stock_categoria
    HAVING stock_total_viveros < promedios.promedio_stock_categoria
    ORDER BY p.tipo_producto ASC, stock_total_viveros ASC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `sp_PedidosEnvioAltoSimplicado` ()   BEGIN
    SELECT 
        v.cod_vivero,
        v.ciudad,
        YEAR(p.Fecha) AS anio_pedido,
        COUNT(p.Numero_pedido) AS cantidad_pedidos_caros,
        SUM(p.Valor_envio) AS total_gastado_en_fletes_altos,
        CASE 
            WHEN COUNT(p.Numero_pedido) >= 3 THEN 'Alerta: Revisar contratos de transporte'
            ELSE 'Logística bajo control'
        END AS estado_alerta
    FROM PEDIDO p
    INNER JOIN VIVERO v ON p.cod_vivero = v.cod_vivero
    -- Consulta Correlacionada: Filtra pedidos que superan el promedio de su propio vivero
    WHERE p.Valor_envio > (
        SELECT AVG(p2.Valor_envio)
        FROM PEDIDO p2
        WHERE p2.cod_vivero = p.cod_vivero
    )
    -- Agrupamiento complejo (por columnas geográficas y temporales)
    GROUP BY v.cod_vivero, v.ciudad, YEAR(p.Fecha)
    ORDER BY anio_pedido DESC, total_gastado_en_fletes_altos DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `sp_ProductosStockSobrePromedio` ()   BEGIN
    SELECT 
        p.Cod_producto,
        p.nombre_producto,
        SUM(u.stock) AS stock_total_actual
    FROM PRODUCTO p
    INNER JOIN UBICA u ON p.Cod_producto = u.Cod_producto
    GROUP BY p.Cod_producto, p.nombre_producto
    HAVING SUM(u.stock) > (
        SELECT AVG(stock) FROM UBICA
    )
    ORDER BY stock_total_actual DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `sp_StockPorCiudadYTipoZona` ()   BEGIN
    SELECT 
        v.ciudad,
        z.Tipo AS tipo_ambiente,
        COUNT(DISTINCT u.Cod_producto) AS variedad_de_articulos,
        SUM(u.stock) AS total_unidades_disponibles
    FROM VIVERO v
    INNER JOIN ZONA z ON v.cod_vivero = z.cod_vivero
    INNER JOIN UBICA u ON z.cod_zona = u.cod_zona
    GROUP BY v.ciudad, z.Tipo
    ORDER BY v.ciudad ASC, total_unidades_disponibles DESC;
END$$

CREATE DEFINER=`Derlin`@`localhost` PROCEDURE `sp_ValoracionInventarioPorVivero` ()   BEGIN
    SELECT 
        v.cod_vivero,
        v.ciudad,
        v.provincia,
        COUNT(DISTINCT u.Cod_producto) AS total_productos_unicos,
        SUM(u.stock) AS stock_total,
        SUM(u.stock * p.precio) AS valoracion_total_usd,
        CASE 
            WHEN SUM(u.stock) > 100 THEN 'Inventario Alto / Sobrestock'
            WHEN SUM(u.stock) BETWEEN 30 AND 100 THEN 'Inventario Moderado / Óptimo'
            ELSE 'Inventario Crítico / Requiere Abastecimiento'
        END AS estado_almacenamiento
    FROM VIVERO v
    LEFT JOIN ZONA z ON v.cod_vivero = z.cod_vivero
    LEFT JOIN UBICA u ON z.cod_zona = u.cod_zona
    LEFT JOIN PRODUCTO p ON u.Cod_producto = p.Cod_producto
    GROUP BY v.cod_vivero, v.ciudad, v.provincia
    HAVING stock_total IS NOT NULL
    ORDER BY valoracion_total_usd DESC;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ASIGNADO`
--

CREATE TABLE `ASIGNADO` (
  `cedula_PK` char(10) NOT NULL,
  `cod_zona` varchar(50) NOT NULL,
  `fecha_i` date NOT NULL,
  `fecha_f` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `ASIGNADO`
--

INSERT INTO `ASIGNADO` (`cedula_PK`, `cod_zona`, `fecha_i`, `fecha_f`) VALUES
('0501234567', 'Z005', '2025-03-20', NULL),
('0923456781', 'Z004', '2025-02-10', NULL),
('1105678901', 'Z007', '2026-02-10', NULL),
('1711122233', 'Z002', '2025-04-01', NULL),
('1718392745', 'Z001', '2025-01-15', NULL),
('1804567890', 'Z006', '2026-01-20', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `AUDITORIA_PRODUCTO`
--

CREATE TABLE `AUDITORIA_PRODUCTO` (
  `id_auditoria` int(11) NOT NULL,
  `Cod_producto` varchar(50) NOT NULL,
  `campo_modificado` varchar(50) NOT NULL,
  `valor_anterior` text DEFAULT NULL,
  `valor_nuevo` text DEFAULT NULL,
  `fecha_cambio` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_db` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `AUDITORIA_PRODUCTO`
--

INSERT INTO `AUDITORIA_PRODUCTO` (`id_auditoria`, `Cod_producto`, `campo_modificado`, `valor_anterior`, `valor_nuevo`, `fecha_cambio`, `usuario_db`) VALUES
(1, 'PROD-TEST-02', 'precio', '15.00', '20.00', '2026-06-03 22:09:05', 'root@localhost');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `CUENTA_VIP`
--

CREATE TABLE `CUENTA_VIP` (
  `cedulacli` char(10) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `fecha_inc` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `CUENTA_VIP`
--

INSERT INTO `CUENTA_VIP` (`cedulacli`, `nombre`, `direccion`, `telefono`, `fecha_inc`) VALUES
('0102345678', 'Santiago Morocho', 'Calle Larga y Benigno Malo, Cuenca', '072845963', '2026-03-01'),
('0603456789', 'Ana Paredes', 'Riobamba, Av. Daniel León Borja', '032945678', '2026-05-10'),
('1304567890', 'Miguel Zambrano', 'Portoviejo, Av. Universitaria', '052345678', '2026-05-15');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `EMPLEADOS`
--

CREATE TABLE `EMPLEADOS` (
  `cedula_PK` char(10) NOT NULL,
  `Nombre` varchar(150) NOT NULL,
  `Telefono` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `EMPLEADOS`
--

INSERT INTO `EMPLEADOS` (`cedula_PK`, `Nombre`, `Telefono`) VALUES
('0501234567', 'José Andrade', '0976543210'),
('0923456781', 'María López', '0987654321'),
('1105678901', 'Patricia Cueva', '0992223344'),
('1711122233', 'Andrea Villacís', '0961234567'),
('1718392745', 'Carlos Mena', '0998765432'),
('1804567890', 'Luis Herrera', '0981112233');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ENCARGADO`
--

CREATE TABLE `ENCARGADO` (
  `cedula_PK` char(10) NOT NULL,
  `cod_vivero` varchar(50) NOT NULL,
  `fecha_i` date NOT NULL,
  `fecha_f` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `ENCARGADO`
--

INSERT INTO `ENCARGADO` (`cedula_PK`, `cod_vivero`, `fecha_i`, `fecha_f`) VALUES
('0501234567', 'VIV003', '2025-03-15', NULL),
('0923456781', 'VIV002', '2025-02-01', NULL),
('1105678901', 'VIV005', '2026-02-01', NULL),
('1718392745', 'VIV001', '2025-01-10', NULL),
('1804567890', 'VIV004', '2026-01-15', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `HISTORICO_STOCK`
--

CREATE TABLE `HISTORICO_STOCK` (
  `id_historico` int(11) NOT NULL,
  `Cod_producto` varchar(50) NOT NULL,
  `cod_zona` varchar(50) NOT NULL,
  `stock_anterior` int(11) NOT NULL,
  `stock_nuevo` int(11) NOT NULL,
  `tipo_movimiento` varchar(20) NOT NULL,
  `motivo` varchar(100) NOT NULL,
  `fecha_movimiento` datetime NOT NULL DEFAULT current_timestamp(),
  `usuario_db` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `HISTORICO_STOCK`
--

INSERT INTO `HISTORICO_STOCK` (`id_historico`, `Cod_producto`, `cod_zona`, `stock_anterior`, `stock_nuevo`, `tipo_movimiento`, `motivo`, `fecha_movimiento`, `usuario_db`) VALUES
(1, 'PROD-TEST-02', 'ZON-01', 50, 48, 'SALIDA', 'Venta en pedido PED-001', '2026-06-03 22:15:34', 'root@localhost'),
(2, 'PROD-TEST-02', 'ZON-01', 50, 48, 'SALIDA', 'Venta en pedido PED-001', '2026-06-03 22:22:19', 'root@localhost');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `INCLUYE`
--

CREATE TABLE `INCLUYE` (
  `Numero_pedido` varchar(50) NOT NULL,
  `Cod_producto` varchar(50) NOT NULL,
  `Cantidad` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `INCLUYE`
--

INSERT INTO `INCLUYE` (`Numero_pedido`, `Cod_producto`, `Cantidad`) VALUES
('PED-001', 'PROD-TEST-02', 2),
('PED001', 'PROD007', 3),
('PED001', 'PROD009', 2),
('PED002', 'PROD008', 4),
('PED002', 'PROD010', 1),
('PED003', 'PROD007', 2),
('PED004', 'PROD008', 1),
('PED005', 'PROD009', 3),
('PED006', 'PROD010', 2),
('PED007', 'PROD007', 4),
('PED008', 'PROD008', 2),
('PED009', 'PROD009', 1),
('PED010', 'PROD010', 2),
('PED011', 'PROD007', 3);

--
-- Disparadores `INCLUYE`
--
DELIMITER $$
CREATE TRIGGER `trg_incluye_descontar_stock_historico` AFTER INSERT ON `INCLUYE` FOR EACH ROW BEGIN
    DECLARE v_cod_vivero VARCHAR(50);
    DECLARE v_cod_zona VARCHAR(50);
    DECLARE v_stock_anterior INT;

    SELECT cod_vivero INTO v_cod_vivero
    FROM PEDIDO
    WHERE Numero_pedido = NEW.Numero_pedido
    LIMIT 1;

    SELECT u.cod_zona, u.stock INTO v_cod_zona, v_stock_anterior
    FROM UBICA u
    INNER JOIN ZONA z ON u.cod_zona = z.cod_zona
    WHERE u.Cod_producto = NEW.Cod_producto
      AND z.cod_vivero = v_cod_vivero
      AND u.stock >= NEW.Cantidad
    ORDER BY u.stock DESC
    LIMIT 1;

    IF v_cod_zona IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No existe una zona con stock suficiente para descontar.';
    END IF;

    UPDATE UBICA
    SET stock = stock - NEW.Cantidad
    WHERE Cod_producto = NEW.Cod_producto
      AND cod_zona = v_cod_zona;

    INSERT INTO HISTORICO_STOCK (
        Cod_producto, cod_zona, stock_anterior, stock_nuevo, tipo_movimiento, motivo, usuario_db
    )
    VALUES (
        NEW.Cod_producto, v_cod_zona, v_stock_anterior, v_stock_anterior - NEW.Cantidad,
        'SALIDA', CONCAT('Venta en pedido ', NEW.Numero_pedido), CURRENT_USER()
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_incluye_validar_insert` BEFORE INSERT ON `INCLUYE` FOR EACH ROW BEGIN
    DECLARE v_cod_vivero VARCHAR(50);
    DECLARE v_stock_disponible INT DEFAULT 0;

    IF NEW.Cantidad IS NULL OR NEW.Cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero.';
    END IF;

    SELECT cod_vivero INTO v_cod_vivero
    FROM PEDIDO
    WHERE Numero_pedido = NEW.Numero_pedido
    LIMIT 1;

    IF v_cod_vivero IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El pedido no tiene un vivero asociado.';
    END IF;

    SELECT COALESCE(MAX(u.stock), 0) INTO v_stock_disponible
    FROM UBICA u
    INNER JOIN ZONA z ON u.cod_zona = z.cod_zona
    WHERE u.Cod_producto = NEW.Cod_producto
      AND z.cod_vivero = v_cod_vivero;

    IF v_stock_disponible < NEW.Cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para registrar el producto en el pedido.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `PEDIDO`
--

CREATE TABLE `PEDIDO` (
  `Numero_pedido` varchar(50) NOT NULL,
  `Valor_envio` decimal(10,2) NOT NULL,
  `Fecha` date NOT NULL,
  `cedula_empleado` char(10) DEFAULT NULL,
  `ci_vip` char(10) DEFAULT NULL,
  `cod_vivero` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `PEDIDO`
--

INSERT INTO `PEDIDO` (`Numero_pedido`, `Valor_envio`, `Fecha`, `cedula_empleado`, `ci_vip`, `cod_vivero`) VALUES
('PED-001', 5.00, '2026-06-03', NULL, NULL, 'VIV-01'),
('PED001', 5.00, '2026-05-20', '1804567890', '0603456789', 'VIV004'),
('PED002', 7.50, '2026-05-22', '1105678901', '1304567890', 'VIV005'),
('PED003', 5.00, '2026-06-01', '1804567890', '0603456789', 'VIV004'),
('PED004', 10.00, '2026-06-02', '1804567890', '0603456789', 'VIV004'),
('PED005', 20.00, '2026-06-03', '1804567890', '0603456789', 'VIV004'),
('PED006', 30.00, '2026-06-04', '1804567890', '0603456789', 'VIV004'),
('PED007', 40.00, '2026-06-05', '1804567890', '0603456789', 'VIV004'),
('PED008', 8.00, '2026-06-06', '1105678901', '1304567890', 'VIV005'),
('PED009', 12.00, '2026-06-07', '1105678901', '1304567890', 'VIV005'),
('PED010', 18.00, '2026-06-08', '1105678901', '1304567890', 'VIV005'),
('PED011', 28.00, '2026-06-09', '1105678901', '1304567890', 'VIV005');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `PLANTA`
--

CREATE TABLE `PLANTA` (
  `Cod_producto` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `PLANTA`
--

INSERT INTO `PLANTA` (`Cod_producto`, `descripcion`) VALUES
('PROD001', 'Planta ornamental de exterior con flor roja.'),
('PROD002', 'Cactus pequeño resistente a climas secos.'),
('PROD003', 'Orquídea de interior con floración blanca.'),
('PROD006', 'Árbol bonsái decorativo para interiores.'),
('PROD007', 'Planta aromática utilizada en jardinería ornamental.'),
('PROD008', 'Suculenta resistente ideal para interiores.');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `PRODUCTO`
--

CREATE TABLE `PRODUCTO` (
  `Cod_producto` varchar(50) NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `tipo_producto` varchar(30) NOT NULL,
  `nombre_producto` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `PRODUCTO`
--

INSERT INTO `PRODUCTO` (`Cod_producto`, `precio`, `tipo_producto`, `nombre_producto`) VALUES
('00001', 10.00, 'PLANTA', 'Girasol'),
('PROD-TEST-02', 20.00, 'PLANTA', 'Orquídea'),
('PROD001', 12.50, 'PLANTA', 'Rosa Roja'),
('PROD002', 8.75, 'PLANTA', 'Cactus Mini'),
('PROD003', 15.00, 'PLANTA', 'Orquídea Blanca'),
('PROD004', 5.50, 'ACCESORIO', 'Maceta de Barro'),
('PROD005', 18.00, 'DECORACION', 'Fuente Decorativa'),
('PROD006', 22.00, 'PLANTA', 'Bonsái'),
('PROD007', 14.50, 'PLANTA', 'Lavanda'),
('PROD008', 7.25, 'PLANTA', 'Suculenta Jade'),
('PROD009', 12.00, 'ACCESORIO', 'Maceta Cerámica'),
('PROD010', 25.00, 'DECORACION', 'Fuente de Piedra');

--
-- Disparadores `PRODUCTO`
--
DELIMITER $$
CREATE TRIGGER `trg_producto_validar_auditar_update` BEFORE UPDATE ON `PRODUCTO` FOR EACH ROW BEGIN
    SET NEW.tipo_producto = UPPER(TRIM(NEW.tipo_producto));
    SET NEW.nombre_producto = TRIM(NEW.nombre_producto);

    IF NEW.precio IS NULL OR NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor que cero.';
    END IF;

    IF NEW.nombre_producto IS NULL OR CHAR_LENGTH(NEW.nombre_producto) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El nombre del producto no puede estar vacío.';
    END IF;

    IF NEW.tipo_producto IS NULL
        OR NEW.tipo_producto NOT IN ('PLANTA', 'ACCESORIO', 'DECORACION') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El tipo de producto debe ser PLANTA, ACCESORIO o DECORACION.';
    END IF;

    IF OLD.precio <> NEW.precio THEN
        INSERT INTO AUDITORIA_PRODUCTO (Cod_producto, campo_modificado, valor_anterior, valor_nuevo, usuario_db)
        VALUES (OLD.Cod_producto, 'precio', OLD.precio, NEW.precio, CURRENT_USER());
    END IF;

    IF OLD.tipo_producto <> NEW.tipo_producto THEN
        INSERT INTO AUDITORIA_PRODUCTO (Cod_producto, campo_modificado, valor_anterior, valor_nuevo, usuario_db)
        VALUES (OLD.Cod_producto, 'tipo_producto', OLD.tipo_producto, NEW.tipo_producto, CURRENT_USER());
    END IF;

    IF OLD.nombre_producto <> NEW.nombre_producto THEN
        INSERT INTO AUDITORIA_PRODUCTO (Cod_producto, campo_modificado, valor_anterior, valor_nuevo, usuario_db)
        VALUES (OLD.Cod_producto, 'nombre_producto', OLD.nombre_producto, NEW.nombre_producto, CURRENT_USER());
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_producto_validar_insert` BEFORE INSERT ON `PRODUCTO` FOR EACH ROW BEGIN
    SET NEW.tipo_producto = UPPER(TRIM(NEW.tipo_producto));
    SET NEW.nombre_producto = TRIM(NEW.nombre_producto);

    IF NEW.precio IS NULL OR NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio del producto debe ser mayor que cero.';
    END IF;

    IF NEW.nombre_producto IS NULL OR CHAR_LENGTH(NEW.nombre_producto) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El nombre del producto no puede estar vacío.';
    END IF;

    IF NEW.tipo_producto IS NULL
        OR NEW.tipo_producto NOT IN ('PLANTA', 'ACCESORIO', 'DECORACION') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El tipo de producto debe ser PLANTA, ACCESORIO o DECORACION.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `UBICA`
--

CREATE TABLE `UBICA` (
  `Cod_producto` varchar(50) NOT NULL,
  `cod_zona` varchar(50) NOT NULL,
  `stock` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `UBICA`
--

INSERT INTO `UBICA` (`Cod_producto`, `cod_zona`, `stock`) VALUES
('PROD-TEST-02', 'ZON-01', 48),
('PROD001', 'Z001', 50),
('PROD002', 'Z004', 35),
('PROD003', 'Z005', 20),
('PROD004', 'Z003', 60),
('PROD005', 'Z003', 10),
('PROD006', 'Z002', 12),
('PROD007', 'Z006', 50),
('PROD008', 'Z006', 40),
('PROD009', 'Z007', 30),
('PROD010', 'Z007', 15);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `VIVERO`
--

CREATE TABLE `VIVERO` (
  `cod_vivero` varchar(50) NOT NULL,
  `provincia` varchar(100) NOT NULL,
  `ciudad` varchar(100) NOT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `VIVERO`
--

INSERT INTO `VIVERO` (`cod_vivero`, `provincia`, `ciudad`, `telefono`, `direccion`) VALUES
('VIV-01', 'Bolivar', 'Guaranda', NULL, 'Centro'),
('VIV001', 'Pichincha', 'Quito', '022345678', 'Av. Amazonas y Naciones Unidas'),
('VIV002', 'Guayas', 'Guayaquil', '042567890', 'Av. Francisco de Orellana'),
('VIV003', 'Cotopaxi', 'Latacunga', '032345678', 'Sector La Laguna'),
('VIV004', 'Cotopaxi', 'Latacunga', '032800111', 'Av. Amazonas y Quito'),
('VIV005', 'Tungurahua', 'Ambato', '032801222', 'Av. Cevallos y Mera');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ZONA`
--

CREATE TABLE `ZONA` (
  `cod_zona` varchar(50) NOT NULL,
  `Nombre_Zona` varchar(100) NOT NULL,
  `Tipo` varchar(50) DEFAULT NULL,
  `cod_vivero` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Volcado de datos para la tabla `ZONA`
--

INSERT INTO `ZONA` (`cod_zona`, `Nombre_Zona`, `Tipo`, `cod_vivero`) VALUES
('Z001', 'Zona Ornamentales', 'EXTERIOR', 'VIV001'),
('Z002', 'Zona Tropical', 'INVERNADERO', 'VIV001'),
('Z003', 'Zona Herramientas', 'BODEGA', 'VIV001'),
('Z004', 'Zona Cactus', 'EXTERIOR', 'VIV002'),
('Z005', 'Zona Flores', 'INVERNADERO', 'VIV003'),
('Z006', 'Zona Aromáticas', 'Producción', 'VIV004'),
('Z007', 'Zona Ornamentales', 'Exhibición', 'VIV005'),
('ZON-01', 'Invernadero A', 'Exhibicion', 'VIV-01');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `ASIGNADO`
--
ALTER TABLE `ASIGNADO`
  ADD PRIMARY KEY (`cedula_PK`,`cod_zona`,`fecha_i`),
  ADD KEY `cod_zona` (`cod_zona`);

--
-- Indices de la tabla `AUDITORIA_PRODUCTO`
--
ALTER TABLE `AUDITORIA_PRODUCTO`
  ADD PRIMARY KEY (`id_auditoria`);

--
-- Indices de la tabla `CUENTA_VIP`
--
ALTER TABLE `CUENTA_VIP`
  ADD PRIMARY KEY (`cedulacli`);

--
-- Indices de la tabla `EMPLEADOS`
--
ALTER TABLE `EMPLEADOS`
  ADD PRIMARY KEY (`cedula_PK`);

--
-- Indices de la tabla `ENCARGADO`
--
ALTER TABLE `ENCARGADO`
  ADD PRIMARY KEY (`cedula_PK`,`cod_vivero`,`fecha_i`),
  ADD KEY `cod_vivero` (`cod_vivero`);

--
-- Indices de la tabla `HISTORICO_STOCK`
--
ALTER TABLE `HISTORICO_STOCK`
  ADD PRIMARY KEY (`id_historico`);

--
-- Indices de la tabla `INCLUYE`
--
ALTER TABLE `INCLUYE`
  ADD PRIMARY KEY (`Numero_pedido`,`Cod_producto`),
  ADD KEY `Cod_producto` (`Cod_producto`);

--
-- Indices de la tabla `PEDIDO`
--
ALTER TABLE `PEDIDO`
  ADD PRIMARY KEY (`Numero_pedido`),
  ADD KEY `cedula_empleado` (`cedula_empleado`),
  ADD KEY `ci_vip` (`ci_vip`),
  ADD KEY `cod_vivero` (`cod_vivero`);

--
-- Indices de la tabla `PLANTA`
--
ALTER TABLE `PLANTA`
  ADD PRIMARY KEY (`Cod_producto`);

--
-- Indices de la tabla `PRODUCTO`
--
ALTER TABLE `PRODUCTO`
  ADD PRIMARY KEY (`Cod_producto`);

--
-- Indices de la tabla `UBICA`
--
ALTER TABLE `UBICA`
  ADD PRIMARY KEY (`Cod_producto`,`cod_zona`),
  ADD KEY `cod_zona` (`cod_zona`);

--
-- Indices de la tabla `VIVERO`
--
ALTER TABLE `VIVERO`
  ADD PRIMARY KEY (`cod_vivero`);

--
-- Indices de la tabla `ZONA`
--
ALTER TABLE `ZONA`
  ADD PRIMARY KEY (`cod_zona`),
  ADD KEY `cod_vivero` (`cod_vivero`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `AUDITORIA_PRODUCTO`
--
ALTER TABLE `AUDITORIA_PRODUCTO`
  MODIFY `id_auditoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `HISTORICO_STOCK`
--
ALTER TABLE `HISTORICO_STOCK`
  MODIFY `id_historico` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `ASIGNADO`
--
ALTER TABLE `ASIGNADO`
  ADD CONSTRAINT `ASIGNADO_ibfk_1` FOREIGN KEY (`cedula_PK`) REFERENCES `EMPLEADOS` (`cedula_PK`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `ASIGNADO_ibfk_2` FOREIGN KEY (`cod_zona`) REFERENCES `ZONA` (`cod_zona`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `ENCARGADO`
--
ALTER TABLE `ENCARGADO`
  ADD CONSTRAINT `ENCARGADO_ibfk_1` FOREIGN KEY (`cedula_PK`) REFERENCES `EMPLEADOS` (`cedula_PK`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `ENCARGADO_ibfk_2` FOREIGN KEY (`cod_vivero`) REFERENCES `VIVERO` (`cod_vivero`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `INCLUYE`
--
ALTER TABLE `INCLUYE`
  ADD CONSTRAINT `INCLUYE_ibfk_1` FOREIGN KEY (`Numero_pedido`) REFERENCES `PEDIDO` (`Numero_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `INCLUYE_ibfk_2` FOREIGN KEY (`Cod_producto`) REFERENCES `PRODUCTO` (`Cod_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `PEDIDO`
--
ALTER TABLE `PEDIDO`
  ADD CONSTRAINT `PEDIDO_ibfk_1` FOREIGN KEY (`cedula_empleado`) REFERENCES `EMPLEADOS` (`cedula_PK`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `PEDIDO_ibfk_2` FOREIGN KEY (`ci_vip`) REFERENCES `CUENTA_VIP` (`cedulacli`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `PEDIDO_ibfk_3` FOREIGN KEY (`cod_vivero`) REFERENCES `VIVERO` (`cod_vivero`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Filtros para la tabla `PLANTA`
--
ALTER TABLE `PLANTA`
  ADD CONSTRAINT `PLANTA_ibfk_1` FOREIGN KEY (`Cod_producto`) REFERENCES `PRODUCTO` (`Cod_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `UBICA`
--
ALTER TABLE `UBICA`
  ADD CONSTRAINT `UBICA_ibfk_1` FOREIGN KEY (`Cod_producto`) REFERENCES `PRODUCTO` (`Cod_producto`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `UBICA_ibfk_2` FOREIGN KEY (`cod_zona`) REFERENCES `ZONA` (`cod_zona`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `ZONA`
--
ALTER TABLE `ZONA`
  ADD CONSTRAINT `ZONA_ibfk_1` FOREIGN KEY (`cod_vivero`) REFERENCES `VIVERO` (`cod_vivero`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
