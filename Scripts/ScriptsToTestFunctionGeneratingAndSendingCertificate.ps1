# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
# Generate the certificate
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My"

# Define the export path
$exportPath = ".\cert.cer"

# Export the certificate to the specified folder
Export-Certificate -Cert "cert:\LocalMachine\My\$($cert.Thumbprint)" -FilePath $exportPath

# Read and convert the certificate to Base64
$certBytes = Get-Content -Path $exportPath -Encoding Byte
$base64Cert = [System.Convert]::ToBase64String($certBytes)

# Prepare the header with the Base64 encoded certificate
$headers = @{
    "X-ARR-ClientCert" = $base64Cert
}

# Invoke the API request with the certificate in the header
$response = Invoke-RestMethod -Uri "http://localhost:7164/api/ValidateCertAuth" -Method Get -Headers $headers

$response

# Output the status code
$response.StatusCode

# Output the headers
$response.Headers

# Output the response content
$response.Content