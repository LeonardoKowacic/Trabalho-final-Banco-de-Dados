# Trabalho Final - Banco de Dados 1

Modulo **G2 - Profissionais de Saude** | UNOESC Chapeco
Disciplina: Banco de Dados 1 - Prof. Alvaro Gianni Pagliari
Trabalho integrado com Programacao 1 e Engenharia de Software.

## Integrantes
- Jackson Michel Hillesheim Florêncio
- <preencher>
- <preencher>

## Descricao do modulo
Modulo responsavel pelo cadastro e consulta de profissionais de saude. Fornece dados para os modulos de Agenda (G3) e Consultas (G4); nao consome nenhum modulo.

Funcionalidades:
1. **Cadastro de profissionais** com CRM unico e validado (nome, CRM, especialidade e contato).
2. **Consulta por especialidade ou nome** para selecao em agendamentos.
3. **Controle de status** (ativo/inativo) - profissionais inativos nao aparecem para agendamento.

## Modelo de dados
Tres tabelas em 3a Forma Normal:

| Tabela | Descricao |
|---|---|
| `especialidade` | Especialidades medicas |
| `profissional`  | Profissionais, com FK para especialidade e flag de status |
| `contato`       | Telefone/e-mail do profissional (1:1) |

Cardinalidade:
- `especialidade` 1:N `profissional`
- `profissional` 1:1 `contato`

## Objetos de banco (requisitos BD1)
- **View** `vw_profissionais_ativos` - lista somente profissionais ativos (consumida por G3/G4).
- **Stored Procedure** `sp_cadastrar_profissional` - cadastra profissional + contato em uma transacao, bloqueando CRM duplicado.
- **Trigger** `trg_validar_crm` (funcao `fn_validar_crm`) - impede CRM nulo/vazio em INSERT e UPDATE.

## Como executar
Pre-requisito: PostgreSQL 16+.

1. Crie um banco para o sistema:
   ```sql
   CREATE DATABASE clinica;
   ```
2. Rode o script (escolha uma opcao):
   - **pgAdmin:** Query Tool conectado ao banco -> abrir `g2_profissionais_saude.sql` -> F5.
   - **psql:**
     ```bash
     psql -d clinica -f g2_profissionais_saude.sql
     ```

O script comeca com um bloco `DROP ... IF EXISTS`, entao pode ser executado quantas vezes quiser sem erro. Ao final, ele ja insere dados de exemplo e roda as consultas que demonstram o uso da view, da procedure e da trigger.

## Arquivos
- `g2_profissionais_saude.sql` - schema completo + dados de demonstracao.
- `diagrama_fisico.png` - diagrama fisico (exportado do pgAdmin).
