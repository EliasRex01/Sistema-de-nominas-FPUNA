create or replace package body "MTL_AUTH_PKG" as

-- Función de autenticación personalizada
function custom_authenticate (
    p_username in varchar2,
    p_password in varchar2
) return boolean is
    l_password_raw raw(64);
    l_stored_password raw(64);
begin
    l_password_raw := standard_hash(p_password, 'SHA256');
    
    select password
    into l_stored_password
    from mtl_user
    where upper(email) = upper(p_username);

    return l_password_raw = l_stored_password;
exception
    when no_data_found then
        return false;
end custom_authenticate;


-- Registro de nueva cuenta
procedure create_account(
    p_email    in varchar2,
    p_password in varchar2
) is
    l_message varchar2(4000);
    l_password raw(64);
    l_user_id number;
    l_url varchar2(1000);
begin
    apex_debug.message(p_message => 'Begin create_account', p_level => 3);

    l_password := standard_hash(p_password, 'SHA256');

    begin
        select user_id
        into l_user_id
        from mtl_user
        where upper(email) = upper(p_email);

        raise_application_error(-20001, 'El email ya está registrado.');
    exception
        when no_data_found then
            insert into mtl_user (
                user_id, email, password, role_id, points, first_name, last_name
            ) values (
                MTL_USER_SEQ.NEXTVAL,
                p_email,
                l_password,
                2, -- rol por defecto: User
                0, NULL, NULL
            );

            commit;
    end;
end create_account;


-- Solicitud de reseteo de contraseña
procedure request_reset_password(
    p_email in varchar2
) is
    l_code varchar2(100);
begin
    select dbms_random.string('X', 10)
    into l_code
    from dual;

    update mtl_user
    set verification_code = l_code
    where upper(email) = upper(p_email);

    mail_reset_password(p_email, l_code);
end request_reset_password;


-- Envío de email (simulado)
procedure mail_reset_password(
    p_email in varchar2,
    p_url in varchar2
) is
begin
    apex_mail.send(
        p_to => p_email,
        p_from => 'noreply@miapp.com',
        p_subj => 'Restablecer contraseña',
        p_body => 'Visita el siguiente enlace para restablecer tu contraseña: ' || p_url || '?code=' || p_url
    );
end mail_reset_password;


-- Validar código de verificación
function verify_reset_password(
    p_id in number,
    p_verification_code in varchar2
) return number is
    l_user_id number;
begin
    select user_id
    into l_user_id
    from mtl_user
    where user_id = p_id
    and verification_code = p_verification_code;

    return l_user_id;
exception
    when no_data_found then
        return null;
end verify_reset_password;


-- Restablecer contraseña
procedure reset_password(
    p_id in number,
    p_password in varchar2
) is
    l_new_password raw(64);
begin
    l_new_password := standard_hash(p_password, 'SHA256');

    update mtl_user
    set password = l_new_password,
        verification_code = null
    where user_id = p_id;

    commit;
end reset_password;


-- Validación de administrador
function authz_administrator(
    p_username in varchar2
) return boolean is
    l_count number;
begin
    select count(*)
    into l_count
    from mtl_user u
    join mtl_role r on u.role_id = r.role_id
    where upper(u.email) = upper(p_username)
      and upper(r.role_name) = 'ADMINISTRATOR';

    return l_count > 0;
end authz_administrator;


-- Validación de usuario registrado
function authz_user(
    p_username in varchar2
) return boolean is
    l_count number;
begin
    select count(*)
    into l_count
    from mtl_user
    where upper(email) = upper(p_username);

    return l_count > 0;
end authz_user;

end "MTL_AUTH_PKG";
