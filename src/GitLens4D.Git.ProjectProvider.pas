unit GitLens4D.Git.ProjectProvider;

{ ============================================================================
  GitLens4D - Provedor de Metadados do Projeto Delphi
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: Interagir com a Open Tools API (OTA) para extrair
  informações do projeto ativo (Nome, Versão).
  Centraliza a lógica complexa de fallbacks para o Delphi Tokyo.
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.Variants,
  System.StrUtils,
  ToolsAPI,
  GitLens4D.Interfaces;

type
  TGitProjectProvider = class(TInterfacedObject, IGitProjectProvider)
  public
    function GetMetadata: TGitProjectMetadata;
  end;

implementation

{ TGitProjectProvider }

function TGitProjectProvider.GetMetadata: TGitProjectMetadata;
var
  LModSvc : IOTAModuleServices;
  LProject: IOTAProject;
begin
  Result.ProjectName := 'Unknown';
  Result.ProjectVersion := '1.0.0.0';

  if Supports(BorlandIDEServices, IOTAModuleServices, LModSvc) then
  begin
    LProject := LModSvc.GetActiveProject;
    if Assigned(LProject) then
    begin
      // Nome do Projeto
      Result.ProjectName := ExtractFileName(LProject.FileName);
      Result.ProjectName := ChangeFileExt(Result.ProjectName, '');

      // Versão do Projeto (Lógica robusta para Tokyo)
      if Assigned(LProject.ProjectOptions) then
      begin
        try
          // Tenta FileVersion direto primeiro
          Result.ProjectVersion := VarToStrDef(LProject.ProjectOptions.Values['FileVersion'], '');

          if (Result.ProjectVersion = '') or (Result.ProjectVersion = '1.0.0.0') or (Result.ProjectVersion = '0.0.0.0') then
          begin
            // Fallback 1: MajorVersion
            Result.ProjectVersion := 
              VarToStrDef(LProject.ProjectOptions.Values['MajorVersion'], '1') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['MinorVersion'], '0') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['Release'], '0') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['Build'], '0');

            // Fallback 2: VerInfo_MajorVer (Padrão ToolsAPI em algumas versões do Tokyo)
            if (Result.ProjectVersion = '1.0.0.0') or (Result.ProjectVersion = '0.0.0.0') then
            begin
              Result.ProjectVersion := 
                IfThen(VarToStrDef(LProject.ProjectOptions.Values['VerInfo_MajorVer'], '1') = '', '1', VarToStrDef(LProject.ProjectOptions.Values['VerInfo_MajorVer'], '1')) + '.' +
                IfThen(VarToStrDef(LProject.ProjectOptions.Values['VerInfo_MinorVer'], '0') = '', '0', VarToStrDef(LProject.ProjectOptions.Values['VerInfo_MinorVer'], '0')) + '.' +
                IfThen(VarToStrDef(LProject.ProjectOptions.Values['VerInfo_Release'], '0') = '', '0', VarToStrDef(LProject.ProjectOptions.Values['VerInfo_Release'], '0')) + '.' +
                IfThen(VarToStrDef(LProject.ProjectOptions.Values['VerInfo_Build'], '0') = '', '0', VarToStrDef(LProject.ProjectOptions.Values['VerInfo_Build'], '0'));
            end;
          end;
        except
          Result.ProjectVersion := '1.0.0.0';
        end;
      end;
    end;
  end;
end;

end.
