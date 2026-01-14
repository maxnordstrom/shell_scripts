# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# --- Failed Login Attempt Checker ---
# 
# Detta skript söker i Event Viewer efter misslyckade inloggningsförsök som skett
# under de senaste 7 dagarna. Scriptet skriver ut en rapport och rangordnar de
# berörda kontona baserat på antalet misslyckade inloggningsförsök. För konton med
# upp till 3 missyckade försök listas under rubriken INFO. Konton med 4-9 misslyckade
# försök listas under WARNING och konton med 10 eller fler misslyckade försök under
# rubriken CRITICAL.
#
# Scriptet ger en överblick av misslyckade inloggningar. Om ett konto flaggas som
# CRITICAL kan admin göra en mer noggrann analys i Event Viewer.
#
# Kör scriptet genom att:
#   - Öppna PowerShell som administratör
#   - Navigera till katalogen där scriptet är sparat.
#   - Kör .\failed-logins-checker.ps1
# 
# Rapporten skrivs ut till .\reports\Failed-Login-Report-DATUM_TID.txt
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Inled med att kolla om användaren kör sessionen som Administratör. Om inte - stoppa scriptet.
function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-IsAdmin
if (-not $isAdmin) {
    Write-Host "You need to run the script as Administrator. Stopping script..."
    exit
}

# Skapa variabel med dagens datum och aktuell tid att använda till rapportens namn och rubrik.
$CurrentDateAndTime = (Get-Date -Format 'yyyyMMdd_HHmmss')

# Skapa variabel för att hämta loggar från och med idag och 7 dagar bakåt.
$SevenDaysAgo = (Get-Date).AddDays(-7)

# Kolla om mappen .\reports finns, annars skapa mapp.
$ReportsFolderPath = ".\reports"

if (-not (Test-Path $ReportsFolderPath)) {
    New-Item -Path $ReportsFolderPath -ItemType Directory
}

# Rapportens sökväg
$OutputFile = ".\reports\Failed-Login-Report-$CurrentDateAndTime.txt"

# Skriv sidhuvud till rapporten med rubrik, datumstämpel och separerande linje.
$Header = "Failed Login Attempt Report - Generated on $CurrentDateAndTime"

$Header | Out-File -FilePath $OutputFile
"=" * 70 | Out-File -FilePath $OutputFile -Append
"" | Out-File -FilePath $OutputFile -Append

# Funktion för att skriva ut sidfoten till rapporten.
# Kallas om det inte finns några misslyckade inloggningsförsök och/eller i slutet av scriptet.
function WriteFooter {
    "" | Out-File -FilePath $OutputFile -Append
    "=" * 70 | Out-File -FilePath $OutputFile -Append
    "Report saved to: $OutputFile" | Out-File -FilePath $OutputFile -Append

    Write-Host ""
    Write-Host "Report completed and saved to: $OutputFile"
    Write-Host ""
    Write-Host "Thank you for using the Failed Logins Checker."
    Write-Host ""
}

# Hämta misslyckade inloggningsförsök från Event Viewer (ID 4625).
$FailedLogins = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$SevenDaysAgo} -ErrorAction SilentlyContinue

# Skriv meddelande till terminalen som visar att scriptet kör.
Write-Host ""
Write-Host "Collecting failed login attempts from Event Viewer..."
Write-Host ""

# Kontrollera om några misslyckade inloggningsförsök hittas.
# Om inga hittas skrivs meddelande till både terminalen och rapporten
# och scriptet avslutas.
if ($FailedLogins -eq $null -or $FailedLogins.Count -eq 0) {
    $Message = "No failed login attempts found in the last 7 days."
    Write-Host $Message -ForegroundColor Green
    $Message | Out-File -FilePath $OutputFile -Append
    WriteFooter
    exit
}

# Skapa tomt hashtable för att kunna hålla namnet på användarna
# och antalet misslyckade inloggningsförsök.
$AccountCounts = @{}

# Loopa igenom alla misslyckade inloggningsförsök
foreach ($Event in $FailedLogins) {
    # Konvertera varje event till XML för vidare hantering
    $EventXML = [xml]$Event.ToXml()
    
    # Hämta användarnamnet för den misslyckade inloggningen och
    # sätt till en variabel
    $Username = $EventXML.Event.EventData.Data | Where-Object {$_.Name -eq 'TargetUserName'} | Select-Object -ExpandProperty '#text'
    
    # Kontrollera att användarnamnet är giltigt
    if ($Username -ne $null -and $Username -ne "" -and $Username -ne "-") {
        # Räkna antalet misslyckade inloggnignar per användare
        # och skriv ut antalet. Om användaren redan finns i hastable
        # $AccountCounts ökar antalet med 1, om användaren inte finns
        # läggs den till och värdet sätts till 1.
        if ($AccountCounts.ContainsKey($Username)) {
            $AccountCounts[$Username] = $AccountCounts[$Username] + 1
        } else {
            $AccountCounts[$Username] = 1
        }
    }
}

# Sortera hashtable baserat på antal misslyckade inloggningsförsök (Från högt till lågt)
$SortedAccounts = $AccountCounts.GetEnumerator() | Sort-Object -Property Value -Descending

# Loopa igenom alla aktuella konton och 
# generera rätt meddelande.
foreach ($Account in $SortedAccounts) {
    $Username = $Account.Key
    $FailedAttempts = $Account.Value
    
    # Baserat på antalet misslyckade inloggningsförsök 
    # genererar rätt meddelande.
    if ($FailedAttempts -le 3) { # INFO-nivå vid 1-3 misslyckade inloggningsförsök
        $Message = "INFO: Account '$Username' has $FailedAttempts failed login attempt(s). No action needed."
        Write-Host $Message -ForegroundColor Green
        $Message | Out-File -FilePath $OutputFile -Append
    }
    elseif ($FailedAttempts -ge 4 -and $FailedAttempts -le 9) { # WARNING-nivå vid 4-9 misslyckade inloggningsförsök
        $Message = "WARNING: Account '$Username' has $FailedAttempts failed login attempts. Suspicious activity detected. Escalate to SOC L2."
        Write-Host $Message -ForegroundColor Yellow
        $Message | Out-File -FilePath $OutputFile -Append
    }
    elseif ($FailedAttempts -ge 10) { # CRITICAL-nivå vid 10 eller fler misslyckade inloggningsförsök.
        $Message = "CRITICAL: Account '$Username' has $FailedAttempts failed login attempts. Possible brute force attempt detected. Escalate to SOC L2 immediately and lock down/isolate account."
        Write-Host $Message -ForegroundColor Red
        $Message | Out-File -FilePath $OutputFile -Append
    }
}

# Kallar på funktionen som skriver ut sidfoten i de fall scriptet
# kör hela vägen till slutet.
WriteFooter