function Get-LatestVersion {
    param([string]$packageName)
    try {
        $version = npm view $packageName version --silent
        return $version
    }
    catch {
        Write-Warning "无法获取包 $packageName 的版本信息: $($_.Exception.Message)"
        return "latest"
    }
}

function Format-JsonString {
    param(
        [hashtable]$data,
        [int]$indentLevel = 0
    )
    
    $indent = "  " * $indentLevel
    $nextIndent = "  " * ($indentLevel + 1)
    $lines = @()
    
    # 按照指定顺序定义属性
    $propertyOrder = @("name", "version", "private", "type", "engines", "scripts", 
                      "dependencies", "devDependencies")
    
    $lines += "$indent{"
    
    # 按顺序处理属性
    $propertyCount = 0
    foreach ($prop in $propertyOrder) {
        if ($data.ContainsKey($prop)) {
            $propertyCount++
            $comma = if ($propertyCount -lt $data.Count) { "," } else { "" }
            
            if ($data[$prop] -is [hashtable] -or $data[$prop] -is [System.Collections.Specialized.OrderedDictionary]) {
                # 处理嵌套对象
                $lines += "$nextIndent`"$prop`": {"
                $subCount = 0
                
                # 获取键并保持顺序
                $keys = if ($prop -eq "scripts") {
                    @("dev", "build", "preview", "build-only", "type-check", "format")
                } else {
                    # 对于其他对象，按键名排序
                    $data[$prop].Keys | Sort-Object
                }
                
                foreach ($key in $keys) {
                    if ($data[$prop].ContainsKey($key)) {
                        $subCount++
                        $subComma = if ($subCount -lt $data[$prop].Count) { "," } else { "" }
                        $value = $data[$prop][$key]
                        
                        # 特殊处理build脚本中的引号
                        if ($key -eq "build" -and $value -like "*`"*") {
                            $escapedValue = $value -replace "`"", "\`""
                            $lines += "$nextIndent  `"$key`": `"$escapedValue`"$subComma"
                        } else {
                            $lines += "$nextIndent  `"$key`": `"$value`"$subComma"
                        }
                    }
                }
                $lines += "$nextIndent}$comma"
            }
            elseif ($data[$prop] -is [array]) {
                # 处理数组
                $arrayContent = ($data[$prop] | ForEach-Object { "`"$_`"" }) -join ", "
                $lines += "$nextIndent`"$prop`": [$arrayContent]$comma"
            }
            else {
                # 处理简单值
                $value = $data[$prop]
                if ($value -eq $true -or $value -eq $false) {
                    $lines += "$nextIndent`"$prop`": $($value.ToString().ToLower())$comma"
                } else {
                    $lines += "$nextIndent`"$prop`": `"$value`"$comma"
                }
            }
        }
    }
    
    $lines += "$indent}"
    
    return $lines -join "`n"
}

function Generate-VuePackageJson {
    param(
        [string]$projectName = "my-project"
    )
    
    $dependenciesList = @(
        "@vueuse/core",
        "element-plus",
        "pinia",
        "vue",
        "vue-router"
    )
    
    $devDependenciesList = @(
        "@tsconfig/node22",
        "@types/node",
        "@vitejs/plugin-vue",
        "@vue/tsconfig",
        "npm-run-all2",
        "prettier",
        "typescript",
        "unocss",
        "unplugin-auto-import",
        "unplugin-vue-components",
        "vite",
        "vite-plugin-vue-devtools",
        "vue-tsc"
    )
    
    # 获取依赖的最新版本
    $depsWithVersions = @{}
    Write-Host "正在获取生产依赖的最新版本..." -ForegroundColor Yellow
    foreach ($dep in $dependenciesList) {
        Write-Host "  获取 $dep 版本..." -NoNewline
        $latestVersion = Get-LatestVersion $dep
        
        # 特殊处理@开头的包
        if ($dep.StartsWith("@") -and $latestVersion -eq $dep) {
            # 如果获取失败，尝试使用npm info命令
            try {
                $latestVersion = npm info $dep version --silent
            }
            catch {
                Write-Warning "无法获取包 $dep 的版本信息，使用latest"
                $latestVersion = "latest"
            }
        }
        
        $depsWithVersions[$dep] = if ($latestVersion -like "npm:*" -or $latestVersion -like "*@*") {
            $latestVersion
        } else {
            "^$latestVersion"
        }
        Write-Host " $($depsWithVersions[$dep])" -ForegroundColor Green
    }
    
    $devDepsWithVersions = @{}
    Write-Host "正在获取开发依赖的最新版本..." -ForegroundColor Yellow
    foreach ($devDep in $devDependenciesList) {
        Write-Host "  获取 $devDep 版本..." -NoNewline
        $latestVersion = Get-LatestVersion $devDep
        
        if ($devDep.StartsWith("@") -and $latestVersion -eq $devDep) {
            try {
                $latestVersion = npm info $devDep version --silent
            }
            catch {
                Write-Warning "无法获取包 $devDep 的版本信息，使用latest"
                $latestVersion = "latest"
            }
        }
        
        $devDepsWithVersions[$devDep] = if ($latestVersion -like "npm:*" -or $latestVersion -like "*@*") {
            $latestVersion
        } else {
            "^$latestVersion"
        }
        Write-Host " $($devDepsWithVersions[$devDep])" -ForegroundColor Green
    }
    
    # 特殊处理vite为rolldown版本
    $devDepsWithVersions["vite"] = "npm:rolldown-vite@latest"
    
	$scripts = @{
        "dev" = "vite"
        "build" = 'run-p type-check "build-only {@}" --'
        "preview" = "vite preview"
        "build-only" = "vite build"
        "type-check" = "vue-tsc --build"
        "format" = "prettier --write src/"
    }
    
    $packageJson = [ordered]@{
        name        = $projectName
        version     = "0.0.0"
        private     = $true
        type        = "module"
        engines     = @{
            node = "^20.19.0 || >=22.12.0"
        }
        scripts     = $scripts
        dependencies = $depsWithVersions
        devDependencies = $devDepsWithVersions
    }
    
    return $packageJson
}

function Save-Utf8NoBom {
    param(
        [string]$Content,
        [string]$FilePath
    )
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
}

$projectName = Read-Host "请输入项目名称"
if ([string]::IsNullOrWhiteSpace($projectName)) {
    $projectName = "my-project"
}

Write-Host ""
Write-Host "正在生成项目的 package.json 文件..." -ForegroundColor Green

$packageJson = Generate-VuePackageJson -projectName $projectName

$jsonContent = Format-JsonString -data $packageJson

Save-Utf8NoBom -Content $jsonContent -FilePath "package.json"

Write-Host ""
Write-Host "$(Get-Location)\package.json 已生成"
Write-Host "按任意键退出..." -ForegroundColor Yellow

$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
