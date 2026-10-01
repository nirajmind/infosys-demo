$path = "c:\Users\nadhi\source-repos\Infosys-Demo\docs\kong-onprem-gw-test-bkp.yaml"
$reader = [System.IO.File]::OpenText($path)
$lineNum = 0
$keys = [ordered]@{}
$plugins = @{}
$servicesCount = 0
$routesCount = 0
$consumersCount = 0
$upstreamsCount = 0

while ($null -ne ($line = $reader.ReadLine())) {
    $lineNum++
    if ($line -match '^([a-z_]+):') {
        $k = $matches[1]
        if (-not $keys.Contains($k)) {
            $keys[$k] = $lineNum
        }
    }
    if ($line -match '^\s+-\s+name:\s+([a-zA-Z0-9_-]+)') {
        $p = $matches[1]
        if ($plugins.ContainsKey($p)) { $plugins[$p]++ } else { $plugins[$p] = 1 }
    }
    if ($line -match '^\s+name:\s+') {
        # Check context
    }
    if ($line -match '^services:') {
        $inServices = $true
    }
}
$reader.Close()

Write-Output "--- ROOT KEYS & STARTING LINES ---"
$keys.GetEnumerator() | Format-Table -AutoSize

Write-Output "--- TOP PLUGINS FOUND ---"
$plugins.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | Format-Table -AutoSize
