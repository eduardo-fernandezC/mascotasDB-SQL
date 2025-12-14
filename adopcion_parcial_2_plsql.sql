SET SERVEROUTPUT ON;

--------------------------------------------------------------------------------
-- LIMPIEZA DE TRIGGERS, PAQUETES Y SECUENCIAS
DROP TRIGGER trg_set_fecha_adopcion;
DROP TRIGGER trg_adopcion_set_estado;
DROP TRIGGER trg_rescate_set_estado;
DROP PACKAGE pkg_logs_refugio;
DROP PACKAGE pkg_refugio;
DROP SEQUENCE ADOPCION_SEQ;
DROP PROCEDURE mostrar_adopciones;
DROP PROCEDURE mostrar_adopciones_filtrado;
DROP FUNCTION total_mascotas_adoptadas;
--------------------------------------------------------------------------------
-- SECUENCIA
CREATE SEQUENCE ADOPCION_SEQ
START WITH 306
INCREMENT BY 1
CACHE 20
NOCYCLE;
/

--------------------------------------------------------------------------------
-- PACKAGE DE LOGS
CREATE OR REPLACE PACKAGE pkg_logs_refugio IS
   PROCEDURE registrar_log(
      p_accion VARCHAR2,
      p_detalle VARCHAR2,
      p_estado VARCHAR2 DEFAULT 'OK'
   );
END pkg_logs_refugio;
/

CREATE OR REPLACE PACKAGE BODY pkg_logs_refugio IS
   PROCEDURE registrar_log(
      p_accion VARCHAR2,
      p_detalle VARCHAR2,
      p_estado VARCHAR2 DEFAULT 'OK'
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO LOG_REFUGIO (accion, detalle, usuario_ejecuta, estado)
      VALUES (p_accion, p_detalle, USER, p_estado);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error registrando log: ' || SQLERRM);
   END registrar_log;
END pkg_logs_refugio;
/

--------------------------------------------------------------------------------
-- PACKAGE PRINCIPAL pkg_refugio
CREATE OR REPLACE PACKAGE pkg_refugio IS
   PROCEDURE registrar_adopcion(p_id_mascota NUMBER, p_id_adoptador NUMBER);
   FUNCTION contar_adopciones(p_id_adoptador NUMBER) RETURN NUMBER;
END pkg_refugio;
/

CREATE OR REPLACE PACKAGE BODY pkg_refugio IS

   PROCEDURE registrar_adopcion(p_id_mascota NUMBER, p_id_adoptador NUMBER) IS
      v_existe NUMBER;
   BEGIN
      SELECT COUNT(*) INTO v_existe FROM ADOPCION WHERE id_mascota = p_id_mascota;

      IF v_existe > 0 THEN
         DBMS_OUTPUT.PUT_LINE('Error: La mascota ya fue adoptada.');
         pkg_logs_refugio.registrar_log('registrar_adopcion', 'Intento fallido de adopcion para mascota ' || p_id_mascota, 'ERROR');
      ELSE
         INSERT INTO ADOPCION (id_adopcion, id_mascota, id_adoptador, fecha)
         VALUES (ADOPCION_SEQ.NEXTVAL, p_id_mascota, p_id_adoptador, SYSDATE);

         DBMS_OUTPUT.PUT_LINE('Adopcion registrada correctamente.');
         pkg_logs_refugio.registrar_log('registrar_adopcion', 'Nueva adopcion registrada para mascota ' || p_id_mascota);
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error en registrar_adopcion: ' || SQLERRM);
         pkg_logs_refugio.registrar_log('registrar_adopcion', SQLERRM, 'ERROR');
   END registrar_adopcion;

   FUNCTION contar_adopciones(p_id_adoptador NUMBER) RETURN NUMBER IS
      v_total NUMBER;
   BEGIN
      SELECT COUNT(*) INTO v_total FROM ADOPCION WHERE id_adoptador = p_id_adoptador;
      pkg_logs_refugio.registrar_log('contar_adopciones', 'Consulta de total para adoptante ' || p_id_adoptador);
      RETURN v_total;
   EXCEPTION
      WHEN OTHERS THEN
         DBMS_OUTPUT.PUT_LINE('Error en contar_adopciones: ' || SQLERRM);
         pkg_logs_refugio.registrar_log('contar_adopciones', SQLERRM, 'ERROR');
         RETURN 0;
   END contar_adopciones;

END pkg_refugio;
/

--------------------------------------------------------------------------------
-- PROCEDIMIENTOS 
CREATE OR REPLACE PROCEDURE mostrar_adopciones IS
BEGIN
   DBMS_OUTPUT.PUT_LINE('--- LISTADO DE ADOPCIONES ---');
   FOR rec IN (
      SELECT a.id_adopcion, m.nombre AS mascota, ad.nombre AS adoptante, a.fecha
      FROM ADOPCION a
      JOIN MASCOTA m ON a.id_mascota = m.id_mascota
      JOIN ADOPTANTE ad ON a.id_adoptador = ad.id_adoptador
      ORDER BY a.fecha
   ) LOOP
      DBMS_OUTPUT.PUT_LINE('ID: ' || rec.id_adopcion ||
                           ' | Mascota: ' || rec.mascota ||
                           ' | Adoptante: ' || rec.adoptante ||
                           ' | Fecha: ' || TO_CHAR(rec.fecha, 'YYYY-MM-DD'));
   END LOOP;
   pkg_logs_refugio.registrar_log('mostrar_adopciones', 'Consulta de listado completa');
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error al mostrar adopciones: ' || SQLERRM);
      pkg_logs_refugio.registrar_log('mostrar_adopciones', SQLERRM, 'ERROR');
END;
/

CREATE OR REPLACE PROCEDURE mostrar_adopciones_filtrado(p_id_adoptador NUMBER) IS
   v_contador NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_contador
   FROM ADOPCION
   WHERE id_adoptador = p_id_adoptador;

   IF v_contador = 0 THEN
      DBMS_OUTPUT.PUT_LINE('El adoptante con ID ' || p_id_adoptador || ' no tiene adopciones registradas.');
      pkg_logs_refugio.registrar_log('mostrar_adopciones_filtrado', 'Sin resultados para adoptante ' || p_id_adoptador);
      RETURN;
   END IF;

   DBMS_OUTPUT.PUT_LINE('--- ADOPCIONES DEL ADOPTANTE ' || p_id_adoptador || ' ---');
   FOR rec IN (
      SELECT a.id_adopcion, m.nombre AS mascota, a.fecha
      FROM ADOPCION a
      JOIN MASCOTA m ON a.id_mascota = m.id_mascota
      WHERE a.id_adoptador = p_id_adoptador
      ORDER BY a.fecha
   ) LOOP
      DBMS_OUTPUT.PUT_LINE('ID Adopcion: ' || rec.id_adopcion ||
                           ' | Mascota: ' || rec.mascota ||
                           ' | Fecha: ' || TO_CHAR(rec.fecha, 'YYYY-MM-DD'));
   END LOOP;
   pkg_logs_refugio.registrar_log('mostrar_adopciones_filtrado', 'Consulta exitosa para adoptante ' || p_id_adoptador);
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error al mostrar adopciones filtradas: ' || SQLERRM);
      pkg_logs_refugio.registrar_log('mostrar_adopciones_filtrado', SQLERRM, 'ERROR');
END;
/

CREATE OR REPLACE FUNCTION total_mascotas_adoptadas RETURN NUMBER IS
   v_total NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_total
   FROM MASCOTA
   WHERE estado = 'ADOPTADA';
   
   pkg_logs_refugio.registrar_log('total_mascotas_adoptadas', 'Consulta realizada correctamente');
   RETURN v_total;
EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error en total_mascotas_adoptadas: ' || SQLERRM);
      pkg_logs_refugio.registrar_log('total_mascotas_adoptadas', SQLERRM, 'ERROR');
      RETURN 0;
END;
/

--------------------------------------------------------------------------------
-- TRIGGERS
CREATE OR REPLACE TRIGGER trg_set_fecha_adopcion
BEFORE INSERT ON ADOPCION
FOR EACH ROW
BEGIN
   IF :NEW.fecha IS NULL THEN
      :NEW.fecha := SYSDATE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pkg_logs_refugio.registrar_log('TRIGGER_FECHA_ADOPCION', SQLERRM, 'ERROR');
END;
/

CREATE OR REPLACE TRIGGER trg_adopcion_set_estado
AFTER INSERT ON ADOPCION
FOR EACH ROW
BEGIN
   UPDATE MASCOTA
   SET estado = 'ADOPTADA'
   WHERE id_mascota = :NEW.id_mascota;

   pkg_logs_refugio.registrar_log('TRIGGER_ADOPCION', 'Estado actualizado a ADOPTADA para mascota ' || :NEW.id_mascota);
EXCEPTION
   WHEN OTHERS THEN
      pkg_logs_refugio.registrar_log('TRIGGER_ADOPCION', SQLERRM, 'ERROR');
END;
/

CREATE OR REPLACE TRIGGER trg_rescate_set_estado
AFTER INSERT ON RESCATE
FOR EACH ROW
BEGIN
   UPDATE MASCOTA
   SET estado = 'RESCATADA'
   WHERE id_mascota = :NEW.id_mascota
   AND estado = 'DISPONIBLE';

   pkg_logs_refugio.registrar_log('TRIGGER_RESCATE', 'Mascota ' || :NEW.id_mascota || ' marcada como RESCATADA');
EXCEPTION
   WHEN OTHERS THEN
      pkg_logs_refugio.registrar_log('TRIGGER_RESCATE', SQLERRM, 'ERROR');
END;
/


--------------------------------------------------------------------------------
-- Pruebas

-- 1. Insertar adopcion y verificar log
INSERT INTO ADOPTANTE (id_adoptador, nombre) VALUES (200, 'Adoptante 200');
INSERT INTO MASCOTA (id_mascota, nombre, especie, edad, estado)
VALUES (100, 'Fido', 'Perro', 2, 'DISPONIBLE');

BEGIN
   pkg_refugio.registrar_adopcion(100, 201);  
END;
/

-- Verificar estado de la mascota
SELECT id_mascota, nombre, estado FROM MASCOTA WHERE id_mascota = 100;

-- Verificar que se haya insertado log
SELECT * FROM LOG_REFUGIO ORDER BY fecha_log DESC;

-- 2. Intentar adoptar una mascota ya adoptada (debe generar error y log)
INSERT INTO ADOPTANTE (id_adoptador, nombre) VALUES (199, 'Adoptante 199');

BEGIN
   pkg_refugio.registrar_adopcion(100, 202); 
END;
/

-- Verificar log de error
SELECT * FROM LOG_REFUGIO ORDER BY fecha_log DESC;

-- 3. Insertar rescate y verificar log
INSERT INTO MASCOTA (id_mascota, nombre, especie, edad, estado)
VALUES (11, 'Max', 'Perro', 7, 'DISPONIBLE');

INSERT INTO RESCATE (id_rescate, id_mascota, fecha, lugar, descripcion)
VALUES (301, 11, SYSDATE, 'Zona sur', 'Perro encontrado');

-- Verificar que estado de mascota se actualizo y log creado
SELECT id_mascota, nombre, estado FROM MASCOTA WHERE id_mascota = 11;
SELECT * FROM LOG_REFUGIO ORDER BY fecha_log DESC;

-- 4. Probar procedimientos y funciones con logs
BEGIN
   mostrar_adopciones;
END;
/

BEGIN
   DBMS_OUTPUT.PUT_LINE('Total adoptadas: ' || total_mascotas_adoptadas);
END;
/

-- Revisar logs de consultas
SELECT * FROM LOG_REFUGIO ORDER BY fecha_log DESC;


