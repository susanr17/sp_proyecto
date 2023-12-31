USE [db_a9f761_pandemitierra]
GO
/****** Object:  StoredProcedure [dbo].[SP_CALCULAR_TEMPORAL]    Script Date: 4/11/2023 00:00:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_CALCULAR_TEMPORAL]
    @id_formula INT,
    @cantidad_libras DECIMAL,
    @ganancia_porcentaje DECIMAL,
    @precio_por_onza DECIMAL(10, 2) = 0.0 OUTPUT,
    @total_libras DECIMAL(10, 2) = 0.0 OUTPUT,
    @total_onzas DECIMAL(10, 2) = 0.0 OUTPUT,
    @subtotal DECIMAL(10, 2) = 0.0 OUTPUT,
    @ganancia DECIMAL(10, 2) = 0.0 OUTPUT,
    @total DECIMAL(10, 2) = 0.0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Asegurarse de que @cantidad_libras no sea nulo
    SET @cantidad_libras = ISNULL(@cantidad_libras, 0);

    -- Crear una tabla temporal para almacenar los cálculos por ingrediente
    CREATE TABLE #CalculosTemporales (
        ingrediente varchar(100),
		porcentaje  DECIMAL(10, 2),
        libras DECIMAL(10, 2),
        onzas DECIMAL(10, 2),
		precio DECIMAL(10, 2),
        costo DECIMAL(10, 2)
    );


    -- Calcular libras, onzas y costo por ingrediente y almacenarlos en la tabla temporal
    INSERT INTO #CalculosTemporales (ingrediente, porcentaje, libras, onzas, precio, costo)
    SELECT
        ingrediente,
		porcentaje,
        (porcentaje * (@cantidad_libras/100.0)) AS libras,
        (porcentaje * (@cantidad_libras/100.0) * 16) AS onzas,
		precio,
        (precio * (porcentaje * (@cantidad_libras/100.0))) AS costo
    FROM MATERIA_PRIMA
    WHERE id_formula = @id_formula;

    -- Calcular totales
    SELECT
        @total_libras = SUM(libras),
        @total_onzas = SUM(onzas),
        @subtotal = SUM(costo)
    FROM #CalculosTemporales;

    -- Calcular ganancia (corregir el cálculo)
    SET @ganancia = @ganancia_porcentaje * @subtotal / 100.0;

    -- Calcular total
    SET @total = @subtotal + @ganancia;

    -- Calcular precio por onza
    SET @precio_por_onza = @total / @total_onzas;

 
    -- Obtener la lista de ingredientes con sus libras y onzas
    DECLARE @ListaIngredientes TABLE (
        ingrediente varchar(100),
		porcentaje  DECIMAL(10, 2) ,
        libras DECIMAL(10, 2) ,
        onzas DECIMAL(10, 2),
		precio  DECIMAL(10, 2) ,
		costo DECIMAL(10, 2)
    );

    INSERT INTO @ListaIngredientes (ingrediente, porcentaje, libras, onzas, precio, costo)
    SELECT
        ingrediente,
		porcentaje,
        libras,
        onzas,
		precio,
		costo
    FROM #CalculosTemporales;

    -- Eliminar tabla temporal
IF OBJECT_ID('tempdb..#CalculosTemporales') IS NOT NULL
    DROP TABLE #CalculosTemporales;

    -- Devolver la lista de ingredientes con sus libras y onzas como resultado adicional
    SELECT
        ingrediente,
		porcentaje,
        libras,
        onzas,
		precio,
		costo
    FROM @ListaIngredientes;
END
