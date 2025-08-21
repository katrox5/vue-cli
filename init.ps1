function Get-LatestVersion {
    param([string]$packageName)
    try {
        $version = npm view $packageName version --silent
        return $version
    }
    catch {
        Write-Warning "�޷���ȡ�� $packageName �İ汾��Ϣ: $($_.Exception.Message)"
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
    
    # ����ָ��˳��������
    $propertyOrder = @("name", "version", "private", "type", "engines", "scripts", 
                      "dependencies", "devDependencies")
    
    $lines += "$indent{"
    
    # ��˳��������
    $propertyCount = 0
    foreach ($prop in $propertyOrder) {
        if ($data.ContainsKey($prop)) {
            $propertyCount++
            $comma = if ($propertyCount -lt $data.Count) { "," } else { "" }
            
            if ($data[$prop] -is [hashtable] -or $data[$prop] -is [System.Collections.Specialized.OrderedDictionary]) {
                # ����Ƕ�׶���
                $lines += "$nextIndent`"$prop`": {"
                $subCount = 0
                
                # ��ȡ��������˳��
                $keys = if ($prop -eq "scripts") {
                    @("dev", "build", "preview", "build-only", "type-check", "format")
                } else {
                    # �����������󣬰���������
                    $data[$prop].Keys | Sort-Object
                }
                
                foreach ($key in $keys) {
                    if ($data[$prop].ContainsKey($key)) {
                        $subCount++
                        $subComma = if ($subCount -lt $data[$prop].Count) { "," } else { "" }
                        $value = $data[$prop][$key]
                        
                        # ���⴦��build�ű��е�����
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
                # ��������
                $arrayContent = ($data[$prop] | ForEach-Object { "`"$_`"" }) -join ", "
                $lines += "$nextIndent`"$prop`": [$arrayContent]$comma"
            }
            else {
                # �����ֵ
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
    
    # ��ȡ���������°汾
    $depsWithVersions = @{}
    Write-Host "���ڻ�ȡ�������������°汾..." -ForegroundColor Yellow
    foreach ($dep in $dependenciesList) {
        Write-Host "  ��ȡ $dep �汾..." -NoNewline
        $latestVersion = Get-LatestVersion $dep
        
        # ���⴦��@��ͷ�İ�
        if ($dep.StartsWith("@") -and $latestVersion -eq $dep) {
            # �����ȡʧ�ܣ�����ʹ��npm info����
            try {
                $latestVersion = npm info $dep version --silent
            }
            catch {
                Write-Warning "�޷���ȡ�� $dep �İ汾��Ϣ��ʹ��latest"
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
    Write-Host "���ڻ�ȡ�������������°汾..." -ForegroundColor Yellow
    foreach ($devDep in $devDependenciesList) {
        Write-Host "  ��ȡ $devDep �汾..." -NoNewline
        $latestVersion = Get-LatestVersion $devDep
        
        if ($devDep.StartsWith("@") -and $latestVersion -eq $devDep) {
            try {
                $latestVersion = npm info $devDep version --silent
            }
            catch {
                Write-Warning "�޷���ȡ�� $devDep �İ汾��Ϣ��ʹ��latest"
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
    
    # ���⴦��viteΪrolldown�汾
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

$projectName = Read-Host "��������Ŀ����"
if ([string]::IsNullOrWhiteSpace($projectName)) {
    $projectName = "my-project"
}

Write-Host ""
Write-Host "����������Ŀ�� package.json �ļ�..." -ForegroundColor Green

$packageJson = Generate-VuePackageJson -projectName $projectName

$jsonContent = Format-JsonString -data $packageJson

Save-Utf8NoBom -Content $jsonContent -FilePath "package.json"

Write-Host ""
Write-Host "$(Get-Location)\package.json ������"
Write-Host "��������˳�..." -ForegroundColor Yellow

$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
