#This script is used to reboot citrix servers
#Developer - kujalk
#Date - 24/01/2018

#Clearing all unnecessary files in the folder
Remove-Item -recurse "C:\Reboot_Logs\Wednesday\*" 

#Log location
$log="C:\Reboot_Logs\Wednesday\Log.txt"
$log2="C:\Reboot_Logs\Wednesday\reboot.txt"
$log3="C:\Reboot_Logs\Wednesday\Active.txt"
$log4="C:\Reboot_Logs\Wednesday\Disconnect.txt"

$TDis="C:\Reboot_Logs\Wednesday\TDis.txt"
$TActive="C:\Reboot_Logs\Wednesday\TActive.txt"
$TReboot="C:\Reboot_Logs\Wednesday\TReboot.txt"
$TLogmode="C:\Reboot_Logs\Wednesday\TLogmode.txt"

#Creating the files before hand (From this file only html web page is created)
New-Item $TActive -type file
New-Item $TReboot -type file
New-Item $TDis -type file
New-Item $TLogmode -type file

"Refer:reboot.txt`n********************" >>$TReboot
"Refer:Active.txt`n********************" >>$TActive
"Refer:Disconnect.txt`n*******************" >>$TDis
"Please_Manually_Restart_These_Servers `n******************************" >>$TLogmode

#Function for logging data
function timestamp ($message,$location)
{
$date=Get-Date
"$date : <<Info>> : $message" >> $location
}


#Importing citrix modules to powershell session
Add-PSSnapin citrix*

#Worker group Name is hard coded
#**********************************#
$servers= Get-XAWorkerGroup -WorkerGroupName "Reboot_Wednesday" | select ServerNames -ExpandProperty ServerNames


"Worker Group Name : Reboot_Wednesday`n" >> $log

	foreach ($ser in $servers)
	{

	timestamp "$ser LogOn mode was changed to Prohibit_LogOn_UntilReboot " $log
	Set-XAServerLogOnMode -ServerName $ser -LogOnMode ProhibitNewLogOnsUntilRestart

	}

#Sleeping 12 hrs
timestamp "`nGoing to sleep for 12 hrs!!!!" $log
Start-Sleep -s 43200
timestamp "Waking up from sleep !!!!`n" $log

	Foreach ($mac in $servers)
	{
		$session= Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | Where {($_.State -eq "Active") -or ($_.State -eq "Disconnected")} | select State | measure

			#No any session
			if (($session.count) -eq 0)
			{
			#Reboot server
			Restart-Computer -ComputerName $mac -Force
			
			#To check whether reboot is successful
			if($? -eq "True")
			{
		    timestamp "$mac was successfully rebooted (No any sessions found)" $log2
			$mac >> $TReboot
			}
			
			else
			{
			timestamp "<<<ERROR>>> $mac was not successfully rebooted. Please reboot manually" $log2
			}

			}			

			#Some Active or Disconnected Sessions available
			else
			{
			$act = Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | Where {($_.State -eq "Active")} | select state,AccountName
			$dis = Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | Where {($_.State -eq "Disconnected")} | select state,AccountName


				#Active sessions are found
				if((($act | measure).count) -gt 0)
				{	
				
				"`n`n***************$mac*******************" >> $log3
				
				#Printing Active Sessions which are active more than 24 hrs
				$ActHrs = Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | where {$_.state -eq "Active"} | select ConnectTime -ExpandProperty ConnectTime
				
				foreach ($b in $ActHrs)
					{
					#Getting current date
					$E=Get-Date

					$differ=New-Timespan -Start $b -End $E | select TotalHours -ExpandProperty TotalHours 

					$who=Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | where {($_.state -eq "Active") -and ($_.ConnectTime -eq $b) } | select AccountName -ExpandProperty AccountName
						
							
						#Active Sessions < 24 hrs
						if($differ -lt 24)
						{
						#These servers cannot be rebooted because Active sessions with < 24 hrs are found
						timestamp "Active session (Less than 24 hrs) is $who " $log3	
						}
						
						##Active Sessions > 24 hrs
						else
						{
						#These servers cannot be rebooted because Active sessions with > 24 hrs are found
						timestamp "Active session (More than 24 hrs) is $who " $log3
						}
					}
					$mac >> $TActive
					
					timestamp "$mac LogOn mode was still in ProhibitNewLogOnsUntilRestart (Active sessions found) " $log
				}


				#Disconnected session are found
				ElseIf ((($dis | measure).count) -gt 0)
				{
				#Flag to capture
				$do=1

				#getting the time difference between the last disconnected time
				#You have to use a loop because multiple disconneted session can be detected

				$Start = Get-XASession -ServerName $mac | Where {$_.Protocol -eq "Ica"} | where {$_.state -eq "Disconnected"} | select DisconnectTime -ExpandProperty DisconnectTime

					foreach ($a in $Start)
					{
					#Getting current date
					$End=Get-Date

					$diff=New-Timespan -Start $a -End $End | select TotalHours -ExpandProperty TotalHours 

						#Some disconnected sessions detected with less than 3hrs, therefore cannot reboot
						if($diff -lt 3)
						{
						#changing flag
						$do=0
						}
					}

				#No any disconnected session with less than 3 hrs, therefore these disconnected session may be strucked and can be rebooted
				if($do -eq 1)
				{
				#Reboot server
				Restart-Computer -ComputerName $mac -Force
				
				#To check whether reboot is successful
			    if($? -eq "True")
			    {
		        timestamp "$mac was successfully rebooted (Disconnected sessions greater than 3hrs are discarded)" $log2
			    $mac >> $TReboot
			    }
			
			    else
			    {
			    timestamp "<<<ERROR>>> $mac was not successfully rebooted. Please reboot manually" $log2
			    }
			
			
				}

				#Disconnected session found with less than 3 hrs
				if($do -eq 0)
				{
				#These servers cannot be rebooted
				"`n`n***************$mac*******************" >> $log4
				timestamp "Disconnected sessions including less than 3 hrs are found on $mac" $log4
				"The disconnected sessions are - `n" >> $log4
				$dis >> $log4
				$mac >> $TDis
				
				timestamp "$mac LogOn mode was still in ProhibitNewLogOnsUntilRestart (Disconnected sessions < 3 hrs found) " $log
				}

				}

			}

	}


Start-Sleep -Seconds 1200

Get-XAServer | where {$_.LogOnMOde -eq "ProhibitNewLogOnsUntilRestart"} | select ServerName -ExpandProperty ServerName >> $TLogmode


#Creating table of list
$r=Get-content $TReboot | ? {$_.trim() -ne "" }
$p=Get-content $TDis | ? {$_.trim() -ne "" }
$s=Get-content $TActive | ? {$_.trim() -ne "" }
$w=Get-content $TLogmode | ? {$_.trim() -ne "" }

$max = ($r, $p,$s,$w | Measure-Object -Maximum -Property Count).Maximum   

$Header = @"
<style>
TABLE {border-width: 4px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 4px; padding: 6px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 4px; padding: 6px; border-style: solid; border-color: black;}
</style>
"@

0..($max-1) | Select-Object @{n="Servers Rebooted Successfully";e={$r[$_]}}, @{n="Servers Did not Rebooted (Disconnected sessions < 3 hrs)";e={$p[$_]}},@{n="Servers Did not Rebooted (Active sessions)";e={$s[$_]}},@{n="Servers with ProhibitNewLogOnsUntilRestart";e={$w[$_]}}| ConvertTo-Html -Head $Header | Out-File -FilePath "C:\Reboot_Logs\Wednesday\Table.html"

#To Send log files to the mail

$smtpServer = "smtp.xxxxxxxxxx"

$msg = new-object Net.Mail.MailMessage

$smtp = new-object Net.Mail.SmtpClient($smtpServer)

#Change according to server where the script is executed
$msg.From = "xxxxxxxxxxx"

$msg.To.Add("1st mail")
$msg.To.Add("2nd mail")


$msg.Subject = "WorkerGroupName - Reboot_Wednesday Reboot Logs"
$msg.Body = "Logs files are attached with this mail"

#checking for file
If(Test-Path $log)
{
$att1 = new-object Net.Mail.Attachment($log)
$msg.Attachments.Add($att1)
}

If(Test-Path $log2 )
{
$att2 = new-object Net.Mail.Attachment($log2)
$msg.Attachments.Add($att2)
}

If(Test-Path $log3)
{
$att3 = new-object Net.Mail.Attachment($log3)
$msg.Attachments.Add($att3)
}

If(Test-Path $log4)
{
$att4 = new-object Net.Mail.Attachment($log4)
$msg.Attachments.Add($att4)
}

If(Test-Path "C:\Reboot_Logs\Wednesday\Table.html")
{
$att5 = new-object Net.Mail.Attachment("C:\Reboot_Logs\Wednesday\Table.html")
$msg.Attachments.Add($att5)
}

$smtp.Send($msg)

Start-Sleep -Seconds 5 

exit