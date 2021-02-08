#use Powershell5.1 or above
Function Search-SQLService{
    param(
        [Parameter(Mandatory=$true,HelpMessage="Enter Server Name")]$serverName,
        [Parameter(Mandatory=$true,HelpMessage="Enter Server Name")]$ServiceName,
        [parameter(Mandatory=$true)][validateset("NONPROD","PROD")]$ScriptEnvironment
    )
    $masterserver = switch($ScriptEnvironment)
    {
        #change your prod\non prod server here.
        'PROD'{ 'PROD Server Instance'}
        'NONPROD'{'Non Prod INstance'}
    }
    <##
    #Change your DBName here
    in Case db name is different than use switch case for PROD & non prod server as per example below:
        $masterdb = switch($ScriptEnvironment)
    {
        #change your prod\non prod server here.
        'PROD'{ 'PROD DB Name'}
        'NONPROD'{'Non Prod DB Name'}
    }
    #>
    #Change your DBName here
    $masterdb = 'DB Name'
    #Change your Tablename here for loggings
    $logstable = "T_ServiceDetails_logs"
    #Change your Tablename here for service data
    $servicedetailstable = "T_ServiceDetails"
    #Change schema if different
    $schemaname = "dbo"
    try{
        Write-Host "Test Connection fo server $servername"
        $testcon = Test-Connection -ComputerName $serverName -Count 2 -ErrorAction Stop
    }
    Catch{
        $err = $Error[0].Exception.message
        $hashtable = @{}
        $hashtable.Add("RunMachine" ,$env:COMPUTERNAME)
        $hashtable.Add("RunDate",$(get-date -Format "yyyy-MM-dd HH:mm:ss")) 
        $hashtable.Add("ComputerName",$serverName)
        $hashtable.Add("Status","Error")
        $hashtable.add("Message","Test connection failed for server $($servername).")
        $hashtable.add("ErrorDetails","$err")
        
        $tabledata = New-Object psobject -Property $hashtable
        $tabledata
        $tabledata|Write-SqlTableData -ServerInstance $masterserver -DatabaseName $masterdb -SchemaName $schemaname -TableName $logstable -Force -ErrorAction Stop
        Throw  "Test Connection failed for server $($servername)."
    }
    try{
        Write-Host "Test Connection success for server $($servername).Getting Service Information."
        $searchresult = Get-CimInstance -ClassName Win32_Service -ComputerName $serverName|Where-object{$_.DisplayName -match $ServiceName}|Select-Object @{n="RunMachine";e={$env:COMPUTERNAME}},@{n="RunDate";e={get-date -Format "yyyy-MM-dd HH:mm:ss"}},SystemName,@{n="ServiceName";e={$psitem.Name}},DisplayName,State,@{n="ServiceAccountName";e={$psitem.StartName}},StartMode,Status -ErrorAction Stop
        
        if($searchresult)
        {
            $searchresult|Write-SqlTableData -ServerInstance $masterserver -DatabaseName $masterdb -SchemaName $schemaname -TableName $servicedetailstable -Force -ErrorAction Stop
        }
        else{
            $hashtable = @{}
            $hashtable.Add("RunMachine" ,$env:COMPUTERNAME)
            $hashtable.Add("RunDate",$(get-date -Format "yyyy-MM-dd HH:mm:ss"))  
            $hashtable.Add("ComputerName",$serverName)
            $hashtable.Add("Status","Information")
            $hashtable.add("Message","No SQL Service found for server $($servername).")
            $hashtable.add("ErrorDetails","None")
            $tabledata = New-Object psobject -Property $hashtable
            $tabledata|Write-SqlTableData -ServerInstance $masterserver -DatabaseName $masterdb -SchemaName $schemaname -TableName $logstable -Force -ErrorAction Stop
        }
    }
    catch{
        $err = $Error[0].Exception.message
        $hashtable = @{}
        $hashtable.Add("RunMachine" ,$env:COMPUTERNAME)
        $hashtable.Add("RunDate",$(get-date -Format "yyyy-MM-dd HH:mm:ss"))  
        $hashtable.Add("ComputerName",$serverName)
        $hashtable.Add("Status","Error")
        $hashtable.add("Message","Error in getting service for server $($servername).")
        $hashtable.add("ErrorDetails","$($err)")
        $tabledata = New-Object psobject -Property $hashtable
        $tabledata|Write-SqlTableData -ServerInstance $masterserver -DatabaseName $masterdb -SchemaName $schemaname -TableName $logstable -Force -ErrorAction Stop
        Throw "Error in getting service for server $($servername). Error $($err)."
    }
}

Function Invoke-SQLQuery
{
    Param
    (
        [parameter(Mandatory=$true)][validateset("NONPROD","PROD")]$ScriptEnvironment,
        [parameter(Mandatory=$true)]$sqlquery
    )
    $masterserver = switch($ScriptEnvironment)
    {
        #change your prod\non prod server here.
        'PROD'{ 'PROD Server Instance'}
        'NONPROD'{'Non Prod INstance'}
    }
    <##
    #Change your DBName here
    in Case db name is different than use switch case for PROD & non prod server as per example below:
        $masterdb = switch($ScriptEnvironment)
    {
        #change your prod\non prod server here.
        'PROD'{ 'PROD DB Name'}
        'NONPROD'{'Non Prod DB Name'}
    }
    #>
    #Change your DBName here
    $masterdb = 'DB Name'
    ##Change your DBName here
    try
    {
        Invoke-Sqlcmd -ServerInstance $masterserver -Database $masterdb -query $sqlquery -ErrorAction Stop
    }
    Catch
    {
        Throw "Error calling script in master server. Error $($error[0].Exception.Message)"
    }
}



Function send-userhtmlmail
{
    param(
    [parameter(Mandatory=$true,HelpMessage="enter valid email id")]$emailid,
    [parameter(Mandatory=$true)][validateset("NONPROD","PROD")]$ScriptEnvironment
    )

    $getreportquery = "SELECT Distinct [RunMachine]
    ,[RunDate]
    ,[SystemName]
    ,[ServiceName]
    ,[DisplayName]
    ,[State]
    ,[ServiceAccountName]
    ,[StartMode]
    ,[Status]
FROM [T_ServiceDetails]
where State='Stopped'
and cast([rundate] as date) = cast(getdate() as date)"
$getreportdata = Invoke-SQLQuery -sqlquery $getreportquery -ScriptEnvironment $ScriptEnvironment
   $html = "
              <style>
              TABLE{border-width: 5px;border-style: solid;border-color: black;border-collapse: collapse;}
              TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;background-color: #DFCADC}
              TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black}
              </style>
              "
  if($getreportdata -ne $null)
  { 
      $getreportdata= $getreportdata|ConvertTo-Html -Head $html
      $getreportdata= $getreportdata -replace "<title>HTML TABLE</title>",""
      $getreportdata = $getreportdata -replace "<table>",'<table style="color:Black">'
      $getreportdata = $getreportdata -replace "<td>Stopped", '<td bgcolor="Orange">Stopped'
      $getreportdata = $getreportdata -replace "<td>Disabled", '<td bgcolor="Yellow">Disabled'
      $getreportdata = $getreportdata -replace "<td>Running", '<td bgcolor="Green">Running'

      $Body = @"
      Dear Team, <br />
                  <br />
              Please take action services which are in stopped state: <br><br>
              $getreportdata
      <br><br>
      <br><br><br>
      <br>Warm Regards,
      <br>Automation Team<br>
      <br />
      <br />
"@
  }
  else {
      $report  = "No Service in stopped state.No Action Required." 
      $Body = @"
      Dear Team, <br />
                  <br />
      $report
      <br><br>
      Cheers!!
      <br>Warm Regards,
      <br>Automation Team<br>
      <br />
      <br />
"@
  }

  ################### Get the Password for Tec Account ########################
  $tecaccountname = "Techaccount name"
  $password = "In Case smpt server is using different tech account for sending mail"
  $secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ($tecaccountname, $secpasswd) 
      $Subject  = "SQL Services Status"
       Send-MailMessage -From "abc@test.com" -To ($emailid -split',') `
      -Cc "xyz@outlook.com"  `
      -Subject $Subject `
      -Body $Body `
      -SmtpServer "Enter here SMTP Server Name" `
      -Credential $cred -UseSsl -BodyAsHtml `
      -dno onSuccess, onFailure  

}

Function Start-SQLServiceStatus{
param(
    [parameter(Mandatory=$true)][validateset("NONPROD","PROD")]$ScriptEnvironment
)
#Get List of servers
#Change Table name
$serverslistqueryy= "SELECT distinct [host_name] as host_name FROM tablecontainserverlist"
try{
    $serverslist = Invoke-SQLQuery -sqlquery $serverslistqueryy -ScriptEnvironment $ScriptEnvironment -ErrorAction Stop
}
catch{
    $err = $error[0].Exception.Message
    Throw "Error in getting server list information. Error : $err"
}

foreach($server in $serverslist)
{
    try{
        Search-SQLService -serverName $($server.host_name) -ServiceName "SQL Server" -ScriptEnvironment $ScriptEnvironment -ErrorAction Stop
    }
    Catch{
        $erro = $($($error[0].Exception.Message))
        Write-Host "$erro"
    }
}
#send email once data is collect in table.
send-userhtmlmail -ScriptEnvironment $ScriptEnvironment -emailid "abc@example.com"
}

#Start-SQLServiceStatus -ScriptEnvironment NONPROD





