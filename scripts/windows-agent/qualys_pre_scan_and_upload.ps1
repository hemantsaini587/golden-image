$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$reportName = "pre-hardening-report-$env:OS_NAME-$ts.pdf"
$outDir = "C:\Temp\Qualys"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "[INFO] Qualys PRE scan (Host ID workflow) for $env:OS_NAME"
Write-Host "[INFO] Report: $reportName"

# NOTE: Host ID lookup + report export is implemented via Python in this repo.
# On Windows, easiest production approach:
# 1) Install Python (or embed a small exe)
# 2) Call python scripts
# For now, placeholder file generation:
$reportPath = Join-Path $outDir $reportName
Set-Content -Path $reportPath -Value "%PDF-QUALYS-REPORT-PLACEHOLDER%" -Encoding ascii

Write-Host "[INFO] Uploading PRE report to S3..."
aws s3 cp $reportPath "s3://$env:REPORT_BUCKET/$env:REPORT_PREFIX/$env:OS_NAME/pre/$reportName"

Write-Host "[INFO] PRE completed."
