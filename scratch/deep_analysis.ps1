$path = "c:\Users\nadhi\source-repos\Infosys-Demo\docs\kong-onprem-gw-test-bkp.yaml"
$reader = [System.IO.File]::OpenText($path)
$lineNum = 0

$services = 0
$routes = 0
$upstreams = 0
$targets = 0
$globalPlugins = @()
$routePlugins = @{}
$currentService = ""
$inGlobalPlugins = $false
$inServices = $false
$inUpstreams = $false

while ($null -ne ($line = $reader.ReadLine())) {
    $lineNum++
    if ($line -match '^plugins:') { $inGlobalPlugins = $true; continue }
    if ($line -match '^services:') { $inGlobalPlugins = $false; $inServices = $true; continue }
    if ($line -match '^upstreams:') { $inServices = $false; $inUpstreams = $true; continue }
    
    if ($inGlobalPlugins) {
        if ($line -match '^\s+-\s+name:\s+([a-zA-Z0-9_-]+)') {
            $globalPlugins += $matches[1]
        }
    }
    if ($inServices) {
        if ($line -match '^- connect_timeout:' -or $line -match '^- host:') {
            $services++
        }
        if ($line -match '^\s+-\s+paths:' -or $line -match '^\s+-\s+hosts:') {
            $routes++
        }
        if ($line -match '^\s+name:\s+([a-zA-Z0-9_-]+)') {
            $p = $matches[1]
            if ($p -notin @("CCPServices", "v0", "none", "round-robin")) {
                if ($routePlugins.ContainsKey($p)) { $routePlugins[$p]++ } else { $routePlugins[$p] = 1 }
            }
        }
    }
    if ($inUpstreams) {
        if ($line -match '^- algorithm:') {
            $upstreams++
        }
        if ($line -match '^\s+-\s+target:') {
            $targets++
        }
    }
}
$reader.Close()

Write-Output "=== ENTITY COUNTS ==="
Write-Output "Services: $services"
Write-Output "Routes: $routes"
Write-Output "Upstreams: $upstreams"
Write-Output "Targets: $targets"

Write-Output "`n=== GLOBAL PLUGINS (Line 21 to 542) ==="
$globalPlugins | ForEach-Object { Write-Output "  - $_" }

Write-Output "`n=== ROUTE / SERVICE LEVEL PLUGINS (Frequency) ==="
$routePlugins.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | Format-Table -AutoSize
