Write-Host "[REST_API_Server] Loading Library..." -ForegroundColor Gray

# USER AND APPLICATION SPECIFIC DATA ------------------------------
# Copy this section into your script to overwrite these values with application specific values
# Windows HTTP REST Server Setup --------------------------------
# HTTP Parameters (Required)
$Global:REST_Server_Port = 8832
$Global:REST_Server_Uri = "http://127.0.0.1:$Global:REST_Server_Port/"
# Partner Process Name (Optional)
$Global:REST_Client_processName = "ProcessName"
# REST API Application Information (Required)
$Global:REST_API_appInfo = 	@{
						author = "AUTHOR NAME"
						name = "API NAME" 
						version = "0.0"
					}
Write-Host "[REST_API_Server] Parameters registered. May be overwritten." -ForegroundColor Yellow
# REST API Data Definitions for Actions (Required)
# Define action categories and their corresponding actions for the REST API
# Each action category has a unique identifier (categoryId) and a human-readable name (categoryName).
# Each action within a category has a unique identifier (actionId) and a human-readable name (actionName).
# Replace with your own definitions

$Global:REST_API_Actions = @{
    cat1 = @{
        categoryId   = "cat1"
        categoryName = "Category 1"

        actions = @{
            cat1action1 = @{
                actionId    = "cat1action1"
                actionName  = "Action 1"
				applicationData = ""
            }

            cat1action2 = @{
                actionId    = "cat1action2"
                actionName  = "Action 2"
				applicationData = ""
            }
        }
    }

    cat2 = @{
        categoryId   = "cat2"
        categoryName = "Category 2"

        actions = @{
            cat2action1 = @{
                actionId    = "cat2action1"
                actionName  = "Action 1"
				applicationData = ""
            }

            cat2action2 = @{
                actionId    = "cat2action2"
                actionName  = "Action 2"
                applicationData = ""
            }
        }
    }
}

$Global:REST_API_JSON_ExecuteThirdPartyAction = @'
{
  "categoryId": "categoryId",
  "actionId": "actionId",
  "context": {
    "applicationData": "applicationData"
  }
}
'@

Write-Host "[REST_API_Server] Action Categories & Definitions registered. May be overwritten." -ForegroundColor Yellow
# REST API Data Definitions for Actions ^^^^^^^^^^^^^^^^
# Function to Run on REST Action (Required)
# Put your code that performs your desired activity for this plug-in
function REST_API_Application-Specific-Action {
	#Overwrite this function with your own function to execute when a valid REST action is received
	#Example:
	if ($null -ne $Global:REST_API_clientActionData.context.applicationData) {
		$Global:REST_API_Action_applicationData = $Global:REST_API_clientActionData.context.applicationData
		Write-Host "[REST_API_Application-Specific-Action]: applicationData: $($Global:REST_API_Action_applicationData)"
	}
	
	$Global:REST_API_Action_ApplicationDataAvailable = $true
}
Write-Host "[REST_API_Server] REST_API_Application-Specific-Action registered. May be overwritten." -ForegroundColor Yellow
# Windows HTTP REST Server Setup ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# Important Global Parameters
$Global:REST_Server_Running = $false 		# Server Status
$Global:REST_Server_Listener = $null				# HTTP Handler Object
$Global:REST_Server_Debug = $false
$Global:REST_API_clientActionData = $null				# Client Data received during Event Action
$Global:REST_API_Action_categoryId = ""
$Global:REST_API_Action_actionId = ""
$Global:REST_API_Action = $null
$Global:REST_API_Action_Category = $null
$Global:REST_API_Action_ApplicationDataAvailable = $false
$Global:REST_API_Action_Executed = $false
$Global:REST_API_Debug = $true
# USER AND APPLICATION SPECIFIC DATA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


# Helper Functions ---------------------
function Show-ObjectProperties {
    param(
        [Parameter(Mandatory)]
        [psobject]$Obj,
        [int]$Indent = 0
    )

	if ($Obj -is [hashtable] -or -not ($Obj -is [PSCustomObject])) {
    try {
        $ObjJSON = $Obj | ConvertTo-Json
		$Obj = $ObjJSON | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to normalize object for display: $($_.Exception.Message)"
    }
}

    $prefix = " " * ($Indent * 4)  # 4 spaces per level

    foreach ($prop in $Obj.PSObject.Properties) {
        if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
            Write-Host "$prefix$($prop.Name):" -ForegroundColor Gray
            Show-ObjectProperties -Obj $prop.Value -Indent ($Indent + 1)
        }
        elseif ($prop.Value -is [System.Collections.IEnumerable] -and -not ($prop.Value -is [string])) {
            Write-Host "$prefix$($prop.Name):" -ForegroundColor Gray
            foreach ($item in $prop.Value) {
                if ($item -is [PSCustomObject]) {
                    Show-ObjectProperties -Obj $item -Indent ($Indent + 1)
                }
                else {
                    Write-Host "$prefix    $item" -ForegroundColor DarkGray
                }
            }
        }
        else {
            Write-Host "$prefix$($prop.Name): $($prop.Value)" -ForegroundColor Gray
        }
    }
}
Write-Host "[REST_API_Server] function Show-ObjectProperties registered" -ForegroundColor Green
# Helper Functions ^^^^^^^^^^^^^^^^^^^^^
# HTTP Request Handling Functions --------------------------
# HTTP extensions
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Web.Extensions
function REST_Server_Startup {
    if ($Global:REST_Server_Debug -eq $false) {
		Write-Host "[REST Server Startup]: Enable Server Debugging Messages?" -ForegroundColor Cyan
		Write-Host -NoNewLine "[Enter Command (yes|no)]:> "
		$enableServerDebugging = Read-Host
		if ($enableServerDebugging -eq 'yes') { $Global:REST_Server_Debug = $true }
	}
	if ($Global:REST_Server_Debug) {
		Write-Host "[REST Server Startup]: Port: $($Global:REST_Server_Port)" -ForegroundColor Cyan
		Write-Host "[REST Server Startup]: URI: $($Global:REST_Server_Uri)" -ForegroundColor Cyan
		Write-Host "[REST Server Startup]: Process: $($Global:REST_Client_processName)" -ForegroundColor Cyan
		Write-Host "[REST Server Startup]: appInfo: $($Global:REST_API_appInfo.name) version $($Global:REST_API_appInfo.version) by $($Global:REST_API_appInfo.author)"
	}
	
    $ProcessName = $Global:REST_Client_processName
    $processRunning = (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
	if ($Global:REST_Server_Debug) {
		if ($processRunning) { Write-Host "[REST Server Startup]: $ProcessName is running" -ForegroundColor Green }
		else { Write-Host "[REST Server Startup]: WARNING - $ProcessName is not running" -ForegroundColor Yellow }	
	}
	
    if ($Global:REST_Server_Running -ne $true) {
        if ($processRunning) {
            Write-Host "[REST Server Startup]: Since $ProcessName is running, it's recommended to start the server to enable connectivity." -ForegroundColor Green
        } else {
            Write-Host "[REST Server Startup]: Since $ProcessName is not running, starting the server may not provide connectivity." -ForegroundColor Yellow
            Write-Host "[REST Server Startup]: You can still continue in offline mode and enter the Event Data manually."
        }
        Write-Host "[REST Server Startup]: Would you like to start the server, or work offline?"
        Write-Host -NoNewLine "[Enter Command (start|offline|exit)]:> "
        $cmd = Read-Host
        if ($cmd -eq '') { exit 1 }
        if ($cmd -ne '') {
	        if ($cmd -eq 'exit') { exit 1 }
	        elseif ($cmd -eq 'start') { 
                # Create HTTP Listener
                $Global:REST_Server_Listener = New-Object System.Net.HttpListener
                $Global:REST_Server_Listener.Prefixes.Add($Global:REST_Server_Uri)
                # Start Listener
                try {
                    $Global:REST_Server_Listener.Start()
                    if ($Global:REST_Server_Debug) { Write-Host "[REST Server Startup]: Listener started successfully!" -ForegroundColor Green }
                } catch {
                    Write-Host "[REST Server Startup]: FAULT - Failed to start: $($_.Exception.Message)" -ForegroundColor Red
                    exit 1
                }
                # Server Running Flags
                $Global:REST_Server_Running = $true                
            }
            elseif ($cmd -eq 'offline') { 
                Write-Host "[REST Server Startup]: Continuing in offline mode. No $ProcessName connectivity." -ForegroundColor Yellow
            }
	        else { 
                Write-Host '[REST Server Startup]: Exiting...' -ForegroundColor Yellow
                exit 1
            }
        } # end processing user choice
    } # end if ($Global:REST_Server_Running -ne $true)

} # end function WindowsHTTPRESTServerStartup
function REST_Server_Add-CORSHeaders {
    param($Response)
    if ($Global:REST_Server_Debug) { Write-Host "[REST_Server_Add-CORSHeaders]: DEBUG - Adding CORS headers" -ForegroundColor Gray}
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Headers", "*") 
    $Response.Headers.Add("Access-Control-Allow-Methods", "*")
}
Write-Host "[REST_API_Server] function REST_Server_Add-CORSHeaders registered" -ForegroundColor Green
function REST_Server_Send-JSONResponse {
    param($Response, $Data, $StatusCode = 200, $Message = $null)
    
    REST_Server_Add-CORSHeaders -Response $Response
    
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
    
    if ($Global:REST_API_Debug) {
		Write-Host "[REST_Server_Send-JSONResponse]: DEBUG - Sending response - Status: $StatusCode" -ForegroundColor Gray
		Write-Host "[REST_Server_Send-JSONResponse]: DEBUG - Response body: $jsonResponse" -ForegroundColor Gray
	}
    
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json"
    $Response.ContentLength64 = $buffer.Length
    
    $output = $Response.OutputStream
    $output.Write($buffer, 0, $buffer.Length)
    $output.Close()
    
    if ($Global:REST_API_Debug) { Write-Host "[REST_Server_Send-JSONResponse]: DEBUG - Response sent successfully" -ForegroundColor Gray }
}
Write-Host "[REST_API_Server] function REST_Server_Send-JSONResponse registered" -ForegroundColor Green
function REST_API_Execute-REST-Action {
	if ($Global:REST_API_Debug) {
		Write-Host "[REST_API_Execute-REST-Action]: DEBUG - Remote Request Data: " -ForegroundColor Gray
		Show-ObjectProperties -Obj $Global:REST_API_clientActionData	
		Write-Host "[REST_API_Execute-REST-Action]: DEBUG - Locally Defined Action: " -ForegroundColor Gray
		Show-ObjectProperties -Obj $Global:REST_API_Action
	}
	if ($Global:REST_API_Debug) { Write-Host "[REST_API_Execute-REST-Action]: Executing Application Specific Action" -ForegroundColor White }
	#Overwrite this function with whatever you want to execute	
	REST_API_Application-Specific-Action
}
Write-Host "[REST_API_Server] function REST_API_Execute-REST-Action registered" -ForegroundColor Green
function REST_API_Validate-Requested-Action {
	param($RequestedActionData)
	
	#until validated, the category and action are null
	$Global:REST_API_Action_categoryId = $null
	$Global:REST_API_Action_actionId = $null
	$Global:REST_API_Action_Category = $null
	$Global:REST_API_Action = $null
	# Invalid if either categoryId or actionId is null
	$nullRequestError = $false
	$categoryId = $RequestedActionData.categoryId
	if ($null -eq $categoryId) {
		Write-Host "[REST_API_Validate-Requested-Action]: FAULT - REST Action Request missing .categoryId" -ForegroundColor Red
		$nullRequestError = $true
	} else {
		if ($Global:REST_API_Debug) { Write-Host "[REST_API_Validate-Requested-Action]: DEBUG - REST Action Requested  categoryId: $($categoryId)" -ForegroundColor Gray }
	}
	$actionId   = $RequestedActionData.actionId
	if ($null -eq $actionId) {
		Write-Host "[REST_API_Validate-Requested-Action]: FAULT - REST Action Request missing .actionId" -ForegroundColor Red
		$nullRequestError = $true
	} else {
		if ($Global:REST_API_Debug) { Write-Host "[REST_API_Validate-Requested-Action]: DEBUG - REST Action Requested  actionId: $($actionId)" -ForegroundColor Gray }
	}
	if ($nullRequestError) {
		return $false
	}

	#invalidate if no matching Category
    $category = $Global:REST_API_Actions[$categoryId]
    if ($null -eq $category) {
		Write-Host "[REST_API_Validate-Requested-Action]: FAULT - No matching category for categoryId $($categoryId)" -ForegroundColor Red
		return $false
	}
	#Invalidate if no matching Action
	$action = $category.actions[$actionId]
	if ($null -eq $action) {
		Write-Host "[REST_API_Validate-Requested-Action]: FAULT - No matching action found for categoryId: $($categoryId) and actionId: $($actionId)" -ForegroundColor Red
		return $false
	}
	else {
		#validated
		if ($Global:REST_API_Debug) { Write-Host "[REST_API_Validate-Requested-Action]: INFO - Requested Action Validated" -ForegroundColor Green }
		$Global:REST_API_Action_categoryId = $categoryId
		$Global:REST_API_Action_actionId = $actionId
		$Global:REST_API_Action_Category = $category
		$Global:REST_API_Action = $action
		return $true
	}
	#just in case
	return $false
}
Write-Host "[REST_API_Server] function REST_API_Validate-Requested-Action registered" -ForegroundColor Green
function REST_API_Process-clientActionData {
	$Global:REST_API_Action_ApplicationDataAvailable = $false
	$Global:REST_API_Action_Executed = $false
	$validRESTactionRequest = REST_API_Validate-Requested-Action -RequestedActionData $Global:REST_API_clientActionData
	if ($validRESTactionRequest) {
		if ($Global:REST_API_Debug) { Write-Host "[REST_API_Process-clientActionData]: DEBUG - Valid Action reference from REST client." -ForegroundColor Gray }
		REST_API_Execute-REST-Action
		$Global:REST_API_Action_Executed = $true
	} else {
		Write-Host "[REST_API_Process-clientActionData]: FAULT - Invalid Action reference from REST client." -ForegroundColor Red
	}
}
Write-Host "[REST_API_Server] function REST_API_Process-clientActionData registered" -ForegroundColor Green
function REST_API_Handle-Request {
    param($Context)
    
    $request = $Context.Request
    $response = $Context.Response
    $url = $request.Url.ToString()
    $localPath = $request.Url.LocalPath
    $method = $request.HttpMethod
    
    if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Processing request - Method: $method, URL: $url" -ForegroundColor Gray }
    
    if ($method -eq "OPTIONS") {
        if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Handling OPTIONS (preflight) request" -ForegroundColor Gray }
        REST_Server_Add-CORSHeaders -Response $response
        $response.StatusCode = 200
        $response.Close()
        if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: INFO - OPTIONS request serviced" -ForegroundColor White }
        return
    }
    
    if ($method -eq "POST") {
        if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Reading POST body..." -ForegroundColor Gray }
        try {
            $stream = $request.InputStream
            $reader = New-Object System.IO.StreamReader($stream, $request.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - POST Body: $body" -ForegroundColor Gray }
			
        } catch {
            Write-Host "[REST_API_Handle-Request]: FAULT - ERROR reading POST body: $($_.Exception.Message)" -ForegroundColor Red
        }
		if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: INFO - POST Body Read Completed" -ForegroundColor White }
    }
    
    # Route the request
    switch -Wildcard ($localPath) {
        "/api/app/info" {
            if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - App Info Requested" -ForegroundColor Gray }
            if ($method -eq "GET") {
                REST_Server_Send-JSONResponse -Response $response -Data $Global:REST_API_appInfo
				
            } else {
                REST_Server_Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
			Write-Host "[REST_API_Handle-Request]: INFO - App Info Request serviced" -ForegroundColor White
        }
        "/api/features/categories" {
            if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Action Categories Info Requested" -ForegroundColor Gray }
            if ($method -eq "GET") {
				$categories = foreach ($cat in $Global:REST_API_Actions.Values) 
				{
					[PSCustomObject]@{
						categoryId   = $cat.categoryId
						categoryName = $cat.categoryName
					}	
				}
				if ($Global:REST_API_Debug) { Show-ObjectProperties -Obj $categories }
				REST_Server_Send-JSONResponse -Response $response -Data $categories
				
            } else {
                REST_Server_Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
			Write-Host "[REST_API_Handle-Request]: INFO - Action Category Info Request serviced" -ForegroundColor White
        }
        "/api/features/actions" {
            if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Actions List for Category Requested" -ForegroundColor Gray }
            if ($method -eq "GET") {
                $categoryId = $request.QueryString["categoryId"]
                if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Query categoryId: $categoryId" -ForegroundColor Gray }
                
                if (-not $categoryId) {
                    REST_Server_Send-JSONResponse -Response $response -Data @() -Message "categoryId parameter is required"
                    return
                }
                
                if (-not $Global:REST_API_Actions.ContainsKey($categoryId)) {
                    REST_Server_Send-JSONResponse -Response $response -Data @() -Message "Category not found"
                    return
                }
                $actions = foreach ($act in $Global:REST_API_Actions[$categoryId].actions.Values) 
				{
					[PSCustomObject]@{
						actionId   = $act.actionId
						actionName = $act.actionName
					}	
				}
				if ($Global:REST_API_Debug) { Show-ObjectProperties -Obj $actions }
                REST_Server_Send-JSONResponse -Response $response -Data $actions
            } else {
                REST_Server_Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
			Write-Host "[REST_API_Handle-Request]: INFO - Actions List for Category Request serviced" -ForegroundColor White
        }
        "/api/features/actions/exec" {
            if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Execute Action Requested" -ForegroundColor Gray }
            if ($method -eq "POST") {
                try {
                    $Global:REST_API_clientActionData = $body | ConvertFrom-Json
                    REST_Server_Send-JSONResponse -Response $response -Data @()
					if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Action Data Received." -ForegroundColor Gray }
					REST_API_Process-clientActionData
                } catch {
                    Write-Host "[REST_API_Handle-Request]: FAULT - ERROR executing action: $($_.Exception.Message)" -ForegroundColor Red
                    REST_Server_Send-JSONResponse -Response $response -Data @() -Message "Error processing request" -StatusCode 500
                }
            } else {
                REST_Server_Send-JSONResponse -Response $response -Data $null -Message "Method not allowed" -StatusCode 405
            }
			Write-Host "[REST_API_Handle-Request]: INFO - Execute Action Request serviced" -ForegroundColor White
        }
        default {
            Write-Host "[REST_API_Handle-Request]: FAULT - UNKNOWN ENDPOINT: $localPath" -ForegroundColor Red
            REST_Server_Send-JSONResponse -Response $response -Data $null -Message "Endpoint not found" -StatusCode 404
        }
    }
    
    if ($Global:REST_API_Debug) { Write-Host "[REST_API_Handle-Request]: DEBUG - Request completed: $localPath" -ForegroundColor White }
    
}
Write-Host "[REST_API_Server] function REST_API_Handle-Request registered" -ForegroundColor Green
function REST_Server_Wait-For-Request {
	if ($Global:REST_Server_Running) {
		Write-Host "[REST_Server_Wait-For-Request]: BLOCKING - Waiting for incoming HTTP requests..." -ForegroundColor Magenta
		$context = $Global:REST_Server_Listener.GetContext()  # Blocking call
		REST_API_Handle-Request -Context $context
	} else { 
		Write-Host "[REST_Server_Wait-For-Request]: WARNING - Server not running." -ForegroundColor Yellow
	}
}
Write-Host "[REST_API_Server] function REST_Server_Wait-For-Request registered" -ForegroundColor Green
function REST_API_SERVER_LibraryLoaded {
    Write-Host "[REST_API_SERVER] Library Loaded and functional" -ForegroundColor Gray
}
Write-Host "[REST_API_Server] Library Loaded" -ForegroundColor Gray
# HTTP Request Handling Functions ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
