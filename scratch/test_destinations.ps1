$token = '6934b1c2291ff9ef3886bf70adb20c0b229d1a99'
$headers = @{ 'Authorization' = "METToken $token" }
$jsonRaw = Get-Content -Raw -Path "c:\Users\Wei Ren\StudioProjects\HappyWay\assets\data\met_locations.json"
$locations = $jsonRaw | ConvertFrom-Json

$queries = @('Port Dickson', 'Ipoh', 'Johor Bahru', 'Kota Kinabalu', 'Muar', 'Taiping')
$today = (Get-Date).ToString("yyyy-MM-dd")
$tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")

foreach ($q in $queries) {
    Write-Host "================== Testing Search for: '$q' =================="
    $matches = $locations | Where-Object { $_.name -like "*$q*" -or $_.state -like "*$q*" }
    Write-Host "Found $($matches.Count) match(es):"
    $matches | Format-Table id, name, locationcategoryid, state, latitude, longitude -AutoSize

    if ($matches.Count -gt 0) {
        $first = $matches[0]
        Write-Host "Fetching Live Official Forecast for $($first.name) [$($first.id)]..."
        $uri = "https://api.met.gov.my/v2.1/data?datasetid=FORECAST&datacategoryid=GENERAL&locationid=$($first.id)&start_date=$today&end_date=$tomorrow"
        try {
            $res = Invoke-RestMethod -Uri $uri -Headers $headers
            Write-Host "Forecast Items Returned: $($res.results.Count)"
            if ($res.results.Count -gt 0) {
                $todayResults = $res.results | Where-Object { $_.date -like "$today*" }
                $todayResults | Format-Table date, datatype, value -AutoSize
            }
        } catch {
            Write-Host "Error fetching forecast: $_"
        }
    }
}
