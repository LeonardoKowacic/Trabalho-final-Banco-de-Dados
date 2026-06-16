-- =============================
-- G2 - Profissionais de Saude |
-- =============================

-- ---------- RESET (ordem de dependencia) ----------
DROP VIEW      IF EXISTS vw_profissionais_ativos;
DROP TABLE     IF EXISTS contato;
DROP TABLE     IF EXISTS profissional;
DROP TABLE     IF EXISTS especialidade;
DROP PROCEDURE IF EXISTS sp_cadastrar_profissional(VARCHAR, VARCHAR, INTEGER);
DROP PROCEDURE IF EXISTS sp_cadastrar_profissional(VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR);
DROP FUNCTION  IF EXISTS fn_validar_crm();

-- ---------- SCHEMA ----------
CREATE TABLE especialidade (
    id_especialidade SERIAL PRIMARY KEY,
    nome             VARCHAR(100) NOT NULL UNIQUE,
    descricao        VARCHAR(255)
);

CREATE TABLE profissional (
    id_profissional  SERIAL PRIMARY KEY,
    nome             VARCHAR(150) NOT NULL,
    crm              VARCHAR(20)  NOT NULL UNIQUE,
    status           BOOLEAN      NOT NULL DEFAULT TRUE,
    id_especialidade INTEGER      NOT NULL,
    data_cadastro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_profissional_especialidade
        FOREIGN KEY (id_especialidade) REFERENCES especialidade (id_especialidade)
);

CREATE TABLE contato (
    id_contato      SERIAL PRIMARY KEY,
    telefone        VARCHAR(20),
    email           VARCHAR(150),
    id_profissional INTEGER NOT NULL UNIQUE,
    CONSTRAINT fk_contato_profissional
        FOREIGN KEY (id_profissional) REFERENCES profissional (id_profissional)
        ON DELETE CASCADE
);

CREATE INDEX idx_profissional_nome ON profissional (nome);

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

CREATE OR REPLACE PROCEDURE sp_cadastrar_profissional(
    p_nome VARCHAR, p_crm VARCHAR, p_id_especialidade INTEGER,
    p_telefone VARCHAR DEFAULT NULL, p_email VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE v_id_profissional INTEGER;
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

CREATE VIEW vw_profissionais_ativos AS
SELECT p.id_profissional, p.nome, p.crm, e.nome AS especialidade, c.telefone, c.email
FROM profissional p
JOIN especialidade e ON p.id_especialidade = e.id_especialidade
LEFT JOIN contato c  ON p.id_profissional = c.id_profissional
WHERE p.status = TRUE;

-- ---------- DADOS DE TESTE ----------
INSERT INTO especialidade (nome, descricao) VALUES
    ('Cardiologia', 'Coracao e sistema circulatorio'),
    ('Pediatria',   'Saude da crianca'),
    ('Ortopedia',   'Sistema musculoesqueletico');

CALL sp_cadastrar_profissional('Joao Silva',  'CRM12345', 1, '49 99999-0001', 'joao@clinica.com');
CALL sp_cadastrar_profissional('Maria Souza', 'CRM54321', 2, '49 99999-0002', 'maria@clinica.com');
CALL sp_cadastrar_profissional('Carlos Inativo', 'CRM00000', 3);
UPDATE profissional SET status = FALSE WHERE crm = 'CRM00000';

-- =====================================================================
-- VALIDACAO AUTOMATICA
-- =====================================================================
DO $$
DECLARE v_n INTEGER; v_erro BOOLEAN;
BEGIN
    RAISE NOTICE '================ VALIDACAO G2 ================';

    SELECT count(*) INTO v_n FROM vw_profissionais_ativos;
    IF v_n = 2 THEN RAISE NOTICE 'OK  1) view retorna 2 ativos';
    ELSE RAISE EXCEPTION 'FALHA 1) esperado 2 ativos, veio %', v_n; END IF;

    SELECT count(*) INTO v_n FROM (
        SELECT id_profissional FROM vw_profissionais_ativos
        GROUP BY id_profissional HAVING count(*) > 1) d;
    IF v_n = 0 THEN RAISE NOTICE 'OK  2) sem profissional duplicado na view';
    ELSE RAISE EXCEPTION 'FALHA 2) % profissional(is) duplicado(s)', v_n; END IF;

    SELECT count(*) INTO v_n FROM vw_profissionais_ativos WHERE crm = 'CRM00000';
    IF v_n = 0 THEN RAISE NOTICE 'OK  3) profissional inativo fora da view';
    ELSE RAISE EXCEPTION 'FALHA 3) inativo apareceu na view'; END IF;

    v_erro := FALSE;
    BEGIN CALL sp_cadastrar_profissional('Dup', 'CRM12345', 1);
    EXCEPTION WHEN OTHERS THEN v_erro := TRUE; END;
    IF v_erro THEN RAISE NOTICE 'OK  4) procedure bloqueia CRM duplicado';
    ELSE RAISE EXCEPTION 'FALHA 4) CRM duplicado foi aceito'; END IF;

    v_erro := FALSE;
    BEGIN INSERT INTO profissional (nome, crm, id_especialidade) VALUES ('X', '   ', 1);
    EXCEPTION WHEN OTHERS THEN v_erro := TRUE; END;
    IF v_erro THEN RAISE NOTICE 'OK  5) trigger bloqueia CRM vazio';
    ELSE RAISE EXCEPTION 'FALHA 5) CRM vazio foi aceito'; END IF;

    SELECT count(*) INTO v_n FROM contato;
    IF v_n = 2 THEN RAISE NOTICE 'OK  6) procedure gravou os 2 contatos';
    ELSE RAISE EXCEPTION 'FALHA 6) esperado 2 contatos, veio %', v_n; END IF;

    RAISE NOTICE '================ TODOS OS TESTES PASSARAM ================';
END;
$$;


-- tabelas cruas
SELECT * FROM especialidade;
SELECT * FROM profissional;
SELECT * FROM contato;

-- a view (o que G3/G4 enxergam: so ativos, sem duplicar)
SELECT * FROM vw_profissionais_ativos;

-- feature 2: busca por especialidade
SELECT * FROM vw_profissionais_ativos WHERE especialidade = 'Pediatria';

-- feature 2: busca por nome (case-insensitive)
SELECT * FROM profissional WHERE nome ILIKE '%silva%';

-- visao completa, inclusive o inativo que a view esconde (Carlos)
SELECT p.id_profissional, p.nome, p.crm, p.status,
       e.nome AS especialidade, c.telefone, c.email
FROM profissional p
JOIN especialidade e ON e.id_especialidade = p.id_especialidade
LEFT JOIN contato c  ON c.id_profissional = p.id_profissional
ORDER BY p.id_profissional;