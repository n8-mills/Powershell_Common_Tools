########################################################################################
# Author : Nate Mills
# Date   : 06.22.2020
# Description: 	Presents you with files available for decryption.  
#				You can only decrypt files you encrypted on that computer, on that login.
#---------------------------------------------------------------------------------------------
# Authors: 
# Date   : 
# Description: 
########################################################################################


$user = [Environment]::UserName

$autoCredsPath = 'D:\Software\PowerShell_Automation\Powershell_Tools\Auth\AutoCreds'

$options = @(Get-ChildItem $autoCredsPath -Filter $user* -Name)
$options += 'Archive'

$PSW_FILENAME = $options | Out-GridView -Title "Select File" -PassThru

If ($PSW_FILENAME -eq 'Archive') {
    $PSW_FILENAME = Get-ChildItem "$autoCredsPath\Archive" -Filter $user* -Name | Out-GridView -Title "Select File" -PassThru
    $file = "$autoCredsPath\Archive\$PSW_FILENAME"
} Else {
    $file = "$autoCredsPath\$PSW_FILENAME"
}

If ($PSW_FILENAME)
{
  $securepassword = Get-Content $file | ConvertTo-SecureString 
  $helper = New-Object system.Management.Automation.PSCredential(([Environment]::UserName), $securepassword)

  $passWord = $helper.GetNetworkCredential().Password

  Echo "___________________-=-_____________________`nFile: `n$file `ncontents: `n$passWord"
}