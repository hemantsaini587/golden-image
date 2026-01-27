param(
  [Parameter(Mandatory=$true)][string]$HostId,
  [Parameter(Mandatory=$true)][string]$OutFile
)

$ErrorActionPreference = "Stop"

function Invoke-QualysGet($Url) {
  $pair = "$env:QUALYS_USERNAME`:$env:QUALYS_PASSWORD"
  $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
  $b64 = [Convert]::ToBase64String($bytes)

  $headers = @{
    "Authorization"    = "Basic $b64"
    "X-Requested-With" = "GoldenImageFactory"
  }

  return Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing -TimeoutSec 90
}

$url = "https://qualysapi.qualys.com/api/2.0/fo/asset/host/vm/detection/?action=list&ids=$HostId&show_results=1&truncation_limit=0"
$resp = Invoke-QualysGet -Url $url

# Extract basic fields using regex (fast and works reliably)
$matches = [regex]::Matches($resp.Content, "<DETECTION>.*?<QID>(.*?)</QID>.*?<SEVERITY>(.*?)</SEVERITY>.*?<TITLE>(.*?)</TITLE>.*?</DETECTION>", "Singleline")

$rows = @()
foreach ($m in $matches) {
  $rows += [PSCustomObject]@{
    HostId   = $HostId
    QID      = $m.Groups[1].Value
    Severity = $m.Groups[2].Value
    Title    = $m.Groups[3].Value
  }
}

$rows | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Host "[INFO] CSV report exported: $OutFile"