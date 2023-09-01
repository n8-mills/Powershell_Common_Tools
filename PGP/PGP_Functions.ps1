########################################################################################
# Author : Nate Mills
# Date   : 01/10/2020
# Description: A script to simplify the calling of Encryption and Decryption
#---------------------------------------------------------------------------------------------
# Author : 
# Date: 
# Description: 
########################################################################################

#Region Encrypt
function Encrypt()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$KeyName,
        [Parameter(Position=1, Mandatory=$true)][string]$PassPhrase, #to prevent inclusion of a passphrase, pass "none" as the PassPhrase argument
        [Parameter(Position=2, Mandatory=$true)][string]$FileName,
		[Parameter(Position=3, Mandatory=$true)][string]$PathName
	)			
    try
    {
        #Execute the program
        $pgpExec = "$PSScriptRoot\Encrypt_Decrypt.exe"
 
        &$pgpExec "encrypt" $KeyName $PassPhrase $FileName $PathName
    }
    catch
    {

        <########################################################################################
        If error
        ########################################################################################>
    	Return "Encryption Failed, Error: $($_.Exception.Message)"
    }
}
#Endregion

#Region Decrypt
function Decrypt()
{
	param([Parameter(Position=0, Mandatory=$false)][string]$KeyName = 'user@company.com',
        [Parameter(Position=1, Mandatory=$true)][string]$PassPhrase,
        [Parameter(Position=2, Mandatory=$true)][string]$FileName,
		[Parameter(Position=3, Mandatory=$true)][string]$PathName
	)			
    try
    {
        #Execute the program
        $pgpExec = "$PSScriptRoot\Encrypt_Decrypt.exe"

        &$pgpExec "decrypt" $KeyName $PassPhrase $FileName $PathName
    }
    catch
    {

        <########################################################################################
        If error
        ########################################################################################>
    	Return "Decryption Failed, Error: $($_.Exception.Message)"
    }
}
#Endregion
