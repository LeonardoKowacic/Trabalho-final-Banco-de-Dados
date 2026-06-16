-- =====================================================================
-- UNOESC Chapeco | Banco de Dados 1 | Prof. Alvaro Gianni Pagliari
-- Trabalho Final - Modulo G2: Profissionais de Saude
-- Integrantes: Jackson Michel Hillesheim Florencio, Leonardo Kowacic, Joao Marcos Stahl
-- SGBD: PostgreSQL 16+
-- ---------------------------------------------------------------------
-- Como executar:
--   pgAdmin -> Query Tool (conectado no banco) -> abrir este arquivo -> F5
-- O bloco DROP abaixo torna o script re-executavel (pode rodar varias vezes).
-- =====================================================================

-- ---------- LIMPEZA (ordem de dependencia) ----------
DROP VIEW      IF EXISTS vw_profissionais_ativos;
DROP TABLE     IF EXISTS contato;
DROP TABLE     IF EXISTS profissional;
DROP TABLE     IF EXISTS especialidade;
DROP PROCEDURE IF EXISTS sp_cadastrar_profissional(VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR);
DROP FUNCTION  IF EXISTS fn_validar_crm();

-- =====================================================================
-- TABELAS  (3a Forma Normal, nomes sem acentuacao, snake_case)
-- =====================================================================
CREATE TABLE especialidade (
    id_especialidade SERIAL PRIMARY KEY,
    nome             VARCHAR(100) NOT NULL UNIQUE,
    descricao        VARCHAR(255)
);

CREATE TABLE profissional (
    id_profissional  SERIAL PRIMARY KEY,
    nome             VARCHAR(150) NOT NULL,
    crm              VARCHAR(20)  NOT NULL UNIQUE,        -- CRM unico (feature 1)
    status           BOOLEAN      NOT NULL DEFAULT TRUE,  -- ativo/inativo (feature 3)
    id_especialidade INTEGER      NOT NULL,
    data_cadastro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_profissional_especialidade
        FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade)
);

-- contato 1:1 com profissional (UNIQUE garante 1 contato por profissional)
CREATE TABLE contato (
    id_contato      SERIAL PRIMARY KEY,
    telefone        VARCHAR(20),
    email           VARCHAR(150),
    id_profissional INTEGER NOT NULL UNIQUE,
    CONSTRAINT fk_contato_profissional
        FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional)
        ON DELETE CASCADE
);

-- indice para a busca por nome (feature 2); crm e especialidade.nome ja sao indexados pelo UNIQUE
CREATE INDEX idx_profissional_nome ON profissional (nome);

-- =====================================================================
-- TRIGGER  (feature 1 - garante que o CRM nunca seja vazio/em branco)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_validar_crm()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.crm IS NULL OR LENGTH(TRIM(NEW.crm)) = 0 THEN
        RAISE EXCEPTION 'CRM deve ser informado.';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_crm
    BEFORE INSERT OR UPDATE ON profissional
    FOR EACH ROW EXECUTE FUNCTION fn_validar_crm();

-- =====================================================================
-- STORED PROCEDURE  (feature 1 - cadastra profissional + contato em 1 transacao)
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_cadastrar_profissional(
    p_nome             VARCHAR,
    p_crm              VARCHAR,
    p_id_especialidade INTEGER,
    p_telefone         VARCHAR DEFAULT NULL,
    p_email            VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_id_profissional INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM profissional WHERE crm = p_crm) THEN
        RAISE EXCEPTION 'CRM % ja cadastrado.', p_crm;
    END IF;

    INSERT INTO profissional (nome, crm, id_especialidade)
    VALUES (p_nome, p_crm, p_id_especialidade)
    RETURNING id_profissional INTO v_id_profissional;

    IF p_telefone IS NOT NULL OR p_email IS NOT NULL THEN
        INSERT INTO contato (telefone, email, id_profissional)
        VALUES (p_telefone, p_email, v_id_profissional);
    END IF;
END;
$$;

-- =====================================================================
-- VIEW  (features 2 e 3 - somente profissionais ATIVOS, consumida por G3/G4)
-- =====================================================================
CREATE VIEW vw_profissionais_ativos AS
SELECT p.id_profissional,
       p.nome,
       p.crm,
       e.nome AS especialidade,
       c.telefone,
       c.email
FROM profissional p
JOIN especialidade e ON p.id_especialidade = e.id_especialidade
LEFT JOIN contato c  ON p.id_profissional = c.id_profissional
WHERE p.status = TRUE;

-- =====================================================================
-- DEMONSTRACAO DE USO  (cada objeto exercitado pelo sistema)
-- =====================================================================
-- especialidades base
INSERT INTO especialidade (nome, descricao) VALUES
    ('Cardiologia', 'Coracao e sistema circulatorio'),
    ('Pediatria',   'Saude da crianca'),
    ('Ortopedia',   'Sistema musculoesqueletico');

-- cadastro de profissionais via procedure (com contato)
CALL sp_cadastrar_profissional('Joao Silva',  'CRM12345', 1, '49 99999-0001', 'joao@clinica.com');
CALL sp_cadastrar_profissional('Maria Souza', 'CRM54321', 2, '49 99999-0002', 'maria@clinica.com');

-- profissional inativo (feature 3): cadastrado e depois desativado -> sai da view
CALL sp_cadastrar_profissional('Carlos Pereira', 'CRM00000', 3);
UPDATE profissional SET status = FALSE WHERE crm = 'CRM00000';

-- consultas usadas pelo sistema:
-- 1) lista de ativos (o que G3/G4 enxergam)
SELECT * FROM vw_profissionais_ativos;
-- 2) busca por especialidade (feature 2)
SELECT * FROM vw_profissionais_ativos WHERE especialidade = 'Pediatria';
-- 3) busca por nome (feature 2)
SELECT * FROM profissional WHERE nome ILIKE '%silva%';
