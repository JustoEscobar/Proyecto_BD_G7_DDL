USE BD_Grupo7_C2

/*FUNCIONES*/

--Funcion Edad
CREATE function edad_jugador(@fecha_nacimiento date)
RETURNS int
as
BEGIN
declare @edad int
set @edad = DATEDIFF(YEAR,@fecha_nacimiento,GETDATE())
RETURN @edad
END
----------------------------------------------------------------------------------------------------
/*PROCEDIMIENTOS*/

--Procedimiento para actualizar el valor de un jugador
CREATE PROCEDURE actualizar_valor_jugador
	@nro_jugador int ,
	@nuevo_valor  float
	AS
	BEGIN
	  UPDATE jugador
	   SET jugador.valor_actual = @nuevo_valor where jugador.nro_jugador = @nro_jugador
    END
----------------------------------------------------------------------------------------------------
--Prueba
EXEC actualizar_valor_jugador 1,125000000
------------------------------------------
SELECT *
FROM jugador
----------------------------------------------------------------------------------------------------
--Procedimiento para insertar un club nuevo
CREATE PROCEDURE insertar_club
@nombre varchar,
@año_fund int,
@direccion varchar,
@cod_liga int,
@dni_resp int
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM club c WHERE c.nombre = @nombre)
	BEGIN
		INSERT INTO club VALUES(@nombre,@año_fund,@direccion,@cod_liga,@dni_resp)
		PRINT  ('El Club fue insertado satisfactoriamente')
	END
	ELSE
	PRINT ('El Club ya fue insertado anteriormente')
END
----------------------------------------------------------------------------------------------------
--prueba
EXEC insertar_club 'Manchester United',1945,'Av. Pujol 1200',1,32111100
----------------------------------------------------------------------------------------------------
/*TRIGGERS*/

--Trigger de actualizacion de valor_actual de un jugador al realizar una transferencia
CREATE TRIGGER TG1_act_valor_jugador
ON inf_transf_detalle
AFTER INSERT
AS
BEGIN
	DECLARE @nuevo_valor float;
	SET @nuevo_valor = (SELECT valor_transf FROM inserted);
	
	UPDATE jugador SET valor_actual = @nuevo_valor
	WHERE (SELECT nro_jugador FROM inserted) = jugador.nro_jugador
END

-------------------------------------------------------------------------------------------------------
INSERT INTO club_jugador(nro_club,nro_jugador) VALUES(3,2)
INSERT INTO inf_transf_detalle(nro_informe,nro_club,nro_jugador,valor_transf) VALUES(1,3,2,155555555)

SELECT cj.nro_club,j.nombre ,cj.nro_jugador,j.valor_actual
FROM club_jugador cj
INNER JOIN jugador j ON j.nro_jugador = cj.nro_jugador
ORDER BY cj.nro_jugador
-------------------------------------------------------------------------------------------------------
/*VISTAS*/

--Vista de la ficha tecnica de los jugadores
CREATE VIEW ficha_tecnica_operacion
AS
	SELECT (j.nombre+''+j.apellido) as 'Jugador',tp.descripcion 'Posicion',DATEDIFF(YEAR,fecha_nac,GETDATE()) as 'Edad',j.pie_habil as 'Pie Habil',j.altura as 'Altura',('$'+CAST(id.valor_transf as varchar(250))) as 'Precio operacion', id.fecha_transf as 'Fecha', c.nombre as 'Club', ej.descripcion 'Tipo Operacion'
	FROM inf_transf_detalle id
		INNER JOIN club_jugador cj ON cj.nro_club = id.nro_club AND cj.nro_jugador = id.nro_jugador
		INNER JOIN club c ON cj.nro_club = c.nro_club
		INNER JOIN jugador j ON cj.nro_jugador = j.nro_jugador
		INNER JOIN tipo_posicion tp ON tp.cod_tipo_posicion = j.cod_tipo_posicion
		INNER JOIN estado_jugador ej ON ej.cod_estado = j.cod_estado
-------------------------------------------------------------------------------------------------------
SELECT *
FROM ficha_tecnica_operacion
-------------------------------------------------------------------------------------------------------
/*TRANSACCIONES*/
SELECT *
FROM jugador

BEGIN TRANSACTION
UPDATE jugador SET jugador.pie_habil = 'Izquierdo'
WHERE dni = 30289148
COMMIT
ROLLBACK
-------------------------------------------------------------
/*Ejemplo declarar el error */
DECLARE @Error int

BEGIN TRANSACTION
UPDATE jugador SET jugador.pie_habil = 'Izquierdo'
where dni = 30289148

INSERT INTO jugador (dni, nombre, apellido, fecha_nac, nacionalidad, altura, pie_habil, valor_actual, cod_estado, cod_tipo_posicion) 
VALUES (30289148, 'Jobye', 'Potteridge', '1983-08-28', 'China', 1.50, 'Derecho', 23159291, 1, 1);

SET @Error = @@ERROR
  IF  (@Error <>0)
	BEGIN
		ROLLBACK TRANSACTION
		PRINT 'Error en la transacción'
	END
	ELSE
	COMMIT

-------------------------------------------------------------------------------------------------------
--PARA IMPLEMENTAR/ARREGLAR
/*TRIGGERS*/

--Se crea la tabla para registrar los cambios

CREATE TABLE Reg_cambios_valor_jugador
(
	nro_jugador int NOT NULL	PRIMARY KEY,
	valor_anterior int NOT NULL,
	fecha_cambio datetime NOT NULL DEFAULT getdate(),
)

--Se crea el trigger para cambio

CREATE TRIGGER AU_CambiosJugador
ON jugador
 AFTER UPDATE 
 AS 
 -- ¿Ha cambiado el dato?
 IF UPDATE(valor_actual)
 begin
	--Actualizamos el campo fecha a la fecha/hora actual
	UPDATE jugador SET fecha=GetDate() WHERE nro_jugador =(SELECT nro_jugador FROM inserted);
 
    -- A modo de auditoría, añadimos un registro en la tabla expStatusHistory
	INSERT INTO Reg_cambios_valor_jugador(nro_jugador, valor_anterior) 
	(SELECT nro_jugaor, valor_actual
	FROM deleted 
	WHERE nro_jugador = deleted.nro_jugador);
 END;	
-- La tabla deleted contiene información sobre los valores ANTIGUOS mientras que la tabla inserted contiene los NUEVOS valores.
-- Ambas tablas son virtuales y tienen la misma estructura que la tabla a la que se asocia el Trigger. 

 -- Se obtiene los datos de la tabla Reg_cambios_valor_jugador

 SELECT * 
 FROM Reg_cambios_valor_jugador

 UPDATE Reporte_valor_jugador SET valor_actual = 1500
 WHERE nro_jugador = 30289148

--Se comprueba el cambio

SELECT * 
FROM Reporte_valor_jugador
WHERE nro_jugador = 30289148

------------------------------------------
  /*se crea el trigger para borrado*/

CREATE TRIGGER AU_BorradoReporte
ON Reporte_valor_jugador
FOR DELETE
AS
 --Si se quiere borrar se dispara el error
	 BEGIN
		RAISERROR('No puede borrar eliminar registros, intente cambiar la calificacion',16,1)
		ROLLBACK TRANSACTION
    -- Genera un erorr al intentar borrar
 END;

 -- Se obtiene los datos de la tabla Reg_cambios_valor_jugador

 SELECT * 
 FROM Reg_cambios_valor_jugador

 DELETE Reporte_valor_jugador
 WHERE nro_jugador = 51632895 AND codReporte = 56;

--Se comprueba el cambio

 SELECT * 
 FROM Reporte_valor_jugador

---------------------------------------------------------------------------------------------------------
--Procedimiento para eliminar un club

--Procedimiento para eliminar un jugador

--Trigger para copiar datos insertados en tabla transf detalle a la tabla club_jugador
CREATE TRIGGER TG2_transf_jugador
ON inf_transf_detalle
FOR INSERT
AS
BEGIN
	DECLARE @nuevo_club int,@nuevo_jugador int;
	SET @nuevo_club = (SELECT nro_club FROM inserted);
	SET @nuevo_jugador = (SELECT nro_jugador FROM inserted);
	
	INSERT INTO club_jugador(nro_club,nro_jugador) VALUES (@nuevo_club,@nuevo_jugador);
END
-------------------------------------------------------------------------------------------------
--PRUEBA
INSERT INTO inf_transf_detalle(nro_informe,nro_club,nro_jugador,valor_transf) VALUES(1,3,5,5500)

SELECT *
FROM club_jugador
-------------------------------------------------------------------------------------------------
--Procedimiento para actualizar fecha hasta del jugador con el club
CREATE PROCEDURE actualizar_fecha_hasta_jugador()
AS
BEGIN
	DECLARE @nuevo_club int, @nuevo_jugador int, @viejo_club int
	SET @viejo_club = (SELECT nro_club FROM club_jugador
						WHERE nro_club = (SELECT nro_club FROM inserted))
						
	SET @nuevo_club = (SELECT nro_club FROM inserted);
	SET @nuevo_jugador = (SELECT nro_jugador FROM inserted);
	
	INSERT INTO club_jugador(nro_club,nro_jugador) VALUES (@nuevo_club,@nuevo_jugador)
	INSERT INTO inf_transf_detalle(nro_informe,nro_club,nro_jugador,valor_transf) VALUES ()
	
	UPDATE club_jugador 
		SET fecha_hasta = GETDATE()
		WHERE nro_club = @viejo_club AND nro_jugador = @nuevo_jugador
		
END
-------------------------------------------------------------------------------------------------

--CREO LA TABLA HISTORIAL_DE_TRANSFERENCIAS
CREATE TABLE historial_de_transf
	(nro_informe int,
	nro_informe_detalle int,
	fecha datetime,
	descripcion varchar(100),
	usuario varchar(20))

--TRIGGER DE INSERTED - GUARDA EN LA TABLA HISTORIAL LAS TRANSFERENCIAS
ALTER TRIGGER TR_inf_transf_Isertado
ON inf_transf_detalle FOR insert
AS
DECLARE @nro_informe int,@nro_informe_detalle int
SELECT @nro_informe = nro_informe,@nro_informe_detalle = nro_informe_detalle FROM inserted
INSERT INTO historial_de_transf VALUES (@nro_informe,@nro_informe_detalle,GETDATE(),'Registro Insertado',CURRENT_USER)

--set nocount on

INSERT INTO club_jugador(nro_club,nro_jugador) VALUES(24,20)
INSERT INTO inf_transf_detalle(nro_informe,nro_club,nro_jugador,valor_transf) VALUES(2,24,20,5641250)

----------------------------------------------------------------
--TRIGGER DE ELIMINACION

ALTER TRIGGER TR_inf_transf_Eliminado
ON inf_transf_detalle FOR delete
AS
DECLARE @nro_informe int,@nro_informe_detalle int
SELECT @nro_informe = nro_informe,@nro_informe_detalle = nro_informe_detalle FROM deleted
INSERT INTO historial_de_transf VALUES (@nro_informe,@nro_informe_detalle,GETDATE(),'Registro Eliminado',CURRENT_USER)


--ELIMINAR EL INFORME DETALLE NRO 27
delete from inf_transf_detalle WHERE nro_informe_detalle = 27
----------------------------------------------------------------

--TRIGGER DE MODIFICACION
CREATE TRIGGER TR_inf_transf_Actualizado
ON inf_transf_detalle FOR UPDATE
AS
DECLARE @nro_informe INT,@nro_informe_detalle INT
SELECT @nro_informe = nro_informe,@nro_informe_detalle = nro_informe_detalle FROM inserted
INSERT INTO historial_de_transf VALUES (@nro_informe,@nro_informe_detalle,GETDATE(),'Registro Actualizado',CURRENT_USER)


--ACTUALIZAMOS EL VALOR DE TRANSFERENCIA AL INFORME DETALLE NRO 29
UPDATE inf_transf_detalle SET valor_transf = 7895216 WHERE nro_informe_detalle = 29

------------------------------------------------------------------------------------------
