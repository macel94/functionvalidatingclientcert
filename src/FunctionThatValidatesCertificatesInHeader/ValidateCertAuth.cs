using System.Net;
using System.Security.Cryptography.X509Certificates;
using Azure;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace FunctionThatValidatesCertificatesInHeader
{
    public class ValidateCertAuth
    {
        private readonly ILogger _logger;
        public ValidateCertAuth(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<DefaultFunction>();
        }

        [Function(nameof(ValidateCertAuth))]
        public HttpResponseData RandomStringCertAuth(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req)
        {
            try
            {
                _logger.LogInformation("C# HTTP trigger to validate the certificate.");
                // Log all headers
                foreach (var header in req.Headers)
                {
                    _logger.LogInformation($"Header '{header.Key}': '{string.Join(",", header.Value)}'");
                }

                var response = req.CreateResponse(HttpStatusCode.OK);

                if (req.Headers.TryGetValues("x-forwarded-client-cert", out var certs))
                {
                    _logger.LogInformation($"Found {certs.Count()} certificates in the header");
                    foreach (var certHeaderValue in certs)
                    {
                        // Extract the certificate part
                        var startIndex = certHeaderValue.IndexOf("-----BEGIN CERTIFICATE-----", StringComparison.Ordinal);
                        var endIndex = certHeaderValue.IndexOf("-----END CERTIFICATE-----", StringComparison.Ordinal) + "-----END CERTIFICATE-----".Length;
                        if (startIndex >= 0 && endIndex >= 0)
                        {
                            var encodedCert = certHeaderValue.Substring(startIndex, endIndex - startIndex);

                            // Decode the URL-encoded certificate
                            var decodedCert = WebUtility.UrlDecode(encodedCert);
                            string certData = decodedCert.Replace("-----BEGIN CERTIFICATE-----", "")
                                                         .Replace("-----END CERTIFICATE-----", "")
                                                         .Trim();

                            // Convert to certificate object
                            byte[] clientCertBytes = Convert.FromBase64String(certData);
                            X509Certificate2 clientCert = new X509Certificate2(clientCertBytes);

                            // Validate Thumbprint  
                            //if (clientCert.Thumbprint != "yourthumprint")
                            //{
                            //    response.StatusCode = HttpStatusCode.BadRequest;
                            //    response.WriteString("A valid client certificate was not used");
                            //    return response;
                            //}

                            // Validate NotBefore and NotAfter  
                            //if (DateTime.Compare(DateTime.UtcNow, clientCert.NotBefore) < 0
                            //            || DateTime.Compare(DateTime.UtcNow, clientCert.NotAfter) > 0)
                            //{
                            //    return new BadRequestObjectResult("client certificate not in alllowed time interval");
                            //}

                            //// Add further validation of certificate as required.  

                            //return new OkObjectResult(GetEncodedRandomString());

                            // Send the decoded certificate multiple fields to the client, for example
                            response.WriteString("Subject: " + clientCert.Subject + "\n");
                            response.WriteString("Issuer: " + clientCert.Issuer + "\n");
                            response.WriteString("Thumbprint: " + clientCert.Thumbprint + "\n");
                            response.WriteString("NotBefore: " + clientCert.NotBefore + "\n");
                            response.WriteString("NotAfter: " + clientCert.NotAfter + "\n");
                            response.WriteString("SerialNumber: " + clientCert.SerialNumber + "\n");
                            response.WriteString("PublicKey: " + clientCert.PublicKey + "\n");
                            response.WriteString("\n");
                        }
                        else
                        {
                            response.WriteString("Could not decode certificate with value: " + certHeaderValue);
                        }
                    }

                    return response;
                }

                response.StatusCode = HttpStatusCode.BadRequest;
                response.WriteString("A valid client certificate is not found");

                return response;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error validating certificate");
                return req.CreateResponse(HttpStatusCode.InternalServerError);
            }
        }
    }
}
