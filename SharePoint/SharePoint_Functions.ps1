########################################################################################
# Author : Nate Mills
# Date   : 03.06.2023
# Description: 	Many SharePoint functions
#				Requires PnP
#---------------------------------------------------------------------------------------------
# Authors: 
# Date   : 
# Description: 
########################################################################################

Function Download-FileFromLibrary()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteUrl,
        [Parameter(Mandatory=$true)] [string] $userName,
        [Parameter(Mandatory=$true)] [SecureString] $securePW,
        [Parameter(Mandatory=$true)] [string] $SourceFile,
        [Parameter(Mandatory=$true)] [string] $TargetPath,
        [Parameter(Mandatory=$true)] [string] $TargetFile
    )
 
    Try {
        #Build credentials
        [System.Management.Automation.PSCredential]$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $securePW

        Connect-PnPOnline -Url $SiteUrl -Credentials $cred
     
        #sharepoint online powershell download file from library
        Get-PnPFile -URL $SourceFile -Path $TargetPath -Filename $TargetFile -AsFile
 
        Write-host -f Green "File '$SourceFile' Downloaded to '$TargetFile' Successfully!" $_.Exception.Message
  }
    Catch {
        write-host -f Red "Error Downloading File!" $_.Exception.Message
    }
}

Function ParseHTML($String) 
{
    $Unicode = [System.Text.Encoding]::Unicode.GetBytes($String)
    $HTML = New-Object -Com 'HTMLFile'
    if ($HTML.PSObject.Methods.Name -Contains 'IHTMLDocument2_Write') {
        $HTML.IHTMLDocument2_Write($Unicode)
    } 
    else {
        $HTML.write($Unicode)
    }
    $HTML.Close()
    $HTML
}

#Convert to flat file or SQL "Create Table" file
Function List-Convert()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteUrl,
        [Parameter(Mandatory=$true)] [string] $listTitle,
        [Parameter(Mandatory=$true)] [string] $userName,
        [Parameter(Mandatory=$true)] [SecureString] $securePW,
        [Parameter(Mandatory=$true)] [string] $outFile,
        [Parameter(Mandatory=$false)] [string] $extension, #file extension
        [Parameter(Mandatory=$false)] [string] $delim = '|'
    )

    #Switch $delim if output is SQL
    If($extension -eq 'SQL') {
        $delim = ', ' #comma and white space for readability
    }

    #Add file extension to $outfile
    $outFile = "$outFile.$extension"

    #Build credentials
    [System.Management.Automation.PSCredential]$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $securePW

    Connect-PnPOnline -Url $SiteUrl -Credentials $cred

    #Set up the context
    $ctx = Get-PnPContext
 
    $targetWeb = Get-PnPWeb
 
    # Get the list object
    $targetList = $targetWeb.Lists.GetByTitle($listTitle)
 
    #Get the Web Object
    $ctx.Load($targetList)
    $ctx.ExecuteQuery()

    Try {        
        #Loop to bypass 5000 count list threshold
        $listItems = (Get-PnPListItem -List $listTitle -Query "<View Scope='RecursiveAll'><RowLimit>5000</RowLimit></View>").FieldValues #$cquery

        $tableFields = ""
        foreach($title in $listItems[0].Keys)
        {
            If($extension -eq 'SQL') {
                $tableFields += "[$title] [nvarchar](max) NULL,"
            } ElseIf($extension -eq 'txt') {
                $tableFields += "$title$delim"
            }
        }
        
        #Remove last comma or $delim
        $tableFields = $tableFields.Substring(0, $tableFields.Length - 1) 

        #Initial creation of output
        If($extension -eq 'SQL') {
            "CREATE TABLE [dbo].[${listTitle}_Stage]($tableFields)" | Out-File -FilePath $outFile -Append 
        } ElseIf($extension -eq 'txt') {
            "$tableFields" | Out-File -FilePath $outFile -Append 
        }
        
        If($listItems) {
            foreach($listItem in $listItems)  
            {  
                $dataRow = ''
                foreach($title in $listItems[0].Keys)
                {
                    #Default "$item" value
                    $item = ''

                    #Override the default, if applicable
                    If($listItem[$title]){
                        $li = $listItem[$title].ToString()
                        If(($li -like "Microsoft.SharePoint.Client.*") -and ($li -notlike '*`[`]')){
                            If($li.Split('.')[3] -eq 'FieldUserValue') {
                                $item = -JOIN($item, $listItem[$title].LookupValue.ToString())
                            } ElseIf($li.Split('.')[3] -eq 'FieldUrlValue') {
                                $item = -JOIN($item, $listItem[$title].URL.ToString())
                            } ElseIf ($listItem[$title].LookupValue) {
                                $item = -JOIN($item, $listItem[$title].LookupValue.ToString())
                            } Else {
                                $item = -JOIN($item, '')
                            }
                        } ElseIf(($li -like "Microsoft.SharePoint.Client.*") -and ($li -like '*`[`]')){
                            If($li.Split('.')[3] -eq 'FieldUserValue') {
                                #For each person in the array
                                #Get the email value and convert to a name
                                foreach($arr_value in $listItem[$title]) {
                                    $item = -JOIN($item, $arr_value.Email.ToString().Split("@")[0].Replace(".", " ") -Replace('[^a-zA-Z ]',''))
                                    $item = -JOIN($item, "$delim")
                                }
                            } Else {
                                #Get each Lookup value in the arracy and add it to a comma-delimited string
                                foreach($arr_value in $listItem[$title]) {
                                    If ($arr_value.LookupValue) {
                                        $item = -JOIN($item, $arr_value.LookupValue.ToString())
                                    } Else {
                                        $item = -JOIN($item, '')
                                    }
                                    $item = -JOIN($item, $delim)
                                }
                            $item = $item.Substring(0, $item.Length - $($delim).Length) 
                            }
                        } ElseIf($li.Length -gt 11 -and ($li.Substring(0,11) -eq '<div class=')){
                                #Get inner text from HTML
                                $HTML = ParseHTML $li 
                                $HTMLval = @($HTML.getElementsByTagName('div')).innerText

                                
                                Try {
                                #Remove "Zero Width Space" unicode character
                                    $HTMLval = $HTMLval.Replace(([char]8203).ToString(),"")
                                }
                                Catch {
                                    #Some older values have a strange error, probably due to manual intervention.  
                                }
                                
                                $item = -JOIN($item, $HTMLval)
                        
                        } Else {
                            $item = -JOIN($item, $li)
                        }
                    }
                    #Replaces single quotes with double single quotes (single quotes will break the automation)
                    $item = $item.Replace("'", "''")

                    #Replaces Carriage Return / Line Feed combination with Line Feed only
                    $item = $item.Replace("`r`n",'`n').Replace('^\`n+', '')
                    $dataRow = -JOIN($dataRow, "'$item'$delim")
                }
                
                #Get rid of last comma / $delim
                $dataRow = $dataRow.Substring(0, $dataRow.Length - $($delim).Length) 

                #Finalize $outFile row
                If($extension -eq 'SQL') {
                    "INSERT INTO [dbo].[${listTitle}_Stage] VALUES ($dataRow)" | Out-File -FilePath $outFile -Append 
                } ElseIf($extension -eq 'txt') {
                    $dataRow | Out-File -FilePath $outFile -Append 
                }
                
            }
        } 

 
  }
    Catch {
        write-output "Error Writing File!" $_.Exception.Message
    }
}

Function Delete-List-Item()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteUrl,
        [Parameter(Mandatory=$true)] [string] $listTitle,
        [Parameter(Mandatory=$true)] [int] $itemID,
        [Parameter(Mandatory=$true)] [string] $userName,
        [Parameter(Mandatory=$true)] [SecureString] $securePW
    )
     
    #Config Parameters
    $BatchSize = 500
   
    Try {
        #Build credentials
        [System.Management.Automation.PSCredential]$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $securePW

        Connect-PnPOnline -Url $SiteUrl -Credentials $cred

        #Set up the context
        $ctx = Get-PnPContext
        $targetWeb = Get-PnPWeb
 
        # Get the list object
        $targetList = $targetWeb.Lists.GetByTitle($listTitle)

        <#
        #Get the Web Object
        $ctx.Load($targetList)
        $ctx.ExecuteQuery()
        #>

        $targetList.GetItemById($itemID).DeleteObject()

        $Ctx.ExecuteQuery()

    }
    Catch {
        write-host -f Red "Error Deleting List Items!" $_.Exception.Message
    }
}

Function Purge-List()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteUrl,
        [Parameter(Mandatory=$true)] [string] $listTitle,
        [Parameter(Mandatory=$true)] [string] $userName,
        [Parameter(Mandatory=$true)] [SecureString] $securePW
    )
     
    #Config Parameters
    $BatchSize = 500
   
    Try {
        #Setup the context
        $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $Ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($userName,$securePW)
   
        #Get the web and List
        $Web = $Ctx.Web
        $List=$web.Lists.GetByTitle($listTitle)
        $Ctx.Load($List)
        $Ctx.ExecuteQuery()
        Write-host "Total Number of Items Found in the List:"$List.ItemCount
  
        #Define CAML Query to get list items in batches
        $Query = New-Object Microsoft.SharePoint.Client.CamlQuery
        $Query.ViewXml = "<View Scope='RecursiveAll'><RowLimit Paged='TRUE'>$BatchSize</RowLimit></View>"
        
        Do {  
            #Get items from the list in batches
            $ListItems = $List.GetItems($Query)
            $Ctx.Load($ListItems)
            $Ctx.ExecuteQuery()
          
            #Exit from Loop if No items found
            If($ListItems.count -eq 0) { Break; }
  
            Write-host Deleting $($ListItems.count) Items from the List...
  
            #Loop through each item and delete
            ForEach($Item in $ListItems)
            {
                $List.GetItemById($Item.Id).DeleteObject()
            } 
            $Ctx.ExecuteQuery()
  
        } While ($True)
  
        Write-host -f Green "All Items Deleted!"
    }
    Catch {
        write-host -f Red "Error Deleting List Items!" $_.Exception.Message
    }
}

Function replaceScriptEditor()
{
    param
    (
        [Parameter(Mandatory=$true)] [PnP.Framework.PnPClientContext] $ctx,
        [Parameter(Mandatory=$true)] [string] $pageRelativeUrl,
        [Parameter(Mandatory=$true)] [string] $contentTitle,
        [Parameter(Mandatory=$true)] [string] $content,
        [Parameter(Mandatory=$true)] [int] $wpZoneOrder
    )

	$wpZoneID = "Main"

	$WebPartXml = [xml] "
	<webParts>
	  <webPart xmlns='http://schemas.microsoft.com/WebPart/v3'>
		<metaData>
		  <type name='Microsoft.SharePoint.WebPartPages.ScriptEditorWebPart, Microsoft.SharePoint, Version=16.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c' />
		  <importErrorMessage>Cannot import this Web Part.</importErrorMessage>
		</metaData>
		<data>
		  <properties>
			<property name='ExportMode' type='exportmode'>All</property>
			<property name='HelpUrl' type='string' />
			<property name='Hidden' type='bool'>False</property>
			<property name='Description' type='string'>Allows authors to insert HTML snippets or scripts.</property>
			<property name='Content' type='string'>$content</property>
			<property name='CatalogIconImageUrl' type='string' />
			<property name='Title' type='string'>$contentTitle</property>
			<property name='AllowHide' type='bool'>True</property>
			<property name='AllowMinimize' type='bool'>True</property>
			<property name='AllowZoneChange' type='bool'>True</property>
			<property name='TitleUrl' type='string' />
			<property name='ChromeType' type='chrometype'>None</property>
			<property name='AllowConnect' type='bool'>True</property>
			<property name='Width' type='unit' />
			<property name='Height' type='unit' />
			<property name='HelpMode' type='helpmode'>Navigate</property>
			<property name='AllowEdit' type='bool'>True</property>
			<property name='TitleIconImageUrl' type='string' />
			<property name='Direction' type='direction'>NotSet</property>
			<property name='AllowClose' type='bool'>True</property>
			<property name='ChromeState' type='chromestate'>Normal</property>
		  </properties>
		</data>
	  </webPart>
	</webParts>"
		
	try{		
		#Using the params, build the page url
		Write-Host "Getting the page with the webpart we are going to modify: " $pageRelativeUrl -ForegroundColor Green

		#Getting the page using the GetFileByServerRelativeURL and do the Checkout
		#After that, we need to call the executeQuery to do the actions in the site
		$page = $ctx.Web.GetFileByServerRelativeUrl($pageRelativeUrl)
		
        try {
            $page.CheckOut()
		    $ctx.ExecuteQuery()
		    Write-Host "The page is checked out" -ForegroundColor Green
        }
        catch {
		    Write-Host "The page was aleady checked out" -ForegroundColor Green
        }

		try{
		    #Get the webpart manager from the page, to handle the webparts
		    $webpartManager = $page.GetLimitedWebPartManager([Microsoft.Sharepoint.Client.WebParts.PersonalizationScope]::Shared);

		    #Load and execute the query to get the data in the webparts
		    Write-Host "Getting the webparts from the page" -ForegroundColor Green
            $ctx.load($webpartManager.webparts)
		    $ctx.ExecuteQuery();
        
            #Remove the existing Script Editor WebPart
            foreach($webPartDefinition in $webpartManager.webparts){
                $ctx.Load($webPartDefinition.WebPart.Properties)
 
                #send the request containing all operations to the server
                try{
                    $ctx.executeQuery()
                }
                catch{
                    write-host "Error: $($_.Exception.Message)" -foregroundcolor red
                }
 
                #Only change the webpart with a certain title
                if ($webPartDefinition.WebPart.Properties.FieldValues.Title -eq $contentTitle)
                {
                    try {
                        Write-Host "Deleting existing webpart." -ForegroundColor Green
                        $webPartDefinition.DeleteWebPart()
			            $ctx.executeQuery()
                    } catch {  
                        Write-Output $Error
                    }
                }
            }

		    #Import the webpart
		    Write-Host "Importing the webpart" -ForegroundColor Green
		    $wp = $webpartManager.ImportWebPart($WebPartXml.OuterXml)

		    #Add the webpart to the page
		    Write-Host "Add the webpart to the Page" -ForegroundColor Green
		    $webPartToAdd = $webpartManager.AddWebPart($wp.WebPart, $wpZoneID, $wpZoneOrder)
            
		    $ctx.Load($webPartToAdd);
		    $ctx.ExecuteQuery()
		}
		catch{
			Write-Host "Errors found:`n$_" -ForegroundColor Red

		}
		finally{
			#CheckIn the Page
			Write-Host "Checkin  the Page" -ForegroundColor Green
			$page.CheckIn("Add the User Profile WebPart", [Microsoft.SharePoint.Client.CheckinType]::MajorCheckIn)			
			$ctx.ExecuteQuery()

			Write-Host "The webpart has been added" -ForegroundColor Yellow 			
		}	

	}
	catch{
		Write-Host "Errors found:`n$_" -ForegroundColor Red
	}

}

Function Sync-To-List()
{ 
    param
    (
        [Parameter(Mandatory=$true)] [string] $SiteUrl,
        [Parameter(Mandatory=$true)] [string] $ListName,
        [Parameter(Mandatory=$true)] [string] $key,
        [Parameter(Mandatory=$true)] [string] $SPlistID,
        [Parameter(Mandatory=$true)] [string] $userName,
        [Parameter(Mandatory=$true)] [SecureString] $securePW,
        [Parameter(Mandatory=$true)] [string] $SQL,
        [Parameter(Mandatory=$true)] [string] $SQLserver,
        [Parameter(Mandatory=$true)] [System.Object] $listMapLookup, 
        [Parameter(Mandatory=$false)] [string] $flagField = 'Flag',
        [Parameter(Mandatory=$false)] [string] $emailTo = 'user@company.com'
    )
             
    #Get data that will add to and update Sharepoint's existing list items
    [System.Array]$listDataAll = Invoke-Sqlcmd -ServerInstance $SQLserver -Query $SQL
    [System.Array]$listDataNew = $listDataAll | Where-Object {($_.$($flagField) -eq 'New')}

    #Create DataTable outside of listDataAll.Count block in case manually running serially.
    #Populated table can persist between sessions if script kept open.
    $DataTable = New-Object System.Data.DataTable

    #Create and populate a data table which can be easily queried
    If($listDataAll.Count -gt 0) {
        #Get list of fields to iterate through
        $header = $listDataAll[0].psobject.Properties | Where-Object {$_.name -notmatch 'RowError|RowState|ItemArray|HasErrors|Table'} | Select Name
        $headerLoop = $header | Where-Object {$_.name -notmatch "\b$($key)\b|$($flagField)"} | Select Name

        #Populate data table with columns
        foreach($field in $header){
            [void]$DataTable.Columns.Add($field.Name, [string]) 
        }
    
        #Populate data table with rows
        $i = 0;
        while($i -ne $listDataAll.Count){

            $row = $DataTable.NewRow()
    
            foreach($field in $header){
                $row.$($field.Name) = $listDataAll[$i].$($field.Name)
            }
    
            $DataTable.Rows.Add($Row)
            $i++;
        }
    }

    ###Start "SharePoint New Items" Region
    IF($listDataNew) {

        #Create new list items, populating only titles, then harvest the new IDs created as a result, and update SQL table with those IDs
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): New items to add: $($listDataNew.Count)"

        #Starting at -1 so as to not enter the loop when there are zero new records
        $j = 0
        ForEach($keyNew in ($listDataNew | Select-Object $key, $flagField | Where-Object {($_.$($flagField) -eq 'New')}).$($key)){

            try {
                $newItem = Add-PnPListItem -List $listTitle -Values @{"Title" = $keyNew}
                Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Item #$j added: ID $keyNew"
            }
            catch {
                Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Item #$j (ID $keyNew) not added, _$" $Error
            }   

            #Get the ID produced by SharePoint for returning to SQL Server
            $newID = $newItem.Id   
        
            #Update the PowerShell array (used later in the script) with the new SharePoint ID
            $DataTable | Where-Object {($_.$($flagField) -eq 'New') -and ($_.$($key) -eq $keyNew )} | ForEach{$_.$($SPlistID) = $newID}

            #Should have been removed?  No idea why it's here.
            #Update the SQL side with the new SharePoint ID
            #Invoke-Sqlcmd -ServerInstance $SQLserver -Query "UPDATE $table SET Cur_Ind = 'y', [$SPlistID] = $newID WHERE [$key] = '$keyNew'" 

            $j++;
        } # Update List Item complete
    } ELSE {
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): No new items to add"
    }

    $DataTable[0]
    #Get list of IDs for all items to be updated in SharePoint (or completed, as in the "New" items)
    $IDlist = $DataTable | Select-Object $($SPlistID), $($flagField) | Where-Object {($_.$($flagField) -in 'Current', 'New')} | Select-Object $($SPlistID) -Unique

    #There will be two rows for each ID, one "Current" data row, and one "Update" row
    #This Nested loop will:
    #                    - Outer: Loop through each ID (i.e. each pair of rows)
    #                    - Inner: Loop through field and compare the field between each row for differences
    #                             If a difference is found, upload the changed value to SharePoint
    foreach($IDnum in $IDlist){
        
        #Strip header from ID value
        $ID = $IDnum.$($SPlistID)    
        
        #Get the Key # (this is only for writing a line to the log)
        $txtKey = ($DataTable | Select-Object * | Where-Object {($_.$($SPlistID) -eq $ID) -and ($_.$($flagField) -in 'Update', 'New')} | Select $key).$($key)
        Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Reviewing $($ListName) $($key)# '$txtKey' for updates."
    
        #Skip updating if $ID = 0 (Updates have nowhere to land because no SP Item ID is zero)
        If($ID -eq 0){
            #Should not be the case, ID should have been assigned for any new items
            Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Skipping updates for $($ListName) $($key) # '$txtKey', IDs = zero."
        }
        ELSE {
            #This loop goes through all the mapped fields that were extracted from SQL
            foreach($field in ($headerLoop | Where {$_.Name -ne 'ID'}).Name){
            
                $curVal = ($DataTable | Select-Object * | Where-Object {($_.$($SPlistID) -eq $ID) -and ($_.$($flagField) -in 'Current')} | Select $field).$($field)
                $updVal = ($DataTable | Select-Object * | Where-Object {($_.$($SPlistID) -eq $ID) -and ($_.$($flagField) -in 'Update', 'New')} | Select $field).$($field)
                                
                #Overwrite "null" values to SharePoint-accepted "blanks"
                If(($updVal -eq $Null)){$updVal = ''}
                
                #Get List field name based on TVF/View field
                $listField = $listMapLookup["[$field]"]
                
                If (!$listField) {
                    Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): **ERROR** No ""listField"" value found in listMapLookup[field] where field = [$field]"
                }
                #Only attempt to update the field if the value is different and if is not the "Title" or "ID" field
                ElseIf (($curVal -ne $updVal)){
        
                    Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): $listField value in SP: $curVal, Source value: $updVal"
            
                    Try {
                        #Set the SharePoint list value and void the output so it doesn't land in the log
                        [void](Set-PnPListItem -Identity $ID -List $listTitle -Values @{$listField=$updVal} -UpdateType UpdateOverwriteVersion -ErrorAction Stop)
                    
                        If($($_.Exception.Message)) {
                            Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Testing $_.Exception.Message: '$($_.Exception.Message)'"
                        }
                    }
                    catch 
                    {    
                        $ErrorMessage = $_.Exception.Message
                        $FailedItem = $_.Exception.ItemName

                        If($updVal.GetType().Name -eq 'String') {
                            If($updVal.Trim() -ne '') {
                                #Many "empty" values fail to write, this isn't noteworthy and need not be logged
                                Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Unable to execute 'Set-PnPListItem -Identity $ID -List $listTitle -Values @{$listField=$updVal} -UpdateType UpdateOverwriteVersion"
                                Write-Output $_.Exception
                            }
                        } Else {
                            Write-Output "$(Get-Date -Format yyyy-MM-dd.hh:mm:ss): Unable to write value '$updVal' to the '$field' field of the '$listTitle' list: $ErrorMessage ($FailedItem)"
                            Write-Output $_.Exception
                        }
                    } #try/catch
                } #If (($curVal -ne $updVal))
            } #foreach($field in ($headerLoop | Where {$_.Name -ne 'ID'}).Name)
        } #If($ID -eq 0)/IF($ID -ne 0)
    }
}

#Some sample function call scripts

<#
$userName = 'fname.lname@company.com'
$securePW = convertto-securestring 'yourP@ss!' -asplaintext -force
#>

<#
$SiteURL="https://company.sharepoint.com/sites/accountingPerhaps/"
$TargetFile="D:\Software\PowerShell_Automation\Out-Files\projects_07142021.SQL"


List-To-SQL-Insert -SiteUrl $SiteURL `
                    -listTitle projects `
                    -userName $userName`
                    -securePW $securePW `
                    -SQLoutFile $TargetFile
#>

<#
$SiteURL = "https://company.sharepoint.com/teams/accountingPerhaps/Resources_Home/"
$SourceFile = "/teams/accountingPerhaps/Resources_Home/Shared%20Documents/Production%20Issues/Complaints.xlsx"  #Relative URL
$TargetFile = "D:\Software\PowerShell_Automation\PowerShell_Job_Scripts\Project_Pipeline\Complaints\Working\Complaints.xlsx"

#Call the function to download file 
Download-FileFromLibrary -SiteURL $SiteURL `
                         -SourceFile $SourceFile `
                         -TargetFile $TargetFile `
                         -userName $userName `
                         -securePW $securePW

#>

<#
$SiteURL = "https://company.sharepoint.com/teams/accountingPerhaps/Resources_Home/"
$SourceFile = "/teams/accountingPerhaps/Resources_Home/Shared%20Documents/Production%20Issues/Complaints.xlsx"  #Relative URL
$TargetFile = "D:\Software\PowerShell_Automation\PowerShell_Job_Scripts\Project_Pipeline\Complaints\Working\Complaints.xlsx"

#Function calls
Purge-List -SiteURL $SiteURL `
           -ListTitle 'Test_List' `
            -userName $userName `
            -securePW $securePW

Delete-List-Item -SiteURL $SiteURL `
                 -ListTitle 'Test_List' `
                 -userName $userName `
                 -securePW $securePW `
                 -itemID 1
#>