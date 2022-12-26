$workdir = Get-Location

tee
$downloadpath ="$workdir\$Package"
if(!(Test-Path $downloadpath))
{
New-Item -ItemType Directory $downloadpath
}

 $URLdownload = switch($Package){
        SQLServer2014SP3CU   { "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57663"}
        SQLServer2016SP2CU   { "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56975"}
        SQLServer2017RTMCU   { "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56128"} 
        SQLServer2019RTMCU   { "https://www.microsoft.com/en-us/download/confirmation.aspx?id=100809"} 
        default              {$null}
    }
    $URLdownload
        $CU = (Invoke-WebRequest $URLdownload  -UseBasicParsing -UseDefaultCredentials).links | Where-Object {$_ -match "https://download.microsoft.com/download"} 
        $CU
        $cu = ($cu |Select-Object -first 1).href # getting first url
        $file = $cu -split('/') | Select-Object -Last 1 # getting file name form end of url
        $downloadedfile = "$downloadpath\$file"
        $downloadedfile
        Write-host "Downloading file $file from $cu"
        whoami
        (New-Object System.Net.WebClient).DownloadFile($cu, $downloadedfile)
        if(Test-Path $downloadedfile -PathType Leaf) {write-host "file is downloaded successfully" }
        Else{Throw "File not present, task is Failed";}

        $version = (get-item $downloadedfile).VersionInfo.FileVersion
        $version
