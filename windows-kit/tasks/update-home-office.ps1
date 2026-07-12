#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
& (Join-Path $root 'bootstrap.ps1')
& (Join-Path $root 'setup-remote-development.ps1') -SkipChromePolicy
