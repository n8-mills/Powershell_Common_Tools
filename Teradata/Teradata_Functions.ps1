########################################################################################
# Author : Nate Mills
# Date   : 08.01.2022
# Description: 	Functions that allow for uploading to or downloading from Teradata
#				Relies upon BTEQ or FLD files
#---------------------------------------------------------------------------------------------
# Authors: 
# Date   : 
# Description: 
########################################################################################

Function Download-From-TD()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $query,
        [Parameter(Mandatory=$true)] [string] $separator,
        [Parameter(Mandatory=$true)] [string] $BTEQpath,
        [Parameter(Mandatory=$true)] [string] $BTEQfile,
        [Parameter(Mandatory=$true)] [string] $TargetPath,
        [Parameter(Mandatory=$true)] [string] $TargetFile,
        [Parameter(Mandatory=$true)] [string] $server,
        [Parameter(Mandatory=$true)] [string] $creds
    )
 
    Try {

        $BTEQfile_Repl = $BTEQfile.Replace(".btq", "_repl.btq")
        $BTEQ = 'C:\Program Files\Teradata\Client\17.20\bin\BTEQ.exe'

        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): performing Find/Replace on BTEQ ""Pre"" scripts"
        #Replace date pattern with date variable and save BTQ file with the name of the file to be executed
        (get-content "$BTEQpath$BTEQfile") `
            | foreach-object {$_ -replace '{outfile}', "$TargetPath$TargetFile"} 
            | foreach-object {$_ -replace '{TD_server}', $server} ``
            | foreach-object {$_ -replace '{TD_creds}', $creds} `
            | foreach-object {$_ -replace '{qry}', $query} `
            | foreach-object {$_ -replace '{separator}', $separator} `
            | set-content "$BTEQpath$BTEQfile_Repl"
    
        #To avoid dumb BTEQ error logs
        Set-Location $BTEQpath

        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Extracting Data"
        cmd /c """${BTEQ}"" < $BTEQpath$BTEQfile_Repl"
        Remove-Item "$BTEQpath$BTEQfile_Repl"
 
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Data downloaded to '$TargetFile' Successfully!"
  }
    Catch {
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Error downloading data! :: " $_.Exception.Message
    }
}

#Uses the first row as a header
#The script tests a set of delimiters ($delimArr) to see which results in the most fields returned
#script then builds various parts of the FLD script, and inserts them into a boilerplate .FLD template via Replace
#Script then saves the FLD as another file, and executes it.  When finished, the temporary FLD is deleted so that the credentials within aren't exposed
Function Fastload-To-TD()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $FLD_path,
        [Parameter(Mandatory=$true)] [string] $FLD_file,
        [Parameter(Mandatory=$true)] [string] $file_path,
        [Parameter(Mandatory=$true)] [string] $file_name,
        [Parameter(Mandatory=$true)] [string] $TD_server,
        [Parameter(Mandatory=$true)] [string] $TD_DB,
        [Parameter(Mandatory=$true)] [string] $TD_table,
        [Parameter(Mandatory=$true)] [array] $delimArr,
        [Parameter(Mandatory=$true)] [string] $creds,
        [Parameter(Mandatory=$true)] [string] $pk = 'PK', #Your Primary Key field name
        [Parameter(Mandatory=$true)] [string] $pk_alt = 'PK_Alt' #Alternate Primary Key field name
    )
 

    #Retrieve header from flat file
    $header = Get-Content "$file_path$file_name" -First 1

    #Loop through delimiters and test to see which results in the most successful split
    #Assumption is that max split defines correct delimiter

    $biggest = 0
    For($i = 0; $i -lt $delimArr.Count; $i++){
        #Write-Output $header.Split($delimArr[$i]).Count
        #$delimArrCheck.Set_Item($delimArr[$i], $header.Split($delimArr[$i]).Count)

        If($header.Split($delimArr[$i]).Count -gt $biggest) {
            $biggest = $header.Split($delimArr[$i]).Count
            $separator = $delimArr[$i]
        }

    }

    #Split the field values into an array
    $headerFields = $header.Split($separator)
    
    $tbl_Create = ""
    $tbl_Def = ""
    $insert_pt1 = ""
    $insert_pt2 = ""
    $index = ""

    ForEach($h in $headerFields){
    
        #Last item is sometimes blank, so ignore empty values
        If($h -ne '') {
            #Build table Create
            $tbl_Create += "$h VARCHAR(255) NULL, "

            #Build table definition
            $tbl_Def += "$h (VARCHAR(255) NULL), "
    
            #Build pt 1 of the insert statement
            $insert_pt1 += "$h, "
    
            #Build pt 2 of the insert statement
            $insert_pt2 += ":$h, "
        
            #Build the "index" core
            If($h -in ($pk, $pk_alt)) {
                $index += "$h, "
            }
        }

    }

    #Handling loop closure (remove extra characters)
    $tbl_Create = $tbl_Create.Substring(0, $tbl_Create.Length - 2)
    $tbl_Def = $tbl_Def.Substring(0, $tbl_Def.Length - 2)
    $insert_pt1 = $insert_pt1.Substring(0, $insert_pt1.Length - 2)
    $insert_pt2 = $insert_pt2.Substring(0, $insert_pt2.Length - 2)
    If($index -ne '') {
        $index = "PRIMARY INDEX ($($index.Substring(0, $index.Length - 2)))"
    }

    #Wrap tbl_Create with full syntax
    $tbl_Create = "CREATE TABLE $TD_DB.$table_name
                (
                    $tbl_Create
                )
                $index"

    Try {

        $FLD_file_Repl = $FLD_file.Replace(".fld", "_repl.fld")
        $FLD_ = 'C:\Program Files\Teradata\Client\17.20\bin\fastload.exe'

        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): performing Find/Replace on FLD ""Pre"" scripts"
        #Replace date pattern with date variable and save FLD file with the name of the file to be executed
        (get-content "$FLD_path$FLD_file") `
            | foreach-object {$_ -replace '{td_server}', $TD_server} `
            | foreach-object {$_ -replace '{TD_creds}', $creds} `
            | foreach-object {$_ -replace '{separator}', $separator} `
            | foreach-object {$_ -replace '{tbl_def}', $tbl_Def} `
            | foreach-object {$_ -replace '{file_name}', "$file_path$file_name"} `
            | foreach-object {$_ -replace '{td_db}', $TD_DB} `
            | foreach-object {$_ -replace '{tbl_name}', $TD_table} `
            | foreach-object {$_ -replace '{tbl_Create}', $tbl_Create} `
            | foreach-object {$_ -replace '{err1}', "${$TD_table}Err1"} `
            | foreach-object {$_ -replace '{err2}', "${$TD_table}Err2"} `
            | foreach-object {$_ -replace '{insert_pt1}', $insert_pt1} `
            | foreach-object {$_ -replace '{insert_pt2}', $insert_pt2} `
            | set-content "$FLD_path$FLD_file_Repl"
    
        #To avoid dumb FLD_ error logs
        Set-Location $FLD_path

        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Performing Fastload"
        cmd /c """${FLD_}"" < $FLD_path$FLD_file_Repl >$TD_table.Log"
        #Remove-Item "$FLD_path$FLD_file_Repl"
 
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Fastload Complete!"
  }
    Catch {
        Write-Output "Fastload Error! :: " $_.Exception.Message
    }
}