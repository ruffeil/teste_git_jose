-- ============================================================================
-- BANCO DE DADOS ACADÊMICO: SOFTWARE HOUSE (MODELO RELACIONAL COMPLETO - 3FN)
-- SGBD: SQLite 3.35+
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- 1. ESTRUTURA ORGANIZACIONAL E PESSOAS
-- ============================================================================

CREATE TABLE sh_departamentos (
    departamento_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    nome                TEXT NOT NULL UNIQUE,
    centro_custo        TEXT NOT NULL UNIQUE,
    criado_em           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE sh_cargos (
    cargo_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    departamento_id     INTEGER NOT NULL REFERENCES sh_departamentos(departamento_id),
    cargo_supervisor_id INTEGER REFERENCES sh_cargos(cargo_id), -- Auto-relacionamento hierárquico
    titulo              TEXT NOT NULL,
    senioridade         TEXT NOT NULL CHECK (senioridade IN ('Estagiario', 'Junior', 'Pleno', 'Senior', 'Staff', 'Principal', 'Lead')),
    custo_hora_base     REAL NOT NULL CHECK (custo_hora_base >= 0),
    UNIQUE (titulo, senioridade)
);

CREATE TABLE sh_colaboradores (
    colaborador_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    cargo_id            INTEGER NOT NULL REFERENCES sh_cargos(cargo_id),
    gestor_id           INTEGER REFERENCES sh_colaboradores(colaborador_id), -- Liderança direta
    nome_completo       TEXT NOT NULL,
    email_corporativo   TEXT NOT NULL UNIQUE,
    cpf                 TEXT NOT NULL UNIQUE CHECK (length(cpf) = 11),
    regime_contratacao  TEXT NOT NULL CHECK (regime_contratacao IN ('CLT', 'PJ', 'Estagio', 'Societario')),
    data_admissao       TEXT NOT NULL, -- Formato YYYY-MM-DD
    data_desligamento   TEXT,
    ativo               INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0, 1)),
    CHECK (data_desligamento IS NULL OR data_desligamento >= data_admissao)
);

CREATE TABLE sh_tecnologias (
    tecnologia_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    nome                TEXT NOT NULL UNIQUE,
    categoria           TEXT NOT NULL CHECK (categoria IN ('Linguagem', 'Framework', 'Banco de Dados', 'Cloud/Infra', 'DevOps/CI-CD', 'QA/Testes', 'IA/Dados'))
);

-- Relacionamento N:N entre colaboradores e tecnologias
CREATE TABLE sh_colaborador_tecnologias (
    colaborador_id      INTEGER NOT NULL REFERENCES sh_colaboradores(colaborador_id) ON DELETE CASCADE,
    tecnologia_id       INTEGER NOT NULL REFERENCES sh_tecnologias(tecnologia_id),
    nivel_proficiencia  INTEGER NOT NULL CHECK (nivel_proficiencia BETWEEN 1 AND 5),
    anos_experiencia    REAL NOT NULL CHECK (anos_experiencia >= 0),
    PRIMARY KEY (colaborador_id, tecnologia_id)
);

-- ============================================================================
-- 2. CLIENTES, CONTRATOS E ESCOPO
-- ============================================================================

CREATE TABLE sh_clientes (
    cliente_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    razao_social        TEXT NOT NULL,
    nome_fantasia       TEXT,
    cnpj                TEXT NOT NULL UNIQUE CHECK (length(cnpj) = 14),
    segmento_atuacao    TEXT NOT NULL,
    porte_empresa       TEXT NOT NULL CHECK (porte_empresa IN ('MEI/ME', 'EPP', 'Medio', 'Grande', 'Enterprise')),
    criado_em           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE sh_contatos_cliente (
    contato_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id          INTEGER NOT NULL REFERENCES sh_clientes(cliente_id) ON DELETE CASCADE,
    nome                TEXT NOT NULL,
    email               TEXT NOT NULL,
    telefone            TEXT,
    papel_decisao       TEXT NOT NULL CHECK (papel_decisao IN ('Sponsor', 'Product Owner', 'Tech Lead', 'Financeiro', 'Operacional')),
    principal           INTEGER NOT NULL DEFAULT 0 CHECK (principal IN (0, 1))
);

CREATE TABLE sh_contratos (
    contrato_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id          INTEGER NOT NULL REFERENCES sh_clientes(cliente_id),
    codigo_contrato     TEXT NOT NULL UNIQUE,
    modelo_cobranca     TEXT NOT NULL CHECK (modelo_cobranca IN ('Escopo Fechado', 'Time and Materials', 'Squad Dedicada', 'Retainer/AMS')),
    data_inicio         TEXT NOT NULL,
    data_fim_previsto   TEXT NOT NULL,
    valor_total_brl     REAL NOT NULL CHECK (valor_total_brl > 0),
    sla_resposta_horas  INTEGER NOT NULL DEFAULT 4 CHECK (sla_resposta_horas > 0),
    status_contrato     TEXT NOT NULL CHECK (status_contrato IN ('Rascunho', 'Ativo', 'Suspenso', 'Encerrado', 'Rescindido')),
    CHECK (data_fim_previsto >= data_inicio)
);

CREATE TABLE sh_projetos (
    projeto_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    contrato_id         INTEGER NOT NULL REFERENCES sh_contratos(contrato_id),
    gerente_projeto_id  INTEGER NOT NULL REFERENCES sh_colaboradores(colaborador_id),
    codigo_projeto      TEXT NOT NULL UNIQUE,
    nome_projeto        TEXT NOT NULL,
    metodologia         TEXT NOT NULL CHECK (metodologia IN ('Scrum', 'Kanban', 'Hibrido', 'Cascata')),
    data_kickoff        TEXT NOT NULL,
    data_entrega_meta   TEXT NOT NULL,
    status_projeto      TEXT NOT NULL CHECK (status_projeto IN ('Planejamento', 'Em Execucao', 'Homologacao', 'Pausado', 'Concluido', 'Cancelado')),
    CHECK (data_entrega_meta >= data_kickoff)
);

-- Stack tecnológica exigida/adotada por projeto (N:N)
CREATE TABLE sh_projeto_tecnologias (
    projeto_id          INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    tecnologia_id       INTEGER NOT NULL REFERENCES sh_tecnologias(tecnologia_id),
    obrigatoria         INTEGER NOT NULL DEFAULT 1 CHECK (obrigatoria IN (0, 1)),
    PRIMARY KEY (projeto_id, tecnologia_id)
);

-- Alocação de equipe no projeto com vigência (N:N com atributos)
CREATE TABLE sh_alocacoes_projeto (
    alocacao_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id           INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    colaborador_id       INTEGER NOT NULL REFERENCES sh_colaboradores(colaborador_id),
    papel_no_projeto     TEXT NOT NULL,
    percentual_dedicacao INTEGER NOT NULL CHECK (percentual_dedicacao BETWEEN 5 AND 100),
    valor_hora_faturado  REAL NOT NULL CHECK (valor_hora_faturado >= 0),
    data_inicio          TEXT NOT NULL,
    data_fim             TEXT,
    CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);

-- ============================================================================
-- 3. CICLO DE ENGENHARIA (SPRINTS, REQUISITOS, TAREFAS E RELEASES)
-- ============================================================================

CREATE TABLE sh_sprints (
    sprint_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id           INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    numero_sprint        INTEGER NOT NULL CHECK (numero_sprint > 0),
    objetivo_sprint      TEXT NOT NULL,
    data_inicio          TEXT NOT NULL,
    data_fim             TEXT NOT NULL,
    pontos_comprometidos INTEGER NOT NULL DEFAULT 0 CHECK (pontos_comprometidos >= 0),
    pontos_entregues     INTEGER NOT NULL DEFAULT 0 CHECK (pontos_entregues >= 0),
    status_sprint        TEXT NOT NULL CHECK (status_sprint IN ('Planejada', 'Ativa', 'Concluida', 'Cancelada')),
    UNIQUE (projeto_id, numero_sprint),
    CHECK (data_fim >= data_inicio)
);

CREATE TABLE sh_requisitos (
    requisito_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id          INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    requisito_pai_id    INTEGER REFERENCES sh_requisitos(requisito_id), -- Decomposição Épico -> Feature -> Requisito
    codigo_requisito    TEXT NOT NULL,
    tipo_requisito      TEXT NOT NULL CHECK (tipo_requisito IN ('Funcional', 'Nao Funcional', 'Regra de Negocio', 'Seguranca')),
    prioridade_moscow   TEXT NOT NULL CHECK (prioridade_moscow IN ('Must', 'Should', 'Could', 'Wont')),
    versao_escopo       INTEGER NOT NULL DEFAULT 1 CHECK (versao_escopo > 0),
    descricao           TEXT NOT NULL,
    UNIQUE (projeto_id, codigo_requisito, versao_escopo)
);

CREATE TABLE sh_tarefas (
    tarefa_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id            INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    sprint_id             INTEGER REFERENCES sh_sprints(sprint_id) ON DELETE SET NULL,
    requisito_id          INTEGER REFERENCES sh_requisitos(requisito_id) ON DELETE SET NULL,
    responsavel_id        INTEGER REFERENCES sh_colaboradores(colaborador_id),
    revisor_id            INTEGER REFERENCES sh_colaboradores(colaborador_id),
    tarefa_bloqueadora_id INTEGER REFERENCES sh_tarefas(tarefa_id), -- Dependência técnica entre tarefas
    codigo_tarefa         TEXT NOT NULL,
    titulo                TEXT NOT NULL,
    tipo_tarefa           TEXT NOT NULL CHECK (tipo_tarefa IN ('Feature', 'Bug', 'Refatoracao', 'Infra/DevOps', 'QA/Teste', 'Documentacao')),
    story_points          INTEGER CHECK (story_points IN (1, 2, 3, 5, 8, 13, 21)),
    horas_estimadas       REAL NOT NULL CHECK (horas_estimadas >= 0),
    status_tarefa         TEXT NOT NULL CHECK (status_tarefa IN ('Backlog', 'A Fazer', 'Em Progresso', 'Code Review', 'Em QA', 'Bloqueada', 'Concluida')),
    criada_em             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    concluida_em          TEXT,
    UNIQUE (projeto_id, codigo_tarefa)
);

CREATE TABLE sh_apontamentos_horas (
    apontamento_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    tarefa_id           INTEGER NOT NULL REFERENCES sh_tarefas(tarefa_id) ON DELETE CASCADE,
    colaborador_id      INTEGER NOT NULL REFERENCES sh_colaboradores(colaborador_id),
    data_trabalho       TEXT NOT NULL,
    horas_trabalhadas   REAL NOT NULL CHECK (horas_trabalhadas > 0 AND horas_trabalhadas <= 24),
    faturavel           INTEGER NOT NULL DEFAULT 1 CHECK (faturavel IN (0, 1)),
    observacao          TEXT,
    criado_em           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE sh_releases (
    release_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id            INTEGER NOT NULL REFERENCES sh_projetos(projeto_id) ON DELETE CASCADE,
    responsavel_deploy_id INTEGER NOT NULL REFERENCES sh_colaboradores(colaborador_id),
    versao_semantica      TEXT NOT NULL, -- Ex: v1.4.2
    ambiente              TEXT NOT NULL CHECK (ambiente IN ('Dev', 'QA/Staging', 'Producao')),
    data_deploy           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    sucesso_deploy        INTEGER NOT NULL CHECK (sucesso_deploy IN (0, 1)),
    notas_release         TEXT,
    UNIQUE (projeto_id, versao_semantica, ambiente)
);

-- Tarefas incluídas em cada release (N:N)
CREATE TABLE sh_release_tarefas (
    release_id          INTEGER NOT NULL REFERENCES sh_releases(release_id) ON DELETE CASCADE,
    tarefa_id           INTEGER NOT NULL REFERENCES sh_tarefas(tarefa_id),
    PRIMARY KEY (release_id, tarefa_id)
);

-- ============================================================================
-- 4. QUALIDADE, INCIDENTES/SLA, FINANCEIRO E AUDITORIA
-- ============================================================================

CREATE TABLE sh_incidentes_suporte (
    incidente_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    projeto_id           INTEGER NOT NULL REFERENCES sh_projetos(projeto_id),
    release_id           INTEGER REFERENCES sh_releases(release_id),
    atribuido_a_id       INTEGER REFERENCES sh_colaboradores(colaborador_id),
    severidade           TEXT NOT NULL CHECK (severidade IN ('Critica', 'Alta', 'Media', 'Baixa')),
    origem_falha         TEXT NOT NULL CHECK (origem_falha IN ('Codigo Aplicacao', 'Infra/Cloud', 'Dados/Integracao', 'Erro Usuario', 'Terceiros')),
    aberto_em            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    primeira_resposta_em TEXT,
    resolvido_em         TEXT,
    status_incidente     TEXT NOT NULL CHECK (status_incidente IN ('Aberto', 'Em Analise', 'Aguardando Cliente', 'Resolvido', 'Fechado')),
    descricao            TEXT NOT NULL,
    CHECK (primeira_resposta_em IS NULL OR primeira_resposta_em >= aberto_em),
    CHECK (resolvido_em IS NULL OR resolvido_em >= aberto_em)
);

CREATE TABLE sh_faturas (
    fatura_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    contrato_id         INTEGER NOT NULL REFERENCES sh_contratos(contrato_id),
    projeto_id          INTEGER REFERENCES sh_projetos(projeto_id),
    numero_nota_fiscal  TEXT UNIQUE,
    competencia         TEXT NOT NULL, -- Primeiro dia do mês (YYYY-MM-01)
    data_emissao        TEXT NOT NULL,
    data_vencimento     TEXT NOT NULL,
    data_pagamento      TEXT,
    valor_bruto_brl     REAL NOT NULL CHECK (valor_bruto_brl > 0),
    impostos_brl        REAL NOT NULL DEFAULT 0 CHECK (impostos_brl >= 0),
    status_fatura       TEXT NOT NULL CHECK (status_fatura IN ('Emitida', 'Paga', 'Vencida', 'Cancelada')),
    CHECK (data_vencimento >= data_emissao),
    CHECK (data_pagamento IS NULL OR data_pagamento >= data_emissao)
);

CREATE TABLE sh_auditoria_alteracoes (
    auditoria_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    tabela_afetada      TEXT NOT NULL,
    registro_id         INTEGER NOT NULL,
    operacao            TEXT NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    resumo_dados        TEXT,
    ocorrido_em         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ============================================================================
-- 5. ÍNDICES DE PERFORMANCE
-- ============================================================================

CREATE INDEX idx_sh_colaboradores_cargo ON sh_colaboradores(cargo_id);
CREATE INDEX idx_sh_contratos_cliente ON sh_contratos(cliente_id);
CREATE INDEX idx_sh_projetos_contrato ON sh_projetos(contrato_id);
CREATE INDEX idx_sh_tarefas_projeto_status ON sh_tarefas(projeto_id, status_tarefa);
CREATE INDEX idx_sh_tarefas_sprint ON sh_tarefas(sprint_id);
CREATE INDEX idx_sh_apontamentos_data ON sh_apontamentos_horas(data_trabalho);
CREATE INDEX idx_sh_incidentes_projeto_sev ON sh_incidentes_suporte(projeto_id, severidade);
CREATE INDEX idx_sh_faturas_contrato_comp ON sh_faturas(contrato_id, competencia);

-- ============================================================================
-- 6. TRIGGERS DE AUDITORIA E VIEW ANALÍTICA
-- ============================================================================

CREATE TRIGGER trg_sh_projetos_insert
AFTER INSERT ON sh_projetos
BEGIN
    INSERT INTO sh_auditoria_alteracoes (tabela_afetada, registro_id, operacao, resumo_dados)
    VALUES (
        'sh_projetos',
        NEW.projeto_id,
        'INSERT',
        json_object(
            'codigo_projeto', NEW.codigo_projeto,
            'nome_projeto', NEW.nome_projeto,
            'status_projeto', NEW.status_projeto
        )
    );
END;

CREATE TRIGGER trg_sh_projetos_update
AFTER UPDATE ON sh_projetos
BEGIN
    INSERT INTO sh_auditoria_alteracoes (tabela_afetada, registro_id, operacao, resumo_dados)
    VALUES (
        'sh_projetos',
        NEW.projeto_id,
        'UPDATE',
        json_object(
            'status_anterior', OLD.status_projeto,
            'status_novo', NEW.status_projeto,
            'data_entrega_meta', NEW.data_entrega_meta
        )
    );
END;

CREATE TRIGGER trg_sh_projetos_delete
AFTER DELETE ON sh_projetos
BEGIN
    INSERT INTO sh_auditoria_alteracoes (tabela_afetada, registro_id, operacao, resumo_dados)
    VALUES (
        'sh_projetos',
        OLD.projeto_id,
        'DELETE',
        json_object(
            'codigo_projeto', OLD.codigo_projeto,
            'nome_projeto', OLD.nome_projeto
        )
    );
END;

CREATE VIEW vw_sh_saude_projetos AS
SELECT
    p.projeto_id,
    p.codigo_projeto,
    p.nome_projeto,
    c.razao_social AS cliente,
    ct.modelo_cobranca,
    ct.valor_total_brl AS valor_contrato_brl,
    COALESCE(SUM(ah.horas_trabalhadas), 0) AS total_horas_apontadas,
    COALESCE(SUM(CASE WHEN ah.faturavel = 1 THEN ah.horas_trabalhadas ELSE 0 END), 0) AS horas_faturaveis,
    COUNT(DISTINCT CASE WHEN inc.severidade IN ('Critica', 'Alta') THEN inc.incidente_id END) AS incidentes_criticos_altos
FROM sh_projetos p
JOIN sh_contratos ct ON ct.contrato_id = p.contrato_id
JOIN sh_clientes c ON c.cliente_id = ct.cliente_id
LEFT JOIN sh_tarefas t ON t.projeto_id = p.projeto_id
LEFT JOIN sh_apontamentos_horas ah ON ah.tarefa_id = t.tarefa_id
LEFT JOIN sh_incidentes_suporte inc ON inc.projeto_id = p.projeto_id
GROUP BY p.projeto_id, p.codigo_projeto, p.nome_projeto, c.razao_social, ct.modelo_cobranca, ct.valor_total_brl;