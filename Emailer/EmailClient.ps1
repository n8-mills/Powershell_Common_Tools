########################################################################################
# Author : Tim Mosby
# Date   : ?
# Description: 	A module to simplify emailing
#---------------------------------------------------------------------------------------------
# Authors: Nate Mills
# Date   : 6-20-2020
# Description: Included attachments and HTML toggle
########################################################################################\

<#
.SYNOPSIS
   This script is used to send status emails
.DESCRIPTION
   When provided To, From, Subject, Body and (optionally) CC, this will send the appropriate message.
.PARAMETER To
   A comma seperated list of email addresses for the TO line
.PARAMETER From
   An email addresses the message originates from.
.PARAMETER Subject
   The email subject line
.PARAMETER Body
   The text to include as the email body
.PARAMETER Cc
   A comma seperated list of email addresses for the CC line
.PARAMETER SmtpServer
   The email server that will deliver the message.   
.PARAMETER att
   The path to a file that will be attached to the email
.PARAMETER html
   A toggle to enable HTML.     
.EXAMPLE
   Basic send mail example
   SendEmail -To "foo@company.com, bar@company.com" -From "No-Reply@company.com" -Subject "Some subject" -Body "Some Body"
.EXAMPLE
   Specifying a CC and SMTPServer value:
   SendEmail -To "foo@company.com, bar@company.com" -From "No-Reply@company.com" -Subject "Some subject" -Body "Some Body" optional: -Cc "cc@company.com" -SmtpServer "mail.company.com"
#>

function Send-Email()
{
	param([Parameter(Position=0, Mandatory=$true)][string]$To = "", 
		  [Parameter(Position=1, Mandatory=$true)][string]$From = "", 
  		  [Parameter(Position=2, Mandatory=$true)][string]$Subject = "", 
		  [Parameter(Position=3, Mandatory=$true)][string]$Body = "", 
		  [Parameter(Position=4, Mandatory=$false)][string]$Cc,
		  [Parameter(Position=5, Mandatory=$false)][string]$SmtpServer = "mail.company.com",
		  [Parameter(Position=6, Mandatory=$false)][string]$att,
		  [Parameter(Position=7, Mandatory=$false)][string]$html = $false
	)
	
	try
	{	
		if($html -eq $false){
            $Body = $Body + "`r`n`r`nExecuted file: $ScriptDefinition `nRan as user: $Environment"
        }
        else {
            $Body = $Body + "<P>Executed file: $ScriptDefinition <BR>Ran as user: $Environment"
        }
		$smtp = New-Object net.Mail.SmtpClient($SmtpServer)
		$msg = New-Object net.Mail.MailMessage($From, $To, $Subject, $Body)
		if (-not [string]::IsNullOrEmpty($Cc))
		{
			$msg.cc.add($Cc)
		}
        if (-not [string]::IsNullOrEmpty($att))
        {
            $msg.Attachments.Add($att)
        }
        $msg.IsBodyHtml = $html
		$smtp.send($msg)

	}
	finally
	{	
		if($null -ne $msg)
		{
			$msg.Dispose()
		}
	}
}