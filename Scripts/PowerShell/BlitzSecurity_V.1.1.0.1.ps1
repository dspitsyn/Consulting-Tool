<# 
.Synopsis
	Secure configuration posture for Microsoft IIS 10
	Security check Script with low CPU usage
.DESCRIPTION
	- Logs		- Errors and audit failures form security logs last 1 hour
.Parameter
.Inputs
	n/a
.Outputs
	This file will generate output from the directory it is run in form of an html file and send mail on defined recipient(s)
.Example
    n/a
.Notes
	Created by 	: Dmitry Spitsyn
	Dated		: November 19, 2020
	OS		: Windows 2012R2
	Version 	:
		V.1.0.1.5 - new start show as warning 
		V.1.0.1.4 - determine user loged in history
.Link
#>

########## Functions
Function Get-FailureReason 
	{
	Param($FailureReason)
    Switch ($FailureReason) 
		{
        '0xC0000064' {"Konto existiert nicht"; break;}
        '0xC000006A' {"Falsches Passwort"; break;}
        '0xC000006D' {"Unbekannter Benutzername oder ungueltiges Passwort"; break;}
        '0xC000006E' {"Account restriction"; break;}
        '0xC000006F' {"Invalid logon hours"; break;}
        '0xC000015B' {"Logon type not granted"; break;}
        '0xc0000070' {"Kontobeschraenkung"; break;}
        '0xC0000071' {"Passwort abgelaufen"; break;}
        '0xC0000072' {"Account deaktiviert"; break;}
        '0xC0000133' {"Zeitunterschied bei DC"; break;}
        '0xC0000193' {"Konto abgelaufen"; break;}
        '0xC0000224' {"Passwort muss geaendert werden"; break;}
        '0xC0000234' {"Konto gesperrt"; break;}
        '0x0' {"0x0"; break;}
        default {"Other"; break;}
		}
	}
########## End Functions

########## Declaration of Variables
$objVersion = 'V.1.1.0.1'
$objStartPoint = Get-Date
$objSimpleFormattedDate	= (Get-Date -Format dddd) + ", " + (Get-Date -F "dd.MM.yyy HH:mm:ss")
$StartDate = (Get-Date).AddDays(-1)
$objLastDay = (Get-Date).AddDays(-1).ToString('dd/MM/yy HH:mm:ss tt')
$objHost = $env:computername
$objOsInfo = gwmi -class Win32_OperatingSystem -ErrorAction SilentlyContinue
$DateOfRestart = $objOsInfo.LastBootUpTime.substring(6,2) + "." + $objOsInfo.LastBootUpTime.substring(4,2) + "." +  $objOsInfo.LastBootUpTime.substring(0,4) + " " + $objOsInfo.LastBootUpTime.substring(8,2) + ":" + $objOsInfo.LastBootUpTime.substring(10,2) + ":" + $objOsInfo.LastBootUpTime.substring(12,2)
$InstalledDate = $objOsInfo.InstallDate.substring(6,2) + "." + $objOsInfo.InstallDate.substring(4,2) + "." + $objOsInfo.InstallDate.substring(0,4)
$DayOfWeekLastRestart = Get-Date($DateOfRestart) -Format dddd
$DateOfLastUpdate = (New-Object -com "Microsoft.Update.AutoUpdate").Results.LastInstallationSuccessDate
$DateOfLastUpdate = Get-Date($DateOfLastUpdate) -F "dd.MM.yyy HH:mm:ss"
If ($objOsInfo.LastBootUpTime) {$Uptime = (Get-Date) - $objOsInfo.ConvertToDateTime($objOsInfo.LastBootUpTime)}
[Environment]::CurrentDirectory = Get-Location -PSProvider FileSystem
$objHTML = $null
$Flag = 0
########## End of Variables

########## Start of HTML Document format
$objHTML= "<html>"
$objHTML+= "<head>"
$objHTML+= "<Style>"
$objHTML+= "
		table	{
			}
		td	{
			border-bottom: 1px solid #ddd; 
			text-align: left; 
			font-size: 11; 
			font-family: Arial, Verdana, Tahoma;
			}
		.label	{ 
			text-align: left; 
			font-weight: bold; 
			color: #5C5C5C; 
			font-size: 12px;
			font-family: Arial, Verdana, Tahoma;
			}
		.title	{
			text-align: left; 
			font-weight: bold; 
			color: #5C5C5C; 
			font-size:18px; 
			font-family: Arial, Verdana, Tahoma; 
			padding: 0px 0px 0px 5px; 
			border-bottom: 0px solid #DDD;
			}
		.inalogo	{
			text-align: right; 
			background-color: #FFFFFF; 
			width: 50%; 
			height: 50; 
			padding: 5px 5px 5px 5px; 
			border-bottom: 0px solid #DDD;
			}
		.titlewouline	{
			text-align: left; 
			font-weight: 700; 
			color: #5C5C5C; 
			font-size:14; 
			font-family: Arial, Verdana, Tahoma; 
			padding: 0px 0px 0px 5px;
			border-color: #BABABA;
			border-width: 0.1px;
			border-style: solid;
			border-collapse: collapse;
			}
		.MainTitle	{
			text-align: left; 
			font-family: Arial, Verdana, Tahoma; 
			font-size: 12px; color: #5C5C5C; 
			font-weight: 700;
			border-bottom: 0px;
			}
		.TitleColumns	{ 
			font-family: Arial, Verdana, Tahoma;
			font-size: 12px;
			color: #5C5C5C;
			font-weight: 700;
			background-color: #CCCCCC;
            		padding: 5px 5px 5px 5px;
			text-align: center; 
			vertical-align: middle;
			border-color: #BABABA;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.ContentTitle	{ 
			font-family: Arial, Verdana, Tahoma;
			font-size: 12px;
			color: #5C5C5C;
			font-weight: 700;
			background-color: #CCCCCC;
            		padding: 5px 5px 5px 5px;
			text-align: center; 
			vertical-align: middle;
			border-color: #BABABA;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.ContentYellow	{
			font-family: Arial, Verdana, Tahoma;
			font-size: 11px;
			color: #B50404;
			font-weight: 700;
			background-color: #FFFF00;
			border-color: #BABABA;
            		padding: 0px 0px 0px 8px;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.ContentGreen	{
			font-family: Arial, Verdana, Tahoma;
			font-size: 11px;
			color: #B50404;
			font-weight: 700;
			background-color: #00FF00;
			border-color: #BABABA;
            		padding: 0px 0px 0px 8px;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.ContentLeft	{
			font-family: Arial, Verdana, Tahoma;
			font-size: 11px;
			font-weight: 500;
			color: #000;
			background-color: #FFF;
            		padding: 0px 0px 0px 5px;
			text-align: left;
			vertical-align: middle;
			border-color: #BABABA;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.Content	{
			font-family: Arial, Verdana, Tahoma;
			font-size: 11px;
			font-weight: 500;
			color: #000;
			background-color: #FFF;
            		padding: 0px 0px 0px 0px;
			text-align: center;
			vertical-align: middle;
			border-color: #BABABA;
			border-width: 0.5px;
			border-style: solid;
			border-collapse: collapse;
			}
		.ContentM	{
			font-family: Arial, Verdana, Tahoma;
			font-size: 11px;
			font-weight: 500;
			color: #000;
			background-color: #FFF;
            		padding: 0px 0px 0px 0px;
			text-align: center;
			vertical-align: middle;
			}
		th	{
			font-family: Arial, Verdana, Tahoma;
			border-bottom: 0.5px solid #D3D3D3; 
			text-align: left;
			font-size: 11;
			}	
			"
$objHTML+= "</Style>"
$objHTML+= "</head>"
$objHTML+= "<body>"

########## SECTION::Report Title
$objHTML+=	"<table class = ""MainTitle"" height = ""50"" cellSpacing = ""0"" cellPadding = ""0"" width = ""100%"" border = ""0"">"
$objHTML+=		"<tr>"
$objHTML+=			"<td class = ""title"" width = ""50%"">Sicherheitszustand " + ([System.Net.Dns]::GetHostByName(($objHost))).Hostname + "</td>"
$objHTML+=			"<td class = ""inalogo"" width = ""50%""><img src = ""cid:Logo.png"" width = ""50"" height = ""50""></td>"
$objHTML+=		"</tr>"
$objHTML+=	"</table>"
########## SECTION::End Report Title

########## SECTION::Column Names
$objHTML+=	"<table height = ""50"" cellSpacing = ""0"" cellPadding = ""0"" width = ""100%"" border = ""0"">"
$objHTML+=		"<tr>"
$objHTML+=			"<td class = ""TitleColumns"" width = ""14%"" height = ""50"">Name</td>"
$objHTML+=			"<td class = ""TitleColumns"" width = ""7%"" height = ""50"">IST-Zustand</td>"
$objHTML+=			"<td class = ""TitleColumns"" width = ""7%"" height = ""50"">SOLL-Zustand</td>"
$objHTML+=			"<td class = ""TitleColumns"" width = ""7%"" height = ""50"">Ziel erreicht</td>"
$objHTML+=			"<td class = ""TitleColumns"" width = ""65%"" height = ""50"">Details</td>"
$objHTML+=		"</tr>"
#$objHTML+=	"</table>"
########## SECTION::End of column names

########## SECTION::Server Properties
########## SECTION: Begin Of Operating System Information		
$objHTML+=		"<tr>"
$objHTML+=			"<td class = ""titlewouline"" width = ""35%"" height = ""30"" colspan = ""4"">Web-Server: " + $objHost + "</td>"
$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"">"
$objHTML+=				"<table width = 100% border = ""0"">"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Letzter Start des Betriebsystems: </td>"
$objHTML+=					"<td>" + $DayOfWeekLastRestart + ", " + $DateOfRestart + "</td></tr>"
$objHTML+=					"<td class = ""ContentPlain"" width = ""30%"">Edition:</td>"
$objHTML+=					"<td>" + $objOsInfo.Caption + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Version des Windows-Betriebssystems:</td>"
$objHTML+=					"<td>" + $objOsInfo.Version + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Systemtyp:</td>"
$objHTML+=					"<td>" + $objOsInfo.OSArchitecture + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Anzahl von Prozesse:</td>"
$objHTML+=					"<td colspan=1>" + $objOsInfo.NumberOfProcesses + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Arbeitsspeicher (gesamt):</td>"
$objHTML+=					"<td>" + [math]::Round($objOsInfo.TotalVisibleMemorySize/1024/1024,2) + " GB</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Arbeitsspeicher (frei):</td>"
$objHTML+=					"<td>" + [math]::Round($objOsInfo.FreePhysicalMemory/1024/1024,2) + " GB</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Letzte Update installiert am:</td>"
$objHTML+=					"<td>" +  $DateOfLastUpdate + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""30%"">Report erstellt am: </td>"
$objHTML+=					"<td>" + $objSimpleFormattedDate + "</td></tr>"
$objHTML+=				"</table>"
$objHTML+=			"</td>"
$objHTML+=		"</tr>"
########## SECTION: End Of Operating System Information
########## SECTION::End Of Server properties

########## SECTION::CIS Microsoft IIS 10 Benchmark

If (([Int](Get-Date).DayOfWeek) -eq 1)
	{

	}

########## SECTION::End CIS Microsoft IIS 10 Benchmark

########## SECTION::Server new start
If($Uptime.Days -eq 0)
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Neustart des Servers</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""65%"" height = ""30"">Das Betriebssystem wurde am " +  $DayOfWeekLastRestart + ", " + $DateOfRestart + " heruntergefahren und neu gestartet.</td>"
	$objHTML+=		"</tr>"
	}
########## SECTION::Server new start | Warning

########## SECTION::Event Log System
$objLogs = Get-Eventlog System -ComputerName $objHost -Source Microsoft-Windows-Winlogon -After (Get-Date).AddHours(-1);
$Resource = @(); ForEach ($Log in $objLogs) 
	{
	If($Log.InstanceID -eq 7001) 
		{$type = "Logon"} 
	Elseif ($Log.InstanceID -eq 7002) 
		{$type = "Logoff"} 
	Else {Continue} $Resource += New-Object PSObject -Property @{Time = $Log.TimeWritten; "Event" = $type; User = (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])} | Where (($_.User -Notlike '*ina.dsn.ab') -Or ($_.User -Notlike '*ina.msm.ab') -Or ($_.User -Notlike '*sul.rbh.ab')) 
	};
IF(![string]::IsNullOrEmpty($Resource))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Windows Anmeldung</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th><b>Benutzer</b></th>"
	$objHTML+= 					"<th><b>Event</b></th>"
	$objHTML+=				"</tr>"
		Foreach ($objEvent in $Resource)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEvent.Time	+ "</td>"
			$objHTML+=			"<td>" + $objEvent.User	+ "</td>"
			$objHTML+=			"<td>" + $objEvent.Event + "</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}
########## SECTION::End Event Log Security | Warning

########## SECTION::Event Log Security | Warning | Authentification failure
If ([System.Diagnostics.EventLog]::SourceExists('4625') -eq $False) {
$fReason = Get-Eventlog -LogName Security -InstanceId 4625 -After (Get-Date).AddHours(-1) |
	Select @{Label='Time';Expression={$_.TimeGenerated.ToString('dd.MM.yyy HH:mm:ss')}},
		@{Label='UserName';Expression={$_.replacementstrings[5]}},
    		@{Label='ClientName';Expression={$_.replacementstrings[13]}},
    		@{Label='ClientAddress';Expression={$_.replacementstrings[19]}},
    		@{Label='ServerName';Expression={$_.MachineName}},
    		@{Label='FailureStatus';Expression={Get-FailureReason ($_.replacementstrings[7])}},
    		@{Label='FailureSubStatus';Expression={Get-FailureReason ($_.replacementstrings[9])}}
	}		
IF(![string]::IsNullOrEmpty($fReason))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>" + ($fReason.FailureStatus | Get-Unique) + "</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th><b>Benutzer</b></th>"
	$objHTML+= 					"<th><b>Arbeitsstationsname</b></th>"
	$objHTML+= 					"<th><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th><b>Server Name</b></th>"
	$objHTML+= 					"<th><b>Details</b></th>"
	$objHTML+=				"</tr>"
		Foreach ($objEvent in $fReason)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEvent.Time	+ "</td>"
			$objHTML+=			"<td>" + $objEvent.UserName + "</td>"
			$objHTML+=			"<td>" + $objEvent.ClientName + "</td>"
			$objHTML+=			"<td>" + $objEvent.ClientAddress + "</td>"
			$objHTML+=			"<td>" + $objEvent.ServerName + "</td>"
			$objHTML+=			"<td>" + $objEvent.FailureSubStatus + "</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}
########## SECTION::End Event Log Security | Warning
$objHTML+= "</table>"
########## SECTION::No Errors
IF ($Flag -eq 0)
	{
	$objHTML+=	"<table height = ""30"" cellSpacing = ""0"" cellPadding = ""0"" width = ""100%"" border = ""0"">"
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentGreen"" width = ""14%"" height = ""30""></b></td>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""86%"" height = ""30"">Es wurden keine Probleme festgestellt</td>"
	$objHTML+=		"</tr>"
	$objHTML+=	"</table>"
	}
########## SECTION::End No Errors

##########
########## HTML No Error - Footer
##########

##########
########## Error Footer
##########

########## SECTION::Signature
$objHTML+= "<p style = ""margin-top: 10; margin-bottom: 10""><br></p>"
$objHTML+= "<p class = ""label"">IntelliNOVA Support</p>"
########## SECTION::End Signature
$objEndPoint = Get-Date
$objElapsedTime = (($objEndPoint - $objStartPoint).TotalSeconds)
Write-Host "Duration " $objElapsedTime " sec."
########## End of HTML
$objHTML+= "</body>"
$objHTML+= "</html>"
########## Write File
$objHTML | Out-File $PSScriptRoot\"HealthReport.html"
########## End write file

########## Set HTML Object to Null
$objHTML = $null
########## SECTION::Send Mail
IF($Flag -eq 0) {$Severity = "GRUEN"} ELSE
	{
	$Severity = "GELB"
	$From = "mail.from@nobody.me"
	$To = "support@nobody.me"
	$User = "useraccount"
	$File = "D:\SCRIPTE\VERWALTUNG\PlainPwd.txt"  # secure password
	$ImagePfad = "D:\INTERN\images\Logo.png"
	$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)
	$Subject = "ELVIS-Betrieb - [" + $Severity + "] Sicherheitszustand " + $objHost
	$Body = Get-Content "D:\SCRIPTE\VERWALTUNG\HealthReport.html" -RAW 
	$SMTPServer = "mail.uni-erfurt.de"
	$att = New-Object Net.Mail.Attachment($ImagePfad)
	$att.ContentType.MediaType = "image/png"
	$att.ContentId = "Attachment"
	$SMTPPort = "25"
	Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -Attachments $ImagePfad -SmtpServer $SMTPServer -Port $SMTPPort -UseSsl -Credential (($cred))
	$att.Dispose()
	}
########## End
