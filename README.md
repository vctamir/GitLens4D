# GitLens4D 🚀

> **Git Management, AI Commits & Blame inline** — direto no editor do Delphi IDE.

GitLens4D é um **IDE Expert** para Delphi que traz o poder do Git para dentro do seu editor. Além de exibir autoria em tempo real (Blame) e histórico de linhas, agora oferece uma central completa de mudanças com geração de mensagens via IA.

---

## ✨ Novidades desta versão

**Todas as telas foram reescritas em HTML**, renderizadas dentro da IDE com tema
escuro combinando com o editor. São cinco: Git Changes, Diff, Histórico da
Linha, Configurações e Pull Request — todas partilhando uma única folha de
estilo (`ui/base.css`), então o visual é consistente por construção.

- **Diff de verdade**: coloração por linha cobrindo a linha inteira, numeração
  pelo arquivo novo e resumo `+N -M`. O `TRichEdit` anterior pintava caractere a
  caractere e não tinha número de linha.
- **Menu no botão direito do editor**: submenu **GitLens4D** com as mesmas ações
  do menu View, no lugar onde se está quando se quer perguntar sobre uma linha.
- **As legendas mostram o atalho real**, lido das configurações — antes o texto
  era fixo e podia mentir sobre a tecla.
- **Instalador** (veja abaixo): instala por usuário, sem pedir administrador.

Correções que vieram junto:

| Sintoma | Causa |
|---|---|
| `Ctrl+Shift+H` não fazia nada | O atalho lia o último cursor visto pelo rastreador, que só é atualizado com o Blame ligado. Agora lê o editor ao vivo. |
| Acentos quebrados nos menus | `UTF8ToString` sobre literal em arquivo com BOM: o compilador já entrega Unicode, e a conversão extra corrompia o texto. |
| Versão do executável errada na mensagem de commit | A versão é propriedade da *build configuration*, com herança. Agora vem de `IOTAProjectOptionsConfigurations.ActiveConfiguration`. |
| `[TIPO]` aparecendo na mensagem de commit | O prompt pedia para substituir um placeholder, e modelos menores copiavam-no. O exemplo agora vem preenchido, e há uma rede de segurança que deduz o tipo do próprio diff. |

---

## 🚀 Central de Mudanças (Git Changes)

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
| **Atalho de Teclado** | `Ctrl+Shift+H` para histórico da linha e `Ctrl+Alt+G` para a central de mudanças — ambos configuráveis. |
| **Menu de Contexto** | Botão direito no editor › **GitLens4D**: histórico da linha, Git Changes, liga/desliga do Blame e configurações. |
| **Modo Editor / Debug** | O Blame pode ser habilitado/desabilitado independentemente para edição ativa ou sessões de debug. |
| **Configuração de IA** | Suporte a Ollama (local) ou Proxy Quality com customização de modelo e temperatura. |
| **Multi-Threading Real** | Toda a comunicação com a CLI do Git roda em threads em segundo plano. Sua IDE nunca congela. |

---

## 💻 Requisitos

- **Delphi 10.2 Tokyo** ou superior (Testado exaustivamente no Delphi 10.4 Sydney, 11 Alexandria e 12 Athens).
- **Git for Windows** instalado — [https://git-scm.com](https://git-scm.com).
- Sistema operacional **Windows** (Win32).

> As telas usam o `TWebBrowser` da IDE, que roda sobre o Trident (IE11). O
> plugin registra `FEATURE_BROWSER_EMULATION` sozinho na primeira execução —
> sem isso o controle roda em modo IE7 e o layout não renderiza.

---

## 📦 Instalação

### Pelo instalador (recomendado)

Baixe o `GitLens4D-<versao>-setup.exe` e execute com o **RAD Studio fechado**.
Ele instala por usuário (sem pedir administrador) em
`%LOCALAPPDATA%\Programs\GitLens4D` e registra o pacote na IDE; ao abrir o
Delphi, o GitLens4D já está lá.

Para gerar o instalador a partir do fonte:

```powershell
.\build-installer.ps1
```

O script compila o pacote em Release, confere que a pasta `ui\` está completa
e empacota com o Inno Setup. A versão sai do próprio `.dproj` — não há número
duplicado em lugar nenhum.

> A pasta `ui\` acompanha o `.bpl` e **não é opcional**: as telas do plugin são
> páginas HTML, e o plugin as procura em `<pasta do .bpl>\..\ui`.

### Compilando pela IDE

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
├── GitLens4D.IDE.WebHost.pas      # SRP        — Host do TWebBrowser: ponte JS↔Pascal, teclado e ciclo de vida
├── GitLens4D.IDE.StatusView.pas   # SRP        — UI principal (Git Changes)
├── GitLens4D.IDE.DiffView.pas     # SRP        — Visualizador de Diff colorido
├── GitLens4D.IDE.HistoryView.pas  # SRP        — Evolução da linha (commits + patch)
├── GitLens4D.IDE.SettingsView.pas # SRP        — Configurações (geral e IA)
├── GitLens4D.IDE.PRView.pas       # SRP        — Descrição de Pull Request
├── GitLens4D.IDE.Menu.pas         # SRP        — Menus da IDE (View e contexto do editor) e seu ciclo de vida
├── GitLens4D.IDE.CursorTracker.pas# SRP        — Rastreamento otimizado de linha ativa via timers nativos
├── GitLens4D.IDE.KeyBinding.pas   # SRP        — Interceptador e registrador do atalho de teclado na ToolsAPI
├── GitLens4D.IDE.Messenger.pas    # SRP        — Fachada de comunicação com a IOTAMessageServices
└── GitLens4D.Wizard.pas           # OCP + DIP  — Orquestrador central acoplado apenas a contratos

ui/
├── base.css                       # A paleta e os controles — uma folha para as cinco telas
├── diff-render.js                 # Pintura de diff, compartilhada por Diff e Histórico
├── status.html                    # Git Changes
├── diff.html                      # Diff de um arquivo
├── history.html                   # Evolução da linha
├── settings.html                  # Configurações
└── pr.html                        # Pull Request
```

O Pascal é a fonte da verdade: o estado vive nas views e é empurrado para as
páginas, que só pintam. Assim a IDE pode recriar a janela do controle a
qualquer momento (troca de desktop, redock) que o painel volta idêntico.

> A pasta `ui/` acompanha o `.bpl` e **não é opcional** — o host a procura em
> `<pasta do .bpl>\..\ui`.

---

## 📄 Licença

Este projeto é software livre licenciado sob os termos da **GNU General Public License v3.0 (GPL-3.0)** — veja o arquivo [LICENSE](LICENSE). Você pode clonar, usar e modificar o código, mas qualquer versão modificada ou derivada distribuída deve permanecer open-source, sob a mesma licença.

Criado com ☕ e Delphi por [vctamir](https://github.com/vctamir).
