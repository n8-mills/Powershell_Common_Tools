########################################################################################
# Authors : Nate Mills and James Stonehocker
# Date   : 06/17/2020
# Description: Credential file retrieval and decryption functions,
#              according to how the CredSecure saves them.
#---------------------------------------------------------------------------------------------
# Authors: 
# Date: 
# Description: 
########################################################################################

#Region Main Script/Function
function Cred_Get()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$system,
        [Parameter(Position=1, Mandatory=$true)][string]$saUser
	)	

    Return [String]"${env:USERNAME}_${system}_${saUser}.secure"
}

#alias function in case of common typo
function Cred-Get()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$system,
        [Parameter(Position=1, Mandatory=$true)][string]$saUser)

    Cred_Get -system $system `
              -saUser $saUser 
}

#Region Main Script/Function
function Cred_Decr()
{
    Param([Parameter(Position=0, Mandatory=$true)][string]$PSW_FILENAME
         ,[Parameter(Position=1, Mandatory=$false)][bool]$autoCred = $false
          )
    # Script to decrypt password from file $PSW_FILENAME.

    $zero=0

    #Points to AutoCreds folder if argument dictates
    If($autoCred -eq $true) {
        [String]$autoPath = '\AutoCreds'
    }

    Write-Host 
    #[String]$PSScriptRoot = 'D:\Systems\Tools\Powershell\Auth\Encrypted_Logins'

    $res=Test-Path "${PSScriptRoot}${autoPath}\${PSW_FILENAME}"
    If ($res -ne $true)
    {
      Write-Host "ERROR: File ""${PSScriptRoot}${autoPath}\${PSW_FILENAME}"" not found!"

      #Do a dived by zero to attract attention!
      $dummy = 100 / $zero
      Return "#@False"
    }
    else
    {
      $securepassword = Get-Content "${PSScriptRoot}${autoPath}\${PSW_FILENAME}" | ConvertTo-SecureString 
      $helper = New-Object system.Management.Automation.PSCredential(([Environment]::UserName), $securepassword)

      [String]$passWord = $helper.GetNetworkCredential().Password
     
      Return $passWord
    }
}

#alias function in case of common typo
function Cred-Decr()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$PSW_FILENAME,
          [Parameter(Position=1, Mandatory=$false)][bool]$autoCred)

    Cred_Decr -PSW_FILENAME $PSW_FILENAME `
              -autoCred $autoCred 
}