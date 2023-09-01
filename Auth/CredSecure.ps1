########################################################################################
# Author : Nate Mills
# Date   : 06.22.2020
# Description: 	A script that encrypts credentials as secure files.  
#   Oracle, Teradata, and SharePoint_List entries prompt for User ID and PW
#   All others are assumed to be FTP and therefore prompt for PW and SSH Key (User ID not stored in Credential.secure file)
#   Credential.secure files are archived to AutoCreds\Archive subfolder so that they can be restored
#   in case of accidental overwrite
#---------------------------------------------------------------------------------------------
# Authors: 
# Date   : 
# Description: 
########################################################################################

$autoCredsPath = 'D:\Software\PowerShell_Automation\Powershell_Tools\Auth\AutoCreds'

$NTID = $env:UserName

Write-Output "Your Windows NTID: $NTID"

# An array of available systems 
$systems = @()
$systems += 'Current_NT'
$systems += 'PGP_passphrase'
$systems += 'Oracle'
$systems += 'Teradata'
$systems += 'SharePoint_List'

$sys = $systems | Out-GridView -Title "Select system" -PassThru

# Yes/No to determine if the credentials will be the user's or a Service Account (so users can use either/or)
$saChoices = @()
$saChoices += 'SA'
$saChoices += 'User'

If ($sys) {

    #$delim = $delimChoices | Out-GridView -Title "Select delimiter" -PassThru
    If (($sys -eq 'PGP_passphrase') -or ($sys -eq 'Current_NT')) {
        
        $saUser = 'SA'
        $pp = Read-Host "Input the Passphrase"

        $encr_String = $pp
    } elseIf ($sys -eq 'SharePoint_List') {
        
        $saUser = $saChoices | Out-GridView -Title "Credentials for a Service Account or User?" -PassThru
        $user = Read-Host "Input the User's Email for $sys"
        $pw = Read-Host "Input the Password for $sys"

        $encr_String = "${user},${pw}"
    } elseIf (($sys -eq 'Oracle') -or ($sys -eq 'Teradata')) {
        
        $saUser = $saChoices | Out-GridView -Title "Credentials for a Service Account or User?" -PassThru
        $user = Read-Host "Input the UserName for $sys"
        $pw = Read-Host "Input the Password for $sys"

        $encr_String = "${user},${pw}"
    } else {
        
        $saUser = 'SA'
        $pw = Read-Host "Input the Password for $sys"
        $fp1 = Read-Host "Input the SSH Key Fingerprint for $sys"

        # The following handles the WinSCP "get fingerprint from clipboard" functionality 
        # and removes the first line, which is not necessary for scripted solutions

        $fp2 = ${fp1}.Split("`r`n")[1] #gets the second line only, if one exists
        If ($fp2) {
      
            $fp = $fp2
        } else {
            $fp = $fp1
        }

        # The whole value for encoding
        $encr_String = "${user},${pw},${fp}"
    }

    
    #Credential file name
    $OUT_FILENAME = "$autoCredsPath\${NTID}_${sys}_${saUser}.secure"
    
    #Credential archive file name
    $dateTime = Get-Date -Format('yyyyMMdd.HH.mm')
    $ARCHIVE_FILENAME = "$autoCredsPath\Archive\${NTID}_${sys}_${saUser}_${dateTime}.secure"
         
    #Encryption
    $secure = ConvertTo-SecureString $encr_String -force -asPlainText  
    $bytes = ConvertFrom-SecureString $secure
    
    #Archive existing file, if exists  
    If (Test-Path($OUT_FILENAME)) {
        Move-Item $OUT_FILENAME $ARCHIVE_FILENAME
    }

    #Create .secure file
    Set-Content -path $OUT_FILENAME -value $bytes

} 
else {
    Write-Output 'No system was selected.'
}