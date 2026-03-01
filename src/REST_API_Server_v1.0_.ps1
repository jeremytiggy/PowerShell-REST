Write-Host "[REST_API_Server] Loading Library..." -ForegroundColor Gray
# Windows HTTP REST Server Setup --------------------------------
# HTTP extensions
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Web.Extensions
# HTTP Parameters
$Global:Port = 8832
$Global:Uri = "http://127.0.0.1:$Global:Port/"
# Windows HTTP REST Server Setup ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# REST API Application Information --------------------------------
$Global:appInfo = 	@{
						author = "AUTHOR NAME"
						name = "API NAME" 
						version = "0.0"
					}
# REST API Application Information ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# REST API Data Definitions for Actions ----------------
# Define action categories and their corresponding actions for the REST API
# Each action category has a unique identifier (categoryId) and a human-readable name (categoryName).
# Each action within a category has a unique identifier (actionId) and a human-readable name (actionName).


$Global:ActionCategories = @(
    @{ categoryId = "cat1"; categoryName = "Category 1" },
    @{ categoryId = "cat2"; categoryName = "Category 2" }
)
$Global:ActionDefinitions = @{
    cat1 = @(
        @{ actionId = "cat1action1"; actionName = "Category 1 Action 1" },
        @{ actionId = "cat1action2"; actionName = "Category 1 Action 2" }
    )
    cat2 = @(
        @{ actionId = "cat2action1"; actionName = "Category 2 Action 1" },
        @{ actionId = "cat2action2"; actionName = "Category 2 Action 2" }
    )
}
# REST API Data Definitions for Actions ^^^^^^^^^^^^^^^^
# HTTP Request Handling Functions --------------------------
Write-Host "[REST_API_Server] Parameters registered" -ForegroundColor Green
function Add-CORSHeaders {
    param($Response)
    Write-Host "[Add-CORSHeaders]: Adding CORS headers" -ForegroundColor Gray
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Headers", "*") 
    $Response.Headers.Add("Access-Control-Allow-Methods", "*")
}
Write-Host "[REST_API_Server] function Add-CORSHeaders registered" -ForegroundColor Green
function Send-JSONResponse {
    param($Response, $Data, $StatusCode = 200, $Message = $null)
    
    Add-CORSHeaders -Response $Response
    
    $responseObj = @{}
    if ($Message) {
        $responseObj.message = $Message
    }
    
    if ($Data -ne $null) {
        $responseObj.data = $Data
    } else {
        $responseObj.data = @()  # Empty array if no data
    }
    
    $jsonResponse = $responseObj | ConvertTo-Json -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonResponse)
    
    Write-Host "[Send-JSONResponse]: Sending response - Status: $StatusCode" -ForegroundColor Gray
    Write-Host "[Send-JSONResponse]: Response body: $jsonResponse" -ForegroundColor Gray
    
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json"
    $Response.ContentLength64 = $buffer.Length
    
    $output = $Response.OutputStream
    $output.Write($buffer, 0, $buffer.Length)
    $output.Close()
    
    Write-Host "[Send-JSONResponse]: Response sent successfully" -ForegroundColor Gray
}
Write-Host "[REST_API_Server] function Send-JSONResponse registered" -ForegroundColor Green
function Handle-Request {
    param($Context)
    
    $request = $Context.Request
    $response = $Context.Response
    $url = $request.Url.ToString()
    $localPath = $request.Url.LocalPath
    $method = $request.HttpMethod
    
    Write-Host "[Handle-Request]: Processing request - Method: $method, URL: $url" -ForegroundColor Gray
    
    if ($method -eq "OPTIONS") {
        Write-Host "[Handle-Request]: Handling OPTIONS (preflight) request" -ForegroundColor Magenta
        Add-CORSHeaders -Response $response
        $response.StatusCode = 200
        $response.Close()
        Write-Host "[Handle-Request]: OPTIONS request handled" -ForegroundColor Green
        return
    }
    
    if ($method -eq "POST") {
        Write-Host "[Handle-Request]: Reading POST body..." -ForegroundColor Yellow
        try {
            $stream = $request.InputStream
            $reader = New-Object System.IO.StreamReader($stream, $request.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            Write-Host "[Handle-Request]: POST Body: $body" -ForegroundColor Green
        } catch {
            Write-Host "[Handle-Request]: ERROR reading POST body: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Route the request
    switch -Wildcard ($localPath) {
        "/api/app/info" {
            Write-Host "[Handle-Request]: Routing to App Info" -ForegroundColor Magenta
            if ($method -eq "GET") {
                Send-JSONResponse -Response $response -Data $Global:appInfo
            } else {
                Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
        }
        "/api/features/categories" {
            Write-Host "[Handle-Request]: Routing to Categories" -ForegroundColor Magenta
            if ($method -eq "GET") {
                Send-JSONResponse -Response $response -Data $Global:ActionCategories
            } else {
                Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
        }
        "/api/features/actions" {
            Write-Host "[Handle-Request]: Routing to Actions" -ForegroundColor Magenta
            if ($method -eq "GET") {
                $categoryId = $request.QueryString["categoryId"]
                Write-Host "[Handle-Request]: Query categoryId: $categoryId" -ForegroundColor Yellow
                
                if (-not $categoryId) {
                    Send-JSONResponse -Response $response -Data @() -Message "categoryId parameter is required"
                    return
                }
                
                if (-not $Global:ActionDefinitions.ContainsKey($categoryId)) {
                    Send-JSONResponse -Response $response -Data @() -Message "Category not found"
                    return
                }
                
                Send-JSONResponse -Response $response -Data $Global:ActionDefinitions[$categoryId]
            } else {
                Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
        }
        "/api/features/actions/exec" {
            Write-Host "[Handle-Request]: Routing to Execute Action" -ForegroundColor Magenta
            if ($method -eq "POST") {
                try {
                    $Global:requestData = $body | ConvertFrom-Json
                    Send-JSONResponse -Response $response -Data @()
					Write-Host "[Handle-Request]: Action Data Received." -ForegroundColor Green
					# This is where to trigger the requested action
                } catch {
                    Write-Host "[Handle-Request]:ERROR executing action: $($_.Exception.Message)" -ForegroundColor Red
                    Send-JSONResponse -Response $response -Data @() -Message "Error processing request" -StatusCode 500
                }
            } else {
                Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
        }
        default {
            Write-Host "[Handle-Request]: UNKNOWN ENDPOINT: $localPath" -ForegroundColor Red
            Send-JSONResponse -Response $response -Data $null -Message "Endpoint not found" -StatusCode 404
        }
    }
    
    Write-Host "[Handle-Request]: Request completed: $localPath" -ForegroundColor Green
    
}
Write-Host "[REST_API_Server] function Handle-Request registered" -ForegroundColor Green
function REST_API_SERVER_LibraryLoaded {
    Write-Host "[REST_API_SERVER] Library Loaded" -ForegroundColor Gray
}
Write-Host "[REST_API_Server] Library Loaded" -ForegroundColor Gray
# HTTP Request Handling Functions ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
