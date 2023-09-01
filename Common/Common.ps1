########################################################################################
# Author : Tim Mosby
# Date   : ?
# Description: 	A script that imports other modules to a script instance
#---------------------------------------------------------------------------------------------
# Authors: 
# Date   : 
# Description: 
########################################################################################\

<#
.SYNOPSIS
   This script will import all the other scripts that are used as commodoties.
.DESCRIPTION
   To avoid having order of loading issues, this script will load all the general scripts that are to be used, 
   thus avoiding issues where calling a function in another script leads to a no loaded error.
.EXAMPLE
   Add this line to the top of your script:
   Import-Module -Name '<Fill in Drive and Folder location>\Systems\Tools\PowerShell\Common\Common.ps1'
#>

if($null -ne $RunCount -and 0 -lt $RunCount) { exit 0 }
$RunCount = 1 

#if D: exist set and Test 
$TOOLS_BASE_DIR = 'D:\Software'
if(Test-Path -Path "D:\Software")
{
	# Set BASE_DIR to the web server location
	if(-not (Test-Path -Path $TOOLS_BASE_DIR))
	{
		throw [System.Exception] "Script directory does not exist: '$TOOLS_BASE_DIR'"
	}
}
else
{
	# Set BASE_DIR to dev system location
	$TOOLS_BASE_DIR = 'C:\Software'
	if(-not (Test-Path -Path $TOOLS_BASE_DIR))
	{
		# If dev machine does not have the base_dir use the alternate location
		$TOOLS_BASE_DIR = '<backup path>'
	}
}

$AUTOMATION_DIR = Join-Path -Path "${TOOLS_BASE_DIR}" -ChildPath "Automation"
$PS_TOOLS_DIR = Join-Path -Path "${TOOLS_BASE_DIR}" -ChildPath "PowerShell_Automation\Powershell_Tools"
$MachineName = [Environment]::MachineName
$UserName = [Environment]::UserName
$AUTH_DIR = Join-Path -Path $PS_TOOLS_DIR -ChildPath "Auth\$MachineName\$UserName"
Write-Host "Auth_Dir = $AUTH_DIR"


#Region Module Imports
#Add/remove these as needed
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\Auth\CredFuncs.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\Emailer\EmailClient.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\FTP\FTP_Functions.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\PGP\PGP_Functions.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\SharePoint\SharePoint_Functions.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\PSexcel\Excel_Functions.ps1') -Force -Verbose
Import-Module -Name (Join-Path -Path $PS_TOOLS_DIR -ChildPath '\Teradata\Teradata_Functions.ps1') -Force -Verbose
#EndRegion

#region Environment Variables
	$Environment = [system.Environment]::UserDomainName + "\" + [System.Environment]::UserName + " on " + [System.Environment]::MachineName
<# This should not be done because inner scripts will set this to a different value
	$ScriptDefinition = $SCRIPT:MyInvocation.MyCommand.Definition
	$ScriptPath = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
	$ScriptName = $SCRIPT:MyInvocation.MyCommand.Name.Split('.')[0]
#>
#endregion