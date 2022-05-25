#Configure HTTPS using Server Certificate
# Change the RS_PBIRS part in case of SSRS or any other custom Name
$serverClass = get-wmiobject -namespace "root\Microsoft\SqlServer\ReportServer\RS_PBIRS\v15\Admin" -class "MSReportServer_ConfigurationSetting"
$serverClass.ReportserverReserveredURL
 
$lcid = (Get-Culture).LCID #[System.Globalization.CultureInfo]::GetCultureInfo("en").LCID
$subjects = [net.dns]::GetHostEntry($env:computername).Hostname
$thmprint = ((Get-ChildItem -Path Cert:LocalMachine\MY | Where-Object { $_.Subject -match $subjects }).Thumbprint).ToLower()
## Reserve ULR for ReportServer site
$result = $serverClass.ReserveURL("ReportServerWebService", "https://${subjects}:443", $lcid)
if ($result.HRESULT -eq 0) {
Write-Host "URL reserved"
}
else {
$result.Error
}
## Bind Certificate for Report Server site
$result = $serverClass.CreateSSLCertificateBinding("ReportServerWebService", $thmprint, "0.0.0.0", 443, $lcid)
if ($result.HRESULT -eq 0) {
Write-Host "Certificate binded for WebService"
}
else {
$result.Error
}
## Reserve ULR for Report site
$result = $serverClass.ReserveURL("ReportServerWebApp", "https://${subjects}:443", $lcid)
if ($result.HRESULT -eq 0) {
Write-Host "URL reserved Report"
}
else {
$result.Error
}
## Bind Certificate for Report site
$result = $serverClass.CreateSSLCertificateBinding("ReportServerWebApp", $thmprint, "0.0.0.0", 443, $lcid)
if ($result.HRESULT -eq 0) {
Write-Host "Certificate binded for Report Managed"
}
else {
$result.Error
}
 
#Change service name here for SSRS
#Restart-Service -Name PowerBIReportServer -Force
