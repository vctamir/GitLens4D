# GitLens4D 🚀

> **Git Blame & History inline** — direto no editor do Delphi IDE.

GitLens4D é um **IDE Expert** para Delphi que exibe, em tempo real, a autoria Git da linha onde o cursor está posicionado e permite navegar pelo histórico completo de cada linha do código — sem sair do IDE.

---

## 🎨 Funcionalidades

| Funcionalidade | Descrição |
|---|---|
| **Blame em Tempo Real** | Mostra autor, data, hora e mensagem do último commit da linha atual na aba de mensagens do IDE. |
| **Histórico da Linha** | Lista os últimos 10 commits que tocaram a linha selecionada, com visualização inteligente e focada. |
| **Atalho de Teclado** | `Ctrl+Shift+H` dispara a varredura profunda e abre o histórico da linha instantaneamente. |
| **Modo Editor / Debug** | O Blame pode ser habilitado/desabilitado independentemente para edição ativa ou sessões de debug. |
| **Configuração Persistente** | Suas preferências são salvas automaticamente no Windows Registry (`HKCU\Software\QSGitLens4D`). |
| **Fura-Bolha (64/32-bits)** | Localiza o `git.exe` de forma agressiva via Registry, caminhos padrão e variável `LOCALAPPDATA` (ignora o isolamento 32-bits da IDE). |
| **Multi-Threading Real** | Toda a comunicação com a CLI do Git roda em threads em segundo plano. Sua IDE nunca congela. |

---

## 💻 Requisitos

- **Delphi** 10.3 Rio ou superior (Testado exaustivamente no Delphi 10.4 Sydney, 11 Alexandria e 12 Athens).
- **Git for Windows** instalado — [https://git-scm.com](https://git-scm.com).
- Sistema operacional **Windows** (Ambiente de desenvolvimento Win32 da IDE).

---

## 📦 Instalação

1. Clone o repositório para a sua máquina:
   ```bash
   git clone [https://github.com/vctamir/GitLens4D.git](https://github.com/vctamir/GitLens4D.git)
   ```

2. Abra o RAD Studio/Delphi e carregue o projeto **`GitLens4D.dproj`**.
3. Na aba **Project Manager** (geralmente no canto superior direito), clique com o botão direito em `GitLens4D.bpl` e selecione **Build**.
4. Após a conclusão do Build, clique novamente com o botão direito sobre o projeto e selecione **Install**.
5. Uma mensagem confirmando a instalação do Expert `QSGitLens Simples para Delphi` será exibida. O menu **QSGitLens4D** aparecerá automaticamente dentro do menu **View** da IDE.

---

## ⌨️ Uso & Manual

### Menu View › QSGitLens4D

| Item | Função |
| --- | --- |
| **Ativo no Editor** | Liga/desliga o blame automático no rodapé enquanto você digita ou navega. |
| **Ativo no Debug** | Liga/desliga o blame automático durante a execução com breakpoints pausados. |
| **Explorar Histórico da Linha Atual** | Atalho visual para disparar o rastreamento histórico do trecho de código. |

### Aba de Mensagens (Outputs)

As informações são injetadas em tempo real na aba customizada **QSGitLens4D** dentro da janela principal de **Messages** do Delphi:

#### 📺 Visualização de Linha Ativa (Blame):

```text
Linha 559: valdemir - 19/05/2026 às 09:04:09 - [FIX] - localização do git e utilização de threads

```

#### 📜 Visualização Avançada de Evolução (`Ctrl + Shift + H`):

O GitLens4D limpa os metadados brutos do Git e entrega o histórico estruturado em caixas visuais com **tradução de fuso e linhas em tempo real**:

```text
=== SESSÃO DE HISTÓRICO: EVOLUÇÃO DA LINHA 376 ===

➔ [df9bf00b6] por valdemir em 18/05/2026 14:18:34
   💬 "[FEAT] - Criação dos menus para ativar ou desativar monitoramento"
   ┌──────────────────────────────────────────────────────────────
   │ 📍 [ LINHA 434 NO PASSADO ] ➔ EMPURRADA PARA A [ LINHA 457 DESTE COMMIT ]
   │ ─────────────────────────────────────────────────────────────
   │ -  Comando := Format('git log...', []);
   │ +  Comando := Format('"%s" log...', [GitExe]);
   └──────────────────────────────────────────────────────────────

```

---

## 🏗️ Arquitetura (SOLID)

O projeto foi totalmente reestruturado para seguir de forma rígida e escalável os padrões de design de software:

```
src/
├── GitLens4D.Interfaces.pas       # ISP + DIP  — Contratos e desacoplamento (interfaces puras)
├── GitLens4D.Settings.pas         # SRP        — Persistência isolada no Registry do Windows
├── GitLens4D.Git.PathResolver.pas # SRP        — Algoritmo dedicado de localização do git.exe
├── GitLens4D.Git.Runner.pas       # SRP        — Execução assíncrona de processos via Windows Pipe
├── GitLens4D.Git.BlameParser.pas  # SRP        — Interpretador especializado da saída estruturada do blame
├── GitLens4D.Git.HistoryParser.pas# SRP        — Interpretador e tradutor do log de patches do Git
├── GitLens4D.IDE.Menu.pas         # SRP        — Criação e gerenciamento do ciclo de vida dos menus da IDE
├── GitLens4D.IDE.CursorTracker.pas# SRP        — Rastreamento otimizado de linha ativa via timers nativos
├── GitLens4D.IDE.KeyBinding.pas   # SRP        — Interceptador e registrador do atalho de teclado na ToolsAPI
├── GitLens4D.IDE.Messenger.pas    # SRP        — Fachada de comunicação com a IOTAMessageServices
└── GitLens4D.Wizard.pas           # OCP + DIP  — Orquestrador central acoplado apenas a contratos

```

### Diagrama de Dependências

```
GitLens4D.Interfaces  ◄──── (Todos os submódulos dependem apenas deste contrato)
       │
       ├── GitLens4D.Settings
       ├── GitLens4D.Git.PathResolver
       ├── GitLens4D.Git.Runner
       ├── GitLens4D.Git.BlameParser
       ├── GitLens4D.Git.HistoryParser
       ├── GitLens4D.IDE.Messenger
       │
       └── GitLens4D.Wizard  ◄── Injeta via IOC: GitLens4D.IDE.Menu
                             ◄── Injeta via IOC: GitLens4D.IDE.CursorTracker
                             ◄── Injeta via IOC: GitLens4D.IDE.KeyBinding

```

### Princípios Aplicados

| Diretriz | Aplicação Técnica no Projeto |
| --- | --- |
| **S**RP | Nenhuma unit faz papel duplo. O Parser traduz, o Runner executa, o Tracker rastreia. |
| **O**CP | Para persistir configurações em arquivo `.ini` em vez do Registry, basta criar uma nova classe. O Core (`Wizard.pas`) não sofre alteração. |
| **L**SP | Qualquer implementação de Runner ou Parser pode ser substituída sem quebrar o ecossistema. |
| **I**SP | Interfaces divididas em pequenos escopos atômicos de execução em vez de um contrato inflado. |
| **D**IP | A classe central do Expert consome estritamente as assinaturas abstratas do repositório. |

---

## 📄 Licença

Este projeto é software livre, open-source e está licenciado sob os termos da **MIT License**. Sinta-se livre para clonar, modificar e distribuir.

Criado com ☕ e Delphi por [vctamir](https://github.com/vctamir).

```

