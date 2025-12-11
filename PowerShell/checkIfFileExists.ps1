# Check if file exists in current directory

# Print welcome message
$name = "Felix"
Write-Host "Welcome $name"

# Prompt for file to check
$file = Read-Host "Choose what file to check"
Write-Host "You chose: $file"

# Logic to look for file and print message
if (Test-Path $file) {
  Write-Host "The file is in the current directory."
} else {
  Write-Host "The file does not exist in the current directory."
}