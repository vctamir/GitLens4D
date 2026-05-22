unit GitLens4D.IDE.KeyBinding;

{ ============================================================================
  GitLens4D - Atalho de Teclado
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: registrar o binding de teclado no IDE e, quando
  acionado, notificar o wizard via callback. Não conhece lógica de negócio.
  ============================================================================ }

interface

uses
  ToolsAPI,
  System.Classes;

type
  TKeyShortcutEvent = procedure of object;

  TGitLensKeyboardBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
    FOnHistory: TKeyShortcutEvent;
    FOnStatus: TKeyShortcutEvent;
    FShortcutHist: string;
    FShortcutChanges: string;
    procedure ExecuteHistoryShortcut(const Context: IOTAKeyContext;
      KeyCode: TShortCut;
      var BindingResult: TKeyBindingResult);
    procedure ExecuteStatusShortcut(const Context: IOTAKeyContext;
      KeyCode: TShortCut;
      var BindingResult: TKeyBindingResult);
  public
    constructor Create(AOnHistory, AOnStatus: TKeyShortcutEvent; const AHist, AChanges: string);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

implementation

uses
  Vcl.Menus;

{ TGitLensKeyboardBinding }

constructor TGitLensKeyboardBinding.Create(AOnHistory, AOnStatus: TKeyShortcutEvent; const AHist, AChanges: string);
begin
  inherited Create;
  FOnHistory := AOnHistory;
  FOnStatus  := AOnStatus;
  FShortcutHist := AHist;
  FShortcutChanges := AChanges;
end;

function TGitLensKeyboardBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TGitLensKeyboardBinding.GetDisplayName: string;
begin
  Result := 'QSGitLens4D Atalhos';
end;

function TGitLensKeyboardBinding.GetName: string;
begin
  Result := 'vcTamir.QSGitLens.Keyboard';
end;

procedure TGitLensKeyboardBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
var
  LSHist, LSChanges: TShortcut;
begin
  if FShortcutHist <> '' then
  begin
    LSHist := TextToShortCut(FShortcutHist);
    if LSHist <> 0 then
      BindingServices.AddKeyBinding([LSHist], ExecuteHistoryShortcut, nil);
  end;

  if FShortcutChanges <> '' then
  begin
    LSChanges := TextToShortCut(FShortcutChanges);
    if LSChanges <> 0 then
      BindingServices.AddKeyBinding([LSChanges], ExecuteStatusShortcut, nil);
  end;
end;

procedure TGitLensKeyboardBinding.ExecuteHistoryShortcut(
  const Context: IOTAKeyContext; KeyCode: TShortCut;
  var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(FOnHistory) then
    FOnHistory;
end;

procedure TGitLensKeyboardBinding.ExecuteStatusShortcut(
  const Context: IOTAKeyContext; KeyCode: TShortCut;
  var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(FOnStatus) then
    FOnStatus;
end;

end.
