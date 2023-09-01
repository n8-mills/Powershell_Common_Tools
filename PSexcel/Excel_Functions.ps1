########################################################################################
# Author: Nate Mills
# Date: 6.22.2020
# Description: Allows for reading Excel documents without having Excel installed
#              Requires the installation of PSExcel 1.0.2 (or higher)
#			   https://www.powershellgallery.com/packages/PSExcel
#---------------------------------------------------------------------------------------------
# Author: 
# Date: 
# Description: 
########################################################################################

#Create an Insert file for MS SQL Server based on an excel file and sheet (default is sheet 1)
Function XLSX-To-SQL-Insert()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $source,
        [Parameter(Mandatory=$true)] [string] $SQLoutFile,
        [Parameter(Mandatory=$true)] [string] $Staging_Table,
        [Parameter(Mandatory=$false)] [int] $sheetNum = 1
    )
    #
    import-module psexcel
	
	#Where "Primary Key" is a column that is reliably 100% populated
    $a = Import-XLSX -Path $source -Sheet $sheetNum | Where { $_.'Primary Key' -ne $null}

    #Total number of records
    $lineMax = $a.Length
    $batchSize = 300
    $batches = [MATH]::FLOOR($lineMax/$batchSize)
    $HeaderFieldsType = ""
    $HeaderFields = ""

    #Create string for the "table" portion of SQL statements
    $a[0].PSObject.Properties | foreach { 
        #For the table CREATE statement
        $HeaderFieldsType += "[$($_.Name)] VARCHAR(MAX) NULL,"

        #For the INSERT statement
        $HeaderFields += "[$($_.Name)],"
    }

    #Remove the trailing commas
    $HeaderFieldsType = $HeaderFieldsType.Substring(0, $HeaderFieldsType.Length - 1)
    $HeaderFields = $HeaderFields.Substring(0, $HeaderFields.Length - 1)

    #SQL Server has issues importing more than 1000 rows in a single INSERT statement, so break up into batches of 500 or less
    $SQLinsert = ""
    $batchCap = 0
    for ($batchNum = 0; $batchNum -le $batches; $batchNum++) {
        If($batchNum -lt $batches) {
            $batchCap += $batchSize}
        Else{
            $batchCap += $lineMax%$batchSize
        }
        
        $row = ""
        #Loop through each row
        for ($rowNum = $batchSize * $batchNum; $rowNum -le $batchCap - 1; $rowNum++)
        {
            #Loop through each field
            $fieldString = ""
            $a[$rowNum].PSObject.Properties | foreach { 
                #Wrap each field in apostrophes and delimit with a comma for the INSERT statement

                If($_.Value){
                    $fieldString += "'$($_.Value.ToString().Replace("'", '"'))',"
                } Else {
                    $fieldString += "' ',"
                }

            }

            #Drop the trailing comma for the value string, then wrap the whole thing in parenthesis a comma delimit for the row
            $row += "($($fieldString.Substring(0, $fieldString.Length - 1))), `n"
            
        }
        #Drop the trailing comma
        $SQLrows = $row.Substring(0, $row.Length - 3)
        $SQLinsert += "INSERT INTO [dbo].[$Staging_Table]($HeaderFields) VALUES $SQLrows `n" 
    }
    $SQLcreate = "CREATE TABLE [dbo].[$Staging_Table]($HeaderFieldsType)" 

    $SQLcreate | Out-File -FilePath $SQLoutFile -Append 
    $SQLinsert | Out-File -FilePath $SQLoutFile -Append 
}