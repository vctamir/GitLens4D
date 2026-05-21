# GitLens4D 🚀

> **Git Management, AI Commits & Blame inline** — direto no editor do Delphi IDE.

GitLens4D é um **IDE Expert** para Delphi que traz o poder do Git para dentro do seu editor. Além de exibir autoria em tempo real (Blame) e histórico de linhas, agora oferece uma central completa de mudanças com geração de mensagens via IA.

---

## 🚀 Novas Funcionalidades (v1.1.0)

A nova aba **"Git Changes"** (`Ctrl+Alt+G`) oferece:

- **Gestão de Commits Seletivos**: Use CheckBoxes para escolher exatamente quais arquivos entram no commit.
- **Sugestão de IA (Ollama/Proxy)**: Gera mensagens de commit inteligentes baseadas no Diff real do seu código.
- **Persistência de Rascunho**: A mensagem sugerida pela IA fica salva no Registro até você comitar ou pedir uma nova.
- **Gestão de Branches**: Crie e troque de branches diretamente pela interface.
- **Operações de Sync**: Botões dedicados para **Push** e **Pull**.
- **Descarte de Alterações**: Opção no menu de contexto para descartar modificações em arquivos específicos.
- **Segurança**: Alertas automáticos para arquivos não salvos no IDE e mudanças pendentes ao trocar de branch.

---

## 🎨 Funcionalidades Clássicas

| Funcionalidade | Descrição |
|---|---|
| **Blame em Tempo Real** | Mostra autor, data, hora e mensagem do último commit da linha atual na aba de mensagens do IDE. |
| **Histórico da Linha** | Lista os últimos 10 commits que tocaram a linha selecionada, com hash, autor, data e mensagem. |
| **Atalho de Teclado** | `Ctrl+Shift+H` para histórico da linha e `Ctrl+Alt+G` para a central de mudanças. |
| **Modo Editor / Debug** | O Blame pode ser habilitado/desabilitado independentemente para edição ativa ou sessões de debug. |
| **Configuração de IA** | Suporte a Ollama (local) ou Proxy Quality com customização de modelo e temperatura. |
| **Multi-Threading Real** | Toda a comunicação com a CLI do Git roda em threads em segundo plano. Sua IDE nunca congela. |

---

## 💻 Requisitos

- **Delphi 10.2 Tokyo** ou superior (Testado exaustivamente no Delphi 10.4 Sydney, 11 Alexandria e 12 Athens).
- **Git for Windows** instalado — [https://git-scm.com](https://git-scm.com).
- Sistema operacional **Windows** (Win32).

---

## 📦 Instalação

1. Clone o repositório para a sua máquina:
   ```bash
   git clone https://github.com/vctamir/GitLens4D.git
   ```

2. Abra o RAD Studio/Delphi e carregue o projeto **`GitLens4D.dproj`**.

3. Na aba **Project Manager**, clique com o botão direito em `GitLens4D.dpk` e selecione **Build**.

4. Após a conclusão do Build, clique novamente com o botão direito sobre o projeto e selecione **Install**.

5. Reinicie o Delphi. A aba **Git Changes** poderá ser aberta via menu **View › QSGitLens4D › Git Changes Window**.

---

## ⌨️ Atalhos Úteis

| Atalho | Ação |
|---|---|
| `Ctrl+Shift+H` | Exibe o histórico Git completo da linha atual |
| `Ctrl+Alt+G` | Abre/Foca na janela de Mudanças Git |

---

## 🏗️ Arquitetura (SOLID)

O projeto segue rigorosamente os princípios **SOLID**, sendo altamente modular e extensível:

```
src/
├── GitLens4D.Interfaces.pas       # ISP + DIP  — Contratos e desacoplamento (interfaces puras)
├── GitLens4D.Settings.pas         # SRP        — Persistência isolada no Registry do Windows
├── GitLens4D.Git.AIService.pas    # SRP        — Integração com IA (Chat Completions)
├── GitLens4D.Git.PathResolver.pas # SRP        — Algoritmo dedicado de localização do git.exe
├── GitLens4D.Git.Runner.pas       # SRP        — Execução assíncrona de processos via Windows Pipe
├── GitLens4D.Git.StatusProvider.pas # SRP      — Provedor de status do repositório
├── GitLens4D.IDE.StatusView.pas   # SRP        — UI principal (Git Changes)
├── GitLens4D.IDE.DiffView.pas     # SRP        — Visualizador de Diff colorido (RichEdit)
├── GitLens4D.IDE.Menu.pas         # SRP        — Criação e gerenciamento do ciclo de vida dos menus da IDE
├── GitLens4D.IDE.CursorTracker.pas# SRP        — Rastreamento otimizado de linha ativa via timers nativos
├── GitLens4D.IDE.KeyBinding.pas   # SRP        — Interceptador e registrador do atalho de teclado na ToolsAPI
├── GitLens4D.IDE.Messenger.pas    # SRP        — Fachada de comunicação com a IOTAMessageServices
└── GitLens4D.Wizard.pas           # OCP + DIP  — Orquestrador central acoplado apenas a contratos
```

---

## 📄 Licença

Este projeto é software livre, open-source e está licenciado sob os termos da **MIT License**. Sinta-se livre para clonar, modificar e distribuir.

Criado com ☕ e Delphi por [vctamir](https://github.com/vctamir).
