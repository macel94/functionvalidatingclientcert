using System.Net;
using System.Security.Cryptography.X509Certificates;
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
            _logger.LogInformation("C# HTTP trigger to validate the certificate.");
            // Log all headers
            foreach (var header in req.Headers)
            {
                _logger.LogInformation($"Header '{header.Key}': '{string.Join(",", header.Value)}'");
            }

            var response = req.CreateResponse(HttpStatusCode.OK);

            if (req.Headers.TryGetValues("X-ARR-ClientCert", out var certs))
            {
                byte[] clientCertBytes = Convert.FromBase64String(certs.First());
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

                // Send the decoded certificate multiple fields to the client
                response.WriteString("Subject: " + clientCert.Subject + "\n");
                response.WriteString("Issuer: " + clientCert.Issuer + "\n");
                response.WriteString("Thumbprint: " + clientCert.Thumbprint + "\n");
                response.WriteString("NotBefore: " + clientCert.NotBefore + "\n");
                response.WriteString("NotAfter: " + clientCert.NotAfter + "\n");
                response.WriteString("SerialNumber: " + clientCert.SerialNumber + "\n");
                response.WriteString("PublicKey: " + clientCert.PublicKey + "\n");
                return response;
            }

            response.StatusCode = HttpStatusCode.BadRequest;
            response.WriteString("A valid client certificate is not found");

            return response;
        }
    }
}
