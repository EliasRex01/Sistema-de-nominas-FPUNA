PROMPT CREATE TABLE dato_error
CREATE TABLE dato_error (
  oracle_user   VARCHAR2(30) DEFAULT USER NULL,
  apex_user     VARCHAR2(30) DEFAULT SYS_CONTEXT('APEX$SESSION','APP_USER') NULL,
  datetime      DATE         DEFAULT SYSDATE NOT NULL,
  sessionid     NUMBER(38,0) DEFAULT SYS_CONTEXT('USERENV', 'SESSIONID') NOT NULL,
  procedimiento CLOB         NOT NULL,
  error         CLOB         NOT NULL,
  obs           CLOB         NULL
)
  STORAGE (
    NEXT       1024 K
  )
/

PROMPT CREATE INDEX i_dato_error_datetime
CREATE INDEX i_dato_error_datetime
  ON dato_error (
    datetime
  )
  STORAGE (
    NEXT       1024 K
  )
/


PROMPT CREATE OR REPLACE FUNCTION sqlerrm_text
CREATE OR REPLACE FUNCTION sqlerrm_text RETURN VARCHAR2 AS
  /**
   * Autor: Rodrigo Avalos
   * Creado el: 03.09.2024 08:30
   * Proposito: Devolver solo el texto del error
   */
  v_sqlerrm VARCHAR2(32676) := sys.standard.sqlerrm;
  v_sqlcode VARCHAR2(6):= '-'||LPad(SubStr(SQLCODE,2),5,0);
BEGIN
  RETURN replace(v_sqlerrm, 'ORA' || v_sqlcode || ': ', '');
END;
/


PROMPT CREATE OR REPLACE FUNCTION fn_contabiliza_columna_ir
CREATE OR REPLACE FUNCTION fn_contabiliza_columna_ir(
  p_page_id IN NUMBER,
  p_app IN NUMBER,
  p_static_id IN VARCHAR2

) RETURN number
IS
    l_report apex_ir.t_report;
    l_query varchar2(32767);
    v_result number;
    l_report_id number;
    V_CONCA_NAMES  VARCHAR2 (100);
    V_CONCA_VALUES VARCHAR2(1000);
    v_region_id  apex_application_page_regions.region_id%TYPE;
    cursor_id INTEGER;
    ret INTEGER;

BEGIN
  BEGIN
    SELECT region_id
    INTO  v_region_id
    FROM apex_application_page_regions
    WHERE application_id = p_app
    and page_id = p_page_id
    and static_id = p_static_id;
  EXCEPTION
    WHEN No_Data_Found THEN
      Raise_Application_Error(-20999,'No se encuentra la region indicada.');
    WHEN Others THEN
      Raise_Application_Error(-20999, sqlerrm );
  end;
    l_report_id := APEX_IR.GET_LAST_VIEWED_REPORT_ID (
        p_page_id   => p_page_id,
        p_region_id => v_region_id);
    l_report := APEX_IR.GET_REPORT (
                    p_page_id => p_page_id,
                    p_region_id => v_region_id,
                    p_report_id => l_report_id);
    l_query := l_report.sql_query;
    l_query :=
      'select count (*)  from ('||
      l_report.sql_query||') t';

    for i in 1..l_report.binds.count
    loop

      IF v_conca_names IS NULL THEN
        v_conca_names := l_report.binds(i).name;
        v_conca_values := l_report.binds(i).value;
      ELSE
        v_conca_names := v_conca_names ||':'||l_report.binds(i).name;
        v_conca_values := v_conca_values ||'|'||l_report.binds(i).value;
      END IF ;

    end loop;

    apex_collection.Create_collection_from_query_b(
      p_collection_name =>'CONTABILIZADOR',
      p_query =>l_query,
      p_names =>apex_util.string_to_table(v_conca_names),
      p_values =>apex_util.string_to_table(v_conca_values,'|') ,
        p_truncate_if_exists => 'YES'
    );
    select  Nvl ((c001),0) Total
    INTO v_result
    from apex_collections
    where collection_name ='CONTABILIZADOR';

    return v_result;
END;
/



PROMPT CREATE OR REPLACE FUNCTION fn_recurso
CREATE OR REPLACE FUNCTION fn_recurso(
  p_codigo IN adu_aplicacion.codigo%TYPE,
  p_recurso IN adu_menu_recurso.recurso%TYPE
) RETURN BOOLEAN IS
  v_id_aplicacion adu_aplicacion.id_aplicacion%TYPE;
  v_publico adu_aplicacion.publico%TYPE;
BEGIN
  BEGIN
    SELECT id_aplicacion, publico
    INTO v_id_aplicacion, v_publico
    FROM adu_aplicacion
    WHERE codigo = p_codigo;
    Dbms_Output.Put_Line('v_id_aplicacion: ' ||v_id_aplicacion );

    IF v_publico = 'N' THEN /* Verificamos si la aplicacion esta en modo publico para aplicar los controles de recursos */
      RETURN TRUE;
    END IF;

  EXCEPTION
    WHEN No_Data_Found THEN
      RETURN FALSE;
  END;

  DECLARE
    dummy CHAR(1);
  BEGIN
    SELECT 1
    INTO dummy
    FROM adu_menu_usuario  mu, adu_menu_recurso mr
    WHERE Upper(mu.login) = Upper(fn_user)
    AND mu.estado = 'A'
    AND mu.id_menu = mr.id_menu
    AND mr.id_aplicacion = v_id_aplicacion
    AND mr.recurso = p_recurso;
    Dbms_Output.Put_Line('v_recurso: ' || p_recurso );
    RETURN TRUE;
  EXCEPTION
    WHEN No_Data_Found THEN
      RETURN FALSE;
  END;
EXCEPTION
  WHEN Others THEN
    Raise_Application_Error(-20999,'Ocurrio un error al consultar la tabla de menu', TRUE);
END;
/


