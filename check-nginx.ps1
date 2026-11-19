$ExpectedContainers = @{
    www1 = 5001
    www2 = 5002
    www3 = 5003
    www4 = 5004
    www5 = 5005
}

foreach ($Entry in $ExpectedContainers.GetEnumerator() | Sort-Object Name) {
    $Name = $Entry.Name
    $Port = $Entry.Value
    $Running = docker inspect --format '{{.State.Running}}' $Name 2>$null
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:$Port" -UseBasicParsing -TimeoutSec 5
        $HttpStatus = $Response.StatusCode
    } catch {
        $HttpStatus = "FAILED"
    }
    [PSCustomObject]@{ Container=$Name; Port=$Port; Running=$Running; HTTP=$HttpStatus }
}
