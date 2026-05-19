# GitLens4D

> **Git Blame & History inline** — direto no editor do Delphi IDE.

GitLens4D é um **IDE Expert** para Delphi que exibe, em tempo real, a autoria Git da linha onde o cursor está posicionado e permite navegar pelo histórico completo de cada linha do código — sem sair do IDE.

---

## Funcionalidades

| Funcionalidade | Descrição |
|---|---|
| **Blame em tempo real** | Mostra autor, data e mensagem do último commit da linha atual na aba de mensagens do IDE |
| **Histórico da linha** | Lista os últimos 10 commits que tocaram a linha selecionada, com hash, autor, data e mensagem |
| **Atalho de teclado** | `Ctrl+Shift+H` abre o histórico da linha sem usar o menu |
| **Modo Editor / Debug** | Blame pode ser habilitado/desabilitado independentemente para edição e para sessões de debug |
| **Configuração persistente** | Preferências salvas no Windows Registry (`HKCU\Software\QSGitLens4D`) |
| **Detecção automática do Git** | Localiza o `git.exe` via Registry, caminhos padrão e variável `LOCALAPPDATA` |

---

## Requisitos

- **Delphi** 10.4 Sydney ou superior (testado no Delphi 12 Alexandria / RAD Studio 25)
- **Git for Windows** instalado — [https://git-scm.com](https://git-scm.com)
- Sistema operacional **Windows** (Win32)

---

## Instalação

1. Clone o repositório:
   ```bash
   git clone https://github.com/vctamir/GitLens4D.git
   ```

2. Abra o projeto **`GitLens4D.dproj`** no Delphi IDE.

3. Compile o pacote (`Shift+F9` ou menu **Project › Compile**).

4. Instale o BPL gerado em `bin\GitLens4D.bpl`:
   - Menu **Component › Install Packages...**
   - Clique em **Add...** e selecione `bin\GitLens4D.bpl`

5. Reinicie o Delphi. O menu **QSGitLens4D** aparecerá em **View**.

---

## Uso

### Menu View › QSGitLens4D

| Item | Função |
|---|---|
| **Ativo no Editor** | Liga/desliga o blame automático durante edição |
| **Ativo no Debug** | Liga/desliga o blame automático durante debug |
| **Explorar Histórico da Linha Atual** | Abre o histórico da linha onde o cursor está |

### Atalho

| Atalho | Ação |
|---|---|
| `Ctrl+Shift+H` | Exibe o histórico Git completo da linha atual |

### Aba de Mensagens

As informações aparecem na aba **QSGitLens4D** dentro da janela **Messages** do IDE:

```
[a3f8b12] por João Silva em 18/05/2026 14:32:01
   💬 "fix: corrige cálculo de desconto em NF-e"
```

---

## Arquitetura

O projeto segue rigorosamente os princípios **SOLID**:

```
src/
├── GitLens4D.Interfaces.pas        # ISP + DIP  — contratos (interfaces puras)
├── GitLens4D.Settings.pas          # SRP        — persistência no Registry
├── GitLens4D.Git.PathResolver.pas  # SRP        — localiza o git.exe
├── GitLens4D.Git.Runner.pas        # SRP        — executa processos git via pipe
├── GitLens4D.Git.BlameParser.pas   # SRP        — interpreta saída do git blame -p
├── GitLens4D.Git.HistoryParser.pas # SRP        — interpreta saída do git log -L
├── GitLens4D.IDE.Menu.pas          # SRP        — cria e gerencia o menu do IDE
├── GitLens4D.IDE.CursorTracker.pas # SRP        — rastreia movimento do cursor via timer
├── GitLens4D.IDE.KeyBinding.pas    # SRP        — registra o atalho Ctrl+Shift+H
├── GitLens4D.IDE.Messenger.pas     # SRP        — exibe mensagens na aba do IDE
└── GitLens4D.Wizard.pas            # OCP + DIP  — orquestra via injeção de dependências
```

### Diagrama de dependências

```
GitLens4D.Interfaces  ◄──── (todos dependem)
       │
       ├── GitLens4D.Settings
       ├── GitLens4D.Git.PathResolver
       ├── GitLens4D.Git.Runner
       ├── GitLens4D.Git.BlameParser
       ├── GitLens4D.Git.HistoryParser
       ├── GitLens4D.IDE.Messenger
       │
       └── GitLens4D.Wizard  ◄── GitLens4D.IDE.Menu
                              ◄── GitLens4D.IDE.CursorTracker
                              ◄── GitLens4D.IDE.KeyBinding
```

### Princípios aplicados

| Princípio | Aplicação |
|---|---|
| **S**RP | Cada unit tem uma única responsabilidade bem definida |
| **O**CP | Novo parser/storage = nova classe; `Wizard.pas` não é alterado |
| **L**SP | Todas as implementações são substituíveis via suas interfaces |
| **I**SP | 6 interfaces atômicas em vez de uma interface monolítica |
| **D**IP | `TGitLens4D` depende apenas de interfaces, nunca de classes concretas |

---

## Estrutura de saídas

```
bin/    → BPLs gerados (GitLens4D.bpl, GitLens4D4D.bpl)
dcp/    → DCPs e BPIs de design
dcu/    → Headers C++ (hpp) para C++Builder
Win32/  → DCUs de compilação
```

---

## Licença

MIT © [vctamir](https://github.com/vctamir)
