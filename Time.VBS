Option Explicit
 
Dim arrDateTime
Dim blnTest
Dim dtmDateTime, dtmNewDateTime
Dim intDateDiff, intOffset, intStatus, intThreshold, intTimeDiff
dim colItems, objHTTP, objItem, objRE, objWMIService
Dim strDateTime, strLocalDateTime, strMsg, strNewdateTime, strURL
 
' Defaults
intThreshold = 10
strURL       = "http://time.gov"
 
' Check command line arguments
With WScript.Arguments
	If .Named.Count   > 0 Then Syntax
	If .Unnamed.Count > 2 Then Syntax
	If .Unnamed.Count > 0 Then
		If IsNumeric( .Unnamed(0) ) Then
			intThreshold = CInt( .Unnamed(0) )
		Else
			strURL = .Unnamed(0)
		End If
	End If
	If .Unnamed.Count = 2 Then
		If IsNumeric( .Unnamed(1) ) Then
			intThreshold = CInt( .Unnamed(1) )
		Else
			strURL = .Unnamed(1)
		End If
		' Only 1 argument should be numeric, not both
		If IsNumeric( .Unnamed(0) ) And IsNumeric( .Unnamed(1) ) Then
			Syntax
		End If
		' 1 argument should be numeric
		If Not ( IsNumeric( .Unnamed(0) ) Or IsNumeric( .Unnamed(1) ) ) Then
			Syntax
		End If
	End If
	' Threshold value must be between 0 and 60
	If intThreshold <  0 Then Syntax
	If intThreshold > 60 Then Syntax
	' URL must be a WEB server (full URL including protocol)
	blnTest = False
	Set objRE = New RegExp
	objRE.Pattern = "^https?://.+$"
	blnTest = objRE.Test( strURL )
	Set objRE = Nothing
	If Not blnTest Then Syntax
End With
 
' Get server time from a web server
Set objHTTP = CreateObject( "WinHttp.WinHttpRequest.5.1" )
objHTTP.Open "GET", strURL, False
objHTTP.SetRequestHeader "User-Agent", WScript.ScriptName
On Error Resume Next
objHTTP.Send
intStatus   = objHTTP.Status
strDateTime = objHTTP.GetResponseHeader( "Date" )
Set objHTTP = Nothing
If Err Then Syntax
On Error Goto 0
 
' Abort if the server could not be reached
If intStatus <> 200 Then Syntax
 
' Convert the returned Apache timestamp string to a date to work with
arrDateTime = Split( strDateTime, " " )
strDateTime = arrDateTime(1) & " " _
            & arrDateTime(2) & " " _
            & arrDateTime(3) & " " _
            & arrDateTime(4)
dtmDateTime = CDate( strDateTime )
strDateTime = Year( dtmDateTime ) _
            & Right( "0" & Month(  dtmDateTime ), 2 ) _
            & Right( "0" & Day(    dtmDateTime ), 2 ) _
            & Right( "0" & Hour(   dtmDateTime ), 2 ) _
            & Right( "0" & Minute( dtmDateTime ), 2 ) _
            & Right( "0" & Second( dtmDateTime ), 2 )
 
' Get and set local system date and time
Set objWMIService = GetObject( "winmgmts:{(Systemtime)}//./root/CIMV2" )
Set colItems      = objWMIService.ExecQuery( "Select * From Win32_OperatingSystem" )
For Each objItem In colItems
	' Get timezone offset telative to GMT
	intOffset        = CInt( objItem.CurrentTimeZone )
	' Get current local system time ("before" time)
	strLocalDateTime = objItem.LocalDateTime
	' Add offset to GMT to get correct local time
	dtmNewDateTime   = DateAdd( "n", intOffset, dtmDateTime )
	' Format date and time string to be used to set new system time
	strNewdateTime   = Year( dtmNewDateTime ) _
	                 & Right( "0" & Month(  dtmNewDateTime ), 2 ) _
	                 & Right( "0" & Day(    dtmNewDateTime ), 2 ) _
	                 & Right( "0" & Hour(   dtmNewDateTime ), 2 ) _
	                 & Right( "0" & Minute( dtmNewDateTime ), 2 ) _
	                 & Right( "0" & Second( dtmNewDateTime ), 2 )
	If intOffset < 0 Then
		strNewdateTime = strNewdateTime & ".000000-" & Right( CStr( intOffset - 1000 ), 3 )
	Else
		strNewdateTime = strNewdateTime & ".000000+" & Right( CStr( intOffset + 1000 ), 3 )
	End If
	' Check difference between local and server date and time
	intDateDiff = CLng( Left( strLocalDateTime, 8 ) )    - CLng( Left( strNewdateTime, 8 ) )
	intTimeDiff = CLng( Mid(  strLocalDateTime, 9, 6 ) ) - CLng( Mid(  strNewdateTime, 9, 6 ) )
	If Abs( intTimeDiff ) > intThreshold And intDateDiff = 0 Then
		' Set new date and time
		objItem.SetDateTime strNewdateTime
		' Display "before" and "after" time
		strMsg = "Synchronized:"   & vbCrLf _
		       & "Before:" & vbTab & strLocalDateTime & vbCrLf _
		       & "After: " & vbTab & strNewdateTime
	Else
		' Display "local" and "server" time
		strMsg = "Skipped synchronization (threshold " & intThreshold & " second"
		If intThreshold > 1 Then strMsg = strMsg  & "s"
		strMsg = strMsg & ")" & vbCrLf _
		       & "Local: "    & vbTab & strLocalDateTime & vbCrLf _
		       & "Server:"    & vbTab & strNewdateTime
	End If
	WScript.Echo strMsg
Next
Set colItems      = Nothing
Set objWMIService = Nothing
 
 
Sub Syntax( )
	Dim strMsg
	strMsg = vbCrLf _
	       & WScript.ScriptName & ", Version 1.00" _
	       & vbCrLf _
	       & "Synchronize the local system date and time with a web server" _
	       & vbCrLf & vbCrLf _
	       & "Usage:" & vbTab & WScript.ScriptName & "  [ server ]  [ seconds ]" _
	       & vbCrLf & vbCrLf _
	       & "Where:" & vbTab & "server " & vbtab & "is the URL of the web server to synchronize date" _
	       & vbCrLf _
	       & "      " & vbTab & "       " & vbTab & "and time with (default: http://www.xs4all.nl/)" _
	       & vbCrLf _
	       & "      " & vbTab & "seconds" & vbTab & "is the threshold in seconds (i.e. if the difference" _
	       & vbCrLf _ 
	       & "      " & vbTab & "       " & vbTab & "between the current and new time is less, skip" _
	       & vbCrLf _
	       & "      " & vbTab & "       " & vbTab & "synchronization; 0..60, default: 10)" _
	       & vbCrLf & vbCrLf _
	       & "Written by Rob van der Woude" _
	       & vbCrLf _
	       & "http://www.robvanderwoude.com"
	WScript.Echo strMsg
	WScript.Quit 1
End Sub
