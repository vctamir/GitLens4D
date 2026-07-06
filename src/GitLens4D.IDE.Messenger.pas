unit GitLens4D.IDE.Messenger;

{ ============================================================================
  GitLens4D - Exibição de Mensagens na Aba do IDE
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: encapsular toda a interação com IOTAMessageServices,
  mantendo o estado do grupo de mensagens (message group) e expondo operações
  de alto nível: exibir uma mensagem, exibir várias, e ocultar a aba.

  Comportamento:
  - ShowMessage : cria o grupo uma vez; nas demais chamadas apenas atualiza.
  (usado pelo blame em tempo real - não força foco na aba)
  - ShowMessages: sempre traz a aba ao primeiro plano.
  (usado pelo histórico - ação explícita do usuário)
  - Hide        : remove o grupo e libera a referência.
  ============================================================================ }

interface

uses
  System.Classes,
  ToolsAPI,
  GitLens4D.Interfaces;

type
  TIDEMessenger = class(TInterfacedObject, IIDEMessenger)
  private
    FMsgGroup : IOTAMessageGroup;
    FFirstShow: Boolean;
    function EnsureGroup(const ASvc: IOTAMessageServices): IOTAMessageGroup;
  public
    constructor Create;
    procedure ShowMessage(const AMessage: string);
    procedure ShowMessages(const AMessages: TStringList);
    procedure Hide;
  end;

implementation

uses
  System.SysUtils;

{ TIDEMessenger }

constructor TIDEMessenger.Create;
begin
  inherited Create;
  FFirstShow := True;
end;

function TIDEMessenger.EnsureGroup(const ASvc: IOTAMessageServices): IOTAMessageGroup;
begin
  if FMsgGroup = nil then
    FMsgGroup := ASvc.AddMessageGroup('QSGitLens4D');
  Result      := FMsgGroup;
end;

procedure TIDEMessenger.ShowMessage(const AMessage: string);
var
  Svc: IOTAMessageServices;
  Grp: IOTAMessageGroup;
begin
  if not Supports(BorlandIDEServices, IOTAMessageServices, Svc) then
    Exit;

  Grp := EnsureGroup(Svc);

  // Exibe a aba apenas na primeira vez; depois apenas atualiza o conteúdo em background
  if FFirstShow then
  begin
    Svc.ShowMessageView(Grp);
    FFirstShow := False;
  end;

  Svc.ClearMessageGroup(Grp);
  Svc.AddTitleMessage(AMessage, Grp);
end;

procedure TIDEMessenger.ShowMessages(const AMessages: TStringList);
var
  Svc: IOTAMessageServices;
  Grp: IOTAMessageGroup;
  I  : Integer;
begin
  if not Supports(BorlandIDEServices, IOTAMessageServices, Svc) then
    Exit;

  Grp := EnsureGroup(Svc);
  Svc.ClearMessageGroup(Grp);
  Svc.ShowMessageView(Grp); // sempre traz ao foco (ação explícita do usuário)

  for I := 0 to AMessages.Count - 1 do
    Svc.AddTitleMessage(AMessages[I], Grp);
end;

procedure TIDEMessenger.Hide;
var
  Svc: IOTAMessageServices;
begin
  if FMsgGroup = nil then
    Exit;
  if Supports(BorlandIDEServices, IOTAMessageServices, Svc) then
    Svc.RemoveMessageGroup(FMsgGroup);
  FMsgGroup := nil;
end;

end.
