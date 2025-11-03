# Entferne alte Datei, falls vorhanden
Remove-Item "controls_grohe_ondus.txt" -ErrorAction SilentlyContinue

# Finde alle .pm und .txt Dateien in ./FHEM (max. Tiefe 2)
Get-ChildItem -Path ".\FHEM" -Recurse -Depth 2 -Include *.pm, *.txt | Sort-Object FullName | ForEach-Object {
    $file = $_.FullName

    # Letztes Änderungsdatum aus Git holen
    $gitTime = git log --pretty=format:%cd -n 1 --date=iso -- "$file"
    if (-not [string]::IsNullOrWhiteSpace($gitTime)) {
        # In Berliner Zeit umwandeln und formatieren
        $time = [DateTime]::Parse($gitTime).ToLocalTime().ToString("yyyy-MM-dd_HH:mm:ss")
    } else {
        $time = ""
    }

    # Dateigröße
    $fileSize = $_.Length

    # Pfad ohne führendes .\
    $relFile = $file.Substring(2)

    # In Datei schreiben
    $line = "UPD {0} {1,-7} {2}" -f $time, $fileSize, $relFile
    Add-Content -Path "controls_grohe_ondus.txt" -Value $line
}

# CHANGED-Datei erzeugen
"FHEM Grohe Ondus last changes:" | Set-Content -Path "CHANGED"
(Get-Date -Format "yyyy-MM-dd") | Add-Content -Path "CHANGED"
(" - " + (git log -1 --pretty=%B)) | Add-Content -Path "CHANGED"
