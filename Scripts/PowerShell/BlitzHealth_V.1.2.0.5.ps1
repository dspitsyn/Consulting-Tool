<#
.Synopsis
	Health check Script with low CPU usage
.DESCRIPTION
	This Script runs at minimal CPU usage and checks the following
	- General Server Information
	- Disk		- Space alerts on low space
	- Services	- Alerts on Problematic
	- Processes	- Top 3 by CPU
	- Memory	- Top 3 by working set
	- Pathces	- Last day installed
	- Logs		- Error and audit failures form all logs last 24 hours
.Parameter
.Inputs
	n/a
.Outputs
	This file will generate output from the directory it is run in form of an html file and send mail on defined recipient(s)
.Example
    n/a
.Notes
	Created by 	: Dmitry Spitsyn
	Dated		: September 12, 2020
	OS			: Windows 2012 R2
	Version 	:
		23.12.2020 - V.1.2.0.4 - sort / order message for error 404
		19.12.2020 - V.1.2.0.3 - sort / order message for error 405
		17.12.2020 - V.1.2.0.1 - approval pfad access to IIS-Log
		11.12.2020 - V.1.2.0.0
				 V.1.0.3.2 - determine user login history
				 V.1.0.3.1 - determine errors and warnings in event log ELVIS21
				 V.1.0.2.2 - determine installed patches
				 V.1.0.2.1 - determine not installed patches
.Link
#>

########## Functions
Function Get-MSHotfix
{ 
    $outputs = Invoke-Expression "wmic qfe list"
    $outputs = $outputs[1..($outputs.length)]

    ForEach ($output in $Outputs) {
        If ($output) {
            $output = $output -replace 'Security Update','Security-Update'
            $output = $output -replace 'NT AUTHORITY','NT-AUTHORITY'
            $output = $output -replace '\s+',' '
            $parts = $output -split ' '
            If ($parts[5] -like "*/*/*") {
                $Dateis = [datetime]::ParseExact($parts[5], '%M/%d/yyyy',[Globalization.cultureinfo]::GetCultureInfo("en-US").DateTimeFormat)
            } Else {
                $Dateis = Get-Date([DateTime][Convert]::ToInt64("$parts[5]", 16)) -Format '%M/%d/yyyy'
            }
            New-Object -Type PSObject -Property @{
                KBArticle = [string]$parts[0]
                Description = [string]$parts[2]
                HotFixID = [string]$parts[3]
                InstalledOn = Get-Date($Dateis)
            }
        }
    }
}
########## End Functions

########## Declaration of Variables
$objVersion = 'V.1.2.0.5'
$sPoint = Get-Date
$objSimpleFormattedDate	= (Get-Date -Format dddd) + ", " + (Get-Date -F "dd.MM.yyy HH:mm:ss")
$StartDate = (Get-Date).AddDays(-1)
$objLastDay = (Get-Date).AddDays(-1).ToString('dd/MM/yy HH:mm:ss tt')
$objHost = $env:computername
$objHTML = $null
$ExpertMode = 0
$Flag = 0
$objOsInfo = gwmi -class Win32_OperatingSystem
$DateOfRestart = $objOsInfo.LastBootUpTime.Substring(6,2) + "." + $objOsInfo.LastBootUpTime.Substring(4,2) + "." +  $objOsInfo.LastBootUpTime.Substring(0,4) + " " + $objOsInfo.LastBootUpTime.Substring(8,2) + ":" + $objOsInfo.LastBootUpTime.Substring(10,2) + ":" + $objOsInfo.LastBootUpTime.Substring(12,2)
$InstalledDate = $objOsInfo.InstallDate.Substring(6,2) + "." + $objOsInfo.InstallDate.Substring(4,2) + "." + $objOsInfo.InstallDate.Substring(0,4)
If ($objOsInfo.LastBootUpTime) {$Uptime = (Get-Date) - $objOsInfo.ConvertToDateTime($objOsInfo.LastBootUpTime)}
$DayOfWeekLastRestart = Get-Date($DateOfRestart) -Format dddd
$DateOfLastUpdate = (New-Object -com "Microsoft.Update.AutoUpdate").Results.LastInstallationSuccessDate
$DateOfLastUpdate = Get-Date($DateOfLastUpdate) -F "dd.MM.yyy HH:mm:ss"
$objDiskInfo = gwmi -Query "Select * From Win32_LogicalDisk Where DriveType = '3'"
$objServiceInfo = gwmi -Query "Select * From win32_service"
$objTopProcessCPU = Get-Process | Sort-Object cpu -Descending | Select -First 3
$objTopProcessMem = Get-Process | Sort-Object WorkingSet -Descending | Select -First 3
$objPatch = Get-MSHotfix | Where-Object { $_.InstalledOn -gt [DateTime]::Today.AddDays(-1)}
$objHotfixError = Get-WinEvent @{Logname = 'System'; ID = 20; ProviderName = 'Microsoft-Windows-WindowsUpdateClient'} | Select -First 1 | Where {$_.TimeCreated -gt ((Get-Date).AddDays(-1))}
$objExpiredCert = Get-ChildItem cert:\ -Recurse | Where-Object {$_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] -And $_.NotAfter -lt (Get-Date)} | Select-Object -Property FriendlyName, NotAfter | Sort NotAfter -Descending
$objToExpireCert = Get-ChildItem -Path cert: -Recurse -ExpiringInDays 30 | Sort NotAfter
$objINAExpireCert = Get-ChildItem -path Cert:\* -Recurse -ExpiringInDays 30 | Where {$_.Subject -like '*erfurt*'} | Sort NotAfter	
$objCAE21W = Get-EventLog -LogName ELVIS21 -EntryType Warning -After (Get-Date).AddDays(-7) | Where-Object {($_.InstanceId -ge 0) -And ($_.InstanceId -lt 1000)}
$objCAE21E = Get-EventLog -LogName ELVIS21 -EntryType Error -After (Get-Date).AddDays(-7) | Where-Object {($_.InstanceId -ge 0) -And ($_.InstanceId -lt 1000)}
If ($objHost -Like "*4")
	{
	$iInstance = "SULWWW"
	$IISLogPath = "D:\SICHERUNGEN\IIS.LOGS\W3SVC3\"
	}
ElseIf ($objHost -Like "*2")
	{
	$iInstance = "SULINT"
	$IISLogPath = "D:\SICHERUNGEN\IIS.LOGS\W3SVC5\"
	}
ElseIf ($objHost -Like "*1")
	{
	$iInstance = "SULACCESS1"
	$IISLogPath = "D:\SICHERUNGEN\IIS.LOGS\W3SVC6\"
	}
Else
	{
	Write-Host 'Check pfad to IIS-Log for analysis on ' + $objHost
	}
$LastIISLogDate = Get-Date -Format yyMMdd (Get-Date).AddDays(-1)
$nExtension = ".csv"
$LastLog = $iInstance + "_" + $LastIISLogDate + $nExtension
$IISLogToProve = $IISLogPath + $LastLog
$IISLogFileRaw = [System.IO.File]::ReadAllLines($IISLogToProve)
$headers = $IISLogFileRaw[3].split(" ")
$headers = $headers | Where {$_ -NotLike "#*"}
$IISLogFileCSV = Import-Csv -Delimiter " " -Header $headers -Path $IISLogToProve 
$IISLogFileCSV = $IISLogFileCSV | Where {$_.date -NotLike "#*"}
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
		padding: 0px 0px 0px 5px;
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
		border-bottom: 0px solid #ddd;
		}
	.inalogo	{
		text-align: right; 
		background-color: #FFFFFF; 
		width: 50%; 
		height: 50; 
		padding: 5px 5px 5px 5px; 
		border-bottom: 0px solid #ddd;
		}
	.titlewouline	{
		text-align: left; 
		font-weight: 700; 
		color: #5C5C5C; 
		font-size:14; 
		font-family: Arial, Verdana, Tahoma; 
		padding: 0px 0px 0px 5px;
		border-color: #8D8D8D;
		border-width: 0.5px;
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
		border-color: #8D8D8D;
		border-width: 0.5px;
		border-style: solid;
		border-collapse: collapse;
		}
	.ContentPlain	{
		font-family: Arial, Verdana, Tahoma;
		font-size: 11px;
		font-weight: 700;
		color: #000;
		background-color: #FFF;
		padding: 2px 2px 2px 2px;
		text-align: left;
		vertical-align: middle;
		border-color: #D3D3D3;
		border-collapse: collapse;
		}
	.ContentYellow	{
		font-family: Arial, Verdana, Tahoma;
		font-size: 11px;
		font-weight: 500;
		color: #000;
		background-color: #FFFF00;
		padding: 0px 0px 0px 5px;
		border-color: #8D8D8D;
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
		border-color: #8D8D8D;
		padding: 0px 0px 0px 8px;
		border-width: 1px;
		border-style: solid;
		border-collapse: collapse;
		}
	.ContentLeft	{
		font-family: Arial, Verdana, Tahoma;
		font-size: 11px;
		font-weight: 500;
		color: #000;
		background-color: #FFF;
		padding: 3px 0px 5px 5px;
		text-align: left;
		vertical-align: middle;
		border-color: #8D8D8D;
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
		border-color: #8D8D8D;
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
	.itext	{
		font-family: Arial, Verdana, Tahoma;
		font-size: 11;
		text-align: left;
		padding: 0px 0px 0px 5px;
		vertical-align: middle;
		border-color: #8D8D8D;
		border-width: 0.5px;
		border-style: solid;
		border-collapse: collapse;
		}
	th	{
		font-family: Arial, Verdana, Tahoma;
		font-size: 11;
		border-bottom: 0.5px solid #8D8D8D; 
		text-align: left;
		}
		"
$objHTML+= "</Style>"
$objHTML+= "</head>"
########## End of HTML Document format
$objHTML+= "<body>"
########## SECTION::Report Title
$objHTML+=	"<table class = ""MainTitle"" height = ""50"" cellSpacing = ""0"" cellPadding = ""0"" width = ""100%"" border = ""0"">"
$objHTML+=		"<tr>"
$objHTML+=			"<td class = ""title"" width = ""50%"">Technischer Zustand " + ([System.Net.Dns]::GetHostByName(($objHost))).Hostname + "</td>"
$objHTML+=			"<td class = ""inalogo"" width = ""50%""><img src = ""cid:IntelliNovaLogo.png"" width = ""50"" height = ""50""></td>"
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
########## SECTION::End of column names

########## SECTION::Server Properties
########## SECTION::Operating System Information
$objHTML+=		"<tr>"
$objHTML+=			"<td class = ""titlewouline"" width = ""35%"" height = ""30"" colspan = ""4"">Web-Server: " + $objHost + "</td>"
$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"">"
$objHTML+=				"<table width = 100% border = ""0"">"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Letzter Start des Betriebsystems: </td>"
$objHTML+=					"<td>" +  $DayOfWeekLastRestart + ", " + $DateOfRestart + "</td></tr>"
$objHTML+=					"<td class = ""ContentPlain"" width = ""40%"">Edition:</td>"
$objHTML+=					"<td>" + $objOsInfo.Caption + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Version des Windows-Betriebssystems:</td>"
$objHTML+=					"<td>" + $objOsInfo.Version + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Systemtyp:</td>"
$objHTML+=					"<td>" + $objOsInfo.OSArchitecture + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Anzahl von Prozesse:</td>"
$objHTML+=					"<td colspan=1>" + $objOsInfo.NumberOfProcesses + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Arbeitsspeicher (gesamt):</td>"
$objHTML+=					"<td>" + [math]::Round($objOsInfo.TotalVisibleMemorySize/1024/1024,2) + " GB</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Arbeitsspeicher (frei):</td>"
$objHTML+=					"<td>" + [math]::Round($objOsInfo.FreePhysicalMemory/1024/1024,2) + " GB</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Letzte Update installiert am:</td>"
$objHTML+=					"<td>" +  $DateOfLastUpdate + "</td></tr>"
$objHTML+=					"<tr><td class = ""ContentPlain"" width = ""40%"">Report erstellt am: </td>"
$objHTML+=					"<td>" + $objSimpleFormattedDate + "</td></tr>"
$objHTML+=				"</table>"
$objHTML+=			"</td>"
$objHTML+=		"</tr>"
########## SECTION::End Of Operating System Information
########## SECTION::End Of Server properties

########## SECTION::Server new start
If($ExpertMode -eq 0 -And $Uptime.Days -eq 0)
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
########## SECTION::End Server new start

########## SECTION::Free space
If($ExpertMode -eq 0)
	{
	ForEach ($objDisk in $objDiskInfo)
		{
		If($objDisk.FreeSpace/1024/1024/1024 -le 10)
			{
			$Flag = 1
			$objHTML+=	"<tr>"
			$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Disk Information</b></td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
			$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
			$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">Laufwerk " + $objDisk.DeviceID + "(" + $objDisk.VolumeName + ") ist " + [math]::Round($objDisk.Size/1024/1024/1024,2) + "GB Gross und hat " + [math]::Round($objDisk.FreeSpace/1024/1024/1024,2) + "GB Speicherplatz" + "</td>"
			$objHTML+=	"</tr>"
			}
		}
	}
########## SECTION::End Logical Disk Information

If ($ExpertMode -eq 0 -And ([Int](Get-Date).DayOfWeek) -eq 1)
	{
	########## SECTION::Check Uni-Erfurt Certificates that are about to expire
	If(![string]::IsNullOrEmpty($objINAExpireCert))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Zertifikate (SUL | URMZ) werden bald ungueltig</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">"
		$objHTML+=		"<table width = 100%>"
		$objHTML+=			"<tr>"
		$objHTML+=				"<th width = ""35%""><b>Details</b></th>"
		$objHTML+=				"<th width = ""35%""><b>Ausgestellt von</b></th>"
		$objHTML+=				"<th><b>Ablaufsdatum</b></th>"
		$objHTML+=			"</tr>"
			ForEach ($objCert in $objINAExpireCert)
				{
				$objHTML+=	"<tr>"
				$objHTML+=		"<td>" + $objCert.Subject + "</td>"
				$objHTML+=		"<td>" + $objCert.Issuer + "</td>"
				$objHTML+=		"<td>" + $objCert.NotAfter + "</td>"
				$objHTML+=	"</tr>"
				}
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	########## SECTION::End Certificates that are about to expire

	########## SECTION::Check Certificates that are about to expire
	If(![string]::IsNullOrEmpty($objToExpireCert))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Zertifikate (System) werden bald ungueltig</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">"
		$objHTML+=		"<table width = ""100%"">"
		$objHTML+=			"<tr>"
		$objHTML+=				"<th><b>Zertifikatsname</b></th>"
		$objHTML+=				"<th><b>Ablaufsdatum</b></th>"
		$objHTML+=			"</tr>"
			ForEach ($objCert in $objToExpireCert)
				{
				$objHTML+=	"<tr>"
				$objHTML+=		"<td width = ""30%"">" + $objCert.Subject + "</td>"
				$objHTML+=		"<td width = ""20%"">" + $objCert.NotAfter + "</td>"
				$objHTML+=	"</tr>"
				}
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	########## SECTION::End certificates that are about to expire

	########## SECTION::Check for expired certificates
	If(![string]::IsNullOrEmpty($objExpiredCert))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Uebersicht bereits ungueltige Zertifikate</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">"
		$objHTML+=		"<table width = ""100%"">"
		$objHTML+=			"<tr>"
		$objHTML+=				"<th><b>Zertifikatsname</b></th>"
		$objHTML+=				"<th><b>Ablaufsdatum</b></th>"
		$objHTML+=				"<th></th>"
		$objHTML+=			"</tr>"
			ForEach ($objCert in $objExpiredCert)
				{
				$objHTML+=	"<tr>"
				$objHTML+=		"<td width = ""30%"">" + $objCert.FriendlyName + "</td>"
				$objHTML+=		"<td width = ""20%"">" + $objCert.NotAfter + "</td>"
				$objHTML+=		"<td width = ""50%""></td>"
				$objHTML+=	"</tr>"
				}
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	########## SECTION::End Certificates Information

	########## SECTION::Event Log ELVIS21 | Warning
	$objLogSysError = Get-EventLog -LogName ELVIS21 -EntryType Warning -After (Get-Date).AddDays(-7)
	If(![string]::IsNullOrEmpty($objLogSysError))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Auswertung ELVIS21</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
		$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
		$objHTML+=		"<table width = ""100%"">"
		$objHTML+=			"<tr>"
		$objHTML+=				"<td>ELVIS-Fehler und ELVIS-Warnungen wurde innerhalb letzten 7 Tagen " + ($objCAE21W.Count + $objCAE21E.Count) + " Mal aufgetretten.</td>"
		$objHTML+=			"</tr>"
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	}

	########## SECTION::End Event Log ELVIS21 | Warning

########## SECTION::Not installed patches
If($ExpertMode -eq 0)
	{
If(![string]::IsNullOrEmpty($objHotfixError))
	{
	$Flag = 1
	$objHTML+=	"<tr>"
	$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Installationsfehler</b></td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
	$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
	$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">"
	$objHTML+=		"<table width = ""100%"">"
	$objHTML+=			"<tr>"
	$objHTML+= 				"<th><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 				"<th><b>Level</b></th>"
	$objHTML+= 				"<th><b>Details</b></th>"
	$objHTML+=			"</tr>"
		ForEach ($objPatch in $objHotfix)
			{
			$objHTML+=	"<tr>"
			$objHTML+=		"<td>" + $objHotfixError.TimeCreated + "</td>"
			$objHTML+=		"<td>" + $objHotfixError.LevelDisplayName + "</td>"
			$objHTML+=		"<td>" + $objHotfixError.Message + "</td>"
			$objHTML+=	"</tr>"
			}
	$objHTML+=		"</table>"
	$objHTML+=		"</td>"
	$objHTML+=	"</tr>"
	}
	}

########## SECTION::End not installed patches
					
########## SECTION::Services

If($ExpertMode -eq 0)
	{
	ForEach ($objService in $objServiceInfo)
		{					
		If(($objService.StartMode -eq "Auto" -Or  $objService.StartMode -like "*Delayd*") -And $objService.State -ne "Running" -And $objService.Name -ne "wuauserv" -And $objService.Name -ne "RemoteRegistry" -And $objService.Name -ne "sppsvc")
			{			
			$Flag = 1	
			$objHTML+=	"<tr>"
			$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Dienst nicht gestartet</b></td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
			$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
			$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">Service """ + $objService.Name +
							""" mit Displayname: """ + $objService.DisplayName +
							""" hat Startmodus """ + $objService.StartMode +
							""" und aktueller Status """ + $objService.State +
							""".<br>Servicepfad: " + $objService.PathName + "</td>"
			$objHTML+=	"</tr>"
			}
		}
	}

########## SECTION::End Services Information

########## SECTION::Patches

If($ExpertMode -eq 0)
	{
	$objPatch = Get-MSHotfix | Where-Object { $_.InstalledOn -gt [DateTime]::Today.AddDays(-1)}
	If(![string]::IsNullOrEmpty($objPatch))
		{
		$objHTML+=		"<tr>"
		$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Windows Updateverlauf</b></td>"
		$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""30"">Information</td>"
		$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
		$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""30""></td>"
		$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
		$objHTML+=			"<table width = ""100%"">"
		$objHTML+=				"<tr>"
		$objHTML+= 					"<th width = ""10%""><b>Installiert am</b></th>"
		$objHTML+= 					"<th width = ""10%""><b>Details</b></th>"
		$objHTML+= 					"<th width = ""10%""><b>HotFixID</b></th>"
		$objHTML+= 					"<th width = ""30%""><b>Hersteller Hinweise</b></th>"
		$objHTML+=				"</tr>"
		$objHTML+=				"<tr>"
		$objHTML+=					"<td>" + $objPatch.InstalledOn + "</td>"
		$objHTML+=					"<td>" + $objPatch.Description + "</td>"
		$objHTML+=					"<td>" + $objPatch.HotFixID + "</td>"
		$objHTML+=					"<td>" + $objPatch.KBArticle + "</td>"
		$objHTML+=				"</tr>"
		$objHTML+=			"</table>"
		$objHTML+=			"</td>"
		$objHTML+=		"</tr>"
		}
	}

########## SECTION::End Last Hotfixes

########## SECTION::IIS Log | Error 400

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '400'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (400)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""30"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""30"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""30""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = ""100%"">"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Beschreibung</b></th>"
	$objHTML+= 					"<th><b>Anmerkungen</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" +	$objEventError.date	+ " " + $objEventError.time + "</td>"
			$objHTML+=			"<td>" +	$objEventError."sc-status"	+ "</td>"
			$objHTML+=			"<td>Der Server kann die Anfrage nicht verarbeiten, weil ein clientseitiger Fehler geschehen ist (z.B. eine syntaktisch falsche Anfrage).</td>"
			$objHTML+=			"<td>" +	$objEventError."time" + " | " + $objEventError."c-ip" + " | "	+ "</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 400

########## SECTION::IIS Log | Error 401

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '401'})
#If(![string]::IsNullOrEmpty($objIISLogError))
#$Threats = $objIISLogError | Group-Object "c-ip" -NoElement | Where {$_.count -gt 10}
#If(![string]::IsNullOrEmpty($Threats))
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (401)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th><b>URL</b></th>"
	$objHTML+= 					"<th><b>Beschreibung</b></th>"
	$objHTML+=				"</tr>"
		#ForEach ($Threat in $Threats)
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td class = ""ContentM"">" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			$objHTML+=			"<td>https://" + $objEventError."cs-host" + $objEventError."cs-uri-stem" + "</td>"
				If ($objEventError."cs-method" -eq "POST")
					{
					$objHTML+=	"<td>Die angeforderte Resource erfordert eine Benutzerauthentifizierung</td>"
					}
				Else
					{
					$objHTML+=	"<td>Benutzer Agent " + $objEventError."cs(User-Agent)" + " unbekannt</td>"
					}
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 401

########## SECTION::IIS Log | Error 401

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '401'})
$Threats = $objIISLogError | Group-Object "c-ip" -NoElement | Where {$_.count -gt 10}
If(![string]::IsNullOrEmpty($Threats))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Benutzername oder Kennwort sind falsch (401)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""65%"" height = ""30"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<td>Es wurde " + $Threats.Count + " Mal von IP-Adresse " + $Threats.Name + " verdaechtige Angriffe registriert.</b></td>"
	$objHTML+=				"</tr>"
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 401

########## SECTION::IIS Log | Error 404

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '404'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (404)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th><b>URL</b></th>"
	$objHTML+= 					"<th><b>Ursache</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td>" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			$objHTML+=			"<td>" + $objEventError."cs(Referer)" + "</td>"
			$objHTML+=			"<td>Es folgen einige haeufige Ursachen fuer diese Fehlermeldung: die angeforderte Datei nicht existiert, wurde umbenannt, verschoben oder geloescht.</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 404

########## SECTION::IIS Log | Error 405

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	#$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'} | Group-Object -Property cs-uri-stem)
	$FirstTime = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'} | Group-Object -Property time).Name | Select-Object -First 1
	$LastTime = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'} | Group-Object -Property time).Name | Select-Object -Last 1
	$objIP = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'} | Group-Object -Property c-ip).Name
	$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '405'} | Group-Object -Property s-ip | Select -ExpandProperty Group).Count
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (405)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Status</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Ursache</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objIP + "</td>"
			$objHTML+=			"<td>Der Fehler ist zwischen " + $FirstTime + " und " + $LastTime + " gesamt " + $objIISLogError + " Mal aufgetretten.</td>"
			$objHTML+=			"<td>Dieses Problem tritt auf, weil der Client eine HTTP-Anforderung (Hypertext Transfer Protocol) mithilfe einer HTTP-Methode erstellt, die nicht den HTTP-Spezifikationen entspricht.</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 405

########## SECTION::IIS Log | Error 408

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '408'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (408)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Beschreibung</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td>" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			$objHTML+=			"<td>The 408 (Request Timeout) status code indicates that the server did not receive a complete request message within the time that it was prepared to wait.</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 408

########## SECTION::IIS Log | Error 409

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '409'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (409)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Beschreibung</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td class = ""ContentM"">" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			$objHTML+=			"<td>The 409 (Conflict) status code indicates that the request could not be completed due to a conflict with the current state of the target resource.</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 409

########## SECTION::IIS Log | Error 500

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '500'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (500)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th><b>URL</b></th>"
	$objHTML+= 					"<th><b>Beschreibung</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td class = ""ContentM"">" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			#$objHTML+=			"<td>" + "https://" + $objEventError."cs-host" + $objEventError."cs-uri-stem" + "</td>"
			$objHTML+=			"<td>https://" + $objEventError."cs-host" + $objEventError."cs-uri-stem" + "?" + $objEventError."cs-uri-query" + "</td>"
				If ($objEventError."sc-win32-status" -eq 64)
					{
					$objHTML+=	"<td>Der angegebene Netzwerkname ist nicht mehr verfuegbar</td>"
					}
				Else
					{
					$objHTML+=	"<td>Dieser HTTP-Statuscode kann aus vielen serverseitigen Gruenden auftreten.<br>https://support.microsoft.com/de-de/help/942031/http-error-500-0-internal-server-error-error-when-you-you-open-an-iis</td>"
					}
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 500

########## SECTION::IIS Log | Error 503

$objIISLogError = ($IISLogFileCSV | Where {$_.("sc-status") -eq '503'})
If(![string]::IsNullOrEmpty($objIISLogError))
	{
	$Flag = 1
	$objHTML+=		"<tr>"
	$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Interner Serverfehler (503)</b></td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
	$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
	$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=			"<table width = 100%>"
	$objHTML+=				"<tr>"
	$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>Eregnis-ID</b></th>"
	$objHTML+= 					"<th class = ""ContentM""><b>IP-Adresse</b></th>"
	$objHTML+= 					"<th width = ""60""><b>Beschreibung</b></th>"
	$objHTML+=				"</tr>"
		ForEach ($objEventError in $objIISLogError)
			{
			$objHTML+=		"<tr>"
			$objHTML+=			"<td>" + $objEventError.date + " " + $objEventError.time + "</td>"
			$objHTML+=			"<td class = ""ContentM"">" + $objEventError."sc-status" + "</td>"
			$objHTML+=			"<td>" + $objEventError."c-ip" + "</td>"
			#$objHTML+=			"<td> + "https://" + $objEventError."cs-host" + $objEventError."cs-uri-stem"<br> + The 503 (Service Unavailable) status code indicates that the server is currently unable to handle the request due to a temporary overload or scheduled maintenance, which will likely be alleviated after some delay.</td>"
			$objHTML+=			"<td>" + $objEventError."cs-host" + $objEventError."cs-uri-stem" + "<br>The 503 (Service Unavailable) status code indicates that the server is currently unable to handle the request due to a temporary overload or scheduled maintenance, which will likely be alleviated after some delay.</td>"
			$objHTML+=		"</tr>"
			}
	$objHTML+=			"</table>"
	$objHTML+=			"</td>"
	$objHTML+=		"</tr>"
	}

########## SECTION::End IIS Log | Error 503

If($ExpertMode -eq 0)
	{
	If (([Int](Get-Date).DayOfWeek) -ne 1)
		{
		########## SECTION::Event Log ELVIS21 | Error
		$objLogSysError = Get-EventLog -LogName ELVIS21 -EntryType Error -After (Get-Date).AddDays(-1) | Where-Object {($_.InstanceId -ge 0) -And ($_.InstanceId -lt 1000)}
		If(![string]::IsNullOrEmpty($objLogSysError))
			{
			$Flag = 1
			$objHTML+=		"<tr>"
			$objHTML+=			"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Auswertung Fehler in ELVIS21</b></td>"
			$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
			$objHTML+=			"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
			$objHTML+=			"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
			$objHTML+=			"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
			$objHTML+=			"<table width = 100%>"
			$objHTML+=				"<tr>"
			$objHTML+= 					"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
			$objHTML+= 					"<th><b>Type</b></th>"
			$objHTML+= 					"<th width = ""60""><b>Eregnis-ID</b></th>"
			$objHTML+= 					"<th><b>Quelle</b></th>"
			$objHTML+= 					"<th><b>Meldung</b></th>"
			$objHTML+=				"</tr>"
				ForEach ($objEventError in $objLogSysError)
					{
					$objHTML+=		"<tr>"
					$objHTML+=			"<td>" + $objEventError.TimeGenerated + "</td>"
					$objHTML+=			"<td>" + $objEventError.EntryType + "</td>"
					$objHTML+=			"<td class = ""ContentM"">" + $objEventError.InstanceID + "</td>"
					$objHTML+=			"<td>" + $objEventError.Source + "</td>"
					$objHTML+=			"<td>" + $objEventError.Message + "</td>"
					$objHTML+=		"</tr>"
					}
			$objHTML+=			"</table>"
			$objHTML+=			"</td>"
			$objHTML+=		"</tr>"
			}
		}
	}
	
########## SECTION::End Event Log ELVIS21 | Error

########## SECTION::Event Log System | Error

If($ExpertMode -eq 0)
	{
	If ($objHost -Like "*4" -Or $objHost -Like "*2" -Or $objHost -Like "*1")
		{
		$objLogSysError = Get-Eventlog -LogName System -EntryType Error -After (Get-Date).AddDays(-1) | Where-Object {($_.eventID -NotMatch '137|7031|36874|36887|36888|10010|10016')} | Select -First 3
		If(![string]::IsNullOrEmpty($objLogSysError))
			{
			$Flag = 1
			$objHTML+=	"<tr>"
			$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Auswertung Fehler in Ereignisanzeige (System)</b></td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
			$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
			$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
			$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
			$objHTML+=		"<table width = 100%>"
			$objHTML+=			"<tr>"
			$objHTML+= 				"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
			$objHTML+= 				"<th><b>Type</b></th>"
			$objHTML+= 				"<th width = ""60""><b>Eregnis-ID</b></th>"
			$objHTML+= 				"<th><b>Quelle</b></th>"
			$objHTML+= 				"<th><b>Meldung</b></th>"
			$objHTML+=			"</tr>"
				ForEach ($objEventError in $objLogSysError)
					{
					$objHTML+=	"<tr>"
					$objHTML+=		"<td>" + $objEventError.TimeGenerated + "</td>"
					$objHTML+=		"<td>" + $objEventError.EntryType + "</td>"
					$objHTML+=		"<td class = ""ContentM"">" + $objEventError.EventID + "</td>"
					$objHTML+=		"<td>" + $objEventError.Source + "</td>"
					$objHTML+=		"<td>" + $objEventError.Message + "</td>"
					$objHTML+=	"</tr>"
					}
			$objHTML+=		"</table>"
			$objHTML+=		"</td>"
			$objHTML+=	"</tr>"
			}
		}
	Else
		{
		Write-Host 'Check System Event-ID for errors on ' + $objHost
		}
	}

########## SECTION::End Event Log System | Error

########## SECTION::Event Log Application | Error
# EventID: 2001 Der Wert von "First Counter" unter dem Schlüssel "usbperf\Performance" kann nicht gelesen werden. Statuscodes wurden in den Daten zurückgegeben.

If($ExpertMode -eq 0)
	{
	If ($objHost -Like "*4" -Or $objHost -Like "*2")
		{
		$objLogSysError = Get-EventLog -LogName Application -EntryType Error -After (Get-Date).AddDays(-1) | Where-Object {($_.EventID -NotMatch '1008|2004|8005')} | Select -First 3
		}
	ElseIf ($objHost -Like "*1")
		{
		$objLogSysError = Get-EventLog -LogName Application -EntryType Error -After (Get-Date).AddDays(-1) | Where-Object {($_.EventID -NotMatch '257|1008|1017|1022|1023|2001|2004|3009|8005')} | Select -First 3
		}
	Else
		{
		Write-Host 'Check Application Event-ID for errors on ' + $objHost
		}
	If(![string]::IsNullOrEmpty($objLogSysError))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Auswertung Fehler in Ereignisanzeige (Anwendung)</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
		$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
		$objHTML+=		"<table width = 100%>"
		$objHTML+=			"<tr>"
		$objHTML+= 				"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
		$objHTML+= 				"<th><b>Type</b></th>"
		$objHTML+= 				"<th width = ""60""><b>Eregnis-ID</b></th>"
		$objHTML+= 				"<th><b>Quelle</b></th>"
		$objHTML+= 				"<th><b>Meldung</b></th>"
		$objHTML+=			"</tr>"
			ForEach ($objEventError in $objLogSysError)
				{
				$objHTML+=	"<tr>"
				$objHTML+=		"<td>" + $objEventError.TimeGenerated + "</td>"
				$objHTML+=		"<td>" + $objEventError.EntryType + "</td>"
				$objHTML+=		"<td class = ""ContentM"">" + $objEventError.EventID + "</td>"
				$objHTML+=		"<td>" + $objEventError.Source + "</td>"
				$objHTML+=		"<td>" + $objEventError.Message + "</td>"
				$objHTML+=	"</tr>"
				}
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	}

########## SECTION::End Event Log Application | Error

########## SECTION::Event Log Security | Warning

If($ExpertMode -eq 0)
	{
	If ($objHost -Like "*4" -Or $objHost -Like "*2")
		{
		$objLogSysError = Get-EventLog -LogName Security -EntryType FailureAudit -After (Get-Date).AddDays(-1) | Where-Object {($_.eventID -NotMatch '1008|1023|4625|4656|4673|4957|5031|5152|5157')} | Select -First 3
		}
	ElseIf ($objHost -Like "*1")
		{
		$objLogSysError = Get-EventLog -LogName Security -EntryType FailureAudit -After (Get-Date).AddDays(-1) | Where-Object {($_.eventID -NotMatch '1008|1023|4625|4656|4673|4776|4957|5031|5152|5157')} | Select -First 3
		}
	Else
		{
		Write-Host 'Check Security Event-ID for Warnings on ' + $objHost
		}
	If(![string]::IsNullOrEmpty($objLogSysError))
		{
		$Flag = 1
		$objHTML+=	"<tr>"
		$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Auswertung Fehler in Ereignisanzeige (Sicherheit)</b></td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">Warnung</td>"
		$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
		$objHTML+=		"<td class = ""ContentYellow"" width = ""7%"" height = ""50""></td>"
		$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
		$objHTML+=		"<table width = 100%>"
		$objHTML+=			"<tr>"
		$objHTML+=				"<th width = ""110""><b>Datum und Uhrzeit</b></th>"
		$objHTML+=				"<th><b>Type</b></th>"
		$objHTML+=				"<th width = ""60""><b>Eregnis-ID</b></th>"
		$objHTML+=				"<th><b>Quelle</b></th>"
		$objHTML+=				"<th><b>Meldung</b></th>"
		$objHTML+=			"</tr>"
			ForEach ($objEventError in $objLogSysError)
				{
				$objHTML+=	"<tr>"
				$objHTML+=		"<td>" + $objEventError.TimeGenerated + "</td>"
				$objHTML+=		"<td>" + $objEventError.EntryType + "</td>"
				$objHTML+=		"<td class = ""ContentM"">" +	$objEventError.EventID + "</td>"
				$objHTML+=		"<td>" + $objEventError.Source + "</td>"
				$objHTML+=		"<td>" + $objEventError.Message + "</td>"
				$objHTML+=	"</tr>"
				}
		$objHTML+=		"</table>"
		$objHTML+=		"</td>"
		$objHTML+=	"</tr>"
		}
	}

########## SECTION::End Event Log Security | Warning

If ($Flag -ne 0 -And $ExpertMode -eq 0)
	{
	########## SECTION::CPU Processe
	$objHTML+=	"<tr>"
	$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>CPU-Auslastung</b></td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">Information</td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=		"<table width = 100%>"
	$objHTML+=			"<tr>"
	$objHTML+=				"<th><b>Prozessname</b></th>"
	$objHTML+=				"<th><b>CPU</b></th>"
	$objHTML+=				"<th><b>Priority Class</b></th>"
	$objHTML+=				"<th><b>Pfad</b></th>"
	$objHTML+=			"</tr>"
		ForEach ($objProc in $objTopProcessCPU)
			{
			$objHTML+=	"<tr>"
			$objHTML+=		"<td>" + $objProc.ProcessName + "</td>"
			$objHTML+=		"<td>" + $objProc.CPU + "</td>"
			$objHTML+=		"<td align = ""center"">" + $objProc.PriorityClass + "</td>"
			$objHTML+=		"<td>" + $objProc.Path + "</td>"
			$objHTML+=	"</tr>"
			}
	$objHTML+=		"</table>"
	$objHTML+=		"</td>"
	$objHTML+=	"</tr>"

	########## SECTION::End CPU Processe

	########## SECTION::Memory Processe

	$objHTML+=	"<tr>"
	$objHTML+=		"<td class = ""ContentLeft"" width = ""14%"" height = ""30""><b>Speicherauslastung</b></td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">Information</td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=		"<td class = ""Content"" width = ""7%"" height = ""50"">-</td>"
	$objHTML+=		"<td class = ""titlewouline"" width = ""65%"" height = ""30"" colspan = ""4"">"
	$objHTML+=		"<table width = 100%>"
	$objHTML+=			"<tr>"
	$objHTML+= 				"<th><b>Prozessname</b></th>"
	$objHTML+= 				"<th><b>WorkingSet</b></th>"
	$objHTML+= 				"<th><b>PagedMemorySize</b></th>"
	$objHTML+= 				"<th><b>PagedSystemMemorySize</b></th>"
	$objHTML+= 				"<th><b>NonpagedSystemMemorySize</b></th>"
	$objHTML+=			"</tr>"
		ForEach ($objProc in $objTopProcessMem)
			{
			$objHTML+=	"<tr>"
			$objHTML+=		"<td>" + $objProc.ProcessName + "</td>"
			$objHTML+=		"<td>" + [math]::Round($objProc.WorkingSet64/1024/1024,2) + " MB</td>"
			$objHTML+=		"<td>" + [math]::Round($objProc.PagedMemorySize/1024/1024,2) + " MB</td>"
			$objHTML+=		"<td>" + [math]::Round($objProc.PagedSystemMemorySize/1024/1024,2) + " MB</td>"
			$objHTML+=		"<td>" + [math]::Round($objProc.NonpagedSystemMemorySize/1024/1024,2) + " MB</td>"
			$objHTML+=	"</tr>"
			}			
	$objHTML+=		"</table>"
	$objHTML+=		"</td>"
	$objHTML+=	"</tr>"

	########## SECTION::End Memory Processe
	}

########## SECTION::No Errors

If ($Flag -eq 0)
	{
	$objHTML+=	"<tr>"
	$objHTML+=		"<td class = ""ContentGreen"" width = ""35%"" height = ""30""></td>"
	$objHTML+=		"<td class = ""ContentLeft"" width = ""65%"" height = ""30"" colspan = ""4"">Es wurden keine technischen Probleme festgestellt</td>"
	$objHTML+=	"</tr>"
	}

########## SECTION::End No Errors

$objHTML+=	"</table>"

##########

########## HTML No Error - Footer

########## Error Footer

########## SECTION::Signature

$objHTML+= "<p style = ""margin-top: 10; margin-bottom: 10""><br></p>"
$objHTML+= "<p class = ""label"">IntelliNOVA Support</p>"

########## SECTION::End Signature
$ePoint = Get-Date
$objElapsedTime = (($ePoint - $sPoint).TotalSeconds)
Write-Host "Duration:" $objElapsedTime "sec."
########## End of HTML

$objHTML+= "</body>"
$objHTML+= "</html>"

########## Write File
$objHTML | Out-File $PSScriptRoot\"HealthReport.html"
########## End write file

########## Set HTML Object to Null
$objHTML = $null
########## SECTION::Send Mail
If($Flag -eq 0) {$Severity = "GRUEN"} Else {$Severity = "GELB"}
If($ExpertMode -ne 0) {$To = "SupportMailOne@nobody.me"} Else {$To = "SupportMailTwo@nobody.me"}
$From = "mail.from@nobody.me"
$User = "user_account"
$File = "D:\SCRIPTE\VERWALTUNG\PlainPwd.txt"  # use secure password
$ImagePath = "D:\INTERN\images\IntelliNovaLogo.png"
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)
$Subject = "ELVIS-Betrieb - [" + $Severity + "] Technischer Zustand " + $objHost
$Body = Get-Content "D:\SCRIPTE\VERWALTUNG\HealthReport.html" -RAW
$SMTPServer = "mail.uni-erfurt.de"
$att = New-Object Net.Mail.Attachment($ImagePath)
$att.ContentType.MediaType = "image/png"
$att.ContentId = "Attachment"
#$Attachments.Add($att)
$SMTPPort = "25"
Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -BodyAsHtml -Attachments $ImagePath -SmtpServer $SMTPServer -Port $SMTPPort -UseSsl -Credential (($cred))
$att.Dispose()
########## END
