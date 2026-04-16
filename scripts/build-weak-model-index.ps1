param(
    [string]$TargetDir = "."
)

# Очистка старых индексов
Remove-Item "coordination/code_map/*.md" -ErrorAction SilentlyContinue

# Сканирование файлов
$files = Get-ChildItem -Path $TargetDir -Recurse -File -Include "*.ts","*.js","*.py","*.go" | 
         Where-Object { $_.FullName -notmatch "node_modules|dist|.git|.worktrees" }

foreach ($f in $files) {
    $relPath = $f.FullName.Replace((Get-Location).Path, "").TrimStart("")
    $indexFile = "coordination/code_map/" + $f.Name + ".map.md"
    
    # Это шаблон, который слабая модель заполнит, прочитав ОДИН файл
    $content = @"
# File: $relPath
## Primary Responsibility: (FILL ME)
## Exports: (LIST CLASSES/FUNCTIONS)
## Imports: (LIST KEY DEPENDENCIES)
## Context: (LINK TO RELATED FILES)
"@
    Set-Content -Path $indexFile -Value $content
}

Write-Host "Index shells created in coordination/code_map/. Now call the agent to fill them file-by-file."
