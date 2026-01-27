$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$outDir = "C:\Temp\Qualys"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$hostname = (hostname)
$hostIdFile = Join-Path $outDir "host_id.txt"

Write-Host "[INFO] Qualys PRE scan (Host-ID based)"
Write-Host "[INFO] Hostname: $hostname"

powershell -ExecutionPolicy Bypass -File scripts/windows-agent/qualys_host_lookup.ps1 `
  -Hostname $hostname `
  -OutFile $hostIdFile `
  -TimeoutSeconds 1800 `
  -PollSeconds 45

$hostId = Get-Content $hostIdFile

$summaryFile = Join-Path $outDir "pre_summary.json"
powershell -ExecutionPolicy Bypass -File scripts/windows-agent/qualys_vuln_summary.ps1 `
  -HostId $hostId `
  -OutFile $summaryFile

$reportFile = Join-Path $outDir ("pre-hardening-report-$env:OS_NAME-$ts.csv")
powershell -ExecutionPolicy Bypass -File scripts/windows-agent/qualys_export_report_csv.ps1 `
  -HostId $hostId `
  -OutFile $reportFile

Write-Host "[INFO] Uploading PRE report + summary to S3..."
aws s3 cp $reportFile "s3://$env:REPORT_BUCKET/$env:REPORT_PREFIX/$env:OS_NAME/pre/$(Split-Path $reportFile -Leaf)"
aws s3 cp $summaryFile "s3://$env:REPORT_BUCKET/$env:REPORT_PREFIX/$env:OS_NAME/pre/$(Split-Path $summaryFile -Leaf)"

Write-Host "[INFO] PRE upload complete."