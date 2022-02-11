## Add Windows support

Updated the app and test code to handle Windows. Note that on Windows, only `ponyup`, `ponyc`, and `corral` are supported packages.

Instead of creating symbolic links, ponyup on Windows creates batch file shims in its bin directory (e.g. `ponyc.bat`) that call the selected versions with the given parameters.

Added a `ponyup-init.ps1` bootstrapper script and updated the README to mention it.

