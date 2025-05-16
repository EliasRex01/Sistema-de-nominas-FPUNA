PROMPT CREATE OR REPLACE FUNCTION fn_enviar_mail
CREATE OR REPLACE FUNCTION fn_enviar_mail(p_remitente         IN VARCHAR2 DEFAULT 'ingrid@alexsa.com.py',
                                          p_destino           IN VARCHAR2,
                                          p_asunto            IN VARCHAR2,
                                          p_cuerpo            IN CLOB,
                                          p_cuerpo_html       IN CLOB DEFAULT NULL,
                                          p_nombre_adjunto    IN VARCHAR2 DEFAULT NULL,
                                          p_adjunto           IN BLOB DEFAULT NULL,
                                          p_adjunto_mime_type IN VARCHAR2 DEFAULT NULL,
                                          p_mensaje           OUT VARCHAR2,
                                          p_cc                IN VARCHAR2 DEFAULT NULL)
  RETURN BOOLEAN IS
  /**
   * Autor: Diana Espinoza
   * Creado el: 28.11.2024 16:16
   * Proposito: Enviar mail el archivo csv previamente generado
  **/
  l_id NUMBER;
BEGIN
  l_id := apex_mail.send(p_to        => p_destino,
                         p_from      => p_remitente,
                         p_body      => p_cuerpo,
                         p_body_html => p_cuerpo_html,
                         p_subj      => p_asunto,
                         p_cc        => p_cc);
  IF p_adjunto IS NOT NULL THEN
    apex_mail.add_attachment(p_mail_id    => l_id,
                             p_attachment => p_adjunto,
                             p_filename   => p_nombre_adjunto,
                             p_mime_type  => p_adjunto_mime_type);
  ELSE
    NULL;
  END IF;
  apex_mail.push_queue;
  p_mensaje := 'El correo se ha enviado correctamente';
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    pr_capturar_error(p_obs => p_remitente || ',' || p_destino || ',' ||
                               p_asunto || ',' || p_cuerpo || ',' ||
                               p_cuerpo_html || ',' || p_nombre_adjunto || ',' ||
                               '"CONTENIDO_BLOB"' || ',' ||
                               p_adjunto_mime_type || ',' || p_mensaje);
    p_mensaje := dbms_utility.format_error_stack ||
                 dbms_utility.format_error_backtrace;
    RETURN FALSE;
END;
/



PROMPT CREATE OR REPLACE FUNCTION fn_genera_csv
CREATE OR REPLACE FUNCTION fn_genera_csv(p_sql_query IN CLOB DEFAULT NULL,
                                         p_csv       OUT BLOB,
                                         p_tipo_mime OUT VARCHAR2,
                                         p_header    IN VARCHAR2 DEFAULT NULL,
                                         p_footer    IN VARCHAR2 DEFAULT NULL,
                                         p_separator IN VARCHAR2 DEFAULT ',')
  RETURN BOOLEAN IS
  /**
   * Autor: Diana Espinoza
   * Creado el: 28.11.2024 16:15
   * Proposito: Genera archivo csv para enviar via mail
  **/
  l_csv          CLOB;
  l_export       apex_data_export.t_export;
  l_context      apex_exec.t_context;
  l_print_config apex_data_export.t_print_config;
  v_in           INTEGER := 1;
  v_out          INTEGER := 1;
  v_lang         INTEGER := 0;
  v_warning      INTEGER := 0;
  v_header       VARCHAR2(32000);
BEGIN
  dbms_lob.createtemporary(l_csv, TRUE);
  IF p_header IS NOT NULL THEN
    dbms_lob.append(l_csv, p_header || CHR(13) || CHR(10));
  END IF;
  l_context := apex_exec.open_query_context(p_location  => apex_exec.c_location_local_db,
                                            p_sql_query => p_sql_query);
  l_print_config := apex_data_export.get_print_config(p_orientation  => apex_data_export.c_orientation_portrait,
                                                      p_border_width => 6);
  l_export := apex_data_export.export(p_context       => l_context,
                                      p_print_config  => l_print_config,
                                      p_format        => apex_data_export.c_format_csv,
                                      p_csv_separator => p_separator);
  apex_exec.close(l_context);
  -- Convierte el contenido exportado a CLOB
  dbms_lob.append(l_csv, to_clob(l_export.content_blob));
  -- Añade footer
  IF p_footer IS NOT NULL THEN
    dbms_lob.append(l_csv, CHR(13) || CHR(10) || p_footer);
  END IF;
  -- Convierte CLOB a BLOB para salida
  dbms_lob.createtemporary(p_csv, TRUE);
  dbms_lob.converttoblob(p_csv,
                         l_csv,
                         DBMS_LOB.LOBMAXSIZE,
                         v_in,
                         v_out,
                         DBMS_LOB.DEFAULT_CSID,
                         v_lang,
                         v_warning);
  p_tipo_mime := 'text/csv';
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    IF l_context IS NOT NULL THEN
      apex_exec.close(l_context);
    END IF;

    RAISE;
    RETURN FALSE;
END;
/

