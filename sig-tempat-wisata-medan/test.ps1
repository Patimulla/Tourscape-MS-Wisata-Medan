$Headers = @{ 
    'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrc2xmdmN6Z2hzbWlxa290aGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODc3ODYsImV4cCI6MjA5MDU2Mzc4Nn0.uFwuatl1DX8Xlhdb70fhgc7AJrD-OVb5xczOUQ4503Y'
    'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrc2xmdmN6Z2hzbWlxa290aGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODc3ODYsImV4cCI6MjA5MDU2Mzc4Nn0.uFwuatl1DX8Xlhdb70fhgc7AJrD-OVb5xczOUQ4503Y' 
    'Content-Type' = 'text/plain'
}
$Body = "Hello World"
try {
    $response = Invoke-RestMethod -Uri 'https://ekslfvczghsmiqkothdm.supabase.co/storage/v1/object/wisata/wisata/test.txt' -Method POST -Headers $Headers -Body $Body
    $response | ConvertTo-Json
} catch {
    $_.Exception.Response | ConvertTo-Json
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $reader.ReadToEnd()
}
