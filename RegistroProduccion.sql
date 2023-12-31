USE [db_a9f761_pandemitierra]
GO
/****** Object:  StoredProcedure [dbo].[SP_REGISTRAR_PRODUCCION]    Script Date: 3/11/2023 23:59:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_REGISTRAR_PRODUCCION]
    @ProduccionTabla AS dbo.ProduccionTablaType READONLY,
    @o_msgerror VARCHAR(200) OUTPUT,
    @o_msg VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Inicializar las variables de salida
    SET @o_msgerror = '';
    SET @o_msg = '';

    -- Verificar si la tabla @ProduccionTabla está vacía
    IF NOT EXISTS (SELECT 1 FROM @ProduccionTabla)
    BEGIN
        SET @o_msgerror = 'La tabla de producción está vacía. No hay datos para procesar.';
        RETURN;
    END

    -- Declarar variables
    DECLARE @ClaseDePan VARCHAR(100);
    DECLARE @Libras DECIMAL(10, 2);
    DECLARE @IdFormula INT;
    DECLARE @CantidadLibrasFormula DECIMAL(10, 2);
    DECLARE @Ingrediente VARCHAR(100);
    DECLARE @CantidadLibrasInventario DECIMAL(10, 2);
    DECLARE @CantidadLibrasActualizada DECIMAL(10, 2);

    CREATE TABLE #ResultadoSP (
        ingrediente VARCHAR(100),
        libras DECIMAL(10, 2)
    );

    -- Insertar los datos de @ProduccionTabla en un cursor
    DECLARE cursorProduccion CURSOR FOR
    SELECT CLASE_DE_PAN, Libras FROM @ProduccionTabla;

    -- Abrir el cursor
    OPEN cursorProduccion;

    -- Leer el primer registro del cursor
    FETCH NEXT FROM cursorProduccion INTO @ClaseDePan, @Libras;

    -- Iterar a través del cursor y realizar las operaciones para cada registro
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Verificar si el valor de Libras es positivo
        IF @Libras <= 0
        BEGIN
            SET @o_msgerror = 'Error: La cantidad de libras debe ser un valor positivo. Registro no procesado.';
            CLOSE cursorProduccion;
            DEALLOCATE cursorProduccion;
            RETURN;
        END

        -- Obtener el ID de la fórmula
        SELECT @IdFormula = ID FROM FORMULA WHERE NOMBRE = @ClaseDePan;

        -- Calcular la cantidad de libras de la fórmula y almacenar los resultados en una tabla temporal
        INSERT INTO #ResultadoSP (ingrediente, libras)
        EXEC [dbo].[SP_CALCULAR_LIBRAS_FORMULA] @IdFormula, @Libras;

        -- Leer el siguiente registro del cursor
        FETCH NEXT FROM cursorProduccion INTO @ClaseDePan, @Libras;
    END

    -- Cerrar y liberar el cursor
    CLOSE cursorProduccion;
    DEALLOCATE cursorProduccion;

    -- Verificar si la tabla #ResultadoSP está vacía
    IF NOT EXISTS (SELECT 1 FROM #ResultadoSP)
    BEGIN
        SET @o_msgerror = 'No se obtuvieron resultados del cálculo. No se pudo continuar con la actualización del inventario.';
        

		IF OBJECT_ID('tempdb..#ResultadoSP') IS NOT NULL
    DROP TABLE #ResultadoSP;
        RETURN;
    END

    -- Actualizar la tabla de inventario
    DECLARE cur CURSOR FOR
    SELECT ingrediente, libras FROM #ResultadoSP;

    OPEN cur;
    FETCH NEXT FROM cur INTO @Ingrediente, @CantidadLibrasFormula;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @CantidadLibrasInventario = CANTIDAD FROM INVENTARIO WHERE NOMBREPRODUCTO = @Ingrediente;
        SET @CantidadLibrasActualizada = @CantidadLibrasInventario - @CantidadLibrasFormula;

        -- Verificar si la cantidad actualizada del inventario es menor a cero
        IF @CantidadLibrasActualizada < 0
        BEGIN
            SET @o_msgerror = 'Error: No hay suficiente inventario de ' + @Ingrediente + ' para la producción. Registro no procesado.';
            CLOSE cur;
            DEALLOCATE cur;
          IF OBJECT_ID('tempdb..#ResultadoSP') IS NOT NULL
    DROP TABLE #ResultadoSP;
            RETURN;
        END

        UPDATE INVENTARIO SET CANTIDAD = @CantidadLibrasActualizada WHERE NOMBREPRODUCTO = @Ingrediente;

        FETCH NEXT FROM cur INTO @Ingrediente, @CantidadLibrasFormula;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- Insertar los resultados en la tabla PRODUCCION
    INSERT INTO PRODUCCION (CLASE_DE_PAN, LIBRAS, BANDEJAS, UNIDADES, COSTO_POR_UNIDAD, FECHAREGISTRO)
    SELECT CLASE_DE_PAN, LIBRAS, BANDEJAS, UNIDADES, COSTO_POR_UNIDAD, GETDATE() FROM @ProduccionTabla;


    -- Eliminar tabla temporal
    IF OBJECT_ID('tempdb..#ResultadoSP') IS NOT NULL
    DROP TABLE #ResultadoSP;

    SET @o_msg = 'Registro guardado exitosamente.';
END
