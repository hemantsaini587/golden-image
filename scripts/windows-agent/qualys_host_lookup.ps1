param(
  [Parameter(Mandatory=$true)][string]$Hostname,
  [Parameter(Mandatory=$true)][string]$OutFile,
  [int]$TimeoutSeconds = 1800,
  [int]$PollSeconds = 45
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

$deadline = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)

while ((Get-Date).ToUniversalTime() -lt $deadline) {
  $url = "https://qualysapi.qualys.com/api/2.0/fo/asset/host/?action=list&details=Basic&dns=$Hostname"
  $resp = Invoke-QualysGet -Url $url

  if ($resp.StatusCode -eq 200 -and $resp.Content) {
    # naive extraction of <ID>...</ID> under <HOST>
    if ($resp.Content -match "<HOST>.*?<ID>(\d+)</ID>.*?</HOST>") {
      $hostId = $Matches[1]
      Set-Content -Path $OutFile -Value $hostId -Encoding ascii
      Write-Host "[INFO] Found Qualys Host ID: $hostId"
      exit 0
    }
  }

  Write-Host "[INFO] Host not found yet in Qualys. Waiting..."
  Start-Sleep -Seconds $PollSeconds
}

throw "Timed out waiting for Qualys Host ID for hostname=$Hostname"