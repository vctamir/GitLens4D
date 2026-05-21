# GitLens4D

> **Git Management, AI Commits & Blame inline** — direto no editor do Delphi IDE.

GitLens4D é um **IDE Expert** para Delphi que traz o poder do Git para dentro do seu editor. Além de exibir autoria em tempo real (Blame) e histórico de linhas, agora oferece uma central completa de mudanças com geração de mensagens via IA.

---

## 🚀 Novas Funcionalidades (v1.1.0)

Além do tradicional Blame, a nova aba **"Git Changes"** (`Ctrl+Alt+G`) oferece:

- **Gestão de Commits Seletivos**: Use CheckBoxes para escolher exatamente quais arquivos entram no commit.
- **Sugestão de IA (Ollama/Proxy)**: Gera mensagens de commit inteligentes baseadas no Diff real do seu código.
- **Persistência de Rascunho**: A mensagem sugerida pela IA fica salva no Registro até você comitar ou pedir uma nova.
- **Gestão de Branches**: Crie e troque de branches diretamente pela interface.
- **Operações de Sync**: Botões dedicados para **Push** e **Pull**.
- **Descarte de Alterações**: Opção no menu de contexto para descartar modificações em arquivos específicos.
- **Segurança**: Alertas automáticos para arquivos não salvos no IDE e mudanças pendentes ao trocar de branch.

---

## Funcionalidades Clássicas

| Funcionalidade | Descrição |
|---|---|
| **Blame em tempo real** | Mostra autor, data e mensagem do último commit da linha atual na aba de mensagens do IDE |
| **Histórico da linha** | Lista os últimos 10 commits que tocaram a linha selecionada, com hash, autor, data e mensagem |
| **Atalho de teclado** | `Ctrl+Shift+H` para histórico da linha e `Ctrl+Alt+G` para a central de mudanças |
| **Modo Editor / Debug** | Blame pode ser habilitado/desabilitado independentemente para edição e debug |
| **Configuração de IA** | Suporte a Ollama (local) ou Proxy Quality com customização de modelo e temperatura |

---

## 🛠 Requisitos

- **Delphi 10.2 Tokyo** ou superior (suporte total a versões modernas)
- **Git for Windows** instalado — [https://git-scm.com](https://git-scm.com)
- Sistema operacional **Windows** (Win32)

---

## 📥 Instalação

1. Clone o repositório:
   ```bash
   git clone https://github.com/vctamir/GitLens4D.git
   ```

2. Abra o projeto **`GitLens4D.dproj`** no Delphi IDE.

3. Compile o pacote (`Shift+F9` ou menu **Project › Compile**).

4. Instale o BPL gerado em `bin\GitLens4D.bpl`:
   - Menu **Component › Install Packages...**
   - Clique em **Add...** e selecione `bin\GitLens4D.bpl`

5. Reinicie o Delphi. A aba **Git Changes** poderá ser aberta via menu **View › QSGitLens4D › Git Changes Window**.

---

## ⌨️ Atalhos Úteis

| Atalho | Ação |
|---|---|
| `Ctrl+Shift+H` | Exibe o histórico Git completo da linha atual |
| `Ctrl+Alt+G` | Abre/Foca na janela de Mudanças Git |

---

## 🏗 Arquitetura

O projeto segue rigorosamente os princípios **SOLID**, sendo altamente modular e extensível.

```
src/
├── GitLens4D.Interfaces.pas        # Contratos (DIP)
├── GitLens4D.Git.AIService.pas     # Integração com IA (Chat Completions)
├── GitLens4D.Git.Runner.pas        # Execução de comandos Git
├── GitLens4D.Git.StatusProvider.pas # Provedor de status do repositório
├── GitLens4D.IDE.StatusView.pas    # UI principal (Git Changes)
├── GitLens4D.IDE.DiffView.pas      # Visualizador de Diff colorido (RichEdit)
└── ...
```

---

## Licença

MIT © [vctamir](https://github.com/vctamir)
