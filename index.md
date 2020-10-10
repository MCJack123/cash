# cash
cash is a shell for ComputerCraft that is compatible with the Bourne shell (`sh`) used in most Linux/UNIX distributions.

![image](image.png)

## Features
* Bash/sh-style command line
* Tab completion (defaulting to file names where not supported)
* Customizable prompts (including ANSI support)
* Local & environment variables
* Argument quoting
* Multiple commands on one line with semicolons
* Many built-in functions (including in-line Lua commands)
* Arithmetic expansion
* If, while, for statements
* Function support
* Shell scripting/shebangs
* Background jobs
* rc files
* Restorable history
* Job control, pausing
* Partial CCKernel2 support
* Full compatibility with CraftOS shell.lua

### Missing features
* Backtick/command substitution
* Pipes/console redirection/here documents

### TODO
* Add test boolean operators (-a, -o)
* Add case statement

## Downloading
You can download the latest version of cash from GitHub:
```
wget https://raw.githubusercontent.com/MCJack123/cash/master/cash.lua cash.lua
```

## License
This project is licensed under the MIT license. You are free to modify and redistribute cash.lua as long as the copyright notice is preserved at the top of the script.
