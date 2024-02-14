Function Calculate-File-Hash {
    param (
        [string]$FilePath
    )

    try {
        $FileHash = Get-FileHash -Path $FilePath -Algorithm SHA512
        return $FileHash.Hash
    } catch {
        Write-Error "Error calculating hash for file: $FilePath"
        return $null
    }
}

Function Erase-Baseline-If-Already-Exists {
    if (Test-Path -Path .\baseline.txt) {
        Remove-Item -Path .\baseline.txt -ErrorAction SilentlyContinue
    }
}

Function Check-Files-Against-Baseline {
    $MismatchedFiles = @()

    # Load file|hash from baseline.txt and store them in a dictionary
    $FileHashDictionary = @{}
    $FilePathsAndHashes = Get-Content -Path .\baseline.txt
    
    foreach ($Line in $FilePathsAndHashes) {
        $FilePath, $Hash = $Line.Split("|")
        $FileHashDictionary[$FilePath] = $Hash
    }

    # Compare files against the baseline
    $Files = Get-ChildItem -Path $FolderPath -File

    foreach ($File in $Files) {
        $Hash = Calculate-File-Hash -FilePath $File.FullName
        if (-not $FileHashDictionary.ContainsKey($File.FullName)) {
            $MismatchedFiles += $File.FullName
        }
        elseif ($FileHashDictionary[$File.FullName] -ne $Hash) {
            $MismatchedFiles += $File.FullName
        }
    }

    return $MismatchedFiles
}

Write-Host ""
Write-Host "What would you like to do?"
Write-Host ""
Write-Host "    A) Collect new Baseline?"
Write-Host "    B) Begin monitoring files with saved Baseline?"
Write-Host "    C) Check files in the folder against the Baseline?"
Write-Host ""
$Response = Read-Host -Prompt "Please enter 'A', 'B', or 'C'"
Write-Host ""

if ($Response -eq "A".ToUpper()) {
    # Prompt for folder path
    $FolderPath = Read-Host -Prompt "Enter the path to the folder you want to monitor"

    # Delete baseline.txt if it already exists
    Erase-Baseline-If-Already-Exists

    # Collect hashes from the target files and store in baseline.txt
    $Files = Get-ChildItem -Path $FolderPath -File

    foreach ($File in $Files) {
        $Hash = Calculate-File-Hash -FilePath $File.FullName
        if ($Hash) {
            "$($File.FullName)|$Hash" | Out-File -FilePath .\baseline.txt -Append
        }
    }
}
elseif ($Response -eq "B".ToUpper()) {
    # Begin monitoring files with saved Baseline
    while ($true) {
        Start-Sleep -Seconds 1
        
        $Files = Get-ChildItem -Path $FolderPath -File

        foreach ($File in $Files) {
            $Hash = Calculate-File-Hash -FilePath $File.FullName
            if (-not $FileHashDictionary.ContainsKey($File.FullName)) {
                # A new file has been created
                Write-Host "$($File.FullName) has been created!" -ForegroundColor Green
                $FileHashDictionary[$File.FullName] = $Hash
            }
            elseif ($FileHashDictionary[$File.FullName] -ne $Hash) {
                # File has been changed
                Write-Host "$($File.FullName) has changed!!!" -ForegroundColor Yellow
                $FileHashDictionary[$File.FullName] = $Hash
            }
        }

        # Check for deleted files
        foreach ($FilePath in $FileHashDictionary.Keys) {
            if (-not (Test-Path -Path $FilePath)) {
                # File has been deleted
                Write-Host "$FilePath has been deleted!" -ForegroundColor DarkRed -BackgroundColor Gray
                $FileHashDictionary.Remove($FilePath)
            }
        }
    }
}
elseif ($Response -eq "C".ToUpper()) {
    # Prompt for folder path
    $FolderPath = Read-Host -Prompt "Enter the path to the folder you want to check"

    # Check files against the baseline
    $MismatchedFiles = Check-Files-Against-Baseline

    if ($MismatchedFiles.Count -eq 0) {
        Write-Host "All files in the folder match the baseline." -ForegroundColor Green
    } else {
        Write-Host "Mismatched files found:" -ForegroundColor Red
        foreach ($file in $MismatchedFiles) {
            Write-Host $file -ForegroundColor Red
        }
    }
}
