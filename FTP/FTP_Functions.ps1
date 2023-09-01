########################################################################################
# Author : Timothy Mosby
# Date   : 04/09/2013
# Description: 	This script is intended to be a commodity piece that can be reused in order to 
#   retrieve content from the external hosted system.
#---------------------------------------------------------------------------------------------
# Authors: Nate Mills
# Date: 12.13.2019
# Description: Implemented credential_Array function
#---------------------------------------------------------------------------------------------
# Authors: Nate Mills
# Date: 6.22.2020
# Description: Implemented Cred-Get and Cred-Decr functions to allow any user to run FTP functions
#              if they have created credential.secure files
#---------------------------------------------------------------------------------------------
# Authors: 
# Date: 
# Description: 
########################################################################################

<#
.SYNOPSIS
   This script is to be used in order to connect to FTP resources and send or retrieve content
.DESCRIPTION
   To use this script, call the FTP_Get or FTP_Put function with required parameters.
.PARAMETER sourceFolder
   The folder to get files from on the FTP server.  Ex: "/d:/FTPROOT/company/Audits/"
#>

function Credential-Array()
{  
	param([Parameter(Position=0, Mandatory=$true)][string]$party)
    Credential_Array -party = $party
}

function Credential_Array()
{  
	param([Parameter(Position=0, Mandatory=$true)][string]$party)

    $credsAll = @()
    
    $credsFile = Cred-Get -system $party -saUser "SA"
    $creds = Cred-Decr -PSW_FILENAME $credsFile -autoCred $true
    $credsPW = $creds.Split(',')[1]
    $credsFP = $creds.Split(',')[2]

    if ($party -eq "KnownFTPrecipient")
    {

        $credsAll += "address.org"
        $credsAll += "ftpName"
        $credsAll += $credsPW
        $credsAll += $credsFP
    }
    else
    {
        $credsAll += "unknown"
        $credsAll += "unknown"
        $credsAll += "unknown"
        $credsAll += "unknown"
    }

  return ,$credsAll
}

#Region Main Script/Function
#alias function in case of common typo
function FTP-Get()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$party,
        [Parameter(Position=1, Mandatory=$true)][string]$sourceFolder,
		[Parameter(Position=5, Mandatory=$false)][string]$fileName,
		[Parameter(Position=4, Mandatory=$true)][string]$destination,
		[Parameter(Position=2, Mandatory=$false)][bool]$remove = $false,
		[Parameter(Position=3, Mandatory=$false)][string]$sourceArchive,
		[Parameter(Position=6, Mandatory=$false)][string]$transferMode = "Binary")

    FTP_Get -party $party `
            -sourceFolder $sourceFolder `
            -destination $destination `
            -remove $remove `
            -sourceArchive $sourceArchive `
            -fileName $fileName `
            -transferMode = $transferMode

}

#Region Main Script/Function
function FTP_Get()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$party,
        [Parameter(Position=1, Mandatory=$true)][string]$sourceFolder,
		[Parameter(Position=5, Mandatory=$false)][string]$fileName,
		[Parameter(Position=4, Mandatory=$true)][string]$destination,
		[Parameter(Position=2, Mandatory=$false)][bool]$remove = $false,
		[Parameter(Position=3, Mandatory=$false)][string]$sourceArchive,
		[Parameter(Position=6, Mandatory=$false)][string]$transferMode = "Binary"
	)			
	<# Examples of FTP connection values
		$sourceFolder = "/d:/FTPROOT/company/Audits/"
		$sourceArchive = "/d:/FTPROOT/company/Audits/Archive/"
		$destination = "\\company.org\public\Accounting\"
	#>
    
    $a = credential_Array $party
    
    write-output "FTP Access: $($a[0])"
    write-output 'Login: {--redacted--}' #$a[1]
    write-output 'Password: {--redacted--}' #$a[2]
    write-output 'Fingerprint: {--redacted--}' #$a[3]

    if ($a[0] -eq "Unknown") 
    {
        write-output "External FTP party unknown"
        exit
    }
    elseif ((test-path $destination) -eq $false)
    {
        write-output "FTP_get destination $destination unknown"
        exit
    }
    else
    {
        try
        {
            # Load WinSCP .NET assembly
            Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
 
            # Setup session options
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Sftp
                HostName = $a[0]
                UserName = $a[1]
                Password = $a[2]
                SshHostKeyFingerprint = $a[3]
            }
 
            $sessionOptions.AddRawSettings("ConsiderDST", 2) # parameter "2" means retain source date/time "modified" stamp 
            $session = New-Object WinSCP.Session
 
            try
            {
                # Connect
                $session.Open($sessionOptions)

                 # Set options
                $transferOptions = New-Object WinSCP.TransferOptions
                $transferOptions.TransferMode = [WinSCP.TransferMode]::$transferMode
                
                #If a file name or pattern is specified, transfer that/those files
                if($fileName){
                    $fullFile = "$sourceFolder/$fileName"
                    Write-Output $fullFile

                    #If archiving at source, get a copy first and move the original file to archive      
                    Write-Output "If(sourceArchive): $sourceArchive"
                    If($sourceArchive)
                    {
                        Write-Host "Case 1: Transferring $fullFile"
					    # Make a copy
					    $transferResult =
						    $session.GetFiles($fullFile, $destination, $remove, $transferOptions)
                                
                        Write-Host "Archive $fullFile to"
					    # Archive at source
					    $transferResult =
						    $session.MoveFile($fullFile, $sourceArchive)
                    }
                    else 
                    {
					    # If not archiving at source, move the file then remove according to "$remove" variable (leave in place or delete)
                        Write-Host "fullFile: $fullFile"
                        Write-Host "destination: $destination"
                        Write-Host "remove: $remove"
                        Write-Host "transferOptions: $transferOptions"
					    $transferResult =
						    $session.GetFiles($fullFile, $destination, $remove, $transferOptions)
                                
                    }
                }
                else #otherwise, transfer everything in that folder
                {
                
                    $directory = $session.ListDirectory($sourceFolder)
                    foreach ($fileInfo in $directory.Files)
                    {
                        #Gather info to determine if file will be transferred
                        $fullFile = "$sourceFolder/" + $fileInfo.Name
                        Write-Output $fullFile

			            If($fileInfo.Name.length -lt 4) {
				            write-output $fileInfo.Name + " could not be evaluated due to lack of file extension and short file name.  Will be bypassed."
			            }
			            Else {
                            if($fileInfo.IsDirectory -eq $false)
                            {
                            
                                #If archiving at source, get a copy first and move the original file to archive                        
                                If($sourceArchive)
                                {
                                    Write-Host "Case 2: Transferring $fullFile"
					                # Make a copy
					                $transferResult =
						                $session.GetFiles($fullFile, $destination, $false, $transferOptions)
                                
                                    Write-Host "Archive $fullFile to"
					                # Archive at source
                                    if ($session.FileExists($sourceArchive + $fileInfo.Name)) {
                                        Write-Host "Archive $sourceArchive" + $fileInfo.Name + " exists, overwriting"
                                        $session.RemoveFiles($sourceArchive + $fileInfo.Name)
                                    }
					                $transferResult = $session.MoveFile($fullFile, $sourceArchive)
                                }
                                else 
                                {
                                    Write-Host "Transferring $fullFile, deleting after transfer"
					                # If not archiving at source, move the file then remove
					                $transferResult =
						                $session.GetFiles($fullFile, $destination, $remove, $transferOptions)
                                
                                }
				            }
                        }
                    }
                }
            }
            finally
            {
                # Disconnect, clean up
                Write-Output "Disposing Session"
                $session.Dispose()
            }
 
            #exit 0
        }
        catch
        {
    	    Write-Output "File Transfer Failed, Error: $($_.Exception.Message)"
        }
    }
}
#Endregion

#Region Main Script/Function
#alias function in case of common typo
function FTP-Put()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$party,
        [Parameter(Position=1, Mandatory=$true)][string]$sourceFile,
		[Parameter(Position=2, Mandatory=$true)][string]$destination,
		[Parameter(Position=3, Mandatory=$false)][bool]$remove = $true,
		[Parameter(Position=4, Mandatory=$false)][string]$transferMode = "ASCII"
	)

    FTP_Put -party $party `
            -sourceFile $sourceFile `
            -destination $destination `
            -remove $remove `
            -sourceArchive $transferMode

}

function FTP_Put()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$party,
        [Parameter(Position=1, Mandatory=$true)][string]$sourceFile,
		[Parameter(Position=2, Mandatory=$true)][string]$destination,
		[Parameter(Position=3, Mandatory=$false)][bool]$remove = $true,
		[Parameter(Position=4, Mandatory=$false)][string]$transferMode = "ASCII"
	)
    
    # get external FTP credential
    $a = credential_Array $party

    if ($a[0] -eq "Unknown") 
    {
        write-output "External FTP party unknown"
    }
    else
    {
        try
        {
            # Load WinSCP .NET assembly
            Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
            if($party -eq "partyWithPort")
            {
            # Setup session options
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Sftp
                HostName = $a[0]
                PortNumber = $a[4]
                UserName = $a[1]
                Password = $a[2]
                SshHostKeyFingerprint = $a[3]
                }
            }

            elseif($party -ne "partyWithPort")
            {
            # Setup session options
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Sftp
                HostName = $a[0]
                UserName = $a[1]
                Password = $a[2]
                SshHostKeyFingerprint = $a[3]
                }
            }


            $sessionOptions.AddRawSettings("ConsiderDST", 2) # parameter "2" means retain source date/time "modified" stamp 
            $session = New-Object WinSCP.Session

            try
            {

                # Connect
                $session.Open($sessionOptions)

                    # Upload files
                $transferOptions = New-Object WinSCP.TransferOptions
                $transferOptions.TransferMode = [WinSCP.TransferMode]::$transferMode
               
              
                Write-Output "Attempting $sourceFile, destination = $destination, ""remove"" variable = $remove, transferOptions = $transferOptions"
                if($party -eq "partyWithPort")
                {
                $transferResult = $session.PutFiles($sourceFile, $destination, $remove)
                }
                elseif($party -ne "partyWithPort")
                {
                $transferResult = $session.PutFiles($sourceFile, $destination, $remove, $transferOptions)
                }
                Write-Output $transferResult
            }
            finally
            {
                # Disconnect, clean up
                Write-Output "Disposing FTP Session"
                $session.Dispose()
            }
        }
        catch
        {
            Write-Output "File Transfer Failed, Error: $($_.Exception.Message)"
            Write-Output "options: $($sessionOptions)"
            Write-Output "options: $($a[0])"
            Write-Output "options: $($a[1])"
            Write-Output "options: $($a[2])"
            Write-Output "options: $($a[3])"
            Write-Output "options: $($a[4])"
        }
    }
}
#Endregion

Function list_Dir()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$party,
        [Parameter(Position=1, Mandatory=$true)][string]$sourceFolder
	)			
	<# Examples of FTP connection values
		$sourceFolder = "/d:/FTPROOT/company/Audits/"
		$sourceArchive = "/d:/FTPROOT/company/Audits/Archive/"
		$destination = "\\company.org\public\Accounting\"
	#>
    
    $a = credential_Array $party
    
    write-output $a[0]
    write-output $a[1]
    write-output $a[2]
    write-output $a[3]

    if ($a[0] -eq "Unknown") 
    {
        write-output "External FTP party unknown"
        exit
    }
    else
    {
        try
        {
            # Load WinSCP .NET assembly
            Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
 
            # Setup session options
            $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                Protocol = [WinSCP.Protocol]::Sftp
                HostName = $a[0]
                UserName = $a[1]
                Password = $a[2]
                SshHostKeyFingerprint = $a[3]
            }
 
            $sessionOptions.AddRawSettings("ConsiderDST", 2) # parameter "2" means retain source date/time "modified" stamp 
            $session = New-Object WinSCP.Session
         
            try
            {
                # Connect
                $session.Open($sessionOptions)
                $directory = $session.ListDirectory($sourceFolder)

                foreach ($fileInfo in $directory.Files)
                {
                    if($fileInfo.IsDirectory -eq $false) {
                        <#Write-output ("$($fileInfo.Name) with size $($fileInfo.Length), " +
                            "permissions $($fileInfo.FilePermissions) and " +
                            "last modification at $($fileInfo.LastWriteTime)")#>
                        Write-output $fileInfo.Name
                    }
                }
            }
            finally
            {
                # Disconnect, clean up
                $session.Dispose()
            }
        }
        catch
        {
            Write-Output "Error: $($_.Exception.Message)"
        }
    }
}