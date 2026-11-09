# ccls na Windows

Tento dokument popisuje (1) jak ccls nainstalovat na Windows z hotového balíčku a (2) jak sestavit nový release.

## 1. Instalace z hotového balíčku

Požadavky: 64bitový Windows 10/11. Na Windows 7/8.1 může být potřeba aktualizace UCRT (KB2999226). MSYS2 ani LLVM není potřeba.

### Instalátor (doporučeno)

1. Spusťte `ccls-<verze>-windows-x64-setup.exe` (vyžaduje práva správce).
2. Ponechte zaškrtnuté **Add ccls to system PATH**, pokud chcete spouštět `ccls` odkudkoli.
3. Výchozí cesta je `C:\Program Files\ccls`. Odinstalovat lze přes *Nastavení → Aplikace* nebo `uninstall.exe`.

Po instalaci otevřete **nový** terminál a ověřte:

```powershell
ccls --version
```

### Zip (přenosná verze)

Rozbalte `ccls-<verze>-windows-x64.zip` kamkoli a používejte `bin\ccls.exe`. PATH se nemění; v editoru zadejte plnou cestu k `ccls.exe`.

### Co balíček obsahuje

```
bin\ccls.exe + potřebné DLL (libclang-cpp, libLLVM, libstdc++ ...)
lib\clang\<N>\include   vestavěné hlavičky clangu
LICENSE, README-windows.txt
```

Hlavičky clangu se najdou automaticky relativně k `bin\ccls.exe`. Jiné umístění nastavíte inicializační volbou `clang.resourceDir`.

### Použití v projektu

ccls potřebuje vědět, jak se projekt překládá:

- `compile_commands.json` v kořeni projektu (např. CMake s `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`), nebo
- soubor `.ccls` v kořeni projektu.

Standardní hlavičky a SDK (MSVC, MinGW, ...) se berou z vašeho překladače, balíček je neobsahuje. Pro MSVC projekty obvykle stačí `compile_commands.json` vygenerovaný Ninja generátorem z „Developer Command Prompt".

Příklad pro VS Code (rozšíření ccls) v `settings.json`:

```json
{ "ccls.launch.command": "C:\\Program Files\\ccls\\bin\\ccls.exe" }
```

## 2. Sestavení nového release

Všechno řeší skript `windows\build-release.ps1` na větvi `windows-build`.

### Jednorázová příprava

1. Nainstalujte [MSYS2](https://www.msys2.org/) do `C:\msys64` (jiná cesta: parametr `-Msys2Root`).
2. Naklonujte repozitář a přepněte se na větev:

   ```powershell
   git checkout windows-build
   ```

3. Doinstalujte závislosti (clang, clang-tools-extra, llvm, cmake, ninja, rapidjson, nsis v prostředí UCRT64):

   ```powershell
   powershell -ExecutionPolicy Bypass -File windows\build-release.ps1 -InstallDeps
   ```

   (první běh rovnou i sestaví release).

### Nový release

Aktualizujte zdrojáky (např. `git merge master` do `windows-build`) a spusťte:

```powershell
powershell -ExecutionPolicy Bypass -File windows\build-release.ps1 -Version 0.20261104 -Clean
```

Parametry:

| Parametr | Význam |
|---|---|
| `-Version` | Verze v názvech souborů; výchozí `git describe --tags --always` |
| `-Msys2Root` | Umístění MSYS2 (výchozí `C:\msys64`) |
| `-InstallDeps` | Nainstaluje/aktualizuje balíčky MSYS2 |
| `-Clean` | Smaže `build-windows\` před překladem |
| `-SkipInstaller` | Vytvoří jen zip, bez NSIS instalátoru |
| `-BuildDir`, `-OutDir` | Adresáře pro build (`build-windows`) a výstup (`dist`) |
| `-Jobs` | Počet paralelních úloh překladu |

Skript postupně: sestaví ccls (CMake + Ninja, gcc, Release), nainstaluje do `dist\ccls-<verze>-windows-x64\`, zkopíruje DLL (podle `ldd`) a hlavičky clangu, spustí `ccls --version` s PATH bez MSYS2 a vytvoří:

- `dist\ccls-<verze>-windows-x64.zip`
- `dist\ccls-<verze>-windows-x64-setup.exe`

### Poznámky

- Verze LLVM je dána balíčky MSYS2 (aktuálně 23.x). ccls musí s danou verzí LLVM umět pracovat; po velké aktualizaci LLVM zkontrolujte, že se zdrojáky překládají.
- Pokud `pacman` hlásí chybu 500 nebo selhání stahování, zopakujte příkaz, jde o výpadek zrcadla.
- Před vydáním vyzkoušejte instalátor na čistém Windows (bez MSYS2/LLVM) a ověřte `ccls --version` v novém terminálu.
