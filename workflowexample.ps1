$wo = New-PSWorkflowExecutionOption -MaxSessionsPerWorkflow 200 -MaxDisconnectedSessions 200 -MaxRunningWorkflows 200 -MaxConnectedSessions 200 -MaxSessionsPerRemoteNode 200 -MaxActivityProcesses 200
# Create the Workflow session configuration
Register-PSSessionConfiguration -Name Start-workflowExample -SessionTypeOption $wo -Force

workflow Start-workflowExample {
    param 
    (
        [Parameter(Mandatory = $true)][Array]$Servers
    )
    $array = @()

    foreach -parallel -ThrottleLimit 200  ($server in $servers) {
      

        #check if IP part of trustedhosts, it's required to WinRM connection using negotiate
        InlineScript
        {
            $tServer = $Using:server
            $ips = (Get-Item WSMan:localhost\Client\TrustedHosts).value 
            $IPToCheck = ([System.Net.Dns]::GetHostByName($tServer).AddressList[0]).IpAddressToString.tostring()
            Set-Item WSMan:\localhost\Client\TrustedHosts –Value * -Force
        }

        #Check PowerBi is installed
        $PowerBIPresent = InlineScript
        {
            $CurVersion = Get-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\PBIRS\MSSQLServer\CurrentVersion" -ErrorAction SilentlyContinue
            return $CurVersion.CurrentVersion 
                                
        }-PSComputer ([System.Net.Dns]::GetHostByName($server).AddressList[0]).IpAddressToString -PSAuthentication Negotiate #-PSCredential $cred 
        

        # does server need a reboot
        $reboot = inlinescript {  
            function Test-PendingReboot {
                if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
                if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
                if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
                try { 
                    $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
                    $status = $util.DetermineIfRebootPending()
                    if (($status -ne $null) -and $status.RebootPending) {
                        return $true
                    }
                }
                catch {}
                return $false
            }
            $value = test-PendingReboot
            return $value
        
        } -PSComputer ([System.Net.Dns]::GetHostByName($server).AddressList[0]).IpAddressToString -PSAuthentication Negotiate #-PSCredential $cred 
        write-output "reboot pending $reboot on $server"

        # catch if reboot is need for stand alone if yes reboot and wait for workflow.
        If ($Reboot -eq $True) {
            Write-Output "reboot is required for  $server"
            #Write-Output "Exit" Exit1
            #Uncomment this line if you want to reboot remote computer.
            #Restart-Computer -PSComputerName $server -Wait -for WMI -Force
            #as we waiting only for WMI after restart( Powershell won't work because of Kerberos WinRM issue!), wait for some time to start more services, even for SQL service more time could be required to start!
            Start-Sleep 30
        } 

        Write-Output "$server patch level : $PowerBIPresent"
        $InstallationStatus = InlineScript
        {
            $CurVersion = Get-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\PBIRS\MSSQLServer\CurrentVersion" -ErrorAction SilentlyContinue
            $Version = $CurVersion.CurrentVersion 
            $Servername = $env:COMPUTERNAME
            if ($Version -match '15.0.1107.166') {
                
                Write-host "$Servername : Power BI Report Server Current Version is upto date no upgrade required" -ForegroundColor DarkYellow
                $out = "PatchUptoDate_$Version"
                return $out
            }
            
            Else {
                Write-host "$Servername : Installation started"

                $InstallInfo = choco upgrade MicrosoftPowerBI -Y --force
                
                
                If ($InstallInfo -match 'Chocolatey upgraded 1/1 packages') {
                    Write-host "Installation successful for $Servername"
                    return 'Successful'
                }
                Else {
                    return "$InstallInfo"
                }

            }
        } -PSComputer ([System.Net.Dns]::GetHostByName($server).AddressList[0]).IpAddressToString -PSAuthentication Negotiate #-PSCredential $cred 
        if ($InstallationStatus -eq 'Successful') {
            $reboot = inlinescript {  
                function Test-PendingReboot {
                    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
                    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
                    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
                    try { 
                        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
                        $status = $util.DetermineIfRebootPending()
                        if (($status) -and $status.RebootPending) {
                            return $true
                        }
                    }
                    catch {}
                    return $false
                }
                $value = test-PendingReboot
                return $value

            } -PSComputer ([System.Net.Dns]::GetHostByName($server).AddressList[0]).IpAddressToString -PSAuthentication Negotiate #-PSCredential $cred 
            write-output "reboot pending $reboot on $server"

            # catch if reboot is need for stand alone if yes reboot and wait for workflow.
            If ($Reboot -eq $True) {
                Write-Output "Installation was succesfull"
                Write-Output "reboot is required post installation for  $server"
                # Uncomment this line if you want to reboot remote computer.
                #Restart-Computer -PSComputerName $server -Wait -for WMI -Force
                #as we waiting only for WMI after restart( Powershell won't work because of Kerberos WinRM issue!), wait for some time to start more services, even for SQL service more time could be required to start!
                Start-Sleep 30
            } 
        }
        Write-output "collecting post patching build on $server"
        $build_post = InlineScript 
        {
            $CurVersion = Get-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\PBIRS\MSSQLServer\CurrentVersion" -ErrorAction SilentlyContinue
            return $CurVersion.CurrentVersion

        } -PSComputer ([System.Net.Dns]::GetHostByName($server).AddressList[0]).IpAddressToString -PSAuthentication Negotiate #-PSCredential $cred 

        $hashtable = [ordered]@{
            PowerBIServer      = $server
            InstallationStatus = $InstallationStatus
            PowerBi_Pre        = if ($PowerBIPresent) { $PowerBIPresent } else { "Empty" }
            PowerBi_Post       = if ($build_post) { $build_post } else { "Empty" }
            Date               = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        write-output "Script Ended On $env:computername for remote $server"
        
        $oneRow = New-Object PSObject -Property $hashtable
        $workflow:array += $oneRow
        
    } #end of Parameterfor loop
    $array
    
} # end of workflow

 
#Uncomment below line to get list of computers
#$computers= "test1","trsrv2"


netsh winhttp reset proxy

#Change log file location here
$outfile = "C:\TEMP\PBIRS\TEST_Patching.log"

#uncomment below to run the script
#Start-workflowExample $computers | out-file $outfile

Remove-Variable * -ErrorAction SilentlyContinue
