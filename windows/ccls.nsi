; NSIS installer for ccls. Built by build-release.ps1 with
;   /DVERSION=... /DSRCDIR=<staged package dir> /DOUTFILE=<setup.exe>
Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

Name "ccls ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\ccls"
InstallDirRegKey HKLM "Software\ccls" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_LICENSE "${SRCDIR}\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "ccls requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Function un.onInit
  SetRegView 64
FunctionEnd

Section "ccls (required)" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File /r "${SRCDIR}\*.*"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\ccls" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "DisplayName" "ccls ${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls" "NoRepair" 1
SectionEnd

Section "Add ccls to system PATH" SecPath
  ; PowerShell avoids NSIS string-length limits and broadcasts the change.
  ExecWait `powershell -NoProfile -ExecutionPolicy Bypass -Command "$$d='$INSTDIR\bin'; $$p=[Environment]::GetEnvironmentVariable('Path','Machine'); if(($$p -split ';') -notcontains $$d){[Environment]::SetEnvironmentVariable('Path',($$p.TrimEnd(';')+';'+$$d),'Machine')}"`
SectionEnd

Section "Uninstall"
  ExecWait `powershell -NoProfile -ExecutionPolicy Bypass -Command "$$d='$INSTDIR\bin'; $$p=[Environment]::GetEnvironmentVariable('Path','Machine'); [Environment]::SetEnvironmentVariable('Path',((($$p -split ';') | Where-Object { $$_ -and $$_ -ne $$d }) -join ';'),'Machine')"`
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "Software\ccls"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ccls"
SectionEnd

LangString DESC_Main ${LANG_ENGLISH} "ccls.exe, runtime libraries and the Clang builtin headers."
LangString DESC_Path ${LANG_ENGLISH} "Lets editors and terminals find ccls without a full path."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_Main)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPath} $(DESC_Path)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
