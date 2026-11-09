ccls for Windows (x64)
======================

Installer: run ccls-<version>-windows-x64-setup.exe (optionally adds ccls to PATH).
Zip:       unpack anywhere and use bin\ccls.exe.

The Clang builtin headers are bundled in lib\clang\<N>\include and are found
automatically relative to bin\ccls.exe. Override with the initialization
option clang.resourceDir if needed.

Create compile_commands.json (e.g. CMake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON)
or a .ccls file in your project root. Standard library / SDK headers come from
your own compiler setup (MSVC, MinGW...); they are not bundled.
