#!/usr/bin/env pwsh

# ****************************************************************************
# Update to powershell v7 
# ****************************************************************************
#Write-Host "Updating powershell to v7" -ForegroundColor Green   
#winget install --id Microsoft.PowerShell --source winget
#winget upgrade --id Microsoft.PowerShell

# ****************************************************************************
# Install git
# ****************************************************************************
Write-Host "Installing git" -ForegroundColor Green   
winget install --id Git.Git -e --source winget

# ****************************************************************************
# Install herdr
# ****************************************************************************
Write-Host "Installing Herdr" -ForegroundColor Green   
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"

# ****************************************************************************
# Install lazyvim
# ****************************************************************************
if (!(Test-Path -Path $env:LOCALAPPDATA\nvim\lazyvim.json -PathType Leaf)) {
  Write-Host "Installing LazyVim" -ForegroundColor Green   
  # Install Prerequisites for lazyvim
  winget install Neovim.Neovim
  winget install sharkdp.fd
  winget install BurntSushi.ripgrep.MSVC
  winget install zig.zig
  # Install LazyVim Starter Template
  cd $env:LOCALAPPDATA
  # Backup existing configs if any
  Move-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak -ErrorAction SilentlyContinue
  Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak -ErrorAction SilentlyContinue
  # Clone the starter template
  git clone https://github.com/LazyVim/starter nvim
  # Remove the .git folder to make it your own repository
  cd nvim
  Remove-Item .git -Recurse -Force
  cd $HOME
  Write-Host "Relaunch the terminal app and run nvim" -ForegroundColor Green   
}

# ****************************************************************************
# Install $PROFILE for shell aliases and config 
# ****************************************************************************
if (!(Test-Path -Path $PROFILE)) { 
  Write-Host "Setting Profile for aliases" -ForegroundColor Green   
  New-Item -ItemType File -Path $PROFILE -Force 
  Add-Content -Path $PROFILE -Value "function jump1 { herdr --remote jump1 }"
  Add-Content -Path $PROFILE -Value "function jump2 { herdr --remote jump2 }"
  Add-Content -Path $PROFILE -Value "function control { herdr --remote control }"
  Add-Content -Path $PROFILE -Value "function vim { nvim }"
  Add-Content -Path $PROFILE -Value "function ll { Get-ChildItem -Force }"
}

