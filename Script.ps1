param($TimeServer = "pool.ntp.org", [Switch]$SetSystemTime = $false)

$startOfEpoch = New-Object -TypeName DateTime -ArgumentList (1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)

# ntp request packet
[byte[]]$ntpData = , 0 * 48

$ntpData[0] = 0x1b # ntp request header

$sock = New-Object `
    -TypeName Net.Sockets.Socket `
    -ArgumentList (
    [Net.Sockets.AddressFamily]::InterNetwork,
    [Net.Sockets.SocketType]::Dgram,
    [Net.Sockets.ProtocolType]::Udp)

$sock.SendTimeout = 2000
$sock.ReceiveTimeout = 2000

try {
    $sock.Connect($TimeServer, 123)
}
catch {
    Write-Error -Message "Failed to connect to server: $TimeServer"
    throw
}

$t1 = Get-Date
$t1ms = ([System.TimeZoneInfo]::ConvertTimeToUtc($t1) - $startOfEpoch).TotalMilliseconds

try {
    [void]$sock.Send($ntpData)
    [void]$sock.Receive($ntpData) 
}
catch {
    Write-Error -Message "Failed to communicate with server: $TimeServer"
    throw
}

$t4 = Get-Date
$t4ms = ([System.TimeZoneInfo]::ConvertTimeToUtc($t4) - $startOfEpoch).TotalMilliseconds

$sock.Shutdown('Both')
$sock.Close()

# Check for leap indicator
$li = ($ntpData[0] -band 0xc0) -shr 6

if ($li -eq 3) {
    throw 'Alarm condition from server (clock not synchronized)'
}

#decode 64-bit ntp time (t2)
$intPart = [BitConverter]::ToUInt32($ntpData[35..32], 0)
$fracPart = [BitConverter]::ToUInt32($ntpData[39..36], 0)

$t2ms = $IntPart * 1000 + ($fracPart * 1000 / 0x100000000)

#again for t3

$intPart = [System.BitConverter]::ToUInt32($ntpData[43..40], 0)
$fracPart = [System.BitConverter]::ToUInt32($ntpData[47..44], 0)

$t3ms = $intPart * 1000 + ($fracPart * 1000 / 0x100000000)

$offset = (($t2ms - $t1ms) + ($t3ms - $t4ms)) / 2

$delay = ($t4ms - $t1ms) - ($t3ms - $t2ms)

$ntpTime = $startOfEpoch.AddMilliseconds($t4ms + $offset).ToLocalTime()

$ntpTimeObj = [PSCustomObject]@{
    PsTypeName    = 'NtpTime'

    NtpServer     = $TimeServer
    NtpTime       = $ntpTime
    Offset        = $offset
    OffsetSeconds = [System.Math]::Round($offset / 1000, 3)
    Delay         = $delay

    LI            = $li

    t1ms          = $t1ms
    t2ms          = $t2ms
    t3ms          = $t3ms
    t4ms          = $t4ms

    t1            = $startOfEpoch.AddMilliseconds($t1ms).ToLocalTime()
    t2            = $startOfEpoch.AddMilliseconds($t2ms).ToLocalTime()
    t3            = $startOfEpoch.AddMilliseconds($t3ms).ToLocalTime()
    t4            = $startOfEpoch.AddMilliseconds($t4ms).ToLocalTime()

    Raw           = $ntpData
}

Write-Verbose -Message "System Time: $t1, NTP Time: $ntpTime"

if ($SetSystemTime) {
    Write-Verbose -Message "Setting system Time to: $ntpTime"
    Invoke-CimMethod `
        -ClassName 'Win32_OperatingSystem' `
        -MethodName 'SetDateTime' `
        -Arguments @{LocalDateTime = $ntpTimeObj.NtpTime.ToLocalTime()}
}

Write-Output $ntpTimeObj
