# Remove old output file if it exists
Remove-Item "controls_grohe_ondus.txt" -ErrorAction SilentlyContinue

# Remember the base directory (current working directory)
$base = (Get-Location).Path

# Find all .pm and .txt files in ./FHEM (max depth 2)
Get-ChildItem -Path ".\FHEM" -Recurse -Depth 2 -Include *.pm, *.txt | Sort-Object FullName | ForEach-Object {
    $file = $_.FullName

    # Get last modification time from Git log
    $gitTime = git log --pretty=format:%cd -n 1 --date=iso -- "$file"
    if (-not [string]::IsNullOrWhiteSpace($gitTime)) {
        # Convert Git timestamp to local time (Berlin) and format
        $time = [DateTime]::Parse($gitTime).ToLocalTime().ToString("yyyy-MM-dd_HH:mm:ss")
    } else {
        $time = ""
    }

    # File size in bytes
    $fileSize = $_.Length

    # Make path relative to project folder and replace backslashes with forward slashes
    $relFile = $file.Substring($base.Length + 1) -replace '\\','/'

    # Write formatted line to output file
    $line = "UPD {0} {1,-7} {2}" -f $time, $fileSize, $relFile
    Add-Content -Path "controls_grohe_ondus.txt" -Value $line
}

# Create CHANGED file with last commit info
"FHEM Grohe Ondus last changes:" | Set-Content -Path "CHANGED"
(Get-Date -Format "yyyy-MM-dd") | Add-Content -Path "CHANGED"
(" - " + (git log -1 --pretty=%B)) | Add-Content -Path "CHANGED"
