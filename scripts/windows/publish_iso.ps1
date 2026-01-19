param(
  [Parameter(Mandatory=$true)]
  [string]$IsoPath,

  [Parameter(Mandatory=$true)]
  [string]$MdtShare
)

Write-Host "[INFO] Publishing ISO to MDT share..."
Write-Host "ISO: $IsoPath"
Write-Host "MDT Share: $MdtShare"

# Placeholder: copy ISO
Copy-Item -Path $IsoPath -Destination $MdtShare -Force

Write-Host "[INFO] ISO published successfully."
