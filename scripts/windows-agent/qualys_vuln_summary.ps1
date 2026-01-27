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

$crit = ([regex]::Matches($resp.Content, "<SEVERITY>5</SEVERITY>")).Count
$high = ([regex]::Matches($resp.Content, "<SEVERITY>4</SEVERITY>")).Count
$med  = ([regex]::Matches($resp.Content, "<SEVERITY>3</SEVERITY>")).Count
$low  = ([regex]::Matches($resp.Content, "<SEVERITY>2</SEVERITY>")).Count
$info = ([regex]::Matches($resp.Content, "<SEVERITY>1</SEVERITY>")).Count

$obj = [PSCustomObject]@{
  host_id            = $HostId
  severity_5_critical = $crit
  severity_4_high     = $high
  severity_3_medium   = $med
  severity_2_low      = $low
  severity_1_info     = $info
}

$obj | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutFile -Encoding utf8
Write-Host "[INFO] Summary written: $OutFile"