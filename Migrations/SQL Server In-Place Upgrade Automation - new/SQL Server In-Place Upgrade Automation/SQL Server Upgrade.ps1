
##Library and module load
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope User -InvalidCertificateAction Ignore -Confirm:$false
#################################################################
$DomainName = "DQSCUST.LOCAL"
$WorkFile = "C:\Temp\WorkFile_Test.csv"
$UpgradeVersion = "2019"

$Stamp = Get-Date
$SnapName = "Pre-SQL Upgrade (UTC) " + $Stamp.ToUniversalTime()
$DoSnapshot = $False
$DoCopyFiles = $False
$DoUpgrades = $True
$DoTest = $False
$VCValidation = 'P054SQLMGMT03.Epiqcorp.com'
##$VCRepository = 'P054SQLMGMT02.USCUST.LOCAL'
$VCRepository = 'P077SQLMGMT02.corp.dtiglobal.com'
#################################################################
##Load vCenters
$VCenters = @('p054vmwvcsa01.epiqcorp.com','p053vmwvcsa01.epiqcorp.com','p064vmwvcsa01.epiqcorp.com','p077vmwvcsa01.epiqcorp.com')

if ($ESXIUser.Count -eq 0  ) 
   { 
      $ESXIUser = Get-Credential -Message "ESX Login" -Title "vCenter"
   }

#Log out of vcenter incase truly not in VCenter
##if ($global:DefaultVIServers.Count -ne 0) { $global:DefaultVIServers.Name | % { disConnect-VIServer $_ -Confirm:$false} }

#Login to VCenter(s)
if ($global:DefaultVIServers.Count -eq 0) 
   { 
      $VCenters | ForEach-Object { Connect-VIServer $_ -Credential $ESXIUser} 
   }


## Get a single guest credential  < NOTE: this will be used on all Servers in $Computers
   if (-not $GuestUser )
   {
      $GuestUser = Get-Credential -Message "Guest Login for $($DomainName)" -Title "Guest Login"
   }

##Import Server list to populate with install files
   $Computers = Import-Csv -Path $WorkFile | Where-Object Domain -eq $DomainName | Select-Object @{label="vmName";expression={ $_.ConnectedServer.split(".")[0] }},ConnectedServer, SQLEdition

   Write-Verbose "Upgrade list"
   ($Computers  | Format-Table -AutoSize)

   if($DoCopyFiles -eq $true)
   {
         ##Group and deploy install software based on Edition
      foreach( $SQLEdition in ($Computers | Select-Object SQLEdition -unique).SQLEdition )
      {
      $WorkList =  Get-VM -Name (($Computers | Where-Object {$_.SQLEdition -eq $SQLEdition}).vmName  )
      Write-Host "Copy Files on the $($SQLEdition) Edition List"  -ForegroundColor Yellow -BackgroundColor Black
      Write-host $Worklist

      # This will create Check for enough space, create Directory, copy files, expand zip
      $ScriptText = '
         $DriveSpace = Get-WmiObject -Class Win32_LogicalDisk  | Where-Object {$_. DriveType -eq 3} | Select-Object DeviceID, @{n="Size";e={$_.Size /1GB}}, @{n="free";e={$_.FreeSpace /1GB}}
         if (($DriveSpace | Where-object {$_.DeviceID -eq "D:"}).free -ge 10 )
         { 
            if ( -not (Test-Path -Path "D:\SQLUpgrade")) 
            {
               New-Item D:\SQLUpgrade -ItemType directory  -Force;
            }
            New-SMBMapping -Remotepath "\\' + $VCRepository + '\SQLUpgrade" -password "Welcome-Epiq-123" -username "' + $VCRepository + '\SQLTeam";
            Copy-Item "\\' + $VCRepository + '\SQLUpgrade\' +$UpgradeVersion + '\' + $SQLEdition + '.zip" D:\SQLUpgrade -Force
            Copy-Item  "\\' + $VCRepository + '\SQLUpgrade\Upgrade-SqlServerStandaloneDatabaseEngineInstance.ps1" D:\SQLUpgrade -Force 
            Copy-Item  "\\' + $VCRepository + '\SQLUpgrade\Validation_Script.ps1" D:\SQLUpgrade -Force
            Expand-Archive -Force -Path D:\SQLUpgrade\'+ $SQLEdition +'.zip -DestinationPath D:\SQLUpgrade
         } 
         else 
         { 
            Write-Host ("Not Enough space on the D: drive on Server "+[System.Net.Dns]::GetHostByName($env:computerName).HostName)
         }' 
         
      Invoke-VMScript -ScriptText $ScriptText -VM $Worklist -GuestCredential $GuestUser

      }
   }

   If ($DoSnapshot -eq $true)
   {
      ##Determine List of Powered Up Servers and Shut Them Down
      $ShutdownList = Get-VM -name $computers.vmName | Where-Object { $_.PowerState -eq "PoweredOn" } | Shutdown-VMGuest -Confirm:$false 
      $ShutdownList = Get-VM -name $ShutdownList.VmName 

      $Tmstmp = get-date

      ##Ensure all Servers are Powered Down
      Do
         {
            write-Host "Shutting Down ${Shutdownlist.count} of ${$computers.count} "
            Start-Sleep -Seconds 2
            $Shutdownlist = get-VM -name $shutdownlist.name
         }
      While ((New-TimeSpan -start $tmstmp -end (get-date)).TotalSeconds -lt 300 -and ($Shutdownlist.PowerState | Where-Object {$_ -eq "PoweredOn"}) -gt 0)

      ##Grab list of servers that haven't powered down in 5 minutes
      $PowerException = Get-VM -name $computers.vmName | Where-Object { $_.PowerState -eq "PoweredOn" }

      ##Pull List of Servers Powered Down on Source List
      $PowerOff = Get-VM -name $computers.vmName | Where-Object { $_.PowerState -eq "PoweredOff" }


      ##Get Snapshot of VM's That are Powered Down
      $SnapShotJobs = $PowerOff | New-Snapshot -Name $SnapName -Description "Pre-SQL Upgrade" -Confirm:$false -RunAsync


      $Tmstmp = get-date

      ##Loop through list of Powered off servers from $computers list
      Do
         {
            write-Host "Snapping"
            Start-Sleep -Seconds 2
            $SnapshotTasks = Get-task -Server $VCenters -id $Snapshotjobs.id
         }
      While ((New-TimeSpan -start $tmstmp -end (get-date)).TotalSeconds -lt 300 -and ($SnapShotTasks.State | Where-Object {$_ -eq "Running"}) -gt 0)

      ## Grab List of Failed or Incomplete Snapshots
      ##$FailedSnapShots = Get-VM.name | Where-Object $SnapShotTasks.Result

      $PowerUp  = Get-VM -name $PowerOff.Name | Where-Object { $_.PowerState -eq "PoweredOff" } | Start-VM -Confirm:$false 
      $PowerUp  = Get-VM -name $PowerUp.Name


      $Tmstmp = get-date


      ##Ensure all Servers are Powered Up
      Do
         {
            write-Host "Powering Up"
            Start-Sleep -Seconds 2
            $PowerUp = get-VM -name $PowerUp.name
         }
      While ((New-TimeSpan -start $tmstmp -end (get-date)).TotalSeconds -lt 300 -and ($PowerUp.PowerState | Where-Object {$_ -eq "PoweredOff"}) -gt 0)
   }

   If ($DoUpgrades -eq $True)
   {
        
      $WorkList =  Get-VM -Name $Computers.vmName 
      Write-Host "Upgrading Computers" -ForegroundColor Yellow -BackgroundColor Black
               
      $UpgradeText =
      'D:
      CD \SQLUpgrade
      
      Write-Host "Running"

      function Get-SQLInstance
      {
         $InstName  = (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server").InstalledInstances[0]
         $p = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").$InstName
         $Version =  (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").PatchLevel
         $Edition = ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").Edition).Split(" ")[0]

            @{ "InstName" = $InstName;
            "Version" = $Version;
            "Edition" = $Edition;
            "TimeStamp" = (Get-Date).ToUniversalTime()
         }
      }
      $SQLInfo=Get-SQLInstance
      $ServerName = [System.Net.Dns]::GetHostByName($env:computerName).HostName +"\"+ $SQLInfo.InstName

      Write-Host "$($ServerName) "
      Write-Host "$($SQLInfo.TimeStamp) Begin"
      $Insertquery = "INSERT INTO UpgradeStat (ConnectedServer, UpgradeType, Version, UpgradeDate, UpgradeBy) 
                      Values (''$ServerName'', ''Pre-Upgrade'', ''$($SQLInfo.Version)'', ''$($SQLInfo.TimeStamp)'' , ''' + $GuestUser.UserName + ''') "
      Invoke-SQLcmd -ServerInstance ''P054SQLMGMT03.EPIQCORP.COM\SQLADMIN'' -query $insertquery -U SQLDBA -P ''obPblasY6&mM?4QQqnOBFb4x'' -Database DBASupport
      
      ./Validation_Script.ps1 -ServerName ($ServerName)

      $sha256FileHash = (Get-FileHash "D:\SQLUpgrade\$($SQLInfo.Edition)\setup.exe").hash
      $Results=./Upgrade-SqlServerStandaloneDatabaseEngineInstance.ps1 -FilePath "D:\SQLUpgrade\$($SQLInfo.Edition)\setup.exe" -InstanceName $SQLInfo.InstName -FileHash $sha256FileHash -IAcceptSqlServerLicenseTerms -Confirm:$False
      ./Validation_Script.ps1 -ServerName ($ServerName)

      $SQLInfo=Get-SQLInstance
      
      $Insertquery = "INSERT INTO UpgradeStat (ConnectedServer, UpgradeType, Version, UpgradeDate, UpgradeBy) 
                      Values (''$ServerName '', ''Post-Upgrade'', ''$($SQLInfo.Version)'', ''$($SQLInfo.TimeStamp)'' , ''' + $GuestUser.UserName + ''') "
      Invoke-SQLcmd -ServerInstance ''P054SQLMGMT03.EPIQCORP.COM\SQLADMIN'' -query $insertquery -U SQLDBA -P ''obPblasY6&mM?4QQqnOBFb4x'' -Database "DBASupport"
      Write-Host "$($SQLInfo.TimeStamp) Done"
      '
      Invoke-VMScript -ScriptText $UpgradeText -VM $WorkList -GuestCredential $GuestUser -ScriptType Powershell 

      $CopyText ='
      Write-Host "Copy Valations Files to ' + $VCValidation + '"
      Import-Module SmbShare
      New-SMBMapping -Remotepath "\\' + $VCValidation + '\SQLUpgrade" -password "Welcome-Epiq-123" -username "' + $VCValidation + '\SQLTeam";
      Copy-Item "C:\Temp\*validation*.html" "\\' + $VCValidation + '\SQLUpgrade\Validation\"

      ##Restart-Computer
      '
      Invoke-VMScript -ScriptText $CopyText -VM $WorkList -GuestCredential $GuestUser -ScriptType Powershell 

   }   

   if ($DoTest -eq $True)
    {
      $WorkList =  Get-VM -Name $Computers.vmName 

      Write-Host "Testing on the Import Files Process" -ForegroundColor Yellow -BackgroundColor Black

      
      $TestText =
         '
          Write-Host ''Used for development and test purposes.''
         '
         

      Invoke-VMScript -ScriptText $TestText -VM $WorkList -GuestCredential $GuestUser


    }