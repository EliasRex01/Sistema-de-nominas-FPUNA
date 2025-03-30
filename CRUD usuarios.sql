-- Tablas
CREATE TABLE usuarios (
    id_usuario    NUMBER(7) CONSTRAINT PK_USUARIOS PRIMARY KEY,
    nombre        VARCHAR2(50) NOT NULL,
    email         VARCHAR2(100) UNIQUE NOT NULL,
    contrasena    VARCHAR2(255) NOT NULL, 
    estado        CHAR(1) DEFAULT 'A' CHECK (estado IN ('A', 'I')), 
    id_empleado   NUMBER(7) NOT NULL,	
	CONSTRAINT FK_USUARIO_EMPLEADO FOREIGN KEY (ID_EMPLEADO)
        REFERENCES EMPLEADOS (ID_EMPLEADO) ON DELETE CASCADE
);
-- Se quiere una relacion de un usuario pertenece a un solo empleado
-- El empleado ya debe existir para tener un nombre de usuario

CREATE TABLE roles (
    id_rol      NUMBER(7) CONSTRAINT PK_ROLES PRIMARY KEY,
    nombre_rol  VARCHAR2(50) UNIQUE NOT NULL
);

CREATE TABLE permisos (
    id_permiso    NUMBER(7) CONSTRAINT PK_PERMISOS PRIMARY KEY,
    nombre        VARCHAR2(100) UNIQUE NOT NULL,
    descripcion   VARCHAR2(255)
);

CREATE TABLE usuarios_roles (
    id_usuario   NUMBER(7) CONSTRAINT FK_USR_ROL_USUARIO REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    id_rol       NUMBER(7) CONSTRAINT FK_USR_ROL_ROL REFERENCES roles(id_rol) ON DELETE CASCADE,
    CONSTRAINT PK_USUARIOS_ROLES PRIMARY KEY (id_usuario, id_rol)
);

CREATE TABLE roles_permisos (
    id_rol       NUMBER(7) CONSTRAINT FK_ROL_PERM_ROL REFERENCES roles(id_rol) ON DELETE CASCADE,
    id_permiso   NUMBER(7) CONSTRAINT FK_ROL_PERM_PERMISO REFERENCES permisos(id_permiso) ON DELETE CASCADE,
    CONSTRAINT PK_ROLES_PERMISOS PRIMARY KEY (id_rol, id_permiso)
);


--  Sequencias
CREATE SEQUENCE SEQ_USUARIOS START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SEQ_ROLES START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE SEQ_PERMISOS START WITH 1 INCREMENT BY 1;


--  Triggers
CREATE OR REPLACE TRIGGER TRG_USUARIOS
BEFORE INSERT ON USUARIOS
FOR EACH ROW
WHEN (NEW.ID_USUARIO IS NULL)
BEGIN
    SELECT SEQ_USUARIOS.NEXTVAL INTO :NEW.ID_USUARIO FROM DUAL;
END;
/

CREATE OR REPLACE TRIGGER TRG_ROLES
BEFORE INSERT ON ROLES
FOR EACH ROW
WHEN (NEW.ID_ROL IS NULL)
BEGIN
    SELECT SEQ_ROLES.NEXTVAL INTO :NEW.ID_ROL FROM DUAL;
END;
/

CREATE OR REPLACE TRIGGER TRG_PERMISOS
BEFORE INSERT ON PERMISOS
FOR EACH ROW
WHEN (NEW.ID_PERMISO IS NULL)
BEGIN
    SELECT SEQ_PERMISOS.NEXTVAL INTO :NEW.ID_PERMISO FROM DUAL;
END;
/


-- Roles de base
INSERT INTO roles (nombre_rol) VALUES ('Administrador');
INSERT INTO roles (nombre_rol) VALUES ('Cliente');
INSERT INTO roles (nombre_rol) VALUES ('Gestor');

-- Permisos generales
INSERT INTO permisos (nombre, descripcion) VALUES ('GESTION_TOTAL', 'Acceso total al sistema');
INSERT INTO permisos (nombre, descripcion) VALUES ('VER_DATOS', 'Solo visualizar datos');
INSERT INTO permisos (nombre, descripcion) VALUES ('GESTION_LIMITADA', 'Acceso restringido');

-- Asignar permisos segun el rol
-- El Administrador tiene acceso total
INSERT INTO roles_permisos (id_rol, id_permiso) 
SELECT id_rol, (SELECT id_permiso FROM permisos WHERE nombre = 'GESTION_TOTAL') 
FROM roles WHERE nombre_rol = 'Administrador';

-- El Cliente solo puede ver datos
INSERT INTO roles_permisos (id_rol, id_permiso) 
SELECT id_rol, (SELECT id_permiso FROM permisos WHERE nombre = 'VER_DATOS') 
FROM roles WHERE nombre_rol = 'Cliente';

-- El Gestor tiene acceso limitado
INSERT INTO roles_permisos (id_rol, id_permiso) 
SELECT id_rol, (SELECT id_permiso FROM permisos WHERE nombre = 'GESTION_LIMITADA') 
FROM roles WHERE nombre_rol = 'Gestor';


-- Funcion para obtener el rol del usuario
CREATE OR REPLACE FUNCTION fn_obtener_rol (p_id_usuario NUMBER) RETURN VARCHAR2 IS
  v_rol 		VARCHAR2(50);
BEGIN
  SELECT r.nombre_rol
  INTO v_rol
  FROM usuarios u
  JOIN usuarios_roles ur ON u.id_usuario = ur.id_usuario
  JOIN roles r ON ur.id_rol = r.id_rol
  WHERE u.id_usuario = p_id_usuario;
  
  RETURN v_rol;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/


-- Autorizacion para las paginas
DECLARE
  v_rol 			VARCHAR2(50);
BEGIN
  v_rol := fn_obtener_rol(:APP_USER);
  RETURN v_rol = 'Administrador';
END;
