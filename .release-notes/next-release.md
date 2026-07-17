## Fix ponyup-init.ps1 corrupting the Windows user PATH

On Windows, installing ponyup added its bin directory to the user PATH but corrupted the rest of that PATH in the process. It copied every entry from the system PATH into the user PATH, duplicating them; it stopped entries that use variables such as `%USERPROFILE%` from expanding; and it could leave an empty entry behind.

The installer now adds only its bin directory and leaves the rest of the user PATH untouched.

