# 强制使用UTF-8编码
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$batchSize = 5
$currentPage = 1579156
Write-Host "Debug: currentPage = $currentPage, endPage = $endPage"
$endPage = 1593293  # 调整为实际存在的最大页码
$commitMessage = "Batch upload images"

# 获取所有符合条件的文件夹并提取页码
$allFolders = Get-ChildItem -Directory -Filter "page_*" | ForEach-Object {
Write-Host "Debug: Found folder: $($_.Name)"
    if ($_.Name -match 'page_(\d+)') {
        $pageNum = [int]$matches[1]
        [PSCustomObject]@{
            Path = $_.Name
            PageNumber = $pageNum
        }
    }
} | Where-Object { $_.PageNumber -ge $currentPage -and $_.PageNumber -le $endPage } | `
    Sort-Object PageNumber

# 计算总批次数
$totalPages = $allFolders.Count
$batchCount = [Math]::Ceiling($totalPages / $batchSize)

Write-Host "Found $totalPages folders to process in $batchCount batches"
Write-Host "First folder: $($allFolders[0].Name), Last folder: $($allFolders[-1].Name)"
Write-Host "All folders count: $($allFolders.Count)"
    Write-Host "Debug: First folder page number: $($allFolders[0].PageNumber)"
    Write-Host "Debug: Last folder page number: $($allFolders[-1].PageNumber)"

# 按批处理
for ($batchIndex = 0; $batchIndex -lt $batchCount; $batchIndex++) {
    $startIndex = $batchIndex * $batchSize
    $endIndex = [Math]::Min($startIndex + $batchSize - 1, $totalPages - 1)
    $batchStartNum = $allFolders[$startIndex].PageNumber
    $batchEndNum = $allFolders[$endIndex].PageNumber
    
    Write-Host "`n=== Processing batch $($batchIndex+1)/${batchCount}: $batchStartNum-$batchEndNum ($($endIndex - $startIndex + 1) folders) ==="
    
    # 获取当前批次的文件夹
    $batchFolders = $allFolders[$startIndex..$endIndex]
    
    # 添加文件
    $batchFolders | ForEach-Object {
        $folderPath = $_.Path
        $files = Get-ChildItem -Path $folderPath -File
        if ($files.Count -eq 0) {
            Write-Host "Skipping empty folder: $folderPath"
            continue
        }
        Write-Host "Adding folder: $folderPath"
$files = Get-ChildItem -Path "$folderPath" -File
if ($files.Count -eq 0) {
    Write-Host "Warning: Folder $folderPath is empty, skipping..."
    continue
}
        Write-Host "Executing: git add $folderPath"
git add "$folderPath"
if ($LASTEXITCODE -eq 128) {
    Write-Host "Critical: Git memory error, skipping folder $folderPath"
    continue
} elseif ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: git add failed with exit code $LASTEXITCODE for $folderPath"
    continue
    Write-Host "Warning: Git out of memory, skipping folder $folderPath"
    continue
}
$statusOutput = git status --porcelain
Write-Host "Git status after add: $statusOutput"
Write-Host "Added folder: $folderPath"
        if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: git add failed with exit code $LASTEXITCODE for path $folderPath/*"
            Write-Host "Error: git add failed for $folderPath"
            continue
        }
    }
    
    # 检查更改
    $changes = git status --porcelain
    if ($changes) {
        $stagedChanges = git diff --cached --name-only
if ([string]::IsNullOrEmpty($stagedChanges)) {
    Write-Host "No staged changes to commit, skipping commit..."
    continue
}
Write-Host "Changes detected, committing..."
        git commit -m "${commitMessage}: $batchStartNum-$batchEndNum"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: git commit failed"
            exit $LASTEXITCODE
        }
        git push
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: git push failed"
            exit $LASTEXITCODE
        }
        
        Write-Host "Pushing batch $batchStartNum-$batchEndNum..."
        git push -u origin main
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: git push failed"
            exit $LASTEXITCODE
        }
        Write-Host "Batch $batchStartNum-$batchEndNum pushed successfully"
    } else {
        Write-Host "No changes detected, skipping commit"
    }
}

Write-Host "`nAll batches processed successfully!"