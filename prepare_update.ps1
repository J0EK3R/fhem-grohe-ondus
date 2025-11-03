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
        # Convert Git timestamp to local time and format
        $time = [DateTime]::Parse($gitTime).ToLocalTime().ToString("yyyy-MM-dd_HH:mm:ss")
    } else {
        $time = ""
    }

    # Relative path with forward slashes for both output and Git commands
    $relFile = ($file.Substring($base.Length + 1) -replace '\\','/')

    # Get blob size from Git (repository bytes, independent of CRLF/LF on disk)
    # 1) Get the blob SHA for the path
    $lsOut = git ls-files -s -- "$relFile"
    if ([string]::IsNullOrWhiteSpace($lsOut)) {
        # Fallback: if file is untracked, use filesystem size (will differ on CRLF)
        $fileSize = $_.Length
    } else {
        # Format: <mode> <sha> <stage>\t<path>; split to extract SHA (2nd token)
        $tokens = $lsOut -split '\s+'
        $sha = $tokens[1]
        # 2) Ask Git for blob size in bytes
        $fileSize = [int](git cat-file -s $sha)
    }

    # Write formatted line to output file
    $line = "UPD {0} {1,-7} {2}" -f $time, $fileSize, $relFile
    Add-Content -Path "controls_grohe_ondus.txt" -Value $line
}

# Create CHANGED file with last commit info
"FHEM Grohe Ondus last changes:" | Set-Content -Path "CHANGED"
(Get-Date -Format "yyyy-MM-dd") | Add-Content -Path "CHANGED"
(" - " + (git log -1 --pretty=%B)) | Add-Content -Path "CHANGED"
